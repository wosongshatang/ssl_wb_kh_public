extends GutTest
## 伤害管线测试 —— **全项目最该守住的三个测试之一**（工程书 §5.2）
##
## 修正链顺序一旦错，12 个终职的数值全错，而且错得很隐蔽（往往只是差 1 点）。
## 所以这里对**每一环**单独断言，并对「加法先于乘法」「取整只做一次」这类易错点
## 用**能区分对错两种实现的数字**验证——而不是随便挑个数字看着对就行。
##
## 每个顺序测试的注释里都写明了「错误实现会得到几」，这样测试失败时
## 一眼就能看出是顺序问题，而不是去猜。


## 用于验证事件钩子确实被分发（内部类声明必须在文件顶部，供下方测试引用）
class _HookRecorder extends AbstractPower:
	var card_played_count: int = 0
	var kill_count: int = 0

	func _init() -> void:
		id = &"hook_recorder"
		display_name = "钩子记录器"

	func on_card_played(_owner: Creature, _card: CardData) -> void:
		card_played_count += 1

	func on_kill(_owner: Creature, _target: Creature) -> void:
		kill_count += 1


const BASE: int = 6


# ── 构造辅助 ────────────────────────────────────────────────

func _make_creature(hp: int = 50) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


func _with_strength(c: Creature, amount: int) -> Creature:
	c.apply_power(BasePowers.Strength.new(amount))
	return c


func _with_weak(c: Creature, turns: int) -> Creature:
	c.apply_power(BasePowers.Weak.new(turns))
	return c


func _with_vulnerable(c: Creature, turns: int) -> Creature:
	c.apply_power(BasePowers.Vulnerable.new(turns))
	return c


func _with_dexterity(c: Creature, amount: int) -> Creature:
	c.apply_power(BasePowers.Dexterity.new(amount))
	return c


# ══ 单环修正 ════════════════════════════════════════════════

func test_no_modifiers_passes_base_through() -> void:
	var attacker := _make_creature()
	var target := _make_creature()
	var info: DamageInfo = DamagePipeline.calculate(attacker, target, BASE)

	assert_eq(info.output, BASE, "无修正时面板伤害等于基础值")
	assert_false(info.is_modified(), "无修正时不应标记为已修改")


func test_strength_is_additive() -> void:
	var attacker := _with_strength(_make_creature(), 3)
	var target := _make_creature()

	assert_eq(DamagePipeline.calculate(attacker, target, BASE).output, 9, "力量 3 应使 6 变 9")


func test_weak_multiplies_by_0_75() -> void:
	var attacker := _with_weak(_make_creature(), 2)
	var target := _make_creature()

	# 6 × 0.75 = 4.5 → floor → 4
	assert_eq(DamagePipeline.calculate(attacker, target, BASE).output, 4, "虚弱应使 6 变 4")


func test_vulnerable_multiplies_by_1_5() -> void:
	var attacker := _make_creature()
	var target := _with_vulnerable(_make_creature(), 2)

	# 6 × 1.5 = 9
	assert_eq(DamagePipeline.calculate(attacker, target, BASE).output, 9, "易伤应使 6 变 9")


# ══ 顺序：加法必须先于乘法 ══════════════════════════════════

func test_strength_applies_before_weak() -> void:
	## 用**能区分对错两种实现**的数字：
	##   正确（先加后乘）：(6 + 3) × 0.75 = 6.75 → floor 6
	##   错误（先乘后加）：6 × 0.75 + 3 = 7.5   → floor 7
	## 若本测试失败，说明 priority 机制没生效、力量被虚弱乘掉了。
	var attacker := _with_strength(_make_creature(), 3)
	_with_weak(attacker, 2)
	var target := _make_creature()

	assert_eq(DamagePipeline.calculate(attacker, target, BASE).output, 6,
		"力量必须先进加法、虚弱后进乘法（顺序颠倒会得到 7）")


func test_strength_applies_before_vulnerable() -> void:
	## 正确：(6 + 2) × 1.5 = 12 ／ 错误：6 × 1.5 + 2 = 11
	var attacker := _with_strength(_make_creature(), 2)
	var target := _with_vulnerable(_make_creature(), 2)

	assert_eq(DamagePipeline.calculate(attacker, target, BASE).output, 12,
		"力量必须先进加法、易伤后进乘法（顺序颠倒会得到 11）")


func test_priority_orders_powers_ascending() -> void:
	var c := _make_creature()
	_with_weak(c, 1)       # priority 99
	_with_strength(c, 1)   # priority 0

	var sorted: Array[AbstractPower] = DamagePipeline.sorted_powers(c)
	assert_eq(sorted.size(), 2)
	assert_eq(sorted[0].id, &"strength", "priority 小的排前面")
	assert_eq(sorted[1].id, &"weak", "priority 大的排后面")


