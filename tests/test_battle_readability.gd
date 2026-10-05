extends GutTest
## 战斗可读性测试（阶段 6）：意图显示 + 按幕背景
##
## 守的是一条核心体验：**看不到敌人意图 = 玩家只能盲打 = 这个游戏的核心决策不存在。**

func before_all() -> void:
	ContentRegistry.load_all()


# ══ 意图可读性 ══════════════════════════════════════════════

func test_every_intent_type_has_text_color_and_icon() -> void:
	for intent_type: int in [
		IntentData.IntentType.ATTACK,
		IntentData.IntentType.DEFEND,
		IntentData.IntentType.BUFF,
		IntentData.IntentType.DEBUFF,
	]:
		var intent := IntentData.new()
		intent.type = intent_type
		intent.value = 5

		assert_ne(intent.display_text(), "?", "意图类型 %d 没有显示文本" % intent_type)
		assert_ne(intent.icon_text(), "·", "意图类型 %d 没有图标" % intent_type)
		assert_true(intent.color().a > 0.0, "意图类型 %d 没有配色" % intent_type)


func test_attack_intent_shows_multi_hit() -> void:
	var intent := IntentData.new()
	intent.type = IntentData.IntentType.ATTACK
	intent.value = 5
	intent.times = 2

	assert_true(intent.display_text().contains("×"), "多段攻击必须显示段数")


func test_attack_and_defend_have_distinct_colors() -> void:
	## 颜色必须能区分"要防"和"不用防"
	var attack := IntentData.new()
	attack.type = IntentData.IntentType.ATTACK
	var defend := IntentData.new()
	defend.type = IntentData.IntentType.DEFEND

	assert_ne(attack.color(), defend.color())


func test_every_pool_enemy_has_a_readable_intent() -> void:
	## 池子里每个敌人都必须能给出**玩家看得懂**的意图
	for act: int in [1, 2, 3]:
		for enemy_id: Variant in MapManager.combat_pool(&"warrior", act):
			var data: EnemyData = ContentRegistry.get_enemy(StringName(str(enemy_id)))
			var enemy := Enemy.new()
			enemy.setup_from_data(data)
			autofree(enemy)

			var intent: IntentData = enemy.current_intent()
			assert_not_null(intent, "%s 没有当前意图" % enemy_id)
			assert_ne(intent.display_text(), "?", "%s 的意图无法读懂" % enemy_id)


func test_combat_actor_view_handles_null_intent() -> void:
	## 玩家自己 / 已死亡敌人不该显示意图——传 null 必须安全
	var view := CombatActorView.new()
	add_child_autofree(view)

	view.set_intent(null)

	assert_false(view._intent_box.visible, "传 null 时应隐藏意图框")


func test_combat_actor_view_shows_intent() -> void:
	var view := CombatActorView.new()
	add_child_autofree(view)

	var intent := IntentData.new()
	intent.type = IntentData.IntentType.ATTACK
	intent.value = 7
	view.set_intent(intent)

	assert_true(view._intent_box.visible)
	assert_true(view._intent_label.text.contains("7"), "意图文本应含数值")


# ══ 按幕背景 ════════════════════════════════════════════════

func test_every_act_has_a_background_theme() -> void:
	for act: int in [1, 2, 3]:
		assert_true(BattleBackground.ACT_THEMES.has(act), "第 %d 幕没有背景配色" % act)


func test_act_backgrounds_are_visually_distinct() -> void:
	## 三幕背景必须**一眼可辨**——纯黑背景会让三幕看起来完全一样，
	## 玩家感受不到"我推进到下一幕了"
	var themes: Array = []
	for act: int in [1, 2, 3]:
		themes.append(BattleBackground.ACT_THEMES[act])

	for i: int in themes.size():
		for j: int in range(i + 1, themes.size()):
			assert_ne(themes[i]["sky_top"], themes[j]["sky_top"],
				"第 %d 幕与第 %d 幕的天空色相同" % [i + 1, j + 1])
			assert_ne(themes[i]["prop"], themes[j]["prop"],
				"第 %d 幕与第 %d 幕的道具风格相同" % [i + 1, j + 1])


func test_every_theme_has_all_required_keys() -> void:
	for act: int in [1, 2, 3]:
		var theme: Dictionary = BattleBackground.ACT_THEMES[act]
		for key: String in ["sky_top", "sky_bottom", "ground", "accent", "prop"]:
			assert_true(theme.has(key), "第 %d 幕的配色缺少 %s" % [act, key])


func test_unknown_act_falls_back_to_a_valid_theme() -> void:
	var view := BattleBackground.new()
	add_child_autofree(view)

	view.set_act(99)

	assert_true(view._theme().has("sky_top"), "未知幕号应回退到有效配色")


func test_act_theme_matches_act_name() -> void:
	## 背景风格要与幕名对得上（竞技场↔看台 / 战场↔旌旗 / 古战场↔残柱）
	assert_eq(str(BattleBackground.ACT_THEMES[1]["prop"]), "stands")
	assert_eq(MapManager.act_name(&"warrior", 1), "竞技场")
	assert_eq(str(BattleBackground.ACT_THEMES[2]["prop"]), "banners")
	assert_eq(MapManager.act_name(&"warrior", 2), "战场")
	assert_eq(str(BattleBackground.ACT_THEMES[3]["prop"]), "ruins")
	assert_eq(MapManager.act_name(&"warrior", 3), "古战场")


func test_background_has_a_drawable_area_when_sized() -> void:
	## 回归：背景控件尺寸为 0 → `_draw()` 一开头就 return →
	## **"背景根本没画"且不报任何错**（用户实际遇到的就是这个）
	var view := BattleBackground.new()
	add_child_autofree(view)
	view.size = Vector2(1280, 720)

	assert_gt(view._draw_rect_area().size.x, 1.0)
	assert_gt(view._draw_rect_area().size.y, 1.0)


func test_background_falls_back_to_viewport_size() -> void:
	## size 退化时回退到视口尺寸——背景是整屏元素，
	## "画大一点"永远比"什么都没画"好
	var view := BattleBackground.new()
	add_child_autofree(view)
	view.size = Vector2.ZERO

	assert_gt(view._draw_rect_area().size.x, 1.0, "尺寸为 0 时应回退到视口尺寸")
	assert_gt(view._draw_rect_area().size.y, 1.0)
