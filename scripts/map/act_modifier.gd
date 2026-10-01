class_name ActModifier
extends Resource
## 幕环境机制（**纯数据**）—— 阶段 6
##
## 每张地图一个环境机制：竞技场的「观众喝彩」、战场的「军势」、
## 古战场的「执念」……
##
## ## 为什么逻辑不写在这里
## `.tres` 存不下方法体。如果把逻辑写在 Resource 上，就得为每个机制
## 单独写一个脚本 + 一个 `.tres`，数据与代码被拆到两个地方。
## 所以按项目既有模式（`PowerFactory` / `RelicFactory`）：
## **本类只存数据，运行时实现放在 [ActModifiers] 里按 id 分发。**
##
## ## 设计判据（设计文档 §2.3）
## 幕环境改变的是**规则**而不是数值。所以它们是钩子，不是"敌人血量 ×1.2"。

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
## 机制参数。不同机制用不同的键，避免为每个机制往类上加字段。
@export var params: Dictionary = {}


## 取参数（带默认值——缺参数不该让机制崩掉，只该让它用默认行为）
func param_int(key: String, fallback: int = 0) -> int:
	return int(params.get(key, fallback))


func param_float(key: String, fallback: float = 0.0) -> float:
	return float(params.get(key, fallback))


func _to_string() -> String:
	return "ActModifier(%s)" % display_name
