extends GutTest
## 阶段 10 · 进阶模式（Ascension）
##
## ## 本文件守的核心是**累积性**
## 进阶 5 必须同时开着 1~5 的全部效果。这是最容易写错、也最难发现的一类：
## 写成"每级各管各的"时，**每一级单独看都是对的**，
## 只有"进阶 5 到底有几条在生效"能测出来。
##
## ## 另一类是"接上了但没生效"
## 效果判定写对了、调用点没接（或接在了错的顺序上），表现成
## "进阶开了但打起来一样"，不报错。所以每条效果都断言**可观测的结果**
## （血量 / 价格 / 权重 / 界面文字），而不是只断言"配置表里有这条"。
##
## ## 数值换算全部走 `Ascension` / `EventData` 的**静态函数**
## 这样测试不需要把整个战斗 / 地图场景建起来。顺带解决了一个硬约束：
## `BattleScene` / `MapScene` 是场景根脚本（无 `class_name`），
## 测试里只能靠 `Variant` 动态派发去调它们——一调就触发
## "类型从 Variant 推断"的警告，而**本项目把警告当错误**。

const MAX := Ascension.MAX_LEVEL


func before_all() -> void:
	ContentRegistry.load_all()


func before_each() -> void:
	MetaState.reset()


func after_each() -> void:
	MetaState.reset()


# ══ ① 配置表自身的自洽 ═══════════════════════════════════════

func test_table_covers_every_level_exactly_once() -> void:
	## 表里的等级必须是 1..MAX 连续且不重复。
	##
	## 为什么必须连续：`has()` 靠"等级 <= level"累加。少一级不会有任何报错，
	## 只会让某一级**白给**（选了它难度不涨），而这在体感上极难发现。
	var seen: Array[int] = []
	for entry: Dictionary in Ascension.LEVEL_EFFECTS:
		var lv: int = int(entry["level"])
		assert_false(seen.has(lv), "等级 %d 在表里出现了两次" % lv)
		seen.append(lv)
	seen.sort()
	assert_eq(seen.size(), MAX, "表里的条目数应等于 MAX_LEVEL")
	for i: int in MAX:
		assert_eq(seen[i], i + 1, "等级应连续：缺了 %d" % (i + 1))


func test_effect_ids_are_unique() -> void:
	var ids: Array[StringName] = []
	for entry: Dictionary in Ascension.LEVEL_EFFECTS:
		var eid := StringName(entry["id"])
		assert_false(ids.has(eid), "效果 id 重复：%s" % eid)
		ids.append(eid)


func test_every_effect_has_text() -> void:
	## 界面要显示这些文字。空文字的表现是"选进阶时右边一片空白"，
	## 玩家不知道自己在选什么，但不会报错。
	for level: int in range(1, MAX + 1):
		assert_ne(Ascension.new_effect_text(level), "",
			"进阶 %d 没有说明文字" % level)


func test_effect_texts_have_sane_percentages() -> void:
	## ★ 这条守的是一类**纯文案 bug**：常量本身已经是百分数，
	## 拼字符串时又乘了一次 100 → 显示"休息点回血 −3000%"。
	##
	## 为什么必须单独测：倍率本身是**对的**，任何行为断言都测不出来；
	## 而玩家一眼就看出数字离谱。第一版就是这么写的，靠渲染截图才发现。
	##
	## 所以直接扫文案里的所有百分数，超过 100% 一律视为"乘了两次"。
	var re := RegEx.new()
	re.compile("(\\d+)%")
	for level: int in range(1, MAX + 1):
		var text: String = Ascension.new_effect_text(level)
		for m: RegExMatch in re.search_all(text):
			var pct: int = int(m.get_string(1))
			assert_lte(pct, 100,
				"进阶 %d 的文案里出现了 %d%%（大概率是百分数被乘了两次）：%s"
					% [level, pct, text])


func test_rest_heal_text_matches_its_constant() -> void:
	## 上一条的**正例**：文案里的数字必须来自常量，不能各写一遍。
	var text: String = Ascension.new_effect_text(7)
	assert_true(text.contains("%d%%" % Ascension.REST_HEAL_PENALTY),
		"进阶 7 的文案应含 %d%%（实际：%s）" % [Ascension.REST_HEAL_PENALTY, text])


