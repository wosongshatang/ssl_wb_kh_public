class_name ShopPanel
extends OverlayPanel
## 商店弹层（**横式展开**）
##
## ## 为什么是横排而不是竖列
## 竖排列表在商品多的时候会拉得很长、还要滚动，而且**玩家没法一眼比较**。
## 卡牌横排 + 药水遗物各一行，配合顶部横幅里的金币，扫一眼就能决定买什么。
##
## ## 只发信号，不碰 RunState
## 金币够不够、买了之后怎么记账，全交给组合根。

signal purchase_requested(card_id: StringName, price: int)
signal removal_requested(card_id: StringName, price: int)
signal potion_purchase_requested(potion_id: StringName, price: int)
signal relic_purchase_requested(relic_id: StringName, price: int)
# 注意：`closed` 由基类 OverlayPanel 声明。
# ⚠️ 子类**不要**重复声明父类已有的信号——编译器会报
#    "Could not resolve external class member"，而且错误指向的是**使用方**。

enum Mode { OFFERS, REMOVAL }

const REMOVAL_PRICE: int = 75
const CARD_COLUMNS: int = 5

var _mode: Mode = Mode.OFFERS
var _gold: int = 0
var _offers: Array[CardData] = []
var _deck: Array[CardData] = []
var _potion_offers: Array[PotionData] = []
var _relic_offers: Array[StringName] = []


func setup(
	gold: int,
	offers: Array[CardData],
	deck: Array[CardData],
	potion_offers: Array[PotionData] = [],
	relic_offers: Array[StringName] = []
) -> void:
	_gold = gold
	_offers = offers
	_deck = deck
	_potion_offers = potion_offers
	_relic_offers = relic_offers
	_mode = Mode.OFFERS
	frame_min_width = 820
	rebuild_content()


func _build_content() -> void:
	add_node_banner(MapNode.Kind.SHOP, "商店", "你的金币：%d" % _gold)
	add_separator()

	if _mode == Mode.OFFERS:
		_build_offers()
	else:
		_build_removal()


# ══ 商品页 ══════════════════════════════════════════════════

func _build_offers() -> void:
	_build_card_shelf()
	_build_consumable_shelf()

	add_separator()
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	content_box.add_child(actions)

	var remove_button := Button.new()
	remove_button.text = "删除一张牌（%d 金币）" % REMOVAL_PRICE
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.disabled = _gold < REMOVAL_PRICE
	remove_button.pressed.connect(_on_open_removal_pressed)
	actions.add_child(remove_button)

	var leave_button := Button.new()
	leave_button.text = "离开商店"
	leave_button.focus_mode = Control.FOCUS_NONE
	leave_button.pressed.connect(func() -> void: closed.emit())
	actions.add_child(leave_button)


## 卡牌货架：横排卡面，每张下面一个价格按钮
func _build_card_shelf() -> void:
	add_title("卡牌")

	if _offers.is_empty():
		add_text("（卡牌已售罄）")
		return

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	content_box.add_child(row)

	for card: CardData in _offers:
		row.add_child(_make_card_slot(card))


func _make_card_slot(card: CardData) -> VBoxContainer:
	var price: int = CardPool.price_of(card)
	var affordable: bool = price <= _gold

	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 4)
	slot.alignment = BoxContainer.ALIGNMENT_CENTER

	var view := CardView.new()
	slot.add_child(view)
	view.set_card(card)
	# 买不起时卡面置灰——比只在按钮上写"金币不足"更直观
	view.set_playable(affordable)

	var buy := Button.new()
	buy.text = "%d 金币" % price
	buy.focus_mode = Control.FOCUS_NONE
	buy.disabled = not affordable
	buy.add_theme_font_size_override("font_size", 12)
	buy.pressed.connect(_on_buy_pressed.bind(card.id, price))
	slot.add_child(buy)

	return slot


## 消耗品货架：药水一行、遗物一行
func _build_consumable_shelf() -> void:
	if _potion_offers.is_empty() and _relic_offers.is_empty():
		return

	add_separator()

	if not _potion_offers.is_empty():
		add_title("药水")
		var potion_row := HBoxContainer.new()
		potion_row.alignment = BoxContainer.ALIGNMENT_CENTER
		potion_row.add_theme_constant_override("separation", 10)
		content_box.add_child(potion_row)
		for potion: PotionData in _potion_offers:
			potion_row.add_child(_make_potion_slot(potion))

	if not _relic_offers.is_empty():
		add_title("遗物")
		var relic_row := HBoxContainer.new()
		relic_row.alignment = BoxContainer.ALIGNMENT_CENTER
		relic_row.add_theme_constant_override("separation", 10)
		content_box.add_child(relic_row)
		for relic_id: StringName in _relic_offers:
			var slot := _make_relic_slot(relic_id)
			if slot != null:
				relic_row.add_child(slot)


