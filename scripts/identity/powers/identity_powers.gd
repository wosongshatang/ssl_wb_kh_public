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
## ## 阶段 9 兑现了挂很久的 TODO
## 旧版注释写着「怒气跨回合保留……完整的怒气资源在阶段 5 的战士线扩展里补」，
## 而阶段 5 过去了**没有兑现**——它一直用「永久力量」顶着。
##
## 现在用真正的 [BasePowers.Rage]：
##   · 效果与力量一致（+1 伤害 / 层，跨回合保留）
##   · **但玩家面板上看到的是"怒气"而不是"力量"**——
##     对狂战玩家来说，"我攒了 8 层怒气"和"我有 8 点力量"是完全不同的心理暗示
##   · 来源唯一（只有失血），所以它天然与"压血线"绑定
class Bloodthirster extends AbstractPower:
	const HEAL_PER_KILL: int = 6

	func _init() -> void:
		id = &"bloodthirster"
		display_name = "血偿"
		description = "每失去 1 点生命获得 1 层怒气；每击杀一个敌人回复 %d 点生命。" % HEAL_PER_KILL
		is_identity = true

	func on_health_lost(owner: Creature, amount: int) -> void:
		if amount > 0:
			owner.apply_power(BasePowers.Rage.new(amount))

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

## 元素亲和（一阶 · 元素师）—— 打出带元素属性的牌时附着对应元素
##
## ## ⚠️ 元素种类由**卡牌**决定，不由能力决定
## `CardData.element` 写明这张牌是燃还是霜。
## 如果让能力写死元素种类，所有牌都会上同一种元素，
## **反应就永远不会发生**——而那正是这条线的核心玩法。
##
## ## 为什么走 ElementSystem 而不是直接 apply_power
## 燃 + 霜 要触发蒸汽反应。反应判定必须唯一，
## 否则每张元素牌各判一次，迟早漏一处（见 [ElementSystem] 的类文档）。
class ElementalAttunement extends AbstractPower:
	func _init() -> void:
		id = &"elemental_attunement"
		display_name = "元素亲和"
		description = "打出带元素属性的牌时，给目标附着对应元素。燃霜共存触发蒸汽。"
		is_identity = true

	func on_card_played(owner: Creature, card: CardData) -> void:
		if card.element == &"":
			return
		for opponent: Creature in owner.opponents:
			if opponent.is_alive():
				ElementSystem.apply_element(opponent, card.element, 1)
				break


## 风暴使者（终职 · 元素师线）—— 元素反应强化
##
## 与一阶「元素亲和」的分工：一阶负责**附着**，它负责**放大反应的收益**。
## 没有它也能触发蒸汽（那是元素系统的通用规则），但有了它才值得围绕反应构筑。
##
## 另外它让元素**每回合自动增殖 1 层**——这是"越拖越强"的来源，
## 也逼玩家在"现在反应"和"再攒一层"之间做选择。
class Stormcaller extends AbstractPower:
	## 蒸汽伤害的额外倍率（在 ElementSystem 的基准倍率之上再加）
	const STEAM_BONUS: int = 1
	## 每回合自动给已带元素的目标 +1 层（不新增元素种类）
	const GROW_PER_TURN: int = 1

	func _init() -> void:
		id = &"stormcaller"
		display_name = "风暴使者"
		description = "每回合开始时，已附着元素的目标各 +%d 层；蒸汽伤害额外 +%d。" % [
			GROW_PER_TURN, STEAM_BONUS,
		]
		is_identity = true

	func on_turn_start(owner: Creature) -> void:
		for opponent: Creature in owner.opponents:
			if not opponent.is_alive():
				continue
			for element: StringName in ElementSystem.elements_on(opponent):
				# ⚠️ 走 ElementSystem 而不是 apply_power——
				# 增殖也可能把霜推过 5 层阈值触发冻结，那是元素的规则。
				ElementSystem.apply_element(opponent, element, GROW_PER_TURN)


