extends GutTest
## 单局状态测试（阶段 3）

func before_all() -> void:
	ContentRegistry.load_all()


func _new_run() -> RunState:
	var run := RunState.new()
	run.start_new_run(&"warrior", 12345)
	return run


func test_start_new_run_initializes_every_field() -> void:
	var run := _new_run()

	assert_eq(run.character_class, &"warrior")
	assert_eq(run.current_act, 1)
	assert_eq(run.current_node_id, -1)
	assert_eq(run.max_hp, RunState.DEFAULT_MAX_HP)
	assert_eq(run.hp, RunState.DEFAULT_MAX_HP)
	assert_eq(run.gold, RunState.STARTING_GOLD)
	assert_eq(run.rng_seed, 12345)
	assert_false(run.is_over)
	assert_false(run.victory)
	assert_true(run.is_alive())


func test_starting_deck_is_five_strikes_and_five_defends() -> void:
	var run := _new_run()

	assert_eq(run.deck_card_ids.size(), 10, "战士初始牌组应为 10 张")

	var strikes: int = 0
	var defends: int = 0
	for id: StringName in run.deck_card_ids:
		if id == &"strike":
			strikes += 1
		elif id == &"defend":
			defends += 1

	assert_eq(strikes, 5)
	assert_eq(defends, 5)


func test_build_deck_resolves_card_data_from_registry() -> void:
	var run := _new_run()

	var deck: Array[CardData] = run.build_deck()

	assert_eq(deck.size(), 10)
	assert_eq(deck[0].id, &"strike", "应解析出真实 CardData 而非空对象")


func test_build_deck_skips_unknown_ids() -> void:
	var run := _new_run()
	run.add_card(&"definitely_not_a_card")

	var deck: Array[CardData] = run.build_deck()

	assert_eq(deck.size(), 10, "查不到的 id 应被跳过而不是变成空牌")


func test_add_and_remove_card() -> void:
	var run := _new_run()

	run.add_card(&"bash")
	assert_eq(run.deck_card_ids.size(), 11)

	assert_true(run.remove_card(&"bash"), "应能移除存在的牌")
	assert_eq(run.deck_card_ids.size(), 10)

	assert_false(run.remove_card(&"bash"), "移除不存在的牌应返回 false")


# ══ 资源 ════════════════════════════════════════════════════

func test_gold_can_be_added_and_spent() -> void:
	var run := _new_run()

	run.add_gold(50)
	assert_eq(run.gold, RunState.STARTING_GOLD + 50)

	assert_true(run.spend_gold(100), "钱够时应能消费")
	assert_eq(run.gold, RunState.STARTING_GOLD - 50)

	assert_false(run.spend_gold(99999), "钱不够时应拒绝")
	assert_eq(run.gold, RunState.STARTING_GOLD - 50, "被拒绝时不应扣钱")


func test_gold_never_goes_negative() -> void:
	var run := _new_run()
	run.add_gold(-99999)

	assert_eq(run.gold, 0, "金币不应为负")


func test_heal_cannot_exceed_max_hp() -> void:
	var run := _new_run()
	run.take_damage(10)
	assert_eq(run.hp, 20)

	run.heal(999)
	assert_eq(run.hp, run.max_hp)


func test_take_damage_to_zero_marks_run_over() -> void:
	var run := _new_run()

	run.take_damage(999)

	assert_eq(run.hp, 0)
	assert_true(run.is_over)
	assert_false(run.victory)
	assert_false(run.is_alive())


func test_finish_marks_victory() -> void:
	var run := _new_run()

	run.finish(true)

	assert_true(run.is_over)
	assert_true(run.victory)


# ══ 与战斗的同步 ════════════════════════════════════════════

func test_sync_from_creature_copies_hp_back() -> void:
	## 战斗里用的是临时 Player，打完必须把血量同步回来——
	## 否则会出现「战斗中掉了血、地图上还是满血」这类经典撕裂
	var run := _new_run()

	var player := Player.new()
	player.max_hp = run.max_hp
	player.reset_for_battle()
	autofree(player)
	player.take_damage(9)

	run.sync_from_creature(player)

	assert_eq(run.hp, RunState.DEFAULT_MAX_HP - 9)


func test_sync_from_dead_creature_marks_run_over() -> void:
	var run := _new_run()

	var player := Player.new()
	player.max_hp = run.max_hp
	player.reset_for_battle()
	autofree(player)
	player.take_damage(9999)

	run.sync_from_creature(player)

	assert_eq(run.hp, 0)
	assert_true(run.is_over)


# ══ 序列化 ══════════════════════════════════════════════════

func test_to_dict_from_dict_round_trip() -> void:
	var run := _new_run()
	run.hp = 17
	run.gold = 42
	run.current_act = 2
	run.current_node_id = 7
	run.add_card(&"bash")
	run.relics.append(&"burning_blood")

	var restored := RunState.new()
	restored.from_dict(run.to_dict())

	assert_eq(restored.character_class, &"warrior")
	assert_eq(restored.hp, 17)
	assert_eq(restored.gold, 42)
	assert_eq(restored.current_act, 2)
	assert_eq(restored.current_node_id, 7)
	assert_eq(restored.rng_seed, 12345)
	assert_eq(restored.deck_card_ids.size(), 11)
	assert_eq(restored.relics.size(), 1)
	assert_eq(restored.relics[0], &"burning_blood")


func test_from_dict_tolerates_missing_keys() -> void:
	## 存档是跨版本读的，缺字段时必须给默认值而不是崩溃
	var restored := RunState.new()
	restored.from_dict({})

	assert_eq(restored.character_class, &"")
	assert_eq(restored.hp, RunState.DEFAULT_MAX_HP)
	assert_eq(restored.deck_card_ids.size(), 0)
	assert_false(restored.is_over)
