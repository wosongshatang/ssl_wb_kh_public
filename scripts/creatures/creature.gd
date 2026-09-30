class_name Creature
extends Node
## 战斗单位基类
##
## ## 格挡时序（decisions.md D10 / Q1 定案）
## 格挡在**自身回合开始时**清零（`on_turn_start` → `clear_block`）。
## 这样玩家回合获得的格挡能撑过敌人回合，敌人打完后才失效。
## 清零量可被身份能力改写——壁垒保留「本该被清掉的那一半」。
##
## ## 身份层不可剥夺（工程书 §3.2）
## 身份能力存在独立的 `identity_powers`，与常规 `powers` 严格隔离：
##   - `remove_power()` **只搜 `powers`**，永远碰不到身份层（沉默 / 驱散 / 夺能走这里）
##   - 回合结束**不倒计时**（`_prune_expired` 只处理 `powers`）
##   - `reset_for_battle()` **不清**身份层
## 身份能力的源头挂在 `GameState` 的 JobData 上，每场战斗重新实例化注入——
## 任何战斗内效果都接触不到那个源头，所以「不可剥夺」是**物理性**的。

signal health_changed(current: int, maximum: int)
signal block_changed(current: int)
## 实际获得格挡时触发，携带**修正后**的量（盾猛依赖这一点，阶段 4）
signal block_gained(amount: int)
## 实际失去生命时触发（嗜血者依赖这一点，阶段 4）
signal health_lost(amount: int)
signal power_added(power: AbstractPower)
signal power_removed(power: AbstractPower)
signal died

@export var display_name: String = "单位"
@export var max_hp: int = 10

var hp: int = 0
var block: int = 0
var energy: int = 0
var is_dead: bool = false

## 常规 Buff / Debuff
var powers: Array[AbstractPower] = []
## 身份层（不可剥夺）。**不要直接操作这个数组**，用 apply_identity_power / clear_identity_powers
var identity_powers: Array[AbstractPower] = []


## 战斗开始时调用：重置战斗内状态。
## ⚠️ **刻意不清 identity_powers**——身份能力不可剥夺。
## 战斗初始化流程应显式调用 clear_identity_powers() 后再从 JobData 重新注入。
func reset_for_battle() -> void:
	hp = max_hp
	block = 0
	energy = 0
	is_dead = false
	powers.clear()
	health_changed.emit(hp, max_hp)
	block_changed.emit(block)


## 进场景树即完成初始化，避免 hp 停留在 0 导致 is_alive() 误判为死亡。
## 测试里不挂树，需显式调用 reset_for_battle()。
func _ready() -> void:
	reset_for_battle()


func is_alive() -> bool:
	return not is_dead and hp > 0


# ══ Power 管理 ══════════════════════════════════════════════

## 全部 Power（常规 + 身份层）。修正链与钩子分发都必须走这里。
func all_powers() -> Array[AbstractPower]:
	var out: Array[AbstractPower] = []
	out.append_array(powers)
	out.append_array(identity_powers)
	return out


## 施加常规 Power。同 id 已存在则**叠加层数**而非新增。
func apply_power(power: AbstractPower) -> AbstractPower:
	var existing: AbstractPower = get_power(power.id)
	if existing != null:
		existing.stack(power.amount)
		power_added.emit(existing)
		return existing
	_attach(power, false)
	return power


## 施加身份能力（不可剥夺）。同 id 已存在则忽略重复注入。
func apply_identity_power(power: AbstractPower) -> AbstractPower:
	var existing: AbstractPower = get_power(power.id)
	if existing != null:
		push_warning("apply_identity_power: %s 已存在，忽略重复注入" % power.id)
		return existing
	_attach(power, true)
	return power


func _attach(power: AbstractPower, as_identity: bool) -> void:
	power.owner_creature = self
	power.is_identity = as_identity
	if as_identity:
		power.is_turn_based = false  # 身份能力恒不倒计时
		identity_powers.append(power)
	else:
		powers.append(power)
	power_added.emit(power)


## 移除常规 Power。
## ⚠️ **对身份层无效**——这是「不可剥夺」的架构级保证，不是靠记得写判断。
## 沉默 / 驱散 / 夺能都走这里，所以它们物理上接触不到身份能力。
func remove_power(id: StringName) -> bool:
	for i: int in range(powers.size() - 1, -1, -1):
		if powers[i].id == id:
			var removed: AbstractPower = powers[i]
			powers.remove_at(i)
			power_removed.emit(removed)
			return true
	return false


## 清空身份层。
## ⚠️ **仅供「战斗初始化」流程使用**（每场战斗从 JobData 重新实例化注入）。
## 这不是「剥夺」——它是身份能力**源头重建**的一部分。
func clear_identity_powers() -> void:
	identity_powers.clear()


