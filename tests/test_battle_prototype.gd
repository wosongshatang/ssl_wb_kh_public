extends GutTest
## 阶段 1 战斗原型验收测试
##
## 覆盖设计文档 §11 阶段 1 的**六项硬指标**：
##   1. 开局抽 5 张
##   2. 出牌正确扣能量
##   3. 回合结束弃手牌
##   4. 敌人回合正确结算
##   5. 抽牌堆空时正确洗牌
##   6. 玩家 / 敌人死亡正确结束战斗
##
## ⚠️ 本文件随阶段 1 的「一次性代码」一起在阶段 2 重写。

const HAND_SIZE: int = 5
const BASE_ENERGY: int = 3


# ── 构造辅助 ────────────────────────────────────────────────

func _make_player(hp: int = 30) -> Player:
	var p := Player.new()
	p.display_name = "战士"
	p.max_hp = hp
	p.reset_for_battle()
	autofree(p)
	return p


func _make_enemy(hp: int = 24, attack: int = 7) -> Enemy:
	var e := Enemy.new()
	e.display_name = "竞技场新兵"
	e.max_hp = hp
	e.attack_damage = attack
	e.reset_for_battle()
	autofree(e)
	return e


## 战士初始牌组：5 打击(6) + 5 防御(5)
func _make_deck(strikes: int = 5, defends: int = 5) -> Array[CardData]:
	var deck: Array[CardData] = []
	for _i: int in strikes:
		deck.append(CardData.make_attack(&"strike", "打击", 1, 6))
	for _i: int in defends:
		deck.append(CardData.make_skill(&"defend", "防御", 1, 5))
	return deck


func _start(player: Player, enemies: Array[Enemy], deck: Array[CardData]) -> BattleManager:
	var bm := BattleManager.new()
	autofree(bm)
	bm.start_battle(player, enemies, deck, RandomNumberGenerator.new())
	return bm


## 把手牌替换成指定构成。
## 为什么需要它：抽牌是随机的，5 攻击 + 5 防御的牌组**完全可能抽出「5 张全是防御」**，
## 于是任何依赖「手牌里一定有攻击牌」的测试都会随机失败。
## 凡是关心**具体牌型**的测试，都必须显式设置手牌，不能依赖洗牌顺序。
func _set_hand(bm: BattleManager, cards: Array[CardData]) -> void:
	bm.deck.hand.clear()
	for card: CardData in cards:
		bm.deck.hand.append(card)


# ── 指标 1：开局抽 5 张 ─────────────────────────────────────

func test_battle_starts_with_five_cards_in_hand() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_enemy()]
	var bm := _start(player, enemies, _make_deck())

	assert_eq(bm.deck.hand.size(), HAND_SIZE, "开局手牌应为 5 张")
	assert_eq(bm.deck.draw_pile.size(), 5, "10 张牌组抽 5 张后抽牌堆应剩 5 张")
	assert_eq(bm.deck.discard_pile.size(), 0, "开局弃牌堆应为空")
	assert_eq(bm.turn_number, 1, "应处于第 1 回合")
	assert_eq(bm.phase, BattleManager.Phase.PLAYER_TURN, "开局应是玩家回合")


func test_player_starts_turn_with_full_energy() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_enemy()]
	var bm := _start(player, enemies, _make_deck())

	assert_eq(player.energy, BASE_ENERGY, "回合开始能量应为 3")
	assert_eq(bm.player.hp, 30, "玩家生命应初始化为 30")


# ── 指标 2：出牌正确扣能量 ──────────────────────────────────

func test_playing_card_spends_energy_and_moves_card_to_discard() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_enemy(9999, 0)]
	var bm := _start(player, enemies, _make_deck())

	var card := CardData.make_attack(&"strike", "打击", 1, 6)
	var hand: Array[CardData] = [card]
	_set_hand(bm, hand)

	var energy_before: int = player.energy
	var ok: bool = bm.play_card(card, enemies[0])

	assert_true(ok, "能量充足时应能打出")
	assert_eq(player.energy, energy_before - card.cost, "应扣除卡牌费用的能量")
	assert_false(bm.deck.hand.has(card), "打出的牌应离开手牌")
	assert_true(bm.deck.discard_pile.has(card), "打出的牌应进入弃牌堆")


