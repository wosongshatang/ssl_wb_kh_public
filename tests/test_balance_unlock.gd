extends GutTest
## 阶段 7 · 解锁型数值修复 + 数据驱动内容扩充
##
## 这一批守的是**"已建成的内容能不能被玩家走到"**——
## 之前的问题是：12 条转职路径、99 张卡、46 个敌人已经建好，
## 但第三幕有一堵**物理上不可通过**的数值墙（单次意图 40 伤 > 玩家 30 血），
## 以及**遗物池只有 13 个**（一局拿光后"精英必掉遗物"静默失效）。
##
## 数值区间一律**两档制**（与 D17 / D27 同一套哲学）：
## 理想区只打印警告、硬上限才判失败——门禁误报会让人干脆关掉门禁。

func before_all() -> void:
	ContentRegistry.load_all()


## 收集一个敌人的**全部攻击意图**（基础 + 各阶段）。
## 只看攻击（type == 0）——防御/增益不造成伤害。
func _attack_intents(data: EnemyData) -> Array:
	var out: Array = []
	for intent: IntentData in data.intents:
		if intent.type == 0:
			out.append(intent)
	for phase: EnemyPhase in data.phases:
		for intent: IntentData in phase.intents:
			if intent.type == 0:
				out.append(intent)
	return out


# ══ 解锁型修复 ①：即死意图 ═══════════════════════════════════

func test_no_intent_is_instantly_lethal() -> void:
	## ★ 硬上限：单次意图总伤必须 **< 玩家起始最大生命**。
	##
	## 原 act3_boss 最后形态是 `20 × 2 = 40`，而玩家 max_hp 只有 30、
	## 单回合格挡上限 15 —— **无论怎么决策都必死**。
	## 这不是难度，是"游戏在此处终止"，它挡住了后面所有内容。
	var lethal: Array[String] = []
	var over_ideal: Array[String] = []

	for enemy_id: StringName in ContentRegistry.all_enemy_ids():
		var data: EnemyData = ContentRegistry.get_enemy(enemy_id)
		if data == null:
			continue
		for intent: IntentData in _attack_intents(data):
			var total: int = intent.value * intent.times
			if total >= RunState.DEFAULT_MAX_HP:
				lethal.append("%s=%d" % [enemy_id, total])
			elif total > int(RunState.DEFAULT_MAX_HP * 0.6):
				over_ideal.append("%s=%d" % [enemy_id, total])

	assert_eq(lethal.size(), 0,
		"以下意图一击必杀（总伤 ≥ 玩家最大生命 %d）：%s" % [RunState.DEFAULT_MAX_HP, ", ".join(lethal)])

	# 理想线（60%）只警告——把"可接受但偏高"的意图刷成失败会触发门禁误报
	if not over_ideal.is_empty():
		print("⚠️ 超过理想线（%d）的意图（仅警告）：%s" % [
			int(RunState.DEFAULT_MAX_HP * 0.6), ", ".join(over_ideal)])


func test_act3_boss_fight_length_is_reasonable() -> void:
	## 玩家常态回合 ≈ 12 输出（3 能量 × 打击 6 伤）。
	## 190 血 = 16 回合，长到"重复劳动"区间；145 血 ≈ 12 回合（4 阶段各 3 回合）。
	var data: EnemyData = ContentRegistry.get_enemy(&"act3_boss")
	assert_not_null(data)
	assert_lte(data.max_hp, 160, "第三幕 Boss 血量过高，单场战斗会拖到失去决策意义")
	assert_gte(data.max_hp, 120, "第三幕 Boss 血量过低，会失去终局压迫感")


func test_boss_hp_curve_has_no_cliff() -> void:
	## 相邻幕 Boss 血量比不应超过 1.5——原 105 → 190 是 +81% 的断崖，
	## 与精英曲线（+26% / +21%）完全脱节
	var prev: int = 0
	for act: int in [1, 2, 3]:
		var data: EnemyData = ContentRegistry.get_enemy(StringName("act%d_boss" % act))
		assert_not_null(data, "找不到第 %d 幕 Boss" % act)
		if prev > 0:
			var ratio: float = float(data.max_hp) / float(prev)
			assert_lte(ratio, 1.5, "第 %d 幕 Boss 血量相对上一幕涨了 %.0f%%，是断崖" % [act, (ratio - 1.0) * 100.0])
		prev = data.max_hp


func test_act3_elite_is_not_thinner_than_act2() -> void:
	var act2: EnemyData = ContentRegistry.get_enemy(&"act2_elite")
	var act3: EnemyData = ContentRegistry.get_enemy(&"act3_elite")
	assert_not_null(act2)
	assert_not_null(act3)
	assert_gt(act3.max_hp, act2.max_hp, "第三幕精英不该比第二幕还脆")


