class_name RunOverlays
extends RefCounted
## 把「查看牌组 / 遗物 / 地图 / 设置」这些**每个场景都要有**的弹层接到一起
##
## ## 为什么抽出来
## 地图 / 战斗 / 结算三个场景都需要同一组弹层。各写一遍的结果是
## 「在结算界面点牌组没反应」这类**不一致**——而玩家会以为是 bug。
## 抽成一处后，新增一个场景只要 `RunOverlays.wire(hud, ...)` 一行。

## 把 HUD 上那排按钮接到通用弹层上。
##
## `on_return_to_title` 由场景决定（结算界面和地图的"回到标题"后续处理不同）。
## `overlay_slot` 是一个返回当前弹层的容器，避免场景各自维护 `_overlay` 变量。
static func wire(
	host: Node,
	hud: RunHUD,
	run: RunState,
	get_overlay: Callable,
	set_overlay: Callable,
	on_return_to_title: Callable
) -> void:
	hud.deck_pressed.connect(func() -> void:
		_open_deck(host, run, get_overlay, set_overlay))
	hud.relics_pressed.connect(func() -> void:
		_open_relics(host, run, get_overlay, set_overlay))
	hud.settings_pressed.connect(func() -> void:
		_open_settings(host, get_overlay, set_overlay, on_return_to_title))
	hud.map_pressed.connect(func() -> void:
		_open_map_readonly(host, get_overlay, set_overlay))


static func _begin(host: Node, get_overlay: Callable, set_overlay: Callable, panel: OverlayPanel) -> bool:
	if get_overlay.call() != null:
		panel.queue_free()
		return false
	set_overlay.call(panel)
	host.add_child(panel)
	panel.closed.connect(func() -> void: set_overlay.call(null))
	return true


static func _open_deck(host: Node, run: RunState, get_overlay: Callable, set_overlay: Callable) -> void:
	var panel := DeckViewPanel.new()
	if not _begin(host, get_overlay, set_overlay, panel):
		return
	panel.setup(run.build_deck())


static func _open_relics(host: Node, run: RunState, get_overlay: Callable, set_overlay: Callable) -> void:
	var panel := RelicViewPanel.new()
	if not _begin(host, get_overlay, set_overlay, panel):
		return
	panel.setup(run.relics)


static func _open_settings(
	host: Node,
	get_overlay: Callable,
	set_overlay: Callable,
	on_return_to_title: Callable
) -> void:
	var panel := SettingsPanel.new()
	if not _begin(host, get_overlay, set_overlay, panel):
		return
	panel.setup()
	panel.return_to_title_pressed.connect(on_return_to_title)
	panel.quit_pressed.connect(func() -> void: host.get_tree().quit())


## 只读地图：能看路线，但点不了节点。
## 战斗中 / 结算时都需要它——玩家要靠路线来决定"接下来选什么牌"。
static func _open_map_readonly(host: Node, get_overlay: Callable, set_overlay: Callable) -> void:
	if GameState.map == null:
		return

	var panel := OverlayPanel.new()
	if not _begin(host, get_overlay, set_overlay, panel):
		return

	panel.frame_min_width = 660
	var map_view := MapView.new()
	map_view.custom_minimum_size = Vector2(600, 380)
	map_view.size = Vector2(600, 380)
	# 只读：把交互整个吃掉
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.content_box.add_child(map_view)
	map_view.build_map(GameState.map)

	var hint := Label.new()
	hint.text = "这里只能查看地图，无法选择节点。"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	panel.content_box.add_child(hint)

	panel.add_button("返回（ESC）", func() -> void:
		panel.closed.emit()
		panel.queue_free())
