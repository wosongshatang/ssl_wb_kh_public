extends Node
## 地图场景控制器（组合根）
##
## 把 GameState 里的单局状态 + 地图，翻译成 [MapUI] 的展示与交互。
## 节点类型分派、商店与事件的**结算**都在这里——UI 只负责「玩家点了哪个按钮」。
##
## ⚠️ 结算为什么必须在控制器而不在面板里：面板改不了 RunState（那是 UI 的职责边界）。
## 面板只发信号说「我要买这张牌」，买不买得起、买完怎么记账，由这里决定。

const REST_HEAL_RATIO: float = 0.3
## 用于把「种子 + 节点」映射成一个稳定的随机源，避免同一节点每次进都刷新商品
const NODE_SEED_STRIDE: int = 7919

@onready var ui: MapUI = %MapUI

var _run: RunState
var _map: MapManager
var _rng := RandomNumberGenerator.new()

var _shop_panel: ShopPanel = null
var _event_panel: EventPanel = null
var _shop_offers: Array[CardData] = []
var _current_event: EventData = null


func _ready() -> void:
	ui.node_selected.connect(_on_node_selected)
	ui.save_and_exit_pressed.connect(_on_save_and_exit)
	ui.abandon_pressed.connect(_on_abandon)

	_run = GameState.run
	_map = GameState.map

	# 直接运行本场景（调试）时自动开一局，避免空指针
	if _run == null or _map == null:
		GameState.start_new_run(&"warrior", randi())
		_run = GameState.run
		_map = GameState.map

	_reseed_rng()
	ui.build_map(_map)
	_refresh()


func _reseed_rng() -> void:
	_rng.seed = _run.rng_seed + _map.current_node_id * NODE_SEED_STRIDE


func _refresh() -> void:
	ui.set_status("%s  %d/%d 生命   %d 金币   第 %d 幕   牌组 %d 张" % [
		_character_display_name(),
		_run.hp, _run.max_hp, _run.gold, _run.current_act, _run.deck_card_ids.size(),
	])

	var current: MapNode = _map.current_node()
	if current == null:
		ui.set_hint("选择起点。高亮为可前往，灰色为已访问。")
	else:
		ui.set_hint("当前位置：%s。请选择下一个节点。" % current.kind_label())

	ui.refresh(_map)


# ── 节点分派 ────────────────────────────────────────────────

func _on_node_selected(node_id: int) -> void:
	if not _map.enter_node(node_id):
		return

	_reseed_rng()
	var node: MapNode = _map.nodes[node_id]

	match node.kind:
		MapNode.Kind.COMBAT, MapNode.Kind.ELITE, MapNode.Kind.BOSS:
			# 进战斗前存档——万一崩了还能从这一步重来
			SaveManager.save_run(_run, _map)
			get_tree().change_scene_to_file("res://scenes/battle/battle_log.tscn")

		MapNode.Kind.REST:
			var healed: int = int(ceil(float(_run.max_hp) * REST_HEAL_RATIO))
			_run.heal(healed)
			ui.set_hint("休息：回复 %d 点生命。" % healed)
			_persist_and_refresh()

		MapNode.Kind.SHOP:
			_open_shop()

		MapNode.Kind.EVENT:
			_open_event(node)

		_:
			ui.set_hint("「%s」尚未实现。" % node.kind_label())
			_persist_and_refresh()


func _persist_and_refresh() -> void:
	SaveManager.save_run(_run, _map)
	_refresh()


# ── 商店 ────────────────────────────────────────────────────

func _open_shop() -> void:
	var pool := CardPool.new(_rng)
	_shop_offers = pool.roll(CardPool.SHOP_OFFER_COUNT)
	_show_shop()


func _show_shop() -> void:
	_close_shop()
	_shop_panel = ShopPanel.new()
	_shop_panel.setup(_run.gold, _shop_offers, _run.build_deck())
	_shop_panel.purchase_requested.connect(_on_purchase_requested)
	_shop_panel.removal_requested.connect(_on_removal_requested)
	_shop_panel.closed.connect(_on_shop_closed)
	add_child(_shop_panel)


func _close_shop() -> void:
	if _shop_panel != null:
		_shop_panel.queue_free()
		_shop_panel = null


