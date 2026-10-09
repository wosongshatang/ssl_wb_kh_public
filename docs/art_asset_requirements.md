# 《弑神律》美术资源需求总表（按优先级）

> **本文件是美术资源的唯一调度清单**：全部待做资源、优先级、可直接使用的提示词。
> **风格基底以 `docs/art_style_base.md` 为准**，本文件原样引用、不另立一套。
>
> 📌 **要开工请看 `docs/art_generation_checklist.md`** —— 那份是**可执行版**：
> 划掉了已完成的 45 项、按批次排好剩余 **208 项**，并附技能 / 文档 / 工具 / 命令清单。
> 本文件负责"这张图该画什么"（提示词与设计依据），那份负责"先做哪个、怎么做"。
>
> 生成日期：2026-10-08 ｜ 依据：`data/` 下全部 `.tres` 实际清点
> 总需求 **247 项**（不含已完成的 3 张角色立绘）

---

## ★ 交付状态（2026-10-08 更新）

| 批次 | 内容 | 数量 | 状态 |
|---|---|---|---|
| **1a** | 背景补齐 | 6 | ✅ **已完成并接线** |
| **1b+1c** | 起手牌 + 普通牌卡图 | 27 | ✅ **已完成并接线** |
| **2a** | Boss / 精英立绘 | 6 | ✅ **已完成并接线** |
| 1 剩余 | 剩余卡图 | 78 | ⬜ 待做 |
| 2b | 地图节点图标 | 8 | ⬜ 待做（**需先接线**） |
| 3 | 普通敌人 46 / 遗物 44 / 药水 10 / 职业 18 | 118 | ⬜ 待做 |
| 4 | 盟友立绘 | 4 | ⬜ 待做 |

**已完成 39 项**，全部落在**已接线**的三类里（丢图即生效）。
实际入库情况：

```
assets/backgrounds/   9 张（三线三幕齐全）
assets/portraits/     9 张（3 角色 + 3 Boss + 3 精英）
assets/cards/        27 张（9 初始牌 + 18 普通牌）
```

**接线改动**（本批次唯一的代码改动）：

| 文件 | 改动 |
|---|---|
| `scripts/ui/battle_background.gd` | `BACKGROUND_GROUND_RATIO` 从 3 条扩到 **9 条**（新增 6 张的地面线比例） |
| `tests/test_art_tone.gd` | `BACKGROUNDS` 从 3 张扩到 **9 张**——原本漏掉的 6 张不受基调约束 |
| `tests/test_battle_readability.gd` | 3 条测试原以「第 2 幕无图」为前提，补齐后**必须改用真正不存在的幕** |

**实测明度（Rec.709，与 `test_art_tone.gd` 同口径）**：

| 背景 | L̄ | 背景 | L̄ | 背景 | L̄ |
|---|---|---|---|---|---|
| warrior_act1 | 53.1 ⚠️折中 | mage_act1 | 36.4 ✅ | hunter_act1 | 40.8 ✅ |
| warrior_act2 | 43.8 ✅ | mage_act2 | 43.1 ✅ | hunter_act2 | 39.7 ✅ |
| warrior_act3 | 39.3 ✅ | mage_act3 | 39.6 ✅ | hunter_act3 | 43.1 ✅ |

非折中项区间 **36.4 – 43.8**，离散 **20.3%**（门槛 20%）——**刚好压线通过**。
下一批若再加背景，必须先看这条会不会被顶破。

---

## 〇、统一规范（所有资产共用，先读这一节）

### 0.1 三段式流程

```
① 共用基底（每次原样前置）
        ↓
② 明度基调（已并入基底，不要删）
        ↓
③ 资产专属基底 + 该资源的「主体短语」
        ↓
④ 生成后程序化校验（§0.7）
```

**为什么必须原样前置**：AI 对"风格"没有记忆。每张图单独描述必然漂移。
把风格**和明度**写成固定前缀，是让一批图看起来像一套的最省力手段。

### 0.2 共用基底（**每次生成，一字不改地放在最前面**）

```
dark fantasy card game art, painterly digital illustration, muted desaturated palette
with one strong accent color, dramatic side lighting, subtle rim light, clean silhouette,
no text, no watermark, no border, no frame
```

### 0.3 ★ 明度基调（**追加在共用基底之后，不要删**）

```
low-key lighting, predominantly dark values, held-down highlights, deep shadows,
overcast dim sky, no blown-out highlights, no sun glare, no bright reflective surfaces
```

> 实测：`dark fantasy` 这类词只影响"风格感"，**不影响实际亮度分布**。
> 必须写**光照方式**和**高光处理**。

### 0.4 四类资产的专属基底与参数

> 四类**不能混用**：画幅、主体、背景都不同。

| 类别 | 专属基底（接在共用基底之后） | 尺寸 | background | quality |
|---|---|---|---|---|
| **A 立绘** | `character portrait, full body, centered, facing viewer, transparent background, arms held slightly away from the torso so the silhouette reads clearly, weapon kept close and within the body silhouette` | **1024×1536** | `transparent` | high |
| **B 卡图** | `single dominant focal subject, high contrast against the background, simple bold composition, readable when scaled down to 104x113 pixels, centered with generous negative space, opaque dark background` | **1024×1024** | `opaque` | high |
| **C 背景** | `environment concept art, wide establishing shot, no characters, fully opaque painted background, no transparency, the lower half is flat walkable ground, the horizon line sits slightly above the middle of the frame, no foreground objects blocking the center` | **1536×1024** | `opaque` | high |
| **D 图标**（本轮新增类别） | `single simple symbol icon, bold flat silhouette, reads clearly at 32x32 pixels, centered, transparent background` | **256×256** | `transparent` | high |

**⚠️ 三类硬约束**

1. **立绘**绝不能用 `opaque`，**背景**绝不能用 `transparent`——
   环境图用透明底会让模型"把天空挖空"，上半部分全透明（已踩过）。
2. **卡图**必须 `1024×1024` **正方形**，不是立绘的 2:3。
3. **图标**是新增类别：显示尺寸只有 **24–40px**（地图节点直径 40 / 药水槽 30），
   所以**必须"一个符号 + 强剪影"**，任何细节都会糊掉。

### 0.5 负向词

**卡图 / 图标**（两者共用）
```
text, letters, numbers, watermark, signature, card frame, border, UI elements,
multiple subjects, cluttered background, busy detail, tiny details, depth of field,
bright saturated colors, anime, chibi, cute, cartoon, blurry, low contrast,
high-key lighting, bright daylight, sun glare, blown-out sky, overexposed, washed-out
```

**背景**额外追加
```
characters, people, figures, creatures
```

### 0.6 命名与放置（**丢进去就生效，不用改任何 `.tres`**）

| 类别 | 目录 | 文件名 = |
|---|---|---|
| A 立绘（角色） | `assets/portraits/` | `warrior.png` / `mage.png` / `hunter.png` |
| A 立绘（敌人 / 盟友） | `assets/portraits/` | `<敌人或盟友 id>.png`（如 `act1_boss.png`、`wolf.png`） |
| B 卡图 | `assets/cards/` | `<卡牌 id>.png`（如 `strike.png`） |
| C 背景 | `assets/backgrounds/` | `<角色>_act<幕>.png` |
| D 图标 | **尚未接线**（见 §0.7） | `<kind>.png` / `<id>.png` |

> **升级牌共用基础卡的图**：`strike+` 自动用 `strike.png`，**不用另出图**。

### 0.7 ★ 接线状态（决定"能不能立刻做"）

清点代码后的实际情况——**只有 3 类已经接线**：

| 类别 | 接线状态 | 依据 |
|---|---|---|
| **A 立绘** | ✅ **已接线**（丢图即生效） | `ContentRegistry.get_portrait()` → `assets/portraits/<id>.png`；敌人走 `EnemyData.effective_portrait_id()`，盟友走 `AllyData.portrait_id` |
| **B 卡图** | ✅ **已接线** | `ContentRegistry.get_card_art()` |
| **C 背景** | ✅ **已接线** | `ContentRegistry.get_battle_background()` |
| **D 图标** | ❌ **未接线** | 地图节点 / 遗物 / 药水 / 职业当前全部是**程序化几何图形**（`map_view.gd:_draw_node_glyph`、`potion_slot.gd:_draw`、`run_hud.gd`），没有任何图片加载路径 |