# ══ 解锁型修复 ②：经济 ═══════════════════════════════════════

func test_combat_gold_reward_is_calibrated() -> void:
	## 单场金币 × 一局约 21 场普通 + 6 场精英，总收入应支撑 6 个商店
	## 各买 2–3 件（原 12/30 时总收入 ~590，每店买不到 1 件）
	## ⚠️ battle_scene.gd 没有 class_name（它是场景根脚本），只能 load 后读常量
	var scene: GDScript = load("res://scripts/battle/battle_scene.gd")
	assert_gte(int(scene.GOLD_REWARD_COMBAT), 18, "普通战斗金币过低，商店会沦为陈列窗")
	assert_gte(int(scene.GOLD_REWARD_ELITE), 45, "精英金币与血量倍率不匹配")


func test_elite_gold_reflects_its_difficulty() -> void:
	var scene: GDScript = load("res://scripts/battle/battle_scene.gd")
	var ratio: float = float(scene.GOLD_REWARD_ELITE) / float(scene.GOLD_REWARD_COMBAT)
	assert_gte(ratio, 2.0, "精英与普通的收入比应至少 2 倍，否则打精英没有收益理由")


func test_card_removal_is_affordable() -> void:
	## 删牌是"薄牌组"流派的核心操作。原价 75 只比一张蓝卡（85）便宜 10，
	## 把整个流派的价格门槛抬到不可及
	assert_lte(ShopPanel.REMOVAL_PRICE, 60, "删牌价格过高，薄牌组流派无法实现")


# ══ 解锁型修复 ③：遗物授予的一次性结算 ═══════════════════════

func _new_run() -> RunState:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	return run


func test_grant_relic_applies_permanent_max_hp_bonus() -> void:
	var run: RunState = _new_run()
	var before: int = run.max_hp

	assert_true(run.grant_relic(&"stone_heart"), "石心应授予成功")
	assert_eq(run.max_hp, before + 6, "石心应提供 +6 永久最大生命")
	assert_eq(run.hp, before + 6, "补的这部分生命应同时补满当前血，否则看起来像 bug")


func test_grant_relic_is_idempotent() -> void:
	var run: RunState = _new_run()
	# ⚠️ 战士开局自带「燃烧之血」，所以基数是 1 而不是 0
	var baseline: int = run.relics.size()
	var before: int = run.max_hp

	assert_true(run.grant_relic(&"stone_heart"))
	assert_false(run.grant_relic(&"stone_heart"), "重复授予应返回 false")
	assert_eq(run.max_hp, before + 6, "重复授予不该叠加最大生命")
	assert_eq(run.relics.size(), baseline + 1, "遗物列表不该出现重复条目")


func test_grant_relic_rejects_empty_id() -> void:
	var run: RunState = _new_run()
	var baseline: int = run.relics.size()
	assert_false(run.grant_relic(&""), "空 id 不该被当成一件遗物")
	assert_eq(run.relics.size(), baseline)


func test_max_hp_relic_does_not_grow_across_battles() -> void:
	## ★★ 这是本批最重要的回归测试。
	##
	## 遗物实例**每场战斗重建**，而战斗结束会把 `creature.max_hp` 同步回
	## `RunState.max_hp`。所以如果把「+6 最大生命」挂在遗物的 `at_battle_start`，
	## 就会变成：第 1 场 30→36、第 2 场 36→42 …… **无限增长**。
	## 这类 bug 不报错、只让数值缓慢失控，而且因为"每场都变强了一点"极难察觉。
	##
	## 这里模拟真实流程：授予遗物 → 打三场战斗 → 断言 max_hp 不再变化。
	var run: RunState = _new_run()
	run.grant_relic(&"stone_heart")
	var expected: int = run.max_hp

	for _battle: int in 3:
		var creature := Player.new()
		creature.display_name = "战士"
		creature.max_hp = run.max_hp
		creature.reset_for_battle()

		# 遗物的战斗钩子**必须不碰 max_hp**
		for relic_id: StringName in run.relics:
			var relic: AbstractRelic = BasicRelics.create(relic_id)
			assert_not_null(relic, "遗物 %s 没有代码实现" % relic_id)
			relic.owner_creature = creature
			relic.at_battle_start(creature)

		run.sync_from_creature(creature)
		creature.free()

	assert_eq(run.max_hp, expected,
		"最大生命在多场战斗后发生了变化——说明有遗物在战斗钩子里改 max_hp（会无限增长）")


