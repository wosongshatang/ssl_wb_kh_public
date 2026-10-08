class_name BasePowers
extends RefCounted
## 基础 Buff / Debuff 集合（以内部类形式定义，见 decisions.md D13）
##
## 用法：`BasePowers.Strength.new(2)`、`BasePowers.Weak.new(3)`
##
## **永久型**（amount 直接参与计算）：力量、敏捷、荆棘
## **持续型**（amount 仅作回合倒计时，乘数固定）：虚弱、易伤
## **自递减型**（自己管理 amount）：中毒
## **计数型**（amount 为剩余次数）：缓冲


## 力量 —— 攻击方加法修正。**必须 priority 0，先于虚弱的乘法**
class Strength extends AbstractPower:
	func _init(amount_value: int = 1) -> void:
		id = &"strength"
		display_name = "力量"
		description = "每层使攻击伤害 +1。"
		amount = amount_value
		priority = 0

	func at_damage_give(value: float, _info: DamageInfo) -> float:
		return value + float(amount)


## 敏捷 —— 格挡加法修正
class Dexterity extends AbstractPower:
	func _init(amount_value: int = 1) -> void:
		id = &"dexterity"
		display_name = "敏捷"
		description = "每层使获得的格挡 +1。"
		amount = amount_value

	func modify_block(block: int, _card: CardData) -> int:
		return block + amount


## 虚弱 —— 攻击方乘法修正（×0.75）
## **priority 99**：保证在力量（加法）之后执行。顺序颠倒会让数值偏差巨大。
class Weak extends AbstractPower:
	const MULTIPLIER: float = 0.75

	func _init(amount_value: int = 1) -> void:
		id = &"weak"
		is_debuff = true
		display_name = "虚弱"
		description = "攻击伤害 ×0.75，持续 %d 回合。" % amount_value
		amount = amount_value
		priority = 99
		is_turn_based = true

	func at_damage_give(value: float, _info: DamageInfo) -> float:
		return value * MULTIPLIER

	func on_turn_end(_owner: Creature) -> void:
		amount -= 1


## 易伤 —— 目标受击乘法修正（×1.5）
class Vulnerable extends AbstractPower:
	const MULTIPLIER: float = 1.5

	func _init(amount_value: int = 1) -> void:
		id = &"vulnerable"
		is_debuff = true
		display_name = "易伤"
		description = "受到攻击伤害 ×1.5，持续 %d 回合。" % amount_value
		amount = amount_value
		is_turn_based = true

	func at_damage_receive(value: float, _info: DamageInfo) -> float:
		return value * MULTIPLIER

	func on_turn_end(_owner: Creature) -> void:
		amount -= 1


## 荆棘 —— 被攻击后反伤（THORNS 类型，不吃力量/虚弱/易伤）
class Thorns extends AbstractPower:
	func _init(amount_value: int = 1) -> void:
		id = &"thorns"
		display_name = "荆棘"
		description = "被攻击时对攻击者造成 %d 点伤害。" % amount_value
		amount = amount_value

	func on_attacked(info: DamageInfo) -> void:
		# 只有 NORMAL 触发反伤，否则荆棘会互相反弹无限递归
		if info.damage_type != DamageType.NORMAL:
			return
		if info.source == null or not info.source.is_alive():
			return
		info.source.take_damage(amount, owner_creature, DamageType.THORNS)


## 中毒 —— 持有者回合开始扣血（无视格挡），随后自身层数 -1
class Poison extends AbstractPower:
	func _init(amount_value: int = 1) -> void:
		id = &"poison"
		is_debuff = true
		display_name = "中毒"
		description = "回合开始时失去 %d 点生命（无视格挡），然后层数 -1。" % amount_value
		amount = amount_value
		is_turn_based = true

	func on_turn_start(owner: Creature) -> void:
		if amount <= 0:
			return
		owner.take_damage(amount, null, DamageType.POISON)
		amount -= 1