**这意味着**：
- A / B / C 三类（6 + 105 + 52 + 4 = **167 项**）**可以立刻开工，零代码改动**。
- D 类（8 + 44 + 10 + 18 = **80 项**）**必须先加接线代码**，
  否则做出来没有地方显示。接线工作量不大（每类约 30–60 行，合计约 120–160 行），
  但**必须先决定"要不要做图标"**，再决定投不投美术产能。

> **167 已接线 ｜ 80 待接线 ｜ 合计 247**

### 0.8 生成后校验（把"感觉"变成"数字"）

```bash
PY="C:/Users/Johnk/.workbuddy-ai/binaries/python/envs/default/Scripts/python.exe"
SK="C:/Users/Johnk/.workbuddy-ai/skills/card-game-art-asset-pipeline/scripts/verify_art.py"

"$PY" "$SK" alpha <目录或文件...>                      # 尺寸 + 透明通道
"$PY" "$SK" luma --char <角色...> --env <环境...>       # 背景是否比角色暗
"$PY" "$SK" luma --card <卡图...>                       # 卡图单独判定
"$PY" "$SK" preview --card <卡图...>                    # 缩到 104×113 验收可读性（卡图必跑）
```

**明度目标（Rec.709 加权平均亮度，只统计 alpha ≥ 200 的像素）**

| 层次 | 理想区（越界只警告 ⚠️） | 硬上限（突破必拦 ❌） |
|---|---|---|
| 环境 / 背景 | 35 – 48 | 30 – 55 |
| 角色 / 立绘 | 42 – 70 | 36 – 75 |
| 卡图 | 22 – 40 | 18 – 48 |
| 图标 | 25 – 55 | 18 – 65 |
| 强调色高光（>160）面积 | — | **< 5%**（硬性） |

**四条层次规则**：① 硬规则 **环境 L̄ < 角色 L̄**；② 理想 ≤ 角色 × 0.85；
③ 高光只归强调色且 < 5%；④ 暗部与中间调占 ≥ 70%。

> ⚠️ **两档制是刻意的**（D17）：理想区越界只警告、不判失败。
> **门禁一旦误报，人就会干脆关掉它——比没有门禁更糟。**

### 0.9 每批必做的三件事

1. 先跑 **3 张试水**，覆盖三档（最常出现 / 中间档 / 天花板），确认风格后再批量
2. 出图后跑 §0.8 的校验命令，**卡图必跑 `preview`**
3. 缩到实际尺寸**肉眼看一眼**——数字只保证"亮度和构图不出错"，**不保证"好看"**

---

## 一、优先级总表

排序依据：**（视觉影响 × 覆盖率 ÷ 成本）× 接线成本修正**

| 优先级 | 类别 | 数量 | 已接线 | 排在这个位置的理由 |
|---|---|---|---|---|
| **P0-1** | 背景补齐 | **6** | ✅ | 每场战斗都看到；9 条线里 6 条在用程序化兜底；**只有 6 张** |
| **P0-2** | 起手牌 / 普通牌卡图 | **27** | ✅ | 手牌**常驻屏幕**；打击/防御每局必出；稀有度最低 = 出现频率最高 |
| **P1-1** | Boss / 精英立绘 | **6** | ✅ | 战斗的视觉焦点；**只有 6 张**；Boss 战是每幕的高潮 |
| **P1-2** | 地图节点图标 | **8** | ❌ 需接线 | **8 张覆盖整张地图 UI**，单张性价比最高；需先加接线代码 |
| **P1-3** | 剩余卡图 | **78** | ✅ | 覆盖剩余全部卡面；可分批 |
| **P2-1** | 普通敌人立绘 | **46** | ✅ | 战斗中一直在看；但数量大，可分批 |
| **P2-2** | 遗物图标 | **44** | ❌ 需接线 | 提升"拿到东西"的仪式感；需接线 |
| **P2-3** | 药水图标 | **10** | ❌ 需接线 | 只有 10 张；需接线 |
| **P2-4** | 职业图标 | **18** | ❌ 需接线 | 转职是叙事高光，但一局只见 2 次；需接线 |
| **P3** | 盟友立绘 | **4** | ✅ | 只有猎人线会看到；锦上添花 |

**总计 247 项**（不含已完成的 3 张角色立绘）

---

## 二、P0-1 · 背景补齐（6 张）

**类型与用途**：环境背景（战斗场景底图）· 尺寸 **1536×1024** · `opaque` · `quality=high`
**为什么 P0**：每场战斗都看到。当前 9 条线里只有 3 条有图，其余 6 条用程序化色块兜底——
**玩家最容易看出"没做完"的地方**。

**拼接方式**：`共用基底 + 明度基调 + C 类专属基底 + 下面的主体短语`

> ⚠️ 生成后**必须量一次地面线比例**，补进 `BattleBackground.BACKGROUND_GROUND_RATIO`。
> 地面线要落在画面 **44% 以上**（角色脚底在 48%），否则角色会浮空。

### 1. `warrior_act2` 战场（战士 · 第二幕）
```
a vast desert battlefield at dusk, scattered broken spears and tattered war banners
planted in the sand, distant smoke columns on the horizon, a cold steel-blue glow
from the banners as the single accent color, no characters
```

### 2. `warrior_act3` 古战场（战士 · 第三幕）
```
an ancient battlefield of bones and rusted armor stretching to the horizon, a huge
cracked stone throne half-buried in the center distance, faint ember-orange light
seeping from the cracks as the single accent color, oppressive stillness, no characters
```

### 3. `mage_act1` 学徒白塔（法师 · 第一幕）
```
the interior of a vast stone tower library, towering shelves of crumbling tomes,
floating geometric teaching constructs of pale blue light as the single accent color,
dust motes in still air, no characters
```

### 4. `mage_act3` 万法归墟（法师 · 第三幕）
```
an endless void of collapsing reality, fragments of stone and broken geometry drifting
inward toward a distant point, thin violet light tracing the fracture lines as the
single accent color, absolute darkness beyond, no characters
```

### 5. `hunter_act1` 翠林猎场（猎人 · 第一幕）
```
a dense primeval forest clearing, enormous twisted tree roots and hanging moss,
low ground fog, faint sickly green bioluminescence from the undergrowth as the single
accent color, dappled shadow, no characters
```

### 6. `hunter_act2` 大荒野（猎人 · 第二幕）
```
a wind-scoured open wasteland of dry grass and scattered animal bones, distant
mesas under a heavy overcast sky, a single cold amber light break on the horizon
as the single accent color, no characters
```

---

## 三、P0-2 · 起手牌 / 普通牌卡图（27 张）

**类型与用途**：卡面插图 · 尺寸 **1024×1024** · `opaque` · `quality=high`
**为什么 P0**：手牌区**常驻屏幕底部**。稀有度最低的牌 = 出现频率最高的牌，
**先做它们，玩家感知到的"完成度提升"最大**。

**拼接方式**：`共用基底 + 明度基调 + B 类专属基底 + 下面的主体短语 + 卡图负向词`

> ⚠️ 主体必须收在**中央 90% 以内**（左右各会被裁掉约 4%）。
> 出图后**必须跑 `preview`** 缩到 104×113 确认可读。

### 初始牌（9 张，出现频率最高）

**1. `strike` 打击**（攻击 · 初始）
```
a single worn iron sword blade slicing diagonally through the frame, a thin trail of
pale steel-blue light as the single accent color, dark storm-grey void background,
no character visible
```

**2. `defend` 防御**（技能 · 初始）
```
a battered round wooden shield raised at a slight angle, chipped paint and dented iron
rim, a faint warm amber glow along the rim as the single accent color, dark slate
background, centered, symmetrical
```

**3. `bash` 重击**（攻击 · 初始）
```
a heavy iron mace head smashing downward into cracked stone, shards and dust flying
outward, dull ember-orange sparks as the single accent color, dark grey dust background
```

**4. `iron_wave` 铁斩波**（攻击 · 初始）
```
a crescent-shaped shockwave of pale steel light sweeping across the frame, iron filings
suspended in the air, cold white-blue as the single accent color, near-black background
```

**5. `shrug_it_off` 甩脱**（技能 · 初始）
```
a pair of scarred forearms breaking free of binding chains, links snapping outward,
a cold white flash at the break point as the single accent color, near-black background
```

