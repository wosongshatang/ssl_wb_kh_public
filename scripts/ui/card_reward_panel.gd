class_name CardRewardPanel
extends OverlayPanel
## 卡牌奖励弹层（战斗胜利 / 事件奖励共用）
##
## 只发信号，不碰 RunState——把「选了哪张牌」抛给组合根去处理。

signal card_chosen(card_id: StringName)
signal skipped

var _offers: Array[CardData] = []
var _title: String = "选择一张牌"
var _allow_skip: bool = true


func _build_content() -> void:
	add_title(_title)

	for card: CardData in _offers:
		add_button(_card_label(card), _on_card_pressed.bind(card.id))

	if _allow_skip:
		add_separator()
		add_button("跳过（不拿牌）", func() -> void: skipped.emit())


func setup(title: String, offers: Array[CardData], allow_skip: bool = true) -> void:
	_title = title
	_offers = offers
	_allow_skip = allow_skip
	rebuild_content()


func _card_label(card: CardData) -> String:
	var rarity_tag: String = ""
	match card.rarity:
		2:
			rarity_tag = "【稀有】"
		1:
			rarity_tag = "【罕见】"
		_:
			pass
	return "%s%s（%d 费）\n%s" % [rarity_tag, card.display_name, card.cost, card.description]


func _on_card_pressed(card_id: StringName) -> void:
	card_chosen.emit(card_id)