# ══ ② 累积性（本文件的核心）══════════════════════════════════

func test_higher_levels_include_all_lower_effects() -> void:
	## ★ 进阶 N 包含 1..N 的**全部**效果，且不包含 N+1..MAX 的任何一条。
	for level: int in range(1, MAX + 1):
		for other: int in range(1, MAX + 1):
			var eid := Ascension.new_effect_id(other)
			var should_have: bool = other <= level
			assert_eq(Ascension.has(level, eid), should_have,
				"进阶 %d 对「进阶 %d 的效果 %s」的判定应为 %s"
					% [level, other, eid, should_have])


func test_level_zero_has_nothing() -> void:
	for level: int in range(1, MAX + 1):
		assert_false(Ascension.has(0, Ascension.new_effect_id(level)),
			"进阶 0 不该有任何进阶效果")


func test_all_effect_texts_grows_with_level() -> void:
	for level: int in range(0, MAX + 1):
		assert_eq(Ascension.all_effect_texts(level).size(), level,
			"进阶 %d 的累积效果条数应为 %d" % [level, level])


func test_unknown_effect_is_false() -> void:
	assert_false(Ascension.has(MAX, &"no_such_effect"),
		"未知效果必须返回 false，不能崩也不能误判为真")
	assert_false(Ascension.has(MAX, &""))


func test_level_name_and_validity() -> void:
	assert_eq(Ascension.level_name(0), "进阶 0")
	assert_eq(Ascension.level_name(7), "进阶 7")
	assert_true(Ascension.is_valid_level(0))
	assert_true(Ascension.is_valid_level(MAX))
	assert_false(Ascension.is_valid_level(-1))
	assert_false(Ascension.is_valid_level(MAX + 1))


# ══ ③ RunState 承载与存档 ════════════════════════════════════

func test_start_new_run_records_level() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1, 7)
	assert_eq(run.ascension, 7)
	assert_true(run.has_ascension(&"weaker_rest"), "进阶 7 应包含休息回血惩罚")


func test_start_new_run_clamps_out_of_range() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1, 999)
	assert_eq(run.ascension, MAX, "越界等级必须钳到 MAX")
	run.start_new_run(&"warrior", 1, -5)
	assert_eq(run.ascension, 0, "负等级必须钳到 0")


func test_default_level_is_zero() -> void:
	## 默认 0 是**有意的**：几十处测试与调试路径调用 `start_new_run`
	## 时不该被迫关心进阶，否则每加一条效果都要改一大片。
	var run := RunState.new()
	run.start_new_run(&"warrior", 1)
	assert_eq(run.ascension, 0)
	assert_false(run.has_ascension(&"less_gold"))


func test_ascension_survives_save_roundtrip() -> void:
	var run := RunState.new()
	run.start_new_run(&"mage", 42, 9)

	var restored := RunState.new()
	restored.from_dict(run.to_dict())
	assert_eq(restored.ascension, 9, "读档必须还原进阶等级")
	assert_eq(restored.character_class, &"mage")


func test_old_save_without_ascension_key_is_level_zero() -> void:
	## 老存档没有 `ascension` 键 → 视作 0。
	## 不能"猜"一个等级，猜高等于白送难度。
	var data: Dictionary = RunState.new().to_dict()
	data.erase("ascension")
	var run := RunState.new()
	run.from_dict(data)
	assert_eq(run.ascension, 0)


func test_lower_start_hp_applies_at_6_not_5() -> void:
	## 边界：进阶 5 不该扣血，进阶 6 该扣。
	var at5 := RunState.new()
	at5.start_new_run(&"warrior", 1, 5)
	var at6 := RunState.new()
	at6.start_new_run(&"warrior", 1, 6)

	assert_eq(at5.max_hp, RunState.DEFAULT_MAX_HP, "进阶 5 还不该扣初始生命")
	assert_eq(at6.max_hp, RunState.DEFAULT_MAX_HP - Ascension.START_HP_PENALTY,
		"进阶 6 应扣 %d 点初始最大生命" % Ascension.START_HP_PENALTY)


