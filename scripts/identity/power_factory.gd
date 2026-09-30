class_name PowerFactory
extends RefCounted
## Power 工厂：把 `power_id` 字符串翻译成实际的 [AbstractPower] 实例
##
## 存在的意义：让卡牌数据（`.tres`）能**只写 id 不写代码**——
## `apply_to_self = {"strength": 2}` 比在数据里塞一个脚本路径好维护得多，
## 也让设计师能直接改数值。
##
## 新增 Power 时，只需在 [method create] 里加一行 match 分支。


## 未知 id 返回 null 并告警（而不是静默返回一个空 Power——
## 那会让「这张牌看起来生效了但什么都没发生」这种 bug 极难查）
static func create(id: StringName, amount: int) -> AbstractPower:
	match id:
		&"strength":
			return BasePowers.Strength.new(amount)
		&"dexterity":
			return BasePowers.Dexterity.new(amount)
		&"weak":
			return BasePowers.Weak.new(amount)
		&"vulnerable":
			return BasePowers.Vulnerable.new(amount)
		&"poison":
			return BasePowers.Poison.new(amount)
		&"thorns":
			return BasePowers.Thorns.new(amount)
		&"buffer":
			return BasePowers.Buffer.new(amount)
		_:
			push_warning("PowerFactory: 未知 Power id「%s」" % id)
			return null


static func is_known(id: StringName) -> bool:
	return id in [
		&"strength", &"dexterity", &"weak", &"vulnerable",
		&"poison", &"thorns", &"buffer",
	]
