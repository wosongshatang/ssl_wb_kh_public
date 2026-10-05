class_name Ally
extends Creature
## 友方单位（猎人线的召唤兽）
##
## ## 与 Enemy 的关系：**故意不做成同一个类**
## 敌人有「意图序列 / 形态 / 掉落」，盟友一样都没有。
## 塞进同一个类会得到一堆"这个字段对盟友无意义"的注解，
## 而每次给敌人加机制都要重新确认"盟友这边会不会被带坏"。
##
## 共用的部分（生命 / 格挡 / Power / 伤害管线）全在 [Creature] 上，不重复。
##
## ## 盟友在战斗里做什么
## - **回合结束时自动攻击**第一个存活敌人（不需要玩家操作）
## - **嘲讽**：带 `is_taunt` 的盟友会替玩家挨打
##
## 嘲讽是盟友存在的意义所在——没有它，盟友就只是"额外的伤害"，
## 而额外伤害完全可以用一张牌解决，不需要一个新实体系统。

var data: AllyData = null

## 嘲讽：敌人优先攻击这个单位（见 `BattleManager._enemy_target`）
var is_taunt: bool = false


func setup_from_data(ally_data: AllyData) -> void:
	data = ally_data
	display_name = ally_data.display_name
	max_hp = ally_data.max_hp
	is_taunt = ally_data.is_taunt
	reset_for_battle()


## 盟友的每回合攻击力
func attack_power() -> int:
	return data.attack if data != null else 0


## 回合结束时自动行动。返回是否真的打到了人。
func act(opponents: Array[Creature]) -> bool:
	for opponent: Creature in opponents:
		if opponent.is_alive():
			opponent.take_damage(attack_power(), self)
			return true
	return false


func _to_string() -> String:
	return "Ally(%s %d/%d)" % [display_name, hp, max_hp]