**6. `hunter_guard` 侧步**（技能 · 初始 · 猎人）
```
a single boot pivoting on loose gravel with a swept arc of dust, motion implied by
direction only, faint amber rim light as the single accent color, dark forest floor
background, no character
```

**7. `hunter_shot` 射击**（攻击 · 初始 · 猎人）
```
a single arrow in mid-flight, fletching blurred with speed, a faint amber trail as the
single accent color, dark forest-green void background, horizontal centered composition
```

**8. `mage_spark` 火花**（攻击 · 初始 · 法师）
```
a small bright spark of arcane energy just igniting between two fingers of empty air,
a tiny cold cyan burst as the single accent color, dark indigo void background, centered
```

**9. `mage_ward` 法力护盾**（技能 · 初始 · 法师）
```
a translucent hexagonal barrier of pale blue energy seen edge-on, faint rune rings
turning slowly within it, cold cyan as the single accent color, dark indigo background,
symmetrical frontal
```

### 普通牌（18 张，出现频率次高）

**10. `arcane_bolt` 奥术弹**（攻击 · 普通）
```
a condensed sphere of arcane energy with a comet tail, fragments of geometric runes
orbiting it, cold cyan-violet as the single accent color, dark indigo void background,
centered
```

**11. `brace` 坚守**（技能 · 普通）
```
a single iron-banded wooden bar braced diagonally against a stone floor, tension in the
angle, faint warm amber glow along the grain as the single accent color, dark background
```

**12. `call_wolf` 唤狼**（技能 · 普通）
```
the translucent spirit-form of a wolf emerging from a swirl of pale mist, eyes glowing,
cold spectral blue as the single accent color, dark background, centered
```

**13. `clothesline` 晾衣绳**（攻击 · 普通）
```
a forearm sweeping horizontally across the frame in a brutal clothesline, dust and
sweat trailing the arc, dull crimson glow at the contact point as the single accent
color, near-black background
```

**14. `dodge_roll` 翻滚**（技能 · 普通）
```
a dust ring left behind by a rolling body that has already left the frame, a few
scattered pebbles mid-air, faint amber trail as the single accent color, dark ground
background, no character
```

**15. `elixir_of_might` 力量药剂**（技能 · 普通）
```
a squat glass vial of dark red liquid, cork askew, thick vapor curling from the mouth,
deep crimson as the single accent color, near-black background, centered macro framing
```

**16. `flame_arrow` 火焰箭**（攻击 · 普通）
```
an arrowhead wreathed in orange flame mid-flight, embers shedding backward, fierce
orange as the single accent color, dark smoky background, diagonal composition
```

**17. `footwork` 步法**（能力 · 普通）
```
a pair of worn boots planted in a wide stable stance, faint amber energy coiling upward
around the ankles, warm amber as the single accent color, near-black background,
symmetrical frontal
```

**18. `heavy_strike` 猛击**（攻击 · 普通）
```
a massive two-handed hammer head caught at the top of its arc, momentum visible in the
blurred shaft, dull orange sparks as the single accent color, dark grey background
```

**19. `ice_shard` 冰锥**（攻击 · 普通）
```
a jagged spear of translucent ice thrusting forward, frost crystals forming along its
length, pale glacier-blue as the single accent color, dark navy background
```

**20. `inflame` 燃烧**（能力 · 普通）
```
a warrior's fist clenched and wreathed in rising orange flame, embers drifting upward,
molten orange as the single accent color, near-black background, centered
```

**21. `mana_shield` 魔力屏障**（技能 · 普通）
```
a curved plane of rippling blue energy deflecting a burst of sparks, concentric
interference rings, cold cyan-blue as the single accent color, dark indigo background
```

**22. `meditate` 冥想**（技能 · 普通）
```
a still pool of dark water reflecting a single point of pale light from above,
concentric ripples frozen, cold white-blue as the single accent color, near-black
background, centered, perfectly symmetrical
```

**23. `pommel_strike` 剑柄打击**（攻击 · 普通）
```
the pommel of a sword driven forward into the frame, short brutal reach, a thin arc of
pale steel light as the single accent color, dark background, tight framing
```

**24. `quick_shot` 速射**（攻击 · 普通）
```
two arrows already loosed and separating in flight, motion streaks behind them, faint
amber as the single accent color, dark forest-green void background, horizontal
```

**25. `sprint` 冲刺**（技能 · 普通）
```
a long trail of disturbed dust and dry leaves stretching across the frame from right to
left, faint amber glow at the leading edge as the single accent color, dark ground, no
character
```

**26. `trap` 陷阱**（攻击 · 普通）
```
a sprung iron jaw trap snapping shut on empty air, teeth interlocked, a few broken twigs
flying, cold steel-blue glint as the single accent color, dark forest floor background
```

**27. `true_grit` 真勇**（技能 · 普通）
```
a scarred hand closing into a fist, knuckles split and bleeding, faint warm amber light
seeping between the fingers as the single accent color, near-black background, centered
```

---

## 四、P1-1 · Boss / 精英立绘（6 张）

**类型与用途**：敌人立绘（战斗场景主体）· 尺寸 **1024×1536** · `transparent` · `quality=high`
**为什么 P1**：战斗的**视觉焦点**；只有 6 张；每幕的高潮都是 Boss 战。
**已接线**：`EnemyData.effective_portrait_id()` → 文件名用**敌人 id**。

**拼接方式**：`共用基底 + 明度基调 + A 类专属基底 + 下面的主体短语`

> ⚠️ 立绘是**透明底**，不能用背景那套 `opaque`。
> 主体同样要收在中央 90% 内。

### 1. `act1_boss` 盾姿态（战士线第一幕 Boss · 78 血）
```
a towering armored arena champion in heavy bronze plate, a massive tower shield planted
in front, helmet fully closed, tattered red cape, faint ember-orange light leaking from
the helmet slit as the single accent color, front facing, full body
```

### 2. `act2_boss` 军阵（战士线第二幕 Boss · 105 血）
```
a desert warlord in layered lamellar armor standing before a wall of overlapping
shields, a curved blade held low, dust swirling at the feet, cold steel-blue rim light
as the single accent color, front facing, full body
```

### 3. `act3_boss` 战神（战士线第三幕 Boss · 145 血）
```
a colossal divine warrior of cracked stone and molten gold seams, four arms, a broken
halo of gold fragments floating behind the head, eyes burning, radiant gold as the
single accent color, front facing, full body, epic scale
```

### 4. `act1_elite` 精英 · 铁律卫士（第一幕精英 · 46 血）
```
a heavy iron automaton enforcer, riveted plates, a single glowing slit visor, chains
hanging from its shoulders, cold pale blue light from the visor as the single accent
color, front facing, full body
```

### 5. `act2_elite` 精英 · 沙暴统领（第二幕精英 · 58 血）
```
a tall nomad commander wrapped in wind-torn layered cloth, face hidden by a veil, a
long spear planted in the sand, sand streaming off the shoulders, cold amber light from
the spear tip as the single accent color, front facing, full body
```

### 6. `act3_elite` 精英 · 律令化身（第三幕精英 · 82 血）
```
an androgynous arbiter figure of white stone and black glass, featureless face, a
floating ring of law-tablets orbiting the body, thin violet light in the tablet
engravings as the single accent color, front facing, full body
```

---

## 五、P1-2 · 地图节点图标（8 个）

**类型与用途**：地图节点图标 · 尺寸 **256×256** · `transparent` · `quality=high`
**为什么 P1**：**8 张覆盖整张地图 UI**，单张性价比全表最高。
**⚠️ 未接线**：当前是程序化几何图形（`map_view.gd:_draw_node_glyph`），
**必须先加接线代码**（约 40 行）。显示直径约 **40px**（`NODE_RADIUS = 20`），
所以**必须极简**。

**拼接方式**：`共用基底 + 明度基调 + D 类专属基底 + 下面的主体短语 + 卡图负向词`

**配色建议**（避免与 `ui_palette.gd` 的既有色撞车）：

| 节点 | 建议强调色 |
|---|---|
| COMBAT | 冷钢蓝 |
| ELITE | 暗金 |
| REST | 暖绿 |
| SHOP | 琥珀 |
| EVENT | 淡紫 |
| BOSS | 血红 |
| GOD_ALTAR | 金白 |
| TRAITOR | 暗青 |

