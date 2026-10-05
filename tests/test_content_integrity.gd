extends GutTest
## 内容引用完整性审计（门禁第 ⑥ 步）
##
## ## 为什么用 GDScript 而不是外部脚本
## 直接读 [ContentRegistry]——**注册表怎么解析，审计就怎么解析**。
## 正则扫 `.tres` 只能看到文本，看不到"这个 id 到底能不能被工厂造出来"。
##
## ## 它守的是什么
## 这一批错误**不报错、测试也不红**：
## 引用了一个不存在的 id，运行时只会得到 null，
## 然后被静默跳过——玩家看到的是"这个机制好像没生效"。
##
## 曾经真实发生过：
##   · 事件 payload 写的是 `placeholder_event_N` → 两个真事件从未被触发
##   · 法师/猎人的 6 个幕环境只有代码没有 `.tres` → **整条线的机制完全没跑过**
##
## ⚠️ 为什么是测试文件而不是独立脚本
## `-s script.gd` 模式下 Autoload 在**编译期**不可见（`ContentRegistry` 会报
## "Identifier not found"）。放进 GUT 就天然跑在正常场景上下文里，
## 而且失败会在门禁里直接可见。

var _problems: PackedStringArray = PackedStringArray()


func before_all() -> void:
	ContentRegistry.load_all()


func test_all_content_references_resolve() -> void:
	_problems = PackedStringArray()
	_check_count = 0

	_audit_jobs()
	_audit_enemies()
	_audit_cards()
	_audit_relics()
	_audit_potions()
	_audit_lines()
	_audit_events()

	# 必须**无条件**断言一次：只靠 fail_test 的话，
	# 全过的情况下这个测试没有任何断言 → GUT 会把它标成 "risky"，
	# 而 risky 在门禁里同样是失败。
	assert_true(_problems.is_empty(),
		"发现 %d 处断引用（共检查 %d 项）：\n%s" % [
			_problems.size(), _check_count, "\n".join(_problems)])
	assert_gt(_check_count, 0, "检查项为 0 —— 审计脚本本身没跑起来")


var _check_count: int = 0


func _fail(message: String) -> void:
	_problems.append(message)


func _ok() -> void:
	_check_count += 1


# ══ 职业 ════════════════════════════════════════════════════

func _audit_jobs() -> void:
	for job_id: StringName in ContentRegistry.all_job_ids():
		var job: JobData = ContentRegistry.get_job(job_id)

		for card_id: StringName in job.job_card_ids:
			_check_count += 1
			if ContentRegistry.get_card(card_id) == null:
				_fail("职业 %s 的 job_card_ids 引用了不存在的卡「%s」" % [job_id, card_id])

		for card_id: StringName in job.signature_card_ids:
			_check_count += 1
			if ContentRegistry.get_card(card_id) == null:
				_fail("职业 %s 的专属卡「%s」不存在" % [job_id, card_id])

		for power_id: StringName in job.identity_power_ids:
			_check_count += 1
			if IdentityPowers.create(power_id) == null:
				_fail("职业 %s 的身份能力「%s」造不出来" % [job_id, power_id])

		# 镜像双向引用
		if job.is_mirror():
			continue
		if not job.is_first_tier() and job.mirror_job_id == &"":
			# 只有终职必须有镜像——一阶不参与神战
			_fail("终职 %s 没有配 mirror_job_id（神战 P4 会静默什么都不做）" % job_id)
		elif job.mirror_job_id != &"":
			_check_count += 1
			var mirror: JobData = JobDatabase.get_job(job.mirror_job_id)
			if mirror == null:
				_fail("职业 %s 的镜像「%s」不存在" % [job_id, job.mirror_job_id])
			elif mirror.mirror_of != job_id:
				_fail("镜像 %s 的反向引用指向「%s」，与正向不符" % [mirror.id, mirror.mirror_of])


# ══ 敌人 ════════════════════════════════════════════════════

func _audit_enemies() -> void:
	for enemy_id: StringName in ContentRegistry.all_enemy_ids():
		var data: EnemyData = ContentRegistry.get_enemy(enemy_id)

		for power_id: StringName in data.identity_power_ids:
			_check_count += 1
			if IdentityPowers.create(power_id) == null:
				_fail("敌人 %s 的身份能力「%s」造不出来" % [enemy_id, power_id])

		_audit_intents(data.intents, "敌人 %s" % enemy_id)

		for i: int in data.phases.size():
			var phase: EnemyPhase = data.phases[i]
			for power_id: StringName in phase.identity_power_ids:
				_check_count += 1
				if IdentityPowers.create(power_id) == null:
					_fail("敌人 %s 形态「%s」的能力「%s」造不出来" % [
						enemy_id, phase.display_name, power_id])
			_audit_intents(phase.intents, "敌人 %s 形态「%s」" % [enemy_id, phase.display_name])

			# 形态必须按 hp_ratio 降序——否则 phase_index_for 会选错
			if i > 0 and phase.hp_ratio > data.phases[i - 1].hp_ratio:
				_fail("敌人 %s 的形态 %d 阈值（%.2f）高于前一形态（%.2f）——应降序排列" % [
					enemy_id, i, phase.hp_ratio, data.phases[i - 1].hp_ratio])

		if data.max_hp <= 0:
			_fail("敌人 %s 的血量为 %d" % [enemy_id, data.max_hp])


