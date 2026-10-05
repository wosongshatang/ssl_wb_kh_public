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

# ══ 形态序列（P6-05 三神战四阶段）═══════════════════════════

## 形态列表，**按 hp_ratio 从高到低**排列。
##
## 空列表 = 单一形态（普通敌人）。
## 一阶 Boss 用 2~3 项，神战用 4 项（化身 → 代行者 → 真身 → 规则对撞）。
##
## ⚠️ 用列表而不是 `phase2_*` / `phase3_*` 字段：
## 字段式每加一阶段就要改 `Enemy` 的代码，列表式只需要补一行数据。
@export var phases: Array[EnemyPhase] = []


func has_phases() -> bool:
	return not phases.is_empty()


## 按当前血量比例，算出应该处于第几个形态（下标）
func phase_index_for(hp_ratio: float) -> int:
	var index: int = 0
	for i: int in phases.size():
		if hp_ratio <= phases[i].hp_ratio:
			index = i
	return index


func phase_count() -> int:
	return phases.size()

