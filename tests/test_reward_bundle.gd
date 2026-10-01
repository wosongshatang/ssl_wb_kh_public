extends GutTest
## 战斗结算奖励包测试（阶段 5）
##
## 重点守两条：
##   1. **一次性提交**（D24）——没点「前进」之前不碰 RunState，避免半成品存档
##   2. **未领取就是放弃**——"我以为自动拿了"是最伤玩家信任的一类误会

func before_all() -> void:
	ContentRegistry.load_all()


func _new_run() -> RunState:
	var run := RunState.new()
	run.start_new_run(&"warrior", 12345)
	autofree(run)
	return run


func _bundle() -> RewardBundle:
	var bundle := RewardBundle.new()
	bundle.gold = 25
	bundle.potion_id = &"heal_potion"
	bundle.relic_id = &"vajra"
	bundle.card_offer_ids = [&"strike", &"defend", &"bash"]
	return bundle


# ══ 序列化（跨场景传递用）═══════════════════════════════════

func test_round_trip_preserves_everything() -> void:
	var original := _bundle()

	var restored := RewardBundle.from_dict(original.to_dict())

	assert_eq(restored.gold, 25)
	assert_eq(restored.potion_id, &"heal_potion")
	assert_eq(restored.relic_id, &"vajra")
	assert_eq(restored.card_offer_ids.size(), 3)


func test_from_empty_dict_is_safe() -> void:
	var bundle := RewardBundle.from_dict({})

	assert_eq(bundle.gold, 0)
	assert_eq(bundle.potion_id, &"")
	assert_eq(bundle.relic_id, &"")
	assert_eq(bundle.card_offer_ids.size(), 0)
	assert_false(bundle.has_anything())


func test_pending_reward_is_cleared_with_the_run() -> void:
	## 结束一局后残留的结算数据会让下一局莫名其妙"多拿一份奖励"。
	## 奖励存在 RunState 上（随存档持久化），所以 reset_run 会清掉它。
	var run := _new_run()
	run.pending_reward = {"gold": 99}

	GameState.reset_run()

	assert_eq(run.pending_reward.size(), 1, "reset_run 只清 GameState，不动已有的 RunState 对象")
	assert_eq(GameState.run, null)


func test_pending_reward_survives_save_round_trip() -> void:
	## 在结算界面退出游戏不该丢奖励
	var run := _new_run()
	run.pending_reward = {"gold": 33, "potion_id": "heal_potion"}

	var restored := RunState.new()
	restored.from_dict(run.to_dict())

	assert_eq(int(restored.pending_reward.get("gold", 0)), 33)
	assert_eq(str(restored.pending_reward.get("potion_id", "")), "heal_potion")


func test_in_battle_flag_survives_save_round_trip() -> void:
	## 「继续游戏」靠这个标记决定回到战斗还是地图——丢了就会跳过战斗
	var run := _new_run()
	run.in_battle = true

	var restored := RunState.new()
	restored.from_dict(run.to_dict())

	assert_true(restored.in_battle, "未完成战斗的标记必须能存进存档")


# ══ 一次性提交 ══════════════════════════════════════════════

func test_commit_does_nothing_before_player_takes_anything() -> void:
	## 这就是「一次性提交」的意义：玩家还没领取时 RunState 完全不动
	var run := _new_run()
	var gold_before: int = run.gold
	var deck_before: int = run.deck_card_ids.size()
	var bundle := _bundle()

	var summary := bundle.commit(run)

	assert_eq(run.gold, gold_before, "没点领取就不该加金币")
	assert_eq(run.deck_card_ids.size(), deck_before, "没选牌就不该进牌组")
	assert_eq(run.potions.size(), 0)
	assert_eq(run.relics.size(), 1, "只有初始遗物")
	assert_eq(summary, "什么也没拿")


func test_commit_applies_every_taken_reward() -> void:
	var run := _new_run()
	var gold_before: int = run.gold
	var deck_before: int = run.deck_card_ids.size()

	var bundle := _bundle()
	bundle.taken_gold = true
	bundle.taken_potion = true
	bundle.taken_relic = true
	bundle.chosen_card_id = &"bash"

	var summary := bundle.commit(run)

	assert_eq(run.gold, gold_before + 25)
	assert_eq(run.potions.size(), 1)
	assert_eq(run.potions[0], &"heal_potion")
	assert_true(run.relics.has(&"vajra"))
	assert_eq(run.deck_card_ids.size(), deck_before + 1)
	assert_eq(run.deck_card_ids[deck_before], &"bash")
	assert_true(summary.contains("金币"), "摘要应包含实际发生的事")


