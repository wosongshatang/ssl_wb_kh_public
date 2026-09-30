class_name Player
extends Creature
## 玩家单位
##
## 目前只负责「每回合回满能量」。遗物 / 职业 / 身份能力在阶段 4~5 接入。

const BASE_ENERGY_PER_TURN: int = 3

var max_energy: int = BASE_ENERGY_PER_TURN


func on_turn_start() -> void:
	# 先跑基类（清格挡 → 分发 Power 钩子），再回满能量
	super.on_turn_start()
	energy = max_energy
