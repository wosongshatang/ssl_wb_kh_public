extends Node
## 地图场景控制器（组合根）
##
## 把 GameState 里的单局状态 + 地图，翻译成 [MapView] 的展示与交互。
## 节点类型分派、商店与事件的**结算**都在这里——UI 只负责「玩家点了哪个按钮」。

const REST_HEAL_RATIO: float = 0.3
## 把「种子 + 节点」映射成稳定的随机源，避免同一节点每次进都刷新商品
const NODE_SEED_STRIDE: int = 7919

var _run: RunState
var _map: MapManager
var _rng := RandomNumberGenerator.new()

var _hud: RunHUD
var _map_view: MapView
var _hint_label: Label
var _save_button: Button
var _overlay: OverlayPanel = null
var _shop_panel: ShopPanel = null
var _event_panel: EventPanel = null
var _shop_offers: Array[CardData] = []
var _current_event: EventData = null


func _ready() -> void:
	_run = GameState.run
	_map = GameState.map

	if _run == null or _map == null:
		GameState.start_new_run(&"warrior", randi())
		_run = GameState.run
		_map = GameState.map

	_build_ui()
	_reseed_rng()
	_refresh()
	get_viewport().size_changed.connect(_layout)


func _build_ui() -> void:
	# 羊皮纸底（参考视频的地图观感）
	var background := ColorRect.new()
	background.color = Color(0.19, 0.155, 0.13)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_map_view = MapView.new()
	add_child(_map_view)
	_map_view.node_selected.connect(_on_node_selected)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint_label)

	_save_button = Button.new()
	_save_button.text = "保存并返回标题"
	_save_button.custom_minimum_size = Vector2(140, 34)
	_save_button.focus_mode = Control.FOCUS_NONE
	_save_button.pressed.connect(_on_save_and_exit)
	add_child(_save_button)

	_hud = RunHUD.new()
	add_child(_hud)
	_hud.bind_run(_run)
	_hud.set_time_running(true)
	_hud.deck_pressed.connect(_open_deck)
	_hud.relics_pressed.connect(_open_relics)
	_hud.settings_pressed.connect(_open_settings)
	_hud.map_pressed.connect(_refresh)
	_hud.potion_pressed.connect(_on_potion_pressed)


func _layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_map_view.position = Vector2(0, RunHUD.HUD_HEIGHT)
	_map_view.size = Vector2(viewport_size.x, viewport_size.y - RunHUD.HUD_HEIGHT - 56.0)
	_map_view.build_map(_map)

	_hint_label.position = Vector2(24, viewport_size.y - 46)
	_hint_label.size = Vector2(viewport_size.x * 0.6, 40)
	_save_button.position = Vector2(viewport_size.x - 164, viewport_size.y - 48)


func _reseed_rng() -> void:
	_rng.seed = _run.rng_seed + _map.current_node_id * NODE_SEED_STRIDE


func _refresh() -> void:
	_hud.refresh()
	_map_view.refresh(_map)

	var current: MapNode = _map.current_node()
	if current == null:
		_hint_label.text = "选择起点。金边为可前往，灰色为已访问。"
	else:
		_hint_label.text = "当前位置：%s（第 %d 层）。点击金边节点前进。" % [
			current.kind_label(), current.row + 1,
		]


# ── 节点分派 ────────────────────────────────────────────────

func _on_node_selected(node_id: int) -> void:
	if _overlay != null:
		return
	if not _map.enter_node(node_id):
		return

	_reseed_rng()
	var node: MapNode = _map.nodes[node_id]

	match node.kind:
		MapNode.Kind.COMBAT, MapNode.Kind.ELITE, MapNode.Kind.BOSS:
			# 进战斗前存档——万一崩了还能从这一步重来
			SaveManager.save_run(_run, _map)
			_hud.set_time_running(false)
			get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")

		MapNode.Kind.REST:
			var healed: int = int(ceil(float(_run.max_hp) * REST_HEAL_RATIO))
			_run.heal(healed)
			_hint_label.text = "休息：回复 %d 点生命。" % healed
			_persist_and_refresh()

		MapNode.Kind.SHOP:
			_open_shop()

		MapNode.Kind.EVENT:
			_open_event(node)

		_:
			_hint_label.text = "「%s」尚未实现。" % node.kind_label()
			_persist_and_refresh()


func _persist_and_refresh() -> void:
	SaveManager.save_run(_run, _map)
	_refresh()


