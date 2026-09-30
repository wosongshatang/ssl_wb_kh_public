class_name TurnFlow
extends RefCounted
## 回合流转状态机
##
## **只负责「现在是第几回合、轮到谁」，不碰任何实体与数值。**
## BattleManager 订阅本类的信号来驱动实际行为。
##
## 为什么要拆出来：回合规则是最容易被后期需求反复改动的部分——
## 阶段 4 的 Boss 双姿态要额外回合、阶段 6 的神战 P4 要改变回合结构、
## 眩晕要跳过回合。把这些规则收在一个 100 行的类里，
## 比散落在 BattleManager 的流程代码里安全得多。

enum Phase {
	IDLE,
	PLAYER_TURN,
	ENEMY_TURN,
	BATTLE_OVER,
}

signal phase_changed(phase: Phase)
signal player_turn_started(turn_number: int)
signal player_turn_ended(turn_number: int)
signal enemy_turn_started(turn_number: int)
signal enemy_turn_ended(turn_number: int)
signal battle_finished(player_won: bool)

var phase: Phase = Phase.IDLE
var turn_number: int = 0


func begin() -> void:
	phase = Phase.IDLE
	turn_number = 0
	_begin_player_turn()


## 玩家宣布结束回合 → 进入敌人回合
func end_player_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return
	player_turn_ended.emit(turn_number)
	_set_phase(Phase.ENEMY_TURN)
	enemy_turn_started.emit(turn_number)


## 敌人全部行动完毕 → 回到玩家回合（回合数 +1）
func end_enemy_turn() -> void:
	if phase != Phase.ENEMY_TURN:
		return
	enemy_turn_ended.emit(turn_number)
	_begin_player_turn()


func finish(player_won: bool) -> void:
	if phase == Phase.BATTLE_OVER:
		return
	_set_phase(Phase.BATTLE_OVER)
	battle_finished.emit(player_won)


func is_over() -> bool:
	return phase == Phase.BATTLE_OVER


func is_player_turn() -> bool:
	return phase == Phase.PLAYER_TURN


func _begin_player_turn() -> void:
	turn_number += 1
	_set_phase(Phase.PLAYER_TURN)
	player_turn_started.emit(turn_number)


func _set_phase(next: Phase) -> void:
	phase = next
	phase_changed.emit(phase)
