extends GutTest
## 阶段 7 · 平衡与元进度测试
##
## 这一批守的是**"游戏进程长度"与"成长窗口"**——
## 它们是纯数值问题，测试量不出"好不好玩"，
## 但能量出"够不够"（战斗场次、节点保底、内容种类数）。

func before_all() -> void:
	ContentRegistry.load_all()


const SEEDS: int = 40


func _maps(act: int = 1) -> Array[MapManager]:
	var out: Array[MapManager] = []
	for seed_value: int in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := MapManager.new()
		map.generate(rng, act)
		out.append(map)
	return out


# ══ 进程长度（本轮平衡的核心）═══════════════════════════════

func test_act_has_twelve_rows() -> void:
	## 6 层 → 12 层：这是"进程过快、发育时间不足"的直接修法
	assert_eq(MapManager.ROWS_PER_ACT, 12)


func test_every_act_reaches_the_boss() -> void:
	for act: int in [1, 2, 3]:
		for map: MapManager in _maps(act):
			var boss_rows: int = 0
			for node_id: int in map.nodes:
				if (map.nodes[node_id] as MapNode).kind == MapNode.Kind.BOSS:
					boss_rows += 1
			assert_eq(boss_rows, 1, "第 %d 幕应有且仅有一个 Boss" % act)


func test_a_run_offers_enough_combats_to_build_a_deck() -> void:
	## ★ 成长窗口的量化指标。
	## 三选一奖励每次给 1 张牌，玩家需要 **至少 8 次** 才能凑出一套构筑。
	## 12 层 × 3 幕 × 约 60% 战斗节点 ≈ 20+ 场，远超门槛。
	var total_combats: int = 0
	for act: int in [1, 2, 3]:
		var combats: int = 0
		var maps: Array[MapManager] = _maps(act)
		var sample: MapManager = maps[0]
		for node_id: int in sample.nodes:
			var kind: int = (sample.nodes[node_id] as MapNode).kind
			if kind in [MapNode.Kind.COMBAT, MapNode.Kind.ELITE, MapNode.Kind.BOSS]:
				combats += 1

		# 单幕即可断言
		assert_gt(combats, 5, "第 %d 幕的战斗节点太少，构筑没机会成型" % act)
		total_combats += combats

	assert_gt(total_combats, 15, "整局战斗场次不足以支撑三次转职的成长曲线")


# ══ 保底（随机不该决定有没有恢复机会）═══════════════════════

func test_every_generated_map_has_enough_rests() -> void:
	for act: int in [1, 2, 3]:
		for map: MapManager in _maps(act):
			var rests: int = 0
			for node_id: int in map.nodes:
				if (map.nodes[node_id] as MapNode).kind == MapNode.Kind.REST:
					rests += 1
			assert_gte(rests, MapManager.MIN_REST_PER_ACT,
				"第 %d 幕只有 %d 个休息点——玩家会因为没恢复手段而必败" % [act, rests])


func test_every_generated_map_has_enough_shops() -> void:
	for act: int in [1, 2, 3]:
		for map: MapManager in _maps(act):
			var shops: int = 0
			for node_id: int in map.nodes:
				if (map.nodes[node_id] as MapNode).kind == MapNode.Kind.SHOP:
					shops += 1
			assert_gte(shops, MapManager.MIN_SHOP_PER_ACT, "第 %d 幕商店不足" % act)


func test_every_generated_map_has_enough_elites() -> void:
	for act: int in [1, 2, 3]:
		for map: MapManager in _maps(act):
			var elites: int = 0
			for node_id: int in map.nodes:
				if (map.nodes[node_id] as MapNode).kind == MapNode.Kind.ELITE:
					elites += 1
			assert_gte(elites, MapManager.MIN_ELITE_PER_ACT, "第 %d 幕精英不足" % act)


