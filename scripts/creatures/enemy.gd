class_name Enemy
extends Creature
## 敌人单位（阶段 1 薄切片版）
##
## 阶段 1：固定意图——每回合固定攻击固定伤害，纯数值。
## 阶段 2 换成数据驱动的 IntentResolver（意图独立于行为，用 .tres 配图标与数值）。

@export var attack_damage: int = 6


## 阶段 1 的「意图」：本回合会做什么。阶段 2 由 IntentResolver 取代。
func get_intent_damage() -> int:
	return attack_damage
