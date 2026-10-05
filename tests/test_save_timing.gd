extends GutTest
## 存档时机测试 —— **SL（读档重来）能不能用，全靠这一批**
##
## ## 为什么值得为"存档时机"单独写测试
## 它是一条**看不见的规则**：没有任何类型系统或编译器能表达
## "这个函数不该存档"。写错了不会报错，只会让玩家在买错东西时
## **发现自己唯一的补救手段被系统亲手毁掉了**。

func before_all() -> void:
	ContentRegistry.load_all()


## 读一个脚本的源码（用于检查"某个函数里没有某句话"）
func _source_of(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "读不到 %s" % path)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _function_body(source: String, func_name: String) -> String:
	var start: int = source.find("func %s(" % func_name)
	if start < 0:
		return ""
	# 到下一个顶层 func 为止
	var next: int = source.find("\nfunc ", start + 1)
	if next < 0:
		next = source.length()
	return _strip_comments(source.substr(start, next - start))


## 剥掉注释再断言。
##
## ⚠️ 不剥的话会被**注释里的词**骗到：`_on_node_selected` 的注释里就写了
## 「存档必须在 enter_node 之前」，于是"save_run 出现在 enter_node 之前"这句
## 断言会因为注释而误判。**和分层门禁是同一条教训（D17）。**
func _strip_comments(text: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		var hash_at: int = line.find("#")
		out.append(line if hash_at < 0 else line.substr(0, hash_at))
	return "\n".join(out)


# ══ ★ 核心：退出时不能存档 ══════════════════════════════════

func test_returning_to_title_does_not_save() -> void:
	## ⚠️ 这条守着一个**极容易写错、且错了没人发现**的规则。
	##
	## 存档时机是「进入节点时」——那是玩家的 SL 锚点。
	## 玩家在商店里买错了东西、想读档重来；
	## 如果"返回标题"顺手存了一次，存下去的会是"节点已访问"的状态，
	## SL 之后就**直接跳过这个节点**了。
	var source := _source_of("res://scripts/map/map_scene.gd")
	var body := _function_body(source, "_on_save_and_exit")

	assert_ne(body, "", "找不到 _on_save_and_exit（改名了？那这条测试要跟着改）")
	assert_false(body.contains("save_run"),
		"「返回标题」绝不能存档——它会把玩家唯一的补救手段毁掉")


func test_entering_a_node_creates_a_checkpoint() -> void:
	## 进入节点前必须存一次，否则玩家没有可以回退的锚点
	var source := _source_of("res://scripts/map/map_scene.gd")
	var body := _function_body(source, "_on_node_selected")

	assert_true(body.contains("save_run"), "进入节点前必须存一个检查点")
	# 而且必须在 enter_node **之前**——之后的话节点已被标记访问，SL 就晚了
	var save_at: int = body.find("save_run")
	var enter_at: int = body.find("enter_node")
	assert_true(save_at >= 0 and enter_at >= 0)
	assert_lt(save_at, enter_at,
		"存档必须在 enter_node 之前——之后存的话节点已标记访问，SL 回不去")


func test_shop_purchases_do_not_save_mid_node() -> void:
	## 商店内部买一件东西不该落盘——整个节点对玩家是**原子的**：
	## 要么全接受，要么读档重来。
	var source := _source_of("res://scripts/map/map_scene.gd")
	for handler: String in [
		"_on_purchase_requested", "_on_potion_purchase_requested",
		"_on_relic_purchase_requested", "_on_removal_requested",
	]:
		var body := _function_body(source, handler)
		assert_ne(body, "", "找不到 %s" % handler)
		assert_false(body.contains("save_run"),
			"%s 不该在节点内部落盘" % handler)


# ══ 节点是原子的 ════════════════════════════════════════════

func test_node_state_is_atomic_across_a_reload() -> void:
	## 端到端：检查点 → 改状态 → 读档 → 应回到检查点
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	var gold_before: int = run.gold
	var deck_before: int = run.deck_card_ids.size()

	# 「进入节点」= 存检查点
	var checkpoint := run.to_dict()

	# 「节点内部的操作」= 只改内存
	run.spend_gold(50)
	run.add_card(&"heavy_strike")

	# 「读档」= 从检查点恢复
	var restored := RunState.new()
	restored.from_dict(checkpoint)

	assert_eq(restored.gold, gold_before, "读档后金币应回到进节点之前")
	assert_eq(restored.deck_card_ids.size(), deck_before, "读档后牌组应回到进节点之前")
	autofree(run)
	autofree(restored)
