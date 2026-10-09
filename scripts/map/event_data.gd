class_name EventData
extends Resource
## 事件数据
##
## 阶段 3 采用**两个固定选项**的结构——足够跑通事件节点，且 `.tres` 手写好读。
## 阶段 6 若需要「三选项 + 条件解锁」，再泛化成 `Array[EventOption]`。
##
## 数据外置原则：事件文本与效果数值一律在 `.tres`，代码只读不算。

enum Effect {
	NONE,             ## 什么也不会发生
	HEAL,             ## 回复生命
	DAMAGE,           ## 失去生命
	GOLD,             ## 金币增减（负数为失去）
	ADD_RANDOM_CARD,  ## 获得一张随机卡牌
	REMOVE_CARD,      ## 移除牌组中一张牌（进删牌页）
	MAX_HP,           ## 最大生命增加
	ADD_POTION,       ## 获得一瓶随机药水（药水栏满则失败）
	ADD_DIVINE_CARD,  ## 获得一张**对应神明**的无色卡（同时增加神性）
	ADD_CURSE_CARD,   ## 获得一张随机诅咒卡（纯负面）
	ADD_RELIC,        ## 获得一件普通遗物
	ADD_DIVINE_RELIC, ## 获得一件**神格遗物**（窃权事件专用，同时增加神性）
	ADD_SPECIAL_CARD, ## 获得一张**特殊牌**（神化/契约/神谕/考题，P6-12）
	## ⚠️ **新增枚举值一律追加在末尾**。
	## 插在中间会让所有已存盘的 .tres 整数值集体错位——
	## 而 .tres 里存的是数字，不是符号，错了不会报错，只会静默变成别的东西。
}

## 事件涉及的属性（无色卡事件据此只给对应神明的卡）
@export var deity_id: StringName = &""

@export var id: StringName = &""
@export var title: String = "事件"
@export var description: String = ""

@export_group("选项 A")
@export var option_a_label: String = ""
@export var option_a_effect: Effect = Effect.NONE
@export var option_a_value: int = 0

@export_group("选项 B")
@export var option_b_label: String = ""
@export var option_b_effect: Effect = Effect.NONE
@export var option_b_value: int = 0


## 把效果翻译成给玩家看的文字。**必须与 MapScene 里的实际结算保持一致**——
## 玩家看到「回复 10 点生命」就必须真的回 10 点，这类撕裂最伤信任。
static func effect_text(effect: Effect, value: int) -> String:
	match effect:
		Effect.HEAL:
			return "回复 %d 点生命" % value
		Effect.DAMAGE:
			return "失去 %d 点生命" % value
		Effect.GOLD:
			if value >= 0:
				return "获得 %d 金币" % value
			return "失去 %d 金币" % absi(value)
		Effect.ADD_RANDOM_CARD:
			return "获得一张随机卡牌"
		Effect.REMOVE_CARD:
			return "移除牌组中一张牌"
		Effect.MAX_HP:
			# ⚠️ 负数（如「血誓」的 −6 最大生命）是**合法设计**。
			# 写成 `"最大生命 +%d" % value` 会显示"最大生命 +-6"。
			if value >= 0:
				return "最大生命 +%d" % value
			return "最大生命 −%d" % absi(value)
		Effect.ADD_POTION:
			return "获得一瓶随机药水"
		Effect.ADD_DIVINE_CARD:
			return "获得一张神明的无色卡（同时增加神性）"
		Effect.ADD_CURSE_CARD:
			return "获得一张诅咒卡（无法打出、无法升级）"
		Effect.ADD_SPECIAL_CARD:
			return "获得一张特殊牌（神化 / 契约 / 神谕 / 考题）"
		Effect.ADD_RELIC:
			return "获得一件遗物"
		Effect.ADD_DIVINE_RELIC:
			return "窃取一件神格遗物（强力，但会大幅增加神性）"
		_:
			return "什么也不会发生"


## 进阶 3：把事件的**负面**数值按倍率放大。
##
## ## 为什么放在这里（而不是 Ascension 或 MapScene）
##   · 放 `Ascension` → `core/` 要依赖 `map/` 的 `EventData.Effect`，方向反了
##   · 放 `MapScene`  → 那是场景根脚本（无 `class_name`），测试只能靠
##     `Variant` 动态派发去调，而本项目**把"类型从 Variant 推断"的警告当错误**
##   · 放这里 → 与 [method effect_text] 相邻，"哪些效果算负面"和
##     "这些效果怎么描述"在同一处，改一个不容易忘了另一个
##
## ## 只放大"确定是坏事"的方向
## | 效果 | 什么时候算负面 |
## |---|---|
## | `DAMAGE` | `value > 0`（正数 = 扣血） |
## | `GOLD` | `value < 0`（负数 = 扣钱） |
## | `MAX_HP` | `value < 0`（负数 = 削上限） |
## | `ADD_CURSE_CARD` | 恒负面（`value` = 张数，0 视作 1） |
##
## 其余一律原样返回。特别是：
##   · `HEAL` / `GOLD > 0` / `ADD_*` 是**奖励**——放大它们等于让进阶变成福利
##   · `REMOVE_CARD` **不缩放**：删牌在多数构筑里是**好事**（精简牌组），
##     把它当负面放大反而会帮玩家；而且它随机删，"一次删 2 张"会变成
##     纯赌博而不是决策
static func ascend_value(effect: Effect, value: int, multiplier: float) -> int:
	if multiplier <= 1.0:
		return value
	match effect:
		Effect.DAMAGE:
			if value <= 0:
				return value
			return int(ceil(float(value) * multiplier))
		Effect.GOLD:
			if value >= 0:
				return value
			return -int(ceil(float(-value) * multiplier))
		Effect.MAX_HP:
			if value >= 0:
				return value
			return -int(ceil(float(-value) * multiplier))
		Effect.ADD_CURSE_CARD:
			# 老数据里 value 是 0（视作 1 张）→ 先抬到 1 再放大，
			# 否则 0 乘任何数都是 0，这条进阶对老事件完全失效。
			return int(ceil(float(maxi(1, value)) * multiplier))
		_:
			return value
