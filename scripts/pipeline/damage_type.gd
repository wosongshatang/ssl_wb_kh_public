class_name DamageType
extends RefCounted
## 伤害类型 —— 决定修正链的哪些环节生效（工程书 §3.1）
##
## ⚠️ **分流规则集中在 DamagePipeline，不要在 Power 钩子里重复判断类型。**
## 理由（decisions.md D11）：分流规则是可测试的、只应存在一份；
## 分散到每个钩子里必然漏掉某一个。
##
## 用法：`DamageType.NORMAL`（无名枚举，值直接挂在类上）

enum {
	NORMAL,    ## 普通攻击：吃全部修正，格挡可吸收
	THORNS,    ## 荆棘反伤：跳过攻击方加成与受击加成，格挡可吸收
	HP_LOSS,   ## 生命流失：跳过几乎所有修正，且**无视格挡**（嗜血者 / 契约师）
	POISON,    ## 中毒：跳过攻击方加成，**无视格挡**，每回合结算
}


## 该类型是否无视格挡（毒与生命流失是壁垒的天敌）
static func ignores_block(damage_type: int) -> bool:
	return damage_type == HP_LOSS or damage_type == POISON


## 该类型是否走「攻击方加成」环节（力量 / 虚弱 / 姿态）
static func uses_offensive_modifiers(damage_type: int) -> bool:
	return damage_type == NORMAL


## 该类型是否走「目标受击加成」环节（易伤 / 印记 / 奥术）
static func uses_defensive_modifiers(damage_type: int) -> bool:
	return damage_type == NORMAL


## 该类型是否走「最终修正」环节
static func uses_final_modifiers(damage_type: int) -> bool:
	return damage_type == NORMAL


static func to_string_name(damage_type: int) -> StringName:
	match damage_type:
		NORMAL:
			return &"NORMAL"
		THORNS:
			return &"THORNS"
		HP_LOSS:
			return &"HP_LOSS"
		POISON:
			return &"POISON"
		_:
			return &"UNKNOWN"
