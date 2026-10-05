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


# ══ ④ 卡面文本在「先 set_card 再挂树」时不能丢 ═════════════════
## 真实缺陷：商店的 `_make_card_slot` 是「先建 slot → 建 CardView →
## set_card → 最后才 row.add_child(slot)」。
## `set_card()` 调用时外层容器还没挂树 → `CardView._ready()` 没触发 →
## `_name_label` 是 null → `_refresh_all()` 直接 return。
## 等挂树时标签才建出来，而**那时已经没人再填文本** —— 卡面永远空白。
##
## 表现是「商店的卡没有名字没有效果」，而它是**生命周期顺序**问题，
## 不是渲染问题——不报任何错。

func test_card_view_renders_when_set_card_precedes_tree_entry() -> void:
	var holder := VBoxContainer.new()          # 刻意不挂树
	var view := CardView.new()
	holder.add_child(view)
	view.set_card(ContentRegistry.get_card(&"strike"))   # 此时 view 还没 _ready

	add_child_autofree(holder)                 # 现在才挂树
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(view._name_label.text, "打击",
		"卡名丢了——`set_card()` 早于 `_ready()` 时必须补一次刷新")
	assert_true(view._desc_label.text.contains("伤害"),
		"卡牌描述丢了")


func test_card_view_still_renders_when_added_first() -> void:
	## 反过来（先挂树再 set_card）本来就能用，别改坏了
	var view := CardView.new()
	add_child_autofree(view)
	view.set_card(ContentRegistry.get_card(&"defend"))
	await get_tree().process_frame

	assert_eq(view._name_label.text, "防御")


func test_shop_card_slots_show_name_and_effect() -> void:
	## 直接建一个真实的商店面板，断言卡槽里的卡面**有名字**
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var offers: Array[CardData] = CardPool.new(rng, &"warrior").roll(3)

	var shop := ShopPanel.new()
	add_child_autofree(shop)
	shop.setup(999, offers, [], [], [])
	await get_tree().process_frame
	await get_tree().process_frame

	var found: int = 0
	for child: Node in shop.content_box.get_children():
		for slot: Node in child.get_children():
			for inner: Node in slot.get_children():
				if inner is CardView:
					var view := inner as CardView
					assert_ne(view._name_label.text, "",
						"商店卡面没有名字")
					found += 1
	assert_gt(found, 0, "没找到任何卡槽——商店结构变了？")


# ══ ⑤ 删牌要二次确认 ════════════════════════════════════════

func test_removal_asks_for_confirmation_first() -> void:
	## 删牌不可逆，玩家常常是"随便点点看"——必须拦一道
	var source := FileAccess.get_file_as_string("res://scripts/ui/shop_panel.gd")
	var start: int = source.find("func _on_remove_pressed(")
	assert_gt(start, 0)
	var end: int = source.find("\nfunc ", start + 1)
	var body: String = source.substr(start, end - start)

	assert_true(body.contains("ConfirmPanel"),
		"点删牌必须先弹确认，不能直接 emit removal_requested")
	assert_false(body.contains("removal_requested.emit"),
		"确认之前不该发出删除请求")


func test_confirm_panel_has_both_buttons_in_footer() -> void:
	var panel := ConfirmPanel.new()
	add_child_autofree(panel)
	panel.setup("标题", "正文")
	await get_tree().process_frame

	assert_eq(panel.footer_box.get_child_count(), 2, "确认 / 取消都该在固定页脚")