func test_droppable_relic_pool_is_deep_enough() -> void:
	## 一局期望掉落 ~10 个（6 次精英必掉 + 21 次普通 × 18%）。
	## 池子小于这个数就会枯竭，`_roll_relic_drop()` 返回空串——
	## **精英"必掉遗物"的承诺静默失效**，玩家打了最难的节点却什么也没有。
	var pool: Array[StringName] = RelicFactory.droppable_ids([])
	assert_gte(pool.size(), 20, "可掉落遗物池只有 %d 个，一局内会被拿光" % pool.size())


func test_every_registered_relic_is_creatable() -> void:
	for relic_id: StringName in BasicRelics.ids():
		assert_not_null(BasicRelics.create(relic_id), "遗物 %s 在 ids() 里但没有 create() 分支" % relic_id)
		assert_not_null(ContentRegistry.get_relic(relic_id), "遗物 %s 缺少 .tres（UI 查不到名字）" % relic_id)


# ══ 新内容 ①：事件（12 → 20）════════════════════════════════

func test_event_pool_is_expanded() -> void:
	## 单局约 3 个事件节点。池子只有 12 个时每局看到的事件高度重复
	assert_gte(MapManager.EVENT_POOL.size(), 20, "事件池未扩充到 20 个")


func test_new_events_offer_max_hp_growth() -> void:
	## A1（玩家无成长）的主要修复来源之一：事件提供永久最大生命。
	## 玩家需要从 30 涨到 ~50，单靠遗物不够
	var sources: int = 0
	for event_id: StringName in MapManager.EVENT_POOL:
		var data: EventData = ContentRegistry.get_event(event_id)
		if data == null:
			continue
		if data.option_a_effect == EventData.Effect.MAX_HP or data.option_b_effect == EventData.Effect.MAX_HP:
			sources += 1
	assert_gte(sources, 4, "提供最大生命成长的事件太少（只有 %d 个）" % sources)


func test_every_event_option_has_a_label() -> void:
	## 空标签会让玩家看到一个没有文字的按钮
	for event_id: StringName in MapManager.EVENT_POOL:
		var data: EventData = ContentRegistry.get_event(event_id)
		assert_not_null(data, "事件 %s 不存在" % event_id)
		assert_ne(data.option_a_label, "", "事件 %s 的选项 A 没有标签" % event_id)
		assert_ne(data.option_b_label, "", "事件 %s 的选项 B 没有标签" % event_id)


# ══ 新内容 ②：3 费卡牌（4 → 9）══════════════════════════════

func test_three_cost_card_pool_is_deep_enough() -> void:
	var count: int = 0
	for card: CardData in ContentRegistry.all_cards():
		if card.cost == 3:
			count += 1
	assert_gte(count, 8, "3 费牌池太浅（只有 %d 张），高费构筑无法展开" % count)


func test_three_cost_cards_stay_in_value_band() -> void:
	## 每能量价值表：3 费**净价值**应在 16–40（不含特殊牌）。
	## 净价值 = 伤害 + 格挡 − 自身生命流失——代价牌（如「万象归墟」42 伤 / 自伤 10）
	## 用高伤害换高风险，必须把代价扣掉才能横向比较。
	## 原 2 费段内部离散度达 3.75×，就是因为没有这张表做约束
	for card: CardData in ContentRegistry.all_cards():
		if card.cost != 3 or card.is_special():
			continue
		var value: int = card.damage + card.block - card.self_hp_loss
		if value <= 0:
			continue
		assert_between(value, 16, 40, "「%s」的 3 费净价值（%d）偏离区间" % [card.display_name, value])


func test_new_cards_are_reachable_by_their_character() -> void:
	## 卡牌必须能进对应角色的奖励池，否则等于没做
	var expect: Dictionary = {
		&"earthshaker": &"warrior",
		&"last_stand": &"warrior",
		&"arcane_nova": &"mage",
		&"frost_prison": &"mage",
		&"hunters_volley": &"hunter",
	}
	for card_id: StringName in expect:
		var card: CardData = ContentRegistry.get_card(card_id)
		assert_not_null(card, "找不到新卡 %s" % card_id)
		var character: StringName = expect[card_id]
		var pool := CardPool.new(RandomNumberGenerator.new(), character)
		assert_true(pool.reward_candidates().has(card),
			"「%s」不在 %s 的奖励池里，玩家永远抽不到" % [card.display_name, character])


# ══ 新内容 ③：幕机制（9 → 12）与机制池 ══════════════════════

func test_modifier_pools_are_declared_for_all_acts() -> void:
	for character: StringName in [&"warrior", &"mage", &"hunter"]:
		for act: int in [1, 2, 3]:
			var pool: Array[StringName] = MapManager.modifier_pool_for(character, act)
			assert_false(pool.is_empty(), "%s 第 %d 幕没有机制池" % [character, act])