func test_lower_start_hp_does_not_leave_hp_above_max() -> void:
	## ★ 扣血必须在 `hp = max_hp` **之前**。
	## 顺序反了会变成 hp > max_hp（开局比满血还多），表现成
	## "选了进阶反而更肉"，而且不报错。
	var run := RunState.new()
	run.start_new_run(&"warrior", 1, 6)
	assert_eq(run.hp, run.max_hp, "开局血量必须等于（已被扣减的）上限")
	assert_lte(run.hp, run.max_hp)


# ══ ④ MetaState：解锁进度与调试开关 ══════════════════════════

func test_new_character_starts_at_level_zero() -> void:
	assert_eq(MetaState.unlocked_ascension_level(&"warrior"), 0)


func test_clearing_a_level_unlocks_the_next() -> void:
	MetaState.record_ascension_clear(&"warrior", 0)
	assert_eq(MetaState.unlocked_ascension_level(&"warrior"), 1)

	MetaState.record_ascension_clear(&"warrior", 1)
	assert_eq(MetaState.unlocked_ascension_level(&"warrior"), 2)


func test_unlock_is_per_character() -> void:
	MetaState.record_ascension_clear(&"warrior", 0)
	assert_eq(MetaState.unlocked_ascension_level(&"mage"), 0,
		"战士的解锁不该影响法师")


func test_clearing_a_low_level_does_not_downgrade() -> void:
	## 重打低进阶不该把进度打回去。
	MetaState.record_ascension_clear(&"warrior", 5)
	MetaState.record_ascension_clear(&"warrior", 0)
	assert_eq(MetaState.unlocked_ascension_level(&"warrior"), 6,
		"重打低进阶不该降低已解锁等级")


func test_clearing_max_level_does_not_overflow() -> void:
	MetaState.record_ascension_clear(&"warrior", MAX)
	assert_eq(MetaState.unlocked_ascension_level(&"warrior"), MAX,
		"通关最高进阶后不该解锁出 %d" % (MAX + 1))


func test_debug_switch_unlocks_everything() -> void:
	## ★ 用户明确要求的"一次性开启全部进阶"开关。
	assert_eq(MetaState.unlocked_ascension_level(&"warrior"), 0)
	MetaState.set_unlock_all_ascension(true)
	for character: StringName in [&"warrior", &"mage", &"hunter"]:
		assert_eq(MetaState.unlocked_ascension_level(character), MAX,
			"调试开关应让 %s 的全部进阶可选" % character)


func test_debug_switch_restores_real_progress_when_off() -> void:
	## 关掉开关要回到**真实进度**，不是清零——
	## 否则"调完忘了关"会顺手把玩家记录抹掉。
	MetaState.record_ascension_clear(&"warrior", 2)
	MetaState.set_unlock_all_ascension(true)
	assert_eq(MetaState.unlocked_ascension_level(&"warrior"), MAX)
	MetaState.set_unlock_all_ascension(false)
	assert_eq(MetaState.unlocked_ascension_level(&"warrior"), 3,
		"关掉开关应回到真实进度 3")


func test_debug_switch_is_not_persisted() -> void:
	## ★ 调试开关**不能**进存档。
	## 存下来的话，下次启动就是"我以为在玩普通模式，其实全解锁了"——
	## 玩家会以为自己解锁过全部进阶，而且**没有任何提示**。
	MetaState.set_unlock_all_ascension(true)
	assert_false(MetaState.to_dict().has("unlock_all_ascension"),
		"调试开关不该出现在存档里")


func test_unlock_progress_survives_save_roundtrip() -> void:
	MetaState.record_ascension_clear(&"hunter", 4)
	var snapshot: Dictionary = MetaState.to_dict()

	MetaState.reset()
	assert_eq(MetaState.unlocked_ascension_level(&"hunter"), 0)

	MetaState.from_dict(snapshot)
	assert_eq(MetaState.unlocked_ascension_level(&"hunter"), 5,
		"解锁进度必须能存下来")


