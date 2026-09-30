class_name EnemyData
extends Resource
## 敌人配置（数据外置原则：数值一律在 .tres，代码只读不算）

@export var id: StringName = &""
@export var display_name: String = "敌人"
@export var max_hp: int = 20
## 意图序列，**循环取用**。留空则该敌人每回合什么都不做（便于构造测试假人）。
@export var intents: Array[IntentData] = []
@export var is_elite: bool = false
@export var is_boss: bool = false
## 所属幕（1/2/3），用于地图敌人池筛选
@export_range(1, 3, 1) var act: int = 1
