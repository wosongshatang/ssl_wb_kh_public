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

	# 盟友是**单场战斗**的东西——不清空的话，同一实例复用时会跨战斗残留
	allies.clear()
	bonus_gold = 0

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
	if card.is_unplayable() and not _can_play_unplayable(card):
		# 诅咒牌默认恒不可打出——它的作用是在手里持续折磨你，不是让你花能量丢掉。
		# **契约师是唯一的例外**：它能把诅咒当核弹打出去（阶段 9）。
		_log("「%s」无法打出。" % card.display_name)
		return false

	# 契约师可以改写牌的花费（把 0 费的诅咒变成 2 费核弹）
	var cost: int = card.cost
	for power: AbstractPower in player.all_powers():
		cost = power.modify_energy_cost(cost, card)

	# 魂能代付（阶段 9）：**只在付不起的时候才动用**——
	# 否则"付得起也拿魂能顶"会变成无脑消耗，魂能就失去"应急"的定位了。
	var subsidy: int = 0
	var subsidizer: AbstractPower = null
	if not player.can_afford(cost):
		for power: AbstractPower in player.all_powers():
			var offered: int = power.energy_subsidy_max(cost, card)
			if offered > subsidy:
				subsidy = offered
				subsidizer = power
	var payable: int = maxi(0, cost - subsidy)
	if not player.can_afford(payable):
		_log("能量不足：「%s」需要 %d，剩余 %d" % [card.display_name, cost, player.energy])
		return false

	if subsidizer != null and subsidy > 0:
		subsidizer.consume_energy_subsidy(subsidy)
		_log("魂能代付 %d 点能量" % subsidy)
	player.spend_energy(payable)
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
		_exhaust_card(card)
	else:
		deck.add_to_discard(card)

	_check_battle_end()
	return true


## 契约师：允许打出"本来不可打出"的牌（目前只用于诅咒）。
func _can_play_unplayable(card: CardData) -> bool:
	for power: AbstractPower in player.all_powers():
		if power.allows_playing(card):
			return true
	return false


## 把牌放进消耗区，**并通知所有能力**（阶段 9）。
##
## ⚠️ 这是"进消耗区"的**唯一入口**。任何地方直接调
## `deck.add_to_exhaust()` 都会绕过 `on_card_exhausted`，
## 表现成"死灵师的魂能不涨"——而且**不报错**。
func _exhaust_card(card: CardData) -> void:
	deck.add_to_exhaust(card)
	player.notify_card_exhausted(card)


## **主动消耗手牌**（咒术师「禁忌知识」）。
##
## ⚠️ 必须也走 `_exhaust_card` 的通知——
## 否则会出现"打出后消耗会涨魂能，主动消耗不涨"这种**半个机制生效**的状态，
## 玩家只会觉得这机制是坏的，而日志里什么都没有。
func exhaust_from_hand(card: CardData) -> bool:
	if not deck.take_from_hand(card):
		return false
	_exhaust_card(card)
	_log("消耗「%s」" % card.display_name)
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
##
## 公开入口（阶段 9）——死灵师的骸骨兵走这里。
## 内部逻辑仍集中在 `_summon_ally`，不另开一套召唤路径。
func summon_ally(ally_id: StringName) -> Ally:
	return _summon_ally(ally_id)


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
	# 死了就移出数组——否则它会一直占着位置，
	# 而 `_enemy_target` / `_allies_act` 每次都要重新判活。
	ally.died.connect(func() -> void:
		_log("  ☠ %s 倒下了" % ally.display_name)
		allies.erase(ally))
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

		CardData.SpecialKind.FORM_SHIFT:
			# 兽化者的人形 / 兽形切换（阶段 9）。
			# ⚠️ 只有**响应了**的能力才写日志——没有兽化者的角色打出这张牌时，
			# 日志必须干净，否则玩家会以为自己切换了形态。
			for power: AbstractPower in player.all_powers():
				var message: String = power.on_form_shift(player)
				if message != "":
					_log("〔兽化〕%s" % message)
					break

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
	# 幕环境也在这里收尾（如「因果律」：本回合没挨打就 +2 力量）。
	# ⚠️ 必须放在 `player.on_turn_end()` **之后**——因果律读的是"本回合是否受过伤"，
	# 那个状态由本回合累积，不能被提前打断。
	if act_modifier != null:
		act_modifier.on_turn_end(player)
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
			# 冻结（阶段 9）：跳过本次行动。由 [ElementSystem] 在霜满层时施加。
			# ⚠️ 放在 `refresh_phase()` **之前**——被冻住的敌人连姿态都不该变，
			# 否则玩家会看到"它冻着但还是变强了"，冻结的价值就被削弱了。
			if enemy.has_power(&"frozen"):
				enemy.remove_power(&"frozen")
				_log("  ❄ %s 被冻结，跳过行动" % enemy.display_name)
			else:
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

## 重新结算一张牌的效果（**不付能量、不消耗牌**）。
##
## 风行者用它复制每回合的第一张攻击牌。
##
## ⚠️ **必须复用 `_resolve_card_effects`**，不要另写一份"复制的结算"——
## 两份结算迟早会不一致（少算了某个字段），而且那种偏差**不报错**，
## 玩家只会觉得"这张牌复制出来好像弱一点"。
func replay_card_effects(card: CardData) -> void:
	if not player.is_alive():
		return
	_log("〔风行者〕复制「%s」" % card.display_name)
	_resolve_card_effects(card, null)


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

		# ★ 元素必须走 ElementSystem（阶段 9）。
		#
		# 这里是最容易漏的一处：卡牌的 `apply_to_target = {"burn": 2}` 会直接
		# 走到 `apply_power`，**绕过反应判定**——于是"用卡牌上燃"永远不触发蒸汽，
		# 而"用元素亲和上燃"会触发。同一个元素两种行为，且**不报错**。
		# 所以元素统一在这里改道。
		if ElementSystem.is_element(power_id):
			var note: String = ElementSystem.apply_element(receiver, power_id, amount)
			_log("  %s 附着 %s ×%d%s" % [
				label, power_id, amount, "（%s）" % note if note != "" else "",
			])
			continue

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
		# ⚠️ **只有敌人被击败才触发击杀逻辑**。
		#
		# 不区分的话，敌人打死你的召唤兽会触发：
		#   · 幕环境的「执念」（古战场：每次击杀玩家受 4 点伤害）——**盟友死了你还挨罚**
		#   · 敌人的 on_kill 遗物/能力——**敌人杀你的盟友算它的战功**
		# 两条都是"结果与因果不符"，而且不会报错，只会让人觉得"这游戏在乱扣血"。
		if target is Enemy:
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
