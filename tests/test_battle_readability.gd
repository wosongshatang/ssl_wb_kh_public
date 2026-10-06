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

	view.set_scene(&"warrior", 99)

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


# ══ 阶段 8：真背景图接线 ═══════════════════════════════════════

func test_background_path_follows_convention() -> void:
	## 约定：assets/backgrounds/<角色>_act<幕>.png
	assert_eq(ContentRegistry.battle_background_path(&"warrior", 1),
		"res://assets/backgrounds/warrior_act1.png")
	assert_eq(ContentRegistry.battle_background_path(&"mage", 2),
		"res://assets/backgrounds/mage_act2.png")
	assert_eq(ContentRegistry.battle_background_path(&"hunter", 3),
		"res://assets/backgrounds/hunter_act3.png")


func test_background_path_rejects_invalid_input() -> void:
	assert_eq(ContentRegistry.battle_background_path(&"", 1), "", "空角色 id 应返回空路径")
	assert_eq(ContentRegistry.battle_background_path(&"warrior", 0), "", "幕号 0 无效")
	assert_eq(ContentRegistry.battle_background_path(&"warrior", -1), "", "负幕号无效")


func test_every_line_act_has_a_queryable_path() -> void:
	## 九张图逐个查一遍：不该有任何一个抛错（有没有图另说）
	var checked: int = 0
	for character: Variant in MapManager.LINES.keys():
		for act: int in [1, 2, 3]:
			var path: String = ContentRegistry.battle_background_path(
				StringName(str(character)), act)
			assert_true(path.begins_with("res://assets/backgrounds/"),
				"路径前缀不对：%s" % path)
			ContentRegistry.get_battle_background(StringName(str(character)), act)
			checked += 1
	assert_eq(checked, 9, "三线三幕应恰好 9 张")


func test_shipped_backgrounds_load_and_are_landscape() -> void:
	## 已入库的三张必须能加载，且是**横构图**（背景不是立绘）
	var shipped: Array = [
		[&"warrior", 1], [&"mage", 2], [&"hunter", 3],
	]
	for entry: Array in shipped:
		var tex: Texture2D = ContentRegistry.get_battle_background(entry[0], entry[1])
		assert_not_null(tex, "%s 第 %d 幕的背景图应存在" % [entry[0], entry[1]])
		if tex != null:
			assert_gt(tex.get_width(), tex.get_height(),
				"背景应是横构图（宽 > 高）")


func test_missing_background_returns_null_not_crash() -> void:
	## 还没做的六张必须安全返回 null（回退程序化背景），而不是崩
	assert_null(ContentRegistry.get_battle_background(&"warrior", 2),
		"第 2 幕还没有真图，应返回 null")
	assert_null(ContentRegistry.get_battle_background(&"no_such_line", 1))


func test_background_hides_image_node_when_no_texture() -> void:
	## 没图时必须隐藏节点，否则空 TextureRect 会盖住程序化背景 → 一片空白
	var view := BattleBackground.new()
	add_child_autofree(view)
	view.set_scene(&"warrior", 2)  # 第 2 幕无图

	assert_not_null(view._image)
	assert_false(view._image.visible, "缺图时真图节点必须隐藏，露出程序化背景")


func test_background_shows_image_node_when_texture_exists() -> void:
	var view := BattleBackground.new()
	add_child_autofree(view)
	view.set_scene(&"warrior", 1)  # 第 1 幕有图

	assert_true(view._image.visible, "有图时真图节点应可见")
	assert_not_null(view._image.texture)


func test_background_sets_scene_before_tree_entry() -> void:
	## 回归：先 `new()` → `set_scene()` → 再 `add_child()` 的顺序
	## 曾会让 `_image` 还是 null、图永远贴不上——**不报任何错**。
	var view := BattleBackground.new()
	view.set_scene(&"warrior", 1)   # 还没进树
	add_child_autofree(view)        # 这时才 _ready()
	await get_tree().process_frame

	assert_not_null(view._image)
	assert_true(view._image.visible, "进树后必须补上真图（_ready 里要再刷新一次）")


func test_crop_preserves_bottom_edge() -> void:
	## ⚠️ 核心：裁切必须**保住底边**。
	## 环境图的构图约定是「下半部是地面」，从正中裁会把地面切掉，
	## 角色看起来**浮在半空**。所以只能从顶部裁。
	var fake := PlaceholderTexture2D.new()
	fake.size = Vector2(1536, 1024)

	var view := BattleBackground.new()
	add_child_autofree(view)
	view.set_scene(&"warrior", 1)
	var cropped: Texture2D = view._crop_to_viewport_aspect(fake)

	var atlas := cropped as AtlasTexture
	assert_not_null(atlas, "非 16:9 的图应被裁成 AtlasTexture")
	if atlas != null:
		var bottom: float = atlas.region.position.y + atlas.region.size.y
		assert_almost_eq(bottom, 1024.0, 0.5,
			"裁切后底边必须仍贴着原图底边（地面不能被切）")
		var want: float = 1280.0 / 720.0
		assert_almost_eq(atlas.region.size.x / atlas.region.size.y, want, 0.01,
			"裁出的高宽比应等于视口比例（否则后续会再被 COVERED 裁一次）")


