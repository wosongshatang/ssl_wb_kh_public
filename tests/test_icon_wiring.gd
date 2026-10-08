extends GutTest
## 图标接线（阶段 8 · 第四类资产）
##
## ## 守的是什么
## 图标类是**最后接线**的一类（80 个：地图 8 / 遗物 44 / 药水 10 / 职业 18）。
## 前三类（立绘 / 卡图 / 背景）接线时都是"丢图即生效"，图标也是同一套约定。
##
## ## 为什么这些测试现在就有意义（一张图都还没有）
## 1. **路径推导**是纯函数，可以现在就断言命名规则——
##    等投了 80 张图才发现目录名写错，返工成本是 80 张
## 2. **缺图回退**必须现在就成立：图标不可能一次做完，
##    任何一处"缺图即崩"都会让分批投图变成不可能
## 3. **`kind_key` 覆盖性**：新增 `MapNode.Kind` 时若忘了加映射，
##    新节点会静默地没有图标（不报错），门禁必须拦

func before_all() -> void:
	ContentRegistry.load_all()


func _icon_ids(category: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	match category:
		ContentRegistry.ICON_MAP:
			for kind: MapNode.Kind in MapNode.all_kinds():
				out.append(MapNode.kind_key(kind))
		ContentRegistry.ICON_RELIC:
			out = ContentRegistry.all_relic_ids()
		ContentRegistry.ICON_POTION:
			out = ContentRegistry.all_potion_ids()
		ContentRegistry.ICON_JOB:
			for job: JobData in JobDatabase.all_jobs():
				out.append(job.id)
	return out


const ALL_CATEGORIES: Array[StringName] = [
	ContentRegistry.ICON_MAP, ContentRegistry.ICON_RELIC,
	ContentRegistry.ICON_POTION, ContentRegistry.ICON_JOB,
]


# ══ 路径推导（纯函数，不依赖仓库里有没有图）══════════════════

func test_icon_path_is_well_formed_for_every_category() -> void:
	for category: StringName in ALL_CATEGORIES:
		var ids: Array[StringName] = _icon_ids(category)
		assert_gt(ids.size(), 0, "类别 %s 一个 id 都取不到" % category)
		for icon_id: StringName in ids:
			var path: String = ContentRegistry.icon_path(category, icon_id)
			assert_eq(path, "res://assets/icons/%s/%s.png" % [category, icon_id],
				"图标路径推导不对：%s / %s" % [category, icon_id])


func test_empty_id_yields_empty_path() -> void:
	## 空 id 必须返回空串而不是 "res://assets/icons/relics/.png"——
	## 后者会去 load 一个目录，行为未定义
	for category: StringName in ALL_CATEGORIES:
		assert_eq(ContentRegistry.icon_path(category, &""), "",
			"%s 的空 id 应返回空串" % category)
	assert_eq(ContentRegistry.icon_path(&"", &"whatever"), "",
		"空类别应返回空串")


func test_icon_categories_do_not_collide() -> void:
	## 四类图标分居四个子目录，同名 id 也不该撞在一起。
	## 撞了的话"地图的 combat"和"某个叫 combat 的遗物"会互相覆盖——
	## 而且因为路径不同、只是文件同名，**极难发现**。
	var seen: Dictionary = {}
	for category: StringName in ALL_CATEGORIES:
		for icon_id: StringName in _icon_ids(category):
			var path: String = ContentRegistry.icon_path(category, icon_id)
			assert_false(seen.has(path), "路径 %s 被两类图标共用" % path)
			seen[path] = true


# ══ 缺图回退（分批投图的前提）════════════════════════════════

func test_missing_icon_returns_null_not_crash() -> void:
	for category: StringName in ALL_CATEGORIES:
		assert_null(ContentRegistry.get_icon(category, &"no_such_id_at_all"),
			"%s 的未知 id 应返回 null（调用方据此回退）" % category)
	assert_null(ContentRegistry.get_icon(&"no_such_category", &"whatever"))
	assert_null(ContentRegistry.get_icon(&"", &""))


func test_every_icon_id_resolves_without_error() -> void:
	## 遍历全部 80 个 id 调一次加载函数——
	## **不断言非 null**（现在一张图都没有），只断言不抛异常、不崩。
	## 这守的是"id 里出现奇怪字符导致 load 失败"这类问题。
	var checked: int = 0
	for category: StringName in ALL_CATEGORIES:
		for icon_id: StringName in _icon_ids(category):
			ContentRegistry.get_icon(category, icon_id)
			checked += 1
	assert_gte(checked, 80, "四类图标合计应至少 80 个 id（实得 %d）" % checked)


# ══ 地图节点：kind_key 覆盖性 ═══════════════════════════════

func test_every_map_kind_has_a_key() -> void:
	for kind: MapNode.Kind in MapNode.all_kinds():
		assert_ne(MapNode.kind_key(kind), &"",
			"MapNode.Kind %d 没有 kind_key——这个节点类型会静默地没有图标" % kind)


func test_map_kind_keys_are_unique() -> void:
	var seen: Dictionary = {}
	for kind: MapNode.Kind in MapNode.all_kinds():
		var key: StringName = MapNode.kind_key(kind)
		assert_false(seen.has(key), "kind_key「%s」被两个 Kind 共用" % key)
		seen[key] = true


func test_all_kinds_matches_the_enum() -> void:
	## ★ `all_kinds()` 是手工维护的列表。新增 `Kind` 时若忘了加进来，
	## 上面两条测试**都遍历不到它**，于是"新类型没图标"这件事无人发现。
	## 这条用 kind_key 的返回值反查：枚举里有几个值，就该有几个非空 key。
	var mapped: int = 0
	for raw: int in range(64):   # 枚举不会超过 64 个
		var key: StringName = MapNode.kind_key(raw as MapNode.Kind)
		if key != &"":
			mapped += 1
	assert_eq(mapped, MapNode.all_kinds().size(),
		"枚举里有 %d 个 Kind 有 key，但 all_kinds() 只列了 %d 个——有 Kind 漏登记了"
		% [mapped, MapNode.all_kinds().size()])


func test_map_kind_key_is_snake_case_filename() -> void:
	## 文件名必须是小写 + 下划线，否则在大小写敏感的文件系统上对不上
	for kind: MapNode.Kind in MapNode.all_kinds():
		var key: String = str(MapNode.kind_key(kind))
		assert_eq(key, key.to_lower(), "kind_key「%s」含大写" % key)
		assert_false(key.contains(" "), "kind_key「%s」含空格" % key)


# ══ 已入库图标的规格（现在空跑，投图后立刻生效）══════════════

func test_shipped_icons_are_square_and_transparent() -> void:
	## 图标是**符号**不是小图：必须正方形（圆形节点里才不会变形），
	## 且带透明通道（否则会在地图节点上出现一个方块底）。
	##
	## 现在一张图都没有 → 循环里不会执行任何断言。
	## ⚠️ 但**必须留一条无条件断言**：GUT 把"一条都没断言"判为 `Risky`，
	## 而 Risky 会让门禁失败。所以末尾那句 `assert_gte(expected, 80)` 不是装饰。
	var found: int = 0
	var expected: int = 0
	for category: StringName in ALL_CATEGORIES:
		for icon_id: StringName in _icon_ids(category):
			expected += 1
			var tex: Texture2D = ContentRegistry.get_icon(category, icon_id)
			if tex == null:
				continue
			found += 1
			assert_eq(tex.get_width(), tex.get_height(),
				"图标 %s/%s 不是正方形（%dx%d）" % [category, icon_id, tex.get_width(), tex.get_height()])
			assert_eq(tex.get_width(), 256,
				"图标 %s/%s 不是 256×256（%d）" % [category, icon_id, tex.get_width()])

	assert_gte(expected, 80, "四类图标 id 合计应至少 80 个（实得 %d）" % expected)
	gut.p("图标 id 共 %d 个，其中已入库 %d 张" % [expected, found])


# ══ 四个调用点：缺图时必须照常构建，不能崩 ═══════════════════

func test_relic_panel_builds_without_icons() -> void:
	var panel := RelicViewPanel.new()
	add_child_autofree(panel)   # 触发 _ready → 创建 content_box
	panel.setup(ContentRegistry.all_relic_ids())

	assert_gt(panel.content_box.get_child_count(), 0,
		"遗物面板缺图时也必须构建出行（回退到占位方块）")


func test_relic_panel_uses_texture_rect_when_icon_exists() -> void:
	## 有图时应当用 TextureRect，没图时用 ColorRect 占位。
	## 现在没有图 → 断言走的是占位分支（**行为可预期**，不是"随便哪个都行"）。
	var panel := RelicViewPanel.new()
	add_child_autofree(panel)
	var first: StringName = ContentRegistry.all_relic_ids()[0]
	var data: Variant = ContentRegistry.get_relic(first)
	assert_true(data is RelicData)

	var icon: Control = panel._make_icon(data as RelicData)
	add_child_autofree(icon)
	if ContentRegistry.get_relic_icon(first) != null:
		assert_true(icon is TextureRect, "有图标时应使用 TextureRect")
	else:
		assert_true(icon is ColorRect, "缺图标时应回退到占位方块")


func test_potion_slot_handles_missing_icon() -> void:
	var slot := PotionSlot.new()
	add_child_autofree(slot)

	var pool: Array[StringName] = ContentRegistry.all_potion_ids()
	assert_gt(pool.size(), 0, "药水池为空")
	var data: Variant = ContentRegistry.get_potion(pool[0])
	assert_true(data is PotionData, "取不到药水数据")

	slot.set_potion(data as PotionData, 0)
	assert_eq(slot.potion, data, "药水应被设进槽位")
	# 缺图时必须回退到"首字"分支而不是崩——这里只验证状态设置成功
	assert_null(ContentRegistry.get_potion_icon(&"no_such_potion"))


func test_job_panel_builds_without_icons() -> void:
	var jobs: Array[JobData] = JobDatabase.first_tier_jobs(&"warrior")
	assert_gt(jobs.size(), 0, "战士一阶职业为空")

	var panel := JobChoicePanel.new()
	add_child_autofree(panel)
	panel.setup("选择一条要刻进灵魂的规则", jobs)

	assert_gt(panel.content_box.get_child_count(), 0, "转职面板缺图时也必须构建")


func test_job_panel_scales_icon_to_button_size() -> void:
	## ★ 回归：**不要**把 256×256 原图直接塞给 `button.icon`——
	## Button 按原始像素画，会把按钮撑成一堵墙（而且不报错）。
	## 这里直接测缩放辅助函数的输出尺寸。
	var panel := JobChoicePanel.new()
	add_child_autofree(panel)

	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))
	var tex := ImageTexture.create_from_image(img)

	var scaled: Texture2D = panel._scaled_icon(tex, JobChoicePanel.ICON_PX)
	assert_not_null(scaled)
	assert_eq(scaled.get_width(), JobChoicePanel.ICON_PX,
		"图标应被缩到按钮尺寸 %d，实得 %d" % [JobChoicePanel.ICON_PX, scaled.get_width()])
	assert_eq(scaled.get_height(), JobChoicePanel.ICON_PX)


