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
## 转职**固定赠送**的专属金卡（每次转职给两张，用户指定）。
## 与 job_card_ids 的区别：那个是三选一，这个是必得——
## 专属卡代表"这条路的标志性招式"，不该让玩家有机会错过。
@export var signature_card_ids: Array[StringName] = []
## 职业卡池标签（阶段 5 接入奖励权重）
@export var card_pool_tags: Array[StringName] = []

# ══ 神级镜像（阶段 6 · P6-06）═══════════════════════════════
## 该终职对应的「神级镜像」职业 id。神战 P4 时神会**变成你**。
## 留空表示这个职业没有镜像（一阶职业都没有）。
@export var mirror_job_id: StringName = &""

## 这是哪个终职的镜像（留空 = 普通职业，玩家可选）。
## ⚠️ **镜像不是可转职的职业**，它只出现在神战的敌人身上。
@export var mirror_of: StringName = &""

## 镜像的强度倍率：同一个身份能力，层数按此放大。
## 用倍率而不是新写一套能力类——**神用的是你的招式，只是更强**，
## 加一个新终职时不用再写一份镜像能力。
@export_range(1.0, 4.0, 0.5) var power_scale: float = 1.0

## 镜像的额外开场属性：{power_id: 层数}
##
## ⚠️ **光有 `power_scale` 不够**：我们的身份能力大多是**比例型 / 标记型**
## （壁垒保留一半、盾猛按格挡反伤），它们的 `amount` 是 0——
## 乘任何倍率都还是 0。所以镜像必须另外带一点"神才有的东西"，
## 否则「神用你的招式」实际等于「神什么都没用」。
@export var mirror_starting_powers: Dictionary = {}


func is_mirror() -> bool:
	return mirror_of != &""


func is_first_tier() -> bool:
	return tier == 1


func _to_string() -> String:
	return "JobData(%s 第%d阶)" % [display_name, tier]
