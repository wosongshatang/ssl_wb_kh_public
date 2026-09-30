extends GutTest
## 卡牌数据外置验证（工程书 §1.5 约束 2：数值一律 .tres，代码只读不算）
##
## 这些测试守着一条纪律：卡牌数值只能来自 `res://data/cards/*.tres`。
## 如果哪天有人在代码里 new 出一张写死数值的卡，这里的 `id 唯一` 与
## `目录可扫描` 断言会先出问题。

func before_all() -> void:
	ContentRegistry.load_all()


func test_starting_cards_are_registered() -> void:
	for card_id: StringName in [&"strike", &"defend", &"bash", &"iron_wave", &"shrug_it_off"]:
		assert_not_null(ContentRegistry.get_card(card_id), "应注册卡牌 %s" % card_id)


func test_strike_values_come_from_tres() -> void:
	var card: CardData = ContentRegistry.get_card(&"strike")
	assert_not_null(card)
	assert_eq(card.display_name, "打击")
	assert_eq(card.cost, 1)
	assert_eq(card.damage, 6)
	assert_eq(card.block, 0)
	assert_eq(card.type, CardData.CardType.ATTACK)


func test_defend_values_come_from_tres() -> void:
	var card: CardData = ContentRegistry.get_card(&"defend")
	assert_not_null(card)
	assert_eq(card.cost, 1)
	assert_eq(card.block, 5)
	assert_eq(card.damage, 0)
	assert_eq(card.type, CardData.CardType.SKILL)


func test_iron_wave_is_dual_purpose() -> void:
	## 攻防一体牌：damage 与 block 同时非零。
	## 这验证了 play_card 是**按字段驱动**而不是按类型分支——
	## 按类型分支的实现会把 block 整块丢掉。
	var card: CardData = ContentRegistry.get_card(&"iron_wave")
	assert_not_null(card)
	assert_eq(card.damage, 5)
	assert_eq(card.block, 5)


func test_all_card_ids_are_unique() -> void:
	var seen: Dictionary = {}
	var dir := DirAccess.open("res://data/cards")
	assert_not_null(dir, "data/cards 目录应存在")

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var card: Variant = load("res://data/cards/" + file_name)
			assert_true(card is CardData, "%s 应是 CardData" % file_name)
			if card is CardData:
				var data := card as CardData
				assert_false(seen.has(data.id), "卡牌 id 重复：%s（%s 与 %s）" % [
					data.id, seen.get(data.id, ""), file_name,
				])
				seen[data.id] = file_name
		file_name = dir.get_next()
	dir.list_dir_end()

	assert_gt(seen.size(), 0, "应至少注册一张卡牌")


func test_every_card_has_non_empty_id() -> void:
	var dir := DirAccess.open("res://data/cards")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var card: Variant = load("res://data/cards/" + file_name)
			if card is CardData:
				var data := card as CardData
				assert_ne(data.id, &"", "%s 的 id 不能为空（ContentRegistry 靠它建索引）" % file_name)
				assert_ne(data.display_name, "", "%s 的显示名不能为空" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
