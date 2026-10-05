extends GutTest
## 盟友 UI 测试
##
## ## 守的是什么
## 盟友是**玩家唯一看不见就会出事的东西**——它的存在、血量、死活
## 全都要在界面上体现。曾经它只存在于战斗日志里，
## 玩家召唤了熊却看不到它在哪、还剩多少血。

func before_all() -> void:
	ContentRegistry.load_all()


func test_beast_look_exists() -> void:
	## 盟友需要与敌人区分开的外观
	assert_true(CombatActorView.Look.has("BEAST"),
		"CombatActorView.Look 里应有 BEAST（召唤兽外观）")


func test_ally_view_can_bind() -> void:
	var view := CombatActorView.new()
	add_child_autofree(view)
	await get_tree().process_frame

	var ally := Ally.new()
	autofree(ally)
	ally.setup_from_data(ContentRegistry.get_ally(&"bear"))

	view.bind(ally, CombatActorView.Look.BEAST, true)

	assert_eq(view.creature, ally, "盟友应绑定到视图上")


func test_ally_data_loads() -> void:
	for ally_id: StringName in [&"wolf", &"bear", &"hawk", &"serpent"]:
		var data: Variant = ContentRegistry.get_ally(ally_id)
		assert_not_null(data, "盟友 %s 不存在" % ally_id)
		assert_gt((data as AllyData).max_hp, 0, "%s 的血量应为正" % ally_id)


func test_at_least_one_ally_taunts() -> void:
	## 嘲讽是盟友存在的意义——没有嘲讽，盟友只是"额外伤害"，
	## 而额外伤害用一张牌就能解决，不需要一个新实体系统。
	var taunting: int = 0
	for ally_id: StringName in [&"wolf", &"bear", &"hawk", &"serpent"]:
		if (ContentRegistry.get_ally(ally_id) as AllyData).is_taunt:
			taunting += 1
	assert_gt(taunting, 0, "至少要有一个嘲讽盟友，否则这个系统没有意义")


# ══ 视图同步（源码级：它必须在每次刷新时被调用）═════════════

func test_battle_scene_syncs_ally_views_on_refresh() -> void:
	## `allies` 的变动来源有三处（召唤 / 死亡 / 战斗重置），
	## 逐个监听容易漏；**每次刷新对齐**才不会漏。
	var source := FileAccess.get_file_as_string("res://scripts/battle/battle_scene.gd")
	var start: int = source.find("func _refresh_all(")
	assert_gt(start, 0)
	var end: int = source.find("\nfunc ", start + 1)
	var body: String = source.substr(start, end - start)

	assert_true(body.contains("_sync_ally_views"),
		"_refresh_all 必须对齐盟友视图——否则召唤/死亡后界面与状态不一致")


func test_ally_views_are_laid_out_between_player_and_enemies() -> void:
	## 站位要有意义：盟友在玩家与敌人之间，才看得出"它挡在你前面"
	var source := FileAccess.get_file_as_string("res://scripts/battle/battle_scene.gd")
	assert_true(source.contains("ALLY_X_RATIO"), "盟友应有独立站位比例")
	assert_true(source.contains("_ally_views[i].position"), "_layout 应给盟友定位")
