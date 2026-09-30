extends GutTest
## 牌堆管理测试（阶段 2 剩余：消耗区落地）
##
## 消耗区的全部意义就是**不参与重洗**。如果消耗的牌能被洗回抽牌堆，
## 阶段 5 法师线的「禁忌知识 / 死灵师」整个引擎就废了。

func _make_card(index: int) -> CardData:
	return CardData.make_attack(&"strike_%d" % index, "打击%d" % index, 1, 6)


func _setup_deck(count: int = 10) -> DeckManager:
	var deck := DeckManager.new(RandomNumberGenerator.new())
	var cards: Array[CardData] = []
	for i: int in count:
		cards.append(_make_card(i))
	deck.setup(cards)
	return deck


func _total_cards(deck: DeckManager) -> int:
	return deck.draw_pile.size() + deck.hand.size() + deck.discard_pile.size() + deck.exhaust_pile.size()


# ══ 基础流转 ════════════════════════════════════════════════

func test_setup_puts_everything_in_draw_pile() -> void:
	var deck := _setup_deck(10)

	assert_eq(deck.draw_pile.size(), 10)
	assert_eq(deck.hand.size(), 0)
	assert_eq(deck.discard_pile.size(), 0)
	assert_eq(deck.exhaust_pile.size(), 0)


func test_draw_moves_cards_to_hand() -> void:
	var deck := _setup_deck(10)

	var drawn: Array[CardData] = deck.draw(5)

	assert_eq(drawn.size(), 5)
	assert_eq(deck.hand.size(), 5)
	assert_eq(deck.draw_pile.size(), 5)


func test_draw_returns_fewer_when_piles_run_out() -> void:
	var deck := _setup_deck(3)

	var drawn: Array[CardData] = deck.draw(5)

	assert_eq(drawn.size(), 3, "牌不够时应提前停止而非报错")
	assert_eq(deck.hand.size(), 3)


func test_take_from_hand_removes_card() -> void:
	var deck := _setup_deck(5)
	deck.draw(5)
	var card: CardData = deck.hand[0]

	assert_true(deck.take_from_hand(card))
	assert_false(deck.hand.has(card))
	assert_false(deck.take_from_hand(card), "重复取出应返回 false")


func test_discard_hand_returns_count_and_clears() -> void:
	var deck := _setup_deck(10)
	deck.draw(5)

	var count: int = deck.discard_hand()

	assert_eq(count, 5)
	assert_eq(deck.hand.size(), 0)
	assert_eq(deck.discard_pile.size(), 5)


# ══ 消耗区 ══════════════════════════════════════════════════

func test_exhaust_moves_card_from_hand_to_exhaust_pile() -> void:
	var deck := _setup_deck(5)
	deck.draw(5)
	var card: CardData = deck.hand[0]

	assert_true(deck.exhaust(card))
	assert_false(deck.hand.has(card), "消耗的牌应离开手牌")
	assert_false(deck.discard_pile.has(card), "消耗的牌不应进弃牌堆")
	assert_true(deck.exhaust_pile.has(card), "应进消耗区")


func test_exhaust_returns_false_for_card_not_in_hand() -> void:
	var deck := _setup_deck(5)
	deck.draw(2)

	var outside: CardData = _make_card(99)
	assert_false(deck.exhaust(outside), "不在手牌里的牌不应被消耗")
	assert_eq(deck.exhaust_pile.size(), 0)


func test_exhausted_cards_never_return_to_draw_pile() -> void:
	## 这是消耗区存在的**全部意义**
	var deck := _setup_deck(6)
	deck.draw(6)
	var exhausted: CardData = deck.hand[0]
	deck.exhaust(exhausted)

	deck.discard_hand()   # 剩 5 张进弃牌堆
	deck.draw(5)          # 抽牌堆空 → 重洗弃牌堆

	assert_false(deck.draw_pile.has(exhausted), "消耗的牌绝不能回到抽牌堆")
	assert_false(deck.hand.has(exhausted), "消耗的牌绝不能回到手牌")
	assert_eq(deck.exhaust_pile.size(), 1)


func test_total_card_count_is_conserved_with_exhaust() -> void:
	var deck := _setup_deck(10)
	deck.draw(6)
	deck.exhaust(deck.hand[0])
	deck.exhaust(deck.hand[0])
	deck.discard_hand()
	deck.draw(3)

	assert_eq(_total_cards(deck), 10, "牌只在各堆之间流转，总数恒为 10")


func test_setup_clears_exhaust_pile() -> void:
	var deck := _setup_deck(5)
	deck.draw(5)
	deck.exhaust(deck.hand[0])
	assert_eq(deck.exhaust_pile.size(), 1)

	var empty: Array[CardData] = []
	deck.setup(empty)

	assert_eq(deck.exhaust_pile.size(), 0, "开新局应清空消耗区")


# ══ 洗牌可复现性 ════════════════════════════════════════════

func test_same_seed_produces_same_order() -> void:
	var cards: Array[CardData] = []
	for i: int in 10:
		cards.append(_make_card(i))

	var a := DeckManager.new(_seeded_rng(12345))
	a.setup(cards)
	var b := DeckManager.new(_seeded_rng(12345))
	b.setup(cards)

	var a_ids: Array[StringName] = []
	for card: CardData in a.draw_pile:
		a_ids.append(card.id)
	var b_ids: Array[StringName] = []
	for card: CardData in b.draw_pile:
		b_ids.append(card.id)

	assert_eq(a_ids, b_ids, "相同种子应得到相同牌序（否则测试无法断言洗牌结果）")


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
