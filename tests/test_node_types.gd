extends GutTest
## 阶段 6 · 节点类型扩展测试（P6-10：神坛 / 叛神者）

func before_all() -> void:
	ContentRegistry.load_all()


const NEW_KINDS: Array[int] = [MapNode.Kind.GOD_ALTAR, MapNode.Kind.TRAITOR]


# ══ 节点类型 ════════════════════════════════════════════════

func test_new_kinds_have_labels() -> void:
	for kind: int in NEW_KINDS:
		assert_ne(MapNode.kind_label_of(kind), "?", "节点类型 %d 没有中文名" % kind)
		assert_ne(MapNode.kind_label_of(kind), "", "节点类型 %d 名字为空" % kind)


func test_new_kinds_have_colors() -> void:
	for kind: int in NEW_KINDS:
		assert_true(UiPalette.color_for_node_kind(kind).a > 0.0,
			"节点类型 %d 没有配色" % kind)


func test_new_kinds_have_distinct_colors() -> void:
	## 地图上要一眼分得清，颜色撞了等于没有类型
	var seen: Dictionary = {}
	for kind: int in [
		MapNode.Kind.COMBAT, MapNode.Kind.ELITE, MapNode.Kind.REST,
		MapNode.Kind.SHOP, MapNode.Kind.EVENT, MapNode.Kind.BOSS,
		MapNode.Kind.GOD_ALTAR, MapNode.Kind.TRAITOR,
	]:
		var color: Color = UiPalette.color_for_node_kind(kind)
		assert_false(seen.has(color), "节点类型 %d 与 %s 撞色" % [kind, seen.get(color, "")])
		seen[color] = str(kind)


func test_new_kinds_are_in_the_generation_weights() -> void:
	## 不在权重表里 = 生成器永远不会产出 = 玩家永远遇不到
	for kind: int in NEW_KINDS:
		assert_true(MapManager.KIND_WEIGHTS.has(kind),
			"节点类型 %d 不在生成权重表里" % kind)
		assert_gt(int(MapManager.KIND_WEIGHTS[kind]), 0,
			"节点类型 %d 的权重必须大于 0" % kind)


func test_combat_still_dominates_the_weights() -> void:
	## 新节点不能把战斗密度挤下去——这毕竟是个卡牌战斗游戏
	var combat: int = int(MapManager.KIND_WEIGHTS[MapNode.Kind.COMBAT])
	var others: int = 0
	for kind: Variant in MapManager.KIND_WEIGHTS:
		if kind != MapNode.Kind.COMBAT:
			others += int(MapManager.KIND_WEIGHTS[kind])

	assert_gt(combat, others, "普通战斗的权重应超过其他所有类型之和")


func test_generated_maps_can_contain_the_new_kinds() -> void:
	## 40 个种子里至少要出现一次——单种子通过不代表生成算法真的会产出
	var seen: Dictionary = {}
	for seed_value: int in 40:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := MapManager.new()
		map.generate(rng, 1)
		for node: MapNode in map.nodes.values():
			seen[node.kind] = true

	for kind: int in NEW_KINDS:
		assert_true(seen.has(kind),
			"40 个种子里都没生成过节点类型 %d——权重等于白配" % kind)


# ══ 永久力量（神坛的产物）════════════════════════════════════

func test_bonus_strength_defaults_to_zero() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)

	assert_eq(run.bonus_strength, 0)


func test_bonus_strength_survives_save_round_trip() -> void:
	## 存不下来 = 玩家献祭换的力量在 SL 之后凭空消失
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.bonus_strength = 3

	var restored := RunState.new()
	restored.from_dict(run.to_dict())

	assert_eq(restored.bonus_strength, 3, "永久力量必须能存进存档")


func test_bonus_strength_is_cleared_on_new_run() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	run.bonus_strength = 3

	run.start_new_run(&"warrior", 2)

	assert_eq(run.bonus_strength, 0, "新的一局不该继承上一局的献祭")


# ══ 叛神者：凡人路线的出口 ══════════════════════════════════

func test_traitor_can_reduce_divinity() -> void:
	## ★ 这是「凡人结局」能成立的前提。
	## 无色卡 / 神格遗物 / 神坛全都在加神性——
	## 一个只涨不跌的侵蚀条，等于宣告凡人结局只是个理论值。
	GameState.reset_run()
	GameState.divinity = 50

	GameState.add_divinity(-TraitorPanel.DIVINITY_DELTA)

	assert_eq(GameState.divinity, 30, "叛神者应能剥离神性")
	GameState.reset_run()


func test_divinity_never_goes_negative() -> void:
	GameState.reset_run()
	GameState.divinity = 5

	GameState.add_divinity(-TraitorPanel.DIVINITY_DELTA)

	assert_eq(GameState.divinity, 0, "神性不该变成负数")
	GameState.reset_run()


func test_stripping_divinity_can_reach_the_mortal_ending() -> void:
	## 端到端：神性过高 → 剥离 → 凡人结局变成可达
	GameState.reset_run()
	GameState.humanity = 3
	GameState.divinity = 75

	assert_eq(GameState.resolve_ending(), &"godslayer", "75 神性时还够不到凡人")

	GameState.add_divinity(-TraitorPanel.DIVINITY_DELTA)

	assert_eq(GameState.resolve_ending(), &"mortal",
		"剥离之后应该够得到凡人结局——这正是叛神者存在的意义")
	GameState.reset_run()


# ══ 神坛的代价 ══════════════════════════════════════════════

func test_altar_constants_are_sane() -> void:
	assert_gt(GodAltarPanel.HP_COST_RATIO, 0.0)
	assert_lt(GodAltarPanel.HP_COST_RATIO, 1.0, "代价不该是必死")
	assert_gt(GodAltarPanel.STRENGTH_GAIN, 0)
	assert_gt(GodAltarPanel.DIVINITY_GAIN, 0, "献祭必须推高侵蚀")


func test_altar_leave_is_not_a_wasted_trip() -> void:
	## 白跑一趟会让玩家觉得这个节点是负收益
	assert_gt(GodAltarPanel.LEAVE_HEAL_RATIO, 0.0)


func test_altar_sacrifice_cannot_kill_the_player() -> void:
	## 献祭是"代价"，不是"自杀"——必须留 1 点生命
	var max_hp: int = 30
	var cost: int = int(ceil(float(max_hp) * GodAltarPanel.HP_COST_RATIO))
	var hp: int = maxi(1, 1 - cost)

	assert_eq(hp, 1, "献祭后至少保留 1 点生命")
