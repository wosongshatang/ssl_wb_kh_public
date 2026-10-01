extends GutTest
## 卡牌稀有度与升级测试（阶段 5）
##
## 重点守三条：
##   1. **升级不污染模板**——预览升级不能改到注册表里的原牌
##   2. **描述与效果一致**——卡面写的数字必须就是实际会生效的数字
##   3. **预览无副作用**——UI 刷新一次不该把盾卫的加成吃掉

func before_all() -> void:
	ContentRegistry.load_all()


func _make_creature(hp: int = 60) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


# ══ 稀有度 ══════════════════════════════════════════════════

func test_rarity_enum_matches_design() -> void:
	## 灰 — 白 — 绿 — 蓝 — 紫 — 金 / 无色 / 黑
	assert_eq(CardData.Rarity.STARTER, 0)
	assert_eq(CardData.Rarity.COMMON, 1)
	assert_eq(CardData.Rarity.UNCOMMON, 2)
	assert_eq(CardData.Rarity.RARE, 3)
	assert_eq(CardData.Rarity.EPIC, 4)
	assert_eq(CardData.Rarity.GOLD, 5)
	assert_eq(CardData.Rarity.COLORLESS, 6)
	assert_eq(CardData.Rarity.CURSE, 7)


func test_every_rarity_has_a_color() -> void:
	for rarity: int in range(0, 8):
		assert_true(UiPalette.color_for_rarity(rarity).a > 0.0,
			"稀有度 %d 没有配色" % rarity)


func test_premium_rarities_are_flagged() -> void:
	assert_true(UiPalette.rarity_is_premium(CardData.Rarity.GOLD))
	assert_true(UiPalette.rarity_is_premium(CardData.Rarity.COLORLESS))
	assert_false(UiPalette.rarity_is_premium(CardData.Rarity.COMMON))


func test_starting_deck_is_all_starter_rarity() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	for entry: StringName in run.deck_card_ids:
		var loaded: Variant = ContentRegistry.get_card(RunState.decode_card_id(entry))
		assert_true(loaded is CardData)
		assert_eq((loaded as CardData).rarity, CardData.Rarity.STARTER,
			"初始牌组的 %s 应该是灰卡" % entry)


# ══ 升级：默认规则（用户指定）═══════════════════════════════

func test_attack_upgrade_delta_follows_rarity() -> void:
	var expected := {
		CardData.Rarity.STARTER: 3,
		CardData.Rarity.COMMON: 3,
		CardData.Rarity.UNCOMMON: 4,
		CardData.Rarity.RARE: 5,
		CardData.Rarity.EPIC: 6,
	}
	for rarity: int in expected:
		var card := CardData.make_attack(&"t", "测试", 1, 10)
		card.rarity = rarity
		assert_eq(card.create_upgraded().damage, 10 + int(expected[rarity]),
			"稀有度 %d 的攻击牌升级增量不对" % rarity)


func test_skill_upgrade_delta_follows_rarity() -> void:
	var card := CardData.make_skill(&"t", "测试", 1, 10)
	card.rarity = CardData.Rarity.UNCOMMON
	assert_eq(card.create_upgraded().block, 14)


func test_power_upgrade_adds_two_regardless_of_rarity() -> void:
	for rarity: int in [CardData.Rarity.STARTER, CardData.Rarity.EPIC]:
		var card := CardData.new()
		card.id = &"t"
		card.type = CardData.CardType.POWER
		card.rarity = rarity
		card.apply_to_self = {"strength": 2}
		assert_eq(int(card.create_upgraded().apply_to_self["strength"]), 4,
			"能力牌统一 +2（稀有度 %d）" % rarity)


func test_debuff_upgrade_adds_two_layers() -> void:
	var card := CardData.make_attack(&"t", "测试", 1, 10)
	card.rarity = CardData.Rarity.COMMON
	card.apply_to_target = {"weak": 2}

	assert_eq(int(card.create_upgraded().apply_to_target["weak"]), 4)


