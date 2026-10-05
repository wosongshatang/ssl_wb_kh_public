class_name RunHUD
extends Control
## 顶部信息栏（**地图与战斗共用**）
##
## ## 布局（左 → 右）
## 头像 → 血量 → 金币 → 药水栏 → 地图信息（幕 / 层数 / Boss 头像）→ 弹性空白
## → 遗物栏 → 游玩时间 → 查看地图 → 牌组 → 设置
##
## ## 职责边界
## 只**读** RunState / GameState，只**发**信号。不参与任何玩法逻辑——
## 「点击遗物栏要做什么」由场景决定，HUD 只负责喊一声。
##
## ## 游玩时间为什么放在 HUD 里
## 计时属于"展示"而不是"玩法"。放在 HUD 里，地图与战斗共用同一个计时器，
## 跨场景切换时不会重置——玩家看到的"游玩时间"才是这一局的真实总时长。

signal map_pressed
signal deck_pressed
signal relics_pressed
signal settings_pressed
## 单击药水槽 → 查看信息（**不是**直接使用）
signal potion_pressed(slot_index: int)
## 双击药水槽 → 直接使用（战斗式默认打第一个敌人）
signal potion_double_clicked(slot_index: int)
## 打开战斗日志（战斗中才可用）
signal log_pressed

const HUD_HEIGHT: float = 58.0
const AVATAR_SIZE: float = 42.0
const BOSS_ICON_SIZE: float = 22.0

var _run: RunState = null
var _timing: bool = false

var _avatar_box: PanelContainer
var _avatar_letter: Label
var _hp_chip: Label
var _gold_chip: Label
var _map_info_label: Label
var _boss_icon: Control
var _relic_chip: Button
var _time_chip: Label
var _log_button: Button
var _erosion_bar: Control
var _potion_slots: Array[PotionSlot] = []


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_bottom = HUD_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _process(delta: float) -> void:
	if not _timing or _run == null:
		return
	_run.play_seconds += delta
	_update_time_chip()


func set_time_running(running: bool) -> void:
	_timing = running


## 战斗日志只在地图之外有意义——地图场景会把它藏起来
func set_log_available(available: bool) -> void:
	if _log_button != null:
		_log_button.visible = available


func bind_run(run: RunState) -> void:
	_run = run
	refresh()


# ══ 构建 ════════════════════════════════════════════════════

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.94)
	style.border_color = UiPalette.BORDER
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	_build_avatar(row)

	# 侵蚀条（阶段 6）：神性从右往左长，人性从左往右长——
	# 两者在中间相遇就是"被同化"的直观表达
	_erosion_bar = Control.new()
	_erosion_bar.custom_minimum_size = Vector2(96, 16)
	_erosion_bar.size = Vector2(96, 16)
	_erosion_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_erosion_bar.draw.connect(_on_erosion_draw)
	row.add_child(_erosion_bar)

	_hp_chip = _make_chip("", UiPalette.HP_RED)
	row.add_child(_hp_chip)
	_gold_chip = _make_chip("", UiPalette.COIN)
	row.add_child(_gold_chip)
	_build_potion_bar(row)
	_build_map_info(row)

	# 「战斗日志」按钮紧跟层数（用户要求：层数右边加一本书一样的按钮）。
	# 地图上没有战斗，由 set_log_available(false) 隐藏。
	_log_button = _make_action_button("日志")
	_log_button.tooltip_text = "查看本场战斗的完整日志"
	_log_button.pressed.connect(func() -> void: log_pressed.emit())
	row.add_child(_log_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_relic_chip = _make_action_button("遗物")
	_relic_chip.pressed.connect(func() -> void: relics_pressed.emit())
	row.add_child(_relic_chip)

	_time_chip = _make_chip("00:00", UiPalette.TEXT_DIM)
	row.add_child(_time_chip)

	var map_button := _make_action_button("查看地图")
	map_button.pressed.connect(func() -> void: map_pressed.emit())
	row.add_child(map_button)

	var deck_button := _make_action_button("牌组")
	deck_button.pressed.connect(func() -> void: deck_pressed.emit())
	row.add_child(deck_button)

	var settings_button := _make_action_button("设置")
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	row.add_child(settings_button)


func _build_avatar(row: HBoxContainer) -> void:
	_avatar_box = PanelContainer.new()
	_avatar_box.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	_avatar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.2, 0.18)
	style.border_color = UiPalette.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(AVATAR_SIZE / 2.0))
	_avatar_box.add_theme_stylebox_override("panel", style)
	row.add_child(_avatar_box)

	_avatar_letter = Label.new()
	_avatar_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_letter.add_theme_font_size_override("font_size", 20)
	_avatar_letter.add_theme_color_override("font_color", UiPalette.GOLD)
	_avatar_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar_box.add_child(_avatar_letter)


