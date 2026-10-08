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
var _potion_offers: Array[PotionData] = []
var _relic_offers: Array[StringName] = []
var _current_event: EventData = null


func _ready() -> void:
	_run = GameState.run
	_map = GameState.map

	if _run == null or _map == null:
		GameState.start_new_run(&"warrior", randi())
		_run = GameState.run
		_map = GameState.map

	_build_ui()
	# ⚠️ 必须**立刻**调一次 _layout()。只连接 size_changed 是不够的——
	#    那要等到窗口尺寸变化才触发，而初始布局永远等不到。
	#    症状：地图视图尺寸停在 (0,0)，`_recompute_positions()` 算不出坐标，
	#    整张地图空白。这是个"看起来在跑、其实什么都没画"的典型 bug。
	_layout()
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
	_save_button.text = "返回标题"
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
	_hud.potion_pressed.connect(_on_potion_clicked)
	_hud.potion_double_clicked.connect(_on_potion_double_clicked)
	# 地图上没有战斗，日志按钮无意义
	_hud.set_log_available(false)


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

	# ⚠️ 存档必须在 `enter_node` **之前**。
	#
	# `enter_node` 会把节点标记为已访问并把它设为当前位置。先 enter 再存，
	# SL 之后就回不到"进入这个节点之前"了——用户报告的正是这个：
	# 商店买错了想读档，回来发现商店节点已经结算完了。
	#
	# 这是「**进节点前留一个检查点**」的通用做法，商店 / 事件 / 休息 / 战斗都适用。
	SaveManager.save_run(_run, _map)

	if not _map.enter_node(node_id):
		return

	_reseed_rng()
	var node: MapNode = _map.nodes[node_id]

	match node.kind:
		MapNode.Kind.COMBAT, MapNode.Kind.ELITE, MapNode.Kind.BOSS:
			# 再存一次：此时节点已标记访问 + `in_battle` 置位，
			# 让「继续游戏」能**直接回到这场战斗**而不是回到地图再点一次
			_run.in_battle = true
			SaveManager.save_run(_run, _map)
			_hud.set_time_running(false)
			get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")

		MapNode.Kind.REST:
			_open_rest()

		MapNode.Kind.SHOP:
			_open_shop()

		MapNode.Kind.EVENT:
			_open_event(node)

		MapNode.Kind.GOD_ALTAR:
			_open_god_altar()

		MapNode.Kind.TRAITOR:
			_open_traitor()

		_:
			_persist_and_refresh("「%s」尚未实现。" % node.kind_label())


## ⚠️ 结果文本必须在 `_refresh()` **之后**写——`_refresh()` 会重设 `_hint_label.text`。
## 之前把结果写在 `_refresh()` 之前，玩家点了休息看不到任何反馈：
## 血确实回了，但提示立刻被"当前位置：休息"覆盖掉，看起来就是**点了没反应**。
## `save = false` 用于**节点内部的全部操作**（买东西 / 休息 / 事件 / 锻造 / 神坛 / 叛神者）。
##
## **整个节点对玩家是原子的**：要么全接受，要么读档重来。
##
## ⚠️ 为什么中间操作不能落盘：
## 存档时机是「**进入节点时**」——那是玩家 SL 的锚点。
## 如果买一件东西就存一次，SL 就回不到"进商店之前"，
## 玩家买错了没有任何补救手段（用户实际遇到的就是这个）。
##
## 节点**离开时**才落盘，所以整个节点对玩家是**原子的**：
## 要么全接受，要么读档重来。
func _persist_and_refresh(result: String = "", save: bool = true) -> void:
	if save:
		SaveManager.save_run(_run, _map)
	_refresh()
	if result != "":
		_hint_label.text = result


# ── 休息点 ──────────────────────────────────────────────────

func _open_rest() -> void:
	if _overlay != null:
		return

	var heal_amount: int = int(ceil(float(_run.max_hp) * RestChoicePanel.HEAL_RATIO))
	var panel := RestChoicePanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(heal_amount, _run.max_hp, _run.upgradable_card_ids().size())
	panel.rest_chosen.connect(_on_rest_chosen)
	panel.upgrade_chosen.connect(_on_forge_chosen)
	panel.cancelled.connect(_close_overlay)


