class_name CardData
extends Resource
## 卡牌数据（Resource）
##
## 数据外置原则（工程书 §3.4）：费用 / 伤害 / 格挡等数值**只放在 .tres 里**，
## 代码只读不算。阶段 1 的卡牌由代码临时构造（原型验证用），
## 阶段 3 起改为从 res://data/cards/*.tres 加载。
##
## `id` 字段是 ContentRegistry 的索引键，必须唯一且非空。

enum CardType {
	ATTACK,   ## 攻击牌
	SKILL,    ## 技能牌
	POWER,    ## 能力牌（打出后持续生效）
}

@export var id: StringName = &""
@export var display_name: String = "未命名"
@export var description: String = ""
@export_range(0, 5, 1) var cost: int = 1
@export var type: CardType = CardType.ATTACK
@export var damage: int = 0
@export var block: int = 0
## 打出后进入消耗区而非弃牌堆（阶段 5 法师线用，先留字段）
@export var exhaust: bool = false


static func make_attack(p_id: StringName, p_name: String, p_cost: int, p_damage: int) -> CardData:
	var card := CardData.new()
	card.id = p_id
	card.display_name = p_name
	card.cost = p_cost
	card.type = CardType.ATTACK
	card.damage = p_damage
	card.description = "造成 %d 点伤害。" % p_damage
	return card


static func make_skill(p_id: StringName, p_name: String, p_cost: int, p_block: int) -> CardData:
	var card := CardData.new()
	card.id = p_id
	card.display_name = p_name
	card.cost = p_cost
	card.type = CardType.SKILL
	card.block = p_block
	card.description = "获得 %d 点格挡。" % p_block
	return card


func _to_string() -> String:
	return "[%s %d费]" % [display_name, cost]
