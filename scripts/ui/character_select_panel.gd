class_name CharacterSelectPanel
extends OverlayPanel
## 角色选择 + **进阶等级选择**（阶段 10）
##
## ## 「能不能选」是**推导**出来的，不是写死的
## 判据是 `MapManager.LINES` 里有没有这个角色——
## 也就是说：**只要把某条线的数据补齐，这个角色自动可选**。
##
## 写死一个 `unlocked = true/false` 的话，加完法师线还要记得回来改这里，
## 而"忘了改"的表现是"内容做好了但玩家点不到"——**没有任何报错**。
##
## ## 进阶等级的上限也是推导的
## 上限 = [method MetaState.unlocked_ascension_level]，
## 所以"通关解锁下一级"只改 MetaState 一处，UI 自动跟上。

signal character_chosen(character: StringName, ascension_level: int)

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

const CARD_WIDTH: int = 250

## 每个角色**当前选中的**进阶等级。
##
## ⚠️ 必须存在面板上、而不是卡片上：`rebuild_content()` 会重建全部卡片，
## 状态放在卡片里会在每次点 ◀/▶ 之后被重置——表现成"点了没反应"。
var _levels: Dictionary = {}
## 每个角色那张卡上的等级文字控件（重建后按 id 找回来刷新，避免整页重绘）
var _level_labels: Dictionary = {}
var _effect_labels: Dictionary = {}
## character_id → [左箭头, 右箭头]（`_refresh_arrows` 用来同步 disabled）
var _arrow_buttons: Dictionary = {}
var _debug_button: Button = null


func setup() -> void:
	frame_min_width = 900
	rebuild_content()


func _build_content() -> void:
	add_title("选择角色与进阶")
	# ⚠️ 不要用 `**粗体**`：`add_text` 是**普通 Label**（没有 BBCode），
	# 星号会原样显示给玩家。强调用中文引号。
	add_text("进阶是「累积」的：选进阶 5 就等于同时开着进阶 1~5 的全部效果。\n"
		+ "通关某一进阶后解锁下一级。")

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	content_box.add_child(row)

	for entry: Dictionary in CHARACTERS:
		row.add_child(_make_character_card(entry))

	_build_debug_footer()


# ══ 角色卡 ══════════════════════════════════════════════════

func _make_character_card(entry: Dictionary) -> Control:
	var character_id: StringName = entry["id"]
	var available: bool = MapManager.LINES.has(character_id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 268)

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
	desc_label.custom_minimum_size = Vector2(CARD_WIDTH - 30, 0)
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	column.add_child(desc_label)

	column.add_child(_make_ascension_selector(character_id, accent, available))

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


## 进阶选择行：`◀  进阶 N  ▶` + 该级新增效果说明
func _make_ascension_selector(character_id: StringName, accent: Color, available: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)

	var max_level: int = MetaState.unlocked_ascension_level(character_id)
	var current: int = clampi(int(_levels.get(character_id, 0)), 0, max_level)
	_levels[character_id] = current

	var left := Button.new()
	left.text = "◀"
	left.focus_mode = Control.FOCUS_NONE
	left.custom_minimum_size = Vector2(34, 30)
	left.disabled = not available or max_level <= 0
	left.pressed.connect(_on_level_step.bind(character_id, -1))
	row.add_child(left)

	var level_label := Label.new()
	level_label.text = Ascension.level_name(current)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.custom_minimum_size = Vector2(96, 0)
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color",
		UiPalette.TEXT if current <= 0 else accent.lightened(0.35))
	row.add_child(level_label)

	var right := Button.new()
	right.text = "▶"
	right.focus_mode = Control.FOCUS_NONE
	right.custom_minimum_size = Vector2(34, 30)
	right.disabled = not available or current >= max_level
	right.pressed.connect(_on_level_step.bind(character_id, 1))
	row.add_child(right)

	box.add_child(row)

	var effect_label := Label.new()
	effect_label.text = _effect_summary(current)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.custom_minimum_size = Vector2(CARD_WIDTH - 30, 46)
	effect_label.add_theme_font_size_override("font_size", 11)
	effect_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	box.add_child(effect_label)

	# 记下控件，点 ◀/▶ 时只刷新这两个，不整页重建——
	# 整页重建会让按钮在按下瞬间被 free 掉，手感上像是"点了没反应"
	_level_labels[character_id] = level_label
	_effect_labels[character_id] = effect_label
	_arrow_buttons[character_id] = [left, right]
	return box


