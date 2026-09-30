extends Node
## 战斗场景控制器（组合根）
##
## 阶段 3 起：战斗从 GameState 读单局状态（血量 / 牌组 / 当前节点），
## 结束后把结果写回去并返回地图。这是「一局能走完」的闭环所在。

const GOLD_REWARD_COMBAT: int = 12
const GOLD_REWARD_ELITE: int = 30
## 三幕结构：第 1、2 幕 Boss 后转职，第 3 幕 Boss 后通关（神战 P4 待实现）
const MAX_ACTS: int = 3

@onready var ui: BattleLogUI = %BattleLogUI

var _battle: BattleManager
var _player: Player
var _enemy: Enemy
var _run: RunState
var _node_kind: int = MapNode.Kind.COMBAT
var _reward_panel: CardRewardPanel = null
var _job_panel: JobChoicePanel = null


func _ready() -> void:
	ui.attack_pressed.connect(_on_attack_pressed)
	ui.defend_pressed.connect(_on_defend_pressed)
	ui.end_turn_pressed.connect(_on_end_turn_pressed)
	ui.back_pressed.connect(_on_back_pressed)
	_start_battle()


func _start_battle() -> void:
	_run = GameState.run
	# 直接运行本场景（调试）时自动开一局
	if _run == null:
		GameState.start_new_run(&"warrior", randi())
		_run = GameState.run

	var node: MapNode = GameState.map.current_node() if GameState.map != null else null
	_node_kind = node.kind if node != null else MapNode.Kind.COMBAT

	_battle = BattleManager.new()
	add_child(_battle)
	_battle.log_message.connect(_on_log)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.phase_changed.connect(_on_phase_changed)

	_player = Player.new()
	_player.display_name = _character_display_name()
	_player.max_hp = _run.max_hp
	add_child(_player)

	_enemy = Enemy.new()
	_enemy.setup_from_data(_build_enemy_data())
	add_child(_enemy)

	var enemies: Array[Enemy] = [_enemy]
	_battle.start_battle(_player, enemies, _run.build_deck())

	# ⚠️ 下面全部必须在 start_battle **之后**——它内部会 reset_for_battle()。
	#    顺序颠倒会导致「地图上残血、一进战斗就满血」这类最难查的数值 bug。
	_inject_identity_and_relics()
	_player.set_hp(_run.hp)
	_enemy.apply_starting_powers()
	_assign_opponents(enemies)
	_player.notify_battle_start()
	_enemy.notify_battle_start()

	_refresh_view()


## 注入身份能力与遗物。
##
## 身份能力的「源头」是 [member GameState.identity_power_ids]——
## **每场战斗重新实例化注入**。战斗内任何效果都接触不到那个源头，
## 所以「不可剥夺」是物理性的，不是靠记得写判断。
func _inject_identity_and_relics() -> void:
	_player.clear_identity_powers()
	for power_id: StringName in GameState.identity_power_ids:
		var power := IdentityPowers.create(power_id)
		if power != null:
			_player.apply_identity_power(power)

	_player.clear_relics()
	for relic_id: StringName in _run.relics:
		var relic := RelicFactory.create(relic_id)
		if relic != null:
			_player.add_relic(relic)


## 注入敌对单位。盾猛这类「对当前敌人造成伤害」的能力靠它拿目标。
func _assign_opponents(enemies: Array[Enemy]) -> void:
	var player_side: Array[Creature] = [_player]
	var enemy_side: Array[Creature] = []
	for enemy: Enemy in enemies:
		enemy_side.append(enemy)

	_player.set_opponents(enemy_side)
	for enemy: Enemy in enemies:
		enemy.set_opponents(player_side)


## 从 `data/enemies/*.tres` 按节点 payload 的 enemy_id 加载。
## 找不到配置时退回兜底敌人——**绝不能让玩家卡在一场打不完的战斗里**。
func _build_enemy_data() -> EnemyData:
	var enemy_id := _node_enemy_id()
	var loaded: Variant = ContentRegistry.get_enemy(enemy_id)
	if loaded is EnemyData:
		return loaded as EnemyData

	push_warning("BattleScene: 找不到敌人配置「%s」，使用兜底敌人" % enemy_id)
	return _fallback_enemy_data()


func _node_enemy_id() -> StringName:
	if GameState.map == null:
		return &""
	var node: MapNode = GameState.map.current_node()
	if node == null:
		return &""
	return StringName(str(node.payload.get("enemy_id", "")))