func _make_potion_slot(potion: PotionData) -> VBoxContainer:
	var price: int = potion_price_of(potion)
	var affordable: bool = price <= _gold

	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 4)

	slot.add_child(_make_info_block(
		potion.display_name, potion.description, UiPalette.POTION, affordable))

	var buy := Button.new()
	buy.text = "%d 金币" % price
	buy.focus_mode = Control.FOCUS_NONE
	buy.disabled = not affordable
	buy.add_theme_font_size_override("font_size", 12)
	buy.pressed.connect(_on_buy_potion_pressed.bind(potion.id, price))
	slot.add_child(buy)

	return slot


func _make_relic_slot(relic_id: StringName) -> VBoxContainer:
	var loaded: Variant = ContentRegistry.get_relic(relic_id)
	if not (loaded is RelicData):
		return null

	var relic := loaded as RelicData
	var price: int = RelicFactory.price_of(relic_id)
	var affordable: bool = price <= _gold

	var slot := VBoxContainer.new()
	slot.add_theme_constant_override("separation", 4)

	var accent: Color = UiPalette.color_for_rarity(
		CardData.Rarity.EPIC if relic.is_divine() else CardData.Rarity.COMMON)
	slot.add_child(_make_info_block(relic.display_name, relic.description, accent, affordable))

	var trigger := Label.new()
	trigger.text = "触发：%s" % relic.trigger_text
	trigger.add_theme_font_size_override("font_size", 11)
	trigger.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	slot.add_child(trigger)

	var buy := Button.new()
	buy.text = "%d 金币" % price
	buy.focus_mode = Control.FOCUS_NONE
	buy.disabled = not affordable
	buy.add_theme_font_size_override("font_size", 12)
	buy.pressed.connect(_on_buy_relic_pressed.bind(relic_id, price))
	slot.add_child(buy)

	return slot


## 一块"名称 + 描述"的信息牌（药水与遗物共用，保证两者视觉一致）
func _make_info_block(
	title: String, body: String, accent: Color, affordable: bool
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 92)

	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.BG_PANEL if affordable else UiPalette.BG_SLOT
	style.border_color = accent if affordable else UiPalette.BORDER_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", accent.lightened(0.2))
	column.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(182, 0)
	body_label.add_theme_font_size_override("font_size", 11)
	body_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	column.add_child(body_label)

	return panel


# ══ 删牌页 ══════════════════════════════════════════════════

func _build_removal() -> void:
	add_title("选择要移除的牌（%d 金币）" % REMOVAL_PRICE)

	if _deck.is_empty():
		add_text("（牌组为空）")
		add_separator()
		add_button("返回商品页", _on_back_to_offers_pressed)
		return

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = CARD_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for card: CardData in _deck:
		var view := CardView.new()
		grid.add_child(view)
		view.set_card(card)
		# 无色卡 / 金卡删不掉——置灰让规则**看得见**
		view.set_playable(card.can_remove())
		view.card_clicked.connect(_on_remove_pressed.bind(card.id))

	add_separator()
	add_button("返回商品页", _on_back_to_offers_pressed)


# ══ 交互 ════════════════════════════════════════════════════

func _on_buy_pressed(card_id: StringName, price: int) -> void:
	if price > _gold:
		return
	purchase_requested.emit(card_id, price)


func _on_buy_potion_pressed(potion_id: StringName, price: int) -> void:
	if price > _gold:
		return
	potion_purchase_requested.emit(potion_id, price)


func _on_buy_relic_pressed(relic_id: StringName, price: int) -> void:
	if price > _gold:
		return
	relic_purchase_requested.emit(relic_id, price)


func _on_open_removal_pressed() -> void:
	if _gold < REMOVAL_PRICE:
		return
	_mode = Mode.REMOVAL
	rebuild_content()


func _on_back_to_offers_pressed() -> void:
	_mode = Mode.OFFERS
	rebuild_content()


func _on_remove_pressed(card_id: StringName) -> void:
	if _gold < REMOVAL_PRICE:
		return
	removal_requested.emit(card_id, REMOVAL_PRICE)


## 药水定价：稀有度越高越贵（与卡牌定价同一套思路）
static func potion_price_of(potion: PotionData) -> int:
	match potion.rarity:
		2:
			return 90
		1:
			return 62
		_:
			return 40
