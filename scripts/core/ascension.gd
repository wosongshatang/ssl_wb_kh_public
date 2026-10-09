class_name Ascension
extends RefCounted
## 进阶模式（阶段 10）—— 通关后解锁的**累积式**难度递增
##
## ## 核心规则：高进阶**包含**所有低进阶
## 进阶 5 = 进阶 1+2+3+4 的全部效果，再加它自己那一条。
##
## 所以数据表里**只写"这一级多出来的东西"**，累加由 [method has] 负责。
## 如果把每级都写成"完整的 5 条效果"，改一条就要同步改后面所有级——
## 迟早有一级忘了改，而那种不一致**不会报错**，只会让某两级难度莫名其妙地一样。
##
## ## 为什么用 `effect_id` 而不是直接判等级
## 调用点写 `run.has_ascension(&"hidden_intents")` 而不是 `run.ascension >= 10`：
##   · 等级数字改了，调用点不用动
##   · 读代码时"这一行在管什么"是自明的
##   · 一条效果想挪到别的等级，只改这张表

## 最高进阶等级
const MAX_LEVEL: int = 10

# ── 数值常量（改这里 = 改平衡）──
# ⚠️ 必须定义在 LEVEL_EFFECTS **之前**——表里的文案引用了它们。

## 进阶 1：每场战斗的金币奖励扣减
const GOLD_PENALTY: int = 10
## 进阶 3：事件负面效果的倍率加成（0.5 = 负面效果 ×1.5）
const EVENT_PENALTY_BONUS: float = 0.50
## 进阶 2：战斗奖励里"高于白色"的稀有度权重乘数
const RARITY_WEIGHT_MULTIPLIER: float = 0.5
## 进阶 4 / 8 / 9：各类敌人生命的加成
const ELITE_HP_BONUS: float = 0.15
const COMMON_HP_BONUS: float = 0.12
const BOSS_HP_BONUS: float = 0.12
## 进阶 5：商店价格倍率加成
const SHOP_PRICE_BONUS: float = 0.25
## 进阶 6：初始最大生命扣减
const START_HP_PENALTY: int = 5
## 进阶 7：休息点回血比例的乘数（0.7 = 只回 70%）
const REST_HEAL_MULTIPLIER: float = 0.70
## 由上一条推导，仅用于文案。
##
## ⚠️ 它**已经是百分数**（30 = 30%），拼文案时**不要再乘 100**——
## 写成 `REST_HEAL_PENALTY * 100` 会显示成"−3000%"，
## 而这是个纯字符串问题，任何断言都测不出来，只有渲染一帧才看得见。
const REST_HEAL_PENALTY: int = int((1.0 - REST_HEAL_MULTIPLIER) * 100.0)

## 各级**新增**的效果。顺序即解锁顺序。
##
## ⚠️ **改这张表时要同步改 `tests/test_ascension.gd` 的累积性断言**——
## 那条测试按 `MAX_LEVEL` 遍历，表里的等级必须连续（1..MAX_LEVEL）。
const LEVEL_EFFECTS: Array[Dictionary] = [
	{
		"level": 1,
		"id": &"less_gold",
		"text": "战斗金币奖励 −%d" % GOLD_PENALTY,
	},
	{
		"level": 2,
		"id": &"worse_card_rarity",
		"text": "战斗卡牌奖励的稀有度下降",
	},
	{
		"level": 3,
		"id": &"harsher_events",
		"text": "事件的负面效果加重 %d%%" % int(EVENT_PENALTY_BONUS * 100.0),
	},
	{
		"level": 4,
		"id": &"tougher_elites",
		"text": "精英敌人生命 +%d%%" % int(ELITE_HP_BONUS * 100.0),
	},
	{
		"level": 5,
		"id": &"pricier_shop",
		"text": "商店价格 +%d%%" % int(SHOP_PRICE_BONUS * 100.0),
	},
	{
		"level": 6,
		"id": &"lower_start_hp",
		"text": "初始最大生命 −%d" % START_HP_PENALTY,
	},
	{
		"level": 7,
		"id": &"weaker_rest",
		"text": "休息点回血 −%d%%" % REST_HEAL_PENALTY,
	},
	{
		"level": 8,
		"id": &"tougher_commons",
		"text": "普通敌人生命 +%d%%" % int(COMMON_HP_BONUS * 100.0),
	},
	{
		"level": 9,
		"id": &"tougher_bosses",
		"text": "Boss 生命 +%d%%" % int(BOSS_HP_BONUS * 100.0),
	},
	{
		"level": 10,
		"id": &"hidden_intents",
		"text": "无法探知敌人意图",
	},
]


## 该等级是否**包含**某条效果（累积判定）。
##
## 这是本模块唯一的真相来源——所有调用点都走它，
## 不要在别处写 `level >= 4` 这种硬编码。
static func has(level: int, effect: StringName) -> bool:
	if level <= 0 or effect == &"":
		return false
	for entry: Dictionary in LEVEL_EFFECTS:
		if int(entry["level"]) <= level and StringName(entry["id"]) == effect:
			return true
	return false


