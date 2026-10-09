# 《弑神律》美术资源生成清单（统一生成与接入用）

> **本文件是"要生成什么、用什么生成、怎么接入"的唯一入口。**
> 资源内容与提示词见 `docs/art_asset_requirements.md`（247 项总表）；
> 本文件负责**把已完成的划掉、把待做的按可执行批次排好**。
>
> 生成日期：2026-10-08 ｜ 依据：`data/` + `assets/` 实际清点

---

## 〇、当前进度总览

| 类别 | 总量 | 已入库 | **待做** | 接线状态 | 目录 |
|---|---|---|---|---|---|
| 背景 | 9 | **9** ✅ | **0** | ✅ | `assets/backgrounds/` |
| 角色立绘 | 3 | **3** ✅ | **0** | ✅ | `assets/portraits/` |
| Boss / 精英立绘 | 6 | **6** ✅ | **0** | ✅ | `assets/portraits/` |
| 卡图 | 105 | 27 | **78** | ✅ | `assets/cards/` |
| 普通敌人立绘 | 46 | 0 | **46** | ✅ | `assets/portraits/` |
| 盟友立绘 | 4 | 0 | **4** | ✅ | `assets/portraits/` |
| 地图节点图标 | 8 | 0 | **8** | ✅ | `assets/icons/map/` |
| 遗物图标 | 44 | 0 | **44** | ✅ | `assets/icons/relics/` |
| 药水图标 | 10 | 0 | **10** | ✅ | `assets/icons/potions/` |
| 职业图标 | 18 | 0 | **18** | ✅ | `assets/icons/jobs/` |
| **合计** | **253** | **45** | **208** | — | — |

> **★ 接线已全部完成（v6.00）** —— 剩下的 **208 项全部是"丢进去就生效"**，
> 不需要再改任何代码。这是本清单最重要的前提。

---

## 一、待生成资源清单（按类别分组）

### 1.1 图标 80 张 —— **性价比最高，建议先做**

**为什么先做**：**8 张地图图标就能覆盖整张地图 UI**，单张视觉收益全表最高；
且图标是 256×256 的小图，生成成本远低于立绘与卡图。

**提示词**：`docs/art_asset_requirements.md` §五 / §八 / §九 / §十

#### map 地图节点（8 张）
```
combat  elite  rest  shop  event  boss  god_altar  traitor
```

#### relics 遗物（44 张）
```
anchor_chain  blood_vial  bloodthirst_ring  burning_blood  crimson_lens
executioner_edge  golden_idol  herb_pouch  iron_boots  iron_lung  iron_will
lantern  lucky_coin  lucky_dice  paper_frog  rest_totem  smooth_stone
stone_heart  swift_gloves  thorn_ring  vajra  war_banner
god_arcane_orb  god_death_crown  god_hunt_sigil  god_war_emblem
job_arcanist  job_archmage  job_bastion_keystone  job_beast_king
job_berserker_chain  job_bloodthirster_fang  job_chronomancer  job_cryomancer
job_elementalist  job_falconer  job_momentum_banner  job_pyromancer
job_ranger  job_shield_bash_spur  job_shield_guard_bracer  job_tamer
job_thorn  job_tracker
```

#### potions 药水（10 张）
```
beast_draught  block_potion  card_potion  draw_potion  explosive_potion
forget_river  god_blood  heal_potion  mana_spring  strength_potion
```

#### jobs 职业（18 张）
> ⚠️ `mirror_*`（神级镜像）**复用**对应职业的图标，**不单独出图**。

```
warrior_berserker  warrior_shield_guard  warrior_bloodthirster
warrior_momentum  warrior_bastion  warrior_shield_bash
mage_arcanist  mage_elementalist  mage_archmage  mage_chronomancer
mage_pyromancer  mage_cryomancer
hunter_tamer  hunter_tracker  hunter_beast_king  hunter_falconer
hunter_ranger  hunter_thorn
```

---

### 1.2 卡图 78 张

**提示词**：`docs/art_asset_requirements.md` §六（含每张的主体短语）
**已完成 27 张**：9 张初始牌 + 18 张普通牌（出现频率最高的一批）

#### warrior 战士线（10 张）
```
armor_break  divine_might  earthshaker  gather  godslayer_blow
heavy_blow  impervious  iron_bulwark  last_stand  whirl
```

#### mage 法师线（10 张）
```
arcane_nova  arcane_torrent  blink  charge_up  frost_armor
frost_prison  frozen_tomb  ignite  meteor  singularity
```

