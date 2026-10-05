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


# ══ 立绘查表（阶段 8 接入点）═════════════════════════════════

func test_portrait_id_defaults_to_own_id() -> void:
	## ★ 「约定优于配置」：留空时用自己的 id，
	## 这样往 assets/portraits/ 丢一张 <id>.png 就直接生效，
	## **不用回头改 46 个 .tres**。
	var data: EnemyData = ContentRegistry.get_enemy(&"act1_combat")
	assert_eq(data.effective_portrait_id(), &"act1_combat",
		"没配 portrait_id 时应回退到自己的 id")


func test_explicit_portrait_id_wins() -> void:
	## 需要"两个敌人共用一张图"时可以显式指定
	var data := EnemyData.new()
	data.id = &"some_enemy"
	data.portrait_id = &"shared_beast"
	assert_eq(data.effective_portrait_id(), &"shared_beast")


func test_missing_portrait_returns_null_not_crash() -> void:
	## 美术没到位时**必须回退到几何剪影，而不是崩**
	assert_null(ContentRegistry.get_portrait(&"definitely_no_such_portrait"))
	assert_null(ContentRegistry.get_portrait(&""), "空 id 应直接返回 null")


func test_actor_view_falls_back_when_no_portrait() -> void:
	var view := CombatActorView.new()
	add_child_autofree(view)
	await get_tree().process_frame

	var enemy := Enemy.new()
	autofree(enemy)
	enemy.setup_from_data(ContentRegistry.get_enemy(&"act1_combat"))

	# 没有立绘资源，绑定不该报错
	view.bind(enemy, CombatActorView.Look.BRUTE, false, &"no_such_portrait")

	assert_eq(view.portrait_id, &"no_such_portrait")
	assert_true(view.creature == enemy, "缺图时仍应完成绑定")


# ── 阶段 8：三个主角立绘真的接进来了吗 ──────────────────────

func test_three_playable_portraits_exist() -> void:
	## 三个可选角色的 id 恰好就是 `RunState.character_class`。
	## 只要 `assets/portraits/<id>.png` 存在，约定自动生效——
	## 这条测试守的是「美术掉了 / 文件名写错了」这类静默失效。
	for character_id: StringName in [&"warrior", &"mage", &"hunter"]:
		var tex: Texture2D = ContentRegistry.get_portrait(character_id)
		assert_not_null(tex, "角色 %s 应有立绘 assets/portraits/%s.png" % [character_id, character_id])
		if tex != null:
			assert_gt(tex.get_width(), 0, "%s 立绘宽度应 > 0" % character_id)
			assert_gt(tex.get_height(), 0, "%s 立绘高度应 > 0" % character_id)


func test_every_playable_character_has_a_portrait() -> void:
	## 反向守：`MapManager.LINES` 里能选的每个角色都必须有图。
	## 以后新加角色忘了配图，这里会红——而不是等到玩家看到几何剪影才发现。
	for character_id: Variant in MapManager.LINES.keys():
		var id: StringName = StringName(str(character_id))
		assert_not_null(ContentRegistry.get_portrait(id),
			"可选角色 %s 缺少立绘（assets/portraits/%s.png）" % [id, id])


func test_player_view_receives_character_portrait_id() -> void:
	## ⚠️ 曾经的真 bug：敌人 / 盟友都传了 `effective_portrait_id()`，
	## **唯独玩家这一路留空** → 玩家永远回退几何剪影。
	## 这条测试守住「玩家也得按角色 id 取图」这个契约。
	##
	## 直接查源码，因为真正的接线在 battle_scene 里、需要完整战斗才能跑到。
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/battle_scene.gd")
	var code: String = _strip_comments(src)
	assert_true(code.contains("_player_view.bind(_player, CombatActorView.Look.WARRIOR, true, _run.character_class)"),
		"玩家视图必须把 `_run.character_class` 作为立绘 id 传进去；"
		+ "否则战士 / 法师 / 猎人的立绘永远显示不出来")


## 去掉注释行，避免「注释里提到了」被误判成「代码里有」（D17）
func _strip_comments(src: String) -> String:
	var out: PackedStringArray = []
	for line: String in src.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)


# ── 阶段 8：立绘必须走 TextureRect 节点，不能在 _draw() 里画（D34）─────

func test_portrait_uses_texture_rect_node_not_draw_call() -> void:
	## ⚠️ 曾经的真 bug（D34）：`_draw()` 里调 `draw_texture_rect_region` 画大立绘，
	## 在 BattleScene 里**整块渲染成纯白**，而孤立场景完全正常。
	## 换成 TextureRect 节点后立刻正常。
	##
	## 这条测试守住"别再改回 `_draw()`"——那是个调试了很久才定位的坑。
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/combat_actor_view.gd")
	var code: String = _strip_comments(src)
	assert_false(code.contains("draw_texture_rect_region"),
		"立绘不能用 draw_texture_rect_region 画（会在 BattleScene 里变白，见 D34）；"
		+ "必须用 TextureRect 节点")
	assert_false(code.contains("draw_texture_rect("),
		"同上：立绘必须用 TextureRect 节点，不要用 draw_texture_rect")


func test_bound_view_shows_portrait_node() -> void:
	## 有图时：TextureRect 节点可见且真的拿到了贴图。
	var view := CombatActorView.new()
	add_child_autofree(view)
	await get_tree().process_frame

	var enemy := Enemy.new()
	autofree(enemy)
	enemy.setup_from_data(ContentRegistry.get_enemy(&"act1_combat"))
	view.bind(enemy, CombatActorView.Look.BRUTE, false, &"warrior")

	assert_eq(view.portrait_id, &"warrior")

	var shown: bool = false
	for child: Node in view.get_children():
		if child is TextureRect:
			var rect := child as TextureRect
			if rect.visible and rect.texture != null:
				shown = true
	assert_true(shown,
		"给了立绘 id 且图存在时，TextureRect 应可见并带上贴图")


func test_missing_portrait_hides_node_and_falls_back() -> void:
	## 没图时：**不能出现"图和剪影同时显示"**，也不能白屏。
	## 节点必须可见性为 false，几何剪影接管。
	var view := CombatActorView.new()
	add_child_autofree(view)
	await get_tree().process_frame

	var enemy := Enemy.new()
	autofree(enemy)
	enemy.setup_from_data(ContentRegistry.get_enemy(&"act1_combat"))
	view.bind(enemy, CombatActorView.Look.BRUTE, false, &"definitely_no_such_portrait")

	# 找那个 TextureRect 子节点，确认它被隐藏了
	var found_hidden: bool = false
	for child: Node in view.get_children():
		if child is TextureRect:
			if not (child as TextureRect).visible:
				found_hidden = true
	assert_true(found_hidden,
		"缺图时 TextureRect 必须隐藏，否则会和几何剪影重叠成一团")


