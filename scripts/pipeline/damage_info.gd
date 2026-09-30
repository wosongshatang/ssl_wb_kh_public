class_name DamageInfo
extends RefCounted
## 一次伤害结算的完整记录
##
## 由 [DamagePipeline] 计算填充，贯穿修正链，也是 UI 展示与日志的数据源。
## 拆成「计算」与「结算」两步，是为了让第三方在结算前介入
## （例：盾猛需要知道本次格挡量，再决定反伤多少）。

## 伤害来源；可为 null（例如中毒的自然结算没有攻击者）
var source: Creature = null
## 伤害承受方
var target: Creature = null
## 见 [DamageType]
var damage_type: int = DamageType.NORMAL
## 触发本次伤害的卡牌；可为 null（非卡牌来源）
var card: CardData = null

## 修正前的原始值
var base: int = 0
## 修正后的面板伤害（已 floor 且非负）
var output: int = 0
## 被格挡吸收的量
var blocked: int = 0
## 实际扣掉的生命的量
var hp_lost: int = 0


## 面板伤害是否与原始值不同（UI 变色用：绿=增强 / 红=削弱 / 白=无变化）
func is_modified() -> bool:
	return output != base


func _to_string() -> String:
	return "DamageInfo(%s %d -> %d, 格挡 %d, 掉血 %d)" % [
		DamageType.to_string_name(damage_type), base, output, blocked, hp_lost,
	]
