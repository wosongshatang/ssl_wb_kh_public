extends GutTest
## 身份层（不可剥夺）测试 —— **全项目最该守住的三个测试之一**（工程书 §5.2）
##
## 「不可剥夺」是架构级承诺，不是规则级约定。它必须由**数据结构隔离**保证，
## 而不是靠每个战斗内效果「记得别动身份能力」。所以这里的测试全部针对
## **隔离机制本身**，而不是某个具体终职。
##
## 这些测试一旦变红，说明有人把身份层和常规 Power 混在一起了——
## 那会导致沉默 / 驱散 / 夺能能够剥掉玩家的终职能力，直接违背设计承诺。


## 假身份能力：加法修正（验证身份层确实进修正链）
class FakeIdentityStrength extends AbstractPower:
	func _init() -> void:
		id = &"fake_identity_strength"
		display_name = "假身份力量"
		amount = 4

	func at_damage_give(value: float, _info: DamageInfo) -> float:
		return value + float(amount)


## 假壁垒：保留「本该清零格挡」的一半，向下取整（D10 / Q1 定案的能力）
class FakeBastion extends AbstractPower:
	func _init() -> void:
		id = &"fake_bastion"
		display_name = "假壁垒"
		description = "回合开始时保留本该清零格挡的一半。"

	func at_block_clear(clearing: int, _owner: Creature) -> int:
		# 返回**实际清零的量**：总数 - 保留数
		return clearing - int(floor(float(clearing) / 2.0))


## 假衰减型：故意声明 is_turn_based，验证注入身份层时会被强制关掉
class FakeDecaying extends AbstractPower:
	func _init() -> void:
		id = &"fake_decaying"
		display_name = "假衰减"
		amount = 1
		is_turn_based = true


func _make_creature(hp: int = 50) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


# ══ 数据结构隔离 ════════════════════════════════════════════

func test_identity_power_goes_into_its_own_array() -> void:
	var c := _make_creature()
	c.apply_identity_power(FakeIdentityStrength.new())

	assert_eq(c.identity_powers.size(), 1, "应进身份层数组")
	assert_eq(c.powers.size(), 0, "不应混进常规 Power 数组")
	assert_true(c.identity_powers[0].is_identity, "应被标记为身份能力")


func test_all_powers_merges_both_layers() -> void:
	var c := _make_creature()
	c.apply_power(BasePowers.Strength.new(1))
	c.apply_identity_power(FakeIdentityStrength.new())

	assert_eq(c.all_powers().size(), 2, "all_powers 应合并两层")
	assert_eq(c.powers.size(), 1)
	assert_eq(c.identity_powers.size(), 1)


# ══ 核心承诺：remove_power 对身份层无效 ═════════════════════

func test_remove_power_cannot_touch_identity_layer() -> void:
	## 沉默 / 驱散 / 夺能全都走 remove_power，所以这一条守住了，
	## 「任何方式不可剥夺」就守住了。
	var c := _make_creature()
	c.apply_identity_power(FakeIdentityStrength.new())

	var removed: bool = c.remove_power(&"fake_identity_strength")

	assert_false(removed, "remove_power 对身份能力应返回 false")
	assert_true(c.has_power(&"fake_identity_strength"), "身份能力必须仍然存在")
	assert_eq(c.identity_powers.size(), 1, "身份层数组不应被改动")


func test_remove_power_still_works_on_regular_powers() -> void:
	## 对照组：证明 remove_power 本身没坏，只是碰不到身份层
	var c := _make_creature()
	c.apply_power(BasePowers.Strength.new(2))

	assert_true(c.remove_power(&"strength"), "常规 Power 应能被移除")
	assert_false(c.has_power(&"strength"))


func test_remove_power_cannot_remove_identity_even_when_regular_power_shares_id() -> void:
	var c := _make_creature()
	c.apply_identity_power(FakeIdentityStrength.new())
	# 同名常规 Power 无法注入（apply_power 会走叠加分支），这里直接构造冲突场景
	c.powers.append(FakeIdentityStrength.new())

	var removed: bool = c.remove_power(&"fake_identity_strength")

	assert_true(removed, "常规数组里的那条应被移除")
	assert_eq(c.identity_powers.size(), 1, "身份层那条必须还在")


# ══ 核心承诺：reset 不清身份层 ══════════════════════════════

func test_reset_for_battle_keeps_identity_layer() -> void:
	var c := _make_creature()
	c.apply_identity_power(FakeIdentityStrength.new())
	c.apply_power(BasePowers.Strength.new(2))

	c.reset_for_battle()

	assert_eq(c.powers.size(), 0, "常规 Power 应被清空")
	assert_eq(c.identity_powers.size(), 1, "身份层不应被 reset 清空")


# ══ 核心承诺：不倒计时 ══════════════════════════════════════

func test_identity_power_is_forced_non_turn_based() -> void:
	var c := _make_creature()
	var power := FakeDecaying.new()
	assert_true(power.is_turn_based, "注入前它自己声明是衰减型")

	c.apply_identity_power(power)

	assert_false(power.is_turn_based, "注入身份层时必须强制关闭倒计时")


