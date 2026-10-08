extends GutTest
## 阶段 4 垂直切片测试：职业树 / 身份能力 / 遗物
##
## 这是**全项目最重要的一组业务测试**——它验证「壁垒这条线」是否真的能成立。
## 其中 `test_bastion_*` 系列是 decisions.md D10（Q1 定案）的守门人。

func before_all() -> void:
	ContentRegistry.load_all()


func _make_creature(hp: int = 60) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


func _with_identity(c: Creature, power_id: StringName) -> Creature:
	var power := IdentityPowers.create(power_id)
	assert_not_null(power, "身份能力 %s 应能创建" % power_id)
	c.apply_identity_power(power)
	return c


# ══ 职业树 ══════════════════════════════════════════════════

func test_all_warrior_jobs_are_registered() -> void:
	var expected: Array[StringName] = [
		&"warrior_shield_guard", &"warrior_berserker",
		&"warrior_bastion", &"warrior_shield_bash",
		&"warrior_bloodthirster", &"warrior_momentum",
	]
	for job_id: StringName in expected:
		assert_not_null(JobDatabase.get_job(job_id), "应注册职业 %s" % job_id)


func test_warrior_has_two_first_tier_jobs() -> void:
	assert_eq(JobDatabase.first_tier_jobs(&"warrior").size(), 2)


func test_shield_guard_line_has_two_final_jobs() -> void:
	var finals: Array[JobData] = JobDatabase.final_jobs(&"warrior_shield_guard")
	assert_eq(finals.size(), 2, "盾卫线应有 2 个终职（壁垒 / 盾猛）")


func test_berserker_line_has_two_final_jobs() -> void:
	var finals: Array[JobData] = JobDatabase.final_jobs(&"warrior_berserker")
	assert_eq(finals.size(), 2, "狂战线应有 2 个终职")


func test_every_identity_power_id_resolves() -> void:
	## 数据里写的 id 必须都能被 create() 解析。
	## 否则玩家转职后会得到一个「什么都没发生」的职业——最难查的一类 bug。
	for job: JobData in JobDatabase.all_jobs():
		for power_id: StringName in job.identity_power_ids:
			assert_not_null(IdentityPowers.create(power_id),
				"职业 %s 的身份能力「%s」无法创建" % [job.id, power_id])


func test_every_job_card_id_resolves() -> void:
	for job: JobData in JobDatabase.all_jobs():
		for card_id: StringName in job.job_card_ids:
			assert_not_null(ContentRegistry.get_card(card_id),
				"职业 %s 的职业牌「%s」不存在" % [job.id, card_id])


func test_final_jobs_point_back_at_a_valid_parent() -> void:
	for job: JobData in JobDatabase.all_jobs():
		if job.tier == 1:
			continue
		assert_not_null(JobDatabase.get_job(job.parent_job),
			"终职 %s 的上级职业「%s」不存在" % [job.id, job.parent_job])


# ══ 一阶 · 盾卫 ═════════════════════════════════════════════

func test_shield_guard_bonus_applies_to_first_block_only() -> void:
	var c := _with_identity(_make_creature(), &"shield_guard_stance")

	var first: int = c.gain_block(5)
	var second: int = c.gain_block(5)

	assert_eq(first, 8, "本回合第一张格挡应 +3")
	assert_eq(second, 5, "第二张不应再加成")


func test_shield_guard_bonus_resets_each_turn() -> void:
	var c := _with_identity(_make_creature(), &"shield_guard_stance")

	c.gain_block(5)
	c.on_turn_start()
	var next_turn: int = c.gain_block(5)

	assert_eq(next_turn, 8, "新回合的第一张格挡应重新获得加成")


# ══ 终职 · 壁垒（D10 / Q1 定案的守门人）═════════════════════

func test_bastion_keeps_half_of_the_block_that_would_be_cleared() -> void:
	var c := _with_identity(_make_creature(), &"bastion_wall")
	c.gain_block(5)

	c.on_turn_start()

	assert_eq(c.block, 2, "5 点格挡应保留 floor(5/2)=2、清掉 3")


func test_bastion_rounds_down() -> void:
	var c := _with_identity(_make_creature(), &"bastion_wall")
	c.gain_block(1)

	c.on_turn_start()

	assert_eq(c.block, 0, "1 点格挡保留 floor(1/2)=0，即全部清掉")


