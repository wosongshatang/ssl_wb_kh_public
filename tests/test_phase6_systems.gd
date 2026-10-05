extends GutTest
## 阶段 6 测试：幕环境机制 / 侵蚀系统 / 三结局判定

func before_all() -> void:
	ContentRegistry.load_all()


func _make_player(hp: int = 60) -> Player:
	var p := Player.new()
	p.display_name = "战士"
	p.max_hp = hp
	p.reset_for_battle()
	autofree(p)
	return p


func _make_creature(hp: int = 60) -> Creature:
	var c := Creature.new()
	c.display_name = "测试体"
	c.max_hp = hp
	c.reset_for_battle()
	autofree(c)
	return c


func _seeded_rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _modifier(modifier_id: StringName) -> ActModifier:
	var loaded: Variant = ContentRegistry.get_act_modifier(modifier_id)
	assert_true(loaded is ActModifier, "找不到幕环境 %s" % modifier_id)
	return loaded as ActModifier


# ══ 幕环境数据 ══════════════════════════════════════════════

func test_every_act_has_a_modifier() -> void:
	for act: int in [1, 2, 3]:
		var modifier_id: StringName = MapManager.act_modifier_id(&"warrior", act)
		assert_ne(modifier_id, &"", "第 %d 幕没有配环境机制" % act)
		assert_not_null(ContentRegistry.get_act_modifier(modifier_id),
			"第 %d 幕的机制 %s 没有 .tres" % [act, modifier_id])


func test_every_modifier_has_data_and_implementation() -> void:
	for modifier_id: StringName in ContentRegistry.all_act_modifier_ids():
		assert_true(ActModifiers.is_known(modifier_id),
			"幕环境 %s 有 .tres 但没有实现" % modifier_id)
		var data := _modifier(modifier_id)
		assert_ne(data.display_name, "", "%s 缺少名称" % modifier_id)
		assert_ne(data.description, "", "%s 缺少描述" % modifier_id)


func test_every_known_modifier_has_data() -> void:
	for modifier_id: StringName in [&"arena_crowd_cheer", &"battlefield_momentum", &"ancient_grudge"]:
		assert_not_null(ContentRegistry.get_act_modifier(modifier_id),
			"机制 %s 在代码里存在但没有 .tres" % modifier_id)


# ══ 竞技场 · 观众喝彩 ════════════════════════════════════════

func test_crowd_cheer_accumulates_on_same_type() -> void:
	var player := _make_player()
	var runtime := ActModifiers.create(_modifier(&"arena_crowd_cheer"), null)
	assert_not_null(runtime)

	runtime.on_card_played(player, CardData.make_attack(&"a", "打击", 1, 6))
	runtime.on_card_played(player, CardData.make_attack(&"b", "重击", 2, 8))

	assert_eq(player.get_power_amount(&"strength"), 1, "连续两张同类牌应积累 1 层喝彩")


func test_crowd_cheer_resets_when_type_changes() -> void:
	var player := _make_player()
	var runtime := ActModifiers.create(_modifier(&"arena_crowd_cheer"), null)

	runtime.on_card_played(player, CardData.make_attack(&"a", "打击", 1, 6))
	runtime.on_card_played(player, CardData.make_attack(&"b", "重击", 2, 8))
	assert_eq(player.get_power_amount(&"strength"), 1)

	# 换类型 → 喝彩清零
	runtime.on_card_played(player, CardData.make_skill(&"c", "防御", 1, 5))

	assert_eq(player.get_power_amount(&"strength"), 0, "换类型应清空喝彩")


func test_crowd_cheer_reset_does_not_wipe_other_strength() -> void:
	## 「清空喝彩」只能扣掉自己加的那部分——
	## 用 remove_power 会把遗物/药水给的力量一起清掉
	var player := _make_player()
	player.apply_power(BasePowers.Strength.new(4))  # 假设来自遗物
	var runtime := ActModifiers.create(_modifier(&"arena_crowd_cheer"), null)

	runtime.on_card_played(player, CardData.make_attack(&"a", "打击", 1, 6))
	runtime.on_card_played(player, CardData.make_attack(&"b", "重击", 2, 8))
	assert_eq(player.get_power_amount(&"strength"), 5)

	runtime.on_card_played(player, CardData.make_skill(&"c", "防御", 1, 5))

	assert_eq(player.get_power_amount(&"strength"), 4, "只该扣掉喝彩那 1 层")


# ══ 战场 · 军势 ══════════════════════════════════════════════

func test_war_momentum_buffs_both_sides() -> void:
	var player := _make_player()
	var enemy := _make_creature()
	var runtime := ActModifiers.create(_modifier(&"battlefield_momentum"), null)

	runtime.apply_battle_start(player, [enemy] as Array)

	assert_eq(player.get_power_amount(&"strength"), 2, "玩家也变强")
	assert_eq(enemy.get_power_amount(&"strength"), 2, "敌人也变强——这才是战场的代价")