## 该等级**新增**的那一条效果（0 级返回空串）
static func new_effect_id(level: int) -> StringName:
	for entry: Dictionary in LEVEL_EFFECTS:
		if int(entry["level"]) == level:
			return StringName(entry["id"])
	return &""


## 该等级新增效果的说明文字
static func new_effect_text(level: int) -> String:
	for entry: Dictionary in LEVEL_EFFECTS:
		if int(entry["level"]) == level:
			return str(entry["text"])
	return ""


## 该等级包含的**全部**效果说明（累积）
static func all_effect_texts(level: int) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in LEVEL_EFFECTS:
		if int(entry["level"]) <= level:
			out.append(str(entry["text"]))
	return out


## 等级是否合法（用于 UI 与读档校验）
static func is_valid_level(level: int) -> bool:
	return level >= 0 and level <= MAX_LEVEL


## 等级显示名（"进阶 0" = 无进阶）
static func level_name(level: int) -> String:
	return "进阶 %d" % level


# ══ 数值换算 ════════════════════════════════════════════════
#
# 这些函数是**纯函数**，也是进阶数值的**唯一来源**。
#
# ## 为什么不写在各自的调用点
# 两个理由，第二个更重要：
#   1. 调用点（BattleScene / MapScene）是场景根脚本，没有 class_name，
#      测试里只能靠 `Variant` 动态派发去调它们——一调就触发
#      "类型从 Variant 推断" 的警告，而本项目**把警告当错误**。
#   2. 数值散在各处时，"这条效果到底改了哪个数"要满仓库找；
#      收在这里之后，改平衡只需要看这一个文件。

## 进阶 4 / 8 / 9：敌人生命加成倍率。
##
## 判定用 `is_elite` / `is_boss` 而不是节点类型：
## 节点类型只说明"这一格是精英房"，真正的敌人身份在数据里。
static func enemy_hp_bonus(level: int, is_elite: bool, is_boss: bool) -> float:
	if is_boss:
		return BOSS_HP_BONUS if has(level, &"tougher_bosses") else 0.0
	if is_elite:
		return ELITE_HP_BONUS if has(level, &"tougher_elites") else 0.0
	return COMMON_HP_BONUS if has(level, &"tougher_commons") else 0.0


## 进阶 4 / 8 / 9：返回**提升过生命的副本**（无加成时原样返回）。
##
## ⚠️⚠️ 这里是"必须复制"的**唯一落点**，放在 Ascension 里而不是场景里，
## 就是为了让这条约束能被直接测到。
##
## 为什么必须复制：`ContentRegistry.get_enemy()` 返回**缓存里的共享实例**。
## 直接改它的 `max_hp` 会把加成**写回缓存** → 下一场再乘一次 → 无限增长，
## 而且**不报任何错**（与本项目 max_hp 遗物踩过的坑同源）。
static func scale_enemy_hp(data: EnemyData, level: int) -> EnemyData:
	var bonus: float = enemy_hp_bonus(level, data.is_elite, data.is_boss)
	if bonus <= 0.0:
		return data
	var copy: EnemyData = data.duplicate() as EnemyData
	copy.max_hp = maxi(1, int(round(float(data.max_hp) * (1.0 + bonus))))
	return copy


## 进阶 1：战斗金币奖励扣减。
##
## 钳在 0（不是负数）——负金币会让"打完反而欠钱"，商店逻辑也没处理过负值。
static func gold_reward(level: int, base: int) -> int:
	if not has(level, &"less_gold"):
		return base
	return maxi(0, base - GOLD_PENALTY)


## 进阶 7：休息点回血比例的乘数（未解锁时 1.0 = 不打折）
static func rest_heal_multiplier(level: int) -> float:
	return REST_HEAL_MULTIPLIER if has(level, &"weaker_rest") else 1.0


## 进阶 5：商店价格倍率（未解锁时 1.0 = 原价）
static func shop_price_markup(level: int) -> float:
	return 1.0 + SHOP_PRICE_BONUS if has(level, &"pricier_shop") else 1.0


## 进阶 2：战斗奖励里"高于白色"的稀有度权重乘数（未解锁时 1.0）
static func rarity_weight_multiplier(level: int) -> float:
	return RARITY_WEIGHT_MULTIPLIER if has(level, &"worse_card_rarity") else 1.0


## 进阶 3：事件负面效果的倍率（未解锁时 1.0）
##
## 只给倍率，**由调用点决定"哪些效果算负面"**——
## 因为那个判断需要 `EventData.Effect`，而 `core/` 不该依赖 `map/`。
static func event_penalty_multiplier(level: int) -> float:
	return 1.0 + EVENT_PENALTY_BONUS if has(level, &"harsher_events") else 1.0