## 奥术圣贤（终职 · 元素师线）—— 未用能量转奥术，蓄力换爆发
##
## 与「风暴使者」的对照：**风暴使者是高频连锁，奥术圣贤是低频巨炮**。
## 同一张一阶分出的两个终职必须给出**相反的建议**，否则选哪个都一样。
##
## ## 为什么每回合限一次兑换
## "5 层换 2 能量"不限制的话会变成**无限循环**：
## 攒够 → 换能量 → 能量没用完 → 又转奥术 → 又攒够……
## 限制每回合一次，它才是"关键时刻兑现"而不是"自动机器"。
class Archsage extends AbstractPower:
	## 每点未用能量转多少层奥术
	const ARCANE_PER_ENERGY: int = 1
	## 兑换比率：多少层奥术换多少能量
	const EXCHANGE_COST: int = 5
	const EXCHANGE_GAIN: int = 2

	var _exchanged_this_turn: bool = false

	func _init() -> void:
		id = &"archsage"
		display_name = "奥术圣贤"
		description = "回合结束时每点未用能量转 %d 层奥术；可消耗 %d 层换 %d 点能量（每回合限一次）。" % [
			ARCANE_PER_ENERGY, EXCHANGE_COST, EXCHANGE_GAIN,
		]
		is_identity = true

	func on_turn_start(_owner: Creature) -> void:
		_exchanged_this_turn = false

	func on_turn_end(owner: Creature) -> void:
		if owner.energy > 0:
			owner.apply_power(BasePowers.Arcane.new(owner.energy * ARCANE_PER_ENERGY))

	## 把奥术层数当能量花掉（每回合限一次）。
	##
	## 走 `energy_subsidy_max` / `consume_energy_subsidy` 这对钩子，
	## 而不是直接加能量——这样它和死灵师的魂能**共用同一条代付通道**，
	## 不会出现两套"另类付费"逻辑。
	func energy_subsidy_max(cost: int, _card: CardData) -> int:
		if _exchanged_this_turn or cost <= 0:
			return 0
		if owner_creature == null:
			return 0
		var arcane: int = owner_creature.get_power_amount(&"arcane")
		if arcane < EXCHANGE_COST:
			return 0
		return mini(EXCHANGE_GAIN, cost)

	func consume_energy_subsidy(amount: int) -> void:
		if amount <= 0 or owner_creature == null:
			return
		_exchanged_this_turn = true
		owner_creature.reduce_power(&"arcane", EXCHANGE_COST)


## 禁忌知识（一阶 · 咒术师）—— 把"消耗"从代价变成动作
##
## 别的职业那里，消耗是**打出强牌要付的代价**；
## 咒术师把它变成**主动动作**：把废牌烧掉换过牌，润滑手牌。
## 这是"废弃物流转"这条线的入口——一阶只负责打开阀门，
## 真正的收益在二阶（死灵师 / 契约师）。
class Hexmaster extends AbstractPower:
	var _drew_once: bool = false

	func _init() -> void:
		id = &"hexmaster"
		display_name = "禁忌知识"
		description = "每场战斗第一次消耗牌时，抽 1 张牌。"
		is_identity = true

	func at_battle_start(_owner: Creature) -> void:
		_drew_once = false

	func on_card_exhausted(_owner: Creature, _card: CardData) -> void:
		if _drew_once or battle == null or battle.deck == null:
			return
		_drew_once = true
		battle.deck.draw(1)


