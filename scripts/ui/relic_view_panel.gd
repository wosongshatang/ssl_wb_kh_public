class_name RelicViewPanel
extends OverlayPanel
## 遗物查看弹层（HUD 的「遗物」按钮 —— 用户要求"点击就展示遗物在下部"）
##
## 遗物只有名字 + 描述，所以用列表而不是卡面。
## 阶段 5 无图标资源，用一个按分类着色的方块占位。

var _relic_ids: Array[StringName] = []


func setup(relic_ids: Array[StringName]) -> void:
	_relic_ids = relic_ids
	frame_min_width = 460
	rebuild_content()


func _build_content() -> void:
	add_title("遗物（%d）" % _relic_ids.size())

	if _relic_ids.is_empty():
		add_text("尚未获得任何遗物。")
		add_separator()
		add_button("关闭（ESC）", _close)
		return

	for relic_id: StringName in _relic_ids:
		var data: Variant = ContentRegistry.get_relic(relic_id)
		if not (data is RelicData):
			add_text("？未知遗物「%s」" % relic_id)
			continue
		var relic := data as RelicData
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		content_box.add_child(row)

		row.add_child(_make_icon(relic))

		var text_box := VBoxContainer.new()
		text_box.add_theme_constant_override("separation", 2)
		row.add_child(text_box)

		var name_label := Label.new()
		name_label.text = "%s%s" % ["【神格】" if relic.is_divine() else "", relic.display_name]
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", UiPalette.GOLD)
		text_box.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = relic.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(360, 0)
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
		text_box.add_child(desc_label)

	add_separator()
	add_button("关闭（ESC）", _close)


## 遗物图标占位：分类着色的方块（阶段 8 换成真图）
func _make_icon(relic: RelicData) -> Control:
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size = Vector2(36, 36)
	match relic.category:
		RelicData.Category.DIVINE:
			icon.color = UiPalette.color_for_rarity(CardData.Rarity.EPIC)
		RelicData.Category.JOB:
			icon.color = UiPalette.TINT_SKILL.lightened(0.2)
		_:
			icon.color = UiPalette.color_for_rarity(CardData.Rarity.COMMON)
	return icon


func _close() -> void:
	closed.emit()
	queue_free()
