extends GutTest
## 阶段 6 · 特殊牌测试（P6-12：神化 / 契约 / 神谕 / 考题）

func before_all() -> void:
	ContentRegistry.load_all()


func _make_player(hp: int = 60) -> Player:
	var p := Player.new()
	p.display_name = "战士"
	p.max_hp = hp
	p.reset_for_battle()
	autofree(p)
	return p


func _make_creature(hp: int = 60) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


func _seeded_rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _make_battle(player: Player, deck: Array[CardData] = []) -> BattleManager:
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())
	return bm


func _put_in_hand(bm: BattleManager, card_id: StringName) -> CardData:
	var source: Variant = ContentRegistry.get_card(card_id)
	assert_true(source is CardData, "找不到卡牌 %s" % card_id)
	var card: CardData = (source as CardData).duplicate() as CardData
	bm.deck.hand.append(card)
	return card


# ══ 数据完整性 ══════════════════════════════════════════════

func test_every_special_kind_has_at_least_one_card() -> void:
	## 定义了类别却没有卡 = 玩家永远见不到这一类
	var present: Dictionary = {}
	for card: CardData in ContentRegistry.special_cards():
		present[card.special_kind] = true

	for kind: int in [
		CardData.SpecialKind.APOTHEOSIS,
		CardData.SpecialKind.PACT,
		CardData.SpecialKind.ORACLE,
		CardData.SpecialKind.TRIAL,
	]:
		assert_true(present.has(kind), "特殊类别 %d 没有任何卡牌" % kind)


func test_special_cards_have_meaningful_values() -> void:
	## 各类别用**各自有意义**的那个字段：
	## 契约的代价是神性（与无色卡同一个概念、同一个字段），其余用 special_value。
	##
	## ⚠️ 两个例外**本来就没有数值**，它们的"意义"在 `special_kind` 本身：
	##   · PACT —— 代价写在 divinity_gain
	##   · FORM_SHIFT —— 就是一个开关，没有量
	## 硬要求它们有 special_value 只会逼出"为了过测试而填个 1"的假数据。
	for card: CardData in ContentRegistry.special_cards():
		if card.special_kind == CardData.SpecialKind.PACT:
			assert_gt(card.divinity_gain, 0, "%s 是契约但没有神性代价" % card.id)
		elif card.special_kind == CardData.SpecialKind.FORM_SHIFT:
			continue
		else:
			assert_gt(card.special_value, 0, "%s 的 special_value 没有意义" % card.id)


func test_trial_cards_have_a_bonus() -> void:
	for card: CardData in ContentRegistry.special_cards():
		if card.special_kind == CardData.SpecialKind.TRIAL:
			assert_gt(card.trial_block_bonus, 0, "%s 是考题但没有额外格挡" % card.id)


func test_special_cards_never_appear_in_rewards() -> void:
	## 混进常规三选一，会让"特殊"两个字失去意义
	for card: CardData in CardPool.new().reward_candidates():
		assert_false(card.is_special(), "%s 是特殊牌，不该出现在奖励池" % card.id)


func test_special_cards_have_no_leftover_placeholders() -> void:
	for card: CardData in ContentRegistry.special_cards():
		var text := card.format_description()
		assert_false(text.contains("{"),
			"%s 的描述有未替换的占位符：%s" % [card.id, text])


# ══ 神化：永久升级牌组 ══════════════════════════════════════

func test_upgrade_random_cards_upgrades_exactly_count() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	var upgraded: Array[StringName] = run.upgrade_random_cards(2, _seeded_rng())

	assert_eq(upgraded.size(), 2)
	var marked: int = 0
	for entry: StringName in run.deck_card_ids:
		if RunState.is_upgraded_entry(entry):
			marked += 1
	assert_eq(marked, 2)


func test_upgrade_random_cards_stops_when_nothing_left() -> void:
	## 牌组全升级完之后不该死循环，也不该报错
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	var upgraded: Array[StringName] = run.upgrade_random_cards(999, _seeded_rng())

	assert_eq(upgraded.size(), 10, "初始牌组 10 张，全升完就停")
	assert_eq(run.upgradable_card_ids().size(), 0)


