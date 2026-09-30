extends GutTest
## 卡池与卡牌效果测试（阶段 3）
##
## 重点守两条：
##   1. **抽卡不能重复、不能死循环**（要的比卡池多时）
##   2. **卡牌效果按字段驱动**（D16）——攻防一体牌必须同时结算伤害与格挡，
##      按类型分支的实现会把其中一半静默丢掉

func before_all() -> void:
	ContentRegistry.load_all()


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# ══ 卡池 ════════════════════════════════════════════════════

func test_pool_is_not_empty() -> void:
	assert_gt(ContentRegistry.all_cards().size(), 0, "卡池不应为空——检查 data/cards/")
	assert_gt(ContentRegistry.all_card_ids().size(), 0)


func test_roll_returns_requested_count() -> void:
	var pool := CardPool.new(_seeded_rng(1))
	assert_eq(pool.roll(3).size(), 3)
	assert_eq(pool.roll(1).size(), 1)


func test_roll_never_repeats_a_card() -> void:
	var pool := CardPool.new(_seeded_rng(2))
	var offers: Array[CardData] = pool.roll(5)

	var seen: Dictionary = {}
	for card: CardData in offers:
		assert_false(seen.has(card.id), "抽到的牌不应重复：%s" % card.id)
		seen[card.id] = true


func test_roll_clamps_when_asking_for_more_than_pool() -> void:
	## 要的比卡池多时必须返回全部而不是死循环——这是个很容易写错的地方
	var total: int = ContentRegistry.all_cards().size()
	var pool := CardPool.new(_seeded_rng(3))

	assert_eq(pool.roll(total + 50).size(), total)


func test_same_seed_produces_same_offers() -> void:
	var a: Array[CardData] = CardPool.new(_seeded_rng(99)).roll(3)
	var b: Array[CardData] = CardPool.new(_seeded_rng(99)).roll(3)

	var a_ids: Array[StringName] = []
	for card: CardData in a:
		a_ids.append(card.id)
	var b_ids: Array[StringName] = []
	for card: CardData in b:
		b_ids.append(card.id)

	assert_eq(a_ids, b_ids, "同种子应抽出同样的牌（否则测试无从断言）")


func test_price_increases_with_rarity() -> void:
	var common: CardData = ContentRegistry.get_card(&"strike")
	var rare: CardData = ContentRegistry.get_card(&"impervious")

	assert_not_null(common)
	assert_not_null(rare)
	assert_gt(CardPool.price_of(rare), CardPool.price_of(common),
		"稀有卡应比普通卡贵")


func test_rarity_weights_favour_common_cards() -> void:
	var pool := CardPool.new(_seeded_rng(7))
	var common: CardData = ContentRegistry.get_card(&"strike")
	var rare: CardData = ContentRegistry.get_card(&"impervious")
	assert_not_null(common)
	assert_not_null(rare)

	assert_gt(pool.weight_of(common), pool.weight_of(rare),
		"普通卡的抽取权重应高于稀有卡")


# ══ PowerFactory ════════════════════════════════════════════

func test_factory_creates_every_known_power() -> void:
	var ids: Array[StringName] = [
		&"strength", &"dexterity", &"weak", &"vulnerable", &"poison", &"thorns", &"buffer",
	]
	for power_id: StringName in ids:
		var power := PowerFactory.create(power_id, 2)
		assert_not_null(power, "应能创建 %s" % power_id)
		assert_eq(power.id, power_id)
		assert_eq(power.amount, 2)


func test_factory_returns_null_for_unknown_id() -> void:
	## 未知 id 必须返回 null（并告警），不能静默返回一个空 Power——
	## 那会让「这张牌看起来生效了但什么都没发生」极难排查
	assert_null(PowerFactory.create(&"definitely_not_a_power", 1))


func test_factory_knows_all_registered_powers() -> void:
	assert_true(PowerFactory.is_known(&"strength"))
	assert_false(PowerFactory.is_known(&"nope"))


# ══ 卡牌效果字段（D16 的回归测试）═══════════════════════════

func _make_player() -> Player:
	var p := Player.new()
	p.display_name = "战士"
	p.max_hp = 60
	p.reset_for_battle()
	autofree(p)
	return p


func _make_enemy(hp: int = 200, attack: int = 0) -> Enemy:
	var data := EnemyData.new()
	data.id = &"dummy"
	data.display_name = "假人"
	data.max_hp = hp
	var intents: Array[IntentData] = [IntentData.make_attack(attack)]
	data.intents = intents
	var e := Enemy.new()
	e.setup_from_data(data)
	autofree(e)
	return e


func _start(player: Player, enemy: Enemy) -> BattleManager:
	var bm := BattleManager.new()
	autofree(bm)
	var enemies: Array[Enemy] = [enemy]
	var empty_deck: Array[CardData] = []
	bm.start_battle(player, enemies, empty_deck, _seeded_rng(5))
	return bm


