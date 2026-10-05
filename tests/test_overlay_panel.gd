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
