extends GutTest
## 阶段 9 · 转职机制重做的核心机制测试
##
## ## 守的是什么
## 这一批把"每回合涨属性"换成了**资源型机制**（印记 / 元素 / 魂能 / 奥术 / 怒气 / 形态）。
## 资源型机制比数值型危险得多：它们有**上限**、有**消耗**、有**组合**，
## 每一处算错都会让机制从"有深度"退化成"无脑最优解"或"完全无效"——
## 而这两种退化**都不会报错**。
##
## 具体守四类：
##   1. **上限**（印记 10 / 奥术 10 / 霜减伤 3 / 魂能代付 2）
##   2. **封顶**（神射手引爆对 Boss 的封顶——没有它 Boss 战会被一发废掉）
##   3. **修正链顺序**（奥术 ×1.25 必须晚于力量 +1，否则数值偏差巨大且不报错）
##   4. **唯一入口**（元素反应必须走 ElementSystem，绕过就静默失效）

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
	var power: AbstractPower = IdentityPowers.create(power_id)
	assert_not_null(power, "身份能力 %s 造不出来" % power_id)
	c.apply_identity_power(power)
	return c


func _make_enemy(hp: int = 40, elite: bool = false, boss: bool = false) -> Enemy:
	var data := EnemyData.new()
	data.id = &"test_dummy"
	data.display_name = "木桩"
	data.max_hp = hp
	data.is_elite = elite
	data.is_boss = boss
	var e := Enemy.new()
	e.setup_from_data(data)
	autofree(e)
	return e


# ══ 印记：层数上限 + 乘法增伤 ═══════════════════════════════

func test_mark_caps_at_ten_stacks() -> void:
	## 上限必须在 `stack()` 里截断——在调用方截的话，
	## "已经 10 层了"这件事每个调用点都要判一次，迟早漏一处。
	var e := _make_enemy()
	e.apply_power(BasePowers.Mark.new(8))
	e.apply_power(BasePowers.Mark.new(8))

	assert_eq(e.get_power_amount(&"mark"), BasePowers.Mark.MAX_STACKS,
		"印记应被截断在 %d 层" % BasePowers.Mark.MAX_STACKS)


func test_mark_multiplies_damage_per_stack() -> void:
	var src := _make_creature()
	var dst := _make_enemy(100)

	var base: int = DamagePipeline.calculate(src, dst, 10).output
	dst.apply_power(BasePowers.Mark.new(5))
	var marked: int = DamagePipeline.calculate(src, dst, 10).output

	# 5 层 × 10% = ×1.5
	assert_eq(marked, int(floor(10.0 * 1.5)), "5 层印记应把 10 伤放大到 15")


func test_mark_does_not_decay() -> void:
	## 印记**不衰减**——这是"叠元素/叠印记"玩法的前提。
	## 会自己消失的层数攒不起来。
	var e := _make_enemy()
	e.apply_power(BasePowers.Mark.new(4))
	e.on_turn_end()

	assert_eq(e.get_power_amount(&"mark"), 4, "印记不该随回合衰减")


# ══ 元素：附着 / 反应 / 冻结 ════════════════════════════════

func test_single_element_stacks_without_reaction() -> void:
	var e := _make_enemy()
	ElementSystem.apply_element(e, &"burn", 2)
	ElementSystem.apply_element(e, &"burn", 3)

	assert_eq(e.get_power_amount(&"burn"), 5, "同种元素应叠加")
	assert_false(e.has_power(&"frost"))


func test_burn_deals_unblockable_damage_at_turn_end() -> void:
	## 燃 = 无视格挡（POISON 类型），与中毒同语义
	var e := _make_enemy(50)
	e.gain_block(20)
	e.apply_power(BasePowers.Burn.new(6))
	e.on_turn_end()

	assert_eq(e.hp, 50 - 6, "燃应无视格挡直接扣血")
	assert_eq(e.block, 20, "格挡不该被燃消耗")


