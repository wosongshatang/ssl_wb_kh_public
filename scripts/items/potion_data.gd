class_name PotionData
extends Resource
## 药水数据
##
## ## 一次性资源
## 用掉即从药水栏消失（`RunState.remove_potion_at`）。所以**没有"次数"字段**——
## 药水的全部价值就在于「用在哪一刻」。
##
## ## 使用方式由 targeting 决定
## - `ENEMY`（**默认**，战斗式）：只能对敌人用，仅战斗中使用
## - `SELF`（通用式）：对自己用，战斗与地图都能用
##
## ## 为什么 battle_only 要独立于 targeting
## 抽牌药水是 `SELF` 目标，但**只能战斗中**用——地图上抽牌毫无意义。
## 靠 targeting 推导不出来，必须能单独标注。

enum Effect {
	DAMAGE,              ## 直伤类：对目标造成固定伤害
	DRAW_CARDS,          ## 得牌类：从抽牌堆抽 N 张
	ADD_CARD_FROM_POOL,  ## 得牌类：从总牌库随机展示 N 张，选一张加入手牌（战斗结束自动消失）
	STRENGTH,            ## 增益类：力量
	BLOCK,               ## 增益类：格挡
	HEAL_PERCENT,        ## 增益类：回复最大生命的 N%
	HEAL_FLAT,           ## 增益类：回复固定生命
	ENERGY,              ## 增益类：能量
	CLEANSE,             ## 特殊：清除自身所有负面状态（只清 powers，碰不到身份层）
	APPLY_POWER,         ## 特殊：施加 power_id x value（正负皆可）
}

enum Targeting {
	ENEMY,  ## 战斗式（默认）：仅战斗，需指定敌人
	SELF,   ## 通用式：战斗与地图均可，对自己生效
}

@export var id: StringName = &""
@export var display_name: String = "药水"
@export var description: String = ""
@export var effect: Effect = Effect.DAMAGE
## 数值含义随 effect 变化（伤害量 / 抽牌数 / 力量层数 / 百分比……）
@export var value: int = 0
## 使用方式。**默认战斗式**。
@export var targeting: Targeting = Targeting.ENEMY
## 是否只能战斗中使用的补充开关（默认 true = 默认战斗式）
@export var battle_only: bool = true
## 0 普通 / 1 罕见 / 2 稀有（影响掉落与商店定价）
@export_range(0, 2, 1) var rarity: int = 0

## APPLY_POWER 专用：要施加的 Power id
@export var power_id: StringName = &""


## 是否需要玩家指定敌人（决定是「拖到敌人身上」还是「双击即用」）
func needs_enemy_target() -> bool:
	return targeting == Targeting.ENEMY


func targeting_text() -> String:
	if needs_enemy_target():
		return "战斗中对敌人使用"
	if battle_only:
		return "战斗中对自己使用"
	return "战斗中或地图上对自己使用"


## 效果的分类名（UI 分组 / 掉落权重用）
func category_text() -> String:
	match effect:
		Effect.DAMAGE:
			return "直伤"
		Effect.DRAW_CARDS, Effect.ADD_CARD_FROM_POOL:
			return "得牌"
		_:
			return "增益"