func _on_potion_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _run.potions.size():
		return
	var data: Variant = ContentRegistry.get_potion(_run.potions[slot_index])
	if not (data is PotionData):
		return
	var potion := data as PotionData
	if potion.battle_only:
		_hint_label.text = "%s 只能在战斗中使用。" % potion.display_name
		return

	_run.heal(potion.value)
	_run.remove_potion_at(slot_index)
	_hint_label.text = "使用 %s：回复 %d 点生命。" % [potion.display_name, potion.value]
	_persist_and_refresh()


# ── 商店 ────────────────────────────────────────────────────

func _open_shop() -> void:
	var pool := CardPool.new(_rng)
	_shop_offers = pool.roll(CardPool.SHOP_OFFER_COUNT)
	_show_shop()


func _show_shop() -> void:
	_close_shop()
	_shop_panel = ShopPanel.new()
	_overlay = _shop_panel
	_shop_panel.setup(_run.gold, _shop_offers, _run.build_deck())
	_shop_panel.purchase_requested.connect(_on_purchase_requested)
	_shop_panel.removal_requested.connect(_on_removal_requested)
	_shop_panel.closed.connect(_on_shop_closed)
	add_child(_shop_panel)


func _close_shop() -> void:
	if _shop_panel != null:
		_shop_panel.queue_free()
		_shop_panel = null
	_overlay = null


func _on_purchase_requested(card_id: StringName, price: int) -> void:
	if not _run.spend_gold(price):
		return

	_run.add_card(card_id)
	for i: int in range(_shop_offers.size() - 1, -1, -1):
		if _shop_offers[i].id == card_id:
			_shop_offers.remove_at(i)
			break

	_hint_label.text = "购买了「%s」（花费 %d 金币）。" % [_card_name(card_id), price]
	_hud.refresh()
	_show_shop()


func _on_removal_requested(card_id: StringName, price: int) -> void:
	if not _run.spend_gold(price):
		return

	_run.remove_card(card_id)
	_hint_label.text = "移除了「%s」（花费 %d 金币）。" % [_card_name(card_id), price]
	_hud.refresh()
	_show_shop()


func _on_shop_closed() -> void:
	_close_shop()
	_persist_and_refresh()


# ── 事件 ────────────────────────────────────────────────────

func _open_event(node: MapNode) -> void:
	var event_id := StringName(str(node.payload.get("event_id", "")))
	var loaded: Variant = ContentRegistry.get_event(event_id)

	if not (loaded is EventData):
		_hint_label.text = "事件「%s」尚未实现（阶段 6 填充）。" % event_id
		_persist_and_refresh()
		return

	_current_event = loaded as EventData
	_event_panel = EventPanel.new()
	_overlay = _event_panel
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
	_hint_label.text = "「%s」→ %s" % [label, result]

	if _event_panel != null:
		_event_panel.queue_free()
		_event_panel = null
	_overlay = null
	_current_event = null

	if _run.is_over:
		_hud.set_time_running(false)
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
			var offers: Array[CardData] = CardPool.new(_rng).roll(1)
			if offers.is_empty():
				return "卡池为空，什么也没得到"
			_run.add_card(offers[0].id)
			return "获得「%s」" % offers[0].display_name
		EventData.Effect.REMOVE_CARD:
			# 阶段 5 简化：随机移除一张。阶段 6 改成让玩家选。
			var deck: Array[CardData] = _run.build_deck()
			if deck.is_empty():
				return "牌组为空"
			var victim: CardData = deck[_rng.randi_range(0, deck.size() - 1)]
			_run.remove_card(victim.id)
			return "移除了「%s」" % victim.display_name
		_:
			return "什么也没发生"


# ── 弹层 ────────────────────────────────────────────────────

func _open_deck() -> void:
	if _overlay != null:
		return
	var panel := DeckViewPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(_run.build_deck())
	panel.closed.connect(_close_overlay)


func _open_relics() -> void:
	if _overlay != null:
		return
	var panel := RelicViewPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(_run.relics)
	panel.closed.connect(_close_overlay)


func _open_settings() -> void:
	if _overlay != null:
		return
	var panel := SettingsPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup()
	panel.closed.connect(_close_overlay)
	panel.return_to_title_pressed.connect(_on_save_and_exit)
	panel.quit_pressed.connect(func() -> void: get_tree().quit())


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


# ── 退出 ────────────────────────────────────────────────────

func _on_save_and_exit() -> void:
	SaveManager.save_run(_run, _map)
	_hud.set_time_running(false)
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


# ── 辅助 ────────────────────────────────────────────────────

func _card_name(card_id: StringName) -> String:
	var card: Variant = ContentRegistry.get_card(card_id)
	if card is CardData:
		return (card as CardData).display_name
	return String(card_id)
