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

# ══ 开场配置 ════════════════════════════════════════════════

## 开场即拥有的常规 Power：{power_id: 层数}
@export var starting_powers: Dictionary = {}
## 开场即拥有的**身份能力** id（不可剥夺）。神战 P4 的战神用。
@export var identity_power_ids: Array[StringName] = []

## 神战 P4：开战时**模仿玩家的终职**，用它的神级镜像（P6-06）。
##
## ⚠️ 刻意做成一个布尔开关而不是写死"战神镜像壁垒"——
## 硬编码进 Boss 脚本的话，**每加一个终职就要改一次 Boss 代码**，
## 而且神只能模仿设计时想到的那几个职业。
@export var uses_player_mirror: bool = false

# ══ 第二形态（Boss 双姿态）══════════════════════════════════

## 血量降到该比例以下时切换到第二形态（0 表示没有第二形态）
@export_range(0.0, 1.0, 0.05) var phase2_hp_ratio: float = 0.0
## 第二形态的意图序列（为空则继续沿用第一形态的）
@export var phase2_intents: Array[IntentData] = []


func has_second_phase() -> bool:
	return phase2_hp_ratio > 0.0 and not phase2_intents.is_empty()

