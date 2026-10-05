class_name JobDatabase
extends RefCounted
## 职业查询（薄封装在 [ContentRegistry] 之上）
##
## 为什么不另建一套加载逻辑：`ContentRegistry` 已经是「卡牌/遗物/敌人/职业/事件」
## 的统一只读查询入口（工程书 §2.2）。再建一个 JobDatabase 去扫同一个目录，
## 只会得到两份可能不同步的索引。

## 取职业；找不到返回 null（不 push_error——「这个 id 不是职业」在正常流程里会发生）
static func get_job(job_id: StringName) -> JobData:
	var loaded: Variant = ContentRegistry.get_job(job_id)
	if loaded is JobData:
		return loaded as JobData
	return null


## 全部**可转职**的职业（不含神级镜像——镜像不是玩家能选的）
static func all_jobs() -> Array[JobData]:
	var out: Array[JobData] = []
	for job: JobData in _load_all():
		if not job.is_mirror():
			out.append(job)
	return out


## 全部神级镜像（P6-06）
static func all_mirrors() -> Array[JobData]:
	var out: Array[JobData] = []
	for job: JobData in _load_all():
		if job.is_mirror():
			out.append(job)
	return out


## 从注册表把所有职业实例捞出来。
## ⚠️ `ContentRegistry` 只提供 `all_job_ids()` / `get_job()`——
## 没有现成的 `all_jobs()`，别想当然。
static func _load_all() -> Array[JobData]:
	var out: Array[JobData] = []
	for job_id: StringName in ContentRegistry.all_job_ids():
		var job: JobData = get_job(job_id)
		if job != null:
			out.append(job)
	return out


## 给定终职 id → 它的神级镜像。找不到返回 null。
##
## 查表而不是写 if-else：**新增终职时只要补一个 .tres**，
## 神战代码一行都不用动（这正是 P6-06 那条约束的意义）。
static func mirror_for(job_id: StringName) -> JobData:
	for mirror: JobData in all_mirrors():
		if mirror.mirror_of == job_id:
			return mirror
	return null


## 某角色可选的**一阶**职业。阶段 4 只有战士线，靠 id 前缀区分。
static func first_tier_jobs(character: StringName) -> Array[JobData]:
	var out: Array[JobData] = []
	var prefix: String = _character_prefix(character)
	for job: JobData in all_jobs():
		if job.is_first_tier() and String(job.id).begins_with(prefix):
			out.append(job)
	return out


## 某职业的二阶终职候选
static func final_jobs(parent_job_id: StringName) -> Array[JobData]:
	var out: Array[JobData] = []
	for job: JobData in all_jobs():
		if job.parent_job == parent_job_id:
			out.append(job)
	return out


static func _character_prefix(character: StringName) -> String:
	match character:
		&"warrior":
			return "warrior_"
		&"hunter":
			return "hunter_"
		&"mage":
			return "mage_"
		_:
			return ""
