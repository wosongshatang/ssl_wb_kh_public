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


static func all_jobs() -> Array[JobData]:
	var out: Array[JobData] = []
	for job_id: StringName in ContentRegistry.all_job_ids():
		var job: JobData = get_job(job_id)
		if job != null:
			out.append(job)
	return out


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
