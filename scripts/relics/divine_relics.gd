class_name DivineRelics
extends RefCounted
## 神格遗物（`RelicData.Category.DIVINE`）—— 权柄的碎片
##
## ## 设计约束（设计文档 §9.4）
## - **强力**：效果明显强于普通遗物
## - **+神性**：拾取即推高侵蚀条，把玩家往「登神」结局推
## - **跨神格全通用、不削弱**：神的力量本就该不讲道理
## - **只能通过「窃权事件」获得**：不进普通掉落池
##
## ## 代价必须是真的代价
## 神格遗物大多带负面（自伤 / 每回合流血），否则"选不选"就不是选择。


## 战神徽记 —— 每回合 +1 力量，代价是每回合流失生命
class GodWarEmblem extends AbstractRelic:
	const STRENGTH_PER_TURN: int = 1
	const HP_LOSS_PER_TURN: int = 1

	func _init() -> void:
		id = &"god_war_emblem"
		display_name = "战神徽记"
		description = "每回合开始时获得 %d 点力量，并失去 %d 点生命。" % [
			STRENGTH_PER_TURN, HP_LOSS_PER_TURN,
		]
		trigger_text = "每回合开始时"

	func on_turn_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(STRENGTH_PER_TURN))
		# 生命流失**无视格挡**——神明的代价不是你能挡住的
		owner.take_damage(HP_LOSS_PER_TURN, null, DamageType.HP_LOSS)
		announce("+%d 力量，-%d 生命" % [STRENGTH_PER_TURN, HP_LOSS_PER_TURN])


## 猎神印记 —— 每回合 +2 敏捷（纯粹的闪避）
class GodHuntSigil extends AbstractRelic:
	const DEXTERITY_PER_TURN: int = 2

	func _init() -> void:
		id = &"god_hunt_sigil"
		display_name = "猎神印记"
		description = "每回合开始时获得 %d 点敏捷。" % DEXTERITY_PER_TURN
		trigger_text = "每回合开始时"

	func on_turn_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Dexterity.new(DEXTERITY_PER_TURN))
		announce("+%d 敏捷" % DEXTERITY_PER_TURN)


## 法神宝珠 —— 开场同时获得荆棘与缓冲
class GodArcaneOrb extends AbstractRelic:
	const THORNS: int = 2
	const BUFFER: int = 2

	func _init() -> void:
		id = &"god_arcane_orb"
		display_name = "法神宝珠"
		description = "战斗开始时获得 %d 点荆棘与 %d 点缓冲。" % [THORNS, BUFFER]
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Thorns.new(THORNS))
		owner.apply_power(BasePowers.Buffer.new(BUFFER))
		announce("+%d 荆棘，+%d 缓冲" % [THORNS, BUFFER])


## 死神冠冕 —— 每次击杀回复大量生命
class GodDeathCrown extends AbstractRelic:
	const HEAL_PER_KILL: int = 8

	func _init() -> void:
		id = &"god_death_crown"
		display_name = "死神冠冕"
		description = "每击杀一个敌人，回复 %d 点生命。" % HEAL_PER_KILL
		trigger_text = "击杀敌人时"

	func on_kill(owner: Creature, _target: Creature) -> void:
		owner.heal(HEAL_PER_KILL)
		announce("击杀回复 %d 点生命" % HEAL_PER_KILL)


static func create(relic_id: StringName) -> AbstractRelic:
	match relic_id:
		&"god_war_emblem":
			return GodWarEmblem.new()
		&"god_hunt_sigil":
			return GodHuntSigil.new()
		&"god_arcane_orb":
			return GodArcaneOrb.new()
		&"god_death_crown":
			return GodDeathCrown.new()
		_:
			return null


static func ids() -> Array[StringName]:
	return [&"god_war_emblem", &"god_hunt_sigil", &"god_arcane_orb", &"god_death_crown"]