func test_meta_snapshot_is_not_aliased() -> void:
	## `to_dict()` 必须 duplicate()——否则调用方拿到快照后一旦 reset()，
	## 快照会跟着被清空。这类别名 bug 不报错，只会让"我刚存的数据呢"变成玄学。
	MetaState.record_ascension_clear(&"warrior", 3)
	var snapshot: Dictionary = MetaState.to_dict()
	MetaState.reset()
	var restored: Dictionary = snapshot.get("ascension_unlocked", {}) as Dictionary
	assert_eq(int(restored.get("warrior", 0)), 4,
		"快照应不受后续 reset() 影响")


# ══ ⑤ 各条效果的实际生效 ═════════════════════════════════════

func test_card_pool_rarity_shift_lowers_high_rarities() -> void:
	## 进阶 2：稀有度下移。
	var rare := _card_of_rarity(CardData.Rarity.RARE)
	if rare == null:
		pass_test("卡池里没有蓝卡，跳过")
		return
	var normal := CardPool.new(RandomNumberGenerator.new())
	var shifted := CardPool.new(RandomNumberGenerator.new(), &"", true,
		Ascension.rarity_weight_multiplier(2))

	assert_gt(normal.weight_of(rare), shifted.weight_of(rare),
		"开启稀有度下移后蓝卡权重应下降")
	assert_gte(shifted.weight_of(rare), 1, "权重不能降到 0（否则永远抽不到）")


func test_rarity_shift_does_not_touch_common() -> void:
	## 白色是地板，不再削——否则高进阶会变成"全是灰牌"，那不是变难是变没得选。
	var common := _card_of_rarity(CardData.Rarity.COMMON)
	if common == null:
		pass_test("卡池里没有白卡，跳过")
		return
	var normal := CardPool.new(RandomNumberGenerator.new())
	var shifted := CardPool.new(RandomNumberGenerator.new(), &"", true,
		Ascension.rarity_weight_multiplier(2))
	assert_eq(normal.weight_of(common), shifted.weight_of(common),
		"白色权重不该被稀有度下移影响")


func test_card_pool_for_run_reads_ascension() -> void:
	var run := RunState.new()
	run.start_new_run(&"warrior", 1, 1)   # 进阶 1 还没有稀有度下移
	assert_false(CardPool.for_run(RandomNumberGenerator.new(), run).rarity_shift)

	run.start_new_run(&"warrior", 1, 2)   # 进阶 2 开始
	assert_true(CardPool.for_run(RandomNumberGenerator.new(), run).rarity_shift,
		"进阶 2 应让战斗奖励启用稀有度下移")


func test_card_pool_for_run_handles_null_run() -> void:
	## 调试路径可能没有 run——不能崩。
	assert_false(CardPool.for_run(RandomNumberGenerator.new(), null).rarity_shift)


func test_rarity_weight_multiplier() -> void:
	assert_eq(Ascension.rarity_weight_multiplier(1), 1.0, "进阶 1 还不该削稀有度")
	assert_eq(Ascension.rarity_weight_multiplier(2), Ascension.RARITY_WEIGHT_MULTIPLIER)
	assert_lt(Ascension.rarity_weight_multiplier(2), 1.0)


