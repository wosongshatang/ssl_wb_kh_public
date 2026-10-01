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
## 持有者，由 Creature.apply_power 注入
var owner_creature: Creature = null


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
