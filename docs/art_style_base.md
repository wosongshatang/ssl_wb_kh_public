# 《弑神律》美术基底（唯一权威版）

> 所有 AI 生成的美术资产都从这份基底出发。
> 卡图专属示例见 `docs/art_prompts_cards.md`；本文件是**共用的那一层**。

---

## 一、三段式流程

```
① 通用基底（每次生成必须原样前置）
        ↓
② 明度基调（本文件 §三，已并入基底，不要删）
        ↓
③ 资产专属描述（立绘 / 卡图 / 环境，§五）
        ↓
④ 生成后程序化校验（§六，可测、可拦）
```

**为什么必须前置**：AI 对"风格"没有记忆。每张图单独描述会漂移。
把风格**和明度**都写成固定前缀，是让一批图看起来像一套的最省力手段。

---

## 二、通用风格基底

```
dark fantasy card game art, painterly digital illustration,
muted desaturated palette with one strong accent color,
dramatic side lighting, subtle rim light, clean silhouette,
no text, no watermark, no border, no frame
```

---

## 三、★ 明度基调（**必须并入每一次生成**）

### 3.1 为什么明度要写进基底

「背景太亮、角色看不清」是**肉眼能感觉到、但每次都要重新吵一遍**的问题。
把它写死进基底，就不必每次靠"感觉"调：

- **对生成侧**：明度是**可描述**的——`low-key lighting` / `held-down highlights`
  这类词确实能压低整体明度，**只要写具体，不要只写 `dark`**
- **对验收侧**：明度是**可测量**的——Rec.709 加权平均亮度，
  项目里已有 `tests/test_art_tone.gd` 自动拦（§六）

**只写 `dark` 是不够的**。实测：`dark fantasy` 这类词只影响"风格感"，
不影响实际亮度分布。必须写**光照方式**和**高光处理**。

### 3.2 明度基调词（**追加到通用基底之后**）

```
low-key lighting, predominantly dark values, held-down highlights,
deep shadows, overcast dim sky, no blown-out highlights, no sun glare,
no bright reflective surfaces
```

### 3.3 负向词追加

```
high-key lighting, bright daylight, sun glare, blown-out sky, overexposed,
washed-out, pale bright surfaces, harsh specular highlights
```

### 3.4 目标值（写死，不再靠感觉）

Rec.709 加权平均亮度，只统计 **alpha ≥ 200** 的实体像素：

```
L̄ = Σ(0.2126·R + 0.7152·G + 0.0722·B) / N      （0–255 标度）
```

**分两档**——这是刻意设计，不是含糊：

- **理想区**：达标线。超出只提示（⚠️），**不判失败**
- **硬上限**：不可突破（❌），突破必拦

**为什么不用单一区间**：单一区间会让"可接受但非最优"的图把门禁刷成噪音。
**门禁一旦误报，人就会干脆关掉它——比没有门禁更糟（D17）。**

| 层次 | 理想区 | 硬上限 | 当前实测 |
|---|---|---|---|
| **环境 / 背景** | **35 – 48** | 30 – 55 | 43.1 – 52.3 |
| **角色 / 主体** | **42 – 70** | 36 – 75 | 39.8 – 69.9（均值 51.3） |
| **卡图** | **22 – 40** | 18 – 48 | 待接入 |
| **强调色 / 高光** | 局部 120 – 200 | — | 面积占比 **< 5%**（硬性） |

**四条层次规则**

1. **硬规则：环境 L̄ < 角色 L̄** —— 背景不得整体亮于角色
2. **理想：环境 L̄ ≤ 角色 L̄ × 0.85** —— 15% 暗差是"角色明显浮起"的舒适区
3. **高光只归强调色** —— 全图 >160 的亮部面积必须 < 5%
4. **暗部与中间调占 ≥ 70%** —— 0–96 区间应是全图主体

### 3.5 已登记的折中

落在理想区外、硬上限内，**经确认保留**。新增折中必须登记，否则视为未达标。

| 资产 | L̄ | 原因 |
|---|---|---|
| 沙地竞技场 | 52.3 | 沙地 + 落日天空天然高亮；压到理想区需累计系数 0.58（低于 0.70 舒适线），经确认保留 |

> ⚠️ **法师那张是"亮度异常点"**（69.9，比另两张高 60%）——法袍是灰白色。
> 他是把角色均值拉高的那个。若觉得"阈值太松"，先看是不是他在撑门面。

### 3.6 明度压不下来怎么办

**不要靠后处理硬压。** 压暗系数低于 ~0.70 会显脏（暗部糊成一坨）。

正确顺序：

1. **首选重生成**——把 §3.2 的基调词原样加上，并**避免高亮题材**
   （烈日、雪原、明黄沙地、大面积反光水面）
2. 次选**本地压暗**——累计系数还在 0.70 以上时可以压
3. 实在不行**换构图**——把亮部挪出角色所在的区域

> **实例（反面教材）**：竞技场初版 L̄ 75.3。
> 压到理想区需要累计系数 0.58，**已经低于 0.70 舒适线**——
> 这说明正确做法是**第一次就重生成**，而不是压两次。

---

## 四、环境 / 背景的构图约定（**不是明度，但同样必须写死**）

明度解决"看不看得清"，构图解决"站不站得住"。

```
the lower half is flat walkable ground, the horizon line sits slightly above
the middle of the frame, no foreground objects blocking the center
```

