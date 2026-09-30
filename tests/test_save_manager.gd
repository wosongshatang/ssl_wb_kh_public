extends GutTest
## 存档测试（阶段 3）
##
## 存档是"跨版本读"的——旧存档遇上新代码是常态，不是异常。
## 所以除了往返一致性，还必须验证**缺字段时给默认值而不是崩溃**。

func before_each() -> void:
	SaveManager.delete_save()


func after_each() -> void:
	SaveManager.delete_save()


func _make_run() -> RunState:
	var run := RunState.new()
	run.start_new_run(&"warrior", 777)
	return run


func _make_map(seed_value: int = 777) -> MapManager:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := MapManager.new()
	map.generate(rng, 1)
	return map


# ══ 基础 ════════════════════════════════════════════════════

func test_has_save_is_false_initially() -> void:
	assert_false(SaveManager.has_save())


func test_restore_returns_empty_when_no_save_exists() -> void:
	assert_eq(SaveManager.restore().size(), 0, "无存档时应返回空数组而非崩溃")


func test_save_creates_file() -> void:
	assert_true(SaveManager.save_run(_make_run(), _make_map()))
	assert_true(SaveManager.has_save())


func test_delete_save_removes_file() -> void:
	SaveManager.save_run(_make_run(), _make_map())
	assert_true(SaveManager.has_save())

	SaveManager.delete_save()

	assert_false(SaveManager.has_save())


func test_delete_save_is_safe_when_no_file() -> void:
	SaveManager.delete_save()
	SaveManager.delete_save()

	assert_false(SaveManager.has_save())


# ══ 往返一致性 ══════════════════════════════════════════════

func test_run_and_map_survive_round_trip() -> void:
	var run := _make_run()
	run.hp = 17
	run.gold = 42
	run.current_act = 2
	run.add_card(&"bash")
	run.relics.append(&"burning_blood")

	var map := _make_map()
	map.enter_node(int(map.rows[0][0]))

	assert_true(SaveManager.save_run(run, map))

	var restored: Array = SaveManager.restore()
	assert_eq(restored.size(), 2, "应还原出 RunState 与 MapManager 两个对象")

	var r: RunState = restored[0]
	var m: MapManager = restored[1]

	assert_eq(r.character_class, &"warrior")
	assert_eq(r.hp, 17)
	assert_eq(r.gold, 42)
	assert_eq(r.current_act, 2)
	assert_eq(r.rng_seed, 777)
	assert_eq(r.deck_card_ids.size(), 11)
	assert_eq(r.relics[0], &"burning_blood")

	assert_eq(m.act, map.act)
	assert_eq(m.current_node_id, map.current_node_id)
	assert_eq(m.node_count(), map.node_count())
	assert_eq(m.rows.size(), map.rows.size())


func test_restored_map_can_still_be_walked() -> void:
	var map := _make_map(99)
	map.enter_node(int(map.rows[0][0]))
	SaveManager.save_run(_make_run(), map)

	var restored: Array = SaveManager.restore()
	var m: MapManager = restored[1]

	var guard: int = 0
	while not m.is_completed() and guard < 100:
		var options: Array[MapNode] = m.available_nodes()
		if options.is_empty():
			break
		m.enter_node(options[0].id)
		guard += 1

	assert_true(m.is_completed(), "读档后应能继续走到 Boss")


func test_save_overwrites_previous_save() -> void:
	var first := _make_run()
	first.hp = 10
	SaveManager.save_run(first, _make_map())

	var second := _make_run()
	second.hp = 25
	SaveManager.save_run(second, _make_map())

	var restored: Array = SaveManager.restore()
	assert_eq((restored[0] as RunState).hp, 25, "新存档应覆盖旧存档")


# ══ 损坏 / 跨版本存档 ═══════════════════════════════════════

func test_restore_handles_missing_sections() -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"run": {}}))
	file.close()

	assert_eq(SaveManager.restore().size(), 0, "缺少 map 段时应返回空数组而非崩溃")


func test_restore_handles_corrupt_json() -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ this is not valid json ")
	file.close()

	assert_eq(SaveManager.restore().size(), 0, "损坏的存档不应让游戏崩溃")


func test_restore_handles_non_dictionary_top_level() -> void:
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()

	assert_eq(SaveManager.restore().size(), 0, "顶层不是字典时应返回空数组")


func test_load_payload_is_human_readable() -> void:
	## JSON 而非二进制：出问题时能直接打开看
	SaveManager.save_run(_make_run(), _make_map())

	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	assert_true(text.contains("\"character_class\""), "存档应是可读的 JSON")
	assert_true(text.contains("warrior"))