# ══ 取整：只在最终结果做一次 ════════════════════════════════

func test_floor_happens_only_once_at_the_end() -> void:
	## 正确（只在末尾取整）：(9 + 1) × 0.75 × 1.5 = 11.25 → floor 11
	## 错误（中途取整）：      floor(10 × 0.75) = 7 → 7 × 1.5 = 10.5 → 10
	## 差 1 点，且这种误差在复杂构筑下会累积成明显偏差。
	var attacker := _with_strength(_make_creature(), 1)
	_with_weak(attacker, 2)
	var target := _with_vulnerable(_make_creature(), 2)

	assert_eq(DamagePipeline.calculate(attacker, target, 9).output, 11,
		"取整只能做一次（中途取整会得到 10）")


func test_result_is_never_negative() -> void:
	var attacker := _with_weak(_make_creature(), 1)
	var target := _make_creature()

	# 1 × 0.75 = 0.75 → floor 0
	var info: DamageInfo = DamagePipeline.calculate(attacker, target, 1)
	assert_eq(info.output, 0, "取整后不应为负")
	assert_true(info.output >= 0, "面板伤害必须非负")


# ══ DamageType 分流 ═════════════════════════════════════════

func test_thorns_ignores_strength() -> void:
	var attacker := _with_strength(_make_creature(), 5)
	var target := _make_creature()

	assert_eq(
		DamagePipeline.calculate(attacker, target, 3, DamageType.THORNS).output, 3,
		"荆棘反伤不应吃力量"
	)


func test_thorns_ignores_vulnerable() -> void:
	var attacker := _make_creature()
	var target := _with_vulnerable(_make_creature(), 2)

	assert_eq(
		DamagePipeline.calculate(attacker, target, 3, DamageType.THORNS).output, 3,
		"荆棘反伤不应吃易伤"
	)


func test_hp_loss_ignores_block() -> void:
	var target := _make_creature(30)
	target.gain_block(10)
	var info: DamageInfo = target.take_damage(5, null, DamageType.HP_LOSS)

	assert_eq(info.blocked, 0, "生命流失不应被格挡吸收")
	assert_eq(target.block, 10, "格挡应原封不动")
	assert_eq(target.hp, 25, "应直接扣 5 点生命")


func test_hp_loss_ignores_strength() -> void:
	var attacker := _with_strength(_make_creature(), 10)
	var target := _make_creature(30)

	target.take_damage(5, attacker, DamageType.HP_LOSS)
	assert_eq(target.hp, 25, "生命流失不应吃力量加成")


func test_poison_ignores_block() -> void:
	var target := _make_creature(30)
	target.gain_block(10)
	var info: DamageInfo = target.take_damage(4, null, DamageType.POISON)

	assert_eq(info.blocked, 0, "毒不应被格挡吸收")
	assert_eq(target.hp, 26, "毒应直接扣血")


# ══ 格挡结算 ════════════════════════════════════════════════

func test_block_absorbs_normal_damage() -> void:
	var target := _make_creature(30)
	target.gain_block(10)
	var info: DamageInfo = target.take_damage(6)

	assert_eq(info.blocked, 6, "6 点伤害应被格挡全部吸收")
	assert_eq(info.hp_lost, 0, "不应掉血")
	assert_eq(target.block, 4, "格挡应剩 4")
	assert_eq(target.hp, 30, "生命不变")


func test_damage_overflows_after_block() -> void:
	var target := _make_creature(30)
	target.gain_block(4)
	var info: DamageInfo = target.take_damage(10)

	assert_eq(info.blocked, 4, "格挡应被全部打光")
	assert_eq(info.hp_lost, 6, "溢出 6 点应扣血")
	assert_eq(target.block, 0)
	assert_eq(target.hp, 24)


func test_dexterity_increases_block_gained() -> void:
	var c := _with_dexterity(_make_creature(), 2)

	var gained: int = c.gain_block(5)
	assert_eq(gained, 7, "敏捷 2 应使 5 点格挡变 7")
	assert_eq(c.block, 7)


func test_block_gained_signal_reports_actual_amount() -> void:
	## 盾猛依赖这一点：「每当你**实际获得**格挡」——必须是敏捷修正后的值
	var c := _with_dexterity(_make_creature(), 3)
	watch_signals(c)

	c.gain_block(5)
	assert_signal_emitted_with_parameters(c, "block_gained", [8])


# ══ 扣血前拦截（缓冲）═══════════════════════════════════════

func test_buffer_prevents_hp_loss_and_is_removed() -> void:
	var target := _make_creature(30)
	target.apply_power(BasePowers.Buffer.new(1))

	target.take_damage(6)

	assert_eq(target.hp, 30, "缓冲应完全挡下这次掉血")
	assert_false(target.has_power(&"buffer"), "缓冲用尽后应当场移除（不等回合钩子）")


