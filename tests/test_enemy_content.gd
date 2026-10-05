extends GutTest
## 阶段 4 剩余：敌人配置 / Boss 双姿态 / 神战 P4

func before_all() -> void:
	ContentRegistry.load_all()


const ALL_ENEMY_IDS: Array[StringName] = [
	&"act1_combat", &"act1_poisoner", &"act1_elite", &"act1_boss",
	&"act2_combat", &"act2_poisoner", &"act2_elite", &"act2_boss",
	&"act3_combat", &"act3_elite", &"act3_boss",
]


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _make_creature(hp: int = 60) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


func _make_enemy(enemy_id: StringName) -> Enemy:
	var data: EnemyData = ContentRegistry.get_enemy(enemy_id)
	assert_not_null(data, "应能加载敌人 %s" % enemy_id)
	var e := Enemy.new()
	e.setup_from_data(data)
	e.apply_starting_powers()
	autofree(e)
	return e


# ══ 敌人配置 ════════════════════════════════════════════════

func test_every_enemy_is_registered() -> void:
	for enemy_id: StringName in ALL_ENEMY_IDS:
		assert_not_null(ContentRegistry.get_enemy(enemy_id), "应注册敌人 %s" % enemy_id)


func test_every_enemy_loads_with_intents_and_hp() -> void:
	## 这条同时验证 `.tres` 里 `intents = Array[IntentData]([...])` 的序列化格式。
	## 如果 Godot 改了这个格式，这里会**先红**——而不是等玩家进战斗才发现敌人在发呆。
	for enemy_id: StringName in ALL_ENEMY_IDS:
		var data: EnemyData = ContentRegistry.get_enemy(enemy_id)
		assert_not_null(data, "%s 应能加载为 EnemyData" % enemy_id)
		assert_gt(data.intents.size(), 0, "%s 的意图序列不应为空" % enemy_id)
		assert_gt(data.max_hp, 0, "%s 的血量应大于 0" % enemy_id)
		assert_ne(data.display_name, "", "%s 应有显示名" % enemy_id)


func test_every_buff_or_debuff_intent_references_a_known_power() -> void:
	for enemy_id: StringName in ALL_ENEMY_IDS:
		var data: EnemyData = ContentRegistry.get_enemy(enemy_id)
		for intent: IntentData in data.intents:
			var kind: IntentData.IntentType = intent.type
			if kind == IntentData.IntentType.BUFF or kind == IntentData.IntentType.DEBUFF:
				assert_true(PowerFactory.is_known(intent.power_id),
					"%s 的意图引用了未知 Power「%s」" % [enemy_id, intent.power_id])


func test_every_identity_power_on_enemies_resolves() -> void:
	## 身份能力现在**既可以挂在敌人上，也可以挂在形态上**——
	## 两处都要检查，否则一个手滑的 id 会静默变成"这个形态什么都没加"
	for enemy_id: StringName in ALL_ENEMY_IDS:
		var data: EnemyData = ContentRegistry.get_enemy(enemy_id)

		for power_id: StringName in data.identity_power_ids:
			assert_not_null(IdentityPowers.create(power_id),
				"%s 的身份能力「%s」无法创建" % [enemy_id, power_id])

		for phase: EnemyPhase in data.phases:
			for power_id: StringName in phase.identity_power_ids:
				assert_not_null(IdentityPowers.create(power_id),
					"%s 的形态「%s」引用了无法创建的能力「%s」" % [
						enemy_id, phase.display_name, power_id])


func test_poisoner_exists_in_act_one() -> void:
	## 设计文档硬要求：**必须存在一个克制壁垒的敌人**。
	## 毒无视格挡，是「格挡滚雪球」打法的天敌。
	var data: EnemyData = ContentRegistry.get_enemy(&"act1_poisoner")
	assert_not_null(data)

	var has_poison: bool = false
	for intent: IntentData in data.intents:
		if intent.power_id == &"poison":
			has_poison = true
	assert_true(has_poison, "毒刃客必须有施加中毒的意图")


func test_each_act_has_a_boss() -> void:
	for act: int in [1, 2, 3]:
		var data: EnemyData = ContentRegistry.get_enemy(StringName("act%d_boss" % act))
		assert_not_null(data)
		assert_true(data.is_boss, "第 %d 幕 Boss 应标记 is_boss" % act)


# ══ Boss 双姿态 ═════════════════════════════════════════════

func test_act1_boss_has_a_second_phase() -> void:
	var data: EnemyData = ContentRegistry.get_enemy(&"act1_boss")
	assert_true(data.has_phases(), "卡冈应有形态序列")
	assert_eq(data.phase_count(), 2, "卡冈应有 2 个形态")


func test_boss_switches_phase_below_threshold() -> void:
	var e := _make_enemy(&"act1_boss")
	watch_signals(e)
	assert_eq(e.phase(), 0, "开场应是第一个形态（下标 0 起）")

	e.take_damage(e.max_hp / 2 + 1)

	assert_true(e.refresh_phase(), "血量低于阈值应切形态")
	assert_eq(e.phase(), 1)
	assert_signal_emitted(e, "phase_changed")


func test_boss_does_not_switch_above_threshold() -> void:
	var e := _make_enemy(&"act1_boss")
	e.take_damage(1)

	assert_false(e.refresh_phase(), "血量还高时不应切形态")
	assert_eq(e.phase(), 0)


func test_boss_phase_two_uses_its_own_intent_pattern() -> void:
	var e := _make_enemy(&"act1_boss")
	e.take_damage(40)  # 72 → 32，低于 50%
	e.refresh_phase()

	assert_eq(e.current_intent().times, 3, "第二姿态应是连打（8×3）")


