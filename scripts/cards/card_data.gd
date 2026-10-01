class_name CardData
extends Resource
## 卡牌数据
##
## ## 效果按**字段**驱动，不按类型分支（decisions.md D16）
## 这样才能写出「攻防一体」牌（铁斩波：伤害 + 格挡）与「打伤害顺便上减益」牌。
## `type` 是**标签**（鏖战者按攻击牌计数、风行者复制首张攻击牌），不是分派依据。
##
## ## 描述用占位符，保证「写的」与「做的」永远一致
## `description` 里写 `{damage}` `{block}` `{draw}` `{strength}` 等占位符，
## 由 [method format_description] 填**当前实际会生效的数值**。
## 直接写死数字会导致「卡面写 5、实际打 7」这种撕裂——玩家会怀疑整个游戏的数值。
##
## ## 升级
## 默认规则见 [method apply_upgrade]；需要特例时在 `.tres` 里写 `upgraded_*` 覆盖。

enum CardType { ATTACK, SKILL, POWER }

enum Rarity {
	STARTER = 0,    ## 灰 —— 初始卡牌
	COMMON = 1,     ## 白
	UNCOMMON = 2,   ## 绿
	RARE = 3,       ## 蓝
	EPIC = 4,       ## 紫
	GOLD = 5,       ## 金 —— 转职专属
	COLORLESS = 6,  ## 无色 —— 神明赠与，强大但有代价
	CURSE = 7,      ## 黑 —— 诅咒
}

# ══ 升级默认规则（用户指定）═════════════════════════════════
## 攻击 / 技能牌：按稀有度依次 +3 / +4 / +5 / +6
const UPGRADE_NUMERIC_BY_RARITY: Array[int] = [3, 3, 4, 5, 6, 6, 6, 0]
## 能力牌：统一 +2
const UPGRADE_POWER_DELTA: int = 2
## 施加负面状态：额外 +2 层
const UPGRADE_DEBUFF_DELTA: int = 2
## 涉及抽牌：按稀有度依次 +1 / +1 / +2 / +3
const UPGRADE_DRAW_BY_RARITY: Array[int] = [1, 1, 1, 2, 3, 3, 3, 0]

@export var id: StringName = &""
@export var display_name: String = "未命名"
## 支持占位符：{damage} {block} {draw} {cost} {self_hp_loss}
## 以及 apply_to_self / apply_to_target 里的 power id（如 {strength} {vulnerable}）
@export var description: String = ""
@export_range(0, 5, 1) var cost: int = 1
@export var type: CardType = CardType.ATTACK
@export var rarity: Rarity = Rarity.STARTER

# ══ 效果字段 ════════════════════════════════════════════════

@export var damage: int = 0
@export var block: int = 0
@export var draw: int = 0
@export var gain_energy: int = 0
## 对自己造成生命流失（**无视格挡**）
@export var self_hp_loss: int = 0
## 施加给自己的 Power：{power_id: 层数}，例 {"strength": 2}
@export var apply_to_self: Dictionary = {}
## 施加给目标敌人的 Power：{power_id: 层数}，例 {"vulnerable": 2}
@export var apply_to_target: Dictionary = {}
@export var exhaust: bool = false
@export var grant_potion_id: StringName = &""

# ══ 升级 ════════════════════════════════════════════════════

## 实例状态：这张牌是否已升级。
## **注册表里的模板永远是未升级的**——升级只发生在副本上。
@export var is_upgraded: bool = false

## 显式覆盖。-1 表示「按默认规则算」（0 是合法数值，所以不能用 0 当哨兵）
@export var upgraded_damage: int = -1
@export var upgraded_block: int = -1
@export var upgraded_draw: int = -1
@export var upgraded_apply_to_self: Dictionary = {}
@export var upgraded_apply_to_target: Dictionary = {}
## 特例描述（留空则复用 description 模板）
@export var upgraded_description: String = ""


# ══ 构造 ════════════════════════════════════════════════════

static func make_attack(
	card_id: StringName,
	card_name: String,
	card_cost: int,
	card_damage: int
) -> CardData:
	var card := CardData.new()
	card.id = card_id
	card.display_name = card_name
	card.cost = card_cost
	card.type = CardType.ATTACK
	card.damage = card_damage
	return card


static func make_skill(
	card_id: StringName,
	card_name: String,
	card_cost: int,
	card_block: int
) -> CardData:
	var card := CardData.new()
	card.id = card_id
	card.display_name = card_name
	card.cost = card_cost
	card.type = CardType.SKILL
	card.block = card_block
	return card