func test_playing_card_is_rejected_when_energy_is_insufficient() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_enemy(9999, 0)]
	var bm := _start(player, enemies, _make_deck())

	# 手牌直接换成 3 张 1 费攻击牌，不依赖洗牌顺序
	var hand: Array[CardData] = []
	for _i: int in BASE_ENERGY:
		hand.append(CardData.make_attack(&"strike", "打击", 1, 1))
	_set_hand(bm, hand)

	for _i: int in BASE_ENERGY:
		assert_true(bm.play_card(bm.deck.hand[0], enemies[0]), "第 %d 张应能打出" % (_i + 1))
	assert_eq(player.energy, 0, "3 张 1 费牌应打光 3 点能量")

	var extra := CardData.make_attack(&"strike", "打击", 1, 6)
	bm.deck.hand.append(extra)

	assert_false(bm.play_card(extra, enemies[0]), "能量不足时应拒绝出牌")
	assert_eq(player.energy, 0, "被拒绝时不应扣能量")
	assert_true(bm.deck.hand.has(extra), "被拒绝的牌应留在手上")


func test_attack_card_deals_damage_through_block() -> void:
	var player := _make_player()
	var enemy := _make_enemy(24, 0)
	var enemies: Array[Enemy] = [enemy]
	var bm := _start(player, enemies, _make_deck())

	enemy.gain_block(4)
	var card := CardData.make_attack(&"strike", "打击", 1, 6)
	var hand: Array[CardData] = [card]
	_set_hand(bm, hand)
	bm.play_card(card, enemy)

	assert_eq(enemy.block, 0, "4 点格挡应被 6 点伤害打光")
	assert_eq(enemy.hp, 24 - 2, "溢出的 2 点应扣生命")


func test_skill_card_grants_block() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_enemy(9999, 0)]
	var bm := _start(player, enemies, _make_deck())

	var card := CardData.make_skill(&"defend", "防御", 1, 5)
	var hand: Array[CardData] = [card]
	_set_hand(bm, hand)
	bm.play_card(card)

	assert_eq(player.block, 5, "防御牌应给 5 点格挡")


# ── 指标 3：回合结束弃手牌 ──────────────────────────────────

func test_hand_is_discarded_at_turn_end() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_enemy(9999, 0)]
	var bm := _start(player, enemies, _make_deck())

	var hand_before: int = bm.deck.hand.size()
	var discard_before: int = bm.deck.discard_pile.size()

	bm.end_player_turn()

	assert_eq(bm.deck.discard_pile.size(), discard_before + hand_before,
		"回合结束时整张手牌应进弃牌堆")
	assert_eq(bm.deck.hand.size(), HAND_SIZE, "新回合应重新抽满 5 张")
	assert_eq(bm.turn_number, 2, "应进入第 2 回合")


# ── 指标 4：敌人回合正确结算 ────────────────────────────────

func test_enemy_turn_deals_damage_to_player() -> void:
	var player := _make_player(30)
	var enemies: Array[Enemy] = [_make_enemy(9999, 7)]
	var bm := _start(player, enemies, _make_deck())

	var hp_before: int = player.hp
	bm.end_player_turn()

	assert_eq(player.hp, hp_before - 7, "敌人应造成 7 点伤害")
	assert_eq(bm.turn_number, 2, "敌人回合后应回到玩家第 2 回合")


func test_block_absorbs_enemy_damage_and_is_cleared_next_turn() -> void:
	var player := _make_player(30)
	var enemies: Array[Enemy] = [_make_enemy(9999, 7)]
	var bm := _start(player, enemies, _make_deck())

	var skill := CardData.make_skill(&"defend", "防御", 1, 5)
	var hand: Array[CardData] = [skill]
	_set_hand(bm, hand)
	bm.play_card(skill)
	assert_eq(player.block, 5, "先垫 5 点格挡")

	bm.end_player_turn()

	assert_eq(player.hp, 30 - 2, "5 点格挡应吸收 7 点中的 5 点")
	assert_eq(player.block, 0, "新回合开始时格挡应清除（见 decisions.md Q1）")


func test_multiple_enemies_all_act() -> void:
	var player := _make_player(30)
	var a := _make_enemy(9999, 4)
	var b := _make_enemy(9999, 3)
	var enemies: Array[Enemy] = [a, b]
	var bm := _start(player, enemies, _make_deck())

	bm.end_player_turn()

	assert_eq(player.hp, 30 - 7, "两个敌人应各自结算一次（4 + 3）")


# ── 指标 5：抽牌堆空时正确洗牌 ──────────────────────────────