## 该等级的说明文字：0 级说明"无"，其余列出**本局会生效的全部效果**。
##
## 列出累积全量而不是"本级新增那一条"——玩家选进阶 7 时想知道的是
## "我这局要面对什么"，而不是"7 比 6 多了什么"。
func _effect_summary(level: int) -> String:
	if level <= 0:
		return "标准难度。"
	var texts: Array[String] = Ascension.all_effect_texts(level)
	var lines: Array[String] = []
	for i: int in texts.size():
		lines.append("· %s" % texts[i])
	return "\n".join(lines)


func _on_level_step(character_id: StringName, delta: int) -> void:
	var max_level: int = MetaState.unlocked_ascension_level(character_id)
	var current: int = clampi(int(_levels.get(character_id, 0)) + delta, 0, max_level)
	_levels[character_id] = current

	# 只刷新这个角色那两个标签 + 两个箭头按钮的可用态
	if _level_labels.has(character_id):
		(_level_labels[character_id] as Label).text = Ascension.level_name(current)
	if _effect_labels.has(character_id):
		(_effect_labels[character_id] as Label).text = _effect_summary(current)

	# ⚠️ 箭头要跟着更新 disabled，否则到了上限还能点（点了没反应 = 像坏了）
	_refresh_arrows(character_id, current, max_level)


func _refresh_arrows(character_id: StringName, current: int, max_level: int) -> void:
	var pair: Array = _arrow_buttons.get(character_id, [])
	if pair.size() != 2:
		return
	(pair[0] as Button).disabled = current <= 0
	(pair[1] as Button).disabled = current >= max_level


# ══ 调试：一次性开启全部进阶 ════════════════════════════════

## 全解锁开关。
##
## 存在的理由：验证"进阶 10 无法探知敌人意图"必须先通关 9 级，
## 正常流程下这是几十小时的事——没有开关，高进阶效果在开发期
## **永远不会被跑到**，所有 bug 都留到玩家手里才出现。
##
## ⚠️ 它**不进存档**（见 `MetaState`）：调试开关被持久化的话，
## 下次启动就是"我以为在玩普通模式，其实全解锁了"，且不报错。
func _build_debug_footer() -> void:
	add_separator()
	_debug_button = add_footer_button(_debug_button_text(), _on_toggle_debug_unlock)
	var hint := add_text("调试：开启后所有角色的进阶 1~%d 立即可选。"
		% Ascension.MAX_LEVEL + "该开关不会存进存档，重开游戏即恢复。")
	hint.add_theme_font_size_override("font_size", 11)


func _debug_button_text() -> String:
	if MetaState.unlock_all_ascension:
		return "关闭全进阶解锁（当前：全解锁）"
	return "解锁全部进阶（调试）"


func _on_toggle_debug_unlock() -> void:
	MetaState.set_unlock_all_ascension(not MetaState.unlock_all_ascension)
	# 全解锁会改变每个角色的上限，所以必须整页重建；
	# 重建前把已选等级钳一下，否则会显示"进阶 10"但上限是 0 的错位状态。
	for character_id: StringName in _levels.keys():
		var max_level: int = MetaState.unlocked_ascension_level(character_id)
		_levels[character_id] = clampi(int(_levels[character_id]), 0, max_level)
	_level_labels.clear()
	_effect_labels.clear()
	_arrow_buttons.clear()
	rebuild_content()


func _on_choose(character_id: StringName) -> void:
	character_chosen.emit(character_id, int(_levels.get(character_id, 0)))
	queue_free()
