extends GutTest
## 回合流转状态机测试（阶段 2 剩余）
##
## TurnFlow 的价值在于把「回合规则」收进一个可测的纯逻辑类。
## 阶段 4 的 Boss 额外回合、眩晕跳回合、神战 P4 的回合结构改动，
## 都会落到这里——所以它的边界行为必须现在就有测试锁住。

func _started_flow() -> TurnFlow:
	var flow := TurnFlow.new()
	flow.begin()
	return flow


func test_begin_starts_at_player_turn_one() -> void:
	var flow := TurnFlow.new()
	watch_signals(flow)

	flow.begin()

	assert_eq(flow.turn_number, 1)
	assert_eq(flow.phase, TurnFlow.Phase.PLAYER_TURN)
	assert_true(flow.is_player_turn())
	assert_false(flow.is_over())
	assert_signal_emitted_with_parameters(flow, "player_turn_started", [1])


func test_end_player_turn_moves_to_enemy_turn() -> void:
	var flow := _started_flow()
	watch_signals(flow)

	flow.end_player_turn()

	assert_eq(flow.phase, TurnFlow.Phase.ENEMY_TURN)
	assert_false(flow.is_player_turn())
	assert_signal_emitted_with_parameters(flow, "enemy_turn_started", [1])


func test_end_enemy_turn_advances_turn_number() -> void:
	var flow := _started_flow()
	flow.end_player_turn()

	flow.end_enemy_turn()

	assert_eq(flow.turn_number, 2, "回到玩家回合时回合数应 +1")
	assert_eq(flow.phase, TurnFlow.Phase.PLAYER_TURN)


func test_phase_changed_fires_on_every_transition() -> void:
	var flow := _started_flow()
	watch_signals(flow)

	flow.end_player_turn()
	flow.end_enemy_turn()

	# begin() 那次发生在 watch_signals 之前，不计入；这里只有两次转移
	assert_signal_emit_count(flow, "phase_changed", 2)


# ══ 结束战斗 ════════════════════════════════════════════════

func test_finish_sets_battle_over_and_broadcasts_result() -> void:
	var flow := _started_flow()
	watch_signals(flow)

	flow.finish(true)

	assert_true(flow.is_over())
	assert_eq(flow.phase, TurnFlow.Phase.BATTLE_OVER)
	assert_signal_emitted_with_parameters(flow, "battle_finished", [true])


func test_finish_is_idempotent() -> void:
	var flow := _started_flow()
	flow.finish(true)
	watch_signals(flow)

	flow.finish(false)

	assert_signal_emit_count(flow, "battle_finished", 0, "重复 finish 不应再次广播")


# ══ 边界：非法转移必须被忽略 ════════════════════════════════

func test_end_player_turn_is_ignored_outside_player_turn() -> void:
	var flow := _started_flow()
	flow.end_player_turn()

	flow.end_player_turn()  # 现在是敌人回合，这次应被忽略

	assert_eq(flow.phase, TurnFlow.Phase.ENEMY_TURN, "非玩家回合的调用应被忽略")
	assert_eq(flow.turn_number, 1)


func test_end_enemy_turn_is_ignored_outside_enemy_turn() -> void:
	var flow := _started_flow()

	flow.end_enemy_turn()  # 现在是玩家回合，这次应被忽略

	assert_eq(flow.phase, TurnFlow.Phase.PLAYER_TURN)
	assert_eq(flow.turn_number, 1, "不应推进回合数")


func test_cannot_advance_after_battle_over() -> void:
	var flow := _started_flow()
	flow.finish(false)

	flow.end_player_turn()
	flow.end_enemy_turn()

	assert_true(flow.is_over())
	assert_eq(flow.turn_number, 1, "战斗结束后不应再推进回合")


func test_initial_state_is_idle() -> void:
	var flow := TurnFlow.new()

	assert_eq(flow.phase, TurnFlow.Phase.IDLE)
	assert_eq(flow.turn_number, 0)
	assert_false(flow.is_over())
	assert_false(flow.is_player_turn())


# ══ 与 BattleManager 的协作 ═════════════════════════════════

func _make_player(hp: int = 30) -> Player:
	var p := Player.new()
	p.display_name = "战士"
	p.max_hp = hp
	p.reset_for_battle()
	autofree(p)
	return p


func _make_dummy_enemy() -> Enemy:
	var data := EnemyData.new()
	data.id = &"turn_flow_dummy"
	data.display_name = "假人"
	data.max_hp = 9999
	var intents: Array[IntentData] = [IntentData.make_attack(0)]
	data.intents = intents
	var e := Enemy.new()
	e.setup_from_data(data)
	autofree(e)
	return e


func _make_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	for _i: int in 10:
		deck.append(CardData.make_skill(&"defend", "防御", 1, 5))
	return deck


func test_battle_manager_phase_delegates_to_flow() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_dummy_enemy()]
	var bm := BattleManager.new()
	autofree(bm)

	bm.start_battle(player, enemies, _make_deck(), RandomNumberGenerator.new())

	assert_eq(bm.phase, TurnFlow.Phase.PLAYER_TURN, "BattleManager.phase 应透传 TurnFlow 的状态")
	assert_eq(bm.turn_number, 1)
	assert_not_null(bm.flow, "flow 应可被外部访问以便订阅信号")


func test_battle_manager_broadcasts_phase_changed() -> void:
	## 一次 end_player_turn 会连发两次 phase_changed：
	## ENEMY_TURN（敌人开始行动）→ PLAYER_TURN（敌人行动完回到玩家）。
	## 这里断言**完整序列**而不是"某一次匹配"——否则测不出顺序颠倒。
	## （GUT 的 assert_signal_emitted_with_parameters 默认只比对某一次发射，
	##   用来测序列会漏掉错误顺序。）
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_dummy_enemy()]
	var bm := BattleManager.new()
	autofree(bm)
	bm.start_battle(player, enemies, _make_deck(), RandomNumberGenerator.new())
	watch_signals(bm)

	bm.end_player_turn()

	assert_signal_emit_count(bm, "phase_changed", 2, "一个完整回合应发两次阶段变化")
	assert_eq(get_signal_parameters(bm, "phase_changed", 0)[0], TurnFlow.Phase.ENEMY_TURN,
		"第一次应是进入敌人回合")
	assert_eq(get_signal_parameters(bm, "phase_changed", 1)[0], TurnFlow.Phase.PLAYER_TURN,
		"第二次应是回到玩家回合")


func test_turn_number_advances_through_full_cycle() -> void:
	var player := _make_player()
	var enemies: Array[Enemy] = [_make_dummy_enemy()]
	var bm := BattleManager.new()
	autofree(bm)
	bm.start_battle(player, enemies, _make_deck(), RandomNumberGenerator.new())

	bm.end_player_turn()

	assert_eq(bm.turn_number, 2, "敌人回合结束应回到玩家第 2 回合")
	assert_eq(bm.phase, TurnFlow.Phase.PLAYER_TURN)
