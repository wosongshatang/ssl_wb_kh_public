class_name AbstractRelic
extends RefCounted
## 遗物基类 —— 掉在人间的权柄碎片（设计文档 §1.3）
##
## ## 职责分离（`card-game-numerical-framework` 的核心原则）
## **遗物管触发，Power 管数值。**
## 推荐模式：遗物负责计数与触发，通过 `apply_power` 施加临时 Power，由 Power 做数值修正。
## 直接改数值（[method at_damage_modify]）只用于「无条件、无状态」的简单效果。
##
## 为什么不把遗物做成 Power：遗物的生命周期是**整局**，Power 是**单场战斗**。
## 混在一起会让「战斗结束清 Power」顺手把遗物也清掉。

var id: StringName = &""
var display_name: String = ""
var description: String = ""
## 持有者，由 Creature.add_relic 注入
var owner_creature: Creature = null


func at_battle_start(_owner: Creature) -> void:
	pass


func on_battle_end(_owner: Creature, _won: bool) -> void:
	pass


func on_turn_start(_owner: Creature) -> void:
	pass


func on_turn_end(_owner: Creature) -> void:
	pass


func on_use_card(_owner: Creature, _card: CardData) -> void:
	pass


## 修正链第 ② 步：**最先介入**，因此会被后续的力量/虚弱/易伤放大。
## 想让效果不被放大，就改用「施加 Power」模式。
func at_damage_modify(value: float, _info: DamageInfo) -> float:
	return value


func _to_string() -> String:
	return "[遗物]%s" % display_name
