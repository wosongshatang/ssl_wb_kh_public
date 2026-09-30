class_name DeckViewPanel
extends OverlayPanel
## 牌组查看弹层（HUD 的「牌组」按钮 / 快捷键 D）
##
## 按类型分组展示全部卡牌，用真正的 [CardView] 渲染——
## 复用卡面控件而不是另画一套列表，保证「这里看到的牌」与「手里打出的牌」
## 长得完全一样，玩家不用二次学习。

var _cards: Array[CardData] = []
var _title: String = "牌组"


func setup(deck_cards: Array[CardData], title: String = "牌组") -> void:
	_cards = deck_cards
	_title = title
	frame_min_width = 700
	rebuild_content()


func _build_content() -> void:
	add_title("%s（%d 张）" % [_title, _cards.size()])

	if _cards.is_empty():
		add_text("牌组是空的。")
		add_separator()
		add_button("关闭（ESC）", _close)
		return

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for card: CardData in _sorted_cards():
		var view := CardView.new()
		view.is_playable = true
		grid.add_child(view)
		view.set_card(card)

	add_separator()
	add_button("关闭（ESC）", _close)


## 按「攻击 → 技能 → 能力」，同类内按费用升序。
## 排序是为了让玩家一眼看清费用曲线——这是构筑时最需要的信息。
func _sorted_cards() -> Array[CardData]:
	var sorted: Array[CardData] = _cards.duplicate()
	sorted.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.type != b.type:
			return a.type < b.type
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.display_name < b.display_name)
	return sorted


func _close() -> void:
	closed.emit()
	queue_free()
