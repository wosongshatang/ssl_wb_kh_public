class_name RewardUI
extends Control
## 战斗结算界面（**独立场景**，参考「搜刮！」布局）
##
## 顶部横幅 + 竖排奖励行 + 右下「前进」。每行点一下领取。
##
## ## 为什么不再用弹层
## 弹层会盖住战场，而且**屏幕右上角那种小面板**装不下"金币 / 药水 / 遗物 / 卡牌"
## 四类奖励——挤在一起玩家看不清自己拿了什么。独立一屏可以一条一条列清楚。
##
## ## 领取与提交分离
## 本类只负责"玩家点了哪一行"（发信号）与"这行已领取"（置灰）。
## 真正改动 [RunState] 在 RewardScene 点「前进」时**一次性**做（D24）。

signal row_pressed(key: String)
signal forward_pressed

const ROW_WIDTH: float = 400.0
const ROW_HEIGHT: float = 48.0

var _rows_box: VBoxContainer
var _hint_label: Label
var _forward_button: Button
var _row_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.05, 0.045, 0.06)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_bottom", 44)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	column.add_child(_make_banner())

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 10)
	column.add_child(_rows_box)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	column.add_child(_hint_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var forward_row := HBoxContainer.new()
	forward_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(forward_row)

	_forward_button = Button.new()
	_forward_button.text = "前进  ▶"
	_forward_button.custom_minimum_size = Vector2(200, 54)
	_forward_button.focus_mode = Control.FOCUS_NONE
	_forward_button.add_theme_font_size_override("font_size", 20)
	_forward_button.add_theme_color_override("font_color", Color(0.98, 0.92, 0.8))
	var forward_style := StyleBoxFlat.new()
	forward_style.bg_color = Color(0.55, 0.2, 0.18)
	forward_style.border_color = Color(0.82, 0.68, 0.45)
	forward_style.set_border_width_all(2)
	forward_style.set_corner_radius_all(8)
	_forward_button.add_theme_stylebox_override("normal", forward_style)
	_forward_button.add_theme_stylebox_override("hover", forward_style)
	_forward_button.add_theme_stylebox_override("pressed", forward_style)
	_forward_button.pressed.connect(func() -> void: forward_pressed.emit())
	forward_row.add_child(_forward_button)


## 顶部卷轴横幅
func _make_banner() -> PanelContainer:
	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(ROW_WIDTH, 62)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.76, 0.66, 0.44)
	style.border_color = Color(0.52, 0.43, 0.28)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	banner.add_theme_stylebox_override("panel", style)

	var title := Label.new()
	title.text = "搜　刮"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.16, 0.12, 0.09))
	banner.add_child(title)
	return banner


# ══ 构建奖励行 ══════════════════════════════════════════════

func setup(bundle: RewardBundle) -> void:
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_row_buttons.clear()

	if bundle == null:
		_hint_label.text = "（没有结算数据）"
		return

	if bundle.gold > 0:
		_add_row("gold", "金币  +%d" % bundle.gold, UiPalette.COIN)
	if bundle.potion_id != &"":
		_add_row("potion", "药水  %s" % RewardBundle.potion_name(bundle.potion_id), UiPalette.POTION)
	if bundle.relic_id != &"":
		_add_row("relic", "遗物  %s" % RewardBundle.relic_name(bundle.relic_id), UiPalette.GOLD)
	if not bundle.card_offer_ids.is_empty():
		_add_row("card", "将一张牌添加到你的牌组", UiPalette.TINT_SKILL.lightened(0.35))

	if _row_buttons.is_empty():
		_hint_label.text = "本场战斗没有可拾取的战利品，直接前进即可。"
	else:
		_hint_label.text = "点击每一项领取。未领取的奖励会在前进时放弃。"


func _add_row(key: String, text: String, accent: Color) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.text = "　" + text
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", UiPalette.TEXT)

	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.58)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)

	button.pressed.connect(func() -> void: row_pressed.emit(key))
	_rows_box.add_child(button)
	_row_buttons[key] = button


## 标记某项已领取（置灰 + 换文案）。**不 disabled**——
## 玩家可能想再点一次看详情，而且禁用按钮会让"已领取"和"买不起"看起来一样。
func mark_taken(key: String, text: String) -> void:
	if not _row_buttons.has(key):
		return
	var button: Button = _row_buttons[key]
	button.text = "　已领取：%s" % text
	button.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.BG_SLOT
	style.border_color = UiPalette.BORDER_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)


func show_hint(text: String) -> void:
	_hint_label.text = text


func set_forward_enabled(enabled: bool) -> void:
	_forward_button.disabled = not enabled