func test_apotheosis_card_requests_an_upgrade() -> void:
	var player := _make_player()
	var bm := _make_battle(player)
	var card := _put_in_hand(bm, &"apotheosis_minor")
	watch_signals(bm)

	bm.play_card(card)

	assert_signal_emitted(bm, "card_upgrade_requested",
		"神化牌应请求升级（BattleManager 够不着 RunState，必须走信号）")


# ══ 契约：永久神性 ══════════════════════════════════════════

func test_pact_card_requests_divinity() -> void:
	var player := _make_player()
	var bm := _make_battle(player)
	var card := _put_in_hand(bm, &"pact_blood")
	watch_signals(bm)

	bm.play_card(card)

	assert_signal_emitted(bm, "divinity_requested", "契约牌应请求永久神性")


func test_pact_card_still_applies_its_normal_effect() -> void:
	## 契约牌的"好处"不能因为走了信号就丢了
	var player := _make_player()
	var bm := _make_battle(player)
	var card := _put_in_hand(bm, &"pact_war")

	bm.play_card(card)

	assert_eq(player.get_power_amount(&"strength"), 4, "契约牌的力量效果应照常生效")


# ══ 神谕：抽牌 + 看穿牌堆 ════════════════════════════════════

func test_oracle_card_draws_and_reveals() -> void:
	var player := _make_player()
	var bm := _make_battle(player)
	# 往抽牌堆塞牌，验证真的抽到了
	for _i: int in 4:
		bm.deck.draw_pile.append(CardData.make_skill(&"d", "防御", 1, 5))
	var card := _put_in_hand(bm, &"oracle_whisper")
	var hand_before: int = bm.deck.hand.size()
	watch_signals(bm)

	bm.play_card(card)

	assert_eq(bm.deck.hand.size(), hand_before - 1 + 3, "神谕应抽 3 张")
	assert_signal_emitted(bm, "oracle_revealed", "神谕应把牌堆展示出来")


func test_oracle_on_empty_pile_does_not_crash() -> void:
	var player := _make_player()
	var bm := _make_battle(player)
	var card := _put_in_hand(bm, &"oracle_eye")

	bm.play_card(card)

	assert_true(true, "空牌堆时不该崩")


# ══ 考题：条件达成才给额外格挡 ══════════════════════════════

func test_trial_grants_bonus_when_hand_is_large_enough() -> void:
	var player := _make_player()
	var bm := _make_battle(player)
	# 先塞够手牌（考题要求"打出后手牌不少于 N 张"）
	for _i: int in 6:
		bm.deck.hand.append(CardData.make_skill(&"f", "防御", 1, 5))
	var card := _put_in_hand(bm, &"trial_frugal")

	bm.play_card(card)

	# 8 点基础格挡 + 8 点额外（手牌 6 张 ≥ 门槛 4）
	assert_eq(player.block, 16, "达标时应给基础格挡 + 额外格挡")


func test_trial_grants_nothing_extra_below_threshold() -> void:
	var player := _make_player()
	var bm := _make_battle(player)
	var card := _put_in_hand(bm, &"trial_patience")  # 门槛 5 张

	bm.play_card(card)

	# 打出后手牌 0 张 < 5，只有基础 5 点格挡
	assert_eq(player.block, 5, "未达门槛时不该给额外格挡")


# ══ 获取途径 ════════════════════════════════════════════════

func test_special_gift_event_exists() -> void:
	var loaded: Variant = ContentRegistry.get_event(&"god_gift_special")
	assert_true(loaded is EventData, "应有神赐之牌事件")
	assert_eq((loaded as EventData).option_a_effect, EventData.Effect.ADD_SPECIAL_CARD)


func test_special_cards_are_all_non_empty() -> void:
	assert_gt(ContentRegistry.special_cards().size(), 0)
