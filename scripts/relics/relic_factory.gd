class_name RelicFactory
extends RefCounted
## 遗物工厂：`relic_id` → [AbstractRelic] 实例
##
## 与 [PowerFactory] 同样的思路：让 `.tres` 与代码只写 id，不写脚本路径。
## 新增遗物时只需在 [method create] 加一行 match 分支。


## 燃烧之血 —— 战士初始遗物（设计文档 §9.5）
class BurningBlood extends AbstractRelic:
	const HEAL_AMOUNT: int = 5

	func _init() -> void:
		id = &"burning_blood"
		display_name = "燃烧之血"
		description = "战斗胜利后回复 %d 点生命。" % HEAL_AMOUNT

	func on_battle_end(owner: Creature, won: bool) -> void:
		if won:
			owner.heal(HEAL_AMOUNT)


## 金刚杵 —— 战斗开始时获得 1 点力量
class Vajra extends AbstractRelic:
	const STRENGTH: int = 1

	func _init() -> void:
		id = &"vajra"
		display_name = "金刚杵"
		description = "战斗开始时获得 %d 点力量。" % STRENGTH

	func at_battle_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(STRENGTH))


## 锚链 —— 战斗开始时获得 4 点格挡
class AnchorChain extends AbstractRelic:
	const BLOCK: int = 4

	func _init() -> void:
		id = &"anchor_chain"
		display_name = "锚链"
		description = "战斗开始时获得 %d 点格挡。" % BLOCK

	func at_battle_start(owner: Creature) -> void:
		owner.gain_block(BLOCK)


## 血瓶 —— 战斗开始时回复 2 点生命
class BloodVial extends AbstractRelic:
	const HEAL: int = 2

	func _init() -> void:
		id = &"blood_vial"
		display_name = "血瓶"
		description = "战斗开始时回复 %d 点生命。" % HEAL

	func at_battle_start(owner: Creature) -> void:
		owner.heal(HEAL)


static func create(relic_id: StringName) -> AbstractRelic:
	match relic_id:
		&"burning_blood":
			return BurningBlood.new()
		&"vajra":
			return Vajra.new()
		&"anchor_chain":
			return AnchorChain.new()
		&"blood_vial":
			return BloodVial.new()
		_:
			push_warning("RelicFactory: 未知遗物 id「%s」" % relic_id)
			return null


static func is_known(relic_id: StringName) -> bool:
	return relic_id in [&"burning_blood", &"vajra", &"anchor_chain", &"blood_vial"]


## 可掉落的遗物池（排除角色初始遗物——已经拿到的不会重复掉）
static func droppable_ids(owned: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for relic_id: StringName in [&"vajra", &"anchor_chain", &"blood_vial"]:
		if not owned.has(relic_id):
			out.append(relic_id)
	return out