func test_identity_power_never_expires_across_turns() -> void:
	var c := _make_creature()
	c.apply_identity_power(FakeDecaying.new())

	c.on_turn_end()
	c.on_turn_end()
	c.on_turn_start()

	assert_true(c.has_power(&"fake_decaying"), "身份能力不应随回合消失")


# ══ 核心承诺：身份能力必须进修正链 ══════════════════════════

func test_identity_power_participates_in_damage_pipeline() -> void:
	## 若 DamagePipeline.sorted_powers 漏掉 identity_powers，
	## 壁垒、盾猛、神射手等**所有**终职能力都会静默失效——数值看着对，但能力没了。
	var attacker := _make_creature()
	attacker.apply_identity_power(FakeIdentityStrength.new())
	var target := _make_creature()

	assert_eq(DamagePipeline.calculate(attacker, target, 6).output, 10,
		"身份能力必须并入伤害修正链")


func test_sorted_powers_includes_identity_layer() -> void:
	var c := _make_creature()
	c.apply_power(BasePowers.Strength.new(1))
	c.apply_identity_power(FakeIdentityStrength.new())

	var sorted: Array[AbstractPower] = DamagePipeline.sorted_powers(c)
	assert_eq(sorted.size(), 2, "sorted_powers 应包含身份层")


# ══ 身份能力改写基础规则（壁垒的能力原型）═══════════════════

func test_identity_power_can_rewrite_block_clear_rule() -> void:
	## 这是 D10 / Q1 定案的直接验证：格挡在自身回合开始时清零，
	## 壁垒把「本该清零的那部分」保留一半（向下取整）。
	var c := _make_creature()
	c.apply_identity_power(FakeBastion.new())
	c.gain_block(5)

	c.on_turn_start()

	assert_eq(c.block, 2, "5 点格挡应保留 2（floor(5/2)），清掉 3")


func test_block_clear_rewrite_rounds_down() -> void:
	var c := _make_creature()
	c.apply_identity_power(FakeBastion.new())
	c.gain_block(1)

	c.on_turn_start()

	assert_eq(c.block, 0, "1 点格挡保留 floor(1/2)=0，即全部清掉")


func test_block_clear_rewrite_keeps_zero_when_no_block() -> void:
	var c := _make_creature()
	c.apply_identity_power(FakeBastion.new())

	c.on_turn_start()

	assert_eq(c.block, 0, "没有格挡时保留 0")


func test_without_identity_power_block_clears_completely() -> void:
	## 对照组：没有壁垒时格挡应被清光
	var c := _make_creature()
	c.gain_block(5)

	c.on_turn_start()

	assert_eq(c.block, 0, "无身份能力时格挡应全清")


func test_block_clear_rewrite_works_across_multiple_turns() -> void:
	## 壁垒的真实玩法：格挡滚雪球。每回合只清一半，所以会持续累积。
	var c := _make_creature()
	c.apply_identity_power(FakeBastion.new())

	c.gain_block(8)
	c.on_turn_start()
	assert_eq(c.block, 4, "8 → 保留 4")

	c.gain_block(8)
	assert_eq(c.block, 12, "4 + 8 = 12")
	c.on_turn_start()
	assert_eq(c.block, 6, "12 → 保留 6")


# ══ 跨战斗重新注入 ══════════════════════════════════════════

func test_identity_powers_can_be_reinjected_for_next_battle() -> void:
	## 身份能力的「源头」挂在 GameState 的 JobData 上。
	## 每场战斗初始化时：清空 → 从 JobData 重新实例化注入。
	## 这不是「剥夺」——源头自始至终没有被战斗内的任何效果触碰过。
	var c := _make_creature()
	c.apply_identity_power(FakeIdentityStrength.new())

	c.clear_identity_powers()
	assert_eq(c.identity_powers.size(), 0, "源头重建时允许清空")

	c.reset_for_battle()
	c.apply_identity_power(FakeIdentityStrength.new())

	assert_true(c.has_power(&"fake_identity_strength"), "重新注入后应可用")
	assert_eq(c.identity_powers.size(), 1, "不应重复累积")


func test_duplicate_identity_injection_is_ignored() -> void:
	var c := _make_creature()
	c.apply_identity_power(FakeIdentityStrength.new())
	c.apply_identity_power(FakeIdentityStrength.new())

	assert_eq(c.identity_powers.size(), 1, "重复注入应被忽略，不应累积")


# ══ 身份能力与常规 Power 协同 ═══════════════════════════════

func test_identity_and_regular_powers_stack_in_pipeline() -> void:
	var attacker := _make_creature()
	attacker.apply_identity_power(FakeIdentityStrength.new())   # +4
	attacker.apply_power(BasePowers.Strength.new(2))            # +2
	attacker.apply_power(BasePowers.Weak.new(1))                # ×0.75

	# (6 + 4 + 2) × 0.75 = 9
	var target := _make_creature()
	assert_eq(DamagePipeline.calculate(attacker, target, 6).output, 9,
		"身份层与常规层的修正应按 priority 统一排序后依次生效")