func test_first_row_is_still_combat_only() -> void:
	## 保底补齐**不能把开局改成休息**——那样开局就没压力了。
	## ⚠️ 只有第 0 层是强制的；第 1 层本来就可以随机成休息/商店（既有行为）。
	for map: MapManager in _maps(1):
		for node_id: int in map.rows[0]:
			assert_eq((map.nodes[node_id] as MapNode).kind, MapNode.Kind.COMBAT,
				"第 0 层不该被保底改成非战斗节点")


# ══ 内容量（12 层需要更多种类，否则重复感很强）══════════════

func test_each_act_pool_has_enough_variety() -> void:
	## 12 层 ≈ 8 场战斗。池子里少于 6 种敌人会明显感到重复。
	for act: int in [1, 2, 3]:
		var pool: Array = MapManager.COMBAT_POOLS.get(act, [])
		assert_gte(pool.size(), 6, "第 %d 幕的敌人种类太少（%d）" % [act, pool.size()])


func test_content_volume_meets_phase7_targets() -> void:
	assert_gte(ContentRegistry.all_cards().size(), 50, "卡牌总量不足")
	assert_gte(ContentRegistry.all_relic_ids().size(), 20, "遗物总量不足")
	assert_gte(ContentRegistry.all_enemy_ids().size(), 25, "敌人总量不足")
	assert_gte(MapManager.EVENT_POOL.size(), 10, "事件总量不足")


func test_every_event_in_pool_resolves() -> void:
	for event_id: StringName in MapManager.EVENT_POOL:
		assert_not_null(ContentRegistry.get_event(event_id), "事件 %s 不存在" % event_id)


# ══ 元进度（P7-04 / P7-05）══════════════════════════════════

func test_meta_state_counts_endings() -> void:
	MetaState.reset()

	MetaState.record_ending(&"godslayer")
	MetaState.record_ending(&"godslayer")
	MetaState.record_ending(&"ascension")

	assert_eq(MetaState.ending_count(&"godslayer"), 2)
	assert_eq(MetaState.ending_count(&"ascension"), 1)
	assert_eq(MetaState.total_runs_finished(), 3)
	MetaState.reset()


func test_achievements_are_derived_not_stored() -> void:
	## ★ 成就是**从已有状态推导**的，不是另一份要同步的状态。
	## 单独存一份"已解锁列表"迟早会和真实进度对不上。
	MetaState.reset()
	assert_false(MetaState.is_achievement_unlocked(&"first_blood"))

	MetaState.record_ending(&"godslayer")
	assert_true(MetaState.is_achievement_unlocked(&"first_blood"))
	MetaState.reset()


func test_all_endings_achievement_needs_all_three() -> void:
	MetaState.reset()
	MetaState.record_ending(&"godslayer")
	MetaState.record_ending(&"ascension")
	assert_false(MetaState.is_achievement_unlocked(&"all_endings"), "还差凡人")

	MetaState.record_ending(&"mortal")
	assert_true(MetaState.is_achievement_unlocked(&"all_endings"))
	assert_true(MetaState.has_seen_all_endings())
	MetaState.reset()


func test_meta_state_survives_save_round_trip() -> void:
	MetaState.reset()
	MetaState.record_ending(&"mortal")
	MetaState.unlock_card(&"heavy_strike")

	var snapshot := MetaState.to_dict()
	MetaState.reset()
	assert_eq(MetaState.ending_count(&"mortal"), 0, "reset 应清空")

	MetaState.from_dict(snapshot)

	assert_eq(MetaState.ending_count(&"mortal"), 1, "元进度必须能跨局恢复")
	assert_true(MetaState.is_card_unlocked(&"heavy_strike"))
	MetaState.reset()


func test_unlock_is_idempotent() -> void:
	MetaState.reset()
	MetaState.unlock_card(&"brace")
	MetaState.unlock_card(&"brace")

	assert_eq(MetaState.unlocked_cards.size(), 1, "重复解锁不该产生重复条目")
	MetaState.reset()
