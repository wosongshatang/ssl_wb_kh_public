class_name CharacterSelectPanel
extends OverlayPanel
## 角色选择（多角色前置 ③）
##
## ## 「能不能选」是**推导**出来的，不是写死的
## 判据是 `MapManager.LINES` 里有没有这个角色——
## 也就是说：**只要把某条线的数据补齐，这个角色自动可选**。
##
## 写死一个 `unlocked = true/false` 的话，加完法师线还要记得回来改这里，
## 而"忘了改"的表现是"内容做好了但玩家点不到"——**没有任何报错**。

signal character_chosen(character: StringName)

const CHARACTERS: Array[Dictionary] = [
	{
		"id": &"warrior",
		"name": "战士",
		"desc": "最直接的那条路。\n用格挡撑住，用力量压过去。",
		"color": Color(0.78, 0.32, 0.28),
	},
	{
		"id": &"mage",
		"name": "法师",
		"desc": "元素反应与奥术蓄力。\n把资源管线本身当成武器。",
		"color": Color(0.42, 0.55, 0.9),
	},
	{
		"id": &"hunter",
		"name": "猎人",
		"desc": "召唤兽与形态切换。\n你不是一个人在打。",
		"color": Color(0.45, 0.72, 0.5),
	},
]


func setup() -> void:
	frame_min_width = 760
	rebuild_content()


func _build_content() -> void:
	add_title("选择角色")

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	content_box.add_child(row)

	for entry: Dictionary in CHARACTERS:
		row.add_child(_make_character_card(entry))


func _make_character_card(entry: Dictionary) -> Control:
	var character_id: StringName = entry["id"]
	var available: bool = MapManager.LINES.has(character_id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 200)

	var accent: Color = entry["color"] as Color
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.BG_PANEL if available else UiPalette.BG_SLOT
	style.border_color = accent if available else UiPalette.BORDER_DIM
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)

	var name_label := Label.new()
	name_label.text = str(entry["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color",
		accent.lightened(0.3) if available else UiPalette.TEXT_DIM)
	column.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = str(entry["desc"])
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(190, 0)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	column.add_child(desc_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var action := Button.new()
	action.focus_mode = Control.FOCUS_NONE
	action.custom_minimum_size = Vector2(0, 38)
	if available:
		action.text = "开始"
		action.pressed.connect(_on_choose.bind(character_id))
	else:
		# 明确说出"为什么点不了"，而不是给一个灰按钮让玩家猜
		action.text = "尚未开放"
		action.disabled = true
	column.add_child(action)

	if not available:
		var note := Label.new()
		note.text = "该角色线尚未制作"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
		column.add_child(note)

	return card


func _on_choose(character_id: StringName) -> void:
	character_chosen.emit(character_id)
	queue_free()