func test_steam_reaction_consumes_half_of_each() -> void:
	## 燃 + 霜 = 蒸汽：造成「燃层 × 2」伤害，两份元素**各消耗一半**
	var e := _make_enemy(100)
	ElementSystem.apply_element(e, &"burn", 6)
	assert_eq(e.get_power_amount(&"burn"), 6)

	ElementSystem.apply_element(e, &"frost", 4)

	# 伤害 = 燃 6 × 2 = 12
	assert_eq(e.hp, 100 - 12, "蒸汽伤害应为燃层 × 2")
	# 各消耗一半（向下取整）：燃 6→3，霜 4→2
	assert_eq(e.get_power_amount(&"burn"), 3, "燃应消耗一半")
	assert_eq(e.get_power_amount(&"frost"), 2, "霜应消耗一半")


func test_frost_freezes_at_threshold() -> void:
	var e := _make_enemy()
	ElementSystem.apply_element(e, &"frost", BasePowers.Frost.FREEZE_THRESHOLD)

	assert_false(e.has_power(&"frost"), "满层后霜应被清空")
	assert_true(e.has_power(&"frozen"), "满层霜应转成冻结")


func test_frost_damage_reduction_is_capped() -> void:
	## 减伤上限是硬需求——无上限的减伤会让"叠霜"变成无敌
	var src := _make_creature()
	var dst := _make_enemy(100)
	dst.apply_power(BasePowers.Frost.new(99))

	var dmg: int = DamagePipeline.calculate(src, dst, 10).output
	assert_eq(dmg, 10 - BasePowers.Frost.MAX_REDUCE,
		"霜的减伤应封顶在 %d" % BasePowers.Frost.MAX_REDUCE)


func test_element_system_is_the_only_entry() -> void:
	## 反应判定必须收在唯一入口。这里验证"走入口"会触发反应。
	## （源码级守卫见 `test_no_direct_element_apply`）
	var e := _make_enemy(100)
	ElementSystem.apply_element(e, &"frost", 2)
	ElementSystem.apply_element(e, &"burn", 4)

	assert_eq(e.hp, 100 - 8, "霜后上燃也应触发蒸汽")


# ══ 神射手：引爆 + Boss 封顶 ════════════════════════════════

func test_marksman_detonates_at_full_stacks() -> void:
	var p := _with_identity(_make_creature(), &"marksman")
	var e := _make_enemy(100)
	e.hp = 40   # 已损 60
	e.apply_power(BasePowers.Mark.new(IdentityPowers.Marksman.THRESHOLD))
	p.opponents = [e]

	var attack := CardData.new()
	attack.type = CardData.CardType.ATTACK
	p.notify_card_played(attack)

	# 已损 60 × 40% = 24
	assert_eq(e.hp, 40 - 24, "满层引爆应造成已损生命的 40%")
	assert_false(e.has_power(&"mark"), "引爆后印记应清零")


func test_marksman_detonation_is_capped_for_boss() -> void:
	## ★ 没有这个封顶，"打残血 Boss 一发引爆"会直接秒杀，
	## 整场 Boss 战的设计就被一个机制废掉。
	var p := _with_identity(_make_creature(), &"marksman")
	# ⚠️ 血量要留够：`take_damage` 会把 hp 钳在 0，血量太少就分不出
	# "封顶生效"和"直接打死"——测试会以 0 == -10 的形式失败，指向性很差。
	var boss := _make_enemy(200, false, true)
	boss.hp = 100   # 已损 100 → 40% = 40，但封顶 = 200 × 15% = 30
	boss.apply_power(BasePowers.Mark.new(IdentityPowers.Marksman.THRESHOLD))
	p.opponents = [boss]

	var attack := CardData.new()
	attack.type = CardData.CardType.ATTACK
	p.notify_card_played(attack)

	assert_eq(boss.hp, 100 - 30, "Boss 的引爆伤害应封顶在最大生命的 15%")


func test_normal_enemy_is_not_capped() -> void:
	## 封顶只对精英 / Boss 生效——普通敌人用封顶会让引爆变成挠痒
	var p := _with_identity(_make_creature(), &"marksman")
	var e := _make_enemy(100)
	e.hp = 60   # 已损 40 → 40% = 16（若误加封顶则是 15）
	e.apply_power(BasePowers.Mark.new(IdentityPowers.Marksman.THRESHOLD))
	p.opponents = [e]

	var attack := CardData.new()
	attack.type = CardData.CardType.ATTACK
	p.notify_card_played(attack)

	assert_eq(e.hp, 60 - 16, "普通敌人不该吃 Boss 封顶")


# ══ 兽化者：形态切换 + 乘法顺序 ═════════════════════════════