func _fallback_enemy_data() -> EnemyData:
	var data := EnemyData.new()
	data.id = &"fallback_enemy"
	data.display_name = "无名的拦路者"
	data.max_hp = 24
	var intents: Array[IntentData] = [IntentData.make_attack(7)]
	data.intents = intents
	return data


# ── 按钮处理 ────────────────────────────────────────────────

func _on_attack_pressed() -> void:
	_play_first_playable(CardData.CardType.ATTACK)


func _on_defend_pressed() -> void:
	_play_first_playable(CardData.CardType.SKILL)


func _on_end_turn_pressed() -> void:
	_battle.end_player_turn()
	_refresh_view()


func _on_back_pressed() -> void:
	if _battle != null and _battle.is_over() and not _run.is_over:
		get_tree().change_scene_to_file("res://scenes/map/map.tscn")
	else:
		# 战斗中途退出：保留存档（当前节点已标记为已访问）
		SaveManager.save_run(_run, GameState.map)
		get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


func _play_first_playable(type: CardData.CardType) -> void:
	var card: CardData = _find_playable(type)
	if card == null:
		ui.append_log("（手牌里没有能量足够的%s牌）" % (
			"攻击" if type == CardData.CardType.ATTACK else "技能"))
		return
	_battle.play_card(card)
	_refresh_view()


func _find_playable(type: CardData.CardType) -> CardData:
	if _battle.deck == null:
		return null
	for card: CardData in _battle.deck.hand:
		if card.type == type and _player.can_afford(card.cost):
			return card
	return null


# ── 战斗结果 ────────────────────────────────────────────────

func _on_log(text: String) -> void:
	ui.append_log(text)


func _on_phase_changed(next_phase: TurnFlow.Phase) -> void:
	ui.set_actions_enabled(next_phase == TurnFlow.Phase.PLAYER_TURN)


func _on_battle_ended(player_won: bool) -> void:
	# ⚠️ 遗物结算必须在同步血量**之前**——燃烧之血会在胜利时回血。
	#    顺序颠倒会导致「回的血没被写进单局状态」，而且不会有任何报错。
	_player.notify_battle_end(player_won)
	_run.sync_from_creature(_player)
	ui.set_actions_enabled(false)

	if not player_won:
		_run.finish(false)
		SaveManager.delete_save()
		_go_to_game_over()
		return

	var gold: int = _gold_reward()
	_run.add_gold(gold)
	ui.append_log("获得 %d 金币。" % gold)

	if _node_kind == MapNode.Kind.BOSS:
		if _run.current_act >= MAX_ACTS:
			_run.finish(true)
			SaveManager.delete_save()
			_go_to_game_over()
			return
		_start_job_transfer()
		return

	_offer_card_reward()


# ── 转职仪式（第 1、2 幕 Boss 后固定触发，设计文档 §2.1）────

func _start_job_transfer() -> void:
	var jobs: Array[JobData] = _pending_jobs()
	if jobs.is_empty():
		ui.append_log("（没有可选的转职——直接进入下一幕）")
		_advance_act()
		return

	ui.append_log("═══ 转职仪式 ═══")
	_job_panel = JobChoicePanel.new()
	_job_panel.setup("选择一条要刻进灵魂的规则", jobs)
	_job_panel.job_chosen.connect(_on_job_chosen)
	add_child(_job_panel)


## 该转几次了：0 → 一阶二选一；1 → 二阶二选一；2 → 已经没有转职了
func _pending_jobs() -> Array[JobData]:
	var transfers_done: int = GameState.job_path.size()
	if transfers_done == 0:
		return JobDatabase.first_tier_jobs(_run.character_class)
	if transfers_done == 1:
		return JobDatabase.final_jobs(GameState.job_path[0])

	var none: Array[JobData] = []
	return none


func _on_job_chosen(job_id: StringName) -> void:
	var job: JobData = JobDatabase.get_job(job_id)
	if job == null:
		return

	GameState.apply_job(job)
	ui.append_log("你刻入了「%s」的规则。任何方式都无法再把它拿走。" % job.display_name)

	if _job_panel != null:
		_job_panel.queue_free()
		_job_panel = null

	_offer_job_card(job)


