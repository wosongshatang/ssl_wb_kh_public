extends GutTest
## 事件效果结算 —— **行为级**测试
##
## ## 为什么单独建一个文件
## 之前"事件效果"这块**只有源码级检查**（grep 一下有没有写 `_run.add_card`），
## 没有一条断言"选了之后状态真的变了"。于是漏掉了一个真 bug：
##
##   `_on_event_option_chosen()` 里 `_current_event` 被**立刻置空**
##   （防快速双击白拿两份收益），而 `_apply_effect()` 却去读
##   `_current_event.deity_id` → **空对象取值** → 整段结算中断。
##
##   表现：选了「接受战神的赠礼」**什么都没发生，卡组也没加牌**。
##   而其他不需要事件上下文的效果（回血 / 加钱）照常工作——
##   所以从"有些事件好使、有些不好使"极难定位。
##
## 教训：**"状态没变"必须被断言**。只检查"代码里写了这一行"是查不出
## "那一行运行时抛错了"的。

const MAP_SCENE_SCRIPT := preload("res://scripts/map/map_scene.gd")

## 所有事件数据里实际出现过的 effect 数值（从 .tres 清点，见 before_all 校验）
const EVENT_POOL_IDS: Array[StringName] = [
	&"shrine_of_war", &"rebel_broker", &"wandering_alchemist",
	&"god_offer_war", &"god_offer_arcane", &"cursed_altar", &"usurp_power",
	&"god_gift_special", &"wandering_merchant", &"blood_oath",
	&"forgotten_library", &"broken_statue",
	&"ancient_spring", &"trial_stone", &"bone_altar", &"field_medic",
	&"ash_merchant", &"old_smith", &"withered_grove", &"silent_bell",
]


func before_all() -> void:
	ContentRegistry.load_all()


func after_each() -> void:
	# MapScene._ready 会在没有 run 时自己造一个；跑完清掉，免得污染其他测试
	GameState.reset_run()


# ══ ① 用户报告的 bug：神明赠与 ══════════════════════════════

func test_divine_card_offer_actually_adds_a_card() -> void:
	## ★★ 用户报告：「事件选择获得神明赠与的卡时没有反应，卡组里没有添加牌」。
	## 根因见文件头。这条测试**必须**断言卡组张数变化——
	## 断言"返回的文案里有『获得』"是不够的：文案在崩之前就拼好了的话
	## 一样会通过，而玩家什么都没拿到。
	var scene: Variant = _make_map_scene()
	var run: RunState = GameState.run
	var before: int = run.deck_card_ids.size()

	var event: EventData = ContentRegistry.get_event(&"god_offer_war") as EventData
	assert_ne(event, null, "找不到 god_offer_war 事件")
	scene.set("_current_event", event)
	scene.call("_on_event_option_chosen", 0)

	assert_gt(run.deck_card_ids.size(), before,
		"接受神明赠礼后卡组必须多一张牌（实际 %d → %d）"
			% [before, run.deck_card_ids.size()])


func test_divine_card_offer_raises_divinity() -> void:
	## 神明的赠礼都有代价：拿卡的同时神性上涨。
	## 只加卡不加神性的话，"代价"这条设计就消失了，而且不会报错。
	var scene: Variant = _make_map_scene()
	var before: int = GameState.divinity

	var event: EventData = ContentRegistry.get_event(&"god_offer_arcane") as EventData
	scene.set("_current_event", event)
	scene.call("_on_event_option_chosen", 0)

	assert_gt(GameState.divinity, before, "神明赠礼应让神性上涨")


func test_divine_card_granted_belongs_to_the_event_deity() -> void:
	## 战神的事件只能给战神的牌。给错神明会让"代价"与"来源"对不上。
	var scene: Variant = _make_map_scene()
	var run: RunState = GameState.run
	var before: Array[StringName] = run.deck_card_ids.duplicate()

	var event: EventData = ContentRegistry.get_event(&"god_offer_war") as EventData
	scene.set("_current_event", event)
	scene.call("_on_event_option_chosen", 0)

	var added: Array[StringName] = []
	for cid: StringName in run.deck_card_ids:
		if not before.has(cid):
			added.append(cid)
	assert_eq(added.size(), 1, "应恰好新增一张牌")

	var card: CardData = ContentRegistry.get_card(added[0]) as CardData
	assert_ne(card, null, "新增的牌查不到数据")
	assert_eq(card.deity_id, &"war", "战神事件给的牌应属于战神")


