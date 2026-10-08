class_name AbstractPower
extends RefCounted
## Buff / Debuff 基类 —— 项目心脏 2 的载体
##
## **所有钩子默认返回原值**，子类只 override 自己关心的那个。
## 这是「12 个终职挂在同一条链上」的实现基础。
##
## ## 身份层（不可剥夺）
## `is_identity = true` 的 Power 存放在 `Creature.identity_powers`，与常规 `powers` 隔离：
##   - `remove_power()` 对身份层无效（沉默 / 驱散 / 夺能接触不到）
##   - 回合结束**不倒计时**（`is_turn_based` 恒为 false）
##   - 战斗 `reset_for_battle()` **不清**身份层
## 身份能力的「源头」挂在 `GameState` 的 JobData 上，每场战斗重新实例化注入——
## 任何战斗内效果都接触不到那个源头，所以「不可剥夺」是**物理性**的，不是规则性的。
##
## ## priority
## 同一条钩子上的多个 Power 按 `priority` **升序**执行。
## 关键用例：力量（加法，priority 0）必须**先于**虚弱（乘法，priority 99），
## 否则数值偏差巨大。见 [DamagePipeline]。

## 唯一标识，用于叠加与查找（如 &"strength"）
var id: StringName = &""
var display_name: String = ""
var description: String = ""
## 层数。**语义随 Power 而定**：
##   - 永久型（力量 / 敏捷 / 荆棘）：直接参与计算
##   - 持续型（虚弱 / 易伤 / 中毒）：仅作回合倒计时，乘数固定
##   - 计数型（缓冲）：剩余可抵挡次数
var amount: int = 0
## 同钩子执行顺序，越小越先
var priority: int = 0
## 是否为身份能力（不可剥夺）
var is_identity: bool = false
## 是否随回合递减。**身份能力恒为 false**
var is_turn_based: bool = false

## 负面状态（虚弱 / 易伤 / 中毒 / 兽化…）。
## 忘川水这类「清除负面」的消耗品据此筛选——
## 靠 id 白名单判断的话，新加一个 debuff 就会漏掉。
var is_debuff: bool = false
## 持有者，由 Creature.apply_power 注入
var owner_creature: Creature = null

## 战斗上下文（由 [method Creature.bind_powers_to_battle] 在开战时注入）。
##
## ⚠️ **只有需要操作牌堆 / 能量的 Power 才该用它。**
## 大多数 Power 只该碰 `owner_creature` 的数值——那样才能脱离 BattleManager
## 单独测试（`power.on_turn_start(creature)` 一行就能构造场景）。
##
## 与 [AbstractRelic.battle] 是同一套模式。
var battle: BattleManager = null


# ══ 数值修正钩子（进修正链）══════════════════════════════════

## 攻击方加成：力量（加法，priority 0）/ 虚弱（乘法，priority 99）
func at_damage_give(value: float, _info: DamageInfo) -> float:
	return value


## 目标受击加成：易伤（×1.5）/ 印记 / 奥术
func at_damage_receive(value: float, _info: DamageInfo) -> float:
	return value


## 最终修正（攻击方与防御方各跑一遍）
func at_damage_final(value: float, _info: DamageInfo) -> float:
	return value


## 格挡获取修正：敏捷（+N）
func modify_block(block: int, _card: CardData) -> int:
	return block


## 格挡清零改写（**Q1 定案的落点**）
## 返回**实际清零的量**。默认全清。
## 壁垒返回 `clearing - floor(clearing / 2)`（保留一半，向下取整）。
func at_block_clear(clearing: int, _owner: Creature) -> int:
	return clearing


## 扣血前最后拦截（**在格挡吸收之后**执行）
## 返回拦截后的掉血量。缓冲用它把「下一次掉血」归零。
## 之所以放在格挡之后：缓冲要挡的是「真正会掉的血」，
## 一次被格挡完全吃掉的攻击不该消耗缓冲层数。
func prevent_hp_loss(amount: int, _info: DamageInfo) -> int:
	return amount


