class_name RelicFactory
extends RefCounted
## 遗物工厂：`relic_id` → [AbstractRelic] 实例
##
## 与 [PowerFactory] 同样的思路：让 `.tres` 与代码只写 id，不写脚本路径。
## 三层分类各自在 [BasicRelics] / [DivineRelics] / [JobRelics] 里实现，
## 本类只负责按顺序问一遍——新增遗物时改对应的分组文件即可。

static func create(relic_id: StringName) -> AbstractRelic:
	var relic: AbstractRelic = BasicRelics.create(relic_id)
	if relic == null:
		relic = DivineRelics.create(relic_id)
	if relic == null:
		relic = JobRelics.create(relic_id)

	if relic == null:
		push_warning("RelicFactory: 未知遗物 id「%s」" % relic_id)
	return relic


static func is_known(relic_id: StringName) -> bool:
	return all_ids().has(relic_id)


static func all_ids() -> Array[StringName]:
	var out: Array[StringName] = BasicRelics.ids()
	out.append_array(DivineRelics.ids())
	out.append_array(JobRelics.ids())
	return out


## 普通遗物池（战斗掉落 / 商店用）。
##
## **神格遗物与职业遗物刻意排除**：
## 前者只能通过「窃权事件」获得，后者只能通过转职——
## 让它们出现在普通掉落里，等于把"选择的重量"稀释掉了。
static func droppable_ids(owned: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for relic_id: StringName in BasicRelics.ids():
		if not owned.has(relic_id):
			out.append(relic_id)
	return out


## 神格遗物池（窃权事件用）
static func divine_ids(owned: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for relic_id: StringName in DivineRelics.ids():
		if not owned.has(relic_id):
			out.append(relic_id)
	return out


## 商店定价：分类决定档位
static func price_of(relic_id: StringName) -> int:
	if DivineRelics.ids().has(relic_id):
		return 200
	if JobRelics.ids().has(relic_id):
		return 150
	var data: Variant = ContentRegistry.get_relic(relic_id)
	if data is RelicData:
		match (data as RelicData).rarity:
			2:
				return 160
			1:
				return 110
			_:
				return 70
	return 70
