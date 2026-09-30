class_name BattleManager
extends Node
## 战斗流程管理
##
## 阶段 2 起：所有伤害都走 [DamagePipeline]，本类只负责**回合流转与校验**，
## 不参与任何数值计算——数值全在管线里，这样 12 个终职才有唯一的挂载点。
##
## ⚠️ 本类仍是阶段 1 的结构（TurnFlow / IntentResolver 尚未拆分），
## 阶段 2 的 P1 任务会把它拆成 TurnFlow + IntentResolver。

enum Phase {
	PLAYER_TURN,
	ENEMY_TURN,
	BATTLE_OVER,
}

signal phase_changed(phase: Phase)
signal log_message(text: String)
signal battle_ended(player_won: bool)

const HAND_SIZE: int = 5

var player: Player
var enemies: Array[Enemy] = []
var deck: DeckManager
var phase: Phase = Phase.BATTLE_OVER
var turn_number: int = 0

var _rng: RandomNumberGenerator


## 开一场战斗。rng 可注入以保证测试可复现。
func start_battle(
	p_player: Player,
	p_enemies: Array[Enemy],
	starting_deck: Array[CardData],
	p_rng: RandomNumberGenerator = null
) -> void:
	player = p_player
	enemies = p_enemies
	_rng = p_rng if p_rng != null else RandomNumberGenerator.new()

	player.reset_for_battle()
	for enemy: Enemy in enemies:
		enemy.reset_for_battle()

	deck = DeckManager.new(_rng)
	deck.setup(starting_deck)

	turn_number = 0
	_log("═══ 战斗开始 ═══")
	_begin_player_turn()


# ── 玩家回合 ────────────────────────────────────────────────

func play_card(card: CardData, target: Creature = null) -> bool:
	if phase != Phase.PLAYER_TURN:
		_log("当前不是玩家回合，无法出牌")
		return false
	if not deck.hand.has(card):
		_log("该牌不在手牌中")
		return false
	if not player.can_afford(card.cost):
		_log("能量不足：「%s」需要 %d，剩余 %d" % [card.display_name, card.cost, player.energy])
		return false

	player.spend_energy(card.cost)
	deck.take_from_hand(card)
	_log("打出「%s」（剩余能量 %d）" % [card.display_name, player.energy])

	player.notify_card_played(card)

	match card.type:
		CardData.CardType.ATTACK:
			var victim: Creature = target if target != null else first_alive_enemy()
			if victim != null:
				_deal_damage(player, victim, card.damage)
		CardData.CardType.SKILL:
			if card.block > 0:
				var gained: int = player.gain_block(card.block, card)
				_log("  获得 %d 格挡（当前 %d）" % [gained, player.block])
		CardData.CardType.POWER:
			_log("  能力牌在阶段 2 暂未实现")

	if card.exhaust:
		deck.add_to_exhaust(card)
	else:
		deck.add_to_discard(card)

	_check_battle_end()
	return true


func end_player_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return

	player.on_turn_end()
	var discarded: int = deck.discard_hand()
	_log("玩家回合结束，弃掉手牌 %d 张" % discarded)

	phase = Phase.ENEMY_TURN
	phase_changed.emit(phase)
	_run_enemy_turn()


# ── 敌人回合 ────────────────────────────────────────────────

func _run_enemy_turn() -> void:
	_log("── 敌人回合 ──")
	for enemy: Enemy in enemies:
		if not enemy.is_alive():
			continue
		enemy.on_turn_start()
		if player.is_alive():
			_log("%s 发动攻击（%d）" % [enemy.display_name, enemy.attack_damage])
			_deal_damage(enemy, player, enemy.attack_damage)
		enemy.on_turn_end()
		if not player.is_alive():
			break

	if _check_battle_end():
		return
	_begin_player_turn()


func _begin_player_turn() -> void:
	turn_number += 1
	player.on_turn_start()
	var drawn: Array[CardData] = deck.draw(HAND_SIZE)

	phase = Phase.PLAYER_TURN
	phase_changed.emit(phase)
	_log("── 第 %d 回合 · 玩家 ──（能量 %d/%d）" % [turn_number, player.energy, player.max_energy])
	_log("抽到 %d 张：%s" % [drawn.size(), get_hand_names()])


# ── 结算 ────────────────────────────────────────────────────

func _deal_damage(source: Creature, target: Creature, amount: int, damage_type: int = DamageType.NORMAL) -> void:
	## 数值全部交给 DamagePipeline——本类只负责调用与记录
	var info: DamageInfo = target.take_damage(amount, source, damage_type)
	_log("  %s 受到 %d 伤害（格挡挡下 %d，损失 %d，生命 %d/%d）" % [
		target.display_name, info.output, info.blocked, info.hp_lost, target.hp, target.max_hp,
	])
	if not target.is_alive():
		_log("  ☠ %s 被击败" % target.display_name)
		if source != null:
			source.notify_kill(target)


func _check_battle_end() -> bool:
	if phase == Phase.BATTLE_OVER:
		return true
	if not player.is_alive():
		_finish_battle(false)
		return true
	if first_alive_enemy() == null:
		_finish_battle(true)
		return true
	return false


func _finish_battle(player_won: bool) -> void:
	phase = Phase.BATTLE_OVER
	phase_changed.emit(phase)
	_log("═══ %s ═══" % ("胜利" if player_won else "战败"))
	battle_ended.emit(player_won)


# ── 查询 ────────────────────────────────────────────────────

func is_over() -> bool:
	return phase == Phase.BATTLE_OVER


func first_alive_enemy() -> Enemy:
	for enemy: Enemy in enemies:
		if enemy.is_alive():
			return enemy
	return null


func get_hand_names() -> String:
	var names: PackedStringArray = PackedStringArray()
	for card: CardData in deck.hand:
		names.append(card.display_name)
	return "、".join(names)


func _log(text: String) -> void:
	log_message.emit(text)