func test_draw_upgrade_delta_follows_rarity() -> void:
	var expected := {
		CardData.Rarity.STARTER: 1,
		CardData.Rarity.COMMON: 1,
		CardData.Rarity.UNCOMMON: 1,
		CardData.Rarity.RARE: 2,
		CardData.Rarity.EPIC: 3,
	}
	for rarity: int in expected:
		var card := CardData.make_attack(&"t", "测试", 1, 5)
		card.rarity = rarity
		card.draw = 1
		assert_eq(card.create_upgraded().draw, 1 + int(expected[rarity]),
			"稀有度 %d 的抽牌增量不对" % rarity)


func test_explicit_override_beats_default_rule() -> void:
	var card := CardData.make_attack(&"t", "测试", 1, 10)
	card.rarity = CardData.Rarity.EPIC
	card.upgraded_damage = 99

	assert_eq(card.create_upgraded().damage, 99, "显式覆盖应优先于默认规则")


func test_upgrade_does_not_mutate_the_template() -> void:
	## 预览升级（休息点锻造界面）会把升级版画出来，
	## 如果 create_upgraded 改了原对象，注册表里的模板就被污染了
	var card := CardData.make_attack(&"t", "测试", 1, 10)
	card.rarity = CardData.Rarity.COMMON

	var upgraded := card.create_upgraded()

	assert_eq(card.damage, 10, "原牌数值不应被改动")
	assert_false(card.is_upgraded)
	assert_true(upgraded.is_upgraded)
	assert_true(upgraded.display_name.ends_with("+"))


func test_curse_cannot_be_upgraded() -> void:
	var card := CardData.make_attack(&"t", "诅咒", 0, 0)
	card.rarity = CardData.Rarity.CURSE

	assert_false(card.can_upgrade())


# ══ 描述与效果一致（用户的核心诉求）═════════════════════════

func test_description_reflects_upgraded_values() -> void:
	var card: CardData = ContentRegistry.get_card(&"strike")
	var upgraded := card.create_upgraded()

	assert_true(upgraded.format_description().contains(str(upgraded.damage)))


func test_description_reflects_strength_bonus() -> void:
	## 用户报的 bug 原型：卡面写 6、实际打 8
	var card: CardData = ContentRegistry.get_card(&"strike")
	var player := _make_creature()
	player.apply_power(BasePowers.Strength.new(2))

	assert_true(card.format_description(player).contains("8"),
		"有 2 点力量时卡面应显示 8 而不是 6")


func test_description_reflects_dexterity_bonus() -> void:
	var card: CardData = ContentRegistry.get_card(&"defend")
	var player := _make_creature()
	player.apply_power(BasePowers.Dexterity.new(2))

	assert_true(card.format_description(player).contains("7"),
		"有 2 点敏捷时卡面应显示 7 而不是 5")


func test_description_without_context_shows_base_values() -> void:
	var card: CardData = ContentRegistry.get_card(&"strike")
	assert_true(card.format_description().contains(str(card.damage)))


func test_no_leftover_placeholders_in_any_card() -> void:
	for card: CardData in ContentRegistry.all_cards():
		var text := card.format_description()
		assert_false(text.contains("{"),
			"卡牌 %s 的描述有未替换的占位符：%s" % [card.id, text])


func test_no_leftover_placeholders_in_upgraded_cards() -> void:
	for card: CardData in ContentRegistry.all_cards():
		if not card.can_upgrade():
			continue
		var text := card.create_upgraded().format_description()
		assert_false(text.contains("{"),
			"卡牌 %s 的升级描述有未替换的占位符：%s" % [card.id, text])


func test_block_preview_does_not_consume_shield_guard_bonus() -> void:
	## 预览必须**无副作用**——否则 UI 每刷新一次卡面，
	## 盾卫的「本回合第一张格挡 +3」就被白白消耗掉
	var c := _make_creature()
	c.apply_identity_power(IdentityPowers.create(&"shield_guard_stance"))
	var card: CardData = ContentRegistry.get_card(&"defend")

	assert_eq(card.preview_block(c), 8, "预览应含盾卫的 +3")
	assert_eq(card.preview_block(c), 8, "第二次预览仍应是 8（加成不能被消耗）")

	var actual: int = c.gain_block(card.block)
	assert_eq(actual, 8, "真正打出时才消耗加成")


# ══ 奖励池权重 ══════════════════════════════════════════════

