extends GutTest
## 药水系统测试（阶段 5）
##
## 重点守三条：
##   1. **默认战斗式**——新增药水时不写 targeting 就该是对敌人的
##   2. **can_use 与 apply 一致**——UI 说能用就必须真能用，反之亦然
##   3. **失败不消耗**——"用了没效果还把药水吃掉"是最不能忍的一类 bug

func before_all() -> void:
	ContentRegistry.load_all()


const ALL_POTION_IDS: Array[StringName] = [
	&"explosive_potion", &"draw_potion", &"card_potion",
	&"strength_potion", &"heal_potion", &"block_potion",
]


func _seeded_rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _make_creature(hp: int = 100) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


func _make_player(hp: int = 100) -> Player:
	var p := Player.new()
	p.display_name = "战士"
	p.max_hp = hp
	p.reset_for_battle()
	autofree(p)
	return p


func _make_deck(count: int = 5) -> DeckManager:
	var deck := DeckManager.new(_seeded_rng())
	var cards: Array[CardData] = []
	for i: int in count:
		cards.append(CardData.make_skill(&"defend_%d" % i, "防御%d" % i, 1, 5))
	deck.setup(cards)
	return deck


func _potion(potion_id: StringName) -> PotionData:
	var loaded: Variant = ContentRegistry.get_potion(potion_id)
	assert_true(loaded is PotionData, "找不到药水 %s" % potion_id)
	return loaded as PotionData


# ══ 数据 ════════════════════════════════════════════════════

func test_every_potion_is_registered() -> void:
	for potion_id: StringName in ALL_POTION_IDS:
		assert_not_null(ContentRegistry.get_potion(potion_id), "应注册药水 %s" % potion_id)


func test_every_potion_has_display_fields_and_value() -> void:
	for potion_id: StringName in ALL_POTION_IDS:
		var potion: PotionData = _potion(potion_id)
		assert_ne(potion.display_name, "", "%s 缺少显示名" % potion_id)
		assert_ne(potion.description, "", "%s 缺少描述" % potion_id)
		assert_gt(potion.value, 0, "%s 的数值应大于 0" % potion_id)


func test_potion_defaults_to_enemy_targeting() -> void:
	## 用户要求：「默认战斗式，除非特别说明」
	var fresh := PotionData.new()
	assert_true(fresh.needs_enemy_target(), "药水默认应是战斗式（对敌人）")
	assert_true(fresh.battle_only, "药水默认应只能战斗中使用")


func test_explosive_potion_is_the_only_enemy_targeted_one() -> void:
	var enemy_targeted: int = 0
	for potion_id: StringName in ALL_POTION_IDS:
		if _potion(potion_id).needs_enemy_target():
			enemy_targeted += 1
			assert_eq(potion_id, &"explosive_potion", "目前只有爆炸药水是战斗式")
	assert_eq(enemy_targeted, 1)


func test_categories_are_reported() -> void:
	assert_eq(_potion(&"explosive_potion").category_text(), "直伤")
	assert_eq(_potion(&"draw_potion").category_text(), "得牌")
	assert_eq(_potion(&"card_potion").category_text(), "得牌")
	assert_eq(_potion(&"strength_potion").category_text(), "增益")


# ══ can_use 规则 ════════════════════════════════════════════

func test_battle_only_potion_is_blocked_on_map() -> void:
	assert_ne(PotionResolver.can_use(_potion(&"strength_potion"), false, false), "",
		"地图上不应能用力量药水")


func test_general_potion_is_usable_on_map() -> void:
	assert_eq(PotionResolver.can_use(_potion(&"heal_potion"), false, false), "",
		"回复药水应能在地图上用")


func test_enemy_targeting_requires_a_living_enemy() -> void:
	var potion: PotionData = _potion(&"explosive_potion")
	assert_ne(PotionResolver.can_use(potion, true, false), "", "没有敌人时不应能用爆炸药水")
	assert_eq(PotionResolver.can_use(potion, true, true), "", "有敌人时应能用")


