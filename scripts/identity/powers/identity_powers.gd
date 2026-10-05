class_name IdentityPowers
extends RefCounted
## 终职的**身份能力**（规则刻印）集合
##
## 这些能力满足设计文档 §2.3 的判据——它们改变「游戏怎么玩」，而不是「数字大一点」：
##   - **盾卫**：接通「回合」与「格挡量」（每回合第一张格挡额外 +3）
##   - **壁垒**：**改写格挡清零规则**（本该清零的部分保留一半）
##
## ⚠️ 身份能力必须 `is_identity = true`。`Creature._attach` 会自动把它放进
## `identity_powers` 并强制 `is_turn_based = false`，从而获得「不可剥夺」的保证。


## 一阶 · 盾卫 ——「以身为墙」
## 每回合获得的**第一张**格挡额外 +3。
class ShieldGuardStance extends AbstractPower:
	const BONUS: int = 3

	var _used_this_turn: bool = false

	func _init() -> void:
		id = &"shield_guard_stance"
		display_name = "持盾戒备"
		description = "每回合获得的第一张格挡额外 +%d。" % BONUS
		is_identity = true

	func modify_block(block: int, _card: CardData) -> int:
		if _used_this_turn:
			return block
		_used_this_turn = true
		return block + BONUS

	## 预览版本：**不翻转标志**。否则 UI 每刷新一次卡面就会把加成消耗掉，
	## 玩家会看到「卡面写着 +3，打出去却没加」。
	func preview_block(block: int, _card: CardData) -> int:
		if _used_this_turn:
			return block
		return block + BONUS

	func on_turn_start(_owner: Creature) -> void:
		_used_this_turn = false


## 终职 · 壁垒 ——「最坚固的墙永不倒塌」
##
## **这就是 Q1 定案（decisions.md D10）的落点**：
## 格挡在自身回合开始时清零，本能力把「本该清零的那部分」保留一半（向下取整）。
## 例：clearing = 5 → 保留 2、清 3；clearing = 0 → 保留 0。
##
## 设计上必须存在的弱点：**毒与生命流失无视格挡**——
## 所以壁垒玩家必须准备对策，否则会在特定敌人面前完全失效。
class BastionWall extends AbstractPower:
	func _init() -> void:
		id = &"bastion_wall"
		display_name = "壁垒"
		description = "回合开始时，本该清零的格挡保留一半（向下取整）。"
		is_identity = true

	func at_block_clear(clearing: int, _owner: Creature) -> int:
		return clearing - int(floor(float(clearing) / 2.0))


## 一阶 · 狂战 ——「以伤换伤」
## 每失去 2 点生命获得 1 层怒气。**阶段 4 只做盾卫 / 壁垒线**，
## 这条先实现出来供 Boss 卡冈的「狂姿态」预览使用。
class BloodRage extends AbstractPower:
	const HP_PER_RAGE: int = 2

	var _accumulated: int = 0

	func _init() -> void:
		id = &"blood_rage"
		display_name = "血勇"
		description = "每失去 %d 点生命，获得 1 层怒气。" % HP_PER_RAGE
		is_identity = true

	func on_health_lost(owner: Creature, amount: int) -> void:
		_accumulated += amount
		var gained: int = _accumulated / HP_PER_RAGE
		if gained <= 0:
			return
		_accumulated -= gained * HP_PER_RAGE
		owner.apply_power(BasePowers.Strength.new(gained))


## 终职 · 狂战线的对照项（**阶段 4 不实现完整能力**，仅用于 Boss 预览）
class BerserkerPreview extends AbstractPower:
	func _init() -> void:
		id = &"berserker_preview"
		display_name = "狂战姿态"
		description = "（预览）血量越低，伤害越高。"
		is_identity = true