func _on_rest_chosen() -> void:
	_close_overlay()
	var healed: int = int(ceil(float(_run.max_hp) * RestChoicePanel.HEAL_RATIO))
	_run.heal(healed)
	_persist_and_refresh("休息：回复 %d 点生命。" % healed, false)


func _on_forge_chosen() -> void:
	_close_overlay()
	_open_forge()


func _open_forge() -> void:
	var cards: Array[CardData] = []
	for card_id: StringName in _run.upgradable_card_ids():
		var loaded: Variant = ContentRegistry.get_card(card_id)
		if loaded is CardData:
			cards.append(loaded as CardData)

	if cards.is_empty():
		_persist_and_refresh("牌组里没有可升级的牌。")
		return

	var panel := CardUpgradePanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(cards)
	panel.card_chosen.connect(_on_upgrade_card_chosen)
	panel.cancelled.connect(_close_overlay)


## ── 神坛（P6-10）────────────────────────────────────────────
func _open_god_altar() -> void:
	if _overlay != null:
		return
	var panel := GodAltarPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(_run.max_hp)
	panel.sacrifice_chosen.connect(_on_altar_sacrifice)
	panel.leave_chosen.connect(_on_altar_leave)
	panel.closed.connect(_close_overlay)


func _on_altar_sacrifice() -> void:
	_close_overlay()
	_run.hp = maxi(1, _run.hp - int(ceil(float(_run.max_hp) * GodAltarPanel.HP_COST_RATIO)))
	_run.bonus_strength += GodAltarPanel.STRENGTH_GAIN
	GameState.add_divinity(GodAltarPanel.DIVINITY_GAIN)
	_persist_and_refresh("献祭了 %d 点生命，获得 %d 点永久力量（神性 +%d）。" % [
		int(ceil(float(_run.max_hp) * GodAltarPanel.HP_COST_RATIO)),
		GodAltarPanel.STRENGTH_GAIN, GodAltarPanel.DIVINITY_GAIN,
	], false)


func _on_altar_leave() -> void:
	_close_overlay()
	_run.heal(maxi(1, int(ceil(float(_run.max_hp) * GodAltarPanel.LEAVE_HEAL_RATIO))))
	_persist_and_refresh("你没有伸手。", false)


## ── 叛神者（P6-10）──────────────────────────────────────────
func _open_traitor() -> void:
	if _overlay != null:
		return
	var panel := TraitorPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup()
	panel.strip_chosen.connect(_on_traitor_strip)
	panel.deepen_chosen.connect(_on_traitor_deepen)
	panel.leave_chosen.connect(_close_overlay)
	panel.closed.connect(_close_overlay)


func _on_traitor_strip() -> void:
	_close_overlay()
	GameState.add_divinity(-TraitorPanel.DIVINITY_DELTA)

	var pool: Array[StringName] = RelicFactory.droppable_ids(_run.relics)
	if pool.is_empty():
		_persist_and_refresh("神性 -%d，但没有可拿的遗物了。" % TraitorPanel.DIVINITY_DELTA, false)
		return

	var relic_id: StringName = pool[_rng.randi_range(0, pool.size() - 1)]
	_run.grant_relic(relic_id)
	_persist_and_refresh("剥离了神性（-%d），获得遗物「%s」。" % [
		TraitorPanel.DIVINITY_DELTA, _relic_name(relic_id)], false)


func _on_traitor_deepen() -> void:
	_close_overlay()
	GameState.add_divinity(TraitorPanel.DIVINITY_DELTA)

	var granted: int = 0
	for _i: int in 2:
		var potion_pool: Array[StringName] = ContentRegistry.all_potion_ids()
		if potion_pool.is_empty():
			break
		var potion_id: StringName = potion_pool[_rng.randi_range(0, potion_pool.size() - 1)]
		if _run.add_potion(potion_id):
			granted += 1

	_persist_and_refresh("神性 +%d，获得 %d 瓶药水。" % [
		TraitorPanel.DIVINITY_DELTA, granted], false)


func _on_upgrade_card_chosen(card_id: StringName) -> void:
	_close_overlay()
	if _run.upgrade_card(card_id):
		_persist_and_refresh("锻造：升级了「%s」。" % _card_name(card_id), false)
	else:
		_persist_and_refresh("升级失败——这张牌可能已经升级过了。", false)


