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

## 特殊牌类别（P6-12）。与**稀有度正交**——
## 稀有度说的是"这张牌多珍贵"，特殊类别说的是"这张牌怎么运作"。
## 一张金卡也可以是契约牌。
enum SpecialKind {
	NONE,
	APOTHEOSIS,  ## 神化：打出后**永久升级牌组**里的若干张牌
	PACT,        ## 契约：强力效果，代价是**永久神性**
	ORACLE,      ## 神谕：打出后抽牌，并**看穿抽牌堆**
	TRIAL,       ## 考题：满足条件（手牌数 ≥ 门槛）时额外获得格挡
}


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

# ══ 特殊卡标签（无色 / 诅咒 / 转职专属）══════════════════════

## 获得时增加的神性（无色卡用——神明的赠礼都有代价）
@export_range(0, 30, 1) var divinity_gain: int = 0
## 不可打出（诅咒牌在手里就是纯粹的负担）
@export var unplayable: bool = false
## 在**手里**时，回合结束触发 `apply_to_self` / `self_hp_loss`（诅咒牌）
@export var triggers_on_turn_end: bool = false
## 对应的神明（无色卡按神明归属，事件据此筛选）
@export var deity_id: StringName = &""

# ══ 特殊牌（P6-12）════════════════════════════════════════════

@export var special_kind: SpecialKind = SpecialKind.NONE

## 特殊效果的强度。各 kind 的含义不同：
## APOTHEOSIS = 升级几张 / PACT = 神性代价 / ORACLE = 抽几张 / TRIAL = 手牌门槛
@export_range(0, 20, 1) var special_value: int = 0

## TRIAL 专用：达成门槛时额外获得的格挡
@export_range(0, 30, 1) var trial_block_bonus: int = 0


func is_special() -> bool:
	return special_kind != SpecialKind.NONE

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


## 能否升级。**无色卡 / 金卡 / 诅咒卡都不可升级**——
## 它们的价值与代价是设计好的定值，升级会破坏这层平衡。
func can_upgrade() -> bool:
	if is_upgraded:
		return false
	return not (rarity in [Rarity.CURSE, Rarity.COLORLESS, Rarity.GOLD])


## 能否从牌组中删除。
## 无色卡与金卡是「刻进灵魂」的东西，删不掉（与转职能力不可剥夺同理）。
func can_remove() -> bool:
	return not (rarity in [Rarity.COLORLESS, Rarity.GOLD])


## 能否打出。诅咒牌恒不可打出——它的作用是在手里持续折磨你。
func is_unplayable() -> bool:
	return unplayable or rarity == Rarity.CURSE


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
	text = text.replace("{special_value}", str(special_value))
	text = text.replace("{divinity_gain}", str(divinity_gain))
	text = text.replace("{trial_block_bonus}", str(trial_block_bonus))

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
