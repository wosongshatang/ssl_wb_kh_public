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
}

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
			return "最大生命 +%d" % value
		_:
			return "什么也不会发生"