func test_beast_shaper_starts_in_human_form() -> void:
	var p := _with_identity(_make_creature(), &"beast_shaper")
	p.notify_battle_start()
	var shaper: AbstractPower = p.get_power(&"beast_shaper")

	assert_eq((shaper as IdentityPowers.BeastShaper).form, IdentityPowers.BeastShaper.Form.HUMAN, "开场应是人形")


func test_beast_shaper_toggles_form() -> void:
	var p := _with_identity(_make_creature(), &"beast_shaper")
	var shaper := p.get_power(&"beast_shaper") as IdentityPowers.BeastShaper

	var msg: String = shaper.on_form_shift(p)
	assert_eq(shaper.form, IdentityPowers.BeastShaper.Form.BEAST, "切换后应是兽形")
	assert_ne(msg, "", "响应了切换就该返回一句描述（用于日志）")

	shaper.on_form_shift(p)
	assert_eq(shaper.form, IdentityPowers.BeastShaper.Form.HUMAN, "再切一次应回到人形")


func test_beast_form_multiplies_damage() -> void:
	var p := _with_identity(_make_creature(), &"beast_shaper")
	p.notify_battle_start()
	var e := _make_enemy(100)

	var human: int = DamagePipeline.calculate(p, e, 10).output

	var shaper := p.get_power(&"beast_shaper") as IdentityPowers.BeastShaper
	shaper.on_form_shift(p)
	var beast: int = DamagePipeline.calculate(p, e, 10).output

	assert_eq(human, 10, "人形不该有伤害加成")
	assert_eq(beast, 15, "兽形应 ×1.5")


func test_beast_form_multiplier_runs_after_strength() -> void:
	## ★★ 修正链顺序：**乘法必须在加法之后**。
	## 落在加法之前的话，(10 × 1.5) + 5 = 20；落在之后是 (10 + 5) × 1.5 = 22。
	## 两种结果都不会报错——只有测试能锁住。
	var p := _with_identity(_make_creature(), &"beast_shaper")
	p.notify_battle_start()
	p.apply_power(BasePowers.Strength.new(5))
	var e := _make_enemy(100)

	var shaper := p.get_power(&"beast_shaper") as IdentityPowers.BeastShaper
	shaper.on_form_shift(p)

	var dmg: int = DamagePipeline.calculate(p, e, 10).output
	assert_eq(dmg, int(floor((10.0 + 5.0) * 1.5)),
		"兽形倍率必须在力量之后（(10+5)×1.5=22，而不是 10×1.5+5=20）")


func test_form_shift_is_ignored_without_beast_shaper() -> void:
	## 没有兽化者的角色打出切换牌时，不该有任何能力响应
	## （否则玩家会以为自己切换了形态）
	# 挂一个真实但无关的能力——新建 Creature 没有任何 Power，
	# 循环体不执行的话 GUT 会判 Risky（"一条都没断言"）。
	var p := _with_identity(_make_creature(), &"bastion_wall")
	assert_gt(p.all_powers().size(), 0, "至少要有一个能力，否则这条测不出东西")
	for power: AbstractPower in p.all_powers():
		assert_eq(power.on_form_shift(p), "", "%s 不该响应形态切换" % power.id)


# ══ 死灵师：魂能 + 代付上限 ═════════════════════════════════

func test_necromancer_gains_soul_from_exhaust() -> void:
	var p := _with_identity(_make_creature(), &"necromancer")
	p.notify_battle_start()
	var card := CardData.new()

	p.notify_card_exhausted(card)
	p.notify_card_exhausted(card)

	var necro := p.get_power(&"necromancer") as IdentityPowers.Necromancer
	assert_eq(necro.soul, 2, "每消耗 1 张牌应 +1 魂能")


func test_necromancer_subsidy_is_capped_per_turn() -> void:
	## ★ 代付上限是硬需求——无上限会让高费牌变免费，直接摧毁能量曲线
	var p := _with_identity(_make_creature(), &"necromancer")
	p.notify_battle_start()
	var necro := p.get_power(&"necromancer") as IdentityPowers.Necromancer
	necro.soul = 10
	necro.on_turn_start(p)

	var card := CardData.new()
	assert_eq(necro.energy_subsidy_max(3, card), IdentityPowers.Necromancer.SUBSIDY_PER_TURN,
		"单次代付应封顶在 %d" % IdentityPowers.Necromancer.SUBSIDY_PER_TURN)

	necro.consume_energy_subsidy(IdentityPowers.Necromancer.SUBSIDY_PER_TURN)
	assert_eq(necro.energy_subsidy_max(3, card), 0, "用满后本回合不该再能代付")