# ── 药水 ────────────────────────────────────────────────────

## 单击：查看信息，不消耗
func _on_potion_clicked(slot_index: int) -> void:
	if _overlay != null:
		return
	var potion: PotionData = _potion_at(slot_index)
	if potion == null:
		return

	# 地图上恒为 in_battle = false、无敌人
	var blocked: String = PotionResolver.can_use(potion, false, false)

	var panel := PotionInfoPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(potion, slot_index, blocked)
	panel.use_requested.connect(_on_potion_use_requested)
	panel.closed.connect(_close_overlay)


func _on_potion_use_requested(slot_index: int) -> void:
	_close_overlay()
	_use_potion_on_self(slot_index)


## 双击：直接使用（通用式药水）
func _on_potion_double_clicked(slot_index: int) -> void:
	_use_potion_on_self(slot_index)


func _potion_at(slot_index: int) -> PotionData:
	if slot_index < 0 or slot_index >= _run.potions.size():
		return null
	var loaded: Variant = ContentRegistry.get_potion(_run.potions[slot_index])
	if loaded is PotionData:
		return loaded as PotionData
	return null


func _use_potion_on_self(slot_index: int) -> void:
	var potion: PotionData = _potion_at(slot_index)
	if potion == null:
		return

	var blocked: String = PotionResolver.can_use(potion, false, false)
	if blocked != "":
		_hint_label.text = "%s 现在用不了：%s" % [potion.display_name, blocked]
		return

	# 地图上没有战斗实体，用一个**临时 Creature 代理**来承接效果。
	# 为什么不用 if-else 直接改 RunState：药水效果的定义在 PotionResolver 里，
	# 地图再写一套"只能回血"的简化版，两边会慢慢走偏——
	# 以后加了「回复类」新药水，地图上就会莫名其妙用不了。
	var proxy := Creature.new()
	proxy.max_hp = _run.max_hp
	proxy.reset_for_battle()
	proxy.set_hp(_run.hp)

	var result := PotionResolver.apply(potion, proxy, null, null, _rng)
	if not result.success:
		proxy.free()
		_hint_label.text = "%s 用不了：%s" % [potion.display_name, result.message]
		return

	_run.sync_from_creature(proxy)
	proxy.free()

	_run.remove_potion_at(slot_index)
	_hint_label.text = "使用 %s：%s" % [potion.display_name, result.message]
	_persist_and_refresh()


# ── 商店 ────────────────────────────────────────────────────

func _open_shop() -> void:
	var pool := CardPool.new(_rng, _run.character_class)
	_shop_offers = pool.roll(CardPool.SHOP_OFFER_COUNT)
	_potion_offers = _roll_potion_offers(2)
	_relic_offers = _roll_relic_offers(2)
	_show_shop()


## 抽 count 件**不重复**的普通遗物当货架。
## 神格遗物与职业遗物不进商店——前者只能窃取，后者只能转职获得。
func _roll_relic_offers(count: int) -> Array[StringName]:
	var pool: Array[StringName] = RelicFactory.droppable_ids(_run.relics)
	var out: Array[StringName] = []
	while out.size() < count and not pool.is_empty():
		var index: int = _rng.randi_range(0, pool.size() - 1)
		out.append(pool[index])
		pool.remove_at(index)
	return out


## 抽 count 瓶**不重复**的药水当货架
func _roll_potion_offers(count: int) -> Array[PotionData]:
	var out: Array[PotionData] = []
	var pool: Array[StringName] = ContentRegistry.all_potion_ids()

	while out.size() < count and not pool.is_empty():
		var index: int = _rng.randi_range(0, pool.size() - 1)
		var loaded: Variant = ContentRegistry.get_potion(pool[index])
		pool.remove_at(index)
		if loaded is PotionData:
			out.append(loaded as PotionData)

	return out


func _show_shop() -> void:
	_close_shop()
	_shop_panel = ShopPanel.new()
	_overlay = _shop_panel
	_shop_panel.setup(_run.gold, _shop_offers, _run.build_deck(), _potion_offers, _relic_offers)
	_shop_panel.purchase_requested.connect(_on_purchase_requested)
	_shop_panel.removal_requested.connect(_on_removal_requested)
	_shop_panel.potion_purchase_requested.connect(_on_potion_purchase_requested)
	_shop_panel.relic_purchase_requested.connect(_on_relic_purchase_requested)
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


