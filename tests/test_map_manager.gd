extends GutTest
## 地图生成测试（阶段 3）
##
## 地图生成是最容易"看起来能用、实际会卡死"的模块：
## 生成出孤岛节点或死路，玩家会直接走进一条走不完的路。
## 所以这里重点验证**图的结构不变量**，而不只是"生成了几个节点"。

func _generate(seed_value: int = 42) -> MapManager:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := MapManager.new()
	map.generate(rng, 1)
	return map


## 从起点贪心地一路走到 Boss
func _walk_to_boss(map: MapManager) -> bool:
	var guard: int = 0
	while not map.is_completed() and guard < 100:
		var options: Array[MapNode] = map.available_nodes()
		if options.is_empty():
			return false
		map.enter_node(options[0].id)
		guard += 1
	return map.is_completed()


# ══ 结构不变量 ══════════════════════════════════════════════

func test_generates_expected_row_count() -> void:
	var map := _generate()

	assert_eq(map.rows.size(), MapManager.ROWS_PER_ACT)
	assert_gt(map.node_count(), 0)


func test_boss_is_alone_on_the_last_row() -> void:
	var map := _generate()
	var last_row: Array = map.rows[MapManager.ROWS_PER_ACT - 1]

	assert_eq(last_row.size(), 1, "Boss 层应只有一个节点")
	assert_eq(map.boss_node().kind, MapNode.Kind.BOSS)


func test_first_row_is_always_combat() -> void:
	var map := _generate()

	for node_id: int in map.rows[0]:
		assert_eq((map.nodes[node_id] as MapNode).kind, MapNode.Kind.COMBAT,
			"第一层应固定为普通战斗")


func test_no_dead_ends() -> void:
	## 除 Boss 外每个节点都必须有出口，否则玩家会卡在死路上
	var map := _generate()

	for node_id: int in map.nodes:
		var node: MapNode = map.nodes[node_id]
		if node.row == MapManager.ROWS_PER_ACT - 1:
			continue
		assert_gt(node.next_ids.size(), 0, "%s 是死路，玩家会卡住" % node)


func test_no_islands() -> void:
	## 除第一层外每个节点都必须有入口，否则会出现永远到不了的节点
	var map := _generate()

	var has_parent: Dictionary = {}
	for node_id: int in map.nodes:
		for child_id: int in (map.nodes[node_id] as MapNode).next_ids:
			has_parent[child_id] = true

	for node_id: int in map.nodes:
		var node: MapNode = map.nodes[node_id]
		if node.row == 0:
			continue
		assert_true(has_parent.has(node_id), "%s 是孤岛，永远到不了" % node)


func test_edges_only_connect_adjacent_rows() -> void:
	## 跳层的边会让"路径"失去意义（玩家可能直接从第 1 层跳到第 4 层）
	var map := _generate()

	for node_id: int in map.nodes:
		var node: MapNode = map.nodes[node_id]
		for child_id: int in node.next_ids:
			var child: MapNode = map.nodes[child_id]
			assert_eq(child.row, node.row + 1, "边只能连向下一层")


func test_no_elite_in_the_first_two_rows() -> void:
	## 开局就刷精英会劝退玩家（设计上不该出现）
	var map := _generate()

	for r: int in [0, 1]:
		for node_id: int in map.rows[r]:
			assert_ne((map.nodes[node_id] as MapNode).kind, MapNode.Kind.ELITE,
				"第 %d 层不应出现精英" % (r + 1))


func test_every_node_has_a_payload_or_is_intentionally_empty() -> void:
	## 战斗/精英/Boss 必须带 enemy_id，否则进战斗时不知道该生成谁
	var map := _generate()

	for node_id: int in map.nodes:
		var node: MapNode = map.nodes[node_id]
		if node.kind == MapNode.Kind.COMBAT or node.kind == MapNode.Kind.ELITE \
				or node.kind == MapNode.Kind.BOSS:
			assert_true(node.payload.has("enemy_id"), "%s 缺少 enemy_id" % node)
		elif node.kind == MapNode.Kind.EVENT:
			assert_true(node.payload.has("event_id"), "%s 缺少 event_id" % node)


func test_same_seed_produces_identical_map() -> void:
	var a := _generate(2024)
	var b := _generate(2024)

	assert_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()),
		"相同种子应生成完全相同的地图（否则每日种子/回放无从谈起）")


func test_different_seeds_produce_different_maps() -> void:
	var a := _generate(1)
	var b := _generate(2)

	assert_ne(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()),
		"不同种子应生成不同的地图")


# ══ 移动规则 ════════════════════════════════════════════════

func test_available_nodes_before_start_is_first_row() -> void:
	var map := _generate()

	var options: Array[MapNode] = map.available_nodes()

	assert_eq(options.size(), MapManager.STARTING_NODES)
	for node: MapNode in options:
		assert_eq(node.row, 0)


func test_cannot_jump_to_second_row_directly() -> void:
	var map := _generate()
	var second_row_id: int = int(map.rows[1][0])

	assert_false(map.enter_node(second_row_id), "未进入第一层时不能跳到第二层")


