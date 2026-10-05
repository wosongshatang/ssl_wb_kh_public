class_name OverlayPanel
extends Control
## 弹层面板基类：半透明遮罩 + 居中卡片容器
##
## 阶段 3 的三个弹层（卡牌奖励 / 商店 / 事件）内容都是**数据驱动、运行时才知道**的，
## 用 `.tscn` 只会得到一个空容器 + 一模一样的构建代码。所以这里用代码构建骨架。
## 阶段 8 若要美术化，再把骨架搬进 `.tscn`，逻辑不用动。
##
## 分层铁律：ui/ 不 import battle/ 或 pipeline/。本类只发信号 + 纯展示。

const DIMMER_ALPHA: float = 0.72
const CARD_MIN_WIDTH: int = 320

## 玩家关闭了弹层（ESC 或点关闭按钮）。场景据此恢复计时等。
signal closed

var content_box: VBoxContainer
## **固定页脚**：退出 / 关键动作放这里，永不被内容挤走
var footer_box: HBoxContainer
## 内容区最大宽度（牌组网格这类宽内容需要调大）
var frame_min_width: int = CARD_MIN_WIDTH


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, DIMMER_ALPHA)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(frame_min_width, 0)
	# 面板整体不超过视口的 92%——超过就靠内容区的 ScrollContainer 滚
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(frame)
	center.resized.connect(func() -> void:
		frame.custom_minimum_size.y = 0
		frame.size.y = minf(frame.size.y, center.size.y * 0.92))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	frame.add_child(margin)

	# ⚠️ 内容放进**可滚动区**，动作按钮放进**固定页脚**。
	#
	# 用户反馈：商店内容一多（卡牌 + 药水 + 遗物）就把「删牌 / 离开」挤出屏幕，
	# 玩家进得去出不来。**面板的退出路径永远不能被内容挤掉。**
	var root_column := VBoxContainer.new()
	root_column.add_theme_constant_override("separation", 10)
	margin.add_child(root_column)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 上限：视口高度的 78%，给页脚与边距留位置
	scroll.custom_minimum_size = Vector2(0, 0)
	root_column.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 10)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_box)

	footer_box = HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_box.add_theme_constant_override("separation", 12)
	root_column.add_child(footer_box)

	_build_content()


## ESC 关闭弹层（用户要求：「点击 esc 回到游戏界面」）
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		accept_event()
		closed.emit()
		queue_free()


## 子类在这里往 content_box 里塞内容
func _build_content() -> void:
	pass


## 数据变化后重建内容。
## 子类的 setup() 应当调用它——这样无论 setup 发生在 add_child 之前还是之后都正确。
func rebuild_content() -> void:
	if content_box == null:
		return  # 还没 _ready；_ready 里会调 _build_content()
	for child: Node in content_box.get_children():
		content_box.remove_child(child)
		child.queue_free()
	_build_content()


# ── 构建辅助 ────────────────────────────────────────────────

func add_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	content_box.add_child(label)
	return label


func add_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(CARD_MIN_WIDTH, 0)
	content_box.add_child(label)
	return label


func add_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	content_box.add_child(button)
	return button


func add_separator() -> void:
	content_box.add_child(HSeparator.new())


## 往**固定页脚**加一个按钮。退出路径必须放这里——
## 放进内容区的话，内容一多它就被滚出屏幕（用户实际遇到的就是这个）。
func add_footer_button(text: String, handler: Callable, prominent: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 40)
	if prominent:
		button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(handler)
	footer_box.add_child(button)
	return button


## 节点横幅：告诉玩家「你进入了什么」。
##
## 用户反馈：商店 / 事件 / 休息都只是一列文字，看不出自己进了哪个节点。
## 横幅用**节点类型的配色**（与地图上的节点同色）+ 大字标题 + 一句副标题，
## 让玩家一眼确认"我在哪"。
func add_node_banner(kind: int, title: String, subtitle: String = "") -> void:
	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 66)

	var accent := UiPalette.color_for_node_kind(kind)
	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.62)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	banner.add_theme_stylebox_override("panel", style)
	content_box.add_child(banner)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	banner.add_child(column)

	var title_label := Label.new()
	title_label.text = "%s　%s" % [MapNode.kind_label_of(kind), title]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", accent.lightened(0.35))
	column.add_child(title_label)

	if subtitle != "":
		var subtitle_label := Label.new()
		subtitle_label.text = subtitle
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle_label.add_theme_font_size_override("font_size", 12)
		subtitle_label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
		column.add_child(subtitle_label)
