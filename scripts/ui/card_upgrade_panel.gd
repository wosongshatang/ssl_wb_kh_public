class_name CardUpgradePanel
extends OverlayPanel
## 选择一张牌升级（休息点的「锻造」）
##
## ## 为什么是「升级前 → 升级后」并排
## 用户要求能**直观对比**再决定升哪张。只给升级后的卡面，玩家还得回忆
## 原来是什么样——而牌组里往往有好几张长得差不多的牌，回忆并不可靠。
## 并排放在一起，差异一眼可见。
##
## ⚠️ 右边展示的是 `create_upgraded()` 的**副本**——预览绝不能污染牌组里的真牌。

signal card_chosen(card_id: StringName)
signal cancelled

const ROW_CARD_COUNT: int = 2

var _cards: Array[CardData] = []


func setup(cards: Array[CardData]) -> void:
	_cards = cards
	frame_min_width = 620
	rebuild_content()


func _build_content() -> void:
	add_title("锻造：选择一张牌升级（%d 张可升级）" % _cards.size())

	if _cards.is_empty():
		add_text("牌组里已经没有可升级的牌了。")
		add_separator()
		add_button("关闭（ESC）", _cancel)
		return

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(540, 0)
	scroll.add_child(box)

	for card: CardData in _cards:
		box.add_child(_make_comparison_row(card))

	add_separator()
	add_button("放弃（ESC）", _cancel)


## 一行 = [升级前] → [升级后] + 升级按钮
func _make_comparison_row(card: CardData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var before := CardView.new()
	row.add_child(before)
	before.set_card(card)
	# 置灰表示"这是现状"——视觉上把注意力引向右边那张
	before.set_playable(false)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.add_theme_color_override("font_color", UiPalette.GOLD)
	row.add_child(arrow)

	var after := CardView.new()
	row.add_child(after)
	after.set_card(card.create_upgraded())
	after.card_clicked.connect(_on_card_picked.bind(card.id))

	var upgrade_button := Button.new()
	upgrade_button.text = "升级"
	upgrade_button.custom_minimum_size = Vector2(72, 40)
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.pressed.connect(_on_upgrade_pressed.bind(card.id))
	row.add_child(upgrade_button)

	return row


func _on_upgrade_pressed(card_id: StringName) -> void:
	card_chosen.emit(card_id)
	queue_free()


## 点右边的卡面也能升级（`card_clicked` 传来的是升级后的预览副本，
## 真正要升级的是原始 id）
func _on_card_picked(_displayed: CardData, original_id: StringName) -> void:
	card_chosen.emit(original_id)
	queue_free()


func _cancel() -> void:
	cancelled.emit()
	queue_free()