func test_boss_phase_switch_is_idempotent() -> void:
	var e := _make_enemy(&"act1_boss")
	e.take_damage(40)
	e.refresh_phase()
	watch_signals(e)

	e.refresh_phase()

	assert_eq(e.phase(), 1)
	assert_signal_emit_count(e, "phase_changed", 0, "已经切过了不应重复触发")


func test_enemy_without_second_phase_never_switches() -> void:
	var e := _make_enemy(&"act1_combat")
	e.take_damage(e.max_hp - 1)

	assert_false(e.refresh_phase(), "没有形态序列的敌人不应切形态")
	assert_eq(e.phase(), 0)


# ══ 神战 P4 · 战神 ══════════════════════════════════════════

func test_god_of_war_keeps_all_its_block() -> void:
	## 壁垒保留一半，战神**一点都不放**——这是对称设计
	var c := _make_creature()
	c.apply_identity_power(IdentityPowers.create(&"god_of_war_stance"))
	c.gain_block(20)

	c.on_turn_start()

	assert_eq(c.block, 20, "战神格挡永不衰减")


func test_god_of_war_gains_strength_each_turn() -> void:
	var c := _make_creature()
	c.apply_identity_power(IdentityPowers.create(&"god_of_war_stance"))

	c.on_turn_start()
	c.on_turn_start()

	assert_eq(c.get_power_amount(&"strength"), 4, "每回合 +2 力量，两回合共 4")


func test_god_of_war_is_stronger_than_bastion() -> void:
	## 对照：同一场景下壁垒会衰减，战神不会
	var bastion := _make_creature()
	bastion.apply_identity_power(IdentityPowers.create(&"bastion_wall"))
	bastion.gain_block(20)

	var god := _make_creature()
	god.apply_identity_power(IdentityPowers.create(&"god_of_war_stance"))
	god.gain_block(20)

	bastion.on_turn_start()
	god.on_turn_start()

	assert_eq(bastion.block, 10, "壁垒保留一半")
	assert_eq(god.block, 20, "战神全保留")
	assert_gt(god.block, bastion.block)


func test_act3_boss_phases_carry_the_god_powers() -> void:
	## 战神的身份能力挂在**形态**上：P1 什么都不给，越往后越凶。
	## 这是 P6-05「四阶段」的核心——机制**逐步**亮出来，而不是开场全给。
	var data: EnemyData = ContentRegistry.get_enemy(&"act3_boss")

	var war_stance_phase: int = -1
	var endless_phase: int = -1
	for i: int in data.phases.size():
		if data.phases[i].identity_power_ids.has(&"god_of_war_stance"):
			war_stance_phase = i
		if data.phases[i].identity_power_ids.has(&"endless_will"):
			endless_phase = i

	assert_gt(war_stance_phase, 0, "战神姿态不该在第一形态就给")
	assert_gt(endless_phase, 0, "无尽战意不该在第一形态就给")
	assert_gt(war_stance_phase, endless_phase,
		"越强的能力应该越靠后（战神姿态在无尽战意之后）")


func test_first_phase_grants_no_identity_power() -> void:
	## 开场就把所有机制摊开，等于没有阶段
	var data: EnemyData = ContentRegistry.get_enemy(&"act3_boss")
	assert_eq(data.phases[0].identity_power_ids.size(), 0,
		"第一形态不该直接给身份能力")


func test_god_war_stance_is_reachable_through_phases() -> void:
	var e := _make_enemy(&"act3_boss")
	e.take_damage(e.max_hp * 3 / 4 + 1)

	assert_true(e.refresh_phase(), "血量掉到 25% 以下应进入最后的形态")
	assert_true(e.has_power(&"god_of_war_stance"),
		"进入最后形态后应带上战神姿态")
	assert_eq(e.identity_powers.size(), data.identity_power_ids.size())


func test_poison_is_the_answer_to_the_god() -> void:
	## 这是玩家打赢神战 P4 的**唯一**路径：
	## 战神的格挡永不衰减，硬拼打不穿，只能用毒绕过格挡。
	## 这条测试同时锁住了「壁垒的弱点」与「神战的解法」是同一个机制。
	var e := _make_enemy(&"act3_boss")
	# 战神姿态现在挂在最后形态上，这里手动装上（测的是机制，不是阶段推进）
	e.apply_identity_power(IdentityPowers.create(&"god_of_war_stance"))
	e.gain_block(50)
	e.apply_power(BasePowers.Poison.new(10))

	e.on_turn_start()

	assert_eq(e.hp, e.max_hp - 10, "毒应无视 50 点格挡直接扣血")
	assert_eq(e.block, 50, "格挡一点都不衰减")


# ══ 端到端：敌人的减益意图真的落到玩家身上 ═══════════════════

func test_poisoner_applies_poison_to_the_player() -> void:
	var player := Player.new()
	player.max_hp = 60
	player.reset_for_battle()
	autofree(player)

	var enemy := _make_enemy(&"act1_poisoner")
	var enemies: Array[Enemy] = [enemy]
	var deck: Array[CardData] = [CardData.make_skill(&"defend", "防御", 1, 5)]

	var bm := BattleManager.new()
	autofree(bm)
	bm.start_battle(player, enemies, deck, _seeded_rng(3))

	bm.end_player_turn()  # 敌人第 1 手：攻击 5
	bm.end_player_turn()  # 敌人第 2 手：下毒 3；随后玩家回合开始，毒结算一次

	assert_eq(player.hp, 60 - 5 - 3, "应吃到 1 次攻击 + 1 次毒伤")
	assert_eq(player.get_power_amount(&"poison"), 2, "毒层数应递减 1")