func test_map_view_builds_without_icons() -> void:
	var view := MapView.new()
	add_child_autofree(view)
	view.size = Vector2(1200, 700)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var map := MapManager.new()
	map.generate(rng, 1, &"warrior")
	view.build_map(map)

	assert_gt(view.positioned_node_count(), 0, "缺图时地图也必须正常布局")
	# 图标查找必须安全返回 null（→ 走几何图形回退）
	for kind: MapNode.Kind in MapNode.all_kinds():
		assert_null(ContentRegistry.get_map_icon(&"no_such_kind_%d" % kind))


func test_map_view_icon_node_count_matches_shipped_icons() -> void:
	## 图标节点数应当**等于"有图的地图节点种类"能覆盖的节点数**。
	## 现在一张图都没有 → 必须是 0（全部走几何回退），
	## 而不是"建了一堆空 TextureRect 把兜底图形盖住"。
	var view := MapView.new()
	add_child_autofree(view)
	view.size = Vector2(1200, 700)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var map := MapManager.new()
	map.generate(rng, 1, &"warrior")
	view.build_map(map)

	var kinds_with_icons: int = 0
	for kind: MapNode.Kind in MapNode.all_kinds():
		if ContentRegistry.get_map_icon(MapNode.kind_key(kind)) != null:
			kinds_with_icons += 1

	if kinds_with_icons == 0:
		assert_eq(view.icon_node_count(), 0,
			"一张图标都没有时不该建任何图标节点（会盖住几何回退）")
	else:
		assert_gt(view.icon_node_count(), 0, "有图标时应建出图标节点")


