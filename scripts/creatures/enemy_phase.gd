class_name EnemyPhase
extends Resource
## 敌人的一个形态（阶段 6 · P6-05 三神战四阶段）
##
## ## 为什么做成资源列表而不是 `phase2_*` 字段
## 双姿态用两个字段就够了，但神战要**四阶段**——
## 再往下加 `phase3_*` / `phase4_*` 会让 `EnemyData` 长成一坨，
## 而且每加一阶段都要改 `Enemy` 的代码。
## 列表化之后，`Enemy` 只有一段循环，加多少阶段都不用动。
##
## ## 阶段是**规则的递进**，不是数值的放大
## 「化身 → 代行者 → 真身 → 规则对撞」——每一阶段多一层机制，
## 玩家要重新理解这场战斗。纯粹把伤害调高只会让人觉得"这 Boss 血好厚"。

## 血量降到该比例（含）以下时进入本阶段。第一项一般是 1.0。
@export_range(0.0, 1.0, 0.05) var hp_ratio: float = 1.0

## 阶段名（UI 显示，如「化身」「代行者」）
@export var display_name: String = ""

## 变身提示（战斗日志里的一行）
@export var announce: String = ""

## 本阶段的意图序列（为空则沿用上一阶段的）
@export var intents: Array[IntentData] = []

## 进入本阶段时追加的身份能力（**不剥夺已有的**，只叠加）
@export var identity_power_ids: Array[StringName] = []

## 进入本阶段时追加的常规 Power：{power_id: 层数}
@export var starting_powers: Dictionary = {}

## 进入本阶段时**模仿玩家的终职**（P6-06 镜像）。
## 放在最后一阶段：神先用自己的招式，最后才说"我也会你的"。
@export var uses_player_mirror: bool = false


func _to_string() -> String:
	return "EnemyPhase(%s @%.0f%%)" % [display_name, hp_ratio * 100.0]
