class_name DamagePipeline
extends RefCounted
## 伤害修正链 —— **项目心脏 1**（工程书 §3.1）
##
## ⚠️ **顺序固定，写进测试，永不随意改动。改这里等于改全部 12 个终职。**
##
## ## 修正顺序
## ```
## ① 基础值 base
## ② [攻击方] 遗物 at_damage_modify          ← 最先介入，会被后续乘法放大（阶段 5 接入）
## ③ [攻击方] Power.at_damage_give           力量（加法）
## ④ [攻击方] Power.at_damage_give           虚弱（×0.75，priority 99 → 保证在加法之后）
## ⑤ [攻击方] Stance.at_damage_give          姿态（阶段 5 猎人线接入）
## ⑥ [防御方] Power.at_damage_receive        易伤 ×1.5 / 印记 / 奥术
## ⑦ [双方]   Power.at_damage_final          最终修正
## ⑧ floor() 一次 + max(0)                   ← 只在最终结果取整一次
## ⑨ 格挡吸收
## ⑩ [防御方] prevent_hp_loss → 扣血
## ```
##
## ## DamageType 分流（decisions.md D11：集中在本类，不在钩子里重复判断）
## | 类型 | ③~⑦ 修正 | 格挡吸收 |
## |---|---|---|
## | NORMAL | 全走 | ✅ |
## | THORNS | 跳过 | ✅ |
## | HP_LOSS | 跳过 | ❌ 无视格挡 |
## | POISON | 跳过 | ❌ 无视格挡 |


## 计算面板伤害（**不产生任何副作用**，不扣血不扣格挡）
## 拆成 calculate / apply 两步，是为了让第三方在结算前介入。
static func calculate(
	source: Creature,
	target: Creature,
	base_damage: int,
	damage_type: int = DamageType.NORMAL,
	card: CardData = null
) -> DamageInfo:
	var info := DamageInfo.new()
	info.source = source
	info.target = target
	info.damage_type = damage_type
	info.card = card
	info.base = base_damage

	var value: float = float(base_damage)

	# ② 攻击方遗物**最先介入**——因此会被后续的乘法放大。
	#    不想被放大就改用「施加 Power」模式（见 AbstractRelic 的类文档）。
	# ③④⑤ 攻击方 Power（力量 → 虚弱 → 姿态，靠 priority 保证加法先于乘法）
	if DamageType.uses_offensive_modifiers(damage_type) and source != null:
		for relic: AbstractRelic in source.relics:
			value = relic.at_damage_modify(value, info)
		for power: AbstractPower in sorted_powers(source):
			value = power.at_damage_give(value, info)

	# ⑥ 目标受击加成（易伤 / 印记 / 奥术）
	if DamageType.uses_defensive_modifiers(damage_type) and target != null:
		for power: AbstractPower in sorted_powers(target):
			value = power.at_damage_receive(value, info)

	# ⑦ 最终修正
	if DamageType.uses_final_modifiers(damage_type):
		if source != null:
			for power: AbstractPower in sorted_powers(source):
				value = power.at_damage_final(value, info)
		if target != null:
			for power: AbstractPower in sorted_powers(target):
				value = power.at_damage_final(value, info)

	# ⑧ 只在这里取整一次；并保证非负（修正后可能为负）
	info.output = maxi(0, int(floor(value)))
	return info


## 结算：格挡吸收 → 扣血 → 触发被攻击事件
static func apply(info: DamageInfo) -> void:
	var target: Creature = info.target
	if target == null or not target.is_alive():
		return

	var remaining: int = info.output

	# ⑨ 格挡吸收
	if not DamageType.ignores_block(info.damage_type):
		var absorbed: int = mini(target.block, remaining)
		if absorbed > 0:
			target.lose_block(absorbed)
			info.blocked = absorbed
			remaining -= absorbed

	# ⑩ 扣血前最后拦截（缓冲）。放在格挡之后——被格挡吃掉的攻击不该消耗缓冲。
	for power: AbstractPower in sorted_powers(target):
		remaining = power.prevent_hp_loss(remaining, info)

	if remaining > 0:
		target.apply_hp_loss(remaining)
		info.hp_lost = remaining

	# 计数型 Power（缓冲）可能在本轮结算中当场耗尽，立即清理，
	# 否则它要等到下一次回合钩子才消失，UI 会显示一个已经用掉的 buff。
	target.prune_expired_powers()

	# 被攻击事件（荆棘反伤）。目标已死则不触发。
	# 只有 NORMAL 会触发，避免荆棘互相反弹无限递归。
	if info.damage_type == DamageType.NORMAL and target.is_alive():
		for power: AbstractPower in sorted_powers(target):
			power.on_attacked(info)


## 取某单位的全部 Power（**常规 + 身份层**）并按 priority 升序排列。
##
## ⚠️ 身份层**必须合并进来**——身份能力同样要进修正链（工程书 §3.2）。
## 这是「12 个终职挂在同一条链上」的关键：如果漏掉 identity_powers，
## 壁垒、盾猛、神射手等所有终职的能力都会静默失效。
static func sorted_powers(creature: Creature) -> Array[AbstractPower]:
	var list: Array[AbstractPower] = creature.all_powers()
	list.sort_custom(func(a: AbstractPower, b: AbstractPower) -> bool:
		return a.priority < b.priority)
	return list