#### hunter 猎人线（9 张）
```
beast_stampede  call_bear  call_hawk  call_serpent  hunters_focus
hunters_volley  multi_shot  poison_arrow  volley
```

#### 通用 / 无色 / 诅咒（49 张）
```
bulwark_stance
apotheosis_grand  apotheosis_minor
divine_arcaneflux  divine_breakarmy  divine_deathwish  divine_huntmark
divine_unyielding  pact_blood  pact_war
oracle_eye  oracle_whisper  trial_frugal  trial_patience
curse_decay  curse_doubt  curse_pain
gold_alpha_howl  gold_alpha_pack  gold_arc_bolt  gold_arc_reserve
gold_arch_focus  gold_arch_surge  gold_bash_counter  gold_bash_shatter
gold_bastion_hold  gold_bastion_rampart  gold_blood_feast  gold_blood_ritual
gold_chrono_hasten  gold_chrono_rewind  gold_cryo_barrier  gold_cryo_frostbite
gold_elem_spark  gold_elem_veil  gold_guard_brace  gold_guard_bulwark
gold_momentum_flurry  gold_momentum_press  gold_pyro_ember  gold_pyro_immolate
gold_rage_frenzy  gold_rage_reckless  gold_ranger_aim  gold_ranger_step
gold_tame_bond  gold_tame_roar  gold_thorn_hide  gold_thorn_lash
```

> ⚠️ **金框牌（`gold_*`）最容易翻车**：金框 + 金色主体 = 主体被框吃掉。
> 金卡建议用**冷色或暗色主体**，让金色只做边缘光。

---

### 1.3 普通敌人立绘 46 张

**提示词**：`docs/art_asset_requirements.md` §七（含每张的主体短语）
**已完成 6 张**：3 Boss + 3 精英。**建议按幕分批**（第一幕出现最多）。

#### 战士线（22 张）
```
# 第一幕 · 竞技场
act1_combat  act1_gladiator  act1_shieldman  act1_poisoner
act1_beast  act1_champion  act1_javelin
# 第二幕 · 战场
act2_combat  act2_archer  act2_standard  act2_poisoner
act2_cavalry  act2_shieldwall  act2_war_drum
# 第三幕 · 古战场
act3_combat  act3_wraith  act3_berserker  act3_shieldbearer
act3_poisoner  act3_revenant  act3_bone_lord  act3_mirror
```

#### 法师线（12 张）
```
mage_act1_acolyte  mage_act1_construct  mage_act1_shard  mage_act1_sentry
mage_act2_wraith  mage_act2_devourer  mage_act2_tide  mage_act2_mirage
mage_act3_arbiter  mage_act3_echo  mage_act3_voice  mage_act3_warden
```

#### 猎人线（12 张）
```
hunter_act1_wolf  hunter_act1_boar  hunter_act1_spider  hunter_act1_fox
hunter_act2_stalker  hunter_act2_viper  hunter_act2_bull  hunter_act2_vulture
hunter_act3_ancestor  hunter_act3_reborn  hunter_act3_instinct  hunter_act3_ghost
```

---

### 1.4 盟友立绘 4 张

**提示词**：`docs/art_asset_requirements.md` §十一

```
wolf  bear  hawk  serpent
```

---

## 二、技能清单

### 2.1 主技能（**必读**）

| 技能 | 路径 | 用途 |
|---|---|---|
| **`card-game-art-asset-pipeline`** | `~/.workbuddy-ai/skills/card-game-art-asset-pipeline/` | **本管线的核心**：统一基底提示词（内置明度基调）+ 负向词 + 生成后程序化校验三段式。含 `scripts/verify_art.py` |
| ↳ `scripts/verify_art.py` | 同目录 | **四种校验**：`alpha`（尺寸/透明通道）、`luma`（明度基调）、`darken`（压暗兜底）、`preview`（缩到 104px 验收可读性） |

### 2.2 生图后端（按需选一）

| 技能 | 用途 | 备注 |
|---|---|---|
| **`nano-banana-pro`** | 文生图 + **图生图编辑** | 支持改图（如"把这张背景的地面抬高"） |
| **`openai-image-gen`** | **批量**生图 + 生成 `index.html` 画廊 | 适合大批量跑 |

> ⚠️ **无论用哪个后端，提示词都必须按 `card-game-art-asset-pipeline` 的基底拼接**——
> 后端只负责出图，风格一致性靠基底。

### 2.3 相关技能（接入阶段）

| 技能 | 用途 |
|---|---|
| `godot4-project-bootstrap` | Godot 4 项目地基（含 headless 四步校验脚本）。**接入时的导入/门禁流程参考** |

---

