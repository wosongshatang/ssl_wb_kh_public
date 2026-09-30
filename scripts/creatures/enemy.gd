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

## 形态切换信号（1 → 2）。UI 可据此播个特效 / 改个颜色。
signal phase_changed(new_phase: int)

var _phase: int = 1


## 用配置数据装配敌人（这是**唯一推荐**的创建方式）
func setup_from_data(enemy_data: EnemyData) -> void:
	data = enemy_data
	display_name = enemy_data.display_name
	max_hp = enemy_data.max_hp
	intent_resolver.setup(enemy_data)
	_phase = 1
	reset_for_battle()


func phase() -> int:
	return _phase


## 检查是否应切换到第二形态（Boss 双姿态）。
## BattleManager 在敌人行动**前**调用——这样血量刚掉下去的当回合就能变招，
## 玩家能立刻感受到"它变了"，而不是多等一回合。
func refresh_phase() -> bool:
	if data == null or _phase >= 2 or not data.has_second_phase():
		return false
	if max_hp <= 0:
		return false
	if float(hp) / float(max_hp) > data.phase2_hp_ratio:
		return false

	_phase = 2
	intent_resolver.setup_from_intents(data.phase2_intents)
	phase_changed.emit(_phase)
	return true


## 应用开场 Power 与身份能力。
##
## ⚠️ 必须在 `reset_for_battle()` **之后**调用——reset 会清空 `powers`。
## 这是「顺序依赖」而不是「谁忘了写」：reset 的语义就是"回到初始状态"。
func apply_starting_powers() -> void:
	if data == null:
		return

	for raw_id: Variant in data.starting_powers:
		var power_id := StringName(str(raw_id))
		var power := PowerFactory.create(power_id, int(data.starting_powers[raw_id]))
		if power != null:
			apply_power(power)

	for power_id: StringName in data.identity_power_ids:
		var identity := IdentityPowers.create(power_id)
		if identity != null:
			apply_identity_power(identity)


## 展示给玩家的当前意图（**不推进**）。UI 每帧读它。
func current_intent() -> IntentData:
	return intent_resolver.current()


## 取当前意图并推进游标。敌人执行行动时由 BattleManager 调用。
func advance_intent() -> IntentData:
	return intent_resolver.advance()
