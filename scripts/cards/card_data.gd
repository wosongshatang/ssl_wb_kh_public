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
## 稀有度：0 普通 / 1 罕见 / 2 稀有。只影响奖励池权重，不影响数值。
@export_range(0, 2, 1) var rarity: int = 0

# ══ 效果字段 ════════════════════════════════════════════════
# 效果按**字段**驱动，不按类型分支（decisions.md D16）。
# 这样才能写出「攻防一体」牌（铁斩波：5 伤 + 5 格挡）与「打伤害顺便上减益」牌。

@export var damage: int = 0
@export var block: int = 0
## 抽牌数
@export var draw: int = 0
## 获得能量
@export var gain_energy: int = 0
## 对自己造成生命流失（**无视格挡**）
@export var self_hp_loss: int = 0
## 施加给自己的 Power：{power_id: 层数}，例 {"strength": 2}
@export var apply_to_self: Dictionary = {}
## 施加给目标敌人的 Power：{power_id: 层数}，例 {"vulnerable": 2}
@export var apply_to_target: Dictionary = {}
## 打出后进入消耗区而非弃牌堆（阶段 5 法师线用）
@export var exhaust: bool = false
## 打出后获得的药水 id（阶段 5：卡牌也是药水的获取途径之一）
@export var grant_potion_id: StringName = &""


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
