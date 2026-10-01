class_name PowerDetailPanel
extends OverlayPanel
## 状态详情（点击战斗单位上的状态图标时弹出）
##
## ## 为什么需要它
## 状态图标只显示「首字 + 层数」（如 `敏2`），没有地方解释它是什么意思。
## 玩家刚打出「步法」拿到敏捷，看到 `敏2` 完全不知道这 2 层在做什么——
## **看不到效果就等于没有效果**。
##
## ## 为什么列出全部状态而不是只列被点的那一个
## 玩家真正想问的是"我现在身上都有些什么"，而不是"这一个是什么"。

var _owner_name: String = ""
var _powers: Array[AbstractPower] = []


func setup(owner_name: String, powers: Array[AbstractPower]) -> void:
	_owner_name = owner_name
	_powers = powers
	frame_min_width = 460
	rebuild_content()


func _build_content() -> void:
	add_title("%s 的状态" % _owner_name)

	if _powers.is_empty():
		add_text("当前没有任何状态。")
		add_separator()
		add_button("关闭（ESC）", _close)
		return

	for power: AbstractPower in _powers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		content_box.add_child(row)

		var amount := Label.new()
		amount.text = "%d" % power.amount if power.amount > 0 else "—"
		amount.custom_minimum_size = Vector2(34, 0)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount.add_theme_font_size_override("font_size", 16)
		amount.add_theme_color_override("font_color",
			UiPalette.GOLD if power.is_identity else UiPalette.BLOCK_BLUE)
		row.add_child(amount)

		var text_box := VBoxContainer.new()
		text_box.add_theme_constant_override("separation", 1)
		row.add_child(text_box)

		var name_label := Label.new()
		name_label.text = "%s%s" % ["【身份】" if power.is_identity else "", power.display_name]
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color",
			UiPalette.GOLD if power.is_identity else UiPalette.TEXT)
		text_box.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = power.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(360, 0)
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
		text_box.add_child(desc_label)

	add_separator()
	add_button("关闭（ESC）", _close)


func _close() -> void:
	closed.emit()
	queue_free()