func test_enemy_hp_bonus_per_kind() -> void:
	## 进阶 4 精英 / 8 普通 / 9 Boss，各自只在该等级之后生效。
	## 全部走 `Ascension` 的纯函数——不需要把整个战斗场景建起来。
	# 进阶 3：都还没加
	assert_eq(Ascension.enemy_hp_bonus(3, false, false), 0.0)
	assert_eq(Ascension.enemy_hp_bonus(3, true, false), 0.0)
	assert_eq(Ascension.enemy_hp_bonus(3, false, true), 0.0)

	# 进阶 4：只有精英
	assert_eq(Ascension.enemy_hp_bonus(4, true, false), Ascension.ELITE_HP_BONUS)
	assert_eq(Ascension.enemy_hp_bonus(4, false, false), 0.0, "进阶 4 不该影响普通敌人")
	assert_eq(Ascension.enemy_hp_bonus(4, false, true), 0.0, "进阶 4 不该影响 Boss")

	# 进阶 8：精英 + 普通
	assert_eq(Ascension.enemy_hp_bonus(8, false, false), Ascension.COMMON_HP_BONUS)
	assert_eq(Ascension.enemy_hp_bonus(8, true, false), Ascension.ELITE_HP_BONUS)
	assert_eq(Ascension.enemy_hp_bonus(8, false, true), 0.0, "进阶 8 还不该影响 Boss")

	# 进阶 9：三类全加
	assert_eq(Ascension.enemy_hp_bonus(9, false, true), Ascension.BOSS_HP_BONUS)
	assert_eq(Ascension.enemy_hp_bonus(9, false, false), Ascension.COMMON_HP_BONUS)
	assert_eq(Ascension.enemy_hp_bonus(9, true, false), Ascension.ELITE_HP_BONUS)


func test_enemy_scaling_does_not_mutate_the_shared_resource() -> void:
	## ★★ 这条守的是本项目踩过的**同一类坑**：
	## `ContentRegistry.get_enemy()` 返回**缓存里的共享实例**，
	## 直接改 `max_hp` 会把加成写回缓存 → 每打一场再涨一次 → 无限增长，且不报错。
	## 所以 `Ascension.scale_enemy_hp` 必须先 duplicate()。
	var base := _enemy_data(false, false)
	base.max_hp = 40

	var scaled: EnemyData = Ascension.scale_enemy_hp(base, 8)
	assert_ne(scaled, base, "必须返回副本，不能是同一个对象")
	assert_eq(base.max_hp, 40, "★ 原对象不能被改动（否则每场战斗都会再涨一次）")
	assert_gt(scaled.max_hp, base.max_hp, "副本的生命应被提升")

	# 再调一次，原对象仍不变（模拟第二场战斗）
	Ascension.scale_enemy_hp(base, 8)
	assert_eq(base.max_hp, 40, "★ 反复调用也不能让原对象累积增长")


func test_enemy_scaling_returns_same_object_when_no_bonus() -> void:
	## 没有加成时应**原样返回**（不复制）——每场战斗都复制一份纯属浪费，
	## 而且会让"这个敌人是不是被改过"变得无从判断。
	var base := _enemy_data(false, false)
	base.max_hp = 40
	assert_same(Ascension.scale_enemy_hp(base, 0), base,
		"无加成时应原样返回同一个对象")


func test_enemy_scaling_never_reaches_zero_hp() -> void:
	## 极端数据下也不能把生命算成 0——0 血敌人会让战斗直接结束，且看起来像"没生成"。
	var base := _enemy_data(false, false)
	base.max_hp = 1
	var scaled: EnemyData = Ascension.scale_enemy_hp(base, 8)
	assert_gte(scaled.max_hp, 1, "提升后的生命至少是 1")


func test_gold_penalty_applies_from_level_1() -> void:
	var base: int = 20
	assert_eq(Ascension.gold_reward(0, base), base, "进阶 0 不该扣金币")
	assert_eq(Ascension.gold_reward(1, base), base - Ascension.GOLD_PENALTY,
		"进阶 1 起战斗金币应扣 %d" % Ascension.GOLD_PENALTY)
	assert_eq(Ascension.gold_reward(MAX, base), base - Ascension.GOLD_PENALTY,
		"金币惩罚不叠加（只扣一次）")


func test_gold_reward_never_goes_negative() -> void:
	## 负金币会让"打完反而欠钱"，商店逻辑也没处理过负值。
	assert_gte(Ascension.gold_reward(MAX, 0), 0, "金币奖励不能为负")
	assert_gte(Ascension.gold_reward(MAX, 5), 0, "基础奖励小于惩罚时也不能为负")


func test_shop_price_markup() -> void:
	## 进阶 5：商店 +25%。
	assert_eq(Ascension.shop_price_markup(4), 1.0, "进阶 4 还不该涨价")
	assert_eq(Ascension.shop_price_markup(5), 1.0 + Ascension.SHOP_PRICE_BONUS)