# ══ 升级 ════════════════════════════════════════════════════

## 返回这张牌的**升级副本**（不修改自身——注册表里的模板必须保持未升级）。
func create_upgraded() -> CardData:
	var copy := duplicate() as CardData
	copy.is_upgraded = true
	copy.display_name = "%s+" % display_name
	copy.apply_upgrade()
	return copy


## 按用户指定的默认规则升级。
##
## 顺序：**先应用显式覆盖，再应用默认规则**——
## 覆盖说的是"这张牌升级后这项是多少"，默认规则只补没被覆盖的项。
func apply_upgrade() -> void:
	var numeric_delta: int = _numeric_delta()
	var draw_delta: int = _draw_delta()

	if upgraded_damage >= 0:
		damage = upgraded_damage
	elif damage > 0:
		damage += numeric_delta

	if upgraded_block >= 0:
		block = upgraded_block
	elif block > 0:
		block += numeric_delta

	if upgraded_draw >= 0:
		draw = upgraded_draw
	elif draw > 0:
		draw += draw_delta

	# 负面状态：额外 +2 层
	if not upgraded_apply_to_target.is_empty():
		apply_to_target = upgraded_apply_to_target.duplicate()
	elif not apply_to_target.is_empty():
		for key: Variant in apply_to_target:
			apply_to_target[key] = int(apply_to_target[key]) + UPGRADE_DEBUFF_DELTA

	# 增益：能力牌统一 +2，其余按稀有度
	if not upgraded_apply_to_self.is_empty():
		apply_to_self = upgraded_apply_to_self.duplicate()
	elif not apply_to_self.is_empty():
		for key: Variant in apply_to_self:
			apply_to_self[key] = int(apply_to_self[key]) + numeric_delta


## 攻击 / 技能按稀有度；能力牌统一 +2；诅咒不升级
func _numeric_delta() -> int:
	if type == CardType.POWER:
		return UPGRADE_POWER_DELTA
	return UPGRADE_NUMERIC_BY_RARITY[clampi(rarity, 0, UPGRADE_NUMERIC_BY_RARITY.size() - 1)]


func _draw_delta() -> int:
	return UPGRADE_DRAW_BY_RARITY[clampi(rarity, 0, UPGRADE_DRAW_BY_RARITY.size() - 1)]


func can_upgrade() -> bool:
	if is_upgraded or rarity == Rarity.CURSE:
		return false
	return true


# ══ 描述渲染 ════════════════════════════════════════════════

## 把占位符替换成**当前实际会生效的数值**。
##
## `source` 是打出这张牌的人（算力量 / 敏捷加成），`target` 是目标（算易伤）。
## 两者都可以为 null——此时显示基础值。
func format_description(source: Creature = null, target: Creature = null) -> String:
	var template: String = description
	if is_upgraded and upgraded_description != "":
		template = upgraded_description

	var text: String = template
	text = text.replace("{cost}", str(cost))
	text = text.replace("{damage}", str(preview_damage(source, target)))
	text = text.replace("{block}", str(preview_block(source)))
	text = text.replace("{draw}", str(draw))
	text = text.replace("{gain_energy}", str(gain_energy))
	text = text.replace("{self_hp_loss}", str(self_hp_loss))

	for key: Variant in apply_to_self:
		text = text.replace("{%s}" % str(key), str(int(apply_to_self[key])))
	for key: Variant in apply_to_target:
		text = text.replace("{%s}" % str(key), str(int(apply_to_target[key])))

	return text


## 预览实际伤害：**走与结算完全相同的修正链**（力量 / 虚弱 / 易伤 / 遗物）。
## 复用管线而不是自己加一遍力量，是为了保证「预览」与「真打」永远一致。
func preview_damage(source: Creature = null, target: Creature = null) -> int:
	if damage <= 0:
		return 0
	if source == null:
		return damage
	return DamagePipeline.calculate(source, target, damage).output


## 预览实际格挡：走与 gain_block 相同的修正钩子（但**不产生副作用**）
func preview_block(source: Creature = null) -> int:
	if block <= 0:
		return 0
	if source == null:
		return block
	return source.preview_block(block, self)


func has_debuff_effect() -> bool:
	return not apply_to_target.is_empty()


func _to_string() -> String:
	return "CardData(%s%s)" % [display_name, "+" if is_upgraded else ""]