### 1. `combat` 普通战斗
```
two crossed simple swords, bold flat silhouette, cold steel-blue as the single accent color
```

### 2. `elite` 精英战斗
```
a single crown above crossed swords, bold flat silhouette, dark gold as the single accent color
```

### 3. `rest` 休息
```
a campfire flame with two crossed logs beneath, bold flat silhouette, warm green as the single accent color
```

### 4. `shop` 商店
```
a simple merchant coin purse with a coin above it, bold flat silhouette, amber as the single accent color
```

### 5. `event` 事件
```
a question-mark-shaped spiral rune, bold flat silhouette, pale violet as the single accent color
```

### 6. `boss` 幕 Boss
```
a horned skull inside a broken ring, bold flat silhouette, blood red as the single accent color
```

### 7. `god_altar` 神坛
```
a simple stone altar with a single flame rising from it, bold flat silhouette, gold-white as the single accent color
```

### 8. `traitor` 叛神者
```
a broken chain link splitting apart, bold flat silhouette, dark teal as the single accent color
```

---

## 六、P1-3 · 剩余卡图（78 张）

**类型与用途**：卡面插图 · 尺寸 **1024×1024** · `opaque`
**拼接方式**：`共用基底 + 明度基调 + B 类专属基底 + 下表中的主体短语 + 卡图负向词`

> 表内是**唯一可变的部分**。基底固定，所以「基底 + 该行」= 完整提示词。
> `t` = 类型（0 攻击 / 1 技能 / 2 能力）· `r` = 稀有度（2 绿 / 3 蓝 / 4 紫 / 5 金 / 6 无色 / 7 诅咒）

### 罕见（绿框 ⚠️ 避开绿色主体）

| id | 名称 | t | r | 主体短语 |
|---|---|---|---|---|
| `blink` | 闪现 | 1 | 2 | `a human silhouette dissolving into a scatter of pale blue particles mid-step, cold cyan as the single accent color, dark background, centered` |
| `call_bear` | 唤熊 | 1 | 2 | `the translucent spirit-form of a massive bear rearing up, mist trailing from its paws, cold spectral blue as the single accent color, dark background` |
| `charge_up` | 蓄能 | 2 | 2 | `a closed fist wreathed in slowly coiling pale blue energy threads, glow from within, cold cyan as the single accent color, near-black background, centered` |
| `frost_armor` | 寒霜护甲 | 1 | 2 | `a torso-shaped shell of layered frost and ice plates, breath fog curling at the edges, pale ice-blue as the single accent color, dark background, symmetrical frontal` |
| `gather` | 蓄势 | 1 | 2 | `two hands cupped around a slowly gathering sphere of faint light, cold white-blue as the single accent color, near-black background, centered` |
| `hunters_focus` | 猎人专注 | 2 | 2 | `a single eye rendered as a targeting reticle of pale amber light, cold focus, amber as the single accent color, near-black background, centered` |
| `ignite` | 灼烧 | 1 | 2 | `a hand holding a single burning ember that has just caught, thin smoke rising, molten orange as the single accent color, near-black background` |
| `impervious` | 铜墙铁壁 | 1 | 2 | `a wall of overlapping iron tower shields locked together, rivets and deep dents, a faint bronze glow seeping between the seams as the single accent color, symmetrical frontal` |
| `iron_bulwark` | 铁壁 | 1 | 2 | `a single massive slab of riveted iron plate standing upright, faint cold blue rim light as the single accent color, dark background, frontal` |
| `multi_shot` | 多重射击 | 0 | 2 | `three arrows fanned out in flight from a single point, thin motion trails, cold amber as the single accent color, dark forest background, diagonal` |
| `poison_arrow` | 毒箭 | 0 | 2 | `a close-up of an arrowhead dripping viscous green venom, one bead of poison falling, sickly acid-green as the single accent color, dark murky background, macro framing` |

### 稀有（蓝框 ⚠️ 避开蓝色主体）

| id | 名称 | t | r | 主体短语 |
|---|---|---|---|---|
| `arcane_nova` | 奥术新星 | 0 | 3 | `a bursting ring of arcane light expanding outward from a single point, cold violet-cyan as the single accent color, absolute black background, centered` |
| `arcane_torrent` | 奥术洪流 | 0 | 3 | `a wide torrent of arcane energy pouring across the frame, streaked with geometric rune fragments, cold cyan-violet as the single accent color, dark indigo background` |
| `armor_break` | 破甲 | 0 | 3 | `a plate of armor splitting apart along a single crack, fragments separating, dull red glow in the fracture as the single accent color, dark background` |
| `call_hawk` | 唤鹰 | 1 | 3 | `the translucent spirit-form of a hawk with wings fully spread, mist trailing from the wingtips, cold spectral blue as the single accent color, dark sky background` |
| `call_serpent` | 唤蛇 | 1 | 3 | `the translucent spirit-form of a coiled serpent rising, tongue flickering, cold spectral green as the single accent color, dark background, centered` |
| `earthshaker` | 撼地 | 0 | 3 | `the ground splitting open in a jagged fissure, stone slabs tilting upward, dull orange light from the depths as the single accent color, dark background, low angle` |
| `frozen_tomb` | 冰封 | 1 | 3 | `a rough block of clear ice enclosing a still human silhouette, frost spreading on the surface, pale glacier-blue as the single accent color, dark background` |
| `heavy_blow` | 重压 | 0 | 3 | `a colossal stone fist descending from above, cracks radiating from the point of impact, dull grey-white light as the single accent color, near-black background, low angle` |
| `hunters_volley` | 猎手齐射 | 0 | 3 | `a dense volley of arrows arcing down through the frame from the upper left, thin motion lines, cold white-amber as the single accent color, dark sky background, diagonal` |
| `meteor` | 陨石 | 0 | 3 | `a burning meteor streaking down through dark clouds, trailing fire and broken rock, fierce orange-red as the single accent color, stormy near-black sky, dramatic diagonal` |
| `oracle_eye` | 神谕·天眼 | 1 | 3 | `a vast disembodied eye opening in a dark sky, iris made of concentric pale rings, cold white-gold as the single accent color, absolute black background, centered` |
| `oracle_whisper` | 神谕·低语 | 1 | 3 | `a single thin ripple of pale light spreading across absolute darkness, faint whisper made visible, cold white-gold as the single accent color, near-black background` |
| `trial_frugal` | 考题·克己 | 1 | 3 | `an empty open palm held out, nothing in it, faint pale light along the fingers as the single accent color, near-black background, centered` |
| `trial_patience` | 考题·忍耐 | 1 | 3 | `an hourglass with almost all sand fallen, faint pale light in the lower bulb as the single accent color, near-black background, centered, symmetrical` |
| `volley` | 箭雨 | 0 | 3 | `a sky of arrows falling almost vertically through the frame, thin motion lines, cold white-amber as the single accent color, dark sky background` |
| `whirl` | 回旋斩 | 0 | 3 | `a circular blur of a spinning blade tracing one full arc of motion, cold steel-white as the single accent color, dark background with faint dust motes, dynamic circular motion` |

### 史诗（紫框 ⚠️ 避开紫色主体）

| id | 名称 | t | r | 主体短语 |
|---|---|---|---|---|
| `beast_stampede` | 万兽奔腾 | 0 | 4 | `a charging wall of spectral beast silhouettes rushing left to right, dust and mist churning beneath, cold spectral green as the single accent color, dark background` |
| `bulwark_stance` | 壁垒姿态 | 1 | 4 | `a figure-less stance of interlocked angular light plates forming a wall, faint bronze glow at the seams as the single accent color, near-black background, symmetrical frontal` |
| `divine_might` | 神威 | 0 | 4 | `a giant ethereal hand descending from above, palm open, radiating pale authority, blinding white-gold as the single accent color, pitch black background, low angle` |
| `frost_prison` | 霜狱 | 1 | 4 | `a cage of vertical ice bars grown from the ground, frost mist pooling inside, pale ice-blue as the single accent color, dark background, symmetrical frontal` |
| `godslayer_blow` | 弑神一击 | 0 | 4 | `a colossal blade of condensed golden light driving upward through a shattered divine halo, fragments of broken gold raining down, radiant gold as the single accent color, absolute black background, low angle, epic scale` |
| `last_stand` | 背水一战 | 0 | 4 | `a broken sword driven point-first into cracked ground, the last of its light gathering along the remaining edge, cold white-amber as the single accent color, near-black background` |
| `singularity` | 万象归墟 | 0 | 4 | `a collapsing black sphere devouring streaks of light that spiral inward, a thin violet accretion ring as the single accent color, absolute black void background, centered, sense of immense gravity` |

