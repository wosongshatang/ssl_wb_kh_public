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
## 卡牌获得药水（BattleManager 够不着 RunState，所以抛给场景去记账）
signal potion_granted(potion_id: StringName)
## 特殊牌要改**局外状态**时走这三个信号（P6-12）。
## BattleManager 够不着 RunState / GameState，硬塞引用会让它变成上帝对象。
signal card_upgrade_requested(count: int)   ## 神化：升级牌组里的若干张牌
signal divinity_requested(amount: int)      ## 契约：永久神性
signal oracle_revealed(pile: Array)         ## 神谕：把抽牌堆展示给玩家
## 幕环境机制生效（阶段 6）。与遗物同理：**必须看得见**，
## 否则玩家会以为"这关怎么突然变难了"是自己算错了。
signal environment_announced(text: String)

## 遗物在战斗内累加的额外金币（幸运币这类）。
## 金币属于 RunState，遗物够不着，所以先累在这里，由场景结算时一并发放。
var bonus_gold: int = 0

## 本场的幕环境机制（阶段 6）。没有配置时为 null。
## 友方单位（猎人线的召唤兽）。
## 与 `enemies` 对称：都在战斗里存活、都能被打、都有 Power。
var allies: Array[Ally] = []

var act_modifier: ActModifiers.Runtime = null
var _pending_act_modifier: ActModifier = null

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

	# 幕环境机制：在所有 reset 之后、开战之前生效
	_setup_act_modifier()

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
	if card.is_unplayable():
		# 诅咒牌恒不可打出——它的作用是在手里持续折磨你，不是让你花能量丢掉
		_log("「%s」无法打出。" % card.display_name)
		return false
	if not player.can_afford(card.cost):
		_log("能量不足：「%s」需要 %d，剩余 %d" % [card.display_name, card.cost, player.energy])
		return false

	player.spend_energy(card.cost)
	deck.take_from_hand(card)
	_log("打出「%s」（剩余能量 %d）" % [card.display_name, player.energy])

	player.notify_card_played(card)
	_apply_special_effect(card)
	if card.summon_ally_id != &"":
		_summon_ally(card.summon_ally_id)
	if act_modifier != null:
		act_modifier.on_card_played(player, card)
	_resolve_card_effects(card, target)

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
	if act_modifier != null:
		act_modifier.on_turn_start(player, turn)
	var drawn: Array[CardData] = deck.draw(HAND_SIZE)
	_log("── 第 %d 回合 · 玩家 ──（能量 %d/%d）" % [turn, player.energy, player.max_energy])
	_log("抽到 %d 张：%s" % [drawn.size(), get_hand_names()])


## 特殊牌效果（P6-12）。
##
## ⚠️ 神化要改**局外的牌组**、契约要改**局外的神性**——这两个都不归
## BattleManager 管，所以走信号交给场景去记账（与 potion_granted 同一套做法）。
## 直接持有 RunState 引用会让 BattleManager 变成上帝对象，也没法单独测试。
## 召唤一个友方单位（猎人线）
func _summon_ally(ally_id: StringName) -> Ally:
	var loaded: Variant = ContentRegistry.get_ally(ally_id)
	if not (loaded is AllyData):
		push_warning("BattleManager: 未知召唤兽「%s」" % ally_id)
		return null

	var ally := Ally.new()
	ally.setup_from_data(loaded as AllyData)

	for raw_id: Variant in (loaded as AllyData).starting_powers:
		var power := PowerFactory.create(StringName(str(raw_id)), int((loaded as AllyData).starting_powers[raw_id]))
		if power != null:
			ally.apply_power(power)

	allies.append(ally)
	ally.died.connect(func() -> void:
		_log("  ☠ %s 倒下了" % ally.display_name))
	_log("召唤了 %s（%d 血 / %d 攻）" % [ally.display_name, ally.max_hp, ally.attack_power()])
	return ally


func _apply_special_effect(card: CardData) -> void:
	match card.special_kind:
		CardData.SpecialKind.APOTHEOSIS:
			_log("〔神化〕你的牌组被改写了……")
			card_upgrade_requested.emit(card.special_value)

		CardData.SpecialKind.PACT:
			# 用 divinity_gain 而不是 special_value——
			# 「获得时涨神性」在无色卡上已经是这个字段，同一个概念不该有两个字段
			_log("〔契约〕神性 +%d" % card.divinity_gain)
			divinity_requested.emit(card.divinity_gain)

		CardData.SpecialKind.ORACLE:
			var drawn: Array[CardData] = deck.draw(card.special_value)
			_log("〔神谕〕看穿未来，抽 %d 张" % drawn.size())
			oracle_revealed.emit(deck.draw_pile.duplicate())

		CardData.SpecialKind.TRIAL:
			_apply_trial(card)

		_:
			pass


