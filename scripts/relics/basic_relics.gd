class_name BasicRelics
extends RefCounted
## 普通遗物（`RelicData.Category.COMMON`）—— 人的造物 / 自然奇物
##
## 效果克制、无条件触发。**这一层是构筑的地基**：
## 神格遗物给爆发，普通遗物给稳定性。


## 燃烧之血 —— 战士初始遗物
class BurningBlood extends AbstractRelic:
	const HEAL: int = 5

	func _init() -> void:
		id = &"burning_blood"
		display_name = "燃烧之血"
		description = "战斗胜利后回复 %d 点生命。" % HEAL
		trigger_text = "战斗胜利时"

	func on_battle_end(owner: Creature, won: bool) -> void:
		if won:
			owner.heal(HEAL)
			announce("回复 %d 点生命" % HEAL)


class Vajra extends AbstractRelic:
	const STRENGTH: int = 1

	func _init() -> void:
		id = &"vajra"
		display_name = "金刚杵"
		description = "战斗开始时获得 %d 点力量。" % STRENGTH
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(STRENGTH))
		announce("+%d 力量" % STRENGTH)


class AnchorChain extends AbstractRelic:
	const BLOCK: int = 4

	func _init() -> void:
		id = &"anchor_chain"
		display_name = "锚链"
		description = "战斗开始时获得 %d 点格挡。" % BLOCK
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		owner.gain_block(BLOCK)
		announce("+%d 格挡" % BLOCK)


class BloodVial extends AbstractRelic:
	const HEAL: int = 2

	func _init() -> void:
		id = &"blood_vial"
		display_name = "血瓶"
		description = "战斗开始时回复 %d 点生命。" % HEAL
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		owner.heal(HEAL)
		announce("回复 %d 点生命" % HEAL)


## 提灯 —— 每场战斗的第一回合额外抽 1 张
class Lantern extends AbstractRelic:
	const EXTRA_DRAW: int = 1

	var _used: bool = false

	func _init() -> void:
		id = &"lantern"
		display_name = "提灯"
		description = "每场战斗的第一个回合额外抽 %d 张牌。" % EXTRA_DRAW
		trigger_text = "战斗第一回合"

	func at_battle_start(_owner: Creature) -> void:
		_used = false

	func on_turn_start(_owner: Creature) -> void:
		if _used or battle == null or battle.deck == null:
			return
		_used = true
		var drawn: Array[CardData] = battle.deck.draw(EXTRA_DRAW)
		if drawn.size() > 0:
			announce("额外抽 %d 张牌" % drawn.size())


## 荆棘指环 —— 战斗开始时获得 3 点荆棘（近战反伤）
class ThornRing extends AbstractRelic:
	const THORNS: int = 3

	func _init() -> void:
		id = &"thorn_ring"
		display_name = "荆棘指环"
		description = "战斗开始时获得 %d 点荆棘。" % THORNS
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Thorns.new(THORNS))
		announce("+%d 荆棘" % THORNS)


## 光滑石 —— 战斗开始时获得 1 点敏捷
class SmoothStone extends AbstractRelic:
	const DEXTERITY: int = 1

	func _init() -> void:
		id = &"smooth_stone"
		display_name = "光滑石"
		description = "战斗开始时获得 %d 点敏捷。" % DEXTERITY
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Dexterity.new(DEXTERITY))
		announce("+%d 敏捷" % DEXTERITY)


## 幸运币 —— 战斗胜利后额外获得金币
##
## 金币属于 RunState，遗物够不着；所以累加到 `battle.bonus_gold`，
## 由场景在结算时一并发放。
class LuckyCoin extends AbstractRelic:
	const BONUS_GOLD: int = 8

	func _init() -> void:
		id = &"lucky_coin"
		display_name = "幸运币"
		description = "战斗胜利后额外获得 %d 金币。" % BONUS_GOLD
		trigger_text = "战斗胜利时"

	func on_battle_end(_owner: Creature, won: bool) -> void:
		if not won or battle == null:
			return
		battle.bonus_gold += BONUS_GOLD
		announce("+%d 金币" % BONUS_GOLD)


## 纸蛙 —— 战斗开始时给所有敌人 1 层虚弱
class PaperFrog extends AbstractRelic:
	const WEAK: int = 1

	func _init() -> void:
		id = &"paper_frog"
		display_name = "纸蛙"
		description = "战斗开始时，给予所有敌人 %d 层虚弱。" % WEAK
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		var applied: int = 0
		for opponent: Creature in owner.opponents:
			if opponent.is_alive():
				opponent.apply_power(BasePowers.Weak.new(WEAK))
				applied += 1
		if applied > 0:
			announce("给 %d 个敌人施加虚弱" % applied)


## id → 实例。**找不到时返回 null**（由工厂统一告警，避免这里刷屏）
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
		&"lantern":
			return Lantern.new()
		&"thorn_ring":
			return ThornRing.new()
		&"smooth_stone":
			return SmoothStone.new()
		&"lucky_coin":
			return LuckyCoin.new()
		&"paper_frog":
			return PaperFrog.new()
		_:
			return null


static func ids() -> Array[StringName]:
	return [
		&"burning_blood", &"vajra", &"anchor_chain", &"blood_vial",
		&"lantern", &"thorn_ring", &"smooth_stone", &"lucky_coin", &"paper_frog",
	]