## 死灵师（终职 · 咒术师线）—— 把"消耗"和"死亡"都变成魂能
##
## ## 与契约师的对照
## **同为负面资源化，燃料不同**：死灵师烧的是"牌"，契约师烧的是"诅咒"。
##
## ## 魂能是**战斗内**资源，不进 RunState
## 它的用途是"代付能量"——那是**回合内决策**。
## 跨战斗保存会让"攒魂能再打 Boss"变成无脑最优解。
class Necromancer extends AbstractPower:
	## 牌被消耗 → +多少魂能
	const SOUL_PER_EXHAUST: int = 1
	## 敌人死亡 → +多少魂能
	const SOUL_PER_KILL: int = 2
	## 每回合最多用魂能代付多少能量。
	## **上限必须有**——无上限会让高费牌变免费，直接摧毁能量曲线。
	const SUBSIDY_PER_TURN: int = 2
	## 骸骨兵上限
	const MAX_SKELETONS: int = 3

	var soul: int = 0
	var _subsidized_this_turn: int = 0

	func _init() -> void:
		id = &"necromancer"
		display_name = "死灵师"
		description = "牌被消耗 +%d 魂能，击杀 +%d；魂能可代付能量（每回合上限 %d）；击杀召唤骸骨兵（上限 %d）。" % [
			SOUL_PER_EXHAUST, SOUL_PER_KILL, SUBSIDY_PER_TURN, MAX_SKELETONS,
		]
		is_identity = true

	func at_battle_start(_owner: Creature) -> void:
		soul = 0
		_subsidized_this_turn = 0

	func on_turn_start(_owner: Creature) -> void:
		_subsidized_this_turn = 0

	func on_card_exhausted(_owner: Creature, _card: CardData) -> void:
		soul += SOUL_PER_EXHAUST

	func on_kill(owner: Creature, _target: Creature) -> void:
		soul += SOUL_PER_KILL
		_summon_skeleton(owner)

	# ── 魂能代付能量 ────────────────────────────────────────
	# 走 AbstractPower 的通用代付钩子，与奥术圣贤的"奥术换能量"共用通道。

	func energy_subsidy_max(cost: int, _card: CardData) -> int:
		if cost <= 0 or soul <= 0:
			return 0
		var remaining: int = SUBSIDY_PER_TURN - _subsidized_this_turn
		if remaining <= 0:
			return 0
		return mini(mini(soul, remaining), cost)

	func consume_energy_subsidy(amount: int) -> void:
		if amount <= 0:
			return
		soul = maxi(0, soul - amount)
		_subsidized_this_turn += amount

	# ── 骸骨兵 ─────────────────────────────────────────────

	## 复用**现有的盟友系统**（`card.summon_ally_id` → `_summon_ally()`）。
	## 没有新造一套召唤物逻辑——骸骨兵就是一只 `data/allies/skeleton.tres`。
	func _summon_skeleton(_owner: Creature) -> void:
		if battle == null:
			return
		if battle.allies.size() >= MAX_SKELETONS:
			return
		battle.summon_ally(&"skeleton")


## 契约师（终职 · 咒术师线）—— 把诅咒牌变成可打的核弹
##
## ## 只做"诅咒可打"，**不做**"+1 最大生命"
## 参考文档的契约师还有"每加一张诅咒永久 +1 最大生命"。
## 我们**刻意不做**这一半：项目里已经有**两套负面资源**
## （诅咒 / 神性侵蚀），再加"诅咒反而加血上限"会让玩家分不清
## "该躲诅咒还是该攒诅咒"——两套系统的边界会糊掉。
##
## ## 数值为什么不照抄参考文档
## 参考是「6 能量 / 40 伤害 + 8 生命流失」。我们只有 **3 点能量**，
## 6 能量是两回合的量；而 40 伤害对 20–46 血的敌人是**直接秒杀**。
## 降到 2 能量 / 18 伤害，保留"用命换爆发"的手感。
class Contractor extends AbstractPower:
	## 打出诅咒牌的能量花费（覆盖卡牌自身的 0 费）
	const CURSE_COST: int = 2
	const CURSE_DAMAGE: int = 18
	const CURSE_HP_LOSS: int = 8

	func _init() -> void:
		id = &"contractor"
		display_name = "契约师"
		description = "诅咒牌可以打出：消耗 %d 能量，造成 %d 伤害，自身失去 %d 生命。" % [
			CURSE_COST, CURSE_DAMAGE, CURSE_HP_LOSS,
		]
		is_identity = true

	## 允许打出"本来不可打出"的牌——**只放行诅咒**，
	## 否则会把"不可打出"这个机制整个废掉。
	func allows_playing(card: CardData) -> bool:
		return card.rarity == CardData.Rarity.CURSE

	## 诅咒牌的费用由契约师接管
	func modify_energy_cost(_cost: int, card: CardData) -> int:
		if card.rarity == CardData.Rarity.CURSE:
			return CURSE_COST
		return _cost

	## 打出诅咒时：造成伤害 + 自身生命流失
	func on_card_played(owner: Creature, card: CardData) -> void:
		if card.rarity != CardData.Rarity.CURSE:
			return
		for opponent: Creature in owner.opponents:
			if opponent.is_alive():
				opponent.take_damage(CURSE_DAMAGE, owner, DamageType.NORMAL)
				break
		# 生命流失**无视格挡**——这是契约的代价，不能被防御手段规避
		owner.take_damage(CURSE_HP_LOSS, null, DamageType.HP_LOSS)


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


