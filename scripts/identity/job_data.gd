class_name JobData
extends Resource
## 职业数据（转职树的节点）
##
## 转职不是「学会技能」，而是**把一条世界规则刻进自身的存在方式**（设计文档 §2.1）。
## 所以 `identity_power_ids` 指向的能力必须满足「规则级」判据（§2.3）：
## 改写一条基础规则 / 接通两条原本无关的资源管线 / 反转一类负面事物的价值。
## **纯数值加成（"+3 力量"）不允许作为转职能力**——那是卡牌和遗物该干的事。

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""
## 1 = 一阶（第 1 幕 Boss 后二选一）；2 = 二阶终职（第 2 幕 Boss 后二选一）
@export_range(1, 2, 1) var tier: int = 1
## 一阶职业的上级终职指向它；一阶本身为空
@export var parent_job: StringName = &""
## 该职业赋予的**身份能力 id**（不可剥夺）
@export var identity_power_ids: Array[StringName] = []
## 转职附赠的职业牌候选（三选一）——转职**不增加最大生命**（决策 5）
@export var job_card_ids: Array[StringName] = []
## 职业卡池标签（阶段 5 接入奖励权重）
@export var card_pool_tags: Array[StringName] = []


func is_first_tier() -> bool:
	return tier == 1


func _to_string() -> String:
	return "JobData(%s 第%d阶)" % [display_name, tier]
