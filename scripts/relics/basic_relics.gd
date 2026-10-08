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


## 战旗 —— 战斗开始时获得 2 点力量
class WarBanner extends AbstractRelic:
	const STRENGTH: int = 2

	func _init() -> void:
		id = &"war_banner"
		display_name = "战旗"
		description = "战斗开始时获得 %d 点力量。" % STRENGTH
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(STRENGTH))
		announce("+%d 力量" % STRENGTH)


## 铁靴 —— 战斗开始时获得 2 点敏捷
class IronBoots extends AbstractRelic:
	const DEXTERITY: int = 2

	func _init() -> void:
		id = &"iron_boots"
		display_name = "铁靴"
		description = "战斗开始时获得 %d 点敏捷。" % DEXTERITY
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Dexterity.new(DEXTERITY))
		announce("+%d 敏捷" % DEXTERITY)


## 幸运骰 —— 战斗胜利后额外获得金币
class LuckyDice extends AbstractRelic:
	const BONUS_GOLD: int = 12

	func _init() -> void:
		id = &"lucky_dice"
		display_name = "幸运骰"
		description = "战斗胜利后额外获得 %d 金币。" % BONUS_GOLD
		trigger_text = "战斗胜利时"

	func on_battle_end(_owner: Creature, won: bool) -> void:
		if not won or battle == null:
			return
		battle.bonus_gold += BONUS_GOLD
		announce("+%d 金币" % BONUS_GOLD)


## 药囊 —— 战斗胜利后回复生命
class HerbPouch extends AbstractRelic:
	const HEAL: int = 3

	func _init() -> void:
		id = &"herb_pouch"
		display_name = "药囊"
		description = "战斗胜利后回复 %d 点生命。" % HEAL
		trigger_text = "战斗胜利时"

	func on_battle_end(owner: Creature, won: bool) -> void:
		if not won:
			return
		owner.heal(HEAL)
		announce("回复 %d 点生命" % HEAL)


## ══ 阶段 7 新增：修复型遗物 ══════════════════════════════════
##
## 这一批解决两个已登记的数值问题：
##   · **A1 玩家无成长**：敌人血量三幕 +533%，而玩家 max_hp 全程恒 30。
##     → `stone_heart` / `iron_lung` 提供**永久**最大生命成长。
##   · **B3 可掉落遗物池只有 13 个**：一局期望掉落 ~10 个，逼近上限后
##     "精英必掉遗物"会静默失效。→ 池子扩到 22 个。

## 石心 —— **获得时**最大生命 +6（永久）
##
## ⚠️ 效果**不在本类里实现**：写在 `RunState.grant_relic()` 里。
## 遗物实例每场战斗重建，若把 "+6 最大生命" 挂在 `at_battle_start`，
## 会每场叠加一次并被 `sync_from_creature` 持久化 → **无限增长**。
## 详见 `RunState.RELIC_MAX_HP_BONUS` 的注释。
class StoneHeart extends AbstractRelic:
	const MAX_HP_BONUS: int = 6

	func _init() -> void:
		id = &"stone_heart"
		display_name = "石心"
		description = "获得时最大生命 +%d（永久）。" % MAX_HP_BONUS
		trigger_text = "获得时"


## 铁肺 —— **获得时**最大生命 +4（永久）。数值低于石心，换取更低的稀有度
class IronLung extends AbstractRelic:
	const MAX_HP_BONUS: int = 4

	func _init() -> void:
		id = &"iron_lung"
		display_name = "铁肺"
		description = "获得时最大生命 +%d（永久）。" % MAX_HP_BONUS
		trigger_text = "获得时"


## 处刑之刃 —— 击杀敌人时获得 2 点力量
##
## 与「金刚杵」（开场 +1 力量）的区别：**它奖励滚雪球**。
## 面对多敌人时越打越强，但面对单体 Boss 几乎无用——这是刻意的取舍。
class ExecutionerEdge extends AbstractRelic:
	const STRENGTH: int = 2

	func _init() -> void:
		id = &"executioner_edge"
		display_name = "处刑之刃"
		description = "击杀敌人时获得 %d 点力量。" % STRENGTH
		trigger_text = "击杀敌人时"

	func on_kill(owner: Creature, target: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(STRENGTH))
		announce("处刑 %s：+%d 力量" % [target.display_name, STRENGTH])


## 嗜血指环 —— 击杀敌人时回复 3 点生命
class BloodthirstRing extends AbstractRelic:
	const HEAL: int = 3

	func _init() -> void:
		id = &"bloodthirst_ring"
		display_name = "嗜血指环"
		description = "击杀敌人时回复 %d 点生命。" % HEAL
		trigger_text = "击杀敌人时"

	func on_kill(owner: Creature, _target: Creature) -> void:
		owner.heal(HEAL)
		announce("吸血：回复 %d 点生命" % HEAL)