func _audit_intents(intents: Array[IntentData], owner_label: String) -> void:
	for intent: IntentData in intents:
		if intent.power_id == &"":
			continue
		_check_count += 1
		if PowerFactory.create(intent.power_id, 1) == null:
			_fail("%s 的意图引用了造不出来的 Power「%s」" % [owner_label, intent.power_id])


# ══ 卡牌 ════════════════════════════════════════════════════

func _audit_cards() -> void:
	for card: CardData in ContentRegistry.all_cards():
		_audit_power_table(card.apply_to_self, "卡牌 %s 的 apply_to_self" % card.id)
		_audit_power_table(card.apply_to_target, "卡牌 %s 的 apply_to_target" % card.id)

		if card.summon_ally_id != &"":
			_check_count += 1
			if ContentRegistry.get_ally(card.summon_ally_id) == null:
				_fail("卡牌 %s 召唤的盟友「%s」不存在" % [card.id, card.summon_ally_id])

		# 描述里的占位符必须都能被替换——否则卡面会显示 `{damage}` 这种东西
		_check_count += 1
		var rendered: String = card.format_description()
		if rendered.contains("{"):
			_fail("卡牌 %s 的描述有未替换的占位符：%s" % [card.id, rendered])


func _audit_power_table(table: Dictionary, owner_label: String) -> void:
	for raw_id: Variant in table:
		var power_id := StringName(str(raw_id))
		_check_count += 1
		if PowerFactory.create(power_id, 1) == null:
			_fail("%s 引用了造不出来的 Power「%s」" % [owner_label, power_id])


# ══ 遗物 / 药水 ═════════════════════════════════════════════

func _audit_relics() -> void:
	for relic_id: StringName in ContentRegistry.all_relic_ids():
		_check_count += 1
		if RelicFactory.create(relic_id) == null:
			_fail("遗物 %s 有 .tres 但工厂造不出来" % relic_id)

	# 每个可转职的职业都要有职业遗物
	for job: JobData in JobDatabase.all_jobs():
		_check_count += 1
		if JobRelics.for_job(job.id) == &"":
			_fail("职业 %s 没有对应遗物" % job.id)


func _audit_potions() -> void:
	for potion_id: StringName in ContentRegistry.all_potion_ids():
		var potion: PotionData = ContentRegistry.get_potion(potion_id)
		_check_count += 1
		if potion.display_name == "":
			_fail("药水 %s 没有名字" % potion_id)


# ══ 地图线路 ════════════════════════════════════════════════

func _audit_lines() -> void:
	for character: Variant in MapManager.LINES:
		var character_id := StringName(str(character))
		var lines: Array = MapManager.LINES[character]

		_check_count += 1
		if lines.size() != 3:
			_fail("角色 %s 有 %d 幕（三线九图要求 3）" % [character_id, lines.size()])

		for act: int in range(1, lines.size() + 1):
			var line: Dictionary = MapManager.line_for(character_id, act)

			var modifier_id: StringName = MapManager.act_modifier_id(character_id, act)
			_check_count += 1
			if modifier_id == &"" or ContentRegistry.get_act_modifier(modifier_id) == null:
				_fail("%s 第 %d 幕的幕环境「%s」没有 .tres（机制会静默不生效）" % [
					character_id, act, modifier_id])
			elif ActModifiers.create(ContentRegistry.get_act_modifier(modifier_id), null) == null:
				_fail("%s 第 %d 幕的幕环境「%s」没有代码实现" % [character_id, act, modifier_id])

			var pool: Array = MapManager.combat_pool(character_id, act)
			_check_count += 1
			if pool.is_empty():
				_fail("%s 第 %d 幕没有敌人池" % [character_id, act])
			for enemy_id: Variant in pool:
				_check_count += 1
				if ContentRegistry.get_enemy(StringName(str(enemy_id))) == null:
					_fail("%s 第 %d 幕引用了不存在的敌人「%s」" % [character_id, act, enemy_id])


# ══ 事件 ════════════════════════════════════════════════════

func _audit_events() -> void:
	for event_id: StringName in MapManager.EVENT_POOL:
		_check_count += 1
		var data: Variant = ContentRegistry.get_event(event_id)
		if data == null:
			_fail("EVENT_POOL 引用了不存在的事件「%s」" % event_id)
			continue
		var event := data as EventData
		if event.title == "":
			_fail("事件 %s 没有标题" % event_id)
		if event.option_a_effect == EventData.Effect.NONE and event.option_b_effect == EventData.Effect.NONE:
			_fail("事件 %s 两个选项都是「什么也不发生」" % event_id)
