extends GutTest
## 阶段 6 · P4 神级镜像测试（P6-06）
##
## 守的是一条**架构约束**：镜像必须完全数据驱动。
## 如果哪天有人往 Boss 脚本里写了 `if 玩家是壁垒 then ...`，
## 这里的「每个终职都有镜像」就会先红——因为那个分支覆盖不到新职业。

func before_all() -> void:
	ContentRegistry.load_all()


func _final_jobs() -> Array[JobData]:
	var out: Array[JobData] = []
	for job: JobData in JobDatabase.all_jobs():
		if not job.is_first_tier():
			out.append(job)
	return out


# ══ 镜像与职业的一一对应 ════════════════════════════════════

func test_every_final_job_has_a_mirror() -> void:
	## ★ 这条就是 P6-06 的守卫。
	## 新增一个终职却没补镜像 → 神战 P4 会静默地什么都不做。
	for job: JobData in _final_jobs():
		assert_ne(job.mirror_job_id, &"", "终职 %s 没有配 mirror_job_id" % job.id)
		assert_not_null(JobDatabase.get_job(job.mirror_job_id),
			"终职 %s 的镜像 %s 不存在" % [job.id, job.mirror_job_id])


func test_every_mirror_points_back_at_a_real_job() -> void:
	for mirror: JobData in JobDatabase.all_mirrors():
		assert_true(mirror.is_mirror(), "%s 应标记为镜像" % mirror.id)
		assert_not_null(JobDatabase.get_job(mirror.mirror_of),
			"镜像 %s 指向不存在的职业 %s" % [mirror.id, mirror.mirror_of])


func test_mirror_and_job_reference_each_other() -> void:
	## 双向引用必须自洽——只写一边会让查找静默失败
	for job: JobData in _final_jobs():
		var mirror: JobData = JobDatabase.mirror_for(job.id)
		assert_not_null(mirror, "mirror_for(%s) 找不到镜像" % job.id)
		assert_eq(mirror.id, job.mirror_job_id, "正向与反向引用不一致")


func test_mirrors_are_not_offered_as_job_choices() -> void:
	## 镜像**不是玩家能转职的职业**——混进转职界面会让玩家转职成"神"
	for job: JobData in JobDatabase.all_jobs():
		assert_false(job.is_mirror(), "%s 是镜像，不该出现在可转职列表里" % job.id)


func test_final_job_list_excludes_mirrors() -> void:
	for job: JobData in _final_jobs():
		assert_false(job.is_mirror())


# ══ 镜像的内容 ══════════════════════════════════════════════

func test_mirror_reuses_the_original_identity_power() -> void:
	## 「神用你的招式」——镜像不该另写一套能力
	for job: JobData in _final_jobs():
		var mirror: JobData = JobDatabase.mirror_for(job.id)
		assert_eq(mirror.identity_power_ids, job.identity_power_ids,
			"镜像 %s 应与原职业用同一套身份能力" % mirror.id)


func test_mirror_has_a_higher_power_scale() -> void:
	## 神不会累——同样的招式，层数更高
	for mirror: JobData in JobDatabase.all_mirrors():
		assert_gt(mirror.power_scale, 1.0, "镜像 %s 的强度倍率应大于 1" % mirror.id)


func test_mirror_has_no_grantable_cards() -> void:
	## 镜像不给牌——它只出现在敌人身上
	for mirror: JobData in JobDatabase.all_mirrors():
		assert_eq(mirror.signature_card_ids.size(), 0, "%s 不该有专属卡" % mirror.id)
		assert_eq(mirror.job_card_ids.size(), 0, "%s 不该有职业牌池" % mirror.id)


func test_mirror_has_display_text() -> void:
	for mirror: JobData in JobDatabase.all_mirrors():
		assert_ne(mirror.display_name, "")
		assert_ne(mirror.description, "")


# ══ 强度倍率真的生效 ════════════════════════════════════════

func test_every_mirror_grants_extra_starting_powers() -> void:
	## ★ **光有 power_scale 不够**：我们的身份能力大多是比例型 / 标记型
	## （壁垒保留一半、盾猛按格挡反伤），它们的 amount 是 0——
	## 乘任何倍率都还是 0。所以镜像必须另外带一点"神才有的东西"。
	for mirror: JobData in JobDatabase.all_mirrors():
		assert_gt(mirror.mirror_starting_powers.size(), 0,
			"镜像 %s 没有任何开场属性——它实际等于什么都没加" % mirror.id)


func test_mirror_starting_powers_are_real_powers() -> void:
	for mirror: JobData in JobDatabase.all_mirrors():
		for raw_id: Variant in mirror.mirror_starting_powers:
			var power_id := StringName(str(raw_id))
			assert_not_null(PowerFactory.create(power_id, 1),
				"镜像 %s 引用了不存在的能力 %s" % [mirror.id, power_id])


func test_scaled_identity_power_is_still_unstrippable() -> void:
	## 镜像能力仍然是"身份层"，沉默/驱散拿不走
	var c := Creature.new()
	c.max_hp = 60
	c.reset_for_battle()
	autofree(c)
	c.apply_identity_power(IdentityPowers.create(&"bastion_wall"), 2.0)

	c.remove_power(&"bastion_wall")

	assert_not_null(c.get_power(&"bastion_wall"), "身份层不该被 remove_power 拿走")


# ══ Boss 侧的开关 ═══════════════════════════════════════════

func test_act_three_boss_uses_the_player_mirror() -> void:
	## 神战 P4 的开关必须真的打开——否则镜像系统永远不被触发
	var loaded: Variant = ContentRegistry.get_enemy(&"act3_boss")
	assert_true(loaded is EnemyData)
	assert_true((loaded as EnemyData).uses_player_mirror,
		"第 3 幕 Boss 应开启镜像模仿")


func test_only_bosses_use_the_mirror() -> void:
	## 普通敌人都来模仿玩家会让每场战斗都变成"打自己"，很烦
	for enemy_id: StringName in ContentRegistry.all_enemy_ids():
		var data: EnemyData = ContentRegistry.get_enemy(enemy_id)
		if data.uses_player_mirror:
			assert_true(data.is_boss, "%s 不是 Boss 却模仿玩家" % enemy_id)


# ══ 玩家的终职查询 ══════════════════════════════════════════

func test_final_job_id_is_empty_before_any_transfer() -> void:
	GameState.reset_run()

	assert_eq(GameState.final_job_id(), &"")
	assert_null(GameState.final_job())

	GameState.reset_run()


func test_final_job_id_returns_the_last_transfer() -> void:
	GameState.reset_run()
	GameState.job_path = [&"warrior_shield_guard", &"warrior_bastion"]

	assert_eq(GameState.final_job_id(), &"warrior_bastion")
	assert_not_null(GameState.final_job())

	GameState.reset_run()
