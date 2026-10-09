extends GutTest
## 弹层骨架测试
##
## ## 为什么值得单独测
## `OverlayPanel` 的布局错误表现为「**面板打开了但什么都没有**」——
## 不报错、不崩溃，玩家只会觉得"点了没反应"。
## 这类错误只能靠"量一下高度对不对"来抓。

func before_all() -> void:
	ContentRegistry.load_all()


func _make_panel() -> OverlayPanel:
	var panel := OverlayPanel.new()
	add_child_autofree(panel)
	return panel


func _settle() -> void:
	# 布局要等一帧才准
	await get_tree().process_frame
	await get_tree().process_frame


# ══ ★ 回归：内容区不能塌缩 ══════════════════════════════════

func test_panel_fills_the_viewport() -> void:
	## ★★ 回归（用户报告「战斗中无法查看地图」的根因之一）。
	##
	## `set_anchors_preset(PRESET_FULL_RECT)` 在**父节点是普通 `Node`**
	## （场景根就是）时算不出可用区域 → `size` 永远停在 **(0,0)**。
	##
	## 后果不是"面板不见了"，而是一串更隐蔽的错位：
	## `CenterContainer` 把 0×0 当成可居中区域 → 面板被摆到**以原点为中心**
	## → 整体偏到左上角、**左边和顶部被切掉**。
	##
	## 而且**不报任何错**——只有渲染一帧才看得出来。
	var panel := _make_panel()
	await _settle()

	assert_gt(panel.size.x, 1.0,
		"面板宽度为 0：弹层不会居中，且会被裁在屏幕左上角")
	assert_gt(panel.size.y, 1.0, "面板高度为 0")
	assert_eq(panel.size, get_viewport().get_visible_rect().size,
		"面板必须铺满视口（父节点是普通 Node，只能显式取视口尺寸）")


func test_dimmer_fills_the_panel() -> void:
	## 遮罩层是"弹层盖住了游戏"的**唯一视觉证据**。
	## 它是 `ColorRect` + FULL_RECT，父面板是 0×0 时它也是 0×0 → 完全看不见，
	## 表现成"弹层没打开"（其实框架在，只是被裁到了屏幕外）。
	var panel := _make_panel()
	await _settle()

	var dimmer := panel.get_child(0) as Control
	assert_ne(dimmer, null, "面板第一个子节点应该是遮罩层")
	assert_gt(dimmer.size.x, 1.0, "遮罩层宽度为 0（看起来像弹层没打开）")
	assert_gt(dimmer.size.y, 1.0, "遮罩层高度为 0")


func test_content_added_after_ready_is_measured() -> void:
	## ★★ 回归（同一个用户报告的**根因之二**）。
	##
	## 典型写法是「先 `add_child(panel)`，再往 `content_box` 里塞内容」——
	## 战斗里的只读地图就是这么加的。
	## 此时 `_ready()` 里的 `_fit_scroll()` 量到的是**空内容**，
	## 滚动区高度停在 0 → 弹层框架与遮罩都正常，**里面什么都没有**。
	var panel := _make_panel()
	await _settle()
	assert_eq(panel._scroll.custom_minimum_size.y, 0.0,
		"前提：面板刚建好、还没内容时，内容区高度应为 0")

	var block := Control.new()
	block.custom_minimum_size = Vector2(100, 200)
	panel.content_box.add_child(block)
	await _settle()

	assert_gt(panel._scroll.custom_minimum_size.y, 1.0,
		"`_ready()` 之后加进来的内容也必须被重新量到，否则弹层里什么都看不见")


func test_content_area_has_height() -> void:
	## ⚠️ 回归：`ScrollContainer` 用 EXPAND_FILL 塞进自适应容器里会**塌缩成 0 高度**。
	## `PanelContainer` 高度由内容撑开，而 ScrollContainer 最小高度是 0——
	## 两者互相等待，结果是面板只剩一条线。
	##
	## 这曾经让「开始新的一局」看起来完全没反应。
	var panel := _make_panel()
	panel.add_title("标题")
	panel.add_text("正文内容")
	panel._fit_scroll()
	await _settle()

	assert_gt(panel._scroll.custom_minimum_size.y, 1.0,
		"内容区高度为 0 —— 面板会显示成一条线，玩家以为点击无效")


func test_content_area_grows_with_content() -> void:
	var small := _make_panel()
	small.add_title("短")
	small._fit_scroll()
	await _settle()
	var small_height: float = small._scroll.custom_minimum_size.y

	var big := _make_panel()
	for i: int in 20:
		big.add_text("第 %d 行内容" % i)
	big._fit_scroll()
	await _settle()

	assert_gt(big._scroll.custom_minimum_size.y, small_height,
		"内容变多时内容区应该变高")


func test_content_area_is_capped() -> void:
	## 内容再多也不能超过视口的 78%——否则页脚会被顶出屏幕
	var panel := _make_panel()
	for i: int in 80:
		panel.add_text("很长的内容第 %d 行" % i)
	panel._fit_scroll()
	await _settle()

	var cap: float = get_viewport().get_visible_rect().size.y * 0.78
	assert_lte(panel._scroll.custom_minimum_size.y, cap + 1.0,
		"内容区高度必须封顶，否则页脚会被顶出屏幕")


# ══ 固定页脚 ════════════════════════════════════════════════

func test_footer_button_goes_to_the_footer_not_the_content() -> void:
	## ★ 「离开」这类退出路径必须在页脚。
	## 放进内容区的话，内容一多它就被滚出屏幕——玩家**进得去出不来**。
	var panel := _make_panel()
	var pressed: Array[bool] = [false]
	panel.add_footer_button("离开", func() -> void: pressed[0] = true)
	await _settle()

	assert_eq(panel.footer_box.get_child_count(), 1, "按钮应进页脚")
	assert_eq(panel.content_box.get_child_count(), 0, "按钮不该进内容区")

	var button := panel.footer_box.get_child(0) as Button
	button.pressed.emit()
	assert_true(pressed[0], "页脚按钮应能触发回调")