func test_reward_weights_match_spec() -> void:
	assert_eq(CardPool.REWARD_WEIGHTS[CardData.Rarity.COMMON], 50)
	assert_eq(CardPool.REWARD_WEIGHTS[CardData.Rarity.UNCOMMON], 30)
	assert_eq(CardPool.REWARD_WEIGHTS[CardData.Rarity.RARE], 15)
	assert_eq(CardPool.REWARD_WEIGHTS[CardData.Rarity.EPIC], 5)


func test_reward_pool_excludes_non_reward_rarities() -> void:
	for card: CardData in CardPool.new().reward_candidates():
		assert_false(CardPool.REWARD_EXCLUDED.has(card.rarity),
			"%s（稀有度 %d）不该出现在奖励池里" % [card.id, card.rarity])


func test_reward_pool_covers_every_weighted_rarity() -> void:
	## 配了权重但池子里没有对应卡 → 那份权重是空转的，玩家永远抽不到这一档
	var present: Dictionary = {}
	for card: CardData in CardPool.new().reward_candidates():
		present[card.rarity] = true

	for rarity: int in CardPool.REWARD_WEIGHTS:
		assert_true(present.has(rarity),
			"稀有度 %d 配了权重但池子里没有卡" % rarity)


func test_roll_never_returns_excluded_rarity() -> void:
	var pool := CardPool.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i: int in 40:
		for card: CardData in pool.roll(3):
			assert_false(CardPool.REWARD_EXCLUDED.has(card.rarity))


# ══ RunState 的升级记录 ═════════════════════════════════════

func test_upgrade_marks_exactly_one_entry() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	assert_true(run.upgrade_card(&"strike"))

	var upgraded_entries: int = 0
	for entry: StringName in run.deck_card_ids:
		if RunState.is_upgraded_entry(entry):
			upgraded_entries += 1
	assert_eq(upgraded_entries, 1, "只应有一条记录被标记升级")


func test_upgrade_only_affects_one_copy_of_duplicates() -> void:
	## 初始牌组有 5 张打击，升级只该动一张
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.upgrade_card(&"strike")

	var upgraded: int = 0
	for card: CardData in run.build_deck():
		if card.id == &"strike" and card.is_upgraded:
			upgraded += 1
	assert_eq(upgraded, 1)


func test_build_deck_applies_the_upgrade() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.upgrade_card(&"strike")

	for card: CardData in run.build_deck():
		if card.id == &"strike" and card.is_upgraded:
			# 灰卡（STARTER）攻击牌 +3
			assert_eq(card.damage, 6 + 3)
			return
	fail_test("升级后的打击没有出现在牌组里")


func test_upgrading_a_card_not_in_deck_fails() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	assert_false(run.upgrade_card(&"divine_might"))


func test_cannot_upgrade_more_copies_than_owned() -> void:
	## 初始牌组是 5 打击 + 5 防御，升级 5 次后就没有可升级的打击了
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	var copies: int = 0
	for entry: StringName in run.deck_card_ids:
		if RunState.decode_card_id(entry) == &"strike":
			copies += 1
	assert_eq(copies, 5, "初始应有 5 张打击")

	for i: int in copies:
		assert_true(run.upgrade_card(&"strike"), "第 %d 张应能升级" % (i + 1))
	assert_false(run.upgrade_card(&"strike"), "5 张都升级完了，第 6 次应失败")


func test_upgradable_list_excludes_upgraded() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	var before: Array[StringName] = run.upgradable_card_ids()
	assert_true(before.has(&"strike"))

	# 把 5 张打击全部升级
	for _i: int in 5:
		run.upgrade_card(&"strike")

	var after: Array[StringName] = run.upgradable_card_ids()
	assert_false(after.has(&"strike"), "全部升级后不该再出现")
	assert_true(after.has(&"defend"), "防御还都没升级")


func test_deck_survives_save_round_trip_with_upgrades() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.upgrade_card(&"strike")

	var restored := RunState.new()
	restored.from_dict(run.to_dict())

	var upgraded: int = 0
	for entry: StringName in restored.deck_card_ids:
		if RunState.is_upgraded_entry(entry):
			upgraded += 1
	assert_eq(upgraded, 1, "升级状态必须能存进存档")
