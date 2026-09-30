class_name IntentResolver
extends RefCounted
## 意图解析器：按 [EnemyData].intents 的序列**循环**给出「下一手要做什么」
##
## 拆成独立类而不是塞进 Enemy，是为了让「意图推进规则」成为可测试的纯逻辑。
## 阶段 4 的 Boss 双姿态、阶段 6 的万兽之祖三形态，都只需要换掉推进规则，
## 不需要改 Enemy 本身。

var _pattern: Array[IntentData] = []
var _cursor: int = 0


func setup(data: EnemyData) -> void:
	_pattern.clear()
	if data != null:
		_pattern.append_array(data.intents)
	_cursor = 0


## 直接用一串意图重设序列（Boss 切形态时调用）
func setup_from_intents(intents: Array[IntentData]) -> void:
	_pattern.clear()
	_pattern.append_array(intents)
	_cursor = 0


func reset() -> void:
	_cursor = 0


## 当前展示给玩家的意图（**不推进游标**）。UI 每帧读它。
func current() -> IntentData:
	if _pattern.is_empty():
		return null
	return _pattern[_cursor % _pattern.size()]


## 取当前意图并推进游标。敌人执行行动时调用。
func advance() -> IntentData:
	var intent: IntentData = current()
	if intent != null:
		_cursor = (_cursor + 1) % _pattern.size()
	return intent


## 跳到序列中的指定下标（Boss 切形态时用）
func seek(index: int) -> void:
	if _pattern.is_empty():
		_cursor = 0
		return
	_cursor = posmod(index, _pattern.size())


func pattern_size() -> int:
	return _pattern.size()


func cursor() -> int:
	return _cursor