func test_bastion_keeps_zero_when_there_is_no_block() -> void:
	var c := _with_identity(_make_creature(), &"bastion_wall")

	c.on_turn_start()

	assert_eq(c.block, 0, "没有格挡时保留 0")


func test_bastion_block_accumulates_across_turns() -> void:
	## 壁垒的真实玩法：格挡滚雪球。每回合只清一半，所以会持续累积。
	var c := _with_identity(_make_creature(), &"bastion_wall")

	c.gain_block(8)
	c.on_turn_start()
	assert_eq(c.block, 4, "8 → 保留 4")

	c.gain_block(8)
	assert_eq(c.block, 12, "4 + 8 = 12")

	c.on_turn_start()
	assert_eq(c.block, 6, "12 → 保留 6")


func test_without_bastion_block_clears_completely() -> void:
	var c := _make_creature()
	c.gain_block(5)

	c.on_turn_start()

	assert_eq(c.block, 0, "没有壁垒时格挡应全清（对照组）")


func test_bastion_does_not_protect_against_poison() -> void:
	## 设计文档 §3.1：**毒与生命流失无视格挡**——这是壁垒必须存在的弱点。
	## 如果这条测试红了，说明壁垒变成了无解职业。
	var c := _with_identity(_make_creature(30), &"bastion_wall")
	c.gain_block(20)
	c.apply_power(BasePowers.Poison.new(5))

	c.on_turn_start()

	assert_eq(c.hp, 25, "毒应无视 20 点格挡直接扣血")
	assert_eq(c.block, 10, "格挡保留一半（20 → 10），但完全挡不住毒")


# ══ 终职 · 盾猛 ═════════════════════════════════════════════

func _make_bash_setup() -> Array:
	var player := _make_creature(60)
	var enemy := _make_creature(60)
	player.opponents = [enemy]
	_with_identity(player, &"shield_bash")
	return [player, enemy]


func test_shield_bash_deals_half_of_gained_block_as_damage() -> void:
	var setup: Array = _make_bash_setup()
	var player: Creature = setup[0]
	var enemy: Creature = setup[1]

	player.gain_block(10)

	assert_eq(enemy.hp, 55, "10 点格挡应造成 5 点伤害")


func test_shield_bash_triggers_per_gain_not_per_turn() -> void:
	## 触发粒度：每次 gain_block 触发一次（设计文档 §3.1）。
	## 这条决定了「高频小盾」是不是有效构筑——如果按回合只触发一次，整个玩法就变了。
	var setup: Array = _make_bash_setup()
	var player: Creature = setup[0]
	var enemy: Creature = setup[1]

	player.gain_block(4)
	player.gain_block(4)

	assert_eq(enemy.hp, 60 - 4, "两次各 4 格挡应各触发一次（2 + 2）")


func test_shield_bash_damage_scales_with_strength() -> void:
	## 决策 2（方案 A）：盾猛伤害是 NORMAL，**吃力量 / 易伤**
	var setup: Array = _make_bash_setup()
	var player: Creature = setup[0]
	var enemy: Creature = setup[1]
	player.apply_power(BasePowers.Strength.new(2))

	player.gain_block(10)

	# floor(10 × 0.5) = 5，再吃 2 点力量 → 7
	assert_eq(enemy.hp, 60 - 7, "盾猛伤害应吃力量加成")


func test_shield_bash_scales_with_vulnerable_on_target() -> void:
	var setup: Array = _make_bash_setup()
	var player: Creature = setup[0]
	var enemy: Creature = setup[1]
	enemy.apply_power(BasePowers.Vulnerable.new(2))

	player.gain_block(10)

	# 5 × 1.5 = 7.5 → floor 7
	assert_eq(enemy.hp, 60 - 7, "盾猛伤害应吃目标易伤")


func test_shield_bash_ignores_dead_opponents() -> void:
	var setup: Array = _make_bash_setup()
	var player: Creature = setup[0]
	var enemy: Creature = setup[1]
	enemy.take_damage(999)
	var before: int = enemy.hp

	player.gain_block(10)

	assert_eq(enemy.hp, before, "已死亡的敌人不应再被反伤")


# ══ 终职 · 嗜血者 / 鏖战者 ═══════════════════════════════════

func test_bloodthirster_gains_rage_on_hp_loss() -> void:
	## 阶段 9：失血给的是**怒气**（独立资源）而不是力量。
	## 效果数值相同，但面板上显示的名字不同——这是"机制特色"的一部分：
	## 狂战玩家经营的是"怒气"，不是通用的"力量"。
	var c := _with_identity(_make_creature(60), &"bloodthirster")

	c.take_damage(4, null, DamageType.HP_LOSS)

	assert_eq(c.get_power_amount(&"rage"), 4, "每失 1 血应得 1 层怒气")