func test_footer_is_outside_the_scroll_area() -> void:
	## 页脚不能是内容区的子节点，否则还是会被滚走
	var panel := _make_panel()
	await _settle()

	assert_false(panel.content_box.is_ancestor_of(panel.footer_box),
		"页脚不能在内容区里面——那样会被滚动带走")


func test_add_footer_button_returns_a_usable_button() -> void:
	var panel := _make_panel()
	var button := panel.add_footer_button("测试", func() -> void: pass)

	assert_not_null(button)
	assert_eq(button.text, "测试")


# ══ 重建 ════════════════════════════════════════════════════

func test_rebuild_clears_old_content() -> void:
	var panel := _make_panel()
	panel.add_title("旧的")
	panel.rebuild_content()
	await _settle()

	assert_eq(panel.content_box.get_child_count(), 0,
		"rebuild 后不该残留旧内容（基类 _build_content 为空）")


func test_rebuild_refits_the_scroll_area() -> void:
	## ⚠️ 基类的 `_build_content()` 是**空的**，所以 rebuild 之后内容清零、
	## 高度也应该归零。这条验证的是「rebuild 确实重新量过了」，
	## 而不是「高度不会变」——后者是我想当然写错的版本。
	var panel := _make_panel()
	for i: int in 20:
		panel.add_title("内容 %d" % i)
	panel._fit_scroll()
	await _settle()
	assert_gt(panel._scroll.custom_minimum_size.y, 1.0, "加内容后应有高度")

	panel.rebuild_content()
	await _settle()

	assert_eq(panel._scroll.custom_minimum_size.y, 0.0,
		"rebuild 清空内容后高度应归零——说明它重新量过了")


func test_no_ui_string_contains_literal_markdown() -> void:
	## ★ `add_text` / `add_title` 是**普通 Label**（没有 BBCode），
	## 所以字符串里的 `**粗体**` 会**原样显示给玩家**。
	##
	## 这类错误测试断言不出来、运行也不报错——只有"渲染一帧看一眼"才发现。
	## 既然只有肉眼能发现，就把它降级成一条源码级守卫：
	## 扫 `scripts/ui/` 里所有**面向玩家的字符串字面量**，出现 `**` 即失败。
	##
	## 排除：注释（`#` 开头的内容）——那些是写给开发者看的，
	## 本项目到处用 `**` 做强调，不排除会永远红。
	var offenders: Array[String] = []
	for path: String in _ui_scripts():
		var src: String = FileAccess.get_file_as_string(path)
		for line: String in src.split("\n"):
			var code: String = line
			var hash_at: int = code.find("#")
			if hash_at >= 0:
				code = code.substr(0, hash_at)
			if code.contains("**") and (code.contains("\"") or code.contains("'")):
				offenders.append("%s → %s" % [path.get_file(), code.strip_edges()])
	assert_eq(offenders.size(), 0,
		"以下 UI 字符串含 `**`（会原样显示给玩家，改用「」）：\n%s" % "\n".join(offenders))


func _ui_scripts() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://scripts/ui")
	if dir == null:
		return out
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			out.append("res://scripts/ui/%s" % file)
	return out


# ══ 集成：战斗中查看地图（用户报告）════════════════════════

const BATTLE_SCENE_SCRIPT := preload("res://scripts/battle/battle_scene.gd")


func test_battle_map_overlay_shows_the_upcoming_nodes() -> void:
	## ★★ 用户报告：「战斗中无法查看地图接下来的节点」。
	##
	## 根因在基类（见上面三条回归），但这条从**用户视角**再钉一遍：
	## 打开弹层 → 里面真的有一张地图 → 坐标算出来了 → 而且标出了"接下来能去哪"。
	##
	## 只测基类是不够的：那样"战斗场景忘了接线"仍然会漏过。
	ContentRegistry.load_all()
	GameState.start_new_run(&"warrior", 20261009)
	var scene: Variant = BATTLE_SCENE_SCRIPT.new()
	add_child_autofree(scene)

	scene.call("_open_map_overlay")
	await _settle()

	var overlay: Variant = scene.get("_overlay")
	assert_ne(overlay, null, "战斗中必须能打开地图弹层")

	var map_view: MapView = _find_map_view(overlay as Node)
	assert_ne(map_view, null, "弹层里必须真的有一张地图")
	assert_gt(map_view.positioned_node_count(), 0,
		"地图必须算出节点坐标——否则渲染出来是空白")
	assert_gt(map_view.available_node_count(), 0,
		"地图必须标出接下来可去的节点——这是玩家打开它的唯一目的")

	GameState.reset_run()


func test_battle_map_overlay_does_not_stack() -> void:
	## 连点两次不该叠出两个弹层（第二个会被忽略）。
	ContentRegistry.load_all()
	GameState.start_new_run(&"warrior", 20261009)
	var scene: Variant = BATTLE_SCENE_SCRIPT.new()
	add_child_autofree(scene)

	scene.call("_open_map_overlay")
	var first: Variant = scene.get("_overlay")
	scene.call("_open_map_overlay")
	assert_same(scene.get("_overlay"), first, "重复点击不该叠出第二个弹层")

	GameState.reset_run()


func _find_map_view(node: Node) -> MapView:
	if node is MapView:
		return node as MapView
	for child: Node in node.get_children():
		var found: MapView = _find_map_view(child)
		if found != null:
			return found
	return null