## 终职 · 盾猛 ——「最好的防守，是正在进攻的防守」
##
## 每当你**实际获得**格挡，立即对当前敌人造成等于本次格挡量 50% 的伤害。
## 伤害类型为 `NORMAL`（决策 2：方案 A），**吃力量 / 易伤**——
## 高频小格挡可触发多次，天然引导「高频盾」构筑。
##
## 触发粒度：每次 `gain_block` 触发一次。3 张各 5 格挡的牌 = 触发 3 次（吃 3 次力量）。
class ShieldBash extends AbstractPower:
	const DAMAGE_RATIO: float = 0.5

	func _init() -> void:
		id = &"shield_bash"
		display_name = "盾猛"
		description = "每当你实际获得格挡，对当前敌人造成该量 50% 的伤害。"
		is_identity = true

	func on_block_gained(owner: Creature, amount: int) -> void:
		var damage: int = int(floor(float(amount) * DAMAGE_RATIO))
		if damage <= 0:
			return
		for opponent: Creature in owner.opponents:
			if opponent.is_alive():
				opponent.take_damage(damage, owner, DamageType.NORMAL)
				break  # 「当前敌人」= 第一个存活的


## 终职 · 嗜血者 ——「血债必须血偿」
##
## ⚠️ 阶段 4 简化实现：设计文档原文要求「怒气跨回合保留」，
## 那需要一套独立于力量的怒气资源。这里先用**永久力量**近似
## （每失 1 血 +1 力量，击杀回 6 血），手感方向一致。
## 完整的怒气资源在阶段 5 的战士线扩展里补。
class Bloodthirster extends AbstractPower:
	const HEAL_PER_KILL: int = 6

	func _init() -> void:
		id = &"bloodthirster"
		display_name = "血偿"
		description = "每失去 1 点生命获得 1 层力量；每击杀一个敌人回复 %d 点生命。" % HEAL_PER_KILL
		is_identity = true

	func on_health_lost(owner: Creature, amount: int) -> void:
		if amount > 0:
			owner.apply_power(BasePowers.Strength.new(amount))

	func on_kill(owner: Creature, _target: Creature) -> void:
		owner.heal(HEAL_PER_KILL)


## 终职 · 鏖战者 ——「攻势一旦开始，就不会停下」
##
## 本回合每打出一张攻击牌，获得 1 层怒涛（每层使攻击牌 +1 伤害，回合结束清零）。
## ⚠️ 阶段 4 简化：怒涛用「回合结束清零的力量」实现，
## 即 [MomentumStrike] 自己在回合结束时移除自己施加的层数。
class MomentumStrike extends AbstractPower:
	func _init() -> void:
		id = &"momentum_strike"
		display_name = "怒涛"
		description = "本回合每打出一张攻击牌，获得 1 层怒涛（每层 +1 攻击伤害）。"
		is_identity = true

	func on_card_played(owner: Creature, card: CardData) -> void:
		if card.type != CardData.CardType.ATTACK:
			return
		# 用一个「回合结束自动清零」的临时力量来表示怒涛
		var temp := BasePowers.Strength.new(1)
		temp.id = &"momentum_stack"
		temp.display_name = "怒涛"
		temp.is_turn_based = true
		owner.apply_power(temp)

	func on_turn_end(owner: Creature) -> void:
		# 怒涛回合结束必定清零（身份能力本身不倒计时，所以要手动清）
		var stack: AbstractPower = owner.get_power(&"momentum_stack")
		if stack != null:
			stack.amount = 0
			owner.prune_expired_powers()


## 神战 P4 · 战神 —— **壁垒的镜像**
##
## 「壁垒保留一半」的对称设计是「战神一点都不放」：
## 它的格挡**永不衰减**，而且每回合还在涨力量。
##
## 玩家的解法不是硬拼，而是**用毒与生命流失绕过格挡**——
## 这正是壁垒的弱点，也是设计文档要求「克制敌人必须存在」的原因：
## 那类敌人同时是玩家的工具。
class GodOfWarStance extends AbstractPower:
	const STRENGTH_PER_TURN: int = 2

	func _init() -> void:
		id = &"god_of_war_stance"
		display_name = "战神姿态"
		description = "格挡永不衰减；每回合获得 %d 点力量。" % STRENGTH_PER_TURN
		is_identity = true

	func at_block_clear(_clearing: int, _owner: Creature) -> int:
		return 0  # 一点都不清

	func on_turn_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(STRENGTH_PER_TURN))