## 缓冲 —— 抵挡接下来 N 次「真正会掉的血」
## 挂在 prevent_hp_loss（格挡吸收**之后**）：被格挡完全吃掉的攻击不消耗层数。
class Buffer extends AbstractPower:
	func _init(amount_value: int = 1) -> void:
		id = &"buffer"
		display_name = "缓冲"
		description = "抵挡接下来 %d 次生命损失。" % amount_value
		amount = amount_value
		is_turn_based = true

	func prevent_hp_loss(hp_loss: int, _info: DamageInfo) -> int:
		if hp_loss <= 0 or amount <= 0:
			return hp_loss
		amount -= 1
		return 0


## 兽化 —— 兽性药剂的代价
##
## 给力量，但每回合抽走生命。**不是纯增益**：
## 玩家得判断"这一场还撑得住几回合"，而不是无脑喝。
class BeastForm extends AbstractPower:
	const STRENGTH: int = 3
	const HP_LOSS_PER_TURN: int = 1

	func _init() -> void:
		id = &"beast_form"
		display_name = "兽化"
		description = "获得 %d 点力量；每回合开始时失去 %d 点生命。" % [
			STRENGTH, HP_LOSS_PER_TURN,
		]
		is_debuff = true

	func on_turn_start(owner: Creature) -> void:
		owner.take_damage(HP_LOSS_PER_TURN, null, DamageType.HP_LOSS)


# ══ 阶段 9 · 机制原语（转职机制重做）══════════════════════════
#
# 这一批是**"资源型"Power**：它们不是"每回合涨一点属性"，
# 而是**可累积、可消耗、可组合**的层数资源。
#
# ## 与「力量 / 敏捷」的根本区别
# 力量是**通用加成**（谁都一样，加就完了）；这批是**专属资源**：
#   · 只能靠特定行为获得（上印记 / 附元素 / 消耗牌）
#   · 有上限（防止无脑堆叠）
#   · 能参与组合（元素反应、满层引爆）
#
# 这是"机制特色"的来源——**玩家经营的是资源，不是数值**。


## 印记 —— 猎人线的层数资源（上限 10）
##
## 每层使目标受到的伤害 **+10%（乘法）**，**不随回合衰减**。
##
## ## 与「易伤」的分工
## 易伤是**固定 ×1.5 且按回合倒计时**——它奖励"这一回合打一发大的"。
## 印记是**可累积、不衰减**——它奖励"持续盯住同一个目标"。
## 两者可以同时存在（乘法可交换），语义不同所以是两个 Power。
class Mark extends AbstractPower:
	const MAX_STACKS: int = 10
	const PER_STACK: float = 0.10

	func _init(amount_value: int = 1) -> void:
		id = &"mark"
		is_debuff = true
		display_name = "印记"
		description = "每层使受到你的伤害 +%d%%（上限 %d 层，不衰减）。" % [
			int(PER_STACK * 100.0), MAX_STACKS,
		]
		amount = mini(amount_value, MAX_STACKS)
		is_turn_based = false

	## 上限在 `stack()` 里截断——在调用方截的话，
	## "已经 10 层了"这件事每个调用点都要判一次，迟早漏一处。
	func stack(delta: int) -> void:
		amount = clampi(amount + delta, 0, MAX_STACKS)

	func at_damage_receive(value: float, _info: DamageInfo) -> float:
		return value * (1.0 + PER_STACK * float(mini(amount, MAX_STACKS)))


## 燃 —— 法师元素之一（与「中毒」同语义：**无视格挡**的持续伤害）
##
## ## 为什么不复用 Poison
## 中毒和燃**必须能同时存在**（不同的元素，参与不同的反应）。
## 共用一个 id 会让"这个目标中了几层毒"和"燃了几层"混成一个数字。
##
## ## 为什么不衰减
## Poison 每回合 -1，燃**不衰减**——它只能被**元素反应**消耗掉。
## 这是"叠元素 → 引爆"这条玩法的前提：会自己消失的层数攒不起来。
class Burn extends AbstractPower:
	func _init(amount_value: int = 1) -> void:
		id = &"burn"
		is_debuff = true
		display_name = "燃"
		description = "回合结束时失去 %d 点生命（无视格挡），不衰减。" % amount_value
		amount = amount_value
		is_turn_based = false

	func on_turn_end(owner: Creature) -> void:
		if amount <= 0:
			return
		owner.take_damage(amount, null, DamageType.POISON)


