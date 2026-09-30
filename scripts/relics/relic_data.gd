class_name RelicData
extends Resource
## 遗物配置数据（三层分类见设计文档 §9.4）
##
## ⚠️ 本资源只描述**展示与分类**；遗物的实际效果在 [RelicFactory] 里。
## 为什么不把效果也塞进数据：遗物效果需要钩子与状态，用 Resource 表达会退化成
## 一个自己实现的脚本解释器——比直接写代码更难维护。

enum Category {
	COMMON,   ## 普通遗物：人的造物 / 自然奇物，常规被动
	DIVINE,   ## 神格遗物：强力但 +神性。跨神格全通用、不削弱，但只能通过「窃权事件」获得
	JOB,      ## 职业专属遗物：只在对应转职路线出现
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
@export var category: Category = Category.COMMON
## 拾取时增加的神性（0 表示不增加）。神格遗物一般 8~15。
@export_range(0, 30, 1) var divinity_cost: int = 0


func is_divine() -> bool:
	return category == Category.DIVINE