### 4.1 为什么是"下半部"而不是"下三分之一"

角色站在**屏幕 48% 高度**（`battle_scene.gd` 的 `ACTOR_Y_RATIO = 0.56` 算出来）。
地面若只占下三分之一，地面线就会落在**角色脚底以下**——
角色看起来**浮在半空**。

**实测**：元素裂隙那张的地面只占底部 26%（地面线在图高 74% 处），
接进来后法师明显悬空。代码里靠放大 1.52× 硬裁才对齐，
**画面变糊，且 `BattleBackground` 会打警告**。

> 教训：**构图问题在生成时修，不要留到接入时裁**。

### 4.2 地面线要落在哪

| | 值 |
|---|---|
| 角色脚底 | 视口 **48%** 处 |
| 地面线上限 | **44%**（`BattleBackground.GROUND_LINE_MAX`） |

地面线必须**高于**脚底，角色才像"站在场景里"而不是"站在地平线上"。

---

## 五、三种资产专属基底

> 三种**不能混用**：画幅、主体、背景都不同。

### 5.1 角色立绘

```
character portrait, full body, centered, facing viewer,
transparent background
```

参数：`size=1024x1536`（竖）、`background=transparent`、`quality=high`

补充约束（**已验证有效**）：
```
arms held slightly away from the torso so the silhouette reads clearly
weapon kept close and within the body silhouette
```

### 5.2 卡图

```
single dominant focal subject, high contrast against the background,
simple bold composition, readable when scaled down to 104x113 pixels,
centered with generous negative space, opaque dark background
```

参数：`size=1024x1024`（**方**）、`background=opaque`、`quality=high`

完整示例见 `docs/art_prompts_cards.md`。

### 5.3 环境 / 背景

```
environment concept art, wide establishing shot, no characters,
fully opaque painted background, no transparency
```

+ **§四的构图约定**

参数：`size=1536x1024`（横）、`background=opaque`、`quality=high`

负向额外加：`characters, people, figures, creatures`

> ⚠️ 环境图**绝对不能**沿用立绘基底的 `transparent background`——
> 模型会靠"把天空挖空"来同时满足两条矛盾指令，结果上半部分全透明。

---

## 六、生成后校验（把"感觉"变成"数字"）

### 6.1 项目内自动拦（每次提交都跑）

`tests/test_art_tone.gd` —— 直接测**已入库**的美术：

| 断言 | 级别 | 拦什么 |
|---|---|---|
| 背景 L̄ 在硬上限 30–55 内 | ❌ 失败 | 接了张整体过亮/过暗的背景 |
| 角色 L̄ 在硬上限 36–75 内 | ❌ 失败 | 立绘本身过曝/过暗 |
| 背景 L̄ < 角色均值 | ❌ 失败 | 角色会沉进背景（折中项豁免） |
| 折中项必须写明原因 | ❌ 失败 | 防止把折中当免死金牌 |
| 折中项仍不得破硬上限 | ❌ 失败 | 同上 |
| 非折中背景互相差 ≤ 20% | ❌ 失败 | 某一幕"突然亮起来" |
| 偏离理想区的项 | ⚠️ **只打印** | 可接受但非最优，**不拦** |

**已注入故障验证过会红**：把竞技场换回压暗前版本 → 立刻失败并报出具体数值。

> ⚠️ **理想区不判失败是刻意的**（D17：门禁误报比没有门禁更糟）。
> 想知道"离理想区还有多远"，看 GUT 输出里的 `⚠️` 行。

### 6.2 生成时手工校验（出图后立刻跑）

用技能里的脚本（`card-game-art-asset-pipeline/scripts/verify_art.py`）：

```bash
PY="<managed python venv>/python.exe"

# 尺寸 + 透明通道
"$PY" scripts/verify_art.py alpha <目录或文件...>

# 判「背景是否比角色暗」
"$PY" scripts/verify_art.py luma --char <角色图...> --env <环境图...>

# 按目标亮度压暗（系数低于 0.7 就别压了，该重生成）
"$PY" scripts/verify_art.py darken --char <角色图...> --env <环境图...> --out <目录>
```

### 6.3 肉眼那一关不能省

数字只保证"亮度和构图不出错"，**不保证"好看"**。
出图后仍要缩到实际尺寸看一眼——尤其卡图（缩到 104px）。

---

## 七、接入流程

| 资产 | 放哪 | 命名 |
|---|---|---|
| 立绘 | `assets/portraits/` | `<单位id>.png` |
| 卡图 | `assets/cards/` | `<卡id>.png` |
| 背景 | `assets/backgrounds/` | `<角色>_act<幕>.png` |

**丢进去就生效**，不用改任何 `.tres`（见 D36）。
但**背景图必须补一行地面线比例**：
`BattleBackground.BACKGROUND_GROUND_RATIO`（换图后要重新量）。

接入后：

```bash
GODOT="***REMOVED***/Godot_v4.6.2-stable_mono_win64/.../Godot_v4.6.2-stable_mono_win64_console.exe"
"$GODOT" --headless --import --path "***REMOVED***"     # 导入
bash tools/ci_check.sh                                  # 门禁（含明度测试）
"$GODOT" -s tools/shot_battle.gd --path "***REMOVED***" -- <角色> <幕> out.png   # 实机截图
```

> ⚠️ `shot_battle.gd` **不能加 `--headless`**，否则截出来是空图。
