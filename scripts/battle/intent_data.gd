class_name IntentData
extends Resource
## 敌人意图数据（数据驱动，工程书 §11 阶段 2）
##
## 设计要点：**「显示给玩家的意图」与「敌人实际执行的行为」是同一份数据**。
## 这样不可能出现 UI 显示 7 点、实际打 9 点这类撕裂——
## 而那正是玩家最不能容忍的一类 bug。

enum IntentType {
	ATTACK,   ## 攻击
	DEFEND,   ## 防御（获得格挡）
	BUFF,     ## 自身增益
	DEBUFF,   ## 给玩家上减益
	SUMMON,   ## 召唤
	UNKNOWN,  ## 意图不可见（阶段 4+ 的精英/Boss 用）
}

@export var type: IntentType = IntentType.ATTACK
@export var value: int = 0
## 段数。多段攻击要按段单独结算——每段都会独立触发格挡与荆棘。
@export var times: int = 1
## 图标标识。阶段 2 无美术资源，UI 层先用文字符号渲染
@export var icon_key: StringName = &""
## BUFF / DEBUFF 意图要施加的 Power id（如 &"poison" / &"weak"）
@export var power_id: StringName = &""
@export var description: String = ""


static func make_attack(value: int, times: int = 1) -> IntentData:
	var intent := IntentData.new()
	intent.type = IntentType.ATTACK
	intent.value = value
	intent.times = times
	intent.icon_key = &"attack"
	return intent


static func make_defend(value: int) -> IntentData:
	var intent := IntentData.new()
	intent.type = IntentType.DEFEND
	intent.value = value
	intent.icon_key = &"defend"
	return intent


## 本意图的总伤害（非攻击意图返回 0）。供 UI 预览与测试使用。
func total_damage() -> int:
	if type != IntentType.ATTACK:
		return 0
	return value * times


func display_text() -> String:
	match type:
		IntentType.ATTACK:
			if times <= 1:
				return "攻击 %d" % value
			return "攻击 %d×%d" % [value, times]
		IntentType.DEFEND:
			return "防御 %d" % value
		IntentType.BUFF:
			return "强化 %d" % value
		IntentType.DEBUFF:
			return "弱化 %d" % value
		IntentType.SUMMON:
			return "召唤"
		_:
			return "未知"


## 意图配色（UI 用）。**颜色必须与危险程度对应**——
## 玩家扫一眼颜色就该知道这一下要不要防。
func color() -> Color:
	match type:
		IntentType.ATTACK:
			return Color(0.92, 0.42, 0.36)
		IntentType.DEFEND:
			return Color(0.45, 0.66, 0.9)
		IntentType.BUFF:
			return Color(0.55, 0.82, 0.5)
		IntentType.DEBUFF:
			return Color(0.75, 0.5, 0.9)
		_:
			return Color(0.7, 0.7, 0.7)


## 意图图标（无美术资源，用符号占位）
func icon_text() -> String:
	match type:
		IntentType.ATTACK:
			return "⚔"
		IntentType.DEFEND:
			return "◈"
		IntentType.BUFF:
			return "▲"
		IntentType.DEBUFF:
			return "▼"
		_:
			return "·"
