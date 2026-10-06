# 卡图提示词（阶段 8）

> **配套**：
> - **`docs/art_style_base.md`** —— **唯一权威基底**（通用风格 + **明度基调** + 三种资产）
> - `assets/cards/README.md`（接线约定）
> - `docs/project_core_info.md` §4.3-A
>
> ⚠️ **本文件的基底已并入 `art_style_base.md`**。
> 生成时请以那份为准——**尤其是 §三的明度基调，不要漏**，
> 否则卡图会偏亮，被 `tests/test_art_tone.gd` 拦下来。

---

## 一、⚠️ 卡图 ≠ 立绘：三个必须改的地方

立绘那套提示词**不能直接复用**。卡图有三个硬约束：

| | 立绘 | **卡图** |
|---|---|---|
| **画幅** | 2:3 竖（1024×1536） | **1:1 方（1024×1024）** |
| **主体** | 人物全身、正对镜头 | **物件 / 瞬间 / 场景，通常没有人** |
| **观看尺寸** | 168×128（够大） | **约 104×113 —— 只有立绘的 1/3 面积** |

**第三条是决定性的。** 104×113 大约是一枚邮票。凡是靠"细节丰富"取胜的构图，
缩到卡面上都会糊成一坨灰。**卡图必须靠"一个大主体 + 强对比"活着。**

所以立绘基底里的 `character portrait, full body, facing viewer, transparent background`
**全部要换掉**，改成卡图专用的那套（见下）。

---

## 二、基底（**完整版见 `docs/art_style_base.md`**）

> 下面是卡图相关的部分，方便单文件阅读。
> **权威版本以 `art_style_base.md` 为准**——那里还有明度基调的完整说明与目标值。

### 正向基底

```
dark fantasy card game art, painterly digital illustration, muted desaturated palette
with one strong accent color, dramatic side lighting, subtle rim light, single dominant
focal subject, high contrast against the background, simple bold composition, readable
when scaled down to 104x113 pixels, centered with generous negative space, no text,
no watermark, no border, no frame, opaque dark background,
low-key lighting, predominantly dark values, held-down highlights, deep shadows,
overcast dim sky, no blown-out highlights, no sun glare, no bright reflective surfaces
```

> **最后一行是明度基调**（2026-10-06 加入）。**不要删**——
> 删了卡图会偏亮，`tests/test_art_tone.gd` 会拦。

### 负向基底

```
text, letters, numbers, watermark, signature, card frame, border, UI elements,
multiple subjects, cluttered background, busy detail, tiny details, depth of field,
bright saturated colors, anime, chibi, cute, cartoon, blurry, low contrast,
high-key lighting, bright daylight, sun glare, blown-out sky, overexposed, washed-out
```

### 相对立绘基底，改了什么、为什么

| 改动 | 原因 |
|---|---|
| `full body` → **`single dominant focal subject`** | 全身人物缩到 104px 只剩一根火柴棍 |
| `transparent background` → **`opaque dark background`** | 卡图是"窗"，有背景才立得住；透明物件贴在深色卡面上会发飘 |
| 加 **`readable when scaled down to 104x113 pixels`** | 直接把"小尺寸可读"写进提示词，是最有效的一句 |
| 加 **`simple bold composition` / `generous negative space`** | 留白 = 小尺寸下的可读性 |
| 负向加 **`busy detail` / `tiny details` / `depth of field`** | 虚化和碎细节在小图上都是噪声 |

### 两条从立绘继承的有效约束（已验证）

沿用立绘那条经验——**在正面词里追加具体约束能显著提升可控性**：

- **`as the single accent color`** —— 明确强调色**只有一处**，防止颜色扩散
- **`centered with generous negative space`** —— 防止主体撑满画面（下面安全区会再讲）

---

## 三、安全区：出图时四周要留边

接线用的是 `STRETCH_KEEP_ASPECT_COVERED`（等比铺满后裁切）。

图区 104×113 比正方形**略高**，所以方形卡图会**左右各被裁掉约 4%**：

```
出图 1024×1024  →  显示时缩到 113×113  →  左右各裁 ~4.5px  →  可见 104×113
```

**构图要求：主体（含所有"必须看见"的部分）收在中央 90% 以内。**
边缘只放背景、雾、光晕这类"裁掉也不影响"的东西。

> 立绘那次踩过这个坑：战士的阔剑尖端外伸，裁切后差点出框。
> 卡图面积更小，**同样的错误代价更大**。

---

## 四、示例提示词（20 张，覆盖三种类型 × 三条角色线）