## 考题：**手牌数**达到门槛时额外获得格挡。
##
## 条件刻意用"手牌数"而不是"牌的类型"——
## 后者考的是运气（你有没有抽到对的牌），前者考的是决策（你有没有留住牌）。
## 考题应该考决策。
func _apply_trial(card: CardData) -> void:
	if card.trial_block_bonus <= 0:
		return

	var hand_size: int = deck.hand.size()
	if hand_size < card.special_value:
		_log("〔考题〕手牌 %d 张，未达门槛 %d——没有额外格挡" % [hand_size, card.special_value])
		return

	player.gain_block(card.trial_block_bonus, card)
	_log("〔考题〕手牌 %d 张，达标——额外 %d 点格挡" % [hand_size, card.trial_block_bonus])


func _on_player_turn_ended(_turn: int) -> void:
	player.on_turn_end()
	# ⚠️ 诅咒必须在**回合清理之后**发作。
	# 放在 `player.on_turn_end()` 之前的话，它刚上的减益会被同一次清理立刻减掉一层——
	# 「回合结束获得 1 层易伤」实际等于什么都没发生，玩家会以为这张诅咒是废牌。
	_trigger_hand_curses()


## 手里的诅咒牌在回合结束时发作（用户要求：「痛苦」回合结束获得 1 层易伤）。
##
## 为什么放在**回合结束**而不是回合开始：
## 回合开始触发的话，玩家抽到诅咒的当回合就挨罚，完全没有应对窗口；
## 回合结束触发给了玩家「这一回合得想办法处理它」的空间——
## 负面效果的可玩性不在于数值多大，在于玩家有没有反应的余地。
func _trigger_hand_curses() -> void:
	if deck == null:
		return

	for card: CardData in deck.hand:
		if not card.triggers_on_turn_end:
			continue

		_log("「%s」发作……" % card.display_name)

		for raw_id: Variant in card.apply_to_self:
			var power_id := StringName(str(raw_id))
			var power := PowerFactory.create(power_id, int(card.apply_to_self[raw_id]))
			if power != null:
				player.apply_power(power)
				_log("  获得 %s ×%d" % [power.display_name, power.amount])

		if card.self_hp_loss > 0:
			player.take_damage(card.self_hp_loss, null, DamageType.HP_LOSS)
			_log("  失去 %d 点生命" % card.self_hp_loss)
	var discarded: int = deck.discard_hand()
	_log("玩家回合结束，弃掉手牌 %d 张" % discarded)
	_allies_act()


func _on_enemy_turn_started(_turn: int) -> void:
	_log("── 敌人回合 ──")
	for enemy: Enemy in enemies:
		if not enemy.is_alive():
			continue
		enemy.on_turn_start()
		if player.is_alive():
			# 变招检查放在行动**前**：血量刚掉下去的当回合就能切形态，
			# 玩家能立刻感受到「它变了」，而不是多等一回合。
			if enemy.refresh_phase():
				_log("  ⚠ %s 改变了姿态！" % enemy.display_name)
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

## 结算一张牌的全部效果。
##
## 效果按**字段**驱动而非按类型分支（decisions.md D16）——否则「攻防一体」牌
## （铁斩波：5 伤 + 5 格挡）与「打伤害顺便上减益」牌都写不出来。
## `type` 仍是标签（鏖战者按攻击牌计数、风行者复制首张攻击牌），但不是分派依据。
##
## 结算顺序固定：**伤害 → 格挡 → 施加 Power → 抽牌 → 能量 → 自伤**。
## 自伤放最后：万一自伤致死，前面的收益已经结算完，行为可预期。
func _resolve_card_effects(card: CardData, target: Creature) -> void:
	# 伤害与减益作用于**同一个**目标——不能各算一次 first_alive_enemy()，
	# 否则打死了第一个敌人后，减益会莫名其妙落到第二个敌人身上。
	var victim: Creature = target if target != null else first_alive_enemy()

	if card.damage > 0 and victim != null:
		_deal_damage(player, victim, card.damage)

	if card.block > 0:
		var gained: int = player.gain_block(card.block, card)
		_log("  获得 %d 格挡（当前 %d）" % [gained, player.block])

	_apply_powers(player, card.apply_to_self, "自己")

	if victim != null and victim.is_alive():
		_apply_powers(victim, card.apply_to_target, victim.display_name)

	if card.draw > 0:
		var drawn: Array[CardData] = deck.draw(card.draw)
		_log("  抽 %d 张牌" % drawn.size())

	if card.gain_energy > 0:
		player.gain_energy(card.gain_energy)
		_log("  获得 %d 点能量（当前 %d）" % [card.gain_energy, player.energy])

	if card.self_hp_loss > 0:
		player.take_damage(card.self_hp_loss, null, DamageType.HP_LOSS)
		_log("  失去 %d 点生命（无视格挡）" % card.self_hp_loss)

	if card.grant_potion_id != &"":
		# 药水栏是否放得下由场景决定——BattleManager 不该知道 RunState 的存在
		potion_granted.emit(card.grant_potion_id)
		_log("  获得药水（%s）" % card.grant_potion_id)


