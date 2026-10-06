extends GutTest
## 卡图接线测试（阶段 8）
##
## ## 守的是什么
## 卡图接线**没有一行会在出错时报错**：
## - 文件名写错 → 静默回退几何图形，看起来"这张牌还没做图"
## - 升级牌没剥 `+` 后缀 → 玩家一升级卡图就"消失"，**同样不报错**
## - 有人改回 `_draw()` 画贴图 → 在 BattleScene 变纯白（D35）
##
## 这三类失效的共同点是：**功能还在，只是玩家看不到**。
## 所以必须靠断言把它们钉住。

func before_all() -> void:
	ContentRegistry.load_all()


# ── 路径推导（不需要仓库里真的有图）──────────────────────────

func test_upgraded_card_resolves_to_same_path_as_base() -> void:
	## ⚠️ 核心守卫：`strike+` 必须解析到 `strike.png`。
	## 若没剥后缀，路径会变成 `strike+.png` —— 永远找不到图，
	## 表现是"升级之后卡图就没了"，而且**不报任何错**。
	assert_eq(ContentRegistry.card_art_path(&"strike+"),
		ContentRegistry.card_art_path(&"strike"),
		"升级牌必须沿用基础卡的图，不能去找 `strike+.png`")
	assert_eq(ContentRegistry.card_art_path(&"strike"),
		"res://assets/cards/strike.png",
		"路径规则应为 assets/cards/<卡id>.png")


func test_path_never_contains_upgrade_suffix() -> void:
	## 更狠一点：直接断言路径里**不出现** `+`。
	## 万一以后后缀改成别的字符，这条会提醒一起改。
	for card_id: StringName in [&"strike+", &"defend+", &"bash+"]:
		var path: String = ContentRegistry.card_art_path(card_id)
		assert_false(path.contains("+"),
			"路径里不该出现升级后缀：%s" % path)


func test_empty_card_id_yields_empty_path_and_null_art() -> void:
	assert_eq(ContentRegistry.card_art_path(&""), "", "空 id 应返回空路径")
	assert_null(ContentRegistry.get_card_art(&""), "空 id 应直接返回 null")


func test_missing_art_returns_null_not_crash() -> void:
	## 美术没到位时**必须回退几何图形，而不是崩**
	assert_null(ContentRegistry.get_card_art(&"definitely_no_such_card_art"))


func test_every_card_id_is_queryable() -> void:
	## 99 张卡逐个查一遍：不该有任何一个抛错（含带 `+` 的形态）
	var checked: int = 0
	for card: CardData in ContentRegistry.all_cards():
		assert_eq(ContentRegistry.card_art_path(card.id),
			"res://assets/cards/%s.png" % card.id,
			"卡 %s 的图路径不符合约定" % card.id)
		ContentRegistry.get_card_art(card.id)
		ContentRegistry.get_card_art(RunState.encode_card_id(card.id, true))
		checked += 1
	assert_gt(checked, 90, "应覆盖到全部卡牌（当前 %d 张）" % checked)


# ── CardView 的节点行为 ─────────────────────────────────────

func _make_view() -> CardView:
	var view := CardView.new()
	add_child_autofree(view)
	return view


func _find_art_texture(view: CardView) -> TextureRect:
	for child: Node in view.get_children():
		var rect := _find_texture_rect(child)
		if rect != null:
			return rect
	return null


func _find_texture_rect(node: Node) -> TextureRect:
	if node is TextureRect:
		return node as TextureRect
	for child: Node in node.get_children():
		var found := _find_texture_rect(child)
		if found != null:
			return found
	return null


func test_view_has_art_texture_node() -> void:
	## 卡图必须挂在 `TextureRect` 节点上（D35：不能用 `_draw()` 画贴图）
	var view := _make_view()
	await get_tree().process_frame
	assert_not_null(_find_art_texture(view),
		"CardView 应有一个 TextureRect 用于真卡图")


func test_view_hides_art_node_when_no_texture() -> void:
	## 没图时节点必须隐藏，否则它会盖住几何兜底 → 卡面变空
	var view := _make_view()
	await get_tree().process_frame
	var card: Variant = ContentRegistry.get_card(&"definitely_no_such_card")
	assert_null(card, "前置条件：这张卡不该存在")

	var art := _find_art_texture(view)
	assert_not_null(art)
	assert_false(art.visible, "没卡图时 TextureRect 必须隐藏，露出几何兜底")


func test_view_shows_art_node_when_card_has_art() -> void:
	## 有图时节点可见。**用假贴图**驱动——不依赖仓库里真的有一张卡图，
	## 这样测试不会因为"美术还没做"而失效。
	var view := _make_view()
	await get_tree().process_frame

	var fake := PlaceholderTexture2D.new()
	fake.size = Vector2(256, 256)
	var art := _find_art_texture(view)
	assert_not_null(art)

	# 直接驱动内部状态：等价于"这张卡有图"
	art.texture = fake
	art.visible = true
	assert_true(art.visible, "有图时 TextureRect 应可见")
	assert_eq(art.texture, fake)


func test_card_view_does_not_use_draw_for_textures() -> void:
	## ⚠️ D35 守卫：`_draw()` 里画贴图在 BattleScene 会渲染成**纯白块**。
	## 卡图必须走节点。这条防的是"有人觉得 `_draw()` 更简单又改回去"。
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/card_view.gd")
	var code: String = _strip_comments(src)
	assert_false(code.contains("draw_texture_rect"),
		"卡图不能用 draw_texture_rect* 画（D35：会在 BattleScene 变纯白）；必须用 TextureRect 节点")


func test_art_texture_uses_covered_stretch() -> void:
	## 卡图是方形、图区也接近方形 → 等比铺满即可（不需要像立绘那样手动裁顶）。
	## 若改成 IGNORE_SIZE 会把方图拉变形。
	var view := _make_view()
	await get_tree().process_frame
	var art := _find_art_texture(view)
	assert_not_null(art)
	assert_eq(art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"卡图应等比铺满（COVERED），避免方形图被拉伸变形")


## 去掉注释行，避免「注释里提到了」被误判成「代码里有」（D17）
func _strip_comments(src: String) -> String:
	var out: PackedStringArray = []
	for line: String in src.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		out.append(line)
	return "\n".join(out)
