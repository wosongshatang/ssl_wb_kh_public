class_name ElementSystem
extends RefCounted
## 元素系统 —— **施加元素与元素反应的唯一入口**（阶段 9）
##
## ## 为什么必须"唯一入口"
## 如果每张元素牌各自 `target.apply_power(BasePowers.Burn.new(1))`，
## 那么「燃 + 霜 → 蒸汽」的判定就要写在**每一张**元素牌里。
## 迟早有一张忘了判——而"某张牌不触发反应"**不报错、也极难发现**
## （玩家只会觉得"这张牌好像有点弱"，不会想到是反应没触发）。
##
## 所以纪律是：**任何地方都不得直接 `apply_power(Burn/Frost)`，
## 一律走 [method apply_element]。**
## 门禁 `test_no_direct_element_apply` 从源码层拦这条。
##
## ## 为什么只有一种反应
## 参考文档用 3 种元素 × 3 种反应（燃/霜/雷：蒸汽/超载/超导）。
## 但我们的法师树是 **2 一阶 × 2 终职**，元素侧只有 2 个终职——
## 引入第三种元素会导致**它没有终职去强化**，变成一个孤儿资源。
##
## 所以降到 **2 元素（燃/霜）+ 1 反应（蒸汽）**：
## 核心体验（叠加 → 组合 → 爆发）完整保留，
## 实现与平衡成本降一个量级。后续要加"雷"，从追猎者线切入更自然。
##
## ## 反应表
## | 组合 | 效果 |
## |---|---|
## | 燃 + 霜 = **蒸汽** | 造成「燃层 × 2」伤害（无视格挡），两份元素各消耗一半 |

## 全部元素 id。**新增元素必须同步这里**（`is_element` 依赖它）。
const ELEMENTS: Array[StringName] = [&"burn", &"frost"]

## 蒸汽反应的伤害倍率：燃层 × 2
const STEAM_DAMAGE_PER_BURN: int = 2


static func is_element(id: StringName) -> bool:
	return id in ELEMENTS


## 施加元素。**这是唯一的入口**——不要在别处直接 `apply_power`。
##
## 返回一句给日志用的描述（空串 = 什么都没发生）。
static func apply_element(target: Creature, element: StringName, layers: int) -> String:
	if target == null or not target.is_alive() or layers <= 0:
		return ""
	if not is_element(element):
		push_warning("ElementSystem: 未知元素「%s」" % element)
		return ""

	# 1) ★ 先判反应：目标身上是否已有**另一种**元素
	var other: StringName = _other_element(element)
	if other != &"" and target.has_power(other):
		return _resolve_reaction(target, element, other, layers)

	# 2) 无反应 → 正常叠层
	target.apply_power(_make(element, layers))

	# 3) 霜满层 → 转「冻结」并清空霜
	#    ⚠️ 判定放在这里而不是 `Frost` 自己身上：
	#    "满层转冻结"是**元素之间的规则**，属于这个唯一入口，
	#    不属于单个元素的自省逻辑。
	if element == &"frost":
		var frost: int = target.get_power_amount(&"frost")
		if frost >= BasePowers.Frost.FREEZE_THRESHOLD:
			target.remove_power(&"frost")
			target.apply_power(BasePowers.Frozen.new())
			return "霜满 %d 层 → 冻结" % frost

	return ""


## 当前目标身上的元素（供 UI / 测试查询）
static func elements_on(target: Creature) -> Array[StringName]:
	var out: Array[StringName] = []
	if target == null:
		return out
	for element: StringName in ELEMENTS:
		if target.has_power(element):
			out.append(element)
	return out


# ── 内部 ────────────────────────────────────────────────────

static func _other_element(element: StringName) -> StringName:
	for candidate: StringName in ELEMENTS:
		if candidate != element:
			return candidate
	return &""


static func _make(element: StringName, layers: int) -> AbstractPower:
	match element:
		&"burn":
			return BasePowers.Burn.new(layers)
		&"frost":
			return BasePowers.Frost.new(layers)
		_:
			push_warning("ElementSystem: 未知元素「%s」" % element)
			return null


## 燃 + 霜 = 蒸汽
##
## **两份元素各消耗一半（向下取整）**——这是"反应"与"继续叠层"之间的取舍核心：
## 反应立刻兑现伤害，但会烧掉一半层数；不反应则层数继续涨。
static func _resolve_reaction(
	target: Creature, incoming: StringName, existing: StringName, layers: int
) -> String:
	# 先把新元素叠上，再统一结算（这样"各消耗一半"是对总量而言的）
	target.apply_power(_make(incoming, layers))

	var burn: int = target.get_power_amount(&"burn")
	var frost: int = target.get_power_amount(&"frost")
	if burn <= 0 or frost <= 0:
		return ""

	var damage: int = burn * STEAM_DAMAGE_PER_BURN
	target.take_damage(damage, null, DamageType.POISON)

	var burn_left: int = burn / 2
	var frost_left: int = frost / 2
	_set_layers(target, &"burn", burn_left)
	_set_layers(target, &"frost", frost_left)

	return "蒸汽：燃 %d + 霜 %d → %d 伤害（各消耗一半）" % [burn, frost, damage]


static func _set_layers(target: Creature, element: StringName, layers: int) -> void:
	if layers <= 0:
		target.remove_power(element)
		return
	var power: AbstractPower = target.get_power(element)
	if power != null:
		power.amount = layers