## 神性显化（≥70）—— **不是转职能力，是侵蚀的副作用**
##
## 规则开始在你身上外显：力量暴涨，但每回合都在流失生命。
## 与身份能力的区别：这个**可以被移除**（它不是刻进灵魂的，是附着上来的），
## 而且它带着明确的、会累积的代价——把玩家往"要么早点收手、要么一路走到底"推。
class DivinityManifest extends AbstractPower:
	const STRENGTH: int = 3
	const HP_LOSS_PER_TURN: int = 2

	func _init() -> void:
		id = &"divinity_manifest"
		display_name = "神性显化"
		description = "获得 %d 点力量；每回合开始时失去 %d 点生命。" % [
			STRENGTH, HP_LOSS_PER_TURN,
		]
		is_identity = false

	func on_turn_start(owner: Creature) -> void:
		owner.take_damage(HP_LOSS_PER_TURN, null, DamageType.HP_LOSS)


## 无尽战意（战神软狂暴）—— 每回合 +1 力量，**没有上限**
##
## 它惩罚的是"拖"：玩家每多打一回合，神就强一分。
## 用软狂暴而不是硬性回合上限，是为了让"我还能再撑一回合"这个判断保留意义。
class EndlessWill extends AbstractPower:
	const PER_TURN: int = 1

	func _init() -> void:
		id = &"endless_will"
		display_name = "无尽战意"
		description = "每回合开始时获得 %d 点力量。" % PER_TURN
		is_identity = true

	func on_turn_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(PER_TURN))


## 野性轮回（兽神软狂暴）—— 每 3 回合回复 15% 最大生命
##
## 惩罚的是"慢慢磨"：靠小伤害消耗的战术在这里会失效。
class WildRebirth extends AbstractPower:
	const CYCLE: int = 3
	const HEAL_PERCENT: int = 15

	var _turns: int = 0

	func _init() -> void:
		id = &"wild_rebirth"
		display_name = "野性轮回"
		description = "每 %d 回合回复最大生命的 %d%%。" % [CYCLE, HEAL_PERCENT]
		is_identity = true

	func on_turn_start(owner: Creature) -> void:
		_turns += 1
		if _turns % CYCLE != 0:
			return
		owner.heal(int(ceil(float(owner.max_hp) * float(HEAL_PERCENT) / 100.0)))


## 因果律（法神软狂暴）—— 每回合第一次受到的伤害**减半**
##
## 惩罚的是"攒一波大爆发"：单次巨额伤害被腰斩，逼玩家改成多段小伤害——
## 与"多段敌人"形成镜像对照。
class Causality extends AbstractPower:
	var _used_this_turn: bool = false

	func _init() -> void:
		id = &"causality"
		display_name = "因果律"
		description = "每回合第一次受到的伤害减半。"
		is_identity = true

	func on_turn_start(_owner: Creature) -> void:
		_used_this_turn = false

	func at_damage_take(value: float, _info: DamageInfo) -> float:
		if _used_this_turn:
			return value
		_used_this_turn = true
		return value * 0.5


## ══ 法师线（阶段 5 横向扩展 · 第二条线）══════════════════════
##
## 法师的机制核心是**资源管线本身**（设计文档：元素反应 / 奥术蓄力是纯资源管线，
## 不依赖任何新实体系统）——所以这条线风险最低，排在猎人前面。

## 元素亲和（一阶 · 元素使）—— 每回合第一次打出攻击牌时施加易伤
##
## "第一次"而不是"每次"：每次的话它会退化成"多打攻击牌就完事"，
## 而第一次逼玩家**把最重的那张牌放在第一位**——这才是元素的节奏感。
class ElementalAttunement extends AbstractPower:
	const VULNERABLE: int = 2

	var _used_this_turn: bool = false

	func _init() -> void:
		id = &"elemental_attunement"
		display_name = "元素亲和"
		description = "每回合第一次打出攻击牌时，给予目标 %d 层易伤。" % VULNERABLE
		is_identity = true

	func on_turn_start(_owner: Creature) -> void:
		_used_this_turn = false

	func on_card_played(owner: Creature, card: CardData) -> void:
		if _used_this_turn or card.type != CardData.CardType.ATTACK:
			return
		_used_this_turn = true
		for opponent: Creature in owner.opponents:
			if opponent.is_alive():
				opponent.apply_power(BasePowers.Vulnerable.new(VULNERABLE))
				break


