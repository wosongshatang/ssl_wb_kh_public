class_name ActModifier
extends Resource
## 幕环境机制（阶段 3 只留接口，阶段 6 填充）
##
## 每张地图一个环境机制：竞技场的「观众喝彩」、战场的「军势 / 阵型」、
## 古战场的「不灭 / 执念」、翠林猎场的「埋伏 / 逃窜」……
##
## 它们改变的是**规则**而不是数值（设计文档 §2.3 的设计判据），
## 所以走独立资源 + 钩子，**不要**把 if 分支塞进 BattleManager。

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""


## 战斗开始时应用环境效果
func apply_battle_start(_battle: Node, _player: Creature, _enemies: Array) -> void:
	pass


## 玩家打出一张牌时（例：竞技场「连续打出同类型牌积累喝彩」）
func on_card_played(_player: Creature, _card: CardData) -> void:
	pass


## 敌人死亡时（例：古战场「执念需二次处理」）
func on_enemy_killed(_player: Creature, _enemy: Creature) -> void:
	pass


## 回合开始时（例：元素裂隙「魔力潮汐轮替」）
func on_turn_start(_player: Creature, _turn_number: int) -> void:
	pass
