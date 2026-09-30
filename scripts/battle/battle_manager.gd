class_name BattleManager
extends Node
## 战斗编排
##
## 职责边界（阶段 2 收尾后）：
##   - **拥有** player / enemies / deck
##   - **校验并执行**玩家出牌
##   - **响应** [TurnFlow] 的信号，执行各方回合行为
##
## 不再负责：回合状态（交给 [TurnFlow]）、数值计算（交给 [DamagePipeline]）、
## 敌人意图推进（交给 [IntentResolver]）。

signal log_message(text: String)
signal phase_changed(phase: TurnFlow.Phase)
signal battle_ended(player_won: bool)

const HAND_SIZE: int = 5

var player: Player
var enemies: Array[Enemy] = []
var deck: DeckManager
var flow: TurnFlow = TurnFlow.new()

var _rng: RandomNumberGenerator


## 回合状态透传（真正的状态在 TurnFlow 里，这里只做转发避免两处状态不一致）
var phase: TurnFlow.Phase:
	get:
		return flow.phase

var turn_number: int:
	get:
		return flow.turn_number


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

	flow = TurnFlow.new()
	flow.phase_changed.connect(_on_flow_phase_changed)
	flow.player_turn_started.connect(_on_player_turn_started)
	flow.player_turn_ended.connect(_on_player_turn_ended)
	flow.enemy_turn_started.connect(_on_enemy_turn_started)
	flow.battle_finished.connect(_on_battle_finished)

	_log("═══ 战斗开始 ═══")
	flow.begin()


# ── 玩家出牌 ────────────────────────────────────────────────

func play_card(card: CardData, target: Creature = null) -> bool:
	if not flow.is_player_turn():
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
	flow.end_player_turn()


# ── TurnFlow 信号处理 ───────────────────────────────────────

func _on_player_turn_started(turn: int) -> void:
	player.on_turn_start()
	var drawn: Array[CardData] = deck.draw(HAND_SIZE)
	_log("── 第 %d 回合 · 玩家 ──（能量 %d/%d）" % [turn, player.energy, player.max_energy])
	_log("抽到 %d 张：%s" % [drawn.size(), get_hand_names()])


func _on_player_turn_ended(_turn: int) -> void:
	player.on_turn_end()
	var discarded: int = deck.discard_hand()
	_log("玩家回合结束，弃掉手牌 %d 张" % discarded)


func _on_enemy_turn_started(_turn: int) -> void:
	_log("── 敌人回合 ──")
	for enemy: Enemy in enemies:
		if not enemy.is_alive():
			continue
		enemy.on_turn_start()
		if player.is_alive():
			_execute_intent(enemy)
		enemy.on_turn_end()
		if not player.is_alive():
			break

	if _check_battle_end():
		return
	flow.end_enemy_turn()


func _on_battle_finished(player_won: bool) -> void:
	_log("═══ %s ═══" % ("胜利" if player_won else "战败"))
	battle_ended.emit(player_won)


func _on_flow_phase_changed(next_phase: TurnFlow.Phase) -> void:
	phase_changed.emit(next_phase)


# ── 意图执行 ────────────────────────────────────────────────

func _execute_intent(enemy: Enemy) -> void:
	var intent: IntentData = enemy.advance_intent()
	if intent == null:
		return

	match intent.type:
		IntentData.IntentType.ATTACK:
			# 多段攻击逐段结算——每段独立触发格挡与荆棘
			for _i: int in intent.times:
				if not player.is_alive():
					break
				_log("%s 发动攻击（%d）" % [enemy.display_name, intent.value])
				_deal_damage(enemy, player, intent.value)
		IntentData.IntentType.DEFEND:
			var gained: int = enemy.gain_block(intent.value)
			_log("%s 获得 %d 格挡" % [enemy.display_name, gained])
		_:
			_log("%s 使用了「%s」（该意图类型阶段 2 尚未实现）" % [
				enemy.display_name, intent.display_text(),
			])


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
	if flow.is_over():
		return true
	if not player.is_alive():
		flow.finish(false)
		return true
	if first_alive_enemy() == null:
		flow.finish(true)
		return true
	return false


# ── 查询 ────────────────────────────────────────────────────

func is_over() -> bool:
	return flow.is_over()


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