func test_necromancer_subsidy_does_not_exceed_cost() -> void:
	var p := _with_identity(_make_creature(), &"necromancer")
	p.notify_battle_start()
	var necro := p.get_power(&"necromancer") as IdentityPowers.Necromancer
	necro.soul = 10

	assert_eq(necro.energy_subsidy_max(1, CardData.new()), 1,
		"代付不该超过这张牌本身的花费")


# ══ 奥术圣贤：蓄力 + 兑换限次 ═══════════════════════════════

func test_archsage_converts_unused_energy_to_arcane() -> void:
	var p := _with_identity(_make_creature(), &"archsage")
	p.notify_battle_start()
	p.energy = 3

	p.on_turn_end()

	assert_eq(p.get_power_amount(&"arcane"), 3 * IdentityPowers.Archsage.ARCANE_PER_ENERGY,
		"每点未用能量应转 %d 层奥术" % IdentityPowers.Archsage.ARCANE_PER_ENERGY)


func test_arcane_multiplies_damage() -> void:
	var p := _make_creature()
	var e := _make_enemy(100)
	p.apply_power(BasePowers.Arcane.new(4))   # 4 × 25% = ×2.0

	assert_eq(DamagePipeline.calculate(p, e, 10).output, 20, "4 层奥术应让 10 伤变 20")


func test_arcane_multiplier_runs_after_strength() -> void:
	## 与兽形同理：奥术 priority 100，必须晚于力量
	var p := _make_creature()
	var e := _make_enemy(100)
	p.apply_power(BasePowers.Strength.new(5))
	p.apply_power(BasePowers.Arcane.new(4))

	# (10 + 5) × 2.0 = 30
	assert_eq(DamagePipeline.calculate(p, e, 10).output, 30,
		"奥术必须在力量之后（(10+5)×2=30，而不是 10×2+5=25）")


func test_arcane_priority_is_after_strength() -> void:
	## ★ 直接断言 priority，而不是断言"算出来的数字"。
	##
	## 为什么不能只靠数字：两个 Power 的 priority 相同时，
	## 排序结果取决于插入顺序——测试可能**碰巧**算出正确值，
	## 于是"priority 被改坏"这件事测不出来。断言 priority 才是确定的。
	assert_gt(BasePowers.Arcane.new(1).priority, BasePowers.Strength.new(1).priority,
		"奥术（乘法）的 priority 必须大于力量（加法）")


func test_beast_form_priority_is_after_strength() -> void:
	assert_gt(IdentityPowers.BeastShaper.new().priority, BasePowers.Strength.new(1).priority,
		"兽形倍率（乘法）的 priority 必须大于力量（加法）")


func test_apply_powers_routes_elements() -> void:
	## ★ 源码级：`_apply_powers` 必须把元素改道 ElementSystem。
	##
	## 去掉这个改道**不会有任何行为测试失败**——它只会让
	## "用卡牌上燃"不触发反应，而"用元素亲和上燃"会。
	## 玩家看到的是"这张牌好像有点弱"，不会想到是路由问题。
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/battle_manager.gd")
	var idx: int = src.find("func _apply_powers")
	assert_gt(idx, -1, "找不到 _apply_powers")
	var body: String = src.substr(idx, 1200)
	assert_true(body.contains("ElementSystem.is_element"),
		"_apply_powers 必须把元素改道 ElementSystem，否则卡牌上的元素不触发反应")


func test_archsage_exchange_is_once_per_turn() -> void:
	var p := _with_identity(_make_creature(), &"archsage")
	p.notify_battle_start()
	var sage := p.get_power(&"archsage") as IdentityPowers.Archsage
	p.apply_power(BasePowers.Arcane.new(10))
	sage.on_turn_start(p)

	var card := CardData.new()
	assert_gt(sage.energy_subsidy_max(3, card), 0, "有 10 层奥术时应可兑换")

	sage.consume_energy_subsidy(IdentityPowers.Archsage.EXCHANGE_GAIN)
	assert_eq(sage.energy_subsidy_max(3, card), 0, "兑换后本回合不该再能换")