### 金（金框 ⚠️⚠️ **避开金色主体**，最容易撞）

| id | 名称 | t | r | 主体短语 |
|---|---|---|---|---|
| `gold_alpha_howl` | 头狼嗥叫 | 1 | 5 | `a spectral wolf head thrown back mid-howl, breath visible, cold spectral blue as the single accent color, near-black background, centered` |
| `gold_alpha_pack` | 群猎 | 0 | 5 | `several spectral wolf silhouettes fanning out in a hunting arc, mist at their paws, cold spectral blue as the single accent color, dark background` |
| `gold_arc_bolt` | 奥术冲击 | 0 | 5 | `a compressed lance of arcane force punching forward, rune fragments shattering around it, cold cyan as the single accent color, dark indigo background` |
| `gold_arc_reserve` | 蓄能储备 | 1 | 5 | `a slowly rotating ring of stored pale energy with a still core, cold cyan as the single accent color, near-black background, centered, symmetrical` |
| `gold_arch_focus` | 凝神 | 1 | 5 | `a single point of concentrated light at the center of a dark iris-like pattern, cold cyan-white as the single accent color, near-black background, centered` |
| `gold_arch_surge` | 奥术涌动 | 0 | 5 | `a vertical column of arcane energy surging upward through the frame, rune fragments rising with it, cold cyan as the single accent color, dark indigo background` |
| `gold_bash_counter` | 反击 | 0 | 5 | `a shield edge driven forward to meet an incoming blade, sparks at the contact, cold white-blue as the single accent color, near-black background` |
| `gold_bash_shatter` | 碎盾 | 0 | 5 | `a shield bursting apart into iron fragments from the inside, cold blue light in the fracture as the single accent color, dark background` |
| `gold_bastion_hold` | 死守 | 1 | 5 | `a battered shield planted firmly, arrows embedded in its face, cold blue rim light as the single accent color, near-black background, frontal` |
| `gold_bastion_rampart` | 城墙 | 1 | 5 | `a section of stone battlement wall seen frontally, crenellations in silhouette, cold blue rim light as the single accent color, near-black background` |
| `gold_blood_feast` | 血宴 | 0 | 5 | `a blade dripping dark blood, several droplets suspended mid-fall, deep crimson as the single accent color, near-black background, macro framing` |
| `gold_blood_ritual` | 血祭 | 1 | 5 | `a ritual circle drawn in dark blood on stone, cold light gathering in the center, deep crimson as the single accent color, near-black background, low angle` |
| `gold_chrono_hasten` | 加速 | 1 | 5 | `several overlapping clock hands spinning forward, motion trails, cold white-blue as the single accent color, near-black background, centered` |
| `gold_chrono_rewind` | 回溯 | 1 | 5 | `a clock hand reversing with light trailing backward, dust particles pulled back into place, cold white-blue as the single accent color, near-black background` |
| `gold_cryo_barrier` | 冰障 | 1 | 5 | `a wall of jagged ice crystals grown upward from the ground, frost mist at the base, pale ice-blue as the single accent color, dark background, frontal` |
| `gold_cryo_frostbite` | 霜噬 | 0 | 5 | `frost spreading rapidly across a dark surface in branching needles, pale ice-blue as the single accent color, near-black background, macro framing` |
| `gold_elem_spark` | 元素火花 | 0 | 5 | `a small cluster of four different elemental motes colliding, cold cyan dominant as the single accent color, near-black background, centered` |
| `gold_elem_veil` | 元素帷幕 | 1 | 5 | `a hanging curtain of shimmering elemental energy, thin bands of light, cold cyan as the single accent color, near-black background, frontal` |
| `gold_guard_brace` | 迎击架势 | 1 | 5 | `a shield angled forward with a blade set behind it, ready stance implied, cold blue rim light as the single accent color, near-black background` |
| `gold_guard_bulwark` | 磐石壁垒 | 1 | 5 | `a massive rough stone slab standing upright, chisel marks visible, cold blue rim light as the single accent color, near-black background, frontal` |
| `gold_momentum_flurry` | 疾风连斩 | 0 | 5 | `several overlapping blade arcs crossing the frame in rapid succession, cold steel-white as the single accent color, near-black background, dynamic` |
| `gold_momentum_press` | 追击 | 0 | 5 | `a blade driving forward with a long trailing streak, momentum visible, cold steel-white as the single accent color, near-black background, horizontal` |
| `gold_pyro_ember` | 余烬 | 1 | 5 | `a bed of dying embers with one last glow at the center, thin smoke rising, molten orange as the single accent color, near-black background, macro framing` |
| `gold_pyro_immolate` | 焚身 | 0 | 5 | `a humanoid silhouette consumed by rising orange flame, features lost to light, molten orange as the single accent color, absolute black background, centered` |
| `gold_rage_frenzy` | 狂暴 | 2 | 5 | `a clenched fist trembling with contained force, faint red light cracking between the knuckles, dull crimson as the single accent color, near-black background, centered` |
| `gold_rage_reckless` | 莽击 | 0 | 5 | `a wild overhead swing with no guard, the body's silhouette exposed, dull crimson as the single accent color, near-black background, dynamic` |
| `gold_ranger_aim` | 瞄准 | 0 | 5 | `a single arrowhead seen down the shaft, perfectly centered in a faint reticle of light, cold amber as the single accent color, near-black background, centered` |
| `gold_ranger_step` | 疾步 | 1 | 5 | `a light boot print appearing in soft ground, the next already forming ahead, faint amber trail as the single accent color, dark ground background, no character` |
| `gold_tame_bond` | 兽之羁绊 | 1 | 5 | `a thin spectral thread linking two points of light, one brighter than the other, cold spectral blue as the single accent color, near-black background` |
| `gold_tame_roar` | 怒吼 | 2 | 5 | `an open beast maw mid-roar, sound rendered as concentric cold rings, cold spectral blue as the single accent color, near-black background, centered` |
| `gold_thorn_hide` | 荆棘之皮 | 1 | 5 | `a hide surface bristling with short dark thorns, cold blue rim light on the tips as the single accent color, near-black background, macro framing` |
| `gold_thorn_lash` | 荆刺鞭 | 0 | 5 | `a long thorned lash curving through the frame mid-strike, barbs catching light, cold blue-white as the single accent color, near-black background, dynamic` |

### 无色（近白框 ⚠️ 避开纯白主体）

| id | 名称 | t | r | 主体短语 |
|---|---|---|---|---|
| `apotheosis_grand` | 大神化 | 1 | 6 | `a humanoid figure dissolving upward into a pillar of white light, human features breaking apart into luminous fragments, pure white-gold as the single accent color, absolute black background, centered, ascending` |
| `apotheosis_minor` | 小神化 | 1 | 6 | `a single hand dissolving at the fingertips into drifting motes of pale light, cold white as the single accent color, near-black background, centered` |
| `divine_arcaneflux` | 奥流 | 1 | 6 | `a wide slow current of pale divine energy flowing across the frame, faint geometric runes carried within it, cold white-cyan as the single accent color, near-black background` |
| `divine_breakarmy` | 破军 | 0 | 6 | `a single spear of white light splitting a mass of dark silhouettes apart, cold white as the single accent color, absolute black background, dynamic` |
| `divine_deathwish` | 死战 | 0 | 6 | `a broken blade still raised, light gathering at the fracture, cold white as the single accent color, absolute black background, low angle` |
| `divine_huntmark` | 猎印 | 0 | 6 | `a glowing brand-mark shaped like an eye stamped onto dark skin, cold white-amber as the single accent color, near-black background, macro framing` |
| `divine_unyielding` | 不屈 | 1 | 6 | `a figure kneeling but not fallen, pale light holding it upright, cold white as the single accent color, absolute black background, side view` |
| `pact_blood` | 血契 | 0 | 6 | `a contract written in dark blood, one line burning with cold white light as the single accent color, near-black background, macro framing` |
| `pact_war` | 战神契约 | 2 | 6 | `a war banner burning with cold white flame, edges consumed but not falling, cold white as the single accent color, absolute black background, centered` |