func get_power(id: StringName) -> AbstractPower:
	for power: AbstractPower in all_powers():
		if power.id == id:
			return power
	return null


func has_power(id: StringName) -> bool:
	return get_power(id) != null


func get_power_amount(id: StringName) -> int:
	var power: AbstractPower = get_power(id)
	return power.amount if power != null else 0


# ══ 格挡 ════════════════════════════════════════════════════

## 获得格挡，返回**实际获得**的量（经敏捷等修正后）。
## `block_gained` 发射的是实际值——盾猛「每当你**实际获得**格挡」依赖这一点。
func gain_block(amount: int, card: CardData = null) -> int:
	if amount <= 0 or not is_alive():
		return 0

	var final_amount: int = amount
	for power: AbstractPower in all_powers():
		final_amount = power.modify_block(final_amount, card)
	final_amount = maxi(0, final_amount)

	if final_amount <= 0:
		return 0

	block += final_amount
	block_changed.emit(block)
	block_gained.emit(final_amount)
	return final_amount


func lose_block(amount: int) -> void:
	if amount <= 0 or block <= 0:
		return
	block = maxi(0, block - amount)
	block_changed.emit(block)


## 格挡清零（自身回合开始时）。
## 清零量可被钩子改写——**壁垒**通过 `at_block_clear` 保留「本该清零值」的一半。
func clear_block() -> void:
	if block <= 0:
		return

	var clearing: int = block
	for power: AbstractPower in all_powers():
		clearing = power.at_block_clear(clearing, self)
	clearing = clampi(clearing, 0, block)

	block -= clearing
	block_changed.emit(block)


# ══ 伤害 / 治疗 ═════════════════════════════════════════════

## 走完整修正链的伤害入口。
## 返回 DamageInfo 便于调用方读取面板值 / 格挡量 / 掉血量（盾猛、UI 展示都用得上）。
func take_damage(
	amount: int,
	source: Creature = null,
	damage_type: int = DamageType.NORMAL,
	card: CardData = null
) -> DamageInfo:
	var info: DamageInfo = DamagePipeline.calculate(source, self, amount, damage_type, card)
	DamagePipeline.apply(info)
	return info


## 直接扣血。**只应由 DamagePipeline.apply 调用**——绕过修正链会让所有终职数值错乱。
func apply_hp_loss(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	hp = maxi(0, hp - amount)
	health_lost.emit(amount)
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		is_dead = true
		died.emit()


func heal(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	var before: int = hp
	hp = mini(max_hp, hp + amount)
	if hp != before:
		health_changed.emit(hp, max_hp)


# ══ 能量 ════════════════════════════════════════════════════

func can_afford(cost: int) -> bool:
	return energy >= cost


func spend_energy(cost: int) -> bool:
	if not can_afford(cost):
		return false
	energy -= cost
	return true


func gain_energy(amount: int) -> void:
	energy = maxi(0, energy + amount)


# ══ 回合钩子 ════════════════════════════════════════════════

## 回合开始：先清格挡（可被改写），再分发 Power 钩子。
## 顺序有意义——若先分发再清格挡，「回合开始获得格挡」的能力会被立刻清掉。
func on_turn_start() -> void:
	clear_block()
	for power: AbstractPower in all_powers():
		power.on_turn_start(self)
	_prune_expired(powers)


## 回合结束：分发钩子并清理到期常规 Power。
## ⚠️ **刻意不处理 identity_powers**——身份能力不参与倒计时（工程书 §3.2）。
func on_turn_end() -> void:
	for power: AbstractPower in all_powers():
		power.on_turn_end(self)
	_prune_expired(powers)


## 通知「打出了一张牌」（阶段 4~6 的职业引擎大量依赖此钩子）
func notify_card_played(card: CardData) -> void:
	for power: AbstractPower in all_powers():
		power.on_card_played(self, card)


## 通知「击杀了某目标」（嗜血者的击杀回血挂这里）
func notify_kill(target: Creature) -> void:
	for power: AbstractPower in all_powers():
		power.on_kill(self, target)


## 清理已到期的常规 Power（依据 is_turn_based + amount <= 0）
func _prune_expired(list: Array[AbstractPower]) -> void:
	var i: int = list.size() - 1
	while i >= 0:
		if list[i].is_expired():
			var removed: AbstractPower = list[i]
			list.remove_at(i)
			power_removed.emit(removed)
		i -= 1


## 清理已到期的**常规** Power。
## 供外部在钩子执行后调用——例如 DamagePipeline 结算完缓冲（计数型，可能当场耗尽）
## 需要立刻清理，否则它要等到下一次回合钩子才消失，UI 会显示一个已经用掉的 buff。
func prune_expired_powers() -> void:
	_prune_expired(powers)

