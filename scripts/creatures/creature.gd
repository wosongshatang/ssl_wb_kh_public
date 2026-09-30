class_name Creature
extends Node
## 战斗单位基类（阶段 1 薄切片版）
##
## ⚠️ 阶段 1 的代码是**一次性的**（设计文档 §11）：只追求「能跑」，不沉淀架构。
## 阶段 2 会在此基础上重构出 powers / identity_powers / allies / relics，
## 因此本类只做**最小必要**实现，不预设未来的数据结构。
##
## 格挡清除时序（重要，见 docs/decisions.md 待决事项 Q1）：
## 采用 STS 标准——格挡在**自身回合开始时**清除（start_turn → clear_block）。
## 这样玩家回合获得的格挡能撑过敌人回合，在敌人打完后才失效。
## 设计文档 §3.1 把壁垒的改写点写在 on_turn_end，与此表述不一致，
## 阶段 2 建 Power 系统时定案；阶段 4 做壁垒前必须解决。

signal health_changed(current: int, maximum: int)
signal block_changed(current: int)
## 实际获得格挡时触发（盾猛挂这里，阶段 4）
signal block_gained(amount: int)
## 实际失去生命时触发（嗜血者挂这里，阶段 4）
signal health_lost(amount: int)
signal died

@export var display_name: String = "单位"
@export var max_hp: int = 10

var hp: int = 0
var block: int = 0
var energy: int = 0
var is_dead: bool = false


## 战斗开始时调用：把战斗内状态重置到初始值
func reset_for_battle() -> void:
	hp = max_hp
	block = 0
	energy = 0
	is_dead = false
	health_changed.emit(hp, max_hp)
	block_changed.emit(block)


## 进场景树即完成初始化，避免 hp 停留在 0 导致 is_alive() 误判为死亡。
## 测试里不挂树，需显式调用 reset_for_battle()。
func _ready() -> void:
	reset_for_battle()


func is_alive() -> bool:
	return not is_dead and hp > 0


# ── 格挡 ────────────────────────────────────────────────────

func gain_block(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	block += amount
	block_changed.emit(block)
	block_gained.emit(amount)


func clear_block() -> void:
	if block == 0:
		return
	block = 0
	block_changed.emit(block)


# ── 伤害 / 治疗 ──────────────────────────────────────────────
# ⚠️ 阶段 1 简化版：只有格挡吸收，没有修正链。
# 阶段 2 会被 pipeline/DamagePipeline 替换（力量 / 虚弱 / 易伤 / 印记 / 姿态）。

func take_damage(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return

	var absorbed: int = mini(block, amount)
	var to_hp: int = amount - absorbed

	if absorbed > 0:
		block -= absorbed
		block_changed.emit(block)

	if to_hp > 0:
		hp = maxi(0, hp - to_hp)
		health_lost.emit(to_hp)
		health_changed.emit(hp, max_hp)

	if hp <= 0:
		is_dead = true
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	var before: int = hp
	hp = mini(max_hp, hp + amount)
	if hp != before:
		health_changed.emit(hp, max_hp)


# ── 能量 ────────────────────────────────────────────────────

func can_afford(cost: int) -> bool:
	return energy >= cost


func spend_energy(cost: int) -> bool:
	if not can_afford(cost):
		return false
	energy -= cost
	return true


func gain_energy(amount: int) -> void:
	energy = maxi(0, energy + amount)


# ── 回合钩子（阶段 2 会扩展成完整的钩子总线）────────────────

func start_turn() -> void:
	clear_block()


func end_turn() -> void:
	pass