func _apply_powers(receiver: Creature, table: Dictionary, label: String) -> void:
	for raw_id: Variant in table:
		var power_id := StringName(str(raw_id))
		var amount: int = int(table[raw_id])
		var power := PowerFactory.create(power_id, amount)
		if power == null:
			continue
		receiver.apply_power(power)
		_log("  %s 获得 %s ×%d" % [label, power.display_name, amount])


# ── 意图执行 ────────────────────────────────────────────────

## 敌人这一下打谁。
##
## ## 规则（刻意做成**确定性**的）
## 1. 有**嘲讽**盟友 → 打嘲讽的（血最少的那个）
## 2. 否则 → 打玩家
##
## 不用"随机选一个"：随机会让玩家的决策失去意义——
## 你没法围绕一个掷骰子做规划。嘲讽把"谁挨打"变成玩家**主动选择**的结果。
func _enemy_target() -> Creature:
	var taunting: Ally = null
	for ally: Ally in allies:
		if not ally.is_alive() or not ally.is_taunt:
			continue
		if taunting == null or ally.hp < taunting.hp:
			taunting = ally
	return taunting if taunting != null else player


## 盟友回合结束时自动行动（不需要玩家操作）
func _allies_act() -> void:
	if allies.is_empty():
		return

	var living_enemies: Array[Creature] = []
	for enemy: Enemy in enemies:
		if enemy.is_alive():
			living_enemies.append(enemy)

	for ally: Ally in allies:
		if not ally.is_alive() or living_enemies.is_empty():
			continue
		ally.on_turn_start()
		if ally.act(living_enemies):
			_log("%s 攻击了 %s" % [ally.display_name, living_enemies[0].display_name])
		ally.on_turn_end()


func _execute_intent(enemy: Enemy) -> void:
	var intent: IntentData = enemy.advance_intent()
	if intent == null:
		return

	var target: Creature = _enemy_target()

	match intent.type:
		IntentData.IntentType.ATTACK:
			# 多段攻击逐段结算——每段独立触发格挡与荆棘
			for _i: int in intent.times:
				if not target.is_alive():
					# 目标倒了就重新选（嘲讽盟友死了，剩下的打在玩家身上）
					target = _enemy_target()
					if not target.is_alive():
						break
				_log("%s 攻击 %s（%d）" % [enemy.display_name, target.display_name, intent.value])
				_deal_damage(enemy, target, intent.value)
		IntentData.IntentType.DEFEND:
			var gained: int = enemy.gain_block(intent.value)
			_log("%s 获得 %d 格挡" % [enemy.display_name, gained])
		IntentData.IntentType.DEBUFF:
			# 把减益施加给玩家（毒 / 虚弱 / 易伤）。
			# 毒是**壁垒的天敌**——它无视格挡，所以「格挡滚雪球」在它面前完全失效。
			var debuff := PowerFactory.create(intent.power_id, intent.value)
			if debuff != null:
				target.apply_power(debuff)
				_log("%s 对 %s 施加了 %s ×%d" % [
					enemy.display_name, target.display_name, debuff.display_name, intent.value])
			else:
				push_warning("BattleManager: 意图引用了未知 Power「%s」" % intent.power_id)
		IntentData.IntentType.BUFF:
			var buff := PowerFactory.create(intent.power_id, intent.value)
			if buff != null:
				enemy.apply_power(buff)
				_log("%s 获得 %s ×%d" % [enemy.display_name, buff.display_name, intent.value])
			else:
				push_warning("BattleManager: 意图引用了未知 Power「%s」" % intent.power_id)
		_:
			_log("%s 使用了「%s」（该意图类型尚未实现）" % [
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
		if act_modifier != null:
			act_modifier.on_enemy_killed(player, target)


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


## 注入本场的幕环境机制。**必须在 [method start_battle] 之前调用**——
## 机制的 `apply_battle_start` 要在开战时立刻生效。
func set_act_modifier(modifier: ActModifier) -> void:
	_pending_act_modifier = modifier


func _setup_act_modifier() -> void:
	act_modifier = null
	if _pending_act_modifier == null:
		return
	act_modifier = ActModifiers.create(_pending_act_modifier, self)
	if act_modifier != null:
		act_modifier.apply_battle_start(player, enemies)


## 暴露本场战斗的 RNG。神化牌要随机挑牌升级，
## **必须用同一个随机源**，否则"同一局同一种子"无法复现。
func rng() -> RandomNumberGenerator:
	return _rng


func _log(text: String) -> void:
	log_message.emit(text)
