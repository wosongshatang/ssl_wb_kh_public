extends GutTest
## 意图系统测试（阶段 2 剩余）
##
## 意图系统的核心承诺：**「显示给玩家的意图」与「敌人实际执行的行为」是同一份数据**。
## 一旦这条断了，就会出现 UI 显示 7 点、实际打 9 点这类撕裂——
## 玩家最不能容忍的一类 bug，而且极难复现定位。

func _make_enemy_data(intents: Array[IntentData]) -> EnemyData:
	var data := EnemyData.new()
	data.id = &"intent_dummy"
	data.display_name = "假人"
	data.max_hp = 30
	data.intents = intents
	return data


func _three_step_pattern() -> Array[IntentData]:
	var intents: Array[IntentData] = [
		IntentData.make_attack(7),
		IntentData.make_defend(6),
		IntentData.make_attack(3, 2),
	]
	return intents


# ══ 序列推进 ════════════════════════════════════════════════

func test_current_does_not_advance() -> void:
	var resolver := IntentResolver.new()
	resolver.setup(_make_enemy_data(_three_step_pattern()))

	assert_eq(resolver.current().total_damage(), 7)
	assert_eq(resolver.current().total_damage(), 7, "重复读 current 不应推进游标")
	assert_eq(resolver.cursor(), 0)


func test_advance_returns_current_then_moves_on() -> void:
	var resolver := IntentResolver.new()
	resolver.setup(_make_enemy_data(_three_step_pattern()))

	assert_eq(resolver.advance().type, IntentData.IntentType.ATTACK)
	assert_eq(resolver.advance().type, IntentData.IntentType.DEFEND)
	assert_eq(resolver.advance().type, IntentData.IntentType.ATTACK)


func test_pattern_loops() -> void:
	var resolver := IntentResolver.new()
	resolver.setup(_make_enemy_data(_three_step_pattern()))

	resolver.advance()
	resolver.advance()
	resolver.advance()

	assert_eq(resolver.cursor(), 0, "走完一轮应回到起点")
	assert_eq(resolver.current().total_damage(), 7, "第二轮应从第一步重新开始")


func test_empty_pattern_returns_null() -> void:
	var resolver := IntentResolver.new()
	resolver.setup(_make_enemy_data([]))

	assert_null(resolver.current(), "无意图序列时 current 应为 null")
	assert_null(resolver.advance(), "无意图序列时 advance 应为 null")


func test_setup_with_null_data_is_safe() -> void:
	var resolver := IntentResolver.new()
	resolver.setup(null)

	assert_null(resolver.current())
	assert_eq(resolver.pattern_size(), 0)


func test_reset_returns_to_first_step() -> void:
	var resolver := IntentResolver.new()
	resolver.setup(_make_enemy_data(_three_step_pattern()))
	resolver.advance()
	resolver.advance()

	resolver.reset()

	assert_eq(resolver.current().total_damage(), 7)


func test_seek_jumps_to_index() -> void:
	var resolver := IntentResolver.new()
	resolver.setup(_make_enemy_data(_three_step_pattern()))

	resolver.seek(1)
	assert_eq(resolver.current().type, IntentData.IntentType.DEFEND)

	resolver.seek(4)  # 3 步的序列，4 % 3 = 1
	assert_eq(resolver.current().type, IntentData.IntentType.DEFEND, "seek 应支持越界取模")


# ══ 多段攻击 ════════════════════════════════════════════════

func test_multi_hit_intent_totals_correctly() -> void:
	var intent := IntentData.make_attack(3, 2)

	assert_eq(intent.times, 2)
	assert_eq(intent.total_damage(), 6, "3×2 应为 6")
	assert_eq(intent.display_text(), "攻击 3×2")


func test_single_hit_display_text_has_no_multiplier() -> void:
	assert_eq(IntentData.make_attack(7).display_text(), "攻击 7")
	assert_eq(IntentData.make_defend(5).display_text(), "防御 5")


func test_non_attack_intent_has_zero_total_damage() -> void:
	assert_eq(IntentData.make_defend(9).total_damage(), 0, "防御意图没有伤害")


# ══ 与 Enemy 的装配 ═════════════════════════════════════════

func test_enemy_setup_from_data_applies_stats() -> void:
	var e := Enemy.new()
	autofree(e)
	e.setup_from_data(_make_enemy_data(_three_step_pattern()))

	assert_eq(e.display_name, "假人")
	assert_eq(e.max_hp, 30)
	assert_eq(e.hp, 30, "装配后应完成战斗初始化")