func test_shop_price_markup_never_zeroes_a_price() -> void:
	## 0 价 = 白送。倍率取整后可能变 0，必须钳到 1。
	var panel := ShopPanel.new()
	add_child_autofree(panel)
	panel._price_markup = 0.0
	assert_gte(panel._marked_price(55), 1, "价格不能算成 0（等于白送）")


func test_shop_panel_applies_the_markup() -> void:
	var panel := ShopPanel.new()
	add_child_autofree(panel)
	panel._price_markup = 1.0
	assert_eq(panel._marked_price(100), 100)
	panel._price_markup = 1.0 + Ascension.SHOP_PRICE_BONUS
	assert_eq(panel._marked_price(100), 125,
		"进阶 5 应让 100 金币的东西卖 125")


func test_rest_heal_multiplier() -> void:
	assert_eq(Ascension.rest_heal_multiplier(6), 1.0, "进阶 6 还不该削休息回血")
	assert_eq(Ascension.rest_heal_multiplier(7), Ascension.REST_HEAL_MULTIPLIER)
	assert_lt(Ascension.rest_heal_multiplier(7), 1.0)


func test_rest_heal_display_and_settlement_share_one_function() -> void:
	## ★ 展示与结算必须走**同一个函数**。
	## 之前 `_open_rest` 与 `_on_rest_chosen` 各写了一遍同样的算式，
	## 改一处就会让"面板说回 9 点、实际回 6 点"；进阶 7 又给这条算式
	## 加了一层乘法，重复写必错。
	var src: String = FileAccess.get_file_as_string("res://scripts/map/map_scene.gd")
	var open_rest: int = src.find("func _open_rest")
	var on_rest: int = src.find("func _on_rest_chosen")
	assert_gt(open_rest, -1, "找不到 _open_rest")
	assert_gt(on_rest, -1, "找不到 _on_rest_chosen")
	var open_body: String = src.substr(open_rest, on_rest - open_rest)
	assert_true(open_body.contains("_rest_heal_amount()"),
		"`_open_rest` 必须用共用的 _rest_heal_amount()，不能自己再算一遍")
	var rest_body: String = src.substr(on_rest, 500)
	assert_true(rest_body.contains("_rest_heal_amount()"),
		"`_on_rest_chosen` 必须用共用的 _rest_heal_amount()")


func test_event_negative_values_are_amplified() -> void:
	var m: float = Ascension.event_penalty_multiplier(3)
	assert_gt(m, 1.0)

	var dmg: int = EventData.ascend_value(EventData.Effect.DAMAGE, 10, m)
	assert_gt(dmg, 10, "进阶 3 应让扣血变多")

	var gold: int = EventData.ascend_value(EventData.Effect.GOLD, -20, m)
	assert_lt(gold, -20, "进阶 3 应让扣钱变多")

	var curse: int = EventData.ascend_value(EventData.Effect.ADD_CURSE_CARD, 1, m)
	assert_gt(curse, 1, "进阶 3 应让诅咒变多")


func test_event_curse_scaling_handles_zero_count() -> void:
	## ★ 老数据里 `ADD_CURSE_CARD` 的 value 是 0（视作 1 张）。
	## 直接乘的话 0 × 1.5 = 0，这条进阶对**所有老事件**静默失效。
	var m: float = Ascension.event_penalty_multiplier(3)
	assert_gt(EventData.ascend_value(EventData.Effect.ADD_CURSE_CARD, 0, m), 1,
		"value=0（老数据）也必须被放大到 2 张")


func test_event_positive_values_are_untouched() -> void:
	## ★ 只放大"确定是坏事"的方向。
	## 放大奖励（回血 / 进账）等于让进阶变成福利——正好反过来。
	var m: float = Ascension.event_penalty_multiplier(MAX)
	assert_eq(EventData.ascend_value(EventData.Effect.HEAL, 10, m), 10,
		"回血是奖励，不该被放大")
	assert_eq(EventData.ascend_value(EventData.Effect.GOLD, 50, m), 50,
		"进账是奖励，不该被放大")
	assert_eq(EventData.ascend_value(EventData.Effect.MAX_HP, 5, m), 5,
		"加最大生命是奖励，不该被放大")
	assert_eq(EventData.ascend_value(EventData.Effect.REMOVE_CARD, 1, m), 1,
		"删牌不缩放（多数构筑里是好事，放大反而帮玩家）")