### 诅咒（暗红黑框 ⚠️ 深色主体要提亮）

| id | 名称 | t | r | 主体短语 |
|---|---|---|---|---|
| `curse_decay` | 衰朽 | 1 | 7 | `a hand crumbling into grey ash from the fingertips inward, dull sickly green-grey as the single accent color, near-black background, macro framing` |
| `curse_doubt` | 疑惧 | 1 | 7 | `a mirrored surface reflecting nothing, cracks spreading across it, dull violet-grey as the single accent color, near-black background, centered` |
| `curse_pain` | 痛苦 | 1 | 7 | `a twisted thorned iron chain coiling tightly around nothing, barbs slick with dark blood, deep crimson as the single accent color, near-black background, oppressive claustrophobic framing` |

---

## 七、P2-1 · 普通敌人立绘（46 张）

**类型与用途**：敌人立绘 · 尺寸 **1024×1536** · `transparent`
**已接线**：文件名用**敌人 id**。
**拼接方式**：`共用基底 + 明度基调 + A 类专属基底 + 下面的主体短语`

> **建议分批**：先做各线第一幕（13 张，出现最多），再做第二、三幕。
> 敌人立绘是"玩家一直在看"的东西，但对"完成度感知"的影响低于卡图与背景。

### 战士线 · 第一幕（竞技场，7 张）

| id | 名称 | 主体短语 |
|---|---|---|
| `act1_combat` | 竞技场新兵 | `a nervous young arena recruit in mismatched leather armor, a short sword held too tightly, front facing, full body` |
| `act1_gladiator` | 角斗士 | `a lean scarred gladiator in a single shoulder guard, a net and trident, front facing, full body` |
| `act1_shieldman` | 持盾角斗士 | `a stocky fighter behind a tall rectangular arena shield, a short blade at the hip, front facing, full body` |
| `act1_poisoner` | 毒刃客 | `a hooded figure with vials of green liquid strapped across the chest, a curved poisoned dagger, front facing, full body` |
| `act1_beast` | 斗兽 | `a massive chained arena beast, matted fur and broken tusks, hunched forward, front facing, full body` |
| `act1_champion` | 卫冕冠军 | `a decorated arena champion in gilded bronze plate, laurel marks on the pauldrons, a long blade resting on the shoulder, front facing, full body` |
| `act1_javelin` | 标枪手 | `a light skirmisher with a bundle of javelins, one already cocked back to throw, front facing, full body` |

### 战士线 · 第二幕（战场，7 张）

| id | 名称 | 主体短语 |
|---|---|---|
| `act2_combat` | 沙漠游荡者 | `a wiry desert drifter in wrapped cloth and sand goggles, a curved short blade, front facing, full body` |
| `act2_archer` | 弩手 | `a crossbowman in light desert armor, weapon raised and loaded, front facing, full body` |
| `act2_standard` | 掌旗官 | `a standard bearer holding a tall tattered war banner, unarmored torso, front facing, full body` |
| `act2_poisoner` | 蝎毒祭司 | `a masked desert priest with a scorpion motif, vials and a barbed staff, front facing, full body` |
| `act2_cavalry` | 铁骑 | `a heavy cavalryman in lamellar armor on foot, a long lance held low, front facing, full body` |
| `act2_shieldwall` | 盾墙兵 | `an infantryman behind a full-body tower shield, only the helmet visible above the rim, front facing, full body` |
| `act2_war_drum` | 战鼓手 | `a drummer carrying a large war drum on the hip, a single mallet raised, front facing, full body` |

### 战士线 · 第三幕（古战场，8 张）

| id | 名称 | 主体短语 |
|---|---|---|
| `act3_combat` | 神域守卫 | `an animated suit of divine armor, hollow inside, faint light in the visor, front facing, full body` |
| `act3_wraith` | 不灭亡魂 | `a tattered floating wraith with no legs, trailing spectral cloth, front facing, full body` |
| `act3_berserker` | 狂化遗骸 | `a skeletal warrior with cracked bone plates and rusted weapons in both hands, front facing, full body` |
| `act3_shieldbearer` | 遗骸盾卫 | `a skeletal guard behind a battered ancient shield, front facing, full body` |
| `act3_poisoner` | 腐毒残骸 | `a rotting corpse-warrior with green vapor seeping from the ribcage, front facing, full body` |
| `act3_revenant` | 复生者 | `a half-restored corpse in mismatched burial armor, one arm still bone, front facing, full body` |
| `act3_bone_lord` | 白骨领主 | `a tall skeletal noble in a decayed cape and a broken crown, front facing, full body` |
| `act3_mirror` | 镜影 | `a perfect mirrored duplicate of a warrior rendered in dark reflective glass, front facing, full body` |

### 法师线 · 第一幕（学徒白塔，4 张）

| id | 名称 | 主体短语 |
|---|---|---|
| `mage_act1_acolyte` | 白塔学徒 | `a young acolyte in a plain grey robe holding a small open tome, front facing, full body` |
| `mage_act1_construct` | 机关傀儡 | `a floating clockwork construct of brass rings and a single glass eye, front facing, full body` |
| `mage_act1_sentry` | 哨戒石像 | `a stone sentinel statue with carved geometric eyes, faint light in the seams, front facing, full body` |
| `mage_act1_shard` | 元素碎片 | `a small floating crystalline shard cluster with a core of light, front facing, full body` |

### 法师线 · 第二幕（元素裂隙，4 张）

| id | 名称 | 主体短语 |
|---|---|---|
| `mage_act2_wraith` | 裂隙游魂 | `a ghostly scholar in tattered robes, pages of light drifting around it, front facing, full body` |
| `mage_act2_devourer` | 魔力吞噬者 | `a bloated floating mass of devoured spell fragments, many small lights inside, front facing, full body` |
| `mage_act2_tide` | 潮汐使者 | `a robed figure standing in a rising column of pale water, front facing, full body` |
| `mage_act2_mirage` | 蜃楼 | `a shimmering half-real humanoid outline that keeps breaking apart, front facing, full body` |

### 法师线 · 第三幕（万法归墟，4 张）

| id | 名称 | 主体短语 |
|---|---|---|
| `mage_act3_arbiter` | 因果裁定者 | `a faceless robed arbiter holding a set of scales made of light, front facing, full body` |
| `mage_act3_echo` | 归墟回声 | `a blurred repeating silhouette of the same figure overlapping itself, front facing, full body` |
| `mage_act3_voice` | 初言之影 | `a figure made entirely of concentric sound-rings, no solid body, front facing, full body` |
| `mage_act3_warden` | 归墟看守 | `a heavy robed guardian with a blank mask and a staff planted in the ground, front facing, full body` |

### 猎人线 · 第一幕（翠林猎场，4 张）

| id | 名称 | 主体短语 |
|---|---|---|
| `hunter_act1_wolf` | 野狼 | `a lean grey forest wolf in a low stalking stance, front facing, full body` |
| `hunter_act1_boar` | 獠牙野猪 | `a bristling wild boar with long curved tusks, head lowered, front facing, full body` |
| `hunter_act1_spider` | 丛林蛛 | `a large dark forest spider with pale markings, legs spread wide, front facing, full body` |
| `hunter_act1_fox` | 赤狐 | `a slender red fox mid-pounce, tail trailing, front facing, full body` |

### 猎人线 · 第二幕（大荒野，4 张）

| id | 名称 | 主体短语 |
|---|---|---|
| `hunter_act2_stalker` | 荒野潜行者 | `a low crouched beast-form hunter wrapped in hide, face hidden, front facing, full body` |
| `hunter_act2_viper` | 荒原毒蝰 | `a thick desert viper reared up with hood spread, front facing, full body` |
| `hunter_act2_bull` | 铁角蛮牛 | `a massive shaggy bull with iron-banded horns, head down and charging, front facing, full body` |
| `hunter_act2_vulture` | 秃鹫 | `a hunched giant vulture with ragged wings half-spread, front facing, full body` |

### 猎人线 · 第三幕（万兽冢，4 张）

| id | 名称 | 主体短语 |
|---|---|---|
| `hunter_act3_ancestor` | 万兽之祖 | `a colossal spectral beast skull wreathed in mist, far larger than life, front facing, full body` |
| `hunter_act3_reborn` | 轮回之影 | `a beast silhouette that keeps shifting between species, edges unstable, front facing, full body` |
| `hunter_act3_instinct` | 本能化身 | `a beast-form made of pure instinct rendered as raw muscle and motion, no distinct species, front facing, full body` |
| `hunter_act3_ghost` | 兽魂 | `a translucent spirit-beast with faint glowing eyes, mist at the paws, front facing, full body` |