> 每条都可**直接拼接在基底之后**使用。
> 中文是给你看的说明，**实际只传英文部分**。

### 通用起手牌（出现频率最高，优先做）

**1. `strike` 打击**（攻击 · 初始）
```
a single worn iron sword blade slicing diagonally through the frame, a thin trail of
pale steel-blue light as the single accent color, dark storm-grey void background,
dramatic side lighting, no character visible
```

**2. `defend` 防御**（技能 · 初始）
```
a battered round wooden shield raised at a slight angle, chipped paint and dented iron
rim, a faint warm amber glow along the rim as the single accent color, dark slate
background, centered, symmetrical
```

### 战士线

**3. `bash` 重击**（攻击 · 普通）
```
a heavy iron mace head smashing downward into cracked stone, shards and dust flying
outward, dull ember-orange sparks as the single accent color, dark grey dust background
```

**4. `iron_wave` 铁斩波**（攻击 · 普通）
```
a crescent-shaped shockwave of pale steel light sweeping across the frame, iron filings
suspended in the air, cold white-blue as the single accent color, near-black background
```

**5. `whirl` 回旋斩**（攻击 · 稀有）
```
a circular blur of a spinning blade tracing one full arc of motion, cold steel-white as
the single accent color, dark background with faint dust motes, dynamic circular motion
```

**6. `impervious` 铜墙铁壁**（技能 · 罕见）
```
a wall of overlapping iron tower shields locked together, rivets and deep dents, a faint
bronze glow seeping between the seams as the single accent color, dark background,
symmetrical frontal composition
```

**7. `inflame` 燃烧**（能力 · 普通）
```
a warrior's fist clenched and wreathed in rising orange flame, embers drifting upward,
molten orange as the single accent color, near-black background, centered
```

**8. `meteor` 陨石**（攻击 · 稀有）
```
a burning meteor streaking down through dark clouds, trailing fire and broken rock,
fierce orange-red as the single accent color, stormy near-black sky, dramatic diagonal
composition
```

### 法师线

**9. `arcane_bolt` 奥术弹**（攻击 · 普通）
```
a condensed sphere of arcane energy with a comet tail, fragments of geometric runes
orbiting it, cold cyan-violet as the single accent color, dark indigo void background,
centered
```

**10. `ice_shard` 冰锥**（攻击 · 普通）
```
a jagged spear of translucent ice thrusting forward, frost crystals forming along its
length, pale glacier-blue as the single accent color, dark navy background
```

**11. `frost_armor` 寒霜护甲**（技能 · 罕见）
```
a torso-shaped shell of layered frost and ice plates, breath fog curling at the edges,
pale ice-blue as the single accent color, dark background, symmetrical frontal
```

**12. `singularity` 万象归墟**（攻击 · 史诗）
```
a collapsing black sphere devouring streaks of light that spiral inward, a thin violet
accretion ring as the single accent color, absolute black void background, centered,
sense of immense gravity
```

### 猎人线

**13. `hunter_shot` 射击**（攻击 · 初始）
```
a single arrow in mid-flight, fletching blurred with speed, a faint amber trail as the
single accent color, dark forest-green void background, horizontal centered composition
```

**14. `poison_arrow` 毒箭**（攻击 · 罕见）
```
a close-up of an arrowhead dripping viscous green venom, one bead of poison falling,
sickly acid-green as the single accent color, dark murky background, macro framing
```

**15. `call_wolf` 唤狼**（技能 · 普通）
```
the translucent spirit-form of a wolf emerging from a swirl of pale mist, eyes glowing,
cold spectral blue as the single accent color, dark background, centered
```

**16. `volley` 箭雨**（攻击 · 稀有）
```
a dense volley of arrows arcing down through the frame from the upper left, thin motion
lines, cold white-amber as the single accent color, dark sky background, diagonal
composition
```

### 高稀有度（用来定"天花板"标准）

**17. `godslayer_blow` 弑神一击**（攻击 · 史诗）
```
a colossal blade of condensed golden light driving upward through a shattered divine
halo, fragments of broken gold raining down, radiant gold as the single accent color,
absolute black background, low angle, epic scale
```

**18. `curse_pain` 痛苦**（诅咒 · 黑）
```
a twisted thorned iron chain coiling tightly around nothing, barbs slick with dark
blood, deep crimson as the single accent color, near-black background, oppressive
claustrophobic framing
```

**19. `divine_might` 神威**（攻击 · 无色）
```
a giant ethereal hand descending from above, palm open, radiating pale authority,
blinding white-gold as the single accent color, pitch black background, low angle
```

