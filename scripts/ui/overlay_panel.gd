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
var _scroll: ScrollContainer = null
## 内容区最大宽度（牌组网格这类宽内容需要调大）
var frame_min_width: int = CARD_MIN_WIDTH


## ⚠️⚠️ **不能只靠 `set_anchors_preset(PRESET_FULL_RECT)` 撑满。**
##
## 本面板的父节点是**场景根**，而场景根是**普通 `Node`（不是 `Control`）**。
## 普通 Node 没有"父区域"概念，锚点算出来的可用矩形是 **0×0**，
## 于是本面板的 `size` 永远停在 (0,0)（锚点值是对的，尺寸却是 0）。
##
## 后果不是"面板不见了"，而是**更隐蔽的一串错位**：
##   · `CenterContainer` 把 0×0 当成可居中区域 → 卡片以**原点为中心**摆放
##     → 面板整体偏到左上角、**左侧和顶部被切掉**
##   · `dimmer`（ColorRect + FULL_RECT）在 0×0 里也是 0×0 → **遮罩层完全看不见**
##
## 而且**不报任何错**——`battle_background.gd` 踩过同一个坑并写了注释，
## 这里当时没照着做。
##
## 正解是**显式取视口尺寸**（与 `BattleBackground` / `MapView` 同一套做法），
## 并跟随视口变化（窗口缩放时面板要跟着变大）。
func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_to_viewport()
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_sync_to_viewport):
		vp.size_changed.connect(_sync_to_viewport)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, DIMMER_ALPHA)
	# 子节点可以放心用 FULL_RECT：现在父节点（本面板）**是** Control 且有真实尺寸
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

	# ⚠️ ScrollContainer **不能**用 EXPAND_FILL 塞进自适应容器里。
	#
	# `PanelContainer` 的高度由内容撑开，而 ScrollContainer 的最小高度是 0——
	# 两者互相等待，结果是 **ScrollContainer 塌缩成 0 高度、内容完全看不见**。
	# 表现是"面板打开了但什么都没有"，而且**不报任何错**。
	#
	# 正确做法：让它**贴合内容**，只在超过视口上限时才滚动。
	# 具体尺寸在 `_fit_scroll()` 里按内容实测（`_ready` 之后才量得准）。
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 0)
	root_column.add_child(_scroll)
	var scroll := _scroll

	content_box = VBoxContainer.new()
	content_box.add_theme_constant_override("separation", 10)
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_box)

	footer_box = HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_box.add_theme_constant_override("separation", 12)
	root_column.add_child(footer_box)

	_build_content()
	_fit_scroll()

	# ⚠️⚠️ 内容可能在 `_ready()` **之后**才被加进来。
	#
	# 典型写法是「先 `add_child(panel)`，再往 `content_box` 里塞内容」
	# （战斗里那张只读地图就是这么加的）。此时 `_ready()` 里的
	# `_fit_scroll()` 量到的是**空内容** → 滚动区高度停在 0 →
	# 弹层框架正常、遮罩正常，**里面什么都没有**。
	#
	# 与其要求每个调用点都记得手动 refit（已经漏了两处），
	# 不如让基类自己盯着 `content_box`。
	content_box.child_entered_tree.connect(_on_content_changed)
	content_box.child_exiting_tree.connect(_on_content_changed)


## 内容增删后重新量高度。
##
## 必须**延迟一帧**：`child_entered_tree` 在容器排版**之前**发出，
## 那时 `get_combined_minimum_size()` 还是旧值，当场量等于没量。
func _on_content_changed(_node: Node) -> void:
	_fit_scroll.call_deferred()


## 把本面板铺满视口。
##
## ⚠️ 用**显式尺寸**而不是锚点——理由见 [method _ready] 的注释。
## 父节点是普通 `Node` 时锚点算出的可用区域是 0×0，
## 尺寸必须自己从视口取。
func _sync_to_viewport() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	position = Vector2.ZERO
	size = vp.get_visible_rect().size


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

	# ⚠️ **页脚也要清**。
	# 只清内容不清页脚的话，每次 rebuild 都会往页脚追加一批按钮——
	# 商店切一次"删牌页"就多一个「返回商品页」，四次之后页脚挤满了没用的按钮。
	# 这类泄漏不会报错，只会让界面越用越乱。
	for child: Node in footer_box.get_children():
		footer_box.remove_child(child)
		child.queue_free()

	_build_content()
	_fit_scroll()
	_fit_scroll()


## 让内容区**贴合内容高度**，但不超过视口的 78%。
##
## 在 `_ready` 里直接量是量不准的（容器还没排过版），所以延迟一帧。
func _fit_scroll() -> void:
	if _scroll == null or content_box == null:
		return
	var content_height: float = content_box.get_combined_minimum_size().y
	var cap: float = get_viewport_rect().size.y * 0.78
	_scroll.custom_minimum_size.y = minf(content_height, cap)


## 重建内容后必须重新量一次——否则内容变多时高度不会跟着变
func _refit() -> void:
	_fit_scroll()


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
