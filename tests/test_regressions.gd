extends GutTest
## 回归测试 —— 每个用例对应一个**真实发生过**的缺陷
##
## ## 为什么单独一个文件
## 这些 bug 的共同点是：**不报错、不崩溃，而且原来的测试全绿**。
## 它们只能靠"针对那个具体行为写一条断言"来守住。
## 放在一起是为了让"我们踩过哪些坑"一眼可见。

func before_all() -> void:
	ContentRegistry.load_all()


# ══ ① 升级不能污染注册表模板 ═════════════════════════════════
## 真实缺陷：`Resource.duplicate()` 是**浅拷贝**，
## `apply_to_self` 字典和原牌共享引用 → `apply_upgrade()` 改到了模板。
## 而 `ContentRegistry` 整个进程只加载一次 → 污染跨局残留。
## 更糟的是**升级界面一预览就污染**（预览也调 `create_upgraded()`）。

func test_upgrading_does_not_mutate_the_template() -> void:
	var card: CardData = ContentRegistry.get_card(&"charge_up")
	var before: Dictionary = card.apply_to_self.duplicate()

	var upgraded := card.create_upgraded()

	assert_eq(card.apply_to_self, before,
		"升级副本改到了原牌——注册表模板被污染，会跨局残留")
	assert_ne(upgraded.apply_to_self, card.apply_to_self,
		"副本应该真的变了（否则升级没生效）")


func test_repeated_upgrade_previews_do_not_stack() -> void:
	## ★ 这条最能说明问题的严重性：
	## 升级界面每预览一次就调一次 `create_upgraded()`。
	## 浅拷贝的话，模板会 2 → 4 → 6 → 8 一路涨上去。
	var card: CardData = ContentRegistry.get_card(&"charge_up")

	for _i: int in 5:
		card.create_upgraded()

	var fresh: CardData = ContentRegistry.get_card(&"charge_up")
	assert_eq(int(fresh.apply_to_self.get("strength", 0)), 2,
		"预览五次之后模板应还是 2——否则玩家会看到越预览越强的牌")


func test_every_card_template_survives_upgrade_preview() -> void:
	## 全量扫一遍：任何一张牌的升级预览都不该改动模板
	for card: CardData in ContentRegistry.all_cards():
		var snapshot: Dictionary = card.apply_to_self.duplicate()
		var target_snapshot: Dictionary = card.apply_to_target.duplicate()
		var damage_before: int = card.damage
		var block_before: int = card.block

		card.create_upgraded()

		assert_eq(card.apply_to_self, snapshot, "%s 的 apply_to_self 被预览改动了" % card.id)
		assert_eq(card.apply_to_target, target_snapshot, "%s 的 apply_to_target 被预览改动了" % card.id)
		assert_eq(card.damage, damage_before, "%s 的伤害被预览改动了" % card.id)
		assert_eq(card.block, block_before, "%s 的格挡被预览改动了" % card.id)


func test_power_card_upgrade_adds_two() -> void:
	## 用户报告「能力牌升级统一 +2 没实现」——
	## 真相是**实现了，但改到模板上去了**，所以看起来没变。
	var card: CardData = ContentRegistry.get_card(&"charge_up")
	assert_eq(card.type, CardData.CardType.POWER, "charge_up 应该是能力牌")

	var upgraded := card.create_upgraded()

	assert_eq(int(upgraded.apply_to_self.get("strength", 0)),
		int(card.apply_to_self.get("strength", 0)) + 2,
		"能力牌升级应统一 +2")


# ══ ② 重建内容必须清空页脚 ═══════════════════════════════════
## 真实缺陷：`rebuild_content()` 只清内容不清页脚，
## 商店切一次「删牌页」就多一个「返回商品页」，四次之后页脚挤满废按钮。

func test_rebuild_clears_the_footer() -> void:
	var panel := OverlayPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame

	for _i: int in 4:
		panel.add_footer_button("返回商品页", func() -> void: pass)
	assert_eq(panel.footer_box.get_child_count(), 4)

	panel.rebuild_content()
	await get_tree().process_frame

	assert_eq(panel.footer_box.get_child_count(), 0,
		"rebuild 后页脚应清空——否则每重建一次就多一批按钮")


func test_repeated_rebuild_does_not_accumulate_footer_buttons() -> void:
	var panel := OverlayPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame

	for _i: int in 5:
		panel.add_footer_button("按钮", func() -> void: pass)
		panel.rebuild_content()
		await get_tree().process_frame

	# 最后一轮加的那个应该还在（rebuild 在加之后）
	assert_lte(panel.footer_box.get_child_count(), 1,
		"反复重建不该让页脚按钮堆积")


# ══ ③ 节点内部操作不落盘（SL 完整可用）═══════════════════════
## 真实缺陷：`_on_shop_closed` 存档 → 玩家离开商店后节点就被标记完成，
## SL 之后直接跳过整个商店。

func test_leaving_the_shop_does_not_save() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/map/map_scene.gd")
	var start: int = source.find("func _on_shop_closed(")
	assert_gt(start, 0)
	var end: int = source.find("\nfunc ", start + 1)
	var body: String = source.substr(start, end - start)

	assert_true(body.contains("false"),
		"离开商店必须传 save=false——否则 SL 回不到这个节点")


func test_all_node_internal_handlers_pass_save_false() -> void:
	## 休息 / 锻造 / 神坛 / 叛神者 / 事件 / 商店——
	## **节点内部的操作全都不该落盘**，否则 SL 只能覆盖到"节点中途"。
	var source := FileAccess.get_file_as_string("res://scripts/map/map_scene.gd")

	for handler: String in [
		"_on_rest_chosen", "_on_upgrade_card_chosen", "_on_altar_sacrifice",
		"_on_altar_leave", "_on_traitor_strip", "_on_traitor_deepen",
		"_on_event_option_chosen", "_on_shop_closed",
	]:
		var start: int = source.find("func %s(" % handler)
		assert_gt(start, 0, "找不到 %s" % handler)
		var end: int = source.find("\nfunc ", start + 1)
		var body: String = source.substr(start, end - start)

		if body.contains("_persist_and_refresh"):
			assert_true(body.contains("false"),
				"%s 里的 _persist_and_refresh 必须传 save=false" % handler)