## 铁意志 —— 每次受到伤害后获得 1 点格挡
##
## 它把"挨打"变成一种资源：**多段小伤害的敌人反而打不动你**，
## 但一次性大伤害它救不了。定位是"抗压"而不是"免伤"。
class IronWill extends AbstractRelic:
	const BLOCK: int = 1

	func _init() -> void:
		id = &"iron_will"
		display_name = "铁意志"
		description = "每次受到伤害后获得 %d 点格挡。" % BLOCK
		trigger_text = "受到伤害后"

	func on_damage_taken(owner: Creature, _amount: int) -> void:
		owner.gain_block(BLOCK)


## 赤红透镜 —— 战斗开始时给所有敌人 2 层易伤
##
## 与「纸蛙」（1 层虚弱）互补：虚弱降**输出**，易伤提**承伤**。
## 易伤更强，所以层数相同但触发更值钱——这是有意的强度差。
class CrimsonLens extends AbstractRelic:
	const VULNERABLE: int = 2

	func _init() -> void:
		id = &"crimson_lens"
		display_name = "赤红透镜"
		description = "战斗开始时，给予所有敌人 %d 层易伤。" % VULNERABLE
		trigger_text = "战斗开始时"

	func at_battle_start(owner: Creature) -> void:
		var applied: int = 0
		for opponent: Creature in owner.opponents:
			if opponent.is_alive():
				opponent.apply_power(BasePowers.Vulnerable.new(VULNERABLE))
				applied += 1
		if applied > 0:
			announce("给 %d 个敌人施加易伤" % applied)


## 迅捷手套 —— 每回合开始获得 1 点格挡
##
## 与「锚链」（开场 4 格挡）的区别：**它是持续的小额减伤**。
## 长战斗里总收益远超锚链，短战斗里不如锚链——奖励"拖长回合"的打法。
class SwiftGloves extends AbstractRelic:
	const BLOCK: int = 1

	func _init() -> void:
		id = &"swift_gloves"
		display_name = "迅捷手套"
		description = "每回合开始时获得 %d 点格挡。" % BLOCK
		trigger_text = "每回合开始时"

	func on_turn_start(owner: Creature) -> void:
		owner.gain_block(BLOCK)


## 金像 —— 战斗胜利后额外获得 15 金币
##
## 池子里第三个金币遗物（幸运币 8 / 幸运骰 12 / 金像 15）。
## 数值递进是有意的：让"经济流"有明确的强度阶梯，而不是三件等价物。
class GoldenIdol extends AbstractRelic:
	const BONUS_GOLD: int = 15

	func _init() -> void:
		id = &"golden_idol"
		display_name = "金像"
		description = "战斗胜利后额外获得 %d 金币。" % BONUS_GOLD
		trigger_text = "战斗胜利时"

	func on_battle_end(_owner: Creature, won: bool) -> void:
		if not won or battle == null:
			return
		battle.bonus_gold += BONUS_GOLD
		announce("+%d 金币" % BONUS_GOLD)


## 休憩图腾 —— 战斗胜利后回复 4 点生命
##
## 池子里第三个回血遗物（燃烧之血 5 / 药囊 3 / 休憩图腾 4）。
## 4 点是刻意的中间值：药囊太弱、燃烧之血是战士专属起点。
class RestTotem extends AbstractRelic:
	const HEAL: int = 4

	func _init() -> void:
		id = &"rest_totem"
		display_name = "休憩图腾"
		description = "战斗胜利后回复 %d 点生命。" % HEAL
		trigger_text = "战斗胜利时"

	func on_battle_end(owner: Creature, won: bool) -> void:
		if not won:
			return
		owner.heal(HEAL)
		announce("回复 %d 点生命" % HEAL)


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
		&"war_banner":
			return WarBanner.new()
		&"iron_boots":
			return IronBoots.new()
		&"lucky_dice":
			return LuckyDice.new()
		&"herb_pouch":
			return HerbPouch.new()
		&"stone_heart":
			return StoneHeart.new()
		&"iron_lung":
			return IronLung.new()
		&"executioner_edge":
			return ExecutionerEdge.new()
		&"bloodthirst_ring":
			return BloodthirstRing.new()
		&"iron_will":
			return IronWill.new()
		&"crimson_lens":
			return CrimsonLens.new()
		&"swift_gloves":
			return SwiftGloves.new()
		&"golden_idol":
			return GoldenIdol.new()
		&"rest_totem":
			return RestTotem.new()
		_:
			return null


static func ids() -> Array[StringName]:
	return [
		&"burning_blood", &"vajra", &"anchor_chain", &"blood_vial",
		&"lantern", &"thorn_ring", &"smooth_stone", &"lucky_coin", &"paper_frog",
		&"war_banner", &"iron_boots", &"lucky_dice", &"herb_pouch",
		&"stone_heart", &"iron_lung", &"executioner_edge", &"bloodthirst_ring",
		&"iron_will", &"crimson_lens", &"swift_gloves", &"golden_idol", &"rest_totem",
	]
