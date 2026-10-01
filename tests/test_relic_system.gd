extends GutTest
## 遗物系统测试（阶段 5）：三层分类 / 触发钩子 / 获取途径

func before_all() -> void:
	ContentRegistry.load_all()


func _make_creature(hp: int = 60) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


## 战斗需要真正的 Player（`start_battle` 的形参是 Player，不是 Creature）
func _make_player(hp: int = 60) -> Player:
	var p := Player.new()
	p.display_name = "战士"
	p.max_hp = hp
	p.reset_for_battle()
	autofree(p)
	return p


func _seeded_rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _relic(relic_id: StringName) -> AbstractRelic:
	var relic := RelicFactory.create(relic_id)
	assert_not_null(relic, "应能创建遗物 %s" % relic_id)
	autofree(relic)
	return relic


# ══ 数据完整性 ══════════════════════════════════════════════

func test_every_relic_id_has_data_and_factory_entry() -> void:
	## 代码里实现了但 `.tres` 缺失（或反过来）都会让遗物**静默失效**
	for relic_id: StringName in RelicFactory.all_ids():
		assert_not_null(ContentRegistry.get_relic(relic_id),
			"遗物 %s 在代码里存在但没有 .tres" % relic_id)


func test_every_relic_tres_has_an_implementation() -> void:
	for relic_id: StringName in ContentRegistry.all_relic_ids():
		assert_true(RelicFactory.is_known(relic_id),
			"遗物 %s 有 .tres 但没有实现" % relic_id)


func test_every_relic_has_display_fields() -> void:
	for relic_id: StringName in RelicFactory.all_ids():
		var data: RelicData = ContentRegistry.get_relic(relic_id)
		assert_ne(data.display_name, "", "%s 缺少名称" % relic_id)
		assert_ne(data.description, "", "%s 缺少描述" % relic_id)
		assert_ne(data.trigger_text, "", "%s 缺少触发时机说明" % relic_id)


func test_all_three_categories_have_content() -> void:
	var counts: Dictionary = {}
	for relic_id: StringName in RelicFactory.all_ids():
		var data: RelicData = ContentRegistry.get_relic(relic_id)
		counts[data.category] = int(counts.get(data.category, 0)) + 1

	assert_gt(int(counts.get(RelicData.Category.COMMON, 0)), 0, "普通遗物不该为空")
	assert_gt(int(counts.get(RelicData.Category.DIVINE, 0)), 0, "神格遗物不该为空")
	assert_gt(int(counts.get(RelicData.Category.JOB, 0)), 0, "职业遗物不该为空")


func test_divine_relics_cost_divinity() -> void:
	## 神格遗物的代价必须是真的代价——否则"选不选"就不是选择
	for relic_id: StringName in DivineRelics.ids():
		var data: RelicData = ContentRegistry.get_relic(relic_id)
		assert_true(data.is_divine(), "%s 应标为神格" % relic_id)
		assert_gt(data.divinity_cost, 0, "%s 没有神性代价" % relic_id)


# ══ 获取途径的边界 ══════════════════════════════════════════

func test_droppable_pool_excludes_divine_and_job() -> void:
	var pool: Array[StringName] = RelicFactory.droppable_ids([])

	for relic_id: StringName in pool:
		var data: RelicData = ContentRegistry.get_relic(relic_id)
		assert_eq(data.category, RelicData.Category.COMMON,
			"%s 不该出现在普通掉落池里" % relic_id)


func test_droppable_pool_excludes_owned() -> void:
	var owned: Array[StringName] = [&"vajra"]
	var pool: Array[StringName] = RelicFactory.droppable_ids(owned)

	assert_false(pool.has(&"vajra"))
	assert_gt(pool.size(), 0)


func test_divine_pool_excludes_owned() -> void:
	var pool: Array[StringName] = RelicFactory.divine_ids([&"god_war_emblem"])

	assert_false(pool.has(&"god_war_emblem"))
	assert_gt(pool.size(), 0)


