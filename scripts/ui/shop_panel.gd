class_name ShopPanel
extends OverlayPanel
## 商店弹层
##
## 两种页面（商品 / 删牌）用 `_mode` 切换，而不是叠两个面板——
## 商店是单线程操作，同一时刻只该有一个页面，叠面板会带来焦点与遮挡问题。
##
## 只发信号，不碰 RunState：金币是否够、买了之后怎么记账，全交给组合根。

signal purchase_requested(card_id: StringName, price: int)
signal removal_requested(card_id: StringName, price: int)
signal closed

enum Mode { OFFERS, REMOVAL }

const REMOVAL_PRICE: int = 75

var _mode: Mode = Mode.OFFERS
var _gold: int = 0
var _offers: Array[CardData] = []
var _deck: Array[CardData] = []


func setup(gold: int, offers: Array[CardData], deck: Array[CardData]) -> void:
	_gold = gold
	_offers = offers
	_deck = deck
	_mode = Mode.OFFERS
	rebuild_content()


func _build_content() -> void:
	add_title("商店")
	add_text("金币：%d" % _gold)
	add_separator()

	if _mode == Mode.OFFERS:
		_build_offers()
	else:
		_build_removal()


func _build_offers() -> void:
	if _offers.is_empty():
		add_text("（货架已空）")

	for card: CardData in _offers:
		var price: int = CardPool.price_of(card)
		var suffix: String = "" if price <= _gold else "　—　金币不足"
		add_button("%s（%d 费）　%d 金币%s\n%s" % [
			card.display_name, card.cost, price, suffix, card.description,
		], _on_buy_pressed.bind(card.id, price))

	add_separator()
	add_button("删除一张牌（%d 金币）" % REMOVAL_PRICE, _on_open_removal_pressed)
	add_button("离开商店", func() -> void: closed.emit())


func _build_removal() -> void:
	add_text("选择要移除的牌（%d 金币）：" % REMOVAL_PRICE)
	if _deck.is_empty():
		add_text("（牌组为空）")

	for card: CardData in _deck:
		add_button("%s（%d 费）" % [card.display_name, card.cost], _on_remove_pressed.bind(card.id))

	add_separator()
	add_button("返回商品页", _on_back_to_offers_pressed)


func _on_buy_pressed(card_id: StringName, price: int) -> void:
	if price > _gold:
		return
	purchase_requested.emit(card_id, price)


func _on_open_removal_pressed() -> void:
	_mode = Mode.REMOVAL
	rebuild_content()


func _on_back_to_offers_pressed() -> void:
	_mode = Mode.OFFERS
	rebuild_content()


func _on_remove_pressed(card_id: StringName) -> void:
	if REMOVAL_PRICE > _gold:
		return
	removal_requested.emit(card_id, REMOVAL_PRICE)
