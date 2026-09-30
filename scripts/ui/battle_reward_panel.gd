class_name BattleRewardPanel
extends OverlayPanel
## 战斗结算界面（用户要求：「可以获得卡牌、金币、药水等资源，选择完后进入地图」）
##
## ## 为什么所有选择在内部累积，点「继续」才一次性返回
## 如果做成「点一下发一个信号」，场景就得在多个回调之间维护中间状态；
## 更要命的是玩家还没点「继续」就已经改动了 RunState——
## 这时候关掉游戏或崩溃，就会留下一个半成品存档（拿了金币但没拿牌）。
## 一次性返回让「结算」成为一个**原子操作**。

signal finished(result: Dictionary)

var _gold: int = 0
var _potion_id: StringName = &""
var _offers: Array[CardData] = []
var _potion_available: bool = true

var _chosen_card: StringName = &""
var _take_potion: bool = false

var _potion_button: Button
var _continue_button: Button


func setup(gold: int, potion_id: StringName, offers: Array[CardData], potion_available: bool) -> void:
	_gold = gold
	_potion_id = potion_id
	_offers = offers
	_potion_available = potion_available
	_chosen_card = &""
	_take_potion = false
	frame_min_width = 560
	rebuild_content()


func _build_content() -> void:
	add_title("战斗胜利")

	add_text("获得金币：%d" % _gold)

	_potion_button = add_button(_potion_label_text(), _on_potion_pressed)
	_potion_button.disabled = _potion_id == &"" or not _potion_available

	add_separator()
	add_title("选择一张牌加入牌组")

	if _offers.is_empty():
		add_text("（本次没有卡牌奖励）")
	else:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		content_box.add_child(row)
		for card: CardData in _offers:
			var view := CardView.new()
			row.add_child(view)
			view.set_card(card)
			view.card_clicked.connect(_on_card_picked)

	add_separator()
	_continue_button = add_button("继续（不选牌）", _on_continue_pressed)
	_refresh_continue_label()


func _potion_label_text() -> String:
	if _potion_id == &"":
		return "（本次没有药水）"
	var data: Variant = ContentRegistry.get_potion(_potion_id)
	var name_text: String = (data as PotionData).display_name if data is PotionData else String(_potion_id)
	if not _potion_available:
		return "%s —— 药水栏已满，无法拾取" % name_text
	return "%s：%s　［点击拾取］" % [
		name_text, (data as PotionData).description if data is PotionData else "",
	]


func _refresh_continue_label() -> void:
	if _continue_button == null:
		return
	if _chosen_card == &"":
		_continue_button.text = "继续（不选牌）"
	else:
		var data: Variant = ContentRegistry.get_card(_chosen_card)
		var name_text: String = (data as CardData).display_name if data is CardData else String(_chosen_card)
		_continue_button.text = "继续（已选「%s」）" % name_text


func _on_potion_pressed() -> void:
	_take_potion = not _take_potion
	if _potion_button != null:
		_potion_button.text = ("已拾取：" if _take_potion else "") + _potion_label_text()


func _on_card_picked(card: CardData) -> void:
	# 再点同一张 = 取消选择（玩家改主意不该被迫重开界面）
	_chosen_card = &"" if _chosen_card == card.id else card.id
	_refresh_continue_label()


func _on_continue_pressed() -> void:
	finished.emit({
		"gold": _gold,
		"card_id": _chosen_card,
		"potion_id": _potion_id if _take_potion else &"",
	})
	queue_free()
