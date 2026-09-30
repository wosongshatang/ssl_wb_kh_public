class_name CardView
extends Control
## 卡面控件：从上到下 = 名字 / 图片 / 描述（用户要求的三要素）
##
## ## 交互
## - **双击**：直接打出（默认打第一个敌人）→ 发 [signal card_activated]
## - **拖拽**：用 Godot 内建的拖放（`_get_drag_data` / `_drop_data`）拖到敌人身上释放。
##   用内建拖放而不是手写鼠标跟随，是因为内建的那套会自动处理
##   "拖到哪个控件上"、"放下时谁接收"——手写容易在多层 UI 下算错落点。
##
## ## 美术
## 阶段 5 没有美术资源，卡图用 `_draw()` 程序生成的几何图形占位。
## 阶段 8 接真图时，只需把 [method _draw] 换成 TextureRect。

signal card_activated(card: CardData)
## 单击（奖励界面选牌用）。战斗手牌忽略它——那里用双击/拖拽。
signal card_clicked(card: CardData)

const CARD_SIZE := Vector2(118, 166)
const COST_BADGE_SIZE := 26.0

var card: CardData = null
## 是否可交互（能量不足 / 非玩家回合时置灰但仍显示）
var is_playable: bool = true

var _name_label: Label
var _desc_label: Label
var _art: Control
var _frame: PanelContainer
var _cost_label: Label


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	_frame = PanelContainer.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override("panel", _make_frame_style())
	add_child(_frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 5)
	_frame.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", UiPalette.GOLD)
	box.add_child(_name_label)

	_art = Control.new()
	_art.custom_minimum_size = Vector2(0, 64)
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_on_art_draw)
	box.add_child(_art)

	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.add_theme_color_override("font_color", UiPalette.TEXT)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_desc_label)

	# 费用角标：左上角浮在卡面之上
	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 15)
	_cost_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_label.custom_minimum_size = Vector2(COST_BADGE_SIZE, COST_BADGE_SIZE)
	_cost_label.size = Vector2(COST_BADGE_SIZE, COST_BADGE_SIZE)
	_cost_label.position = Vector2(-4, -4)
	add_child(_cost_label)


func set_card(data: CardData) -> void:
	card = data
	if _name_label == null:
		return
	_name_label.text = data.display_name
	_desc_label.text = data.description
	_cost_label.text = str(data.cost)
	_cost_label.add_theme_color_override("font_color", UiPalette.TEXT)
	_cost_label.add_theme_stylebox_override("normal", _make_cost_style(data))
	queue_redraw()
	if _art != null:
		_art.queue_redraw()


## 置灰：不可出牌但仍要显示（玩家需要看见自己有哪些牌、为什么打不出）
func set_playable(playable: bool) -> void:
	is_playable = playable
	modulate = Color.WHITE if playable else Color(0.55, 0.55, 0.6, 0.85)


func _make_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.BG_PANEL
	style.border_color = UiPalette.BORDER_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style


func _make_cost_style(data: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.tint_for_card_type(data.type).lightened(0.25)
	style.border_color = UiPalette.GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(COST_BADGE_SIZE / 2.0))
	return style


## 卡图占位：按卡牌类型画不同的几何图形。
## 攻击 = 斜刃；技能 = 盾牌轮廓；能力 = 菱形。全部程序绘制，不依赖美术资源。
func _on_art_draw() -> void:
	if card == null or _art == null:
		return

	var rect := Rect2(Vector2.ZERO, _art.size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return

	var tint := UiPalette.tint_for_card_type(card.type)
	_art.draw_rect(rect, tint, true)
	_art.draw_rect(rect, UiPalette.BORDER_DIM, false, 1.0)

	var center := rect.size * 0.5
	var r: float = minf(rect.size.x, rect.size.y) * 0.28
	var ink := UiPalette.color_for_rarity(card.rarity).lightened(0.35)

	match card.type:
		CardData.CardType.ATTACK:
			var blade := PackedVector2Array([
				center + Vector2(-r * 0.35, r),
				center + Vector2(r * 0.35, r),
				center + Vector2(r * 0.2, -r),
				center + Vector2(0, -r * 1.25),
				center + Vector2(-r * 0.2, -r),
			])
			_art.draw_colored_polygon(blade, ink)
			_art.draw_line(center + Vector2(-r * 0.6, r * 0.75),
				center + Vector2(r * 0.6, r * 0.75), ink, 2.0)
		CardData.CardType.SKILL:
			var shield := PackedVector2Array([
				center + Vector2(-r * 0.85, -r * 0.7),
				center + Vector2(r * 0.85, -r * 0.7),
				center + Vector2(r * 0.6, r * 0.5),
				center + Vector2(0, r * 1.15),
				center + Vector2(-r * 0.6, r * 0.5),
			])
			_art.draw_colored_polygon(shield, ink)
		_:
			var diamond := PackedVector2Array([
				center + Vector2(0, -r * 1.1),
				center + Vector2(r * 0.9, 0),
				center + Vector2(0, r * 1.1),
				center + Vector2(-r * 0.9, 0),
			])
			_art.draw_colored_polygon(diamond, ink)


# ── 交互 ────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if card == null:
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return

	accept_event()
	if mouse.double_click:
		card_activated.emit(card)
	else:
		card_clicked.emit(card)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if card == null or not is_playable:
		return null
	# 拖拽预览：复制一份卡面，缩小一点跟随鼠标
	var preview := CardView.new()
	preview.card = card
	preview.is_playable = true
	preview.scale = Vector2(0.8, 0.8)
	preview.modulate = Color(1, 1, 1, 0.9)
	set_drag_preview(preview)
	return card