func test_draw_potion_is_self_targeted_but_battle_only() -> void:
	## 这条守着「battle_only 必须独立于 targeting」的设计（见 PotionData 类文档）
	var potion: PotionData = _potion(&"draw_potion")
	assert_false(potion.needs_enemy_target(), "抽牌药水是自目标")
	assert_true(potion.battle_only, "但只能战斗中——地图上抽牌没有意义")
	assert_ne(PotionResolver.can_use(potion, false, false), "")


# ══ 效果结算 ════════════════════════════════════════════════

func test_damage_potion_hurts_the_target() -> void:
	var user := _make_player()
	var target := _make_creature(50)

	var result := PotionResolver.apply(_potion(&"explosive_potion"), user, target, null, _seeded_rng())

	assert_true(result.success)
	assert_eq(target.hp, 40, "爆炸药水应造成 10 点伤害")


func test_damage_potion_without_target_fails_cleanly() -> void:
	var user := _make_player()

	var result := PotionResolver.apply(_potion(&"explosive_potion"), user, null, null, _seeded_rng())

	assert_false(result.success, "没有目标时必须失败而不是崩溃")
	assert_ne(result.message, "", "失败要给得出原因")


func test_heal_potion_restores_ten_percent_of_max_hp() -> void:
	var user := _make_creature(100)
	user.set_hp(50)

	var result := PotionResolver.apply(_potion(&"heal_potion"), user, null, null, _seeded_rng())

	assert_true(result.success)
	assert_eq(user.hp, 60, "应回复最大生命 10% = 10 点")


func test_heal_potion_does_not_exceed_max_hp() -> void:
	var user := _make_creature(100)
	user.set_hp(96)

	PotionResolver.apply(_potion(&"heal_potion"), user, null, null, _seeded_rng())

	assert_eq(user.hp, 100, "回血不应超过上限")


func test_strength_potion_grants_strength() -> void:
	var user := _make_player()

	var result := PotionResolver.apply(_potion(&"strength_potion"), user, null, null, _seeded_rng())

	assert_true(result.success)
	assert_eq(user.get_power_amount(&"strength"), 3)


func test_block_potion_grants_block() -> void:
	var user := _make_player()

	var result := PotionResolver.apply(_potion(&"block_potion"), user, null, null, _seeded_rng())

	assert_true(result.success)
	assert_eq(user.block, 12)


func test_draw_potion_draws_cards() -> void:
	var user := _make_player()
	var deck := _make_deck(5)
	deck.draw(5)

	var result := PotionResolver.apply(_potion(&"draw_potion"), user, null, deck, _seeded_rng())

	assert_true(result.success)
	assert_eq(deck.hand.size(), 5, "抽牌堆已空、弃牌堆也空时抽不到牌，但不该报错")


func test_draw_potion_requires_a_deck() -> void:
	var user := _make_player()

	var result := PotionResolver.apply(_potion(&"draw_potion"), user, null, null, _seeded_rng())

	assert_false(result.success, "没有牌堆时抽牌药水必须失败而不是崩溃")


# ══ 得牌类：从牌库三选一 ════════════════════════════════════

func test_card_potion_offers_cards_and_requests_a_choice() -> void:
	var user := _make_player()
	var deck := _make_deck(3)

	var result := PotionResolver.apply(_potion(&"card_potion"), user, null, deck, _seeded_rng())

	assert_true(result.success)
	assert_true(result.needs_card_choice, "得牌类药水必须要求玩家选牌")
	assert_eq(result.offered_card_ids.size(), 3, "应展示 3 张")


func test_granting_offered_card_adds_it_to_hand() -> void:
	var deck := _make_deck(3)
	var hand_before: int = deck.hand.size()

	var granted: bool = PotionResolver.grant_card_to_hand(&"strike", deck)

	assert_true(granted)
	assert_eq(deck.hand.size(), hand_before + 1)


func test_granted_card_is_a_copy_not_the_registry_instance() -> void:
	## 临时牌必须是副本：注册表里的卡是全局共享实例，
	## 直接塞进去会让"这张牌被升级/消耗"影响到其它牌乃至跨局。
	var deck := _make_deck(0)

	PotionResolver.grant_card_to_hand(&"strike", deck)

	var registry_strike: Variant = ContentRegistry.get_card(&"strike")
	assert_ne(deck.hand[0], registry_strike as CardData, "加入手牌的必须是副本")