func test_buffer_is_not_consumed_when_block_absorbs_everything() -> void:
	## 这是「prevent_hp_loss 必须放在格挡吸收之后」的直接验证。
	## 若钩子放在格挡之前，缓冲会被一次本就没掉血的攻击白白消耗掉。
	var target := _make_creature(30)
	target.gain_block(10)
	target.apply_power(BasePowers.Buffer.new(1))

	target.take_damage(6)

	assert_eq(target.hp, 30, "格挡已挡下全部伤害")
	assert_true(target.has_power(&"buffer"), "被格挡吃掉的攻击不应消耗缓冲")


# ══ 荆棘反伤 ════════════════════════════════════════════════
# 注意方向：伤害的 **target** 持有荆棘，受伤的是 **source**（攻击者）

func test_thorns_damages_attacker() -> void:
	var attacker := _make_creature(30)
	var victim := _make_creature(30)
	victim.apply_power(BasePowers.Thorns.new(3))

	victim.take_damage(6, attacker)   # attacker 打 victim

	assert_eq(victim.hp, 24, "被攻击者应吃到 6 点")
	assert_eq(attacker.hp, 27, "攻击者应吃到 3 点反伤")


func test_thorns_does_not_recurse_infinitely() -> void:
	## 双方都有荆棘时必须能正常结束——反伤本身是 THORNS 类型，不再触发反伤
	var a := _make_creature(30)
	var b := _make_creature(30)
	a.apply_power(BasePowers.Thorns.new(3))
	b.apply_power(BasePowers.Thorns.new(3))

	b.take_damage(6, a)   # a 打 b

	assert_eq(b.hp, 24, "b 吃到 6 点")
	assert_eq(a.hp, 27, "a 吃到 b 的反伤；且不应再反弹回 b")


func test_thorns_triggers_even_when_attack_is_fully_blocked() -> void:
	var attacker := _make_creature(30)
	var victim := _make_creature(30)
	victim.gain_block(20)
	victim.apply_power(BasePowers.Thorns.new(3))

	victim.take_damage(6, attacker)

	assert_eq(victim.hp, 30, "格挡应挡下全部伤害")
	assert_eq(victim.block, 14, "格挡应剩 14")
	assert_eq(attacker.hp, 27, "被完全格挡的攻击同样应触发荆棘")


# ══ 中毒 ════════════════════════════════════════════════════

func test_poison_ticks_on_turn_start_and_decays() -> void:
	var c := _make_creature(30)
	c.apply_power(BasePowers.Poison.new(3))

	c.on_turn_start()

	assert_eq(c.hp, 27, "回合开始应扣 3 点")
	assert_eq(c.get_power_amount(&"poison"), 2, "层数应递减 1")


func test_poison_is_removed_at_zero() -> void:
	var c := _make_creature(30)
	c.apply_power(BasePowers.Poison.new(1))

	c.on_turn_start()

	assert_false(c.has_power(&"poison"), "层数归零后应被移除")


# ══ 回合倒计时 ══════════════════════════════════════════════

func test_weak_and_vulnerable_decay_on_turn_end() -> void:
	var c := _make_creature()
	c.apply_power(BasePowers.Weak.new(2))
	c.apply_power(BasePowers.Vulnerable.new(2))

	c.on_turn_end()

	assert_eq(c.get_power_amount(&"weak"), 1)
	assert_eq(c.get_power_amount(&"vulnerable"), 1)


func test_permanent_powers_do_not_decay() -> void:
	var c := _make_creature()
	c.apply_power(BasePowers.Strength.new(3))

	c.on_turn_end()
	c.on_turn_end()

	assert_eq(c.get_power_amount(&"strength"), 3, "力量是永久型，不应递减")


# ══ 叠加与钩子分发 ══════════════════════════════════════════

func test_same_power_stacks_instead_of_duplicating() -> void:
	var c := _make_creature()
	c.apply_power(BasePowers.Strength.new(2))
	c.apply_power(BasePowers.Strength.new(3))

	assert_eq(c.powers.size(), 1, "同 id 应叠加而非新增")
	assert_eq(c.get_power_amount(&"strength"), 5)


func test_kill_and_card_played_hooks_are_dispatched() -> void:
	var c := _make_creature()
	var recorder := _HookRecorder.new()
	c.apply_power(recorder)

	c.notify_card_played(CardData.make_attack(&"strike", "打击", 1, 6))
	c.notify_kill(_make_creature())

	assert_eq(recorder.card_played_count, 1, "on_card_played 应被分发")
	assert_eq(recorder.kill_count, 1, "on_kill 应被分发")
