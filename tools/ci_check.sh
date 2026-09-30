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

GODOT="${GODOT:-***REMOVED***/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64_console.exe}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUICK=0
[ "${1:-}" = "--quick" ] && QUICK=1

if [ ! -f "$GODOT" ]; then
  echo "✗ 找不到 Godot 可执行文件：$GODOT"
  echo "  请设置环境变量 GODOT 指向 Godot（Windows 用 _console.exe 版本）"
  exit 2
fi

FAILED=0
PASS_MARK="✓"
FAIL_MARK="✗"

# ── ① 脚本解析检查 ────────────────────────────────────────────────
echo "── ① 脚本解析检查 ──────────────────────────────────────"
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
for d in scripts/core scripts/battle scripts/pipeline scripts/identity \
         scripts/cards scripts/creatures scripts/relics scripts/map scripts/ui scripts/content \
         data/cards data/relics data/jobs data/enemies data/acts \
         scenes/boot tests tools docs; do
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
TEST_OUT="$("$GODOT" --headless -s addons/gut/gut_cmdln.gd -gexit --path "$PROJECT_DIR" 2>&1)"
if echo "$TEST_OUT" | grep -q 'All tests passed'; then
  echo "$TEST_OUT" | sed -n '/^Totals$/,/^Time/p' || true
  echo "$PASS_MARK 全部测试通过"
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
  # 逐 token 匹配（用词边界，避免误伤注释里提到类名的情况——注释也算提示，一并暴露）
  HIT="$(grep -nE "$FORBIDDEN" "$f" || true)"
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