func test_commit_only_applies_what_was_taken() -> void:
	## 未领取 = 放弃。这条必须成立，否则玩家会以为"没点也会自动给"
	var run := _new_run()
	var bundle := _bundle()
	bundle.taken_gold = true  # 只拿了金币

	bundle.commit(run)

	assert_eq(run.potions.size(), 0, "没点药水就不该拿到")
	assert_false(run.relics.has(&"vajra"), "没点遗物就不该拿到")
	assert_eq(run.deck_card_ids.size(), 10, "没选牌就不该进牌组")


func test_full_potion_bar_discards_but_does_not_crash() -> void:
	var run := _new_run()
	run.add_potion(&"block_potion")
	run.add_potion(&"block_potion")
	run.add_potion(&"block_potion")

	var bundle := _bundle()
	bundle.taken_potion = true
	var summary := bundle.commit(run)

	assert_eq(run.potions.size(), RunState.MAX_POTIONS, "满栏时应丢弃而不是越界追加")
	assert_true(summary.contains("已满"), "丢弃必须写进摘要——静默丢弃会让玩家以为奖励没生效")


func test_duplicate_relic_is_not_added_twice() -> void:
	var run := _new_run()
	var bundle := _bundle()
	bundle.relic_id = &"burning_blood"  # 战士初始遗物
	bundle.taken_relic = true

	bundle.commit(run)

	var count: int = 0
	for relic_id: StringName in run.relics:
		if relic_id == &"burning_blood":
			count += 1
	assert_eq(count, 1, "已拥有的遗物不应重复加入")


# ══ all_taken ═══════════════════════════════════════════════

func test_all_taken_is_false_until_everything_is_claimed() -> void:
	var bundle := _bundle()

	assert_false(bundle.all_taken())

	bundle.taken_gold = true
	bundle.taken_potion = true
	bundle.taken_relic = true
	assert_false(bundle.all_taken(), "还差卡牌")

	bundle.chosen_card_id = &"strike"
	assert_true(bundle.all_taken())


func test_all_taken_ignores_absent_rewards() -> void:
	var bundle := RewardBundle.new()
	bundle.gold = 10
	bundle.taken_gold = true

	assert_true(bundle.all_taken(), "没有的奖励不应阻止 all_taken")


# ══ 名字查询 ════════════════════════════════════════════════

func test_name_lookup_falls_back_to_id() -> void:
	assert_eq(RewardBundle.card_name(&"strike"), "打击")
	assert_eq(RewardBundle.potion_name(&"heal_potion"), "回复药水")
	assert_eq(RewardBundle.relic_name(&"vajra"), "金刚杵")
	# 找不到时回退成 id，而不是显示空白
	assert_eq(RewardBundle.card_name(&"not_a_card"), "not_a_card")


# ══ 新遗物 ══════════════════════════════════════════════════

func test_all_relics_are_registered_and_creatable() -> void:
	for relic_id: StringName in [&"burning_blood", &"vajra", &"anchor_chain", &"blood_vial"]:
		assert_not_null(ContentRegistry.get_relic(relic_id), "应注册遗物 %s" % relic_id)
		assert_not_null(RelicFactory.create(relic_id), "应能创建遗物 %s" % relic_id)


func test_vajra_grants_strength_at_battle_start() -> void:
	var c := Creature.new()
	c.max_hp = 60
	c.reset_for_battle()
	autofree(c)

	c.add_relic(RelicFactory.create(&"vajra"))
	c.notify_battle_start()

	assert_eq(c.get_power_amount(&"strength"), 1)


func test_anchor_chain_grants_block_at_battle_start() -> void:
	var c := Creature.new()
	c.max_hp = 60
	c.reset_for_battle()
	autofree(c)

	c.add_relic(RelicFactory.create(&"anchor_chain"))
	c.notify_battle_start()

	assert_eq(c.block, 4)


func test_droppable_relics_exclude_owned_ones() -> void:
	var owned: Array[StringName] = [&"vajra"]
	var pool: Array[StringName] = RelicFactory.droppable_ids(owned)

	assert_false(pool.has(&"vajra"), "已拥有的不应再掉落")
	assert_true(pool.has(&"anchor_chain"))
	assert_true(pool.has(&"blood_vial"))


func test_droppable_relics_empty_when_all_owned() -> void:
	var owned: Array[StringName] = BasicRelics.ids()

	assert_eq(RelicFactory.droppable_ids(owned).size(), 0)
