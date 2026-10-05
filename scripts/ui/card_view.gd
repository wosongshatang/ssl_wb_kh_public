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


## 预览上下文：打出这张牌的人与目标。
## 有了它，卡面显示的是**当前实际会生效的数值**（吃力量 / 敏捷 / 易伤），
## 而不是写死的基础值——否则玩家会看到「卡面写 5、实际打 7」。
var _preview_source: Creature = null
var _preview_target: Creature = null


func set_card(data: CardData) -> void:
	card = data
	if _name_label == null:
		return
	_refresh_all()


## 设置预览上下文（战斗手牌区用）。不设也能用——此时显示基础值。
func set_preview(source: Creature, target: Creature = null) -> void:
	_preview_source = source
	_preview_target = target
	_refresh_all()


func _refresh_all() -> void:
	if card == null or _name_label == null:
		return

	_name_label.text = card.display_name
	_name_label.add_theme_color_override("font_color", _rarity_color())
	_desc_label.text = card.format_description(_preview_source, _preview_target)
	_cost_label.text = str(card.cost)
	_cost_label.add_theme_color_override("font_color", UiPalette.TEXT)
	_cost_label.add_theme_stylebox_override("normal", _make_cost_style(card))
	_frame.add_theme_stylebox_override("panel", _make_frame_style())

	queue_redraw()
	if _art != null:
		_art.queue_redraw()


## 置灰：不可出牌但仍要显示（玩家需要看见自己有哪些牌、为什么打不出）
## 置灰并**阻止交互**。
##
## ⚠️ 只改 `modulate` 是不够的——置灰的卡仍然能点、能拖。
## 用户实际遇到过：商店删牌页点了一张**不可删除**的无色卡，
## 钱扣了、牌没删，而界面看起来"这张卡是灰的不能点"。
##
## **"看起来不能点"和"真的不能点"必须一致**，否则玩家会为不存在的操作付钱。
func set_playable(playable: bool) -> void:
	is_playable = playable
	modulate = Color.WHITE if playable else Color(0.55, 0.55, 0.6, 0.85)
	mouse_filter = Control.MOUSE_FILTER_STOP if playable else Control.MOUSE_FILTER_IGNORE


func _rarity_color() -> Color:
	return UiPalette.color_for_rarity(card.rarity)


## 卡框：**边框颜色与粗细都由稀有度决定**（用户要求：越稀有越美观）
##
## ⚠️ `card` 可能还是 null——`_build()` 在 `_ready` 里就要摆好骨架，
## 而 set_card() 是之后才调的。这里必须能处理"还没拿到数据"的状态。
func _make_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.BG_PANEL
	style.set_corner_radius_all(7)

	if card == null:
		style.border_color = UiPalette.BORDER_DIM
		style.set_border_width_all(1)
	else:
		style.border_color = _rarity_color()
		style.set_border_width_all(UiPalette.rarity_border_width(card.rarity))

	return style


func _make_cost_style(data: CardData) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.tint_for_card_type(data.type).lightened(0.25)
	style.border_color = UiPalette.color_for_rarity(data.rarity)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(COST_BADGE_SIZE / 2.0))
	return style


## 卡图占位：按卡牌类型画不同的几何图形，**底色混入稀有度颜色**。
## 攻击 = 斜刃；技能 = 盾牌轮廓；能力 = 菱形。全部程序绘制，不依赖美术资源。
func _on_art_draw() -> void:
	if card == null or _art == null:
		return

	var rect := Rect2(Vector2.ZERO, _art.size)
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return

	# 类型色与稀有度色混合：既看得出是攻击/技能，也看得出稀有度
	var type_tint := UiPalette.tint_for_card_type(card.type)
	var rarity_tint := _rarity_color()
	var tint: Color = type_tint.lerp(rarity_tint, 0.28)

	_art.draw_rect(rect, tint, true)
	_art.draw_rect(rect, rarity_tint, false, float(UiPalette.rarity_border_width(card.rarity)))

	var center := rect.size * 0.5
	var r: float = minf(rect.size.x, rect.size.y) * 0.28
	var ink: Color = rarity_tint.lightened(0.2)

	# 金卡 / 无色卡加一圈光环（"越稀有越好看"）
	if UiPalette.rarity_is_premium(card.rarity):
		_art.draw_arc(center, r * 1.5, 0.0, TAU, 40, Color(rarity_tint, 0.35), 2.0)

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
