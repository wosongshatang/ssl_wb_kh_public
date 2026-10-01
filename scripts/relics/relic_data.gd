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
## 触发时机的一句话说明（UI 用——玩家最想知道的是"它什么时候生效"）
@export var trigger_text: String = ""
@export var category: Category = Category.COMMON
## 拾取时增加的神性（0 表示不增加）。神格遗物一般 8~15。
@export_range(0, 30, 1) var divinity_cost: int = 0
## 掉落权重档位：0 普通 / 1 罕见 / 2 稀有。与卡牌稀有度同一套思路。
@export_range(0, 2, 1) var rarity: int = 0
## 神格遗物所属神明（用于「窃权事件」筛选；空表示跨神格通用）
@export var deity_id: StringName = &""


func is_divine() -> bool:
	return category == Category.DIVINE


func is_job_specific() -> bool:
	return category == Category.JOB


## 分类显示名（UI 用）
func category_text() -> String:
	match category:
		Category.DIVINE:
			return "神格"
		Category.JOB:
			return "职业"
		_:
			return "普通"