func test_pool_first_entry_matches_primary_modifier() -> void:
	## 池首必须是主机制——`act_modifier_id()` 返回它，
	## 工具链与既有测试都依赖这个确定性
	for character: StringName in [&"warrior", &"mage", &"hunter"]:
		for act: int in [1, 2, 3]:
			var pool: Array[StringName] = MapManager.modifier_pool_for(character, act)
			assert_eq(pool[0], MapManager.act_modifier_id(character, act),
				"%s 第 %d 幕：机制池首项必须是主机制" % [character, act])


func test_every_modifier_pool_member_is_implemented() -> void:
	## 池子里的每一项都必须**既有 .tres 又有代码实现**——
	## 否则会静默退化成"这一局没有幕机制"
	for character: StringName in [&"warrior", &"mage", &"hunter"]:
		for act: int in [1, 2, 3]:
			for modifier_id: StringName in MapManager.modifier_pool_for(character, act):
				var data: Variant = ContentRegistry.get_act_modifier(modifier_id)
				assert_not_null(data, "机制 %s 没有 .tres" % modifier_id)
				assert_true(ActModifiers.is_known(modifier_id), "机制 %s 没有登记在 is_known()" % modifier_id)
				assert_not_null(ActModifiers.create(data as ActModifier, null),
					"机制 %s 无法实例化" % modifier_id)


func test_act_modifier_roll_is_deterministic() -> void:
	## 同一局同一种子必须抽到同一机制，否则读档后幕机制会变——
	## 玩家会看到"我明明记得这关是血月"
	for character: StringName in [&"warrior", &"mage", &"hunter"]:
		for act: int in [1, 2, 3]:
			var a: StringName = MapManager.roll_act_modifier_id(character, act, 20261008)
			var b: StringName = MapManager.roll_act_modifier_id(character, act, 20261008)
			assert_eq(a, b, "%s 第 %d 幕的机制抽取不确定" % [character, act])


func test_single_entry_pool_always_returns_the_primary() -> void:
	## 没配 modifier_pool 的图必须退化成"只有主机制"，老数据不改也能用
	var pool: Array[StringName] = MapManager.modifier_pool_for(&"mage", 1)
	assert_eq(pool.size(), 1, "法师第一幕没配机制池，应退化成单元素池")
	assert_eq(MapManager.roll_act_modifier_id(&"mage", 1, 999), &"tower_lesson")


# ══ 新内容 ④：敌人（补齐法师 / 猎人线）═══════════════════════

func test_mage_and_hunter_lines_have_enough_enemies() -> void:
	## 单幕约 8 场战斗。池子只有 3 种敌人时，一局内会反复遇到同一种
	for character: StringName in [&"mage", &"hunter"]:
		for act: int in [1, 2, 3]:
			var pool: Array = MapManager.combat_pool(character, act)
			assert_gte(pool.size(), 4, "%s 第 %d 幕只有 %d 种敌人，重复感过强" % [character, act, pool.size()])


func test_new_enemies_are_wired_into_a_pool() -> void:
	var wired: Dictionary = {}
	for character: StringName in [&"warrior", &"mage", &"hunter"]:
		for act: int in [1, 2, 3]:
			for enemy_id: Variant in MapManager.combat_pool(character, act):
				wired[StringName(str(enemy_id))] = true

	for enemy_id: StringName in [
		&"mage_act1_sentry", &"mage_act2_mirage", &"mage_act3_warden",
		&"hunter_act1_fox", &"hunter_act2_vulture", &"hunter_act3_ghost",
	]:
		assert_true(wired.has(enemy_id), "新敌人 %s 没有被任何线路引用，等于没做" % enemy_id)


func test_new_enemies_respect_their_act_band() -> void:
	## 血量必须落在该幕的区间里，否则会出现"第一幕的怪比第二幕还硬"
	var bands: Dictionary = {1: [16, 32], 2: [24, 44], 3: [30, 50]}
	for enemy_id: StringName in [
		&"mage_act1_sentry", &"mage_act2_mirage", &"mage_act3_warden",
		&"hunter_act1_fox", &"hunter_act2_vulture", &"hunter_act3_ghost",
	]:
		var data: EnemyData = ContentRegistry.get_enemy(enemy_id)
		assert_not_null(data, "找不到新敌人 %s" % enemy_id)
		var band: Array = bands[data.act]
		assert_between(data.max_hp, band[0], band[1],
			"%s 的血量 %d 不在第 %d 幕区间 [%d, %d]" % [enemy_id, data.max_hp, data.act, band[0], band[1]])