## 猎手印记（一阶 · 游侠）—— 造成攻击时给目标叠印记
##
## ## 与旧版的区别（这是"机制特色"的关键一步）
## 旧版是「每回合第一次攻击 → 给 2 层**易伤**」——而法师的「元素亲和」
## 是**一模一样的代码**。两条线的一阶机制完全相同，玩家当然感觉不到区别。
##
## 新版改成**真正的印记层数**：
##   · 可累积（上限 10），**不随回合衰减**
##   · 每层 +10% 受到你的伤害（乘法）
## 于是它奖励"持续盯住同一个目标"，与"易伤"（奖励这一回合打一发大的）语义不同。
class HunterMark extends AbstractPower:
	const LAYERS_PER_HIT: int = 1

	func _init() -> void:
		id = &"hunter_mark"
		display_name = "猎手印记"
		description = "每次打出攻击牌，给目标叠 %d 层印记（每层 +10%% 受到你的伤害，上限 %d 层）。" % [
			LAYERS_PER_HIT, BasePowers.Mark.MAX_STACKS,
		]
		is_identity = true

	func on_card_played(owner: Creature, card: CardData) -> void:
		if card.type != CardData.CardType.ATTACK:
			return
		for opponent: Creature in owner.opponents:
			if opponent.is_alive():
				opponent.apply_power(BasePowers.Mark.new(LAYERS_PER_HIT))
				break


## 神射手（终职 · 游侠线）—— 印记满层引爆，延迟处决
##
## 与「风行者」的对照：**神射手是单点延迟爆破，风行者是回合内高频连射**。
##
## ## 为什么它自己也要上印记
## 一阶「猎手印记」已经在上印记了，这里再上一次是为了：
##   1. 让"神射手 = 印记专精"这件事在数值上成立（叠得更快）
##   2. **避免依赖能力之间的执行顺序**——
##      如果只靠一阶上印记、这里只做判定，那么"判定先于上印记执行"时
##      引爆会永远慢一拍。自己上自己判，顺序就无关了。
class Marksman extends AbstractPower:
	## 满层阈值
	const THRESHOLD: int = 10
	## 引爆伤害 = 目标**已损生命**的百分比
	const LOST_HP_RATIO: float = 0.40
	## 精英 / Boss 的封顶：引爆伤害不超过其**最大生命**的百分比
	##
	## ⚠️ **这个封顶是硬需求**：没有它，"打残血 Boss 一发引爆"会直接秒杀，
	## 整场 Boss 战的设计就被一个机制废掉了。
	const BOSS_CAP_RATIO: float = 0.15
	## 额外叠印记层数（在猎手印记之上）
	const EXTRA_MARK: int = 1

	func _init() -> void:
		id = &"marksman"
		display_name = "神射手"
		description = "攻击牌额外叠 %d 层印记；满 %d 层引爆，造成已损生命 %d%% 的伤害（精英/Boss 封顶其最大生命 %d%%）。" % [
			EXTRA_MARK, THRESHOLD, int(LOST_HP_RATIO * 100.0), int(BOSS_CAP_RATIO * 100.0),
		]
		is_identity = true

	func on_card_played(owner: Creature, card: CardData) -> void:
		if card.type != CardData.CardType.ATTACK:
			return
		for opponent: Creature in owner.opponents:
			if not opponent.is_alive():
				continue
			opponent.apply_power(BasePowers.Mark.new(EXTRA_MARK))
			var mark: AbstractPower = opponent.get_power(&"mark")
			if mark != null and mark.amount >= THRESHOLD:
				_detonate(owner, opponent)
			break

	func _detonate(owner: Creature, target: Creature) -> void:
		var lost: int = maxi(0, target.max_hp - target.hp)
		var damage: int = int(floor(float(lost) * LOST_HP_RATIO))
		if _is_elite_or_boss(target):
			damage = mini(damage, int(floor(float(target.max_hp) * BOSS_CAP_RATIO)))
		# 至少 1 点：满层引爆如果打出 0，"攒满"这件事就毫无反馈
		damage = maxi(damage, 1)

		target.remove_power(&"mark")
		target.take_damage(damage, owner, DamageType.NORMAL)

	func _is_elite_or_boss(target: Creature) -> bool:
		var enemy := target as Enemy
		if enemy == null or enemy.data == null:
			return false
		return enemy.data.is_elite or enemy.data.is_boss