## 三、文档清单（按阅读顺序）

| 顺序 | 文档 | 作用 | 什么时候读 |
|---|---|---|---|
| 1 | **`docs/art_style_base.md`** | **唯一权威基底**：通用风格 + **明度基调** + 三类资产专属基底 + 构图约定 + 目标值 | **每次生成前必读** |
| 2 | **`docs/art_asset_requirements.md`** | **247 项总表**：按 P0–P3 排序，每项含主体短语（可直接拼接使用） | 找"这张图要画什么" |
| 3 | `docs/art_prompts_cards.md` | 卡图 **20 张完整示例** + 三种卡类型的视觉语言 + 安全区 + 验收清单 | 做卡图前读 |
| 4 | `docs/decisions.md` | **D1~D36 决策记录** | ⚠️ **接线前必搜**（见下方警告） |

### 各资产目录的约定文件（**自动生成，不会漂移**）

| 文件 | 内容 |
|---|---|
| `assets/icons/map/README.md` | 8 个地图图标的准确文件名 |
| `assets/icons/relics/README.md` | 44 个遗物图标的准确文件名 |
| `assets/icons/potions/README.md` | 10 个药水图标的准确文件名 |
| `assets/icons/jobs/README.md` | 18 个职业图标的准确文件名 |
| `assets/cards/README.md` | 卡图接线约定 |

### ⚠️⚠️ 一条必须遵守的纪律

> **接线（或生成前）先搜一遍 `decisions.md`。**
>
> 这个项目有多条"**不报错、只看起来不对**"的历史坑，典型是：
> - **D35**：`_draw()` 里画贴图**一律渲染成纯白**（与贴图大小无关）。
>   立绘、卡图、地图图标**都踩过**——最后一次是 2026-10-08 接线图标时**二次踩坑**，
>   因为没先查 `decisions.md`。
>
> 这类问题**单元测试和资源检查都发现不了**，只能"渲染一帧看一眼"。

---

## 四、工具与命令

### 4.1 生成后校验（**每批必跑**）

```bash
PY="C:/Users/Johnk/.workbuddy-ai/binaries/python/envs/default/Scripts/python.exe"
SK="C:/Users/Johnk/.workbuddy-ai/skills/card-game-art-asset-pipeline/scripts/verify_art.py"

"$PY" "$SK" alpha   <目录或文件...>                    # 尺寸 + 透明通道
"$PY" "$SK" luma    --char <角色...> --env <环境...>   # 明度基调（环境 vs 角色）
"$PY" "$SK" luma    --card <卡图...>                   # 卡图单独判定
"$PY" "$SK" preview --card <卡图...>                   # 缩到 104×113 验收可读性（卡图必跑）
```

### 4.2 接入流程

```bash
GODOT="***REMOVED***/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64_console.exe"

# 1) 导入（新增文件后必做）
"$GODOT" --headless --import --path "***REMOVED***"

# 2) 门禁六步（含明度测试 test_art_tone.gd）
bash tools/ci_check.sh

# 3) 实机截图 —— 战斗场景
"$GODOT" -s tools/shot_battle.gd --path "***REMOVED***" -- <角色> <幕> out.png
# 4) 实机截图 —— 地图（看图标）
"$GODOT" -s tools/shot_map.gd    --path "***REMOVED***" -- <角色> out.png
```

> ⚠️ `shot_battle.gd` / `shot_map.gd` **不能加 `--headless`**，否则截出来是空图。

### 4.3 校验脚本清单

| 工具 | 位置 | 作用 |
|---|---|---|
| `verify_art.py` | 技能目录 | 尺寸 / 透明通道 / 明度 / 压暗 / 可读性预览 |
| `tools/ci_check.sh` | 项目 | 六步门禁（导入 / 解析 / 结构 / 冒烟 / GUT / 分层铁律） |
| `tools/shot_battle.gd` | 项目 | 战斗场景截图（验背景地面线、立绘、卡图） |
| `tools/shot_map.gd` | 项目 | 地图截图（验节点图标） |

---

## 五、统一规范速查

### 5.1 四类资产的参数（**不能混用**）

| 类别 | 尺寸 | background | 专属基底关键词 |
|---|---|---|---|
| **A 立绘** | **1024×1536** | `transparent` | `character portrait, full body, centered, facing viewer` |
| **B 卡图** | **1024×1024** | `opaque` | `single dominant focal subject, readable when scaled down to 104x113 pixels` |
| **C 背景** | **1536×1024** | `opaque` | `environment concept art, wide establishing shot, no characters` |
| **D 图标** | **256×256** | `transparent` | `single simple symbol icon, bold flat silhouette, reads clearly at 32x32 pixels` |