# ══ 古战场 · 执念 ════════════════════════════════════════════

func test_undying_grudge_hurts_player_on_kill() -> void:
	var player := _make_player(60)
	player.gain_block(20)
	var runtime := ActModifiers.create(_modifier(&"ancient_grudge"), null)

	runtime.on_enemy_killed(player, _make_creature())

	assert_eq(player.hp, 56, "执念反噬应造成 4 点伤害")
	assert_eq(player.block, 20, "反噬**无视格挡**——所以清场不再是无条件收益")


# ══ 侵蚀与显化 ══════════════════════════════════════════════

func test_manifest_threshold() -> void:
	GameState.reset_run()

	GameState.divinity = GameState.DIVINITY_MANIFEST - 1
	assert_false(GameState.is_divinity_manifest())

	GameState.divinity = GameState.DIVINITY_MANIFEST
	assert_true(GameState.is_divinity_manifest())

	GameState.reset_run()


func test_manifest_power_trades_hp_each_turn() -> void:
	var player := _make_player(60)
	player.apply_power(IdentityPowers.create(&"divinity_manifest"))
	player.apply_power(BasePowers.Strength.new(IdentityPowers.DivinityManifest.STRENGTH))

	player.on_turn_start()

	assert_eq(player.hp, 58, "显化每回合应流失 2 点生命")
	assert_eq(player.get_power_amount(&"strength"), 3)


func test_manifest_is_not_identity() -> void:
	## 侵蚀不是"刻进灵魂"的东西——玩家还有收手的余地
	var manifest := IdentityPowers.create(&"divinity_manifest")
	assert_false(manifest.is_identity, "显化应是可移除的常规 Power")


func test_erosion_ratio_spans_both_directions() -> void:
	GameState.reset_run()

	GameState.divinity = 50
	assert_gt(GameState.erosion_ratio(), 0.0, "神性高 → 偏正")

	GameState.divinity = 0
	GameState.humanity = 50
	assert_lt(GameState.erosion_ratio(), 0.0, "人性高 → 偏负")

	GameState.reset_run()


# ══ 三结局判定 ══════════════════════════════════════════════

func test_ending_ascension_when_divinity_maxed() -> void:
	GameState.reset_run()
	GameState.divinity = GameState.DIVINITY_ASCENSION

	assert_eq(GameState.resolve_ending(), &"ascension")

	GameState.reset_run()


func test_ending_mortal_needs_humanity_and_low_divinity() -> void:
	GameState.reset_run()
	GameState.humanity = 3
	GameState.divinity = 20

	assert_eq(GameState.resolve_ending(), &"mortal")

	GameState.reset_run()


func test_ending_godslayer_is_the_default() -> void:
	GameState.reset_run()
	GameState.humanity = 3
	GameState.divinity = 80  # 人性够但神性太高 → 不再是凡人

	assert_eq(GameState.resolve_ending(), &"godslayer")

	GameState.reset_run()


func test_ascension_beats_mortal() -> void:
	## 顺序不可调换：一个神性 95 的玩家即使人性满了，也已经不是人了
	GameState.reset_run()
	GameState.humanity = 10
	GameState.divinity = GameState.DIVINITY_ASCENSION

	assert_eq(GameState.resolve_ending(), &"ascension")

	GameState.reset_run()


func test_every_ending_has_title_and_summary() -> void:
	for ending: StringName in [&"ascension", &"mortal", &"godslayer"]:
		assert_ne(GameState.ending_title(ending), "")
		assert_ne(GameState.ending_summary(ending), "")


# ══ 幕环境与战斗的接线 ══════════════════════════════════════

func test_battle_manager_applies_the_modifier_at_start() -> void:
	var player := _make_player()
	var enemy := _make_creature()
	var bm := BattleManager.new()
	autofree(bm)
	bm.set_act_modifier(_modifier(&"battlefield_momentum"))

	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	assert_not_null(bm.act_modifier, "开战时应创建运行时")
	assert_eq(player.get_power_amount(&"strength"), 2, "机制应在开战时生效")


func test_battle_without_modifier_still_works() -> void:
	var player := _make_player()
	var bm := BattleManager.new()
	autofree(bm)

	var enemies: Array[Enemy] = []
	var deck: Array[CardData] = []
	bm.start_battle(player, enemies, deck, _seeded_rng())

	assert_null(bm.act_modifier, "没配机制时不该崩")


func test_unknown_modifier_id_returns_null() -> void:
	var unknown := ActModifier.new()
	unknown.id = &"not_a_real_modifier"

	assert_null(ActModifiers.create(unknown, null))
