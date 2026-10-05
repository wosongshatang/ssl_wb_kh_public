extends GutTest
## 九图敌人池测试（阶段 6）
##
## 守的是一条很容易被忽略的事：**敌人池不只是"数量够"**，
## 每一幕都要有机制互补的敌人，而且**壁垒的弱点必须在每一幕都成立**。

func before_all() -> void:
	ContentRegistry.load_all()


const REQUIRED_ACTS: Array[int] = [1, 2, 3]


func _pool(act: int) -> Array:
	return MapManager.combat_pool(&"warrior", act)


func _data(enemy_id: StringName) -> EnemyData:
	var loaded: Variant = ContentRegistry.get_enemy(enemy_id)
	assert_true(loaded is EnemyData, "找不到敌人 %s" % enemy_id)
	return loaded as EnemyData


# ══ 池的完整性 ══════════════════════════════════════════════

func test_every_act_has_a_combat_pool() -> void:
	for act: int in REQUIRED_ACTS:
		assert_gt(_pool(act).size(), 0, "第 %d 幕没有普通敌人池" % act)


func test_every_pool_is_varied_enough() -> void:
	## 池子里只有 1~2 种敌人 = 玩家每一场都在打同一个东西
	for act: int in REQUIRED_ACTS:
		assert_gt(_pool(act).size(), 2, "第 %d 幕的普通敌人种类太少" % act)


func test_every_pool_enemy_resolves() -> void:
	for act: int in REQUIRED_ACTS:
		for enemy_id: Variant in _pool(act):
			assert_not_null(ContentRegistry.get_enemy(StringName(str(enemy_id))),
				"第 %d 幕的敌人池引用了不存在的 id「%s」" % [act, enemy_id])


func test_every_pool_enemy_belongs_to_its_act() -> void:
	for act: int in REQUIRED_ACTS:
		for enemy_id: Variant in _pool(act):
			var data := _data(StringName(str(enemy_id)))
			assert_eq(data.act, act, "%s 的 act 字段与池不符" % enemy_id)


func test_every_pool_enemy_is_not_elite_or_boss() -> void:
	## 普通池里混进精英/Boss 会让难度曲线失控
	for act: int in REQUIRED_ACTS:
		for enemy_id: Variant in _pool(act):
			var data := _data(StringName(str(enemy_id)))
			assert_false(data.is_elite, "%s 是精英，不该在普通池里" % enemy_id)
			assert_false(data.is_boss, "%s 是 Boss，不该在普通池里" % enemy_id)


func test_every_pool_enemy_has_intents() -> void:
	for act: int in REQUIRED_ACTS:
		for enemy_id: Variant in _pool(act):
			var data := _data(StringName(str(enemy_id)))
			assert_gt(data.intents.size(), 0, "%s 没有意图序列" % enemy_id)


# ══ ★ 壁垒的弱点必须在每一幕都成立 ══════════════════════════

func test_every_act_has_a_poison_enemy() -> void:
	## 毒**无视格挡**，是「格挡滚雪球」的天敌。
	## 如果某一幕没有毒敌人，那一幕的壁垒就是无解职业。
	for act: int in REQUIRED_ACTS:
		var found: bool = false
		for enemy_id: Variant in _pool(act):
			var data := _data(StringName(str(enemy_id)))
			for intent: IntentData in data.intents:
				if intent.power_id == &"poison":
					found = true
					break
			if found:
				break
		assert_true(found, "第 %d 幕没有任何会下毒的普通敌人——壁垒在这一幕无解" % act)


func test_every_act_has_a_defensive_enemy() -> void:
	## 有格挡的敌人惩罚「只会堆攻击」，是另一条压力轴
	for act: int in REQUIRED_ACTS:
		var found: bool = false
		for enemy_id: Variant in _pool(act):
			var data := _data(StringName(str(enemy_id)))
			for intent: IntentData in data.intents:
				if intent.type == IntentData.IntentType.DEFEND:
					found = true
					break
			if found:
				break
		assert_true(found, "第 %d 幕没有任何会格挡的敌人" % act)


func test_every_act_has_a_multi_hit_or_scaling_enemy() -> void:
	## 多段伤害惩罚"单次大格挡"；自我强化惩罚"拖时间"。
	## 至少要有其中一种，否则每幕的解法会退化成"堆一个大的"。
	for act: int in REQUIRED_ACTS:
		var found: bool = false
		for enemy_id: Variant in _pool(act):
			var data := _data(StringName(str(enemy_id)))
			for intent: IntentData in data.intents:
				if intent.times > 1 or intent.type == IntentData.IntentType.BUFF:
					found = true
					break
			if found:
				break
		assert_true(found, "第 %d 幕没有多段伤害或自我强化的敌人" % act)


# ══ 幕名 ════════════════════════════════════════════════════

func test_every_act_has_a_name() -> void:
	for act: int in REQUIRED_ACTS:
		assert_ne(MapManager.act_name(&"warrior", act), "", "第 %d 幕没有名字" % act)
		assert_false(MapManager.act_name(&"warrior", act).begins_with("第"),
			"第 %d 幕应配置正式名称" % act)


func test_every_line_has_three_acts() -> void:
	## ⚠️ 这条取代了原来的"越界回退"测试。
	## `line_for()` 现在对越界**会 push_error**（不能静默走进别人的图），
	## 而 GUT 把 push_error 计为失败——所以"越界行为"不适合用运行时断言来测，
	## 应该测**配置本身的完整性**：每条线都必须有且只有 3 幕。
	for character: Variant in MapManager.LINES:
		var lines: Array = MapManager.LINES[character]
		assert_eq(lines.size(), 3, "角色「%s」应有 3 幕（三线九图）" % character)

		for act: int in [1, 2, 3]:
			var line: Dictionary = MapManager.line_for(StringName(str(character)), act)
			assert_true(line.has("name"), "%s 第 %d 幕缺少名字" % [character, act])
			assert_true(line.has("modifier"), "%s 第 %d 幕缺少环境机制" % [character, act])
			assert_gt((line.get("enemies", []) as Array).size(), 0,
				"%s 第 %d 幕没有敌人池" % [character, act])


# ══ 幕环境与敌人池的配合 ════════════════════════════════════

func test_every_act_has_both_a_modifier_and_a_pool() -> void:
	## 一幕只配了环境没有敌人池（或反过来）都是配置事故
	for act: int in REQUIRED_ACTS:
		assert_true(MapManager.act_modifier_id(&"warrior", act) != &"", "第 %d 幕没有环境机制" % act)
		assert_gt(_pool(act).size(), 0, "第 %d 幕没有敌人池" % act)


func test_act_names_match_act_modifier_flavor() -> void:
	## 幕名与机制应当对得上（竞技场↔观众喝彩 / 战场↔军势 / 古战场↔执念）
	assert_eq(MapManager.act_name(&"warrior", 1), "竞技场")
	assert_eq(MapManager.act_modifier_id(&"warrior", 1), &"arena_crowd_cheer")
	assert_eq(MapManager.act_name(&"warrior", 2), "战场")
	assert_eq(MapManager.act_modifier_id(&"warrior", 2), &"battlefield_momentum")
	assert_eq(MapManager.act_name(&"warrior", 3), "古战场")
	assert_eq(MapManager.act_modifier_id(&"warrior", 3), &"ancient_grudge")