**20. `apotheosis_grand` 大神化**（能力 · 无色）
```
a humanoid figure dissolving upward into a pillar of white light, human features
breaking apart into luminous fragments, pure white-gold as the single accent color,
absolute black background, centered, ascending
```

---

## 五、三种卡类型的视觉语言（做新卡时按这个推）

卡面**不显示类型文字**，但玩家要一眼分得出"这是攻击还是防御"。靠画面语汇：

| 类型 | 数量 | 视觉语汇 | 避免 |
|---|---|---|---|
| **攻击** | 43 | 刀刃 / 冲击 / 弹道 / 命中瞬间。**画面有"方向性"** | 静态正面摆放 |
| **技能** | 49 | 盾 / 架势 / 护罩 / 光环。**画面"对称、正面、收拢"** | 任何指向外部的尖锐形状 |
| **能力** | 7 | 持续性的气场 / 符印 / 蜕变。**画面"由内向外发光"** | 一次性动作的瞬间感 |

**能力牌只有 7 张**（`charge_up` / `footwork` / `inflame` / `hunters_focus` /
`pact_war` / `gold_rage_frenzy` / `gold_tame_roar`），可以单独精修。

---

## 六、稀有度与卡框配色（避免撞色）

卡框边框颜色由稀有度决定（`ui_palette.gd:33`）。**强调色最好避开同色系**，
否则主体会和边框糊在一起：

| 稀有度 | 卡框色 | 建议 |
|---|---|---|
| 初始 STARTER | 灰 `#85878F` | 任意 |
| 普通 COMMON | 白 `#E0E3EB` | 任意 |
| 罕见 UNCOMMON | 绿 `#6BC77A` | ⚠️ 避开绿色主体 |
| 稀有 RARE | 蓝 `#5C99F0` | ⚠️ 避开蓝色主体 |
| 史诗 EPIC | 紫 `#B875EB` | ⚠️ 避开紫色主体 |
| **金 GOLD** | 金 `#F5C74D` | ⚠️ **避开金色主体**（最容易撞） |
| **无色 COLORLESS** | 近白 `#E0EDFA` | ⚠️ 避开纯白主体 |
| **诅咒 CURSE** | 暗红黑 `#52333D` | 深色主体要提亮，否则看不出 |

> **金色牌最容易翻车**：金框 + 金色主体 = 主体被框"吃掉"。
> 金卡建议用**冷色或暗色主体**，让金色只做边缘光。

---

## 七、生成参数

```
size       = 1024x1024      ← 方形，不是立绘的 1024x1536
quality    = high
background = opaque         ← 不是 transparent
```

调用方式：把「正向基底 + 卡图专属词 + 负向基底」拼成一段传入。

> ⚠️ 生成会消耗额度（每张约 5–10 点）。**建议先跑 3 张试水**：
> `strike`（最常出现）/ `arcane_bolt`（中间档）/ `godslayer_blow`（天花板），
> 覆盖三档。确认风格后再批量。

---

## 八、验收清单（图回来之后逐条过）

缩到 104×113 看一眼，逐条打勾：

- [ ] **缩小后可读**——把图缩到 104px 宽，还认得出主体是什么吗？（最重要）
- [ ] **主体在中央 90% 内**——左右边缘裁掉 4% 后，主体完整吗？
- [ ] **无文字 / 水印 / 边框**——AI 很容易在角落加签名
- [ ] **强调色唯一**——是不是只有一处用强调色？有没有扩散到背景？
- [ ] **不与卡框撞色**——对照上表，主体颜色和边框颜色分得开吗？
- [ ] **背景够暗**——卡面整体是深色，卡图太亮会喧宾夺主

**六条里最该在意第一条。** 前五条不合格还能修，第一条不合格等于白做。

---

## 九、接线与落地

1. 出图命名成**卡牌 id**：`strike.png`、`arcane_bolt.png`……
2. 丢进 `assets/cards/`（**不用改任何 `.tres`**）
3. 跑一次导入：
   ```bash
   GODOT="***REMOVED***/Godot_v4.6.2-stable_mono_win64/.../Godot_v4.6.2-stable_mono_win64_console.exe"
   "$GODOT" --headless --import --path "***REMOVED***"
   ```
4. 启动游戏看一眼手牌

**可以分批做**：没图的卡继续用几何图形（攻击=斜刃 / 技能=盾牌 / 能力=菱形），
**有图无图并存不冲突**——所以先做 20 张常用的，其余慢慢补。

**升级牌共用基础卡的图**：`strike+` 会自动用 `strike.png`，**不用另出图**。