## 风行者（终职 · 游侠线）—— 首张攻击牌结算两次
##
## ## 为什么只复制"第一张"
## 每张都复制等于伤害翻倍——那不是一个"机制"，是一个乘数。
## 只复制第一张，玩家就必须**把最重的那张牌排在第一位**：
## 这是排序决策，不是无脑增益。
##
## ## 复用 `replay_card_effects` 而不是另写一份结算
## 另写一份"复制的结算"迟早与正常结算不一致（少算了某个字段），
## 而且那种偏差**不报错**——玩家只会觉得"这张牌好像弱一点"。
class Windwalker extends AbstractPower:
	const EXTRA_DRAW: int = 1

	var _used_this_turn: bool = false

	func _init() -> void:
		id = &"windwalker"
		display_name = "风行者"
		description = "每回合第一张攻击牌结算两次；每回合额外抽 %d 张牌。" % EXTRA_DRAW
		is_identity = true

	func on_turn_start(owner: Creature) -> void:
		_used_this_turn = false
		if battle != null and battle.deck != null:
			battle.deck.draw(EXTRA_DRAW)

	func on_card_played(owner: Creature, card: CardData) -> void:
		if _used_this_turn or card.type != CardData.CardType.ATTACK:
			return
		_used_this_turn = true
		if battle == null:
			return
		battle.replay_card_effects(card)


## 兽化者（终职 · 驯兽师线）—— 人形 / 兽形双形态
##
## 与「兽王」的对照：**兽王靠"数量"管理一支军队，兽化者靠"形态"管理自己的节奏**。
##
## ## 形态切换由**一张 0 费牌**驱动，不是自动的
## "每回合首次免费切换"看起来更顺，但它**没有决策**——
## 玩家只会永远停在收益更高的那一形态。
## 做成卡牌后：
##   · 切换要花一张牌位 → 玩家得自己决定带几张
##   · 切换卡可能卡手 → "什么时候切"变成真实的取舍
class BeastShaper extends AbstractPower:
	enum Form { HUMAN, BEAST }

	## 人形：每回合多抽牌
	const HUMAN_EXTRA_DRAW: int = 1
	## 兽形：攻击伤害倍率
	const BEAST_DAMAGE_MULT: float = 1.5
	## 兽形：回合开始获得的格挡
	const BEAST_BLOCK: int = 5
	## 兽形：回合开始获得的荆棘
	const BEAST_THORNS: int = 3

	var form: Form = Form.HUMAN

	func _init() -> void:
		id = &"beast_shaper"
		display_name = "兽化者"
		description = "人形：每回合多抽 %d。兽形：攻击 ×%.1f、回合开始 %d 格挡 + %d 荆棘。" % [
			HUMAN_EXTRA_DRAW, BEAST_DAMAGE_MULT, BEAST_BLOCK, BEAST_THORNS,
		]
		# ⚠️ **priority 100**：乘法必须晚于力量（加法，priority 0）。
		# 落在加法之前的话，"先乘后加"会把力量的贡献也乘进去。
		priority = 100
		is_identity = true

	func at_battle_start(_owner: Creature) -> void:
		form = Form.HUMAN

	func on_turn_start(owner: Creature) -> void:
		if form == Form.HUMAN:
			if battle != null and battle.deck != null:
				battle.deck.draw(HUMAN_EXTRA_DRAW)
		else:
			owner.gain_block(BEAST_BLOCK)
			owner.apply_power(BasePowers.Thorns.new(BEAST_THORNS))

	func at_damage_give(value: float, _info: DamageInfo) -> float:
		if form == Form.BEAST:
			return value * BEAST_DAMAGE_MULT
		return value

	## 形态切换（由 `SpecialKind.FORM_SHIFT` 的牌触发）
	func on_form_shift(_owner: Creature) -> String:
		form = Form.BEAST if form == Form.HUMAN else Form.HUMAN
		return "切换为「%s」" % ("兽形" if form == Form.BEAST else "人形")

	func form_name() -> String:
		return "兽形" if form == Form.BEAST else "人形"


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
		&"stormcaller":
			return Stormcaller.new()
		&"archsage":
			return Archsage.new()
		&"hexmaster":
			return Hexmaster.new()
		&"necromancer":
			return Necromancer.new()
		&"contractor":
			return Contractor.new()
		&"beast_bond":
			return BeastBond.new()
		&"hunter_mark":
			return HunterMark.new()
		&"marksman":
			return Marksman.new()
		&"windwalker":
			return Windwalker.new()
		&"alpha_howl":
			return AlphaHowl.new()
		&"beast_shaper":
			return BeastShaper.new()
		_:
			push_warning("IdentityPowers: 未知身份能力 id「%s」" % power_id)
			return null