func test_granting_unknown_card_fails_cleanly() -> void:
	var deck := _make_deck(0)

	assert_false(PotionResolver.grant_card_to_hand(&"not_a_real_card", deck))
	assert_eq(deck.hand.size(), 0)


func test_granted_card_disappears_next_battle() -> void:
	## 「战斗结束后移除」**不需要任何清理代码**：
	## 临时牌从未进过 RunState.deck_card_ids，而每场战斗的牌组都由
	## build_deck() 重建——这条测试就是把这个不变量钉住。
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	var permanent_count: int = run.deck_card_ids.size()

	var deck := _make_deck(0)
	PotionResolver.grant_card_to_hand(&"impervious", deck)
	assert_eq(deck.hand.size(), 1, "临时牌已进手牌")

	var rebuilt: Array[CardData] = run.build_deck()
	assert_eq(rebuilt.size(), permanent_count,
		"重建的牌组只包含 deck_card_ids 里的牌，临时牌自然消失")
	for card: CardData in rebuilt:
		assert_ne(card.id, &"impervious", "临时牌不应出现在重建的牌组里")


# ══ RunState 药水栏 ═════════════════════════════════════════

func test_potion_bar_has_a_capacity_limit() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	for _i: int in RunState.MAX_POTIONS:
		assert_true(run.add_potion(&"heal_potion"), "未满时应能加入")

	assert_false(run.add_potion(&"heal_potion"), "满了之后必须拒绝")
	assert_eq(run.potions.size(), RunState.MAX_POTIONS)
	assert_true(run.is_potion_bar_full())


func test_consuming_a_potion_removes_it() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.add_potion(&"strength_potion")
	run.add_potion(&"heal_potion")

	assert_eq(run.consume_potion(0), &"strength_potion")
	run.remove_potion_at(0)

	assert_eq(run.potions.size(), 1)
	assert_eq(run.potions[0], &"heal_potion", "移除后剩下的应是原本的第二瓶")


func test_remove_potion_out_of_range_is_safe() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	run.remove_potion_at(99)
	run.remove_potion_at(-1)

	assert_eq(run.potions.size(), 0, "越界移除不应崩溃")


func test_potions_survive_save_round_trip() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.add_potion(&"explosive_potion")

	var restored := RunState.new()
	restored.from_dict(run.to_dict())

	assert_eq(restored.potions.size(), 1)
	assert_eq(restored.potions[0], &"explosive_potion")


# ══ 卡牌给药水 ══════════════════════════════════════════════

func test_elixir_card_is_registered_and_grants_a_potion() -> void:
	var loaded: Variant = ContentRegistry.get_card(&"elixir_of_might")
	assert_true(loaded is CardData)
	var card := loaded as CardData
	assert_eq(card.grant_potion_id, &"strength_potion")
	assert_not_null(ContentRegistry.get_potion(card.grant_potion_id),
		"卡牌给的药水必须真的存在，否则打出后静默失效")


func test_every_card_granted_potion_exists() -> void:
	## 守住"数据里写的 id 必须能解析"——否则玩家打出卡牌后什么都没发生
	for card: CardData in ContentRegistry.all_cards():
		if card.grant_potion_id == &"":
			continue
		assert_not_null(ContentRegistry.get_potion(card.grant_potion_id),
			"卡牌 %s 给的药水「%s」不存在" % [card.id, card.grant_potion_id])


func test_playing_elixir_emits_potion_granted() -> void:
	var player := _make_player(60)
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	var empty_deck: Array[CardData] = []
	bm.start_battle(player, enemies, empty_deck, _seeded_rng())
	watch_signals(bm)

	var source: Variant = ContentRegistry.get_card(&"elixir_of_might")
	var card: CardData = (source as CardData).duplicate() as CardData
	bm.deck.hand.append(card)
	bm.play_card(card)

	assert_signal_emitted_with_parameters(bm, "potion_granted", [&"strength_potion"])
