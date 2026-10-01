extends GutTest
## 特殊卡系统测试（阶段 5）：无色卡 / 诅咒卡 / 转职专属卡

func before_all() -> void:
	ContentRegistry.load_all()


func _make_creature(hp: int = 60) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


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


# ══ 无色卡 ══════════════════════════════════════════════════

func test_divine_cards_exist_for_each_deity() -> void:
	for deity: StringName in [&"war", &"hunt", &"arcane"]:
		assert_gt(ContentRegistry.divine_cards_for(deity).size(), 0,
			"神明「%s」没有任何无色卡" % deity)


func test_divine_cards_are_colorless_rarity() -> void:
	for card: CardData in ContentRegistry.divine_cards_for(&""):
		assert_eq(card.rarity, CardData.Rarity.COLORLESS, "%s 应是无色卡" % card.id)


func test_divine_cards_grant_divinity() -> void:
	## 神明的赠礼都有代价——获得无色卡必须涨神性
	for card: CardData in ContentRegistry.divine_cards_for(&""):
		assert_gt(card.divinity_gain, 0, "%s 没有配神性代价" % card.id)


func test_divine_cards_are_not_upgradable_or_removable() -> void:
	for card: CardData in ContentRegistry.divine_cards_for(&""):
		assert_false(card.can_upgrade(), "%s 不该可升级" % card.id)
		assert_false(card.can_remove(), "%s 不该可删除" % card.id)


func test_deathwish_costs_hp_and_grants_strength() -> void:
	## 用户举例的「死战」：失去 1 点生命，获得 2 点力量
	var loaded: Variant = ContentRegistry.get_card(&"divine_deathwish")
	assert_true(loaded is CardData)
	var card := loaded as CardData

	assert_eq(card.self_hp_loss, 1)
	assert_eq(int(card.apply_to_self.get("strength", 0)), 2)
	assert_eq(card.deity_id, &"war")


func test_divine_card_actually_applies_both_sides() -> void:
	var player := _make_player(60)
	var enemy := _make_creature(200)
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	var source: Variant = ContentRegistry.get_card(&"divine_deathwish")
	var card: CardData = (source as CardData).duplicate() as CardData
	bm.deck.hand.append(card)
	bm.play_card(card)

	assert_eq(player.hp, 59, "应失去 1 点生命")
	assert_eq(player.get_power_amount(&"strength"), 2, "应获得 2 点力量")


func test_run_state_refuses_to_remove_a_divine_card() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.add_card(&"divine_deathwish")

	assert_false(run.remove_card(&"divine_deathwish"), "无色卡删不掉")
	assert_true(run.deck_card_ids.has(&"divine_deathwish"), "牌还在")


# ══ 诅咒卡 ══════════════════════════════════════════════════

func test_curse_cards_exist() -> void:
	assert_gt(ContentRegistry.curse_cards().size(), 0)


func test_curse_cards_are_unplayable_and_not_upgradable() -> void:
	for card: CardData in ContentRegistry.curse_cards():
		assert_true(card.is_unplayable(), "%s 不该能打出" % card.id)
		assert_false(card.can_upgrade(), "%s 不该可升级" % card.id)


func test_curse_cards_have_purely_negative_effects() -> void:
	## 诅咒必须是**纯负面**：要么自伤，要么上减益。任何一项正面效果都是设计事故。
	for card: CardData in ContentRegistry.curse_cards():
		var negative: bool = card.self_hp_loss > 0 or not card.apply_to_self.is_empty()
		assert_true(negative, "%s 没有任何负面效果" % card.id)
		assert_eq(card.damage, 0, "%s 不该有伤害" % card.id)
		assert_eq(card.block, 0, "%s 不该有格挡" % card.id)


func test_pain_curse_applies_vulnerable_at_turn_end() -> void:
	## 用户举例的「痛苦」：回合结束后玩家获得 1 层易伤
	var loaded: Variant = ContentRegistry.get_card(&"curse_pain")
	assert_true(loaded is CardData)
	var card := loaded as CardData

	assert_true(card.triggers_on_turn_end)
	assert_eq(int(card.apply_to_self.get("vulnerable", 0)), 1)


func test_curse_triggers_at_player_turn_end() -> void:
	var player := _make_player(60)
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	var source: Variant = ContentRegistry.get_card(&"curse_pain")
	bm.deck.hand.append((source as CardData).duplicate() as CardData)

	bm.end_player_turn()

	assert_eq(player.get_power_amount(&"vulnerable"), 1,
		"手里的「痛苦」应在回合结束时给玩家 1 层易伤")


