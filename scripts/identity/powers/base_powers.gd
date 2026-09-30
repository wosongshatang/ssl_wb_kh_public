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