# ══ 事件钩子 ════════════════════════════════════════════════

func on_turn_start(_owner: Creature) -> void:
	pass


func on_turn_end(_owner: Creature) -> void:
	pass


func on_card_played(_owner: Creature, _card: CardData) -> void:
	pass


## 持有者被攻击后（无论是否被格挡挡下）。荆棘在这里反伤。
## 注意：仅 NORMAL 类型会触发，避免荆棘互相反弹无限递归。
func on_attacked(_info: DamageInfo) -> void:
	pass


## 持有者实际失去生命后（狂战的怒气挂这里）
func on_health_lost(_owner: Creature, _amount: int) -> void:
	pass


## 持有者实际获得格挡后（盾猛的反伤挂这里）
## 携带的是**修正后**的量（经敏捷等）——盾猛按「实际获得多少」计算反伤。
func on_block_gained(_owner: Creature, _amount: int) -> void:
	pass


## 预估格挡修正。**不得有任何副作用。**
##
## 默认直接转发到 [method modify_block]——只有**带状态的** Power 才需要重写。
## 例：盾卫的「本回合第一张格挡 +3」会翻转内部标志，
## 若预览时直接调 `modify_block`，UI 一刷新就会把加成白白消耗掉。
func preview_block(block: int, card: CardData) -> int:
	return modify_block(block, card)


func on_kill(_owner: Creature, _target: Creature) -> void:
	pass


# ══ 阶段 9 · 机制原语钩子 ═══════════════════════════════════

## 一张牌被**消耗**（进消耗区，本局不回牌堆）时。
##
## 为什么单独开一个钩子而不是复用 `on_card_played`：
## 消耗可能来自"打出后消失"，也可能来自**主动消耗手牌**（咒术师），
## 后者根本没有"打出"这个动作。挂在 `on_card_played` 会漏掉主动消耗。
func on_card_exhausted(_owner: Creature, _card: CardData) -> void:
	pass


## 魂能代付：**最多**能替这张牌付掉多少能量。
##
## ⚠️ **必须是纯查询**——不能在这里扣资源。
## 因为 `play_card` 会先问一遍"够不够付"，
## 够才会真正扣（走 [method consume_energy_subsidy]）。
## 在这里扣的话，一次"能量不足"的失败出牌会白白吃掉魂能。
func energy_subsidy_max(_cost: int, _card: CardData) -> int:
	return 0


## 真正消耗代付资源。**只在确认可支付后调用一次**。
func consume_energy_subsidy(_amount: int) -> void:
	pass


## 是否允许打出这张"本来不可打出"的牌。
##
## 契约师用它把诅咒牌变成可打的核弹——
## 不直接改 `CardData.unplayable` 是因为那是**全局**的，
## 改了会让所有角色的诅咒都变可打。
func allows_playing(_card: CardData) -> bool:
	return false


## 改写一张牌的能量花费（返回实际要付的能量）。
##
## 契约师用它把 0 费的诅咒牌改成"2 费核弹"——
## 诅咒牌本身是 0 费且不可打出的，代价必须由**能力**来定义。
func modify_energy_cost(cost: int, _card: CardData) -> int:
	return cost


## 一张「形态切换」牌被打出时。
##
## 返回**非空字符串** = 本能力响应了它（该字符串会进战斗日志）。
## 做成"返回字符串"而不是无返回值，是为了让"谁响应了"这件事**可观测**：
## 没有兽化者的角色打出这张牌时，日志里必须什么都没有——
## 否则玩家会以为自己切换了形态。
func on_form_shift(_owner: Creature) -> String:
	return ""


# ══ 工具 ════════════════════════════════════════════════════

## 叠加层数（负数为削减）
func stack(delta: int) -> void:
	amount += delta


## 是否应当被移除（仅对递减型生效；身份能力恒不失效）
func is_expired() -> bool:
	return is_turn_based and not is_identity and amount <= 0


func _to_string() -> String:
	var tag: String = "[身份]" if is_identity else ""
	return "%s%s(%d)" % [tag, display_name, amount]