func test_bloodthirster_heals_on_kill() -> void:
	var c := _with_identity(_make_creature(60), &"bloodthirster")
	c.take_damage(20, null, DamageType.HP_LOSS)

	c.notify_kill(_make_creature())

	assert_eq(c.hp, 46, "击杀应回复 6 点生命（40 + 6）")


func test_momentum_grants_stack_per_attack_card() -> void:
	var c := _with_identity(_make_creature(), &"momentum_strike")

	c.notify_card_played(CardData.make_attack(&"strike", "打击", 1, 6))
	c.notify_card_played(CardData.make_attack(&"strike", "打击", 1, 6))

	assert_eq(c.get_power_amount(&"momentum_stack"), 2, "两张攻击牌应给 2 层怒涛")


func test_momentum_ignores_skill_cards() -> void:
	var c := _with_identity(_make_creature(), &"momentum_strike")

	c.notify_card_played(CardData.make_skill(&"defend", "防御", 1, 5))

	assert_eq(c.get_power_amount(&"momentum_stack"), 0, "技能牌不应给怒涛")


func test_momentum_stack_clears_at_turn_end() -> void:
	var c := _with_identity(_make_creature(), &"momentum_strike")
	c.notify_card_played(CardData.make_attack(&"strike", "打击", 1, 6))

	c.on_turn_end()

	assert_eq(c.get_power_amount(&"momentum_stack"), 0, "怒涛回合结束必定清零")


# ══ 遗物 ════════════════════════════════════════════════════

func test_burning_blood_is_registered() -> void:
	assert_not_null(ContentRegistry.get_relic(&"burning_blood"))
	assert_not_null(RelicFactory.create(&"burning_blood"))


func test_burning_blood_heals_on_victory() -> void:
	var c := _make_creature(30)
	c.take_damage(10)
	c.add_relic(RelicFactory.create(&"burning_blood"))

	c.notify_battle_end(true)

	assert_eq(c.hp, 25, "胜利后应回复 5 点生命")


func test_burning_blood_does_not_heal_on_defeat() -> void:
	var c := _make_creature(30)
	c.take_damage(10)
	c.add_relic(RelicFactory.create(&"burning_blood"))

	c.notify_battle_end(false)

	assert_eq(c.hp, 20, "战败不应回血")


func test_relics_survive_battle_reset() -> void:
	## 遗物是**整局持续**的，不能被战斗重置清掉
	var c := _make_creature()
	c.add_relic(RelicFactory.create(&"burning_blood"))

	c.reset_for_battle()

	assert_true(c.has_relic(&"burning_blood"), "遗物不该被 reset_for_battle 清掉")


func test_duplicate_relic_is_ignored() -> void:
	var c := _make_creature()
	c.add_relic(RelicFactory.create(&"burning_blood"))
	c.add_relic(RelicFactory.create(&"burning_blood"))

	assert_eq(c.relics.size(), 1, "重复添加应被忽略")


func test_unknown_relic_returns_null() -> void:
	assert_null(RelicFactory.create(&"not_a_relic"))


# ══ 集成：身份能力进修正链 + 不可剥夺 ═══════════════════════

func test_identity_power_from_job_participates_in_pipeline() -> void:
	var job: JobData = JobDatabase.get_job(&"warrior_bastion")
	assert_not_null(job)

	var c := _make_creature()
	for power_id: StringName in job.identity_power_ids:
		c.apply_identity_power(IdentityPowers.create(power_id))

	var target := _make_creature()
	assert_eq(DamagePipeline.calculate(c, target, 6).output, 6,
		"壁垒本身不改伤害（它改的是格挡规则）")
	assert_true(c.has_power(&"bastion_wall"), "身份能力应可用")


func test_identity_power_cannot_be_removed_after_job_transfer() -> void:
	## 转职得到的规则「任何方式不可剥夺」——沉默 / 驱散 / 夺能都走 remove_power
	var c := _make_creature()
	_with_identity(c, &"bastion_wall")

	c.remove_power(&"bastion_wall")

	assert_true(c.has_power(&"bastion_wall"), "转职能力不应被移除")
	assert_eq(c.identity_powers.size(), 1)