func _on_purchase_requested(card_id: StringName, price: int) -> void:
	if not _run.spend_gold(price):
		return

	_run.add_card(card_id)
	# 买过的从货架移除，避免同一张牌买两次
	for i: int in range(_shop_offers.size() - 1, -1, -1):
		if _shop_offers[i].id == card_id:
			_shop_offers.remove_at(i)
			break

	ui.set_hint("购买了「%s」（花费 %d 金币）。" % [_card_name(card_id), price])
	_show_shop()


func _on_removal_requested(card_id: StringName, price: int) -> void:
	if not _run.spend_gold(price):
		return

	_run.remove_card(card_id)
	ui.set_hint("移除了「%s」（花费 %d 金币）。" % [_card_name(card_id), price])
	_show_shop()


func _on_shop_closed() -> void:
	_close_shop()
	_persist_and_refresh()


# ── 事件 ────────────────────────────────────────────────────

func _open_event(node: MapNode) -> void:
	var event_id := StringName(str(node.payload.get("event_id", "")))
	var loaded: Variant = ContentRegistry.get_event(event_id)

	if not (loaded is EventData):
		ui.set_hint("事件「%s」尚未实现（阶段 6 填充）。" % event_id)
		_persist_and_refresh()
		return

	_current_event = loaded as EventData

	if _event_panel != null:
		_event_panel.queue_free()
	_event_panel = EventPanel.new()
	_event_panel.setup(_current_event)
	_event_panel.option_chosen.connect(_on_event_option_chosen)
	add_child(_event_panel)


func _on_event_option_chosen(index: int) -> void:
	if _current_event == null:
		return

	var label: String = ""
	var effect: EventData.Effect = EventData.Effect.NONE
	var value: int = 0

	if index == 0:
		label = _current_event.option_a_label
		effect = _current_event.option_a_effect
		value = _current_event.option_a_value
	else:
		label = _current_event.option_b_label
		effect = _current_event.option_b_effect
		value = _current_event.option_b_value

	var result: String = _apply_effect(effect, value)
	ui.set_hint("「%s」→ %s" % [label, result])

	if _event_panel != null:
		_event_panel.queue_free()
		_event_panel = null
	_current_event = null

	if _run.is_over:
		get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
		return

	_persist_and_refresh()


## 效果结算。**必须与 [method EventData.effect_text] 的描述一致**——
## 玩家看到「回复 10 点生命」就必须真的回 10 点，这类撕裂最伤信任。
func _apply_effect(effect: EventData.Effect, value: int) -> String:
	match effect:
		EventData.Effect.HEAL:
			_run.heal(value)
			return "回复 %d 点生命" % value

		EventData.Effect.DAMAGE:
			_run.take_damage(value)
			return "失去 %d 点生命" % value

		EventData.Effect.GOLD:
			_run.add_gold(value)
			return "金币变为 %d" % _run.gold

		EventData.Effect.MAX_HP:
			_run.max_hp += value
			_run.heal(value)
			return "最大生命 +%d（现为 %d）" % [value, _run.max_hp]

		EventData.Effect.ADD_RANDOM_CARD:
			var pool := CardPool.new(_rng)
			var offers: Array[CardData] = pool.roll(1)
			if offers.is_empty():
				return "卡池为空，什么也没得到"
			_run.add_card(offers[0].id)
			return "获得「%s」" % offers[0].display_name

		EventData.Effect.REMOVE_CARD:
			# 阶段 3 简化：随机移除一张。阶段 6 改成让玩家选。
			var deck: Array[CardData] = _run.build_deck()
			if deck.is_empty():
				return "牌组为空"
			var victim: CardData = deck[_rng.randi_range(0, deck.size() - 1)]
			_run.remove_card(victim.id)
			return "移除了「%s」" % victim.display_name

		_:
			return "什么也没发生"


# ── 退出 ────────────────────────────────────────────────────

func _on_save_and_exit() -> void:
	SaveManager.save_run(_run, _map)
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


func _on_abandon() -> void:
	SaveManager.delete_save()
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


# ── 辅助 ────────────────────────────────────────────────────

func _card_name(card_id: StringName) -> String:
	var card: Variant = ContentRegistry.get_card(card_id)
	if card is CardData:
		return (card as CardData).display_name
	return String(card_id)


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
