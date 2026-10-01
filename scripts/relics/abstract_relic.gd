class_name AbstractRelic
extends RefCounted
## 遗物基类 —— 掉在人间的权柄碎片（设计文档 §1.3）
##
## ## 职责分离（`card-game-numerical-framework` 的核心原则）
## **遗物管触发，Power 管数值。**
## 推荐模式：遗物负责计数与触发，通过 `apply_power` 施加临时 Power，由 Power 做数值修正。
## 直接改数值（[method at_damage_modify]）只用于「无条件、无状态」的简单效果。
##
## ## 为什么不做成 Power
## 遗物的生命周期是**整局**，Power 是**单场战斗**。
## 混在一起会让「战斗结束清 Power」顺手把遗物也清掉。
##
## ## 三层分类（设计文档 §9.4）
## - `COMMON` 普通遗物：人的造物 / 自然奇物
## - `DIVINE` 神格遗物：强力但 **+神性**，跨神格通用，只能通过「窃权事件」获得
## - `JOB` 职业专属遗物：只在对应转职路线出现

var id: StringName = &""
var display_name: String = ""
var description: String = ""
## 触发时机的一句话说明（UI 用——玩家最想知道的是"它什么时候生效"）
var trigger_text: String = ""
var category: int = 0
## 持有者，由 Creature.add_relic 注入
var owner_creature: Creature = null

## 战斗上下文（由 BattleManager 在开战时注入）。
##
## ⚠️ **只有需要操作牌堆 / 能量的遗物才该用它。**
## 大多数遗物只该碰 `owner_creature` 的数值——那样才能脱离 BattleManager
## 单独测试（`relic.on_turn_start(creature)` 一行就能构造场景）。
var battle: BattleManager = null


func at_battle_start(_owner: Creature) -> void:
	pass


func on_battle_end(_owner: Creature, _won: bool) -> void:
	pass


func on_turn_start(_owner: Creature) -> void:
	pass


func on_turn_end(_owner: Creature) -> void:
	pass


func on_use_card(_owner: Creature, _card: CardData) -> void:
	pass


## 持有者击杀了一个敌人（死神冠冕 / 嗜血者的獠牙挂这里）
func on_kill(_owner: Creature, _target: Creature) -> void:
	pass


## 持有者实际失去生命后（红骷髅这类"低血触发"的遗物挂这里）
func on_damage_taken(_owner: Creature, _amount: int) -> void:
	pass


## 修正链第 ② 步：**最先介入**，因此会被后续的力量/虚弱/易伤放大。
## 想让效果不被放大，就改用「施加 Power」模式。
func at_damage_modify(value: float, _info: DamageInfo) -> float:
	return value


## 修正「获得格挡」的量。**不得有任何副作用。**
func at_block_gain(amount: int, _card: CardData) -> int:
	return amount


## 预估格挡修正。默认转发到 [method at_block_gain]——
## 只有**带状态的**遗物（如「每回合第一张格挡 +2」）才需要重写，
## 否则 UI 一刷新卡面就把加成消耗掉了。
func preview_block(amount: int, card: CardData) -> int:
	return at_block_gain(amount, card)


## 修正「本该清零的格挡」。与壁垒身份能力共用同一个钩子，
## 所以「再保留 25%」自然是乘法叠加，而不是另起一套逻辑。
func at_block_clear(clearing: int, _owner: Creature) -> int:
	return clearing


## 通知"我触发了"——让玩家**看得见**遗物在工作。
##
## 为什么重要：遗物效果如果完全静默，玩家永远不知道它有没有生效，
## 也就无从判断该不该围绕它构筑。**看不到效果等于没有效果。**
func announce(detail: String) -> void:
	if owner_creature != null:
		owner_creature.notify_relic_triggered(self, detail)


func _to_string() -> String:
	return "[遗物]%s" % display_name