---

## 八、P2-2 · 遗物图标（44 个）

**类型与用途**：遗物图标（HUD / 结算 / 商店）· 尺寸 **256×256** · `transparent`
**⚠️ 未接线**：当前遗物在 UI 里只有**名字文字**，没有图标。需先加接线代码。
**拼接方式**：`共用基底 + 明度基调 + D 类专属基底 + 下面的主体短语 + 卡图负向词`

> 遗物图标显示尺寸约 **24–32px**，必须极简。

### 普通遗物（category 0，22 个 — 可掉落池）

| id | 名称 | 主体短语 |
|---|---|---|
| `burning_blood` | 燃烧之血 | `a single drop of glowing red blood, bold flat silhouette, dull crimson as the single accent color` |
| `vajra` | 金刚杵 | `a short double-ended ritual club, bold flat silhouette, cold steel-blue as the single accent color` |
| `anchor_chain` | 锚链 | `a short length of heavy chain with a broken link, bold flat silhouette, cold steel-blue as the single accent color` |
| `blood_vial` | 血瓶 | `a small stoppered vial of red liquid, bold flat silhouette, dull crimson as the single accent color` |
| `lantern` | 提灯 | `a small hooded lantern with a single flame, bold flat silhouette, warm amber as the single accent color` |
| `thorn_ring` | 荆棘指环 | `a plain ring wound with thorns, bold flat silhouette, cold blue-white as the single accent color` |
| `smooth_stone` | 光滑石 | `a single smooth river pebble, bold flat silhouette, cold cyan as the single accent color` |
| `lucky_coin` | 幸运币 | `a single worn coin seen face-on, bold flat silhouette, amber as the single accent color` |
| `paper_frog` | 纸蛙 | `a small folded paper frog, bold flat silhouette, pale green as the single accent color` |
| `war_banner` | 战旗 | `a tattered pennant on a short pole, bold flat silhouette, dull crimson as the single accent color` |
| `iron_boots` | 铁靴 | `a single plated boot seen from the side, bold flat silhouette, cold steel-blue as the single accent color` |
| `lucky_dice` | 幸运骰 | `two small dice showing high faces, bold flat silhouette, amber as the single accent color` |
| `herb_pouch` | 药囊 | `a small tied leather pouch with leaves, bold flat silhouette, warm green as the single accent color` |
| `stone_heart` | 石心 | `a rough stone carved into a heart shape, bold flat silhouette, cold blue-grey as the single accent color` |
| `iron_lung` | 铁肺 | `a simple pair of riveted metal bellows, bold flat silhouette, cold steel-blue as the single accent color` |
| `executioner_edge` | 处刑之刃 | `a broad heavy axe head, bold flat silhouette, dull crimson as the single accent color` |
| `bloodthirst_ring` | 嗜血指环 | `a ring with a single dark red gem, bold flat silhouette, dull crimson as the single accent color` |
| `iron_will` | 铁意志 | `a small riveted iron shield with a single crack, bold flat silhouette, cold steel-blue as the single accent color` |
| `crimson_lens` | 赤红透镜 | `a round lens with a red tinted glass, bold flat silhouette, dull crimson as the single accent color` |
| `swift_gloves` | 迅捷手套 | `a single light leather glove, bold flat silhouette, amber as the single accent color` |
| `golden_idol` | 金像 | `a small abstract figurine on a base, bold flat silhouette, amber as the single accent color` |
| `rest_totem` | 休憩图腾 | `a small carved totem with a simple face, bold flat silhouette, warm green as the single accent color` |

### 神格遗物（category 1，4 个 — 窃权事件专用）

| id | 名称 | 主体短语 |
|---|---|---|
| `god_war_emblem` | 战神徽记 | `a crossed-swords emblem inside a ring, bold flat silhouette, gold-white as the single accent color` |
| `god_arcane_orb` | 法神宝珠 | `a smooth floating orb with an inner ring of runes, bold flat silhouette, cold cyan as the single accent color` |
| `god_death_crown` | 死神冠冕 | `a jagged spiked crown, bold flat silhouette, pale violet as the single accent color` |
| `god_hunt_sigil` | 猎神印记 | `a stylized eye-and-claw sigil, bold flat silhouette, warm green as the single accent color` |

### 职业遗物（category 2，18 个 — 转职专属）

| id | 名称 | 主体短语 |
|---|---|---|
| `job_berserker_chain` | 狂战的骨链 | `a chain of small carved bone links, bold flat silhouette, dull crimson as the single accent color` |
| `job_bloodthirster_fang` | 嗜血者的獠牙 | `a single long curved fang, bold flat silhouette, dull crimson as the single accent color` |
| `job_momentum_banner` | 鏖战者的战旗 | `a narrow battle pennant with a blade motif, bold flat silhouette, amber as the single accent color` |
| `job_shield_guard_bracer` | 盾卫的护腕 | `a single plated forearm bracer, bold flat silhouette, cold steel-blue as the single accent color` |
| `job_shield_bash_spur` | 盾猛的撞角 | `a spiked shield boss seen frontally, bold flat silhouette, cold steel-blue as the single accent color` |
| `job_bastion_keystone` | 壁垒的基石 | `a single carved arch keystone, bold flat silhouette, cold blue-grey as the single accent color` |
| `job_arcanist` | 奥术师的笔记 | `a closed notebook with a rune on the cover, bold flat silhouette, cold cyan as the single accent color` |
| `job_archmage` | 秘法的水晶 | `a tall faceted crystal, bold flat silhouette, cold violet as the single accent color` |
| `job_chronomancer` | 时序的沙漏 | `a simple hourglass, bold flat silhouette, cold white-blue as the single accent color` |
| `job_elementalist` | 元素使的指环 | `a ring set with four small gems, bold flat silhouette, cold cyan as the single accent color` |
| `job_pyromancer` | 烈焰的余烬 | `a single glowing ember on a dark base, bold flat silhouette, molten orange as the single accent color` |
| `job_cryomancer` | 冰霜的壁障 | `a small wall of ice crystal shards, bold flat silhouette, pale ice-blue as the single accent color` |
| `job_tamer` | 驯兽师的哨子 | `a small carved whistle, bold flat silhouette, warm green as the single accent color` |
| `job_beast_king` | 兽王的獠牙 | `two crossed beast fangs, bold flat silhouette, warm green as the single accent color` |
| `job_falconer` | 驯鹰者的护腕 | `a thick leather bracer with feather marks, bold flat silhouette, amber as the single accent color` |
| `job_ranger` | 游侠的箭袋 | `a small quiver with arrows showing, bold flat silhouette, warm green as the single accent color` |
| `job_tracker` | 追猎者的猎刀 | `a short curved skinning knife, bold flat silhouette, warm green as the single accent color` |
| `job_thorn` | 荆棘护符 | `a small amulet wound with thorns, bold flat silhouette, warm green as the single accent color` |

---

## 九、P2-3 · 药水图标（10 个）

**类型与用途**：药水图标（药水栏 / 商店）· 尺寸 **256×256** · `transparent`
**⚠️ 未接线**：当前药水槽显示**名字首字**（`potion_slot.gd:_draw`）。
显示直径 **30px**（`SLOT_SIZE = 30`），必须极简。
**拼接方式**：`共用基底 + 明度基调 + D 类专属基底 + 下面的主体短语 + 卡图负向词`

> 药水图标**统一用"瓶形"作为共同骨架**，靠**液体颜色 + 附加符号**区分——
> 这样在 30px 下仍能一眼分辨，同时保持一套感。