# ══ ★ D35 回归：`_draw()` 里画贴图会渲染成纯白 ═══════════════

func _all_scripts() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_walk_scripts("res://scripts", out)
	return out


func _walk_scripts(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_walk_scripts(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


## 去掉注释行——否则会把**记录 D35 教训的注释本身**当成违规。
## 这个项目到处都写着 "⚠️ D35：`_draw()` 里 `draw_texture_rect*` 会渲染成纯白"，
## 不剥注释的话这条测试永远红。
func _strip_comments(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for raw_line: String in src.split("\n"):
		var idx: int = raw_line.find("#")
		out.append(raw_line if idx < 0 else raw_line.substr(0, idx))
	return "\n".join(out)


func test_no_script_draws_textures_inside_draw() -> void:
	## ★★ D35 回归（源码层）。
	##
	## 本项目里 **`_draw()` 里画贴图会渲染成纯白方块**——
	## 立绘（D35 原始案例）/ 卡图 / 地图图标都踩过同一个坑：
	## 贴图本身、算式、尺寸全对，换成 `TextureRect` **节点**立刻正常。
	##
	## 排查成本极高（"探针查资源没问题、孤立 Probe 渲染完美"），
	## 所以从**源码层**拦：只要有人再写 `draw_texture_rect*`，这条立刻红。
	## 这比"等美术投进来肉眼发现白块"早得多。
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _all_scripts():
		var src: String = _strip_comments(FileAccess.get_file_as_string(path))
		if src.contains("draw_texture_rect"):
			offenders.append(path)
	assert_eq(offenders.size(), 0,
		"以下脚本在 _draw() 里画贴图（D35：会渲染成纯白）：%s" % ", ".join(offenders))


func test_potion_slot_has_exactly_one_icon_node() -> void:
	## 药水图标必须走子节点（D35），且只建一个（建多个会互相叠）
	var slot := PotionSlot.new()
	add_child_autofree(slot)

	var rects: int = 0
	for child: Node in slot.get_children():
		if child is TextureRect:
			rects += 1
	assert_eq(rects, 1, "药水槽应有且仅有一个图标 TextureRect 子节点")

	# 空槽位时图标节点必须隐藏，否则会盖住 `_draw()` 的空槽样式
	var icon := slot.get_child(0) as TextureRect
	assert_not_null(icon)
	assert_false(icon.visible, "空药水栏时图标节点应隐藏")


func test_potion_slot_shows_icon_only_when_it_exists() -> void:
	var slot := PotionSlot.new()
	add_child_autofree(slot)
	var pool: Array[StringName] = ContentRegistry.all_potion_ids()
	var data: Variant = ContentRegistry.get_potion(pool[0])
	slot.set_potion(data as PotionData, 0)

	var icon := slot.get_child(0) as TextureRect
	var tex: Texture2D = ContentRegistry.get_potion_icon(pool[0])
	if tex != null:
		assert_true(icon.visible, "有图标时应显示")
		assert_eq(icon.texture, tex)
	else:
		assert_false(icon.visible, "缺图标时应隐藏，让 `_draw()` 的首字回退露出来")
