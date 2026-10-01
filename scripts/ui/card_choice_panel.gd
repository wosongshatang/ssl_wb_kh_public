class_name CardChoicePanel
extends OverlayPanel
## 从若干张牌里选一张（结算界面 / 药水 / 转职 / 后续更多流程共用）
##
## 与 [RewardUI] 的分工：
##   - `RewardUI` 是**战斗结算整屏**（金币 + 药水 + 遗物 + 卡牌一起给）
##   - 本类是**纯粹的选牌**，可以嵌在任何流程里
## 两者都用 [CardView] 渲染，玩家看到的牌长得一样。

signal card_chosen(card_id: StringName)
signal cancelled

var _cards: Array[CardData] = []
var _title: String = "选择一张牌"
var _allow_cancel: bool = false


func setup(title: String, cards: Array[CardData], allow_cancel: bool = false) -> void:
	_title = title
	_cards = cards
	_allow_cancel = allow_cancel
	frame_min_width = 500
	rebuild_content()


func _build_content() -> void:
	add_title(_title)

	if _cards.is_empty():
		add_text("（没有可选的牌）")
		add_separator()
		add_button("关闭（ESC）", _cancel)
		return

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	content_box.add_child(row)

	for card: CardData in _cards:
		var view := CardView.new()
		row.add_child(view)
		view.set_card(card)
		view.card_clicked.connect(_on_card_picked)

	add_separator()
	if _allow_cancel:
		add_button("放弃", _cancel)
	else:
		add_text("（必须选择一张）")


func _on_card_picked(card: CardData) -> void:
	card_chosen.emit(card.id)
	queue_free()


func _cancel() -> void:
	cancelled.emit()
	queue_free()