func test_apply_effect_works_after_current_event_is_cleared() -> void:
	## ★★ 把根因单独钉死：`_current_event` 在结算**之前**就被置空，
	## 结算函数必须靠**传参**拿到事件，不能读成员变量。
	##
	## 这条直接模拟"已置空"的状态——如果有人把实现改回读成员变量，
	## 这条立刻红，且失败信息直接指向原因。
	var scene: Variant = _make_map_scene()
	var run: RunState = GameState.run
	var before: int = run.deck_card_ids.size()

	var event: EventData = ContentRegistry.get_event(&"god_offer_war") as EventData
	scene.set("_current_event", null)   # 模拟"已被消费"
	var result: String = scene.call("_apply_effect",
		EventData.Effect.ADD_DIVINE_CARD, 0, event)

	assert_gt(run.deck_card_ids.size(), before,
		"`_current_event` 为 null 时，结算仍必须靠传参拿到事件并生效")
	assert_ne(result, "", "结算必须返回一句给玩家看的结果文案")


# ══ ② 花钱类选项（顺手发现的同类 bug）════════════════════════

func test_negative_gold_option_actually_spends() -> void:
	## ★ 与神明赠与**同一次排查中发现的第二个 bug**：
	## `RunState.add_gold()` 拒绝负数（push_error + return），
	## 而事件结算对正负一律调 `add_gold(value)` →
	## 「花钱买下药水（−35 金币）」**扣钱静默失效**，金币没少、药水也没拿到。
	##
	## 同样只影响负数选项，所以"有些事件好使"这个现象掩盖了它。
	var scene: Variant = _make_map_scene()
	var run: RunState = GameState.run
	var before: int = run.gold

	var event: EventData = ContentRegistry.get_event(&"wandering_alchemist") as EventData
	scene.call("_apply_effect", EventData.Effect.GOLD, -35, event)

	assert_eq(run.gold, before - 35, "花钱选项必须真的扣钱")


func test_negative_gold_option_reports_insufficient_funds() -> void:
	## 钱不够时不能扣成负数（`spend_gold` 会拒绝），但**文案要说清楚**，
	## 不能让玩家以为"我付了钱但没拿到东西"。
	var scene: Variant = _make_map_scene()
	var run: RunState = GameState.run
	run.gold = 10

	var event: EventData = ContentRegistry.get_event(&"wandering_merchant") as EventData
	var result: String = scene.call("_apply_effect", EventData.Effect.GOLD, -60, event)

	assert_eq(run.gold, 10, "钱不够时不该扣")
	assert_true(result.contains("不足"), "钱不够必须明说，实际返回：%s" % result)


func test_gold_never_goes_negative_from_events() -> void:
	var scene: Variant = _make_map_scene()
	var run: RunState = GameState.run
	run.gold = 5
	var event: EventData = ContentRegistry.get_event(&"wandering_merchant") as EventData
	scene.call("_apply_effect", EventData.Effect.GOLD, -60, event)
	assert_gte(run.gold, 0, "金币不能变成负数")


func test_negative_max_hp_option_reads_correctly() -> void:
	## 第三个同类问题：「血誓」的 −6 最大生命。
	## 结算本身没错，但文案会拼成"最大生命 +-6"。
	## 结算文案与 `effect_text`（选项按钮上那句）**两处都要正确**。
	var scene: Variant = _make_map_scene()
	var run: RunState = GameState.run
	var before: int = run.max_hp

	var event: EventData = ContentRegistry.get_event(&"blood_oath") as EventData
	var result: String = scene.call("_apply_effect", EventData.Effect.MAX_HP, -6, event)

	assert_eq(run.max_hp, before - 6, "负的最大生命选项应真的削上限")
	assert_false(result.contains("+-"), "文案不能出现「+-」：%s" % result)
	assert_false(EventData.effect_text(EventData.Effect.MAX_HP, -6).contains("+-"),
		"选项按钮上的描述也不能出现「+-」")


func test_max_hp_option_never_drops_below_one() -> void:
	## 上限被削到 0 会让后续所有按 max_hp 算的东西（休息回血、进阶扣血）全崩。
	var scene: Variant = _make_map_scene()
	var run: RunState = GameState.run
	var event: EventData = ContentRegistry.get_event(&"blood_oath") as EventData
	scene.call("_apply_effect", EventData.Effect.MAX_HP, -999, event)
	assert_gte(run.max_hp, 1, "最大生命不能被事件削到 0")
	assert_lte(run.hp, run.max_hp, "削上限后当前血量不能超过上限")


# ══ ③ 每个事件选项都必须真的改变状态 ════════════════════════

