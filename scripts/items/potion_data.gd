class_name PotionData
extends Resource
## 药水数据
##
## 药水效果足够简单（一个枚举 + 一个数值），所以不需要工厂——
## 直接由 [method BattleScene._apply_potion_effect] 按枚举结算。
## 若将来出现「施加随机减益」这类复杂效果，再引入 PotionFactory。

enum Effect {
	HEAL,      ## 回复生命（**唯一可以在地图上使用的效果**）
	BLOCK,     ## 获得格挡
	STRENGTH,  ## 获得力量
	ENERGY,    ## 获得能量
	DAMAGE,    ## 对当前敌人造成伤害
}

@export var id: StringName = &""
@export var display_name: String = "药水"
@export var description: String = ""
@export var effect: Effect = Effect.HEAL
@export var value: int = 0
## 是否只能战斗中使用（除 HEAL 外都为 true）
@export var battle_only: bool = true