## 侵蚀条：左半人性（蓝）／右半神性（红）
func _on_erosion_draw() -> void:
	var rect := Rect2(Vector2.ZERO, _erosion_bar.size)
	_erosion_bar.draw_rect(rect, UiPalette.BG_SLOT, true)

	var half: float = rect.size.x * 0.5
	var divinity_ratio: float = clampf(
		float(GameState.divinity) / float(GameState.DIVINITY_MAX), 0.0, 1.0)
	var humanity_ratio: float = clampf(
		float(GameState.humanity) / float(GameState.HUMANITY_MAX), 0.0, 1.0)

	_erosion_bar.draw_rect(
		Rect2(0.0, 0.0, half * humanity_ratio, rect.size.y), Color(0.35, 0.6, 0.88))
	_erosion_bar.draw_rect(
		Rect2(rect.size.x - half * divinity_ratio, 0.0, half * divinity_ratio, rect.size.y),
		UiPalette.NODE_BOSS)

	# 显化阈值刻线（神性 70）
	var manifest_x: float = rect.size.x - half * (
		float(GameState.DIVINITY_MANIFEST) / float(GameState.DIVINITY_MAX))
	_erosion_bar.draw_line(Vector2(manifest_x, 0.0), Vector2(manifest_x, rect.size.y),
		UiPalette.GOLD, 1.0)

	_erosion_bar.draw_rect(rect, UiPalette.BORDER_DIM, false, 1.0)


func _build_potion_bar(row: HBoxContainer) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	row.add_child(box)

	for i: int in RunState.MAX_POTIONS:
		var slot := PotionSlot.new()
		slot.slot_clicked.connect(_on_potion_slot_clicked)
		slot.slot_double_clicked.connect(_on_potion_slot_double_clicked)
		box.add_child(slot)
		_potion_slots.append(slot)


func _build_map_info(row: HBoxContainer) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	_boss_icon = Control.new()
	_boss_icon.custom_minimum_size = Vector2(BOSS_ICON_SIZE, BOSS_ICON_SIZE)
	_boss_icon.size = Vector2(BOSS_ICON_SIZE, BOSS_ICON_SIZE)
	_boss_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_icon.draw.connect(_on_boss_icon_draw)
	box.add_child(_boss_icon)

	_map_info_label = _make_chip("", UiPalette.TEXT_DIM)
	box.add_child(_map_info_label)


## Boss 头像占位：一个带角的骷髅轮廓（阶段 8 换成真图）
func _on_boss_icon_draw() -> void:
	var c := Vector2(BOSS_ICON_SIZE, BOSS_ICON_SIZE) * 0.5
	var ink := UiPalette.NODE_BOSS
	_boss_icon.draw_circle(c, BOSS_ICON_SIZE * 0.36, ink)
	_boss_icon.draw_circle(c + Vector2(-4, -2), 2.5, Color(0.08, 0.06, 0.08))
	_boss_icon.draw_circle(c + Vector2(4, -2), 2.5, Color(0.08, 0.06, 0.08))
	# 两只角
	_boss_icon.draw_line(c + Vector2(-8, -6), c + Vector2(-13, -12), ink, 3.0)
	_boss_icon.draw_line(c + Vector2(8, -6), c + Vector2(13, -12), ink, 3.0)


# ══ 通用小控件 ══════════════════════════════════════════════

func _make_chip(text: String, accent: Color) -> Label:
	var chip := Label.new()
	chip.text = text
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_theme_font_size_override("font_size", 14)
	chip.add_theme_color_override("font_color", UiPalette.TEXT)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.BG_SLOT
	style.border_color = accent.darkened(0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	chip.add_theme_stylebox_override("normal", style)
	return chip


func _make_action_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	return button


# ══ 刷新 ════════════════════════════════════════════════════

func refresh() -> void:
	if _run == null:
		return

	_avatar_letter.text = _character_letter(_run.character_class)
	_hp_chip.text = "%d / %d" % [_run.hp, _run.max_hp]
	_gold_chip.text = str(_run.gold)
	_relic_chip.text = "遗物 %d" % _run.relics.size()

	var total_rows: int = MapManager.ROWS_PER_ACT
	var row_index: int = 0
	if GameState.map != null:
		var node: MapNode = GameState.map.current_node()
		if node != null:
			row_index = node.row + 1
	_map_info_label.text = "%s · %d/%d 层" % [
		MapManager.act_name(_run.character_class, _run.current_act), row_index, total_rows,
	]

	_refresh_potions()
	_update_time_chip()

	# 侵蚀条要跟着数据走，否则加了神性界面不动
	if _erosion_bar != null:
		_erosion_bar.tooltip_text = "侵蚀　神性 %d / 人性 %d　（显化阈值 %d）" % [
			GameState.divinity, GameState.humanity, GameState.DIVINITY_MANIFEST,
		]
		_erosion_bar.queue_redraw()


func _refresh_potions() -> void:
	for i: int in _potion_slots.size():
		var data: PotionData = null
		if i < _run.potions.size():
			var loaded: Variant = ContentRegistry.get_potion(_run.potions[i])
			if loaded is PotionData:
				data = loaded as PotionData
		_potion_slots[i].set_potion(data, i)


func _update_time_chip() -> void:
	if _run == null:
		return
	var total: int = int(_run.play_seconds)
	_time_chip.text = "%02d:%02d" % [total / 60, total % 60]


func _on_potion_slot_clicked(slot_index: int) -> void:
	potion_pressed.emit(slot_index)


func _on_potion_slot_double_clicked(slot_index: int) -> void:
	potion_double_clicked.emit(slot_index)


func _character_letter(character: StringName) -> String:
	match character:
		&"warrior":
			return "战"
		&"hunter":
			return "猎"
		&"mage":
			return "法"
		_:
			return "?"
