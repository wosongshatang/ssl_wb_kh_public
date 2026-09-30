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


static func create(relic_id: StringName) -> AbstractRelic:
	match relic_id:
		&"burning_blood":
			return BurningBlood.new()
		_:
			push_warning("RelicFactory: 未知遗物 id「%s」" % relic_id)
			return null


static func is_known(relic_id: StringName) -> bool:
	return relic_id == &"burning_blood"
