class_name JobRelics
extends RefCounted
## 职业专属遗物（`RelicData.Category.JOB`）—— 转职时随职业一起到手
##
## ## 与「身份能力」的分工
## - 身份能力 = **规则级改写**（不可剥夺，每场战斗重新注入）
## - 职业遗物 = **数值级强化**（可以围绕它构筑，也可以放弃）
## 两者都在转职时获得，但只有身份能力是"刻进灵魂"的。
## 分清这一点，才不会把遗物的效果写成"不可剥夺"的强度。


## 盾卫的护腕 —— 每回合第一张格挡牌额外 +2
class ShieldGuardBracer extends AbstractRelic:
	const BONUS: int = 2

	var _used_this_turn: bool = false

	func _init() -> void:
		id = &"job_shield_guard_bracer"
		display_name = "盾卫的护腕"
		description = "每回合获得的第一张格挡额外 +%d。" % BONUS
		trigger_text = "每回合第一次获得格挡"

	func on_turn_start(_owner: Creature) -> void:
		_used_this_turn = false

	func at_block_gain(amount: int, _card: CardData) -> int:
		if _used_this_turn or amount <= 0:
			return amount
		_used_this_turn = true
		announce("+%d 格挡" % BONUS)
		return amount + BONUS

	## 预估版本：**不翻转标志**（与盾卫身份能力的处理同理）
	func preview_block(amount: int, _card: CardData) -> int:
		if _used_this_turn or amount <= 0:
			return amount
		return amount + BONUS


## 狂战的骨链 —— 每失去 3 点生命获得 1 点力量
class BerserkerChain extends AbstractRelic:
	const HP_PER_STRENGTH: int = 3

	var _accumulated: int = 0

	func _init() -> void:
		id = &"job_berserker_chain"
		display_name = "狂战的骨链"
		description = "每失去 %d 点生命，获得 1 点力量。" % HP_PER_STRENGTH
		trigger_text = "失去生命时"

	func on_damage_taken(owner: Creature, amount: int) -> void:
		_accumulated += amount
		var gained: int = _accumulated / HP_PER_STRENGTH
		if gained <= 0:
			return
		_accumulated -= gained * HP_PER_STRENGTH
		owner.apply_power(BasePowers.Strength.new(gained))
		announce("+%d 力量" % gained)


## 壁垒的基石 —— 回合结束时额外保留 25% 格挡（**叠加在壁垒身份能力之上**）
##
## 设计上刻意与壁垒的 `at_block_clear` 用同一个钩子：
## 这样"再保留 25%"自然是**乘法叠加**而不是另起一套逻辑。
class BastionKeystone extends AbstractRelic:
	const KEEP_RATIO: float = 0.25

	func _init() -> void:
		id = &"job_bastion_keystone"
		display_name = "壁垒的基石"
		description = "回合结束时，本该清零的格挡额外保留 %d%%。" % int(KEEP_RATIO * 100.0)
		trigger_text = "回合结束时"

	func at_block_clear(clearing: int, _owner: Creature) -> int:
		if clearing <= 0:
			return clearing
		var kept: int = int(floor(float(clearing) * KEEP_RATIO))
		if kept <= 0:
			return clearing
		announce("额外保留 %d 点格挡" % kept)
		return clearing - kept


## 盾猛的撞角 —— 战斗开始时获得 3 点力量（放大的反伤）
class ShieldBashSpur extends AbstractRelic:
	const STRENGTH: int = 3

	func _init() -> void:
		id = &"job_shield_bash_spur"
		display_name = "盾猛的撞角"
		description = "战斗开始时获得 %d 点力量。" % STRENGTH
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(STRENGTH))
		announce("+%d 力量" % STRENGTH)


## 嗜血者的獠牙 —— 每次击杀回复 4 点生命
class BloodthirsterFang extends AbstractRelic:
	const HEAL_PER_KILL: int = 4

	func _init() -> void:
		id = &"job_bloodthirster_fang"
		display_name = "嗜血者的獠牙"
		description = "每击杀一个敌人，回复 %d 点生命。" % HEAL_PER_KILL
		trigger_text = "击杀敌人时"

	func on_kill(owner: Creature, _target: Creature) -> void:
		owner.heal(HEAL_PER_KILL)
		announce("击杀回复 %d 点生命" % HEAL_PER_KILL)


## 鏖战者的战旗 —— 每回合开始时获得 2 点格挡
class MomentumBanner extends AbstractRelic:
	const BLOCK: int = 2

	func _init() -> void:
		id = &"job_momentum_banner"
		display_name = "鏖战者的战旗"
		description = "每回合开始时获得 %d 点格挡。" % BLOCK
		trigger_text = "每回合开始时"

	func on_turn_start(owner: Creature) -> void:
		owner.gain_block(BLOCK)
		announce("+%d 格挡" % BLOCK)


static func create(relic_id: StringName) -> AbstractRelic:
	match relic_id:
		&"job_shield_guard_bracer":
			return ShieldGuardBracer.new()
		&"job_berserker_chain":
			return BerserkerChain.new()
		&"job_bastion_keystone":
			return BastionKeystone.new()
		&"job_shield_bash_spur":
			return ShieldBashSpur.new()
		&"job_bloodthirster_fang":
			return BloodthirsterFang.new()
		&"job_momentum_banner":
			return MomentumBanner.new()
		_:
			return null


static func ids() -> Array[StringName]:
	return [
		&"job_shield_guard_bracer", &"job_berserker_chain", &"job_bastion_keystone",
		&"job_shield_bash_spur", &"job_bloodthirster_fang", &"job_momentum_banner",
	]


## 职业 → 专属遗物（转职时发放）
static func for_job(job_id: StringName) -> StringName:
	match job_id:
		&"warrior_shield_guard":
			return &"job_shield_guard_bracer"
		&"warrior_berserker":
			return &"job_berserker_chain"
		&"warrior_bastion":
			return &"job_bastion_keystone"
		&"warrior_shield_bash":
			return &"job_shield_bash_spur"
		&"warrior_bloodthirster":
			return &"job_bloodthirster_fang"
		&"warrior_momentum":
			return &"job_momentum_banner"
		_:
			return &""
