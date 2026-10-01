class_name CardUpgradePanel
extends OverlayPanel
## 选择一张牌升级（休息点的「锻造」）
##
## ## 为什么既有卡面又有文字对比
## 用户反馈「看不见升级后的效果」——原因是卡面里的描述文字在窄容器里**被裁掉**了。
## 所以这里做两层：
##   1. 左右并排的卡面（直观，但依赖排版）
##   2. **一行纯文本数值对比**（`格挡 5 → 8`，不依赖任何排版，永远读得到）
## 关键信息不该只有一条读取路径。
##
## ⚠️ 右边展示的是 `create_upgraded()` 的**副本**——预览绝不能污染牌组里的真牌。

signal card_chosen(card_id: StringName)
signal cancelled

var _cards: Array[CardData] = []


func setup(cards: Array[CardData]) -> void:
	_cards = cards
	frame_min_width = 780
	rebuild_content()


func _build_content() -> void:
	add_node_banner(MapNode.Kind.REST, "锻造", "选择一张牌升级（%d 张可升级）" % _cards.size())
	add_separator()

	if _cards.is_empty():
		add_text("牌组里已经没有可升级的牌了。")
		add_separator()
		add_button("关闭（ESC）", _cancel)
		return

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(720, 0)
	scroll.add_child(box)

	for card: CardData in _cards:
		box.add_child(_make_comparison_row(card))

	add_separator()
	add_button("放弃（ESC）", _cancel)


## 一行 = [升级前] → [升级后]　[数值对比 + 升级按钮]
func _make_comparison_row(card: CardData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var before := CardView.new()
	# ⚠️ 必须 SHRIEK_CENTER：HBoxContainer 默认会把子节点**纵向拉伸**，
	# 卡面被拉高后内部描述文字会被挤出可见区域——这正是用户看不到效果的原因。
	before.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(before)
	before.set_card(card)
	before.set_playable(false)

	var arrow := Label.new()
	arrow.text = "→"
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.add_theme_color_override("font_color", UiPalette.GOLD)
	row.add_child(arrow)

	var after := CardView.new()
	after.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(after)
	after.set_card(card.create_upgraded())
	after.card_clicked.connect(_on_card_picked.bind(card.id))

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(210, 0)
	side.add_theme_constant_override("separation", 8)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)

	side.add_child(_make_diff_label(card))

	var upgrade_button := Button.new()
	upgrade_button.text = "升级这张"
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.pressed.connect(_on_upgrade_pressed.bind(card.id))
	side.add_child(upgrade_button)

	return row


## 纯文本数值对比。**不依赖卡面排版**——关键信息要有第二条读取路径。
func _make_diff_label(card: CardData) -> Label:
	var upgraded: CardData = card.create_upgraded()
	var parts: PackedStringArray = PackedStringArray()

	if card.damage > 0 or upgraded.damage > 0:
		parts.append("伤害 %d → %d" % [card.damage, upgraded.damage])
	if card.block > 0 or upgraded.block > 0:
		parts.append("格挡 %d → %d" % [card.block, upgraded.block])
	if card.draw > 0 or upgraded.draw > 0:
		parts.append("抽牌 %d → %d" % [card.draw, upgraded.draw])
	if card.gain_energy > 0 or upgraded.gain_energy > 0:
		parts.append("能量 %d → %d" % [card.gain_energy, upgraded.gain_energy])
	if card.self_hp_loss > 0 or upgraded.self_hp_loss > 0:
		parts.append("自伤 %d → %d" % [card.self_hp_loss, upgraded.self_hp_loss])

	_append_power_diff(parts, card.apply_to_self, upgraded.apply_to_self, "自身")
	_append_power_diff(parts, card.apply_to_target, upgraded.apply_to_target, "敌方")

	var label := Label.new()
	label.text = "、\n".join(parts) if not parts.is_empty() else "（无数值变化）"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(200, 0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UiPalette.GOLD)
	return label


func _append_power_diff(
	parts: PackedStringArray, before: Dictionary, after: Dictionary, scope: String
) -> void:
	for raw_key: Variant in before:
		var power_id := StringName(str(raw_key))
		var before_amount: int = int(before[raw_key])
		var after_amount: int = int(after.get(raw_key, before_amount))
		if before_amount == after_amount:
			continue

		# 用 PowerFactory 拿中文名——**单一数据源**，不在这里再抄一份映射表
		var power := PowerFactory.create(power_id, before_amount)
		var name_text: String = power.display_name if power != null else str(power_id)
		parts.append("%s%s %d → %d" % [scope, name_text, before_amount, after_amount])


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