func test_archsage_exchange_needs_enough_arcane() -> void:
	var p := _with_identity(_make_creature(), &"archsage")
	p.notify_battle_start()
	var sage := p.get_power(&"archsage") as IdentityPowers.Archsage
	p.apply_power(BasePowers.Arcane.new(IdentityPowers.Archsage.EXCHANGE_COST - 1))

	assert_eq(sage.energy_subsidy_max(3, CardData.new()), 0,
		"奥术不足 %d 层时不该能兑换" % IdentityPowers.Archsage.EXCHANGE_COST)


# ══ 契约师：诅咒可打 ═══════════════════════════════════════

func test_contractor_allows_playing_curse_only() -> void:
	var p := _with_identity(_make_creature(), &"contractor")
	var contractor := p.get_power(&"contractor") as IdentityPowers.Contractor

	var curse := CardData.new()
	curse.rarity = CardData.Rarity.CURSE
	var normal := CardData.new()
	normal.rarity = CardData.Rarity.COMMON

	assert_true(contractor.allows_playing(curse), "契约师应放行诅咒牌")
	assert_false(contractor.allows_playing(normal),
		"契约师不该放行普通牌——否则「不可打出」这个机制就废了")


func test_contractor_overrides_curse_cost() -> void:
	var p := _with_identity(_make_creature(), &"contractor")
	var contractor := p.get_power(&"contractor") as IdentityPowers.Contractor

	var curse := CardData.new()
	curse.rarity = CardData.Rarity.CURSE
	curse.cost = 0

	assert_eq(contractor.modify_energy_cost(0, curse), IdentityPowers.Contractor.CURSE_COST,
		"诅咒牌的花费应由契约师接管")


func test_without_contractor_curse_stays_unplayable() -> void:
	var p := _with_identity(_make_creature(), &"bastion_wall")
	var curse := CardData.new()
	curse.rarity = CardData.Rarity.CURSE

	assert_gt(p.all_powers().size(), 0, "至少要有一个能力，否则这条测不出东西")
	for power: AbstractPower in p.all_powers():
		assert_false(power.allows_playing(curse),
			"%s 不该放行诅咒牌" % power.id)


# ══ 怒气：独立于力量 ═══════════════════════════════════════

func test_rage_is_a_separate_power_from_strength() -> void:
	## 效果一致但**是两层**——面板上写"怒气 5"和写"力量 5"对狂战玩家意义不同
	var c := _make_creature()
	c.apply_power(BasePowers.Rage.new(3))

	assert_eq(c.get_power_amount(&"rage"), 3)
	assert_eq(c.get_power_amount(&"strength"), 0, "怒气不该混进力量")


func test_rage_adds_damage() -> void:
	var src := _make_creature()
	var dst := _make_enemy(100)
	src.apply_power(BasePowers.Rage.new(4))

	assert_eq(DamagePipeline.calculate(src, dst, 10).output, 14, "4 层怒气应 +4 伤害")


# ══ 源码级守卫：元素必须走唯一入口 ═════════════════════════

func test_no_direct_element_apply() -> void:
	## ★★ 元素反应必须走 `ElementSystem.apply_element`。
	## 如果哪里直接 `apply_power(BasePowers.Burn.new(...))`，
	## 反应判定就被绕过——表现成"某些牌不触发蒸汽"，而且**不报错**。
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _all_scripts():
		var src: String = _strip_comments(FileAccess.get_file_as_string(path))
		if src.contains("Burn.new(") or src.contains("Frost.new("):
			# 两处合法豁免：
			#   · element_system.gd —— 它本身就是那个唯一入口
			#   · power_factory.gd  —— 它只**构造** Power 并返回，不施加；
			#     所有施加点（_apply_powers / 开场 powers）都已改道 ElementSystem
			if path.ends_with("element_system.gd") or path.ends_with("power_factory.gd"):
				continue
			offenders.append(path)
	assert_eq(offenders.size(), 0,
		"以下脚本绕过 ElementSystem 直接施加元素：%s" % ", ".join(offenders))


func _all_scripts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_walk("res://scripts", out)
	return out


func _walk(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_walk(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _strip_comments(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for raw: String in src.split("\n"):
		var idx: int = raw.find("#")
		out.append(raw if idx < 0 else raw.substr(0, idx))
	return "\n".join(out)
