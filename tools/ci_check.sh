#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# 《弑神律》提交前校验（工程书 §2.6）
#
# 用法：
#   bash tools/ci_check.sh            # 五步全跑
#   bash tools/ci_check.sh --quick    # 只跑 ① 脚本解析
#
# 五步：① 脚本解析 ② 目录结构 ③ 场景冒烟 ④ GUT 单测 ⑤ 分层铁律
#
# 退出码：0 = 全过；1 = 有失败项；2 = 环境问题（找不到 Godot）
#
# 注意：Windows 上必须用 Godot 的 _console.exe，否则抓不到 stdout。
# ═══════════════════════════════════════════════════════════════════
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Godot 可执行文件定位 ─────────────────────────────────────
# ⚠️ 这里**不硬编码绝对路径**：本仓库要公开发布，个人机器路径不该进版本库。
# 解析顺序：① 环境变量 GODOT  ② 同目录下的 .local_paths.sh（**已 gitignore**）
#          ③ PATH 中的 godot4 / godot
# Windows 上必须用 **_console.exe**，否则 headless 抓不到 stdout。
if [ -z "${GODOT:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/.local_paths.sh" ]; then
  # shellcheck source=/dev/null
  . "$(dirname "${BASH_SOURCE[0]}")/.local_paths.sh"
fi
GODOT="${GODOT:-$(command -v godot4 2>/dev/null || command -v godot 2>/dev/null || true)}"

QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

if [ -z "${GODOT:-}" ] || [ ! -f "$GODOT" ]; then
  echo "✗ 找不到 Godot 可执行文件（GODOT=${GODOT:-未设置}）"
  echo "  三种设置方式任选其一："
  echo "    1) export GODOT=/path/to/Godot_..._console.exe"
  echo "    2) 在 tools/.local_paths.sh 里写 GODOT=...（该文件不进版本库）"
  echo "    3) 把 godot 加进 PATH"
  echo "  ⚠️ Windows 请用 _console.exe 版本，否则抓不到 stdout"
  exit 2
fi

FAILED=0
PASS_MARK="✓"
FAIL_MARK="✗"

# ── ⓪ 资源导入 ──────────────────────────────────────────────────
# 新增 .gd（尤其带 class_name 的）或 .tres 之后**必须先导入**，
# 否则 .godot/global_script_class_cache.cfg 不更新，引用新类的脚本会整体编译失败，
# 报一个毫无线索的错：「Nonexistent function 'new' in base 'GDScript'」。
# 让门禁自己保证这一点，比依赖「记得先 import」可靠。
echo "── ⓪ 资源导入 ──────────────────────────────────────────"
"$GODOT" --headless --import --path "$PROJECT_DIR" > /dev/null 2>&1
echo "$PASS_MARK 资源导入完成"

# ── ① 脚本解析检查 ────────────────────────────────────────────────
echo "── ① 脚本解析检查 ──────────────────────────────────────"

# ⚠️ 顺带扫一遍「字面量 /n」。
# 用脚本批量生成 GDScript 时，`"\n"` 很容易被写成字面量 `/n` 落进文件，
# 造成 `func xxx() -> int:/n	var ...` 这种语法错误。
# 它会让**整个脚本**解析失败，而报错信息往往指向完全无关的地方。
# 这条扫描花不到一秒，能省掉半小时定位。
LITERAL_N="$(grep -rn '/n\s' "$PROJECT_DIR"/scripts "$PROJECT_DIR"/tests --include=*.gd 2>/dev/null || true)"
if [ -n "$LITERAL_N" ]; then
  echo "$FAIL_MARK 检测到字面量 /n（应为换行）："
  echo "$LITERAL_N" | head -10
  FAILED=1
fi

PARSE_OUT="$("$GODOT" --headless --quit --path "$PROJECT_DIR" 2>&1 \
  | grep -iE 'SCRIPT ERROR|Parse Error' \
  | grep -v '/addons/gut/' || true)"
if [ -n "$PARSE_OUT" ]; then
  echo "$FAIL_MARK 检测到脚本错误："
  echo "$PARSE_OUT" | head -20
  FAILED=1
else
  echo "$PASS_MARK 第一方脚本解析通过"
fi

if [ "$QUICK" = "1" ]; then
  echo
  [ "$FAILED" = "0" ] && echo "── 快速校验通过 ──" || echo "── 快速校验失败 ──"
  exit "$FAILED"
fi

# ── ② 目录结构完整性 ─────────────────────────────────────────────
echo
echo "── ② 目录结构完整性 ────────────────────────────────────"
STRUCT_FAIL=0
# ⚠️ `assets/portraits` / `assets/cards` / `assets/backgrounds` 是**按约定查表的目录**（阶段 8）：
# 代码不引用具体文件，只按 `<id>.png` 去找。目录一旦被改名/删除，
# **不报任何错，只是美术全部消失、静默回退程序化绘制**——
# 正是那种"绿灯下的失效"，所以必须由门禁盯着。
for d in scripts/core scripts/battle scripts/pipeline scripts/identity \
         scripts/cards scripts/creatures scripts/relics scripts/map scripts/ui scripts/content \
         data/cards data/relics data/jobs data/enemies data/acts data/events data/potions data/act_modifiers data/allies \
         scenes/boot scenes/map scenes/battle scenes/ui tests tools docs \
         assets/portraits assets/cards assets/backgrounds; do
  if [ ! -d "$PROJECT_DIR/$d" ]; then
    echo "  $FAIL_MARK 缺少目录：$d"
    STRUCT_FAIL=1
  fi
done
if [ "$STRUCT_FAIL" = "0" ]; then
  echo "$PASS_MARK 目录结构与工程书 §2.1 一致"
