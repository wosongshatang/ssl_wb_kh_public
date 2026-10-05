class_name AllyData
extends Resource
## 友方单位配置（猎人线的召唤兽）
##
## 与 [EnemyData] 分开：盟友没有意图序列、没有形态、没有掉落。
## 共用一份配置会让两边都长出一堆用不到的字段。

@export var id: StringName = &""
@export var display_name: String = "召唤兽"
@export var max_hp: int = 10
## 每回合结束时自动攻击的伤害
@export_range(0, 30, 1) var attack: int = 4
## 嘲讽：敌人优先攻击它
@export var is_taunt: bool = false
## 开场自带的能力：{power_id: 层数}
@export var starting_powers: Dictionary = {}


func _to_string() -> String:
	return "AllyData(%s %d血 %d攻)" % [display_name, max_hp, attack]
