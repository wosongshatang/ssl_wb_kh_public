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
	center.add_child(frame)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	frame.add_child(margin)

	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 10)
	margin.add_child(content_box)

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