## 从注册表取一张牌并**复制**一份塞进手牌（不能直接用注册表里的共享实例）
func _give_card(bm: BattleManager, card_id: StringName) -> CardData:
	var source: Variant = ContentRegistry.get_card(card_id)
	assert_true(source is CardData, "找不到卡牌 %s" % card_id)
	var card: CardData = (source as CardData).duplicate() as CardData
	bm.deck.hand.append(card)
	return card


func test_dual_purpose_card_applies_damage_and_block() -> void:
	## 铁斩波：5 伤 + 5 格挡。按类型分支的实现会把 block 整块丢掉——
	## 这条测试就是那个 bug 的守门人。
	var player := _make_player()
	var enemy := _make_enemy()
	var bm := _start(player, enemy)

	var card: CardData = _give_card(bm, &"iron_wave")
	var hp_before: int = enemy.hp
	bm.play_card(card, enemy)

	assert_eq(enemy.hp, hp_before - 5, "应造成 5 点伤害")
	assert_eq(player.block, 5, "同时应获得 5 点格挡")


func test_card_grants_power_to_self() -> void:
	var player := _make_player()
	var enemy := _make_enemy()
	var bm := _start(player, enemy)

	bm.play_card(_give_card(bm, &"inflame"))

	assert_eq(player.get_power_amount(&"strength"), 2, "燃烧应给 2 点力量")


func test_card_applies_power_to_target() -> void:
	var player := _make_player()
	var enemy := _make_enemy()
	var bm := _start(player, enemy)

	bm.play_card(_give_card(bm, &"clothesline"), enemy)

	assert_eq(enemy.get_power_amount(&"weak"), 2, "晾衣绳应给目标 2 层虚弱")


func test_card_draws_cards() -> void:
	var player := _make_player()
	var enemy := _make_enemy()
	var bm := _start(player, enemy)

	# 往抽牌堆塞几张，保证有牌可抽
	for _i: int in 3:
		bm.deck.draw_pile.append(CardData.make_skill(&"defend", "防御", 1, 5))

	var card: CardData = _give_card(bm, &"pommel_strike")
	var hand_before: int = bm.deck.hand.size()
	bm.play_card(card, enemy)

	# 打出 -1 张，抽 +1 张 → 净持平
	assert_eq(bm.deck.hand.size(), hand_before, "剑柄打击应抽 1 张牌")


func test_strength_from_card_affects_subsequent_attack() -> void:
	## 端到端：卡牌给的力量必须真的进伤害管线
	var player := _make_player()
	var enemy := _make_enemy()
	var bm := _start(player, enemy)

	bm.play_card(_give_card(bm, &"inflame"))          # +2 力量
	var hp_before: int = enemy.hp
	bm.play_card(_give_card(bm, &"strike"), enemy)     # 6 + 2 = 8

	assert_eq(enemy.hp, hp_before - 8, "力量应作用于后续攻击")


func test_self_hp_loss_ignores_block() -> void:
	var player := _make_player()
	var enemy := _make_enemy()
	var bm := _start(player, enemy)
	player.gain_block(20)

	var card := CardData.make_attack(&"bloodletting", "放血", 0, 0)
	card.self_hp_loss = 3
	bm.deck.hand.append(card)

	var hp_before: int = player.hp
	bm.play_card(card)

	assert_eq(player.hp, hp_before - 3, "自伤应无视格挡")
	assert_eq(player.block, 20, "格挡不应被自伤消耗")


func test_gain_energy_field_works() -> void:
	var player := _make_player()
	var enemy := _make_enemy()
	var bm := _start(player, enemy)

	var card := CardData.make_skill(&"adrenaline", "肾上腺素", 0, 0)
	card.gain_energy = 2
	bm.deck.hand.append(card)

	var energy_before: int = player.energy
	bm.play_card(card)

	assert_eq(player.energy, energy_before + 2, "应获得 2 点能量")


# ══ 卡牌实例隔离（阶段 6 卡牌升级的前置条件）════════════════

func test_build_deck_returns_independent_copies() -> void:
	## 注册表里的卡是全局单例。如果牌组直接引用它们，
	## 「升级某一张牌」会连带改掉牌组里所有同名牌，甚至跨局生效。
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	var deck: Array[CardData] = run.build_deck()
	var registry_strike: Variant = ContentRegistry.get_card(&"strike")

	for card: CardData in deck:
		if card.id == &"strike":
			assert_ne(card, registry_strike as CardData,
				"牌组里的牌必须是副本，不能是注册表共享实例")


func test_deck_copies_are_not_shared_between_entries() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	var deck: Array[CardData] = run.build_deck()

	var first_strike: CardData = null
	for card: CardData in deck:
		if card.id == &"strike":
			if first_strike == null:
				first_strike = card
			else:
				assert_ne(card, first_strike,
					"同名牌的不同条目必须是不同对象，否则升级一张会改掉全部")