## 奥术蓄力（一阶 · 奥术师）—— 回合结束时把没用掉的能量转成格挡
##
## 惩罚"留一手"的同时给一条出路：**能量不浪费，但只能变成防御**。
class ArcaneCharge extends AbstractPower:
	const BLOCK_PER_ENERGY: int = 3

	func _init() -> void:
		id = &"arcane_charge"
		display_name = "奥术蓄力"
		description = "回合结束时，每点未使用的能量转化为 %d 点格挡。" % BLOCK_PER_ENERGY
		is_identity = true

	func on_turn_end(owner: Creature) -> void:
		if owner.energy <= 0:
			return
		owner.gain_block(owner.energy * BLOCK_PER_ENERGY)


## 烈焰之心（终职 · 烈焰）—— 攻击牌附带燃烧
class FlameHeart extends AbstractPower:
	const POISON: int = 2

	func _init() -> void:
		id = &"flame_heart"
		display_name = "烈焰之心"
		description = "每次打出攻击牌，额外给予目标 %d 层中毒。" % POISON
		is_identity = true

	func on_card_played(owner: Creature, card: CardData) -> void:
		if card.type != CardData.CardType.ATTACK:
			return
		for opponent: Creature in owner.opponents:
			if opponent.is_alive():
				opponent.apply_power(BasePowers.Poison.new(POISON))
				break


## 霜之护盾（终职 · 冰霜）—— 每回合第一次受到的伤害减半
class FrostShield extends AbstractPower:
	var _used_this_turn: bool = false

	func _init() -> void:
		id = &"frost_shield"
		display_name = "霜之护盾"
		description = "每回合第一次受到的伤害减半。"
		is_identity = true

	func on_turn_start(_owner: Creature) -> void:
		_used_this_turn = false

	func at_damage_take(value: float, _info: DamageInfo) -> float:
		if _used_this_turn:
			return value
		_used_this_turn = true
		return value * 0.5


## 秘法专注（终职 · 秘法）—— 每回合稳定增长的力量
class ArcaneFocus extends AbstractPower:
	const STRENGTH_PER_TURN: int = 2

	func _init() -> void:
		id = &"arcane_focus"
		display_name = "秘法专注"
		description = "每回合开始时获得 %d 点力量。" % STRENGTH_PER_TURN
		is_identity = true

	func on_turn_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(STRENGTH_PER_TURN))


## 时序流转（终职 · 时序）—— 每回合开始获得格挡与敏捷
##
## 与"力量"路线的对照：秘法涨伤害，时序涨生存。
## **同一个一阶分出的两个终职应该给出相反的建议**，否则选哪个都一样。
class TimeFlow extends AbstractPower:
	const BLOCK: int = 3
	const DEXTERITY: int = 1

	func _init() -> void:
		id = &"time_flow"
		display_name = "时序流转"
		description = "每回合开始时获得 %d 点格挡与 %d 点敏捷。" % [BLOCK, DEXTERITY]
		is_identity = true

	func on_turn_start(owner: Creature) -> void:
		owner.gain_block(BLOCK)
		owner.apply_power(BasePowers.Dexterity.new(DEXTERITY))


## ══ 猎人线（阶段 5 横向扩展 · 第三条线）══════════════════════
##
## 猎人引入**友方单位**——这条线风险最高，所以排最后（设计文档 R5）。

## 兽之羁绊（一阶 · 驯兽师）—— 每回合结束获得格挡
class BeastBond extends AbstractPower:
	const BLOCK: int = 3

	func _init() -> void:
		id = &"beast_bond"
		display_name = "兽之羁绊"
		description = "每回合结束时获得 %d 点格挡。" % BLOCK
		is_identity = true

	func on_turn_end(owner: Creature) -> void:
		owner.gain_block(BLOCK)


## 猎手印记（一阶 · 游侠）—— 每回合第一次攻击牌施加易伤
class HunterMark extends AbstractPower:
	const VULNERABLE: int = 2

	var _used_this_turn: bool = false

	func _init() -> void:
		id = &"hunter_mark"
		display_name = "猎手印记"
		description = "每回合第一次打出攻击牌时，给予目标 %d 层易伤。" % VULNERABLE
		is_identity = true

	func on_turn_start(_owner: Creature) -> void:
		_used_this_turn = false

	func on_card_played(owner: Creature, card: CardData) -> void:
		if _used_this_turn or card.type != CardData.CardType.ATTACK:
			return
		_used_this_turn = true
		for opponent: Creature in owner.opponents:
			if opponent.is_alive():
				opponent.apply_power(BasePowers.Vulnerable.new(VULNERABLE))
				break