func test_event_scaling_is_off_below_level_3() -> void:
	assert_eq(Ascension.event_penalty_multiplier(2), 1.0)
	assert_eq(EventData.ascend_value(EventData.Effect.DAMAGE, 10, 1.0), 10,
		"倍率为 1.0 时必须原样返回")


# ══ ⑥ 进阶 10：隐藏敌人意图 ══════════════════════════════════

func test_hidden_intent_does_not_leak_through_text() -> void:
	var view := CombatActorView.new()
	add_child_autofree(view)
	view.hide_intent = true
	view.set_intent(IntentData.make_attack(12))

	var shown: String = view.intent_text()
	assert_false(shown.contains("12"), "隐藏时不能显示伤害数值")
	assert_false(shown.contains("攻击"), "隐藏时不能显示意图类型")


func test_hidden_intent_does_not_leak_through_color() -> void:
	## ★★ 这条最容易漏：图标（⚔/◈/▲/▼）与颜色（红/蓝/绿/紫）**各自**
	## 都一一对应意图类型。只换文字的话，玩家看颜色就知道该格挡还是该挨打——
	## 功能看起来实现了，实际泄露 100% 信息。
	##
	## 所以这里比对"攻击"和"防御"两种意图在隐藏模式下**渲染结果必须一致**。
	var attack_view := CombatActorView.new()
	add_child_autofree(attack_view)
	attack_view.hide_intent = true
	attack_view.set_intent(IntentData.make_attack(12))

	var defend_view := CombatActorView.new()
	add_child_autofree(defend_view)
	defend_view.hide_intent = true
	defend_view.set_intent(IntentData.make_defend(9))

	assert_eq(attack_view.intent_text(), defend_view.intent_text(),
		"★ 攻击与防御在隐藏模式下必须显示成一样——否则颜色/图标泄露了意图类型")
	assert_ne(attack_view.intent_text(), "", "隐藏时仍应显示一个占位符")


func test_intent_is_visible_when_not_hidden() -> void:
	## 对照组：不开进阶时意图必须正常显示（防止"修隐藏把正常显示也弄坏了"）。
	var view := CombatActorView.new()
	add_child_autofree(view)
	view.hide_intent = false
	view.set_intent(IntentData.make_attack(12))
	assert_true(view.intent_text().contains("12"),
		"未开启进阶 10 时必须正常显示意图数值")


func test_hidden_intents_effect_is_level_10() -> void:
	assert_false(Ascension.has(9, &"hidden_intents"), "进阶 9 还不该隐藏意图")
	assert_true(Ascension.has(10, &"hidden_intents"))


func test_battle_scene_hides_intent_from_ascension() -> void:
	## 源码级：战斗场景建敌人视图时必须把 `hide_intent` 接上。
	## 只加字段不接线的话，进阶 10 **完全不生效**且不报错——
	## 玩家看到的是"我选了进阶 10，敌人意图还是明明白白"。
	var src: String = FileAccess.get_file_as_string("res://scripts/battle/battle_scene.gd")
	assert_true(src.contains("hide_intent = _run.has_ascension(&\"hidden_intents\")"),
		"BattleScene 必须按进阶等级设置 enemy_view.hide_intent")


# ══ 工具 ════════════════════════════════════════════════════

func _card_of_rarity(rarity: int) -> CardData:
	for card: CardData in ContentRegistry.all_cards():
		if card.rarity == rarity:
			return card
	return null


func _enemy_data(elite: bool, boss: bool) -> EnemyData:
	var data := EnemyData.new()
	data.id = &"test_enemy"
	data.display_name = "测试敌人"
	data.max_hp = 40
	data.is_elite = elite
	data.is_boss = boss
	return data
