extends Node
## 战斗场景控制器（组合根）
##
## 阶段 3 起：战斗从 GameState 读单局状态（血量 / 牌组 / 当前节点），
## 结束后把结果写回去并返回地图。这是「一局能走完」的闭环所在。

const GOLD_REWARD_COMBAT: int = 12
const GOLD_REWARD_ELITE: int = 30

@onready var ui: BattleLogUI = %BattleLogUI

var _battle: BattleManager
var _player: Player
var _enemy: Enemy
var _run: RunState
var _node_kind: int = MapNode.Kind.COMBAT


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

	# ⚠️ start_battle 内部会 reset_for_battle()（满血）。单局里的残血必须在这之后接管——
	#    否则会出现「地图上残血、一进战斗就满血」这种最难查的数值 bug。
	_player.set_hp(_run.hp)

	_refresh_view()


## 阶段 3 的占位敌人：按节点类型给一组固定数值。
## 阶段 4 起改为从 data/enemies/*.tres 按 payload.enemy_id 加载。
func _build_enemy_data() -> EnemyData:
	var hp: int = 24
	var attack: int = 7
	var label: String = "竞技场新兵"

	match _node_kind:
		MapNode.Kind.ELITE:
			hp = 40
			attack = 10
			label = "精英 · 铁律卫士"
		MapNode.Kind.BOSS:
			hp = 60
			attack = 12
			label = "考官 · 卫冕冠军卡冈"
		_:
			pass

	var data := EnemyData.new()
	data.id = &"placeholder_enemy"
	data.display_name = label
	data.max_hp = hp
	var intents: Array[IntentData] = [IntentData.make_attack(attack)]
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
	if _battle != null and _battle.is_over():
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
	_run.sync_from_creature(_player)

	if player_won:
		var gold: int = _gold_reward()
		_run.add_gold(gold)
		ui.append_log("获得 %d 金币。" % gold)

		if _node_kind == MapNode.Kind.BOSS:
			_run.finish(true)
			SaveManager.delete_save()
			ui.append_log("═══ 第 1 幕完成 ═══")
		else:
			SaveManager.save_run(_run, GameState.map)
	else:
		_run.finish(false)
		SaveManager.delete_save()

	ui.set_actions_enabled(false)
	ui.set_back_label("返回地图" if player_won else "返回启动页")


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

	ui.set_status("%s %d/%d  ❤   格挡 %d   ⚡ %d/%d      |      %s %d/%d  格挡 %d   〔意图：%s〕" % [
		_player.display_name, _player.hp, _player.max_hp, _player.block,
		_player.energy, _player.max_energy,
		_enemy.display_name, _enemy.hp, _enemy.max_hp, _enemy.block, intent_text,
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