func test_draw_pile_reshuffles_from_discard_when_empty() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_enemy(9999, 0)]
	var bm := _start(player, enemies, _make_deck())
	watch_signals(bm.deck)

	bm.end_player_turn()
	assert_eq(bm.deck.draw_pile.size(), 0, "第 2 回合抽完后抽牌堆应为空")
	assert_eq(bm.deck.discard_pile.size(), 5, "弃牌堆应有第 1 回合弃掉的 5 张")

	bm.end_player_turn()
	assert_eq(bm.turn_number, 3, "应进入第 3 回合")
	assert_eq(bm.deck.hand.size(), HAND_SIZE, "重洗后应抽满 5 张")
	assert_signal_emitted(bm.deck, "reshuffled", "抽牌堆空时应触发重洗")


func test_deck_conserves_total_card_count() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_enemy(9999, 0)]
	var bm := _start(player, enemies, _make_deck())
	watch_signals(bm.deck)

	for _i: int in 6:
		bm.end_player_turn()

	var total: int = (bm.deck.draw_pile.size() + bm.deck.hand.size()
		+ bm.deck.discard_pile.size() + bm.deck.exhaust_pile.size())
	assert_eq(total, 10, "牌只应在各堆之间流转，总数恒为 10")


# ── 指标 6：玩家 / 敌人死亡正确结束战斗 ─────────────────────

func test_battle_ends_when_enemy_dies() -> void:
	var player := _make_player(30)
	var enemy := _make_enemy(5, 0)
	var enemies: Array[Enemy] = [enemy]
	var bm := _start(player, enemies, _make_deck())
	watch_signals(bm)

	var card := CardData.make_attack(&"strike", "打击", 1, 6)
	var hand: Array[CardData] = [card]
	_set_hand(bm, hand)
	bm.play_card(card, enemy)

	assert_false(enemy.is_alive(), "5 血敌人应被 6 点伤害击杀")
	assert_true(bm.is_over(), "敌人死亡后战斗应结束")
	assert_eq(bm.phase, BattleManager.Phase.BATTLE_OVER, "阶段应切到 BATTLE_OVER")
	assert_signal_emitted_with_parameters(bm, "battle_ended", [true])


func test_battle_ends_when_player_dies() -> void:
	var player := _make_player(5)
	var enemies: Array[Enemy] = [_make_enemy(9999, 99)]
	var bm := _start(player, enemies, _make_deck())
	watch_signals(bm)

	bm.end_player_turn()

	assert_false(player.is_alive(), "5 血玩家应被 99 点伤害击杀")
	assert_true(bm.is_over(), "玩家死亡后战斗应结束")
	assert_signal_emitted_with_parameters(bm, "battle_ended", [false])


func test_cannot_play_card_after_battle_over() -> void:
	var player := _make_player(30)
	var enemy := _make_enemy(5, 0)
	var enemies: Array[Enemy] = [enemy]
	var bm := _start(player, enemies, _make_deck())

	var card := CardData.make_attack(&"strike", "打击", 1, 6)
	var hand: Array[CardData] = [card]
	_set_hand(bm, hand)
	bm.play_card(card, enemy)
	assert_true(bm.is_over(), "战斗应已结束")

	# 战斗结束后手牌可能还有牌，但不允许再打出
	var leftover := CardData.make_attack(&"strike", "打击", 0, 6)
	bm.deck.hand.append(leftover)
	assert_false(bm.play_card(leftover, enemy), "战斗结束后应拒绝出牌")


# ── Creature 基础行为 ───────────────────────────────────────

func test_block_is_cleared_at_owners_turn_start() -> void:
	## 格挡时序（decisions.md D10 / Q1 定案）：自身回合开始时清零。
	## 阶段 2 起入口改名为 on_turn_start（同时分发 Power 钩子）。
	var player := _make_player()
	player.gain_block(10)
	assert_eq(player.block, 10)

	player.on_turn_start()
	assert_eq(player.block, 0, "自身回合开始时格挡应清除")


func test_heal_cannot_exceed_max_hp() -> void:
	var player := _make_player(30)
	player.take_damage(10)
	assert_eq(player.hp, 20)

	player.heal(999)
	assert_eq(player.hp, 30, "治疗不应超过最大生命")


func test_card_data_factories_set_fields() -> void:
	var attack := CardData.make_attack(&"strike", "打击", 1, 6)
	assert_eq(attack.type, CardData.CardType.ATTACK)
	assert_eq(attack.damage, 6)
	assert_eq(attack.block, 0)

	var skill := CardData.make_skill(&"defend", "防御", 1, 5)
	assert_eq(skill.type, CardData.CardType.SKILL)
	assert_eq(skill.block, 5)
	assert_eq(skill.damage, 0)
