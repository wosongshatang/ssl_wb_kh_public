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

## 形态切换信号。参数是**形态下标**（0 起）与该形态的数据。
## UI 据此播特效 / 改颜色，战斗日志据此写一行提示。
signal phase_changed(phase_index: int, phase: EnemyPhase)

var _phase: int = 0


## 用配置数据装配敌人（这是**唯一推荐**的创建方式）
func setup_from_data(enemy_data: EnemyData) -> void:
	data = enemy_data
	display_name = enemy_data.display_name
	max_hp = enemy_data.max_hp
	_phase = 0
	_apply_phase_intents(_phase, true)
	reset_for_battle()


func phase() -> int:
	return _phase


## 形态总数（没有配形态时算 1）
func phase_count() -> int:
	if data == null or not data.has_phases():
		return 1
	return data.phase_count()


## 当前形态的数据（没配形态时返回 null）
func current_phase_data() -> EnemyPhase:
	if data == null or not data.has_phases():
		return null
	if _phase < 0 or _phase >= data.phases.size():
		return null
	return data.phases[_phase]


## 当前形态名（没配时返回空串，UI 据此决定要不要显示）
func phase_display_name() -> String:
	var phase_data := current_phase_data()
	return phase_data.display_name if phase_data != null else ""


## 检查是否该进入下一个形态。BattleManager 在敌人行动**前**调用——
## 这样血量刚掉下去的当回合就能变招，玩家能立刻感受到"它变了"。
##
## ## ⚠️ 一次爆发跨过多个形态时，**中间形态的能力照样要补上**
## 如果直接跳到最后一个形态，玩家一轮把 Boss 从满血打到残血，
## 就会**跳过**「代行者」「真身」的能力与提示——
## 于是"爆发秒杀"变成严格更优解，四阶段设计等于不存在。
## 神被快速打下去也应该积累它的力量，只是你没看见过程。
##
## 返回是否发生了切换。
func refresh_phase() -> bool:
	if data == null or not data.has_phases() or max_hp <= 0:
		return false

	var target: int = data.phase_index_for(float(hp) / float(max_hp))
	if target <= _phase:
		return false

	# 逐个补上被跨过的形态（含目标形态）
	for i: int in range(_phase + 1, target + 1):
		_apply_phase_powers(i)
		_phase = i
		phase_changed.emit(i, data.phases[i])

	_apply_phase_intents(target, false)
	return true


## 切换意图序列。`force` 用于开场（此时没有"上一阶段"可沿用）。
func _apply_phase_intents(index: int, force: bool) -> void:
	if data == null or not data.has_phases():
		if force:
			intent_resolver.setup(data)
		return

	var phase_data: EnemyPhase = data.phases[index]
	if phase_data.intents.is_empty():
		# 没配意图就沿用上一阶段的——**不要清空**，那会让敌人站着不动
		if force:
			intent_resolver.setup(data)
		return
	intent_resolver.setup_from_intents(phase_data.intents)


## 进入形态时追加的 Power 与身份能力。
## **只叠加、不剥夺**——已经获得的能力不会因为变形态而消失。
func _apply_phase_powers(index: int) -> void:
	if data == null or not data.has_phases():
		return
	var phase_data: EnemyPhase = data.phases[index]
	_apply_power_dict(phase_data.starting_powers)

	for power_id: StringName in phase_data.identity_power_ids:
		var identity := IdentityPowers.create(power_id)
		if identity != null:
			apply_identity_power(identity)


## 应用开场 Power 与身份能力。
##
## ⚠️ 必须在 `reset_for_battle()` **之后**调用——reset 会清空 `powers`。
## 这是「顺序依赖」而不是「谁忘了写」：reset 的语义就是"回到初始状态"。
func apply_starting_powers() -> void:
	if data == null:
		return

	_apply_power_dict(data.starting_powers)

	for power_id: StringName in data.identity_power_ids:
		var identity := IdentityPowers.create(power_id)
		if identity != null:
			apply_identity_power(identity)

	# 第一形态自带的开场效果（如神战 P1 的「化身」）
	if data.has_phases():
		_apply_phase_powers(0)


func _apply_power_dict(source: Dictionary) -> void:
	for raw_id: Variant in source:
		var power_id := StringName(str(raw_id))
		var power := PowerFactory.create(power_id, int(source[raw_id]))
		if power != null:
			apply_power(power)


## 展示给玩家的当前意图（**不推进**）。UI 每帧读它。
func current_intent() -> IntentData:
	return intent_resolver.current()


## 取当前意图并推进游标。敌人执行行动时由 BattleManager 调用。
func advance_intent() -> IntentData:
	return intent_resolver.advance()
