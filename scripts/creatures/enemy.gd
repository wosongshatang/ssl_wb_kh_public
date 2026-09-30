class_name Enemy
extends Creature
## 敌人单位
##
## 行为由 [EnemyData] + [IntentResolver] 驱动：意图序列配在 `.tres`，
## 本类只负责**把意图翻译成动作的数据部分**，「执行」由 BattleManager 负责。
##
## 这样拆的好处：敌人「想做什么」与「实际做什么」共用同一份数据，
## UI 展示的意图不可能与实际结算不一致。

var data: EnemyData = null
var intent_resolver: IntentResolver = IntentResolver.new()


## 用配置数据装配敌人（这是**唯一推荐**的创建方式）
func setup_from_data(enemy_data: EnemyData) -> void:
	data = enemy_data
	display_name = enemy_data.display_name
	max_hp = enemy_data.max_hp
	intent_resolver.setup(enemy_data)
	reset_for_battle()


## 展示给玩家的当前意图（**不推进**）。UI 每帧读它。
func current_intent() -> IntentData:
	return intent_resolver.current()


## 取当前意图并推进游标。敌人执行行动时由 BattleManager 调用。
func advance_intent() -> IntentData:
	return intent_resolver.advance()