## ⚠️ **先删、成功才扣钱**。
##
## 反过来（先扣钱再删）的话，删不掉的情况会让玩家**为一次没发生的操作付钱**：
## 无色卡 / 金卡删不掉，但钱已经扣了。
## 与「药水先结算再消耗」是同一条规则（D29）：**失败的操作不该有代价**。
func _on_removal_requested(card_id: StringName, price: int) -> void:
	if _run.gold < price:
		return

	if not _run.remove_card(card_id):
		_hint_label.text = "「%s」无法删除（神赐之牌与专属卡刻进灵魂）。" % _card_name(card_id)
		_hud.refresh()
		_show_shop()
		return

	_run.spend_gold(price)
	_hint_label.text = "移除了「%s」（花费 %d 金币）。" % [_card_name(card_id), price]
	_hud.refresh()
	_show_shop()


## ⚠️ **离开商店不落盘**。
##
## 存档时机是「**进入节点时**」——那是玩家的 SL 锚点。
## 如果离开商店就存一次，玩家在商店里买错东西、离开后再退出，
## SL 就会跳过这个节点（用户实际遇到的就是这个）。
##
## 节点结果**在进入下一个节点时才提交**：
## 那时 `_on_node_selected` 存的检查点自然包含了上一个节点的结果。
func _on_shop_closed() -> void:
	_close_shop()
	_persist_and_refresh("", false)


func _on_potion_purchase_requested(potion_id: StringName, price: int) -> void:
	# 药水栏满了必须先喝掉一瓶——**不能默默买下来再丢弃**
	if _run.is_potion_bar_full():
		_hint_label.text = "药水栏已满，先喝掉一瓶再来买。"
		_show_shop()
		return

	if not _run.spend_gold(price):
		return

	_run.add_potion(potion_id)
	for i: int in range(_potion_offers.size() - 1, -1, -1):
		if _potion_offers[i].id == potion_id:
			_potion_offers.remove_at(i)
			break

	_hint_label.text = "购买了「%s」（花费 %d 金币）。" % [_potion_name(potion_id), price]
	_hud.refresh()
	_show_shop()


func _on_relic_purchase_requested(relic_id: StringName, price: int) -> void:
	if not _run.spend_gold(price):
		return

	_run.grant_relic(relic_id)
	for i: int in range(_relic_offers.size() - 1, -1, -1):
		if _relic_offers[i] == relic_id:
			_relic_offers.remove_at(i)
			break

	_hint_label.text = "购买了遗物「%s」（花费 %d 金币）。" % [_relic_name(relic_id), price]
	_hud.refresh()
	_show_shop()


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