func test_divine_relics_are_not_in_shop_pool() -> void:
	for relic_id: StringName in RelicFactory.droppable_ids([]):
		assert_false(DivineRelics.ids().has(relic_id), "%s 不该能买到" % relic_id)


func test_price_increases_with_category() -> void:
	assert_gt(RelicFactory.price_of(&"god_war_emblem"), RelicFactory.price_of(&"vajra"))
	assert_gt(RelicFactory.price_of(&"job_bastion_keystone"), RelicFactory.price_of(&"vajra"))


# ══ 触发钩子 ════════════════════════════════════════════════

func test_vajra_grants_strength() -> void:
	var c := _make_creature()
	c.add_relic(_relic(&"vajra"))

	c.notify_battle_start()

	assert_eq(c.get_power_amount(&"strength"), 1)


func test_thorn_ring_grants_thorns() -> void:
	var c := _make_creature()
	c.add_relic(_relic(&"thorn_ring"))

	c.notify_battle_start()

	assert_eq(c.get_power_amount(&"thorns"), 3)


func test_smooth_stone_grants_dexterity() -> void:
	var c := _make_creature()
	c.add_relic(_relic(&"smooth_stone"))

	c.notify_battle_start()

	assert_eq(c.get_power_amount(&"dexterity"), 1)


func test_paper_frog_weakens_opponents() -> void:
	var player := _make_creature()
	var enemy := _make_creature()
	player.set_opponents([enemy])
	player.add_relic(_relic(&"paper_frog"))

	player.notify_battle_start()

	assert_eq(enemy.get_power_amount(&"weak"), 1, "纸蛙应给敌人虚弱")


func test_god_war_emblem_trades_hp_for_strength() -> void:
	## 神格遗物的"代价必须是真的代价"
	var c := _make_creature(60)
	c.add_relic(_relic(&"god_war_emblem"))

	c.on_turn_start()

	assert_eq(c.get_power_amount(&"strength"), 1, "应获得 1 点力量")
	assert_eq(c.hp, 59, "同时应失去 1 点生命")


func test_god_death_crown_heals_on_kill() -> void:
	var c := _make_creature(60)
	c.add_relic(_relic(&"god_death_crown"))
	c.take_damage(20, null, DamageType.HP_LOSS)

	c.notify_kill(_make_creature())

	assert_eq(c.hp, 48, "击杀应回复 8 点生命（40 + 8）")


func test_bastion_keystone_keeps_extra_block() -> void:
	## 与壁垒身份能力用同一个钩子 → 乘法叠加
	var c := _make_creature()
	c.add_relic(_relic(&"job_bastion_keystone"))
	c.gain_block(20)

	c.on_turn_start()

	# 20 点本该全清，额外保留 25% = 5 → 清 15，留 5
	assert_eq(c.block, 5)


func test_bastion_keystone_stacks_with_bastion_power() -> void:
	var c := _make_creature()
	c.apply_identity_power(IdentityPowers.create(&"bastion_wall"))
	c.add_relic(_relic(&"job_bastion_keystone"))
	c.gain_block(20)

	c.on_turn_start()

	# 壁垒先介入：20 点本该全清，保留 50% → 清 10
	# 基石再介入：10 点本该全清，额外保留 25%（floor(10×0.25)=2）→ 清 8
	# 最终保留 20 - 8 = 12
	assert_eq(c.block, 12, "两个钩子应依次叠加（不是各自独立计算）")


func test_shield_guard_bracer_boosts_first_block_only() -> void:
	var c := _make_creature()
	c.add_relic(_relic(&"job_shield_guard_bracer"))

	var first: int = c.gain_block(5)
	var second: int = c.gain_block(5)

	assert_eq(first, 7, "第一张格挡 +2")
	assert_eq(second, 5, "第二张不再加成")


func test_bracer_preview_does_not_consume_bonus() -> void:
	var c := _make_creature()
	c.add_relic(_relic(&"job_shield_guard_bracer"))

	assert_eq(c.preview_block(5), 7)
	assert_eq(c.preview_block(5), 7, "预览不能被消耗")
	assert_eq(c.gain_block(5), 7, "真正获得时才消耗")