### 5.2 每次都原样前置的两段（**一字不改**）

**共用基底**
```
dark fantasy card game art, painterly digital illustration, muted desaturated palette
with one strong accent color, dramatic side lighting, subtle rim light, clean silhouette,
no text, no watermark, no border, no frame
```

**明度基调**（追加在后面，**不要删**）
```
low-key lighting, predominantly dark values, held-down highlights, deep shadows,
overcast dim sky, no blown-out highlights, no sun glare, no bright reflective surfaces
```

### 5.3 明度目标（Rec.709，只统计 alpha ≥ 200 的实体像素）

| 层次 | 理想区（越界只警告 ⚠️） | 硬上限（突破必拦 ❌） |
|---|---|---|
| 环境 / 背景 | 35 – 48 | 30 – 55 |
| 角色 / 立绘 | 42 – 70 | 36 – 75 |
| 卡图 | 22 – 40 | 18 – 48 |
| 图标 | 25 – 55 | 18 – 65 |
| 强调色高光（>160）面积 | — | **< 5%**（硬性） |

**四条层次规则**：① 硬规则 **环境 L̄ < 角色 L̄**；② 理想 ≤ 角色 × 0.85；
③ 高光只归强调色且 < 5%；④ 暗部与中间调占 ≥ 70%。

### 5.4 命名 = 文件名 = 数据 id

**丢进对应目录即生效，不用改任何 `.tres`。** 文件名必须与上表列出的 id **完全一致**。

---

## 六、每批的标准流程（6 步）

```
1. 读基底          → docs/art_style_base.md §二/§三/§五
2. 拼提示词        → 共用基底 + 明度基调 + 类别专属基底 + 该资源的主体短语
                     （主体短语在 art_asset_requirements.md 对应章节）
3. 生成            → 每批 ≤ 4 张（见下方 ⚠️），生成后立刻记「时间戳 → 用途」
4. 校验            → verify_art.py alpha / luma / preview
5. 肉眼看          → 缩到实际尺寸看一眼（数字不保证"好看"）
6. 接入 + 门禁      → 按 id 命名丢进 assets/ → --import → ci_check.sh → 截图
```

### ⚠️ 生成时的三条硬纪律

1. **每批 ≤ 4 张，批后核对文件数。**
   生图工具按**秒级时间戳**命名文件 → 同秒完成的并行调用**静默互相覆盖**，
   且每条都返回"成功"。实测一批 10 张丢 3 张，靠"数文件个数对不上"才发现。
2. **调明度别大幅改词，会过冲。**
   材质词（`pale stone` vs `dark grey stone`）就是明度旋钮，能差 30+ 个 L̄。
   一次只改一处，落点选**区间中值**而非贴边。
3. **构图问题在生成时修，不要留到接入时裁。**
   地面占比不足 → 接入时要放大硬凑（超 1.25× 就打警告）。**正解是重生成**。

---

## 七、批次建议顺序

| 批次 | 内容 | 数量 | 理由 |
|---|---|---|---|
| **B1** | **地图节点图标** | 8 | **8 张覆盖整张地图 UI**，单张性价比全表最高 |
| **B2** | **职业图标 + 药水图标** | 28 | 小图、成本低，且都是"仪式感"场景 |
| **B3** | **遗物图标** | 44 | 补齐图标类（遗物面板 / 商店） |
| **B4** | **第一幕普通敌人立绘** | 13 | 出现频率最高的敌人；先做三条线 act1 |
| **B5** | **卡图 · 三条角色线** | 29 | 各线专属牌，构筑感最强 |
| **B6** | **卡图 · 金框牌** | 32 | ⚠️ 注意避开金色主体 |
| **B7** | **卡图 · 无色 / 诅咒 / 其他** | 17 | 出现频率最低 |
| **B8** | **第二、三幕普通敌人立绘** | 33 | 按幕推进 |
| **B9** | **盟友立绘** | 4 | 仅猎人线可见，收尾 |

> **也可以按"类别整体推进"**（先把 80 个图标一次做完再动立绘）——
> 同一类资产一次做完，风格最稳、校验最省事。

---

## 八、一句话总结

> **接线已 100% 完成，208 项资源全部"丢进去就生效"。**
>
> 现在唯一要做的就是：**按基底拼提示词 → 每批 ≤4 张 → 跑 verify_art 校验 →
> 按 id 命名丢进目录 → 跑门禁**。
>
> 卡住的时候先查 `docs/decisions.md`（尤其 D35）。