## ⚠️ **消费即置空**：`_current_event` 必须在进入处理时立刻清掉。
##
## 不清的话，快速双击会让**两个选项都触发**——玩家白拿两份收益。
## `queue_free()` 是延迟的，所以"面板关了"并不能保证信号只发一次。
func _on_event_option_chosen(index: int) -> void:
	if _current_event == null:
		return

	var event: EventData = _current_event
	_current_event = null   # 立刻消费，防止重复触发

	var label: String = ""
	var effect: EventData.Effect = EventData.Effect.NONE
	var value: int = 0

	if index == 0:
		label = event.option_a_label
		effect = event.option_a_effect
		value = event.option_a_value
	else:
		label = event.option_b_label
		effect = event.option_b_effect
		value = event.option_b_value

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

	_persist_and_refresh("", false)


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
			var offers: Array[CardData] = CardPool.new(_rng, _run.character_class).roll(1)
			if offers.is_empty():
				return "卡池为空，什么也没得到"
			_run.add_card(offers[0].id)
			return "获得「%s」" % offers[0].display_name
		EventData.Effect.ADD_POTION:
			var pool: Array[StringName] = ContentRegistry.all_potion_ids()
			if pool.is_empty():
				return "没有可获得的药水"
			if _run.is_potion_bar_full():
				return "药水栏已满，什么也没拿到"
			var potion_id: StringName = pool[_rng.randi_range(0, pool.size() - 1)]
			if not _run.add_potion(potion_id):
				return "药水栏已满，什么也没拿到"
			return "获得「%s」" % _potion_name(potion_id)

		EventData.Effect.ADD_DIVINE_CARD:
			var deity: StringName = _current_event.deity_id
			var divine_pool: Array[CardData] = ContentRegistry.divine_cards_for(deity)
			if divine_pool.is_empty():
				return "没有可赠予的无色卡"
			var divine: CardData = divine_pool[_rng.randi_range(0, divine_pool.size() - 1)]
			_run.add_card(divine.id)
			# 神明的赠礼都有代价：拿卡的同时神性上涨
			GameState.add_divinity(divine.divinity_gain)
			return "获得「%s」（神性 +%d）" % [divine.display_name, divine.divinity_gain]

		EventData.Effect.ADD_SPECIAL_CARD:
			var special_pool: Array[CardData] = ContentRegistry.special_cards()
			if special_pool.is_empty():
				return "没有可获得的神赐之牌"
			var special: CardData = special_pool[_rng.randi_range(0, special_pool.size() - 1)]
			_run.add_card(special.id)
			if special.divinity_gain > 0:
				GameState.add_divinity(special.divinity_gain)
			return "获得神赐之牌「%s」%s" % [
				special.display_name,
				"（神性 +%d）" % special.divinity_gain if special.divinity_gain > 0 else "",
			]

		EventData.Effect.ADD_CURSE_CARD:
			var curse_pool: Array[CardData] = ContentRegistry.curse_cards()
			if curse_pool.is_empty():
				return "没有可获得的诅咒卡"
			var curse: CardData = curse_pool[_rng.randi_range(0, curse_pool.size() - 1)]
			_run.add_card(curse.id)
			return "获得诅咒「%s」" % curse.display_name

		EventData.Effect.ADD_RELIC:
			var relic_pool: Array[StringName] = RelicFactory.droppable_ids(_run.relics)
			if relic_pool.is_empty():
				return "没有可获得的遗物了"
			var relic_id: StringName = relic_pool[_rng.randi_range(0, relic_pool.size() - 1)]
			_run.grant_relic(relic_id)
			return "获得遗物「%s」" % _relic_name(relic_id)

		EventData.Effect.ADD_DIVINE_RELIC:
			# 窃权事件：神格遗物**只能**从这里来（不进普通掉落池）
			var divine_pool: Array[StringName] = RelicFactory.divine_ids(_run.relics)
			if divine_pool.is_empty():
				return "已经没有可窃取的权柄了"
			var divine_id: StringName = divine_pool[_rng.randi_range(0, divine_pool.size() - 1)]
			_run.grant_relic(divine_id)
			var relic_data: Variant = ContentRegistry.get_relic(divine_id)
			var cost: int = (relic_data as RelicData).divinity_cost if relic_data is RelicData else 0
			GameState.add_divinity(cost)
			return "窃得「%s」（神性 +%d）" % [_relic_name(divine_id), cost]

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

## 返回标题。
##
## ## ⚠️ 这里**绝对不能存档**——这是 SL 能不能用的关键
## 存档时机是「**进入节点时**」，那是玩家的 SL 锚点。
## 玩家在商店里买错了东西、想读档重来——如果此时退出时存一次，
## 存下去的会是"节点已访问"的状态，SL 之后就**直接跳过这个节点**了。
##
## 换句话说：**"退出时保存"会亲手毁掉玩家唯一的补救手段。**
## 该存的地方（进节点 / 开战 / 结算）都已经存过了，这里什么都不用做。
func _on_save_and_exit() -> void:
	_hud.set_time_running(false)
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


# ── 辅助 ────────────────────────────────────────────────────

func _card_name(card_id: StringName) -> String:
	var card: Variant = ContentRegistry.get_card(card_id)
	if card is CardData:
		return (card as CardData).display_name
	return String(card_id)


func _potion_name(potion_id: StringName) -> String:
	var potion: Variant = ContentRegistry.get_potion(potion_id)
	if potion is PotionData:
		return (potion as PotionData).display_name
	return String(potion_id)


func _relic_name(relic_id: StringName) -> String:
	var relic: Variant = ContentRegistry.get_relic(relic_id)
	if relic is RelicData:
		return (relic as RelicData).display_name
	return String(relic_id)