## 头狼嗥叫（终职 · 兽王）—— 每回合 +2 力量
class AlphaHowl extends AbstractPower:
	const STRENGTH: int = 2

	func _init() -> void:
		id = &"alpha_howl"
		display_name = "头狼嗥叫"
		description = "每回合开始时获得 %d 点力量。" % STRENGTH
		is_identity = true

	func on_turn_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Strength.new(STRENGTH))


## 群猎战术（终职 · 驯鹰者）—— 每回合 +2 格挡 +1 敏捷
class PackTactics extends AbstractPower:
	const BLOCK: int = 2
	const DEXTERITY: int = 1

	func _init() -> void:
		id = &"pack_tactics"
		display_name = "群猎战术"
		description = "每回合开始时获得 %d 点格挡与 %d 点敏捷。" % [BLOCK, DEXTERITY]
		is_identity = true

	func on_turn_start(owner: Creature) -> void:
		owner.gain_block(BLOCK)
		owner.apply_power(BasePowers.Dexterity.new(DEXTERITY))


## 追猎（终职 · 追猎者）—— 每次造成伤害额外 +4
##
## 用 `at_damage_give`（修正链第 ② 步，**最先介入**），所以会被力量/虚弱/易伤放大。
## 与"施加 Power"的模式相反：这是**一次性、可被放大**的加值。
class Pursuer extends AbstractPower:
	const BONUS: int = 4

	func _init() -> void:
		id = &"pursuer"
		display_name = "追猎"
		description = "每次造成伤害额外 +%d（会被力量 / 易伤放大）。" % BONUS
		is_identity = true

	func at_damage_give(value: float, _info: DamageInfo) -> float:
		return value + float(BONUS)


## 荆棘之皮（终职 · 荆棘游侠）—— 开场带荆棘
class ThornHide extends AbstractPower:
	const THORNS: int = 4

	func _init() -> void:
		id = &"thorn_hide"
		display_name = "荆棘之皮"
		description = "战斗开始时获得 %d 点荆棘。" % THORNS
		is_identity = true

	func at_battle_start(owner: Creature) -> void:
		owner.apply_power(BasePowers.Thorns.new(THORNS))


## id → 构造器。新增身份能力时只需在这里加一行。
static func create(power_id: StringName) -> AbstractPower:
	match power_id:
		&"shield_guard_stance":
			return ShieldGuardStance.new()
		&"bastion_wall":
			return BastionWall.new()
		&"shield_bash":
			return ShieldBash.new()
		&"blood_rage":
			return BloodRage.new()
		&"bloodthirster":
			return Bloodthirster.new()
		&"momentum_strike":
			return MomentumStrike.new()
		&"god_of_war_stance":
			return GodOfWarStance.new()
		&"berserker_preview":
			return BerserkerPreview.new()
		&"divinity_manifest":
			return DivinityManifest.new()
		&"endless_will":
			return EndlessWill.new()
		&"wild_rebirth":
			return WildRebirth.new()
		&"causality":
			return Causality.new()
		&"elemental_attunement":
			return ElementalAttunement.new()
		&"arcane_charge":
			return ArcaneCharge.new()
		&"flame_heart":
			return FlameHeart.new()
		&"frost_shield":
			return FrostShield.new()
		&"arcane_focus":
			return ArcaneFocus.new()
		&"time_flow":
			return TimeFlow.new()
		&"beast_bond":
			return BeastBond.new()
		&"hunter_mark":
			return HunterMark.new()
		&"alpha_howl":
			return AlphaHowl.new()
		&"pack_tactics":
			return PackTactics.new()
		&"pursuer":
			return Pursuer.new()
		&"thorn_hide":
			return ThornHide.new()
		_:
			push_warning("IdentityPowers: 未知身份能力 id「%s」" % power_id)
			return null