func test_crop_leaves_matching_image_untouched_when_ground_is_high() -> void:
	## 已经匹配比例、且地面线本来就在安全位置 → 不该裁（裁了反而丢内容）
	var fake := PlaceholderTexture2D.new()
	fake.size = Vector2(1600, 900)   # 正好 16:9

	var view := BattleBackground.new()
	add_child_autofree(view)
	view.set_scene(&"warrior", 1)    # 竞技场：地面线 0.337，很高
	var result: Texture2D = view._crop_to_viewport_aspect(fake)

	assert_false(result is AtlasTexture, "比例与地面都合适时应原样返回")


# ── 地面线对齐（角色不能浮空）──────────────────────────────

func test_every_shipped_background_has_a_ground_ratio() -> void:
	## 新增背景图必须补一行地面线比例，否则会退回默认值、可能让角色浮空
	for key: String in ["warrior_act1", "mage_act2", "hunter_act3"]:
		assert_true(BattleBackground.BACKGROUND_GROUND_RATIO.has(key),
			"配置表缺少 %s 的地面线比例（换图后要重新量）" % key)


func test_ground_line_lands_above_actor_baseline() -> void:
	## ⚠️ 这条守的是**"角色不能浮在半空"**。
	## 角色脚底在视口 0.48 处；地面线必须落在 GROUND_LINE_MAX(0.44) 或更高，
	## 角色才像站在场景里。
	for entry: Array in [[&"warrior", 1], [&"mage", 2], [&"hunter", 3]]:
		var view := BattleBackground.new()
		add_child_autofree(view)
		view.set_scene(entry[0], entry[1])

		var tex: Texture2D = ContentRegistry.get_battle_background(entry[0], entry[1])
		assert_not_null(tex, "%s_act%d 应有背景图" % [entry[0], entry[1]])
		if tex == null:
			continue

		var cropped: Texture2D = view._crop_to_viewport_aspect(tex)
		var region: Vector2 = cropped.get_size()
		var src: Vector2 = tex.get_size()
		# 裁剪后的窗口在原图中的位置
		var atlas := cropped as AtlasTexture
		var top: float = atlas.region.position.y if atlas != null else 0.0
		var ground_row: float = src.y * view._ground_ratio()
		var ground_screen: float = (ground_row - top) / region.y

		assert_lte(ground_screen, BattleBackground.GROUND_LINE_MAX + 0.02,
			"%s_act%d 的地面线落在 %.2f，低于上限 %.2f —— 角色会浮空"
			% [entry[0], entry[1], ground_screen, BattleBackground.GROUND_LINE_MAX])


func test_upscale_factor_is_one_for_well_composed_background() -> void:
	## 构图正常的图不该被放大（竞技场地面很高）
	var view := BattleBackground.new()
	add_child_autofree(view)
	view.set_scene(&"warrior", 1)
	var tex: Texture2D = ContentRegistry.get_battle_background(&"warrior", 1)

	assert_almost_eq(view._upscale_factor(tex), 1.0, 0.02,
		"竞技场构图正常，不该被放大")


func test_upscale_warning_threshold_is_documented() -> void:
	## 放大是有画质代价的，阈值必须是个明确的小数字（而不是"随便"）
	assert_gt(BattleBackground.UPSCALE_WARN, 1.0, "阈值应 > 1（否则没放大也告警）")
	assert_lte(BattleBackground.UPSCALE_WARN, 1.5, "阈值太大就失去提醒意义")


func test_ground_line_max_leaves_room_above_actor_feet() -> void:
	## 地面线上限必须**严格小于**角色脚底(0.48)，否则角色会站在地平线上
	assert_lt(BattleBackground.GROUND_LINE_MAX, 0.48,
		"地面线上限必须高于角色脚底，才像站在场景里")


func test_image_node_ignores_mouse() -> void:
	## ⚠️ 背景若吃掉鼠标事件，**整个战斗界面的点击都会失效**
	var view := BattleBackground.new()
	add_child_autofree(view)
	view.set_scene(&"warrior", 1)

	assert_eq(view.mouse_filter, Control.MOUSE_FILTER_IGNORE, "背景本身不接鼠标")
	assert_eq(view._image.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"真图节点也不接鼠标——否则卡牌拖拽、按钮点击全废")


func test_image_node_is_first_child_so_it_stays_behind() -> void:
	## 层级：背景必须是**最底层**。真图节点若是后加的，会盖住名字/血条等子控件。
	var view := BattleBackground.new()
	add_child_autofree(view)
	view.set_scene(&"warrior", 1)

	assert_eq(view.get_child(0), view._image,
		"真图节点必须是第一个子节点，才在最底层")


func test_background_does_not_use_draw_for_textures() -> void:
	## ⚠️ D35 守卫：`_draw()` 里画贴图在 BattleScene 会渲染成**纯白**。
	## 真图必须走 TextureRect 节点。
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/battle_background.gd")
	var code: String = _strip_comments(src)
	assert_false(code.contains("draw_texture_rect"),
		"背景真图不能用 draw_texture_rect* 画（D35：会变纯白）；必须用 TextureRect 节点")


func test_procedural_draw_is_skipped_when_image_present() -> void:
	## 有真图时程序化绘制应被跳过（图会完整盖住它，画了纯属浪费）。
	## 这里查源码，因为"少画了"这件事没法用断言直接观测。
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/battle_background.gd")
	var code: String = _strip_comments(src)
	assert_true(code.contains("if _image != null and _image.visible:"),
		"`_draw()` 开头应有「有真图就提前返回」的短路")


## 去掉注释行，避免「注释里提到了」被误判成「代码里有」（D17）
func _strip_comments(src: String) -> String:
	var out: PackedStringArray = []
	for line: String in src.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)
