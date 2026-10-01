class_name CardUpgradePanel
extends OverlayPanel
## 选择一张牌升级（休息点的「锻造」）
##
## ⚠️ 网格里显示的是**升级后**的卡面——玩家要看到自己会得到什么，
## 而不是看到现在的样子再猜。这也是 `create_upgraded()` 返回副本而不是
## 原地修改的原因：预览不能污染牌组里的真牌。

signal card_chosen(card_id: StringName)
signal cancelled

var _cards: Array[CardData] = []


func setup(cards: Array[CardData]) -> void:
	_cards = cards
	frame_min_width = 700
	rebuild_content()


func _build_content() -> void:
	add_title("锻造：选择一张牌升级（%d 张可升级）" % _cards.size())

	if _cards.is_empty():
		add_text("牌组里已经没有可升级的牌了。")
		add_separator()
		add_button("关闭（ESC）", _cancel)
		return

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for card: CardData in _cards:
		var view := CardView.new()
		grid.add_child(view)
		view.set_card(card.create_upgraded())
		view.card_clicked.connect(_on_card_picked.bind(card.id))

	add_separator()
	add_button("放弃（ESC）", _cancel)


## `card_clicked` 传来的是**升级后的预览副本**，真正要升级的是原始 id
func _on_card_picked(_displayed: CardData, original_id: StringName) -> void:
	card_chosen.emit(original_id)
	queue_free()


func _cancel() -> void:
	cancelled.emit()
	queue_free()