## 转职附赠：从该职业的职业牌里三选一。
## **不增加最大生命**（设计文档 §2.2 / 决策 5）——续航由职业机制本身承担。
func _offer_job_card(job: JobData) -> void:
	var offers: Array[CardData] = []
	for card_id: StringName in job.job_card_ids:
		var card: Variant = ContentRegistry.get_card(card_id)
		if card is CardData:
			offers.append(card as CardData)

	if offers.is_empty():
		_advance_act()
		return

	_reward_panel = CardRewardPanel.new()
	_reward_panel.setup("转职附赠：选择一张职业牌加入牌组", offers, false)
	_reward_panel.card_chosen.connect(_on_job_card_chosen)
	add_child(_reward_panel)


func _on_job_card_chosen(card_id: StringName) -> void:
	_run.add_card(card_id)
	var card: Variant = ContentRegistry.get_card(card_id)
	if card is CardData:
		ui.append_log("「%s」加入牌组。" % (card as CardData).display_name)

	if _reward_panel != null:
		_reward_panel.queue_free()
		_reward_panel = null

	_advance_act()


func _advance_act() -> void:
	GameState.advance_act()
	SaveManager.save_run(_run, GameState.map)
	ui.append_log("═══ 进入第 %d 幕 ═══" % _run.current_act)
	ui.set_back_label("进入第 %d 幕" % _run.current_act)


# ── 战后三选一 ──────────────────────────────────────────────

func _offer_card_reward() -> void:
	var pool := CardPool.new(RandomNumberGenerator.new())
	var offers: Array[CardData] = pool.roll()

	if offers.is_empty():
		# 卡池为空时不能把玩家卡在这里——直接结束流程
		push_warning("BattleScene: 卡池为空，跳过卡牌奖励")
		_finish_battle_flow()
		return

	_reward_panel = CardRewardPanel.new()
	_reward_panel.setup("选择一张牌加入牌组", offers)
	_reward_panel.card_chosen.connect(_on_reward_card_chosen)
	_reward_panel.skipped.connect(_on_reward_skipped)
	add_child(_reward_panel)


func _on_reward_card_chosen(card_id: StringName) -> void:
	_run.add_card(card_id)
	var card: Variant = ContentRegistry.get_card(card_id)
	if card is CardData:
		ui.append_log("「%s」加入牌组。" % (card as CardData).display_name)
	_finish_battle_flow()


func _on_reward_skipped() -> void:
	ui.append_log("放弃了卡牌奖励。")
	_finish_battle_flow()


func _finish_battle_flow() -> void:
	if _reward_panel != null:
		_reward_panel.queue_free()
		_reward_panel = null
	SaveManager.save_run(_run, GameState.map)
	ui.set_back_label("返回地图")


func _go_to_game_over() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")


func _gold_reward() -> int:
	match _node_kind:
		MapNode.Kind.ELITE:
			return GOLD_REWARD_ELITE
		MapNode.Kind.BOSS:
			return 0
		_:
			return GOLD_REWARD_COMBAT


# ── 视图刷新 ────────────────────────────────────────────────

func _refresh_view() -> void:
	var intent_text: String = "—"
	var intent: IntentData = _enemy.current_intent()
	if intent != null and _enemy.is_alive():
		intent_text = intent.display_text()

	# 双姿态 Boss 换姿态时必须让玩家**看见**，否则"它变强了"只会表现为
	# 莫名其妙的掉血变多——玩家会以为是自己算错了
	var stance_tag: String = ""
	if _enemy.phase() >= 2:
		stance_tag = "〔已狂化〕"

	ui.set_status("%s %d/%d  ❤   格挡 %d   ⚡ %d/%d      |      %s%s %d/%d  格挡 %d   〔意图：%s〕" % [
		_player.display_name, _player.hp, _player.max_hp, _player.block,
		_player.energy, _player.max_energy,
		_enemy.display_name, stance_tag, _enemy.hp, _enemy.max_hp, _enemy.block, intent_text,
	])

	var names: PackedStringArray = PackedStringArray()
	for card: CardData in _battle.deck.hand:
		names.append("%s(%d费)" % [card.display_name, card.cost])
	ui.set_hand("手牌 %d 张：%s" % [_battle.deck.hand.size(), "、".join(names)])


func _character_display_name() -> String:
	match _run.character_class:
		&"warrior":
			return "战士"
		&"hunter":
			return "猎人"
		&"mage":
			return "法师"
		_:
			return "无名者"