func test_enter_node_updates_state_and_emits_signal() -> void:
	var map := _generate()
	watch_signals(map)
	var target_id: int = int(map.rows[0][0])

	assert_true(map.enter_node(target_id))

	assert_eq(map.current_node_id, target_id)
	assert_true((map.nodes[target_id] as MapNode).is_visited)
	assert_signal_emitted(map, "node_entered")


func test_available_nodes_after_entering_follow_edges() -> void:
	var map := _generate()
	var first_id: int = int(map.rows[0][0])
	map.enter_node(first_id)

	var expected: Array = (map.nodes[first_id] as MapNode).next_ids
	var options: Array[MapNode] = map.available_nodes()

	assert_eq(options.size(), expected.size())
	for node: MapNode in options:
		assert_true(expected.has(node.id), "可达节点必须来自当前节点的出边")


func test_cannot_re_enter_current_node() -> void:
	var map := _generate()
	var first_id: int = int(map.rows[0][0])
	map.enter_node(first_id)

	assert_false(map.enter_node(first_id), "不能重复进入当前节点")


func test_enter_unknown_node_returns_false() -> void:
	var map := _generate()

	assert_false(map.enter_node(999999), "不存在的节点应返回 false")


func test_walking_greedily_reaches_boss() -> void:
	## 这是「一局能走完」的最基本保证
	var map := _generate()

	assert_true(_walk_to_boss(map), "贪心走法必须能走到 Boss（否则地图有死路）")
	assert_true(map.is_completed())
	assert_eq(map.current_node().kind, MapNode.Kind.BOSS)


func test_map_completed_signal_fires_on_boss() -> void:
	var map := _generate()
	watch_signals(map)

	_walk_to_boss(map)

	assert_signal_emitted(map, "map_completed")


func test_multiple_seeds_all_reachable() -> void:
	## 单个种子通过不代表生成算法正确——跑一批种子，任何一个卡住都是 bug
	for seed_value: int in range(1, 41):
		var map := _generate(seed_value)
		assert_true(_walk_to_boss(map), "种子 %d 生成的地图走不到 Boss" % seed_value)


# ══ 序列化 ══════════════════════════════════════════════════

func test_to_dict_from_dict_round_trip() -> void:
	var map := _generate(7)
	map.enter_node(int(map.rows[0][0]))

	var restored := MapManager.new()
	restored.from_dict(map.to_dict())

	assert_eq(restored.act, map.act)
	assert_eq(restored.current_node_id, map.current_node_id)
	assert_eq(restored.node_count(), map.node_count())
	assert_eq(restored.rows.size(), map.rows.size())
	assert_eq(restored.boss_node().kind, MapNode.Kind.BOSS)
	assert_eq(restored.available_nodes().size(), map.available_nodes().size())


func test_restored_map_preserves_edges() -> void:
	var map := _generate(11)
	var first_id: int = int(map.rows[0][0])

	var restored := MapManager.new()
	restored.from_dict(map.to_dict())

	var original_children: Array = (map.nodes[first_id] as MapNode).next_ids
	var restored_children: Array = (restored.nodes[first_id] as MapNode).next_ids

	assert_eq(restored_children, original_children, "读档后边关系必须完整保留")


func test_restored_map_can_continue_walking() -> void:
	var map := _generate(3)
	map.enter_node(int(map.rows[0][0]))

	var restored := MapManager.new()
	restored.from_dict(map.to_dict())

	assert_true(_walk_to_boss(restored), "读档后应能继续走到 Boss")


# ══ 内容引用完整性 ══════════════════════════════════════════

func test_all_generated_payload_ids_resolve_to_real_content() -> void:
	## 这条守着一个很隐蔽的失败模式：**内容做了但玩家永远遇不到**。
	## 曾经事件 payload 写的是 `placeholder_event_N`，两个真事件因此从未被触发过；
	## 也曾经所有战斗节点都固定用 `act1_combat`，导致毒敌人只存在于单测里。
	ContentRegistry.load_all()

	for seed_value: int in range(1, 21):
		var map := _generate(seed_value)
		for node_id: int in map.nodes:
			var node: MapNode = map.nodes[node_id]

			if node.payload.has("enemy_id"):
				var enemy_id := StringName(str(node.payload["enemy_id"]))
				assert_not_null(ContentRegistry.get_enemy(enemy_id),
					"种子 %d 的 %s 引用了不存在的敌人「%s」" % [seed_value, node, enemy_id])

			if node.payload.has("event_id"):
				var event_id := StringName(str(node.payload["event_id"]))
				assert_not_null(ContentRegistry.get_event(event_id),
					"种子 %d 的 %s 引用了不存在的事件「%s」" % [seed_value, node, event_id])


func test_poisoner_can_actually_appear_in_act_one() -> void:
	## 「克制壁垒的敌人」必须在真实对局里出现，否则壁垒的弱点只存在于单测中
	ContentRegistry.load_all()

	var seen_poisoner: bool = false
	for seed_value: int in range(1, 41):
		var map := _generate(seed_value)
		for node_id: int in map.nodes:
			var node: MapNode = map.nodes[node_id]
			if str(node.payload.get("enemy_id", "")) == "act1_poisoner":
				seen_poisoner = true
				break
		if seen_poisoner:
			break

	assert_true(seen_poisoner, "40 个种子里毒刃客一次都没出现——它不在战斗池里？")
