class_name Player
extends Creature
## 玩家单位（阶段 1 薄切片版）
##
## 阶段 1 只有：每回合回满能量。
## 遗物 / 职业 / 身份能力都在阶段 2~4 接入，此处不预留。

const BASE_ENERGY_PER_TURN: int = 3

var max_energy: int = BASE_ENERGY_PER_TURN


func start_turn() -> void:
	super.start_turn()
	energy = max_energy