else
  FAILED=1
fi

# ── ③ 场景冒烟测试 ───────────────────────────────────────────────
echo
echo "── ③ 场景冒烟测试 ──────────────────────────────────────"
SMOKE_OUT="$("$GODOT" --headless --path "$PROJECT_DIR" --script tools/smoke.gd 2>&1)"
SMOKE_CODE=$?
echo "$SMOKE_OUT" | grep -E '^OK |^smoke:' || true
if [ "$SMOKE_CODE" != "0" ] || echo "$SMOKE_OUT" | grep -q 'FAIL'; then
  echo "$FAIL_MARK 场景冒烟测试失败（退出码 $SMOKE_CODE）"
  echo "$SMOKE_OUT" | grep -E 'ERROR|FAIL' | head -20
  FAILED=1
else
  echo "$PASS_MARK 全部场景可加载"
fi

# ── ④ 单元测试（GUT）────────────────────────────────────────────
echo
echo "── ④ 单元测试（GUT）────────────────────────────────────"

# ⚠️ 先数一遍源码里有多少个 test_ 函数，**跑完再对账**。
#
# 为什么需要这个：GUT 曾经**静默漏跑**整个脚本文件——
# 23 个测试文件只跑了 22 个、444 个用例只跑了 424 个，
# 却照样打印 "All tests passed"。
#
# **报绿但实际没跑，比测试红了危险得多**：红着的测试会有人去看，
# 绿灯下的盲区没人会看。所以这条检查必须存在，而且必须让"对不上"直接失败。
EXPECTED_TESTS="$(grep -h '^func test_' "$PROJECT_DIR"/tests/*.gd | wc -l | tr -d ' ')"
EXPECTED_FILES="$(ls "$PROJECT_DIR"/tests/test_*.gd 2>/dev/null | wc -l | tr -d ' ')"

TEST_OUT="$("$GODOT" --headless -s addons/gut/gut_cmdln.gd -gexit --path "$PROJECT_DIR" 2>&1)"

if echo "$TEST_OUT" | grep -q 'All tests passed'; then
  echo "$TEST_OUT" | sed -n '/^Totals$/,/^Time/p' || true

  REPORTED_TESTS="$(echo "$TEST_OUT" | sed -n 's/^Tests *\([0-9][0-9]*\)$/\1/p' | head -1)"
  REPORTED_FILES="$(echo "$TEST_OUT" | sed -n 's/^Scripts *\([0-9][0-9]*\)$/\1/p' | head -1)"
  : "${REPORTED_TESTS:=0}"
  : "${REPORTED_FILES:=0}"

  # ⚠️ 最要命的一条：测试文件**解析失败**时，GUT 会静默跳过整个文件，
  # 然后照样打印 "All tests passed"。所以这里直接把解析错误捞出来。
  BROKEN="$(echo "$TEST_OUT" | grep -oE 'Failed to load script "res://tests/[^"]+"' | sort -u || true)"
  if [ -n "$BROKEN" ]; then
    echo "$FAIL_MARK 有测试文件解析失败（GUT 会**静默跳过**它，然后照样报绿）："
    echo "$BROKEN" | sed 's/^/   /'
    echo "   单独跑它看具体错误：-gselect=<文件名>"
    FAILED=1
  fi

  if [ "$REPORTED_TESTS" -lt "$EXPECTED_TESTS" ]; then
    echo "$FAIL_MARK 用例数对不上：GUT 只跑了 $REPORTED_TESTS 个，源码里有 $EXPECTED_TESTS 个"
    echo "   （$REPORTED_FILES/$EXPECTED_FILES 个文件）—— **有脚本被静默跳过了**"
    FAILED=1
  fi

  if [ "$FAILED" -eq 0 ]; then
    echo "$PASS_MARK 全部测试通过（$REPORTED_FILES 文件 / $REPORTED_TESTS 用例，与源码对得上）"
  fi
else
  echo "$FAIL_MARK 单元测试失败："
  echo "$TEST_OUT" | tail -40
  FAILED=1
fi

# ── ⑤ 分层铁律：ui/ 不得依赖 battle/ 或 pipeline/ ────────────────
echo
echo "── ⑤ 分层铁律（ui/ 不得依赖 battle/ 或 pipeline/）──────"
FORBIDDEN="BattleManager|DamagePipeline|DamageInfo|IntentResolver|TurnFlow|BattleScene"
LAYER_HITS=""
for f in "$PROJECT_DIR"/scripts/ui/*.gd; do
  [ -f "$f" ] || continue
  # 先剥掉注释再匹配。注释里提一句类名不是依赖；
  # 而误报会让人干脆关掉这道门禁——那比没有门禁更糟。
  HIT="$(sed -E 's/#.*$//' "$f" | grep -nE "$FORBIDDEN" || true)"
  if [ -n "$HIT" ]; then
    LAYER_HITS="$LAYER_HITS$(basename "$f"): $HIT"$'\n'
  fi
done
if [ -n "$LAYER_HITS" ]; then
  echo "$FAIL_MARK ui/ 层出现了对战斗逻辑的依赖："
  echo "$LAYER_HITS"
  echo "  修法：把逻辑移到 scripts/battle/battle_scene.gd（组合根），ui 只发信号 + 收展示指令"
  FAILED=1
else
  echo "$PASS_MARK ui/ 层与战斗逻辑解耦"
fi

# ── 汇总 ─────────────────────────────────────────────────────────
echo
if [ "$FAILED" = "0" ]; then
  echo "════ 校验通过，可以提交 ════"
else
  echo "════ 校验失败，请先修复 ════"
fi
exit "$FAILED"
