extends GutTest
## 阶段 0 骨架自检 —— 验证工程地基可用。
##
## 这些断言是「阶段 0 验收标准」的自动化形式：
##   - 三大 Autoload 可访问
##   - GameState 的转职路径语义正确（不可重复、只追加）
##   - 三结局判定门槛与设计文档 §1.5 / §8.4 一致
##   - ContentRegistry 只读查询可用

const CHARACTER_WARRIOR: StringName = &"warrior"
const JOB_SHIELD_GUARD: StringName = &"shield_guard"
const JOB_BASTION: StringName = &"bastion"


func before_each() -> void:
	GameState.reset_run()


# ── Autoload 可用性 ──────────────────────────────────────────

func test_autoloads_are_available() -> void:
	assert_not_null(GameState, "GameState Autoload 应可用")
	assert_not_null(EventBus, "EventBus Autoload 应可用")
	assert_not_null(ContentRegistry, "ContentRegistry Autoload 应可用")


func test_event_bus_exposes_run_lifecycle_signals() -> void:
	assert_true(EventBus.has_signal("run_started"), "EventBus 应有 run_started")
	assert_true(EventBus.has_signal("run_ended"), "EventBus 应有 run_ended")
	assert_true(EventBus.has_signal("erosion_changed"), "EventBus 应有 erosion_changed")


# ── GameState：转职路径（设计文档 §2.1「不可逆、不可重选」）──

func test_reset_run_clears_everything() -> void:
	## 阶段 3 起：单局资源存在 RunState 里，GameState 只保留身份与侵蚀状态
	GameState.advance_job(JOB_SHIELD_GUARD)
	GameState.add_divinity(40)
	GameState.run = RunState.new()

	GameState.reset_run()

	assert_eq(GameState.job_path.size(), 0, "转职路径应被清空")
	assert_eq(GameState.divinity, 0, "神性应归零")
	assert_null(GameState.run, "单局状态应被清空")
	assert_null(GameState.map, "地图应被清空")


func test_advance_job_appends_in_order() -> void:
	GameState.advance_job(JOB_SHIELD_GUARD)
	GameState.advance_job(JOB_BASTION)

	assert_eq(GameState.job_path, [JOB_SHIELD_GUARD, JOB_BASTION], "转职路径应按顺序记录")
	assert_true(GameState.is_final_job_reached(), "两次转职后应达成终职")


func test_advance_job_rejects_duplicate() -> void:
	GameState.advance_job(JOB_SHIELD_GUARD)
	GameState.advance_job(JOB_SHIELD_GUARD)

	assert_eq(GameState.job_path.size(), 1, "同一职业不可重复刻入")


func test_advance_job_emits_signal() -> void:
	watch_signals(GameState)
	GameState.advance_job(JOB_SHIELD_GUARD)
	assert_signal_emitted_with_parameters(GameState, "job_advanced", [JOB_SHIELD_GUARD])


# ── 侵蚀与结局门槛（设计文档 §1.5 / §8.4）────────────────────

func test_divinity_is_clamped_to_max() -> void:
	GameState.add_divinity(999)
	assert_eq(GameState.divinity, GameState.DIVINITY_MAX, "神性不应超过上限")


func test_ascension_locks_at_divinity_90() -> void:
	GameState.add_divinity(89)
	assert_false(GameState.is_ascension_locked(), "神性 89 时不应锁定登神")

	GameState.add_divinity(1)
	assert_true(GameState.is_ascension_locked(), "神性 90 时应锁定登神")


func test_mortal_ending_requires_humanity_3_and_divinity_under_60() -> void:
	GameState.add_humanity(3)
	GameState.add_divinity(59)
	assert_true(GameState.can_unlock_mortal_ending(), "人性 3 + 神性 59 应可走凡人结局")

	GameState.add_divinity(1)
	assert_false(GameState.can_unlock_mortal_ending(), "神性 60 时凡人结局应关闭")


# ── ContentRegistry ─────────────────────────────────────────

func test_content_registry_summary_has_all_categories() -> void:
	var counts: Dictionary = ContentRegistry.summary()
	for key: String in ["cards", "relics", "jobs", "enemies", "acts"]:
		assert_true(counts.has(key), "summary 应包含分类 %s" % key)


func test_content_registry_returns_null_for_unknown_id() -> void:
	assert_null(ContentRegistry.get_card(&"definitely_not_a_card"), "未知卡牌应返回 null")