func test_every_event_option_changes_something() -> void:
	## ★ 表驱动：把 20 个事件的**每一个选项**都跑一遍，断言"至少有一样东西变了"。
	##
	## 守的是"某个效果静默变成空操作"——这类 bug 不会报错，
	## 玩家只会觉得"这个事件点了没用"，而且**每个效果单独看代码都是对的**。
	##
	## 比对的是 6 个可观测量的快照：牌组 / 遗物 / 药水 / 金币 / 生命 / 神性。
	var failures: Array[String] = []

	for event_id: StringName in EVENT_POOL_IDS:
		var event: EventData = ContentRegistry.get_event(event_id) as EventData
		if event == null:
			failures.append("%s：事件数据缺失" % event_id)
			continue
		for option_index: int in 2:
			var effect: int = event.option_a_effect if option_index == 0 \
				else event.option_b_effect
			var value: int = event.option_a_value if option_index == 0 \
				else event.option_b_value

			# `NONE` 就是"什么都不发生"，是合法设计，跳过
			if effect == EventData.Effect.NONE:
				continue

			var scene: Variant = _make_map_scene()
			var before: Dictionary = _snapshot()
			scene.call("_apply_effect", effect, value, event)
			var after: Dictionary = _snapshot()
			scene.free()

			if before == after:
				failures.append("%s 选项 %s（effect=%d, value=%d）什么都没改变"
					% [event_id, "A" if option_index == 0 else "B", effect, value])

	assert_eq(failures.size(), 0,
		"以下事件选项是**空操作**（玩家点了没反应）：\n%s" % "\n".join(failures))


func test_event_pool_ids_all_exist() -> void:
	## 上一条表驱动依赖这个列表。列表写错（比如抄了个不存在的 id）
	## 会让那条测试**静默少测一个事件**——所以单独钉一下。
	for event_id: StringName in EVENT_POOL_IDS:
		assert_ne(ContentRegistry.get_event(event_id), null,
			"事件「%s」在数据里不存在" % event_id)


# ══ ④ 神明赠与的两个事件本身要自洽 ══════════════════════════

func test_god_offer_events_point_at_deities_with_cards() -> void:
	## 事件写了个没有无色卡的神明 id 时，玩家会看到"没有可赠予的无色卡"。
	## 那是**内容配置错误**，不该等到玩家点进去才发现。
	for event_id: StringName in [&"god_offer_war", &"god_offer_arcane"]:
		var event: EventData = ContentRegistry.get_event(event_id) as EventData
		assert_ne(event, null, "找不到 %s" % event_id)
		assert_ne(event.deity_id, &"", "%s 没写神明 id" % event_id)
		assert_gt(ContentRegistry.divine_cards_for(event.deity_id).size(), 0,
			"%s 指向的神明「%s」没有任何无色卡可赠" % [event_id, event.deity_id])


# ══ 工具 ════════════════════════════════════════════════════

## 造一个跑过 `_ready()` 的地图场景（UI 与单局状态都建好）。
##
## ⚠️ 必须 `add_child_autofree` 而不是直接 `new()`：
## `_hint_label` / `_run` 都是在 `_ready()` 里建的，
## 不挂树的话结算里写 `_hint_label.text` 会空对象取值。
##
## ⚠️ 返回类型写 `Variant` 并**显式标注**（不能用 `:=`）：
## 本项目把警告当错误，`:=` 推断 Variant 会直接解析失败。
##
## ## 为什么把血量压到一半
## 满血时 `HEAL` **天然是空操作**——那不是 bug，但会让"空操作"检测
## 把一整类正常效果误报成坏的。而且**玩家几乎不会满血走进事件节点**，
## 半血才是真实场景。压一半之后所有效果都变成可观测的。
func _make_map_scene() -> Variant:
	# 每次都从干净的单局状态开始，否则"牌组张数"这类断言会互相污染
	GameState.start_new_run(&"warrior", 20261009)
	var run: RunState = GameState.run
	run.hp = int(run.max_hp / 2)
	var scene: Variant = MAP_SCENE_SCRIPT.new()
	add_child_autofree(scene)
	return scene


## 结算前 / 后的可观测状态快照
func _snapshot() -> Dictionary:
	var run: RunState = GameState.run
	return {
		"deck": run.deck_card_ids.size(),
		"relics": run.relics.size(),
		"potions": run.potions.size(),
		"gold": run.gold,
		"hp": run.hp,
		"max_hp": run.max_hp,
		"divinity": GameState.divinity,
	}