func test_berserker_chain_accumulates_strength() -> void:
	var c := _make_creature(60)
	c.add_relic(_relic(&"job_berserker_chain"))

	c.take_damage(6, null, DamageType.HP_LOSS)

	assert_eq(c.get_power_amount(&"strength"), 2, "失去 6 点生命应得 2 点力量")


func test_momentum_banner_grants_block_each_turn() -> void:
	var c := _make_creature()
	c.add_relic(_relic(&"job_momentum_banner"))

	c.on_turn_start()

	assert_eq(c.block, 2)


func test_lantern_draws_once_per_battle() -> void:
	var player := _make_player()
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	var relic := _relic(&"lantern")
	player.add_relic(relic)
	player.bind_relics_to_battle(bm)
	relic.at_battle_start(player)

	# 往抽牌堆塞牌，验证"额外抽 1 张"
	for _i: int in 3:
		bm.deck.draw_pile.append(CardData.make_skill(&"d", "防御", 1, 5))
	var before: int = bm.deck.hand.size()

	player.on_turn_start()
	assert_eq(bm.deck.hand.size(), before + 1, "第一回合应额外抽 1 张")

	# 第二次触发不该再抽（每场战斗只生效一次）
	var after_first: int = bm.deck.hand.size()
	player.on_turn_start()
	assert_eq(bm.deck.hand.size(), after_first, "同一场战斗只该触发一次")


func test_lucky_coin_accumulates_bonus_gold() -> void:
	var player := _make_player()
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	var relic := _relic(&"lucky_coin")
	player.add_relic(relic)
	player.bind_relics_to_battle(bm)

	player.notify_battle_end(true)

	assert_eq(bm.bonus_gold, 8, "胜利后应累加 8 金币")


func test_lucky_coin_gives_nothing_on_defeat() -> void:
	var player := _make_player()
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	var relic := _relic(&"lucky_coin")
	player.add_relic(relic)
	player.bind_relics_to_battle(bm)

	player.notify_battle_end(false)

	assert_eq(bm.bonus_gold, 0)


# ══ 触发反馈 ════════════════════════════════════════════════

func test_relic_announces_its_trigger() -> void:
	## 遗物必须**看得见**——静默生效等于不存在
	var c := _make_creature()
	watch_signals(c)
	c.add_relic(_relic(&"vajra"))

	c.notify_battle_start()

	assert_signal_emitted(c, "relic_triggered", "遗物触发应发出信号供 UI 显示")


func test_relics_survive_battle_reset() -> void:
	var c := _make_creature()
	c.add_relic(_relic(&"vajra"))

	c.reset_for_battle()

	assert_true(c.has_relic(&"vajra"), "遗物是整局持续，不该被战斗重置清掉")


# ══ 职业遗物与职业的绑定 ════════════════════════════════════

func test_every_job_maps_to_a_job_relic() -> void:
	for job: JobData in JobDatabase.all_jobs():
		var relic_id: StringName = JobRelics.for_job(job.id)
		assert_ne(relic_id, &"", "职业 %s 没有对应遗物" % job.id)
		assert_true(JobRelics.ids().has(relic_id), "%s 不是职业遗物" % relic_id)


func test_job_relics_are_marked_job_category() -> void:
	for relic_id: StringName in JobRelics.ids():
		var data: RelicData = ContentRegistry.get_relic(relic_id)
		assert_true(data.is_job_specific(), "%s 应标为职业专属" % relic_id)


# ══ 窃权事件 ════════════════════════════════════════════════

func test_usurp_event_grants_a_divine_relic() -> void:
	var loaded: Variant = ContentRegistry.get_event(&"usurp_power")
	assert_true(loaded is EventData)
	assert_eq((loaded as EventData).option_a_effect, EventData.Effect.ADD_DIVINE_RELIC)


func test_divine_relic_event_has_a_non_empty_pool() -> void:
	assert_gt(RelicFactory.divine_ids([]).size(), 0,
		"窃权事件必须真的有东西可窃")
