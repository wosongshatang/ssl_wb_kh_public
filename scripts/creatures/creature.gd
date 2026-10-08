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
## Power 的**层数**变化（既不是新增也不是移除）。
## 幕环境「喝彩清零」这类按层数削减需要它——只发 added/removed 的话，
## 层数从 3 变成 1 时 UI 不会刷新。
signal power_changed(power: AbstractPower)
## 遗物触发了（UI 据此显示提示——遗物效果必须**看得见**）
signal relic_triggered(relic: AbstractRelic, detail: String)
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
## 遗物（**整局持续**，不进 reset_for_battle——战斗结束不该把遗物清掉）
var relics: Array[AbstractRelic] = []
## 敌对单位（由 BattleManager 在开战时注入）。
## 需要「对当前敌人造成伤害」的能力靠它拿目标——例如盾猛的反伤。
## 放在 Creature 上而不是让 Power 去引用 BattleManager，是为了避免 Power 层
## 依赖战斗编排层（那样 Power 就没法单独测试了）。
var opponents: Array[Creature] = []


## 按层数削减某个 Power。
##
## 与 [method remove_power] 的区别：那个会**整个拿掉**，
## 幕环境的「喝彩清零」只需要扣掉自己加的那几层——
## 用 remove_power 会把别的来源（遗物、药水、卡牌）给的力量一起清掉。
func reduce_power(power_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var power: AbstractPower = get_power(power_id)
	if power == null:
		return

	power.amount -= amount
	if power.amount <= 0:
		power.amount = 0
		remove_power(power_id)
	else:
		power_changed.emit(power)


## 设置敌对单位（BattleManager 在开战时调用）
func set_opponents(units: Array[Creature]) -> void:
	opponents = units


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
func apply_identity_power(power: AbstractPower, scale: float = 1.0) -> AbstractPower:
	if power == null:
		return null

	var existing: AbstractPower = get_power(power.id)
	if existing != null:
		push_warning("apply_identity_power: %s 已存在，忽略重复注入" % power.id)
		return existing

	# 神级镜像：同一个能力，更强的层数（P6-06）。
	# 用倍率而不是另写一套能力类——加新终职时不用再写一份镜像能力。
	if scale != 1.0 and power.amount > 0:
		power.amount = maxi(1, int(round(float(power.amount) * scale)))

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


# ══ 遗物 ════════════════════════════════════════════════════

## 添加遗物。遗物**整局持续**，不参与 reset_for_battle。
func add_relic(relic: AbstractRelic) -> void:
	if relic == null:
		return
	if has_relic(relic.id):
		push_warning("Creature.add_relic: %s 已存在，忽略重复添加" % relic.id)
		return
	relic.owner_creature = self
	relics.append(relic)


## 清空遗物。**仅供「整局初始化」使用**（从 RunState 重新注入）。
func clear_relics() -> void:
	relics.clear()


func has_relic(relic_id: StringName) -> bool:
	for relic: AbstractRelic in relics:
		if relic.id == relic_id:
			return true
	return false


## 清除所有**负面状态**（忘川水）。返回清掉的条数。
##
## 只搜 `powers`——**碰不到身份层**。这是身份层隔离规则的自然延伸：
## 一瓶药水不该能拿走「刻进灵魂」的东西。
func clear_negative_powers() -> int:
	var removed: int = 0
	for i: int in range(powers.size() - 1, -1, -1):
		var power: AbstractPower = powers[i]
		if not power.is_debuff:
			continue
		powers.remove_at(i)
		power_removed.emit(power)
		removed += 1
	return removed


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
	for relic: AbstractRelic in relics:
		final_amount = relic.at_block_gain(final_amount, card)
	final_amount = maxi(0, final_amount)

	if final_amount <= 0:
		return 0

	block += final_amount
	block_changed.emit(block)
	block_gained.emit(final_amount)
	# 分发「获得格挡」钩子（盾猛挂这里）。
	# 携带的是**修正后**的量——盾猛按「实际获得多少格挡」反伤。
	for power: AbstractPower in all_powers():
		power.on_block_gained(self, final_amount)
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
	for relic: AbstractRelic in relics:
		clearing = relic.at_block_clear(clearing, self)
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
	# 分发「失去生命」钩子（狂战的怒气挂这里）。
	# 放在 health_lost 之后：先让监听信号的 UI 拿到正确血量，再跑可能改状态的钩子。
	for power: AbstractPower in all_powers():
		power.on_health_lost(self, amount)
	for relic: AbstractRelic in relics:
		relic.on_damage_taken(self, amount)
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


## 直接把生命设为指定值（跨场景同步单局血量用）。
## ⚠️ 走这里而不是直接写 `hp = x`，是为了保证 health_changed **一定**被发出——
## 否则 UI 会显示一个过期的血量，而且不会有任何报错。
func set_hp(value: int) -> void:
	hp = clampi(value, 0, max_hp)
	is_dead = hp <= 0
	health_changed.emit(hp, max_hp)


## 预估「获得 N 点格挡」实际会拿到多少。
##
## 走与 [method gain_block] 相同的修正钩子，但调的是 **preview 版本**（无副作用）。
## 盾卫的「本回合第一张格挡 +3」带状态，直接调 `modify_block` 会把加成消耗掉——
## 结果就是 UI 一刷新卡面，玩家的加成莫名其妙没了。
func preview_block(amount: int, card: CardData = null) -> int:
	var value: int = amount
	for power: AbstractPower in all_powers():
		value = power.preview_block(value, card)
	for relic: AbstractRelic in relics:
		value = relic.preview_block(value, card)
	return maxi(0, value)


## 给所有遗物注入战斗上下文（需要操作牌堆/能量的遗物用）。
## 由场景在 `notify_battle_start()` **之前**调用。
func bind_relics_to_battle(battle: BattleManager) -> void:
	for relic: AbstractRelic in relics:
		relic.battle = battle


## 给所有 Power（含身份层）注入战斗上下文（阶段 9）。
##
## 与遗物同一套模式。**只有需要操作牌堆 / 能量的 Power 才该用它**——
## 大多数 Power 只碰 `owner_creature` 的数值，那样才能脱离 BattleManager
## 单独测试（`power.on_turn_start(creature)` 一行就能构造场景）。
##
## 目前的使用者：咒术师（消耗时抽牌）。
func bind_powers_to_battle(battle: BattleManager) -> void:
	for power: AbstractPower in all_powers():
		power.battle = battle


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
	for relic: AbstractRelic in relics:
		relic.on_turn_start(self)
	_prune_expired(powers)


## 回合结束：分发钩子并清理到期常规 Power。
## ⚠️ **刻意不处理 identity_powers**——身份能力不参与倒计时（工程书 §3.2）。
func on_turn_end() -> void:
	for power: AbstractPower in all_powers():
		power.on_turn_end(self)
	for relic: AbstractRelic in relics:
		relic.on_turn_end(self)
	_prune_expired(powers)


## 通知「打出了一张牌」（阶段 4~6 的职业引擎大量依赖此钩子）
func notify_card_played(card: CardData) -> void:
	for power: AbstractPower in all_powers():
		power.on_card_played(self, card)
	for relic: AbstractRelic in relics:
		relic.on_use_card(self, card)


## 通知「一张牌被消耗」（阶段 9）。
##
## ⚠️ **所有进消耗区的路径都必须调它**——直接 `deck.add_to_exhaust()` 会绕过，
## 表现成"死灵师的魂能不涨"，而且**不报错**。
## `BattleManager._exhaust_card()` 是唯一入口。
func notify_card_exhausted(card: CardData) -> void:
	for power: AbstractPower in all_powers():
		power.on_card_exhausted(self, card)


## 通知「战斗开始」（遗物在这里做开场布置）
func notify_battle_start() -> void:
	for relic: AbstractRelic in relics:
		relic.at_battle_start(self)


## 通知「战斗结束」（燃烧之血在这里回血）
func notify_battle_end(won: bool) -> void:
	for relic: AbstractRelic in relics:
		relic.on_battle_end(self, won)


## 通知「击杀了某目标」（嗜血者的击杀回血挂这里）
func notify_kill(target: Creature) -> void:
	for power: AbstractPower in all_powers():
		power.on_kill(self, target)
	for relic: AbstractRelic in relics:
		relic.on_kill(self, target)


## 遗物通知"我触发了"。视图据此显示飘字 / 日志。
func notify_relic_triggered(relic: AbstractRelic, detail: String) -> void:
	relic_triggered.emit(relic, detail)


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