func test_enemy_current_intent_matches_resolver() -> void:
	var e := Enemy.new()
	autofree(e)
	e.setup_from_data(_make_enemy_data(_three_step_pattern()))

	assert_eq(e.current_intent().total_damage(), 7)
	assert_eq(e.current_intent().total_damage(), 7, "读取不应推进")
	assert_eq(e.advance_intent().type, IntentData.IntentType.ATTACK)
	assert_eq(e.current_intent().type, IntentData.IntentType.DEFEND, "推进后应换下一手")


# ══ 端到端：意图与实际结算一致 ══════════════════════════════

func test_enemy_intent_matches_actual_damage_dealt() -> void:
	## 这条是意图系统的**核心承诺**：UI 上看到的数字就是实际会打出的数字
	var player := Player.new()
	player.display_name = "战士"
	player.max_hp = 30
	player.reset_for_battle()
	autofree(player)

	var e := Enemy.new()
	autofree(e)
	e.setup_from_data(_make_enemy_data(_three_step_pattern()))

	var enemies: Array[Enemy] = [e]
	var deck: Array[CardData] = []
	for _i: int in 5:
		deck.append(CardData.make_skill(&"defend", "防御", 1, 0))

	var bm := BattleManager.new()
	autofree(bm)
	bm.start_battle(player, enemies, deck, RandomNumberGenerator.new())

	var predicted: int = e.current_intent().total_damage()
	assert_eq(predicted, 7, "开战时应显示 7 点攻击意图")

	bm.end_player_turn()

	assert_eq(player.hp, 30 - predicted, "实际掉血必须等于意图预告的数字")


func test_multi_hit_intent_is_resolved_per_hit() -> void:
	## 多段攻击要逐段结算——每段独立触发格挡与荆棘。
	## 若实现成一次性 6 点，有 4 点格挡的玩家会掉 2 血（正确），
	## 而分两段打则第一段吃掉 4 点格挡、第二段全额打 3 点（也是掉 3）。
	## 两者结果不同，所以必须逐段。
	var player := Player.new()
	player.display_name = "战士"
	player.max_hp = 30
	player.reset_for_battle()
	autofree(player)

	var e := Enemy.new()
	autofree(e)
	var intents: Array[IntentData] = [IntentData.make_attack(3, 2)]
	e.setup_from_data(_make_enemy_data(intents))

	var enemies: Array[Enemy] = [e]
	var deck: Array[CardData] = [CardData.make_skill(&"defend", "防御", 1, 0)]

	var bm := BattleManager.new()
	autofree(bm)
	bm.start_battle(player, enemies, deck, RandomNumberGenerator.new())

	# ⚠️ 格挡必须在 start_battle **之后**加——start_battle 会 reset_for_battle() 把它清掉
	player.gain_block(4)

	bm.end_player_turn()

	# 第 1 段：4 格挡挡下 3 点 → 格挡剩 1，不掉血
	# 第 2 段：1 格挡挡下 1 点，剩 2 点掉血
	assert_eq(player.hp, 28, "多段攻击应逐段结算（一次性结算会得到 27）")


func test_defend_intent_grants_block_to_enemy() -> void:
	var player := Player.new()
	player.display_name = "战士"
	player.max_hp = 30
	player.reset_for_battle()
	autofree(player)

	var e := Enemy.new()
	autofree(e)
	var intents: Array[IntentData] = [IntentData.make_defend(6)]
	e.setup_from_data(_make_enemy_data(intents))

	var enemies: Array[Enemy] = [e]
	var deck: Array[CardData] = [CardData.make_skill(&"defend", "防御", 1, 0)]

	var bm := BattleManager.new()
	autofree(bm)
	bm.start_battle(player, enemies, deck, RandomNumberGenerator.new())
	bm.end_player_turn()

	assert_eq(e.block, 6, "防御意图应给敌人加格挡")


func test_enemy_without_intents_does_nothing() -> void:
	var player := Player.new()
	player.display_name = "战士"
	player.max_hp = 30
	player.reset_for_battle()
	autofree(player)

	var e := Enemy.new()
	autofree(e)
	e.setup_from_data(_make_enemy_data([]))

	var enemies: Array[Enemy] = [e]
	var deck: Array[CardData] = [CardData.make_skill(&"defend", "防御", 1, 0)]

	var bm := BattleManager.new()
	autofree(bm)
	bm.start_battle(player, enemies, deck, RandomNumberGenerator.new())
	bm.end_player_turn()

	assert_eq(player.hp, 30, "无意图的敌人不应造成任何伤害")