| id | 名称 | 主体短语 |
|---|---|---|
| `heal_potion` | 回复药水 | `a small round-bottomed flask of glowing red liquid, bold flat silhouette, dull crimson as the single accent color` |
| `block_potion` | 铁壁药水 | `a squat square-shouldered flask of grey-blue liquid, bold flat silhouette, cold steel-blue as the single accent color` |
| `strength_potion` | 力量药水 | `a small flask of dark red liquid with a clenched-fist mark on the glass, bold flat silhouette, dull crimson as the single accent color` |
| `draw_potion` | 抽牌药水 | `a tall narrow flask of pale blue liquid with a small card-shaped mark, bold flat silhouette, cold cyan as the single accent color` |
| `mana_spring` | 法力涌泉 | `a flask of bright cyan liquid overflowing at the neck, bold flat silhouette, cold cyan as the single accent color` |
| `explosive_potion` | 爆炸药水 | `a round flask of orange liquid with a visible fuse, bold flat silhouette, molten orange as the single accent color` |
| `forget_river` | 忘川水 | `a flask of clear liquid with a single dark ripple at the surface, bold flat silhouette, pale violet as the single accent color` |
| `god_blood` | 神血 | `an ornate flask of white-gold liquid with a halo mark, bold flat silhouette, gold-white as the single accent color` |
| `beast_draught` | 兽性药剂 | `a rough clay flask of murky green liquid with a claw mark, bold flat silhouette, sickly green as the single accent color` |
| `card_potion` | 攻击牌药水 | `a rectangular flask of amber liquid with a sword-shaped mark, bold flat silhouette, amber as the single accent color` |

---

## 十、P2-4 · 职业图标（18 个）

**类型与用途**：转职界面图标 · 尺寸 **256×256** · `transparent`
**⚠️ 未接线**：`JobChoicePanel` 当前只有名字与描述文字。
**拼接方式**：`共用基底 + 明度基调 + D 类专属基底 + 下面的主体短语 + 卡图负向词`

> 转职是叙事高光时刻（"选择一条要刻进灵魂的规则"），图标能显著提升仪式感。
> 但一局只见 2 次，所以排 P2。**神级镜像（`mirror_*`）可复用对应职业的图标**。

### 一阶（6 个）

| id | 名称 | 主体短语 |
|---|---|---|
| `warrior_berserker` | 狂战 | `a cracked skull with a blade driven through it, bold flat silhouette, dull crimson as the single accent color` |
| `warrior_shield_guard` | 盾卫 | `a tall shield with a vertical spine, bold flat silhouette, cold steel-blue as the single accent color` |
| `mage_arcanist` | 奥术师 | `an open book with a rune rising from the pages, bold flat silhouette, cold cyan as the single accent color` |
| `mage_elementalist` | 元素使 | `a four-pointed star made of four different elemental motes, bold flat silhouette, cold cyan as the single accent color` |
| `hunter_tamer` | 驯兽师 | `a beast paw print inside a ring, bold flat silhouette, warm green as the single accent color` |
| `hunter_tracker` | 追猎者 | `a single eye above a trail of small footprints, bold flat silhouette, warm green as the single accent color` |

### 终阶（12 个）

| id | 名称 | 主体短语 |
|---|---|---|
| `warrior_bloodthirster` | 嗜血者 | `a fanged maw dripping blood, bold flat silhouette, dull crimson as the single accent color` |
| `warrior_momentum` | 鏖战者 | `three overlapping blade arcs in sequence, bold flat silhouette, amber as the single accent color` |
| `warrior_bastion` | 壁垒 | `a crenellated fortress tower, bold flat silhouette, cold blue-grey as the single accent color` |
| `warrior_shield_bash` | 盾猛 | `a shield boss with radiating impact cracks, bold flat silhouette, cold steel-blue as the single accent color` |
| `mage_archmage` | 秘法 | `a crown of runes above a closed eye, bold flat silhouette, cold violet as the single accent color` |
| `mage_chronomancer` | 时序 | `an hourglass with a spiral of time threaded through it, bold flat silhouette, cold white-blue as the single accent color` |
| `mage_pyromancer` | 烈焰 | `a flame shaped like a rising serpent, bold flat silhouette, molten orange as the single accent color` |
| `mage_cryomancer` | 冰霜 | `a snowflake crystal with a blade at its center, bold flat silhouette, pale ice-blue as the single accent color` |
| `hunter_beast_king` | 兽王 | `a beast skull wearing a small crown, bold flat silhouette, warm green as the single accent color` |
| `hunter_falconer` | 驯鹰者 | `a stooping hawk silhouette with a jess trailing, bold flat silhouette, amber as the single accent color` |
| `hunter_ranger` | 游侠 | `a longbow with a single arrow nocked, bold flat silhouette, warm green as the single accent color` |
| `hunter_thorn` | 荆棘游侠 | `a coiled thorned vine around an arrow, bold flat silhouette, warm green as the single accent color` |

---

## 十一、P3 · 盟友立绘（4 张）

**类型与用途**：召唤兽立绘（猎人线友方单位）· 尺寸 **1024×1536** · `transparent`
**已接线**：文件名用**盟友 id**。
**为什么 P3**：只有猎人线会看到，且是小体型。

**拼接方式**：`共用基底 + 明度基调 + A 类专属基底 + 下面的主体短语`

| id | 名称 | 主体短语 |
|---|---|---|
| `wolf` | 灰狼 | `a lean grey wolf standing alert, head low, front facing, full body` |
| `bear` | 铁鬃熊 | `a massive brown bear with a thick mane of bristled fur, standing on all fours, front facing, full body` |
| `hawk` | 猎鹰 | `a sharp-eyed hunting hawk perched with wings folded, front facing, full body` |
| `serpent` | 毒牙蛇 | `a thick dark serpent coiled upward with head raised, front facing, full body` |

---

## 十二、执行顺序与批次建议

### 批次 1（P0，**建议立刻做**）

| 批次 | 内容 | 数量 | 预估 |
|---|---|---|---|
| 1a | 背景 6 张 | 6 | 先跑 1 张试水（`warrior_act2`），确认构图与地面线后再做其余 5 张 |
| 1b | 起手牌卡图 9 张 | 9 | **先跑 3 张试水**：`strike`（最常出现）/ `arcane_bolt`（中间档）/ `defend`（技能类） |
| 1c | 普通牌卡图 18 张 | 18 | 风格确认后批量 |

> **批次 1 完成后，玩家感知到的"完成度"提升最大**——
> 每场战斗的背景、每次抽到的牌，都从"几何色块"变成真正的美术。

### 批次 2（P1）

| 批次 | 内容 | 数量 | 前置 |
|---|---|---|---|
| 2a | Boss / 精英立绘 6 张 | 6 | 无（已接线） |
| 2b | 地图节点图标 8 个 | 8 | ⚠️ **需先加接线代码**（约 40 行） |
| 2c | 剩余卡图 78 张 | 78 | 无 |

### 批次 3（P2）

| 批次 | 内容 | 数量 | 前置 |
|---|---|---|---|
| 3a | 普通敌人立绘 46 张 | 46 | 无（已接线）；建议按幕分批 |
| 3b | 遗物图标 44 个 | 44 | ⚠️ 需接线 |
| 3c | 药水图标 10 个 | 10 | ⚠️ 需接线 |
| 3d | 职业图标 18 个 | 18 | ⚠️ 需接线 |

### 批次 4（P3）

| 批次 | 内容 | 数量 |
|---|---|---|
| 4a | 盟友立绘 4 张 | 4 |

### 关键决策点

> **在批次 2b 之前，必须先决定"要不要做图标类（D 类，共 80 个）"。**
>
> - 图标类**全部未接线**，需要先写约 120–160 行代码（地图 / 遗物 / 药水 / 职业各一处）。
> - 好处：**8 张地图图标就能覆盖整张地图 UI**，单张性价比全表最高。
> - 代价：接线 + 80 张图的产能。
>
> 建议：**先做批次 1 + 2a + 2c（全部已接线，零代码风险）**，
> 用实机效果判断"几何图形兜底"到底有多碍眼，再决定图标类投不投。

### 每批完成后

```bash
GODOT="<Godot 安装目录>/Godot_v4.6.2-stable_mono_win64/.../Godot_v4.6.2-stable_mono_win64_console.exe"
"$GODOT" --headless --import --path "<项目根目录>"        # 导入
bash tools/ci_check.sh                                     # 门禁（含明度测试 test_art_tone.gd）
"$GODOT" -s tools/shot_battle.gd --path "<项目根目录>" -- <角色> <幕> out.png   # 实机截图
```

> ⚠️ `shot_battle.gd` **不能加 `--headless`**，否则截出来是空图。
> ⚠️ **背景换图后必须重新量地面线比例**，补进 `BattleBackground.BACKGROUND_GROUND_RATIO`。