func test_curse_self_harm_triggers_at_turn_end() -> void:
	var player := _make_player(60)
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	var source: Variant = ContentRegistry.get_card(&"curse_decay")
	bm.deck.hand.append((source as CardData).duplicate() as CardData)

	bm.end_player_turn()

	assert_eq(player.hp, 58, "「衰朽」应在回合结束时扣 2 点生命")


func test_curse_does_nothing_when_not_in_hand() -> void:
	var player := _make_player(60)
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	bm.end_player_turn()

	assert_eq(player.hp, 60)
	assert_eq(player.get_power_amount(&"vulnerable"), 0)


func test_cannot_play_a_curse() -> void:
	var player := _make_player(60)
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	var source: Variant = ContentRegistry.get_card(&"curse_pain")
	var card: CardData = (source as CardData).duplicate() as CardData
	bm.deck.hand.append(card)

	assert_false(bm.play_card(card), "诅咒牌不该能打出")
	assert_true(bm.deck.hand.has(card), "打不出就应留在手里")


func test_curse_can_be_removed_by_shop() -> void:
	## 诅咒不可升级，但**可以**被商店删掉——玩家需要一条解药
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.add_card(&"curse_pain")

	assert_true(run.remove_card(&"curse_pain"))


# ══ 转职专属卡 ══════════════════════════════════════════════

func test_every_job_grants_two_signature_cards() -> void:
	for job: JobData in JobDatabase.all_jobs():
		assert_eq(job.signature_card_ids.size(), 2,
			"职业 %s 应有 2 张专属卡（用户要求每次转职给两张）" % job.id)


func test_signature_cards_exist_and_are_gold() -> void:
	for job: JobData in JobDatabase.all_jobs():
		for card_id: StringName in job.signature_card_ids:
			var loaded: Variant = ContentRegistry.get_card(card_id)
			assert_true(loaded is CardData, "职业 %s 的专属卡 %s 不存在" % [job.id, card_id])
			assert_eq((loaded as CardData).rarity, CardData.Rarity.GOLD,
				"%s 应该是金卡" % card_id)


func test_signature_cards_are_not_upgradable_or_removable() -> void:
	for job: JobData in JobDatabase.all_jobs():
		for card_id: StringName in job.signature_card_ids:
			var card: CardData = ContentRegistry.get_card(card_id)
			assert_false(card.can_upgrade(), "%s 不该可升级" % card_id)
			assert_false(card.can_remove(), "%s 不该可删除" % card_id)


func test_gold_cards_never_appear_in_rewards() -> void:
	for card: CardData in CardPool.new().reward_candidates():
		assert_ne(card.rarity, CardData.Rarity.GOLD, "%s 不该出现在奖励池" % card.id)


func test_run_state_refuses_to_remove_a_signature_card() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.add_card(&"gold_guard_bulwark")

	assert_false(run.remove_card(&"gold_guard_bulwark"))


# ══ 特殊事件 ════════════════════════════════════════════════

func test_god_offer_events_exist_for_each_deity() -> void:
	for event_id: StringName in [&"god_offer_war", &"god_offer_arcane", &"cursed_altar"]:
		var loaded: Variant = ContentRegistry.get_event(event_id)
		assert_true(loaded is EventData, "应注册事件 %s" % event_id)


func test_god_offer_event_declares_its_deity() -> void:
	var loaded: Variant = ContentRegistry.get_event(&"god_offer_war")
	var event := loaded as EventData

	assert_eq(event.deity_id, &"war")
	assert_eq(event.option_a_effect, EventData.Effect.ADD_DIVINE_CARD)


func test_cursed_altar_grants_a_curse() -> void:
	var loaded: Variant = ContentRegistry.get_event(&"cursed_altar")
	var event := loaded as EventData

	assert_eq(event.option_a_effect, EventData.Effect.ADD_CURSE_CARD)


func test_divine_event_offers_cards_that_exist() -> void:
	## 事件声明的神明必须真的有卡——否则玩家选了"接受"却什么也拿不到
	for event_id: StringName in [&"god_offer_war", &"god_offer_arcane"]:
		var event: EventData = ContentRegistry.get_event(event_id)
		assert_gt(ContentRegistry.divine_cards_for(event.deity_id).size(), 0,
			"事件 %s 声明的神明「%s」没有卡" % [event_id, event.deity_id])
