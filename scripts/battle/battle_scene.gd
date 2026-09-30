extends Node
## 战斗场景控制器 —— 阶段 1 薄切片的「组合根」
##
## 这是唯一同时知道 BattleManager（逻辑）与 BattleLogUI（展示）的地方。
## UI 自己不 import 战斗逻辑（工程书 §2.3），只发信号 + 收展示指令。
##
## ⚠️ 一次性代码：阶段 2 会换成正式的 TurnFlow + IntentResolver + 卡牌视图。

const PROTOTYPE_PLAYER_HP: int = 30
const PROTOTYPE_ENEMY_HP: int = 24
const PROTOTYPE_ENEMY_ATTACK: int = 7
const STRIKE_COUNT: int = 5
const DEFEND_COUNT: int = 5
const STRIKE_DAMAGE: int = 6
const DEFEND_BLOCK: int = 5

@onready var ui: BattleLogUI = %BattleLogUI

var _battle: BattleManager
var _player: Player
var _enemy: Enemy


func _ready() -> void:
	ui.attack_pressed.connect(_on_attack_pressed)
	ui.defend_pressed.connect(_on_defend_pressed)
	ui.end_turn_pressed.connect(_on_end_turn_pressed)
	ui.back_pressed.connect(_on_back_pressed)
	_start_prototype_battle()


func _start_prototype_battle() -> void:
	_battle = BattleManager.new()
	add_child(_battle)
	_battle.log_message.connect(_on_log)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.phase_changed.connect(_on_phase_changed)

	_player = Player.new()
	_player.display_name = "战士"
	_player.max_hp = PROTOTYPE_PLAYER_HP
	add_child(_player)

	_enemy = Enemy.new()
	_enemy.display_name = "竞技场新兵"
	_enemy.max_hp = PROTOTYPE_ENEMY_HP
	_enemy.attack_damage = PROTOTYPE_ENEMY_ATTACK
	add_child(_enemy)

	var enemies: Array[Enemy] = [_enemy]
	_battle.start_battle(_player, enemies, _build_prototype_deck())
	_refresh_view()


## 战士初始牌组（设计文档 §9.5）：5 打击(6) + 5 防御(5)
func _build_prototype_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	for _i: int in STRIKE_COUNT:
		deck.append(CardData.make_attack(&"strike", "打击", 1, STRIKE_DAMAGE))
	for _i: int in DEFEND_COUNT:
		deck.append(CardData.make_skill(&"defend", "防御", 1, DEFEND_BLOCK))
	return deck


# ── 按钮处理 ────────────────────────────────────────────────

func _on_attack_pressed() -> void:
	_play_first_playable(CardData.CardType.ATTACK)


func _on_defend_pressed() -> void:
	_play_first_playable(CardData.CardType.SKILL)


func _on_end_turn_pressed() -> void:
	_battle.end_player_turn()
	_refresh_view()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


func _play_first_playable(type: CardData.CardType) -> void:
	var card: CardData = _find_playable(type)
	if card == null:
		ui.append_log("（手牌里没有能量足够的%s牌）" % ("攻击" if type == CardData.CardType.ATTACK else "技能"))
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


# ── 视图刷新 ────────────────────────────────────────────────

func _on_log(text: String) -> void:
	ui.append_log(text)


func _on_battle_ended(_player_won: bool) -> void:
	ui.set_actions_enabled(false)


func _on_phase_changed(phase: BattleManager.Phase) -> void:
	ui.set_actions_enabled(phase == BattleManager.Phase.PLAYER_TURN)


func _refresh_view() -> void:
	ui.set_status("%s %d/%d  ❤   格挡 %d   ⚡ %d/%d      |      %s %d/%d  格挡 %d" % [
		_player.display_name, _player.hp, _player.max_hp, _player.block, _player.energy, _player.max_energy,
		_enemy.display_name, _enemy.hp, _enemy.max_hp, _enemy.block,
	])

	var names: PackedStringArray = PackedStringArray()
	for card: CardData in _battle.deck.hand:
		names.append("%s(%d费)" % [card.display_name, card.cost])
	ui.set_hand("手牌 %d 张：%s" % [_battle.deck.hand.size(), "、".join(names)])