## 霜 —— 法师元素之二：每层受击 −1（最多生效 3 层）
##
## 满 `FREEZE_THRESHOLD` 层时由 [ElementSystem] 转成「冻结」并清空自身——
## **判定放在 ElementSystem 而不是这里**，因为那是"元素之间"的规则，
## 属于唯一的元素入口，不属于单个元素。
class Frost extends AbstractPower:
	## 减伤上限。**必须有**——无上限的减伤会让"叠霜"变成无敌。
	const MAX_REDUCE: int = 3
	## 冻结阈值。达到即转冻结并清空霜层。
	const FREEZE_THRESHOLD: int = 5

	func _init(amount_value: int = 1) -> void:
		id = &"frost"
		is_debuff = true
		display_name = "霜"
		description = "每层使受到的伤害 −1（最多 −%d），满 %d 层冻结。" % [
			MAX_REDUCE, FREEZE_THRESHOLD,
		]
		amount = amount_value
		is_turn_based = false

	func at_damage_receive(value: float, _info: DamageInfo) -> float:
		return maxf(0.0, value - float(mini(amount, MAX_REDUCE)))


## 冻结 —— **跳过下一次行动**
##
## 纯标记型 Power：效果由 [BattleManager] 在敌人回合开始时读取并消耗。
## 之所以不做成"减伤害"，是因为"让敌人少打一回合"是**节奏控制**，
## 与"扛住这一下"是完全不同的体验。
class Frozen extends AbstractPower:
	func _init() -> void:
		id = &"frozen"
		is_debuff = true
		display_name = "冻结"
		description = "跳过下一次行动。"
		amount = 1
		is_turn_based = true


## 奥术 —— 法师的蓄力层数（上限 10）
##
## 每层使**你造成的伤害 +25%（乘法）**。
##
## ⚠️ **priority 100**：必须晚于力量（加法，priority 0）与虚弱（×0.75，priority 99）。
## 落在加法之前的话，"先乘后加"会把力量的贡献也乘进去——
## 顺序颠倒的偏差在数值上非常明显，且**不会报错**。
class Arcane extends AbstractPower:
	const MAX_STACKS: int = 10
	const PER_STACK: float = 0.25

	func _init(amount_value: int = 1) -> void:
		id = &"arcane"
		display_name = "奥术"
		description = "每层使伤害 +%d%%（上限 %d 层）。" % [
			int(PER_STACK * 100.0), MAX_STACKS,
		]
		amount = mini(amount_value, MAX_STACKS)
		priority = 100
		is_turn_based = false

	func stack(delta: int) -> void:
		amount = clampi(amount + delta, 0, MAX_STACKS)

	func at_damage_give(value: float, _info: DamageInfo) -> float:
		return value * (1.0 + PER_STACK * float(mini(amount, MAX_STACKS)))


## 怒气 —— 狂战线的专属资源
##
## 效果与「力量」完全一致（每层 +1 攻击伤害、跨回合保留），
## **但它是独立的一层**，理由有二：
##   1. **玩家看得见**——面板上写"力量 5"和写"怒气 5"对狂战玩家的意义完全不同
##   2. **来源唯一**——只有失血才涨，所以它天然与"压血线"绑在一起
##
## > 这一条兑现了 `bloodthirster` 里挂了很久的 TODO：
## > 「完整的怒气资源在阶段 5 的战士线扩展里补」。
class Rage extends AbstractPower:
	func _init(amount_value: int = 1) -> void:
		id = &"rage"
		display_name = "怒气"
		description = "每层使攻击伤害 +1。失血获得，跨回合保留。"
		amount = amount_value
		priority = 0
		is_turn_based = false

	func at_damage_give(value: float, _info: DamageInfo) -> float:
		return value + float(amount)
