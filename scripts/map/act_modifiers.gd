class_name ActModifiers
extends RefCounted
## 幕环境机制的**运行时实现** + 工厂
##
## 与 [RelicFactory] / [PowerFactory] 同一套模式：
## `.tres` 只写 id 与参数，逻辑按 id 分发到这里。


## 运行时基类。持有机制数据与战斗上下文。
class Runtime extends RefCounted:
	var data: ActModifier = null
	var battle: BattleManager = null

	func setup(modifier: ActModifier, battle_ref: BattleManager) -> void:
		data = modifier
		battle = battle_ref

	func apply_battle_start(_player: Creature, _enemies: Array) -> void:
		pass

	func on_card_played(_player: Creature, _card: CardData) -> void:
		pass

	func on_enemy_killed(_player: Creature, _enemy: Creature) -> void:
		pass

	func on_turn_start(_player: Creature, _turn_number: int) -> void:
		pass

	## 通知玩家"环境生效了"——幕环境如果完全静默，玩家会以为是 bug
	func announce(text: String) -> void:
		if battle != null:
			battle.environment_announced.emit("%s：%s" % [data.display_name, text])


# ══ 竞技场 · 观众喝彩 ════════════════════════════════════════
## **连续打出同类型牌**会积累喝彩（每层 +1 力量，本场永久）；
## 一旦换类型，喝彩清零。
##
## 为什么用"连续"而不是"累计"：累计只会奖励"多打牌"，
## 连续才逼玩家在**卡组纯度**与**临场应变**之间做取舍——
## 这才是竞技场该有的压力。
class CrowdCheer extends Runtime:
	const MAX_STACKS: int = 5

	var _last_type: int = -1
	var _stacks: int = 0

	func on_card_played(player: Creature, card: CardData) -> void:
		if card.type == _last_type:
			if _stacks >= MAX_STACKS:
				return
			_stacks += 1
			player.apply_power(BasePowers.Strength.new(1))
			announce("喝彩 %d 层（+1 力量）" % _stacks)
		else:
			# 换类型：喝彩清零。**只削减自己加的那部分**，
			# 不能调 remove_power —— 那会把别的来源的力量一起清掉
			if _stacks > 0:
				player.reduce_power(&"strength", _stacks)
				announce("换手了，喝彩清零（-%d 力量）" % _stacks)
				_stacks = 0
		_last_type = card.type


# ══ 战场 · 军势 ══════════════════════════════════════════════
## 战斗开始时，**双方**各获得力量。战场让所有人都更强——包括敌人。
class WarMomentum extends Runtime:
	func apply_battle_start(player: Creature, enemies: Array) -> void:
		var amount: int = data.param_int("strength", 2)
		player.apply_power(BasePowers.Strength.new(amount))
		for enemy: Creature in enemies:
			enemy.apply_power(BasePowers.Strength.new(amount))
		announce("双方各 +%d 力量" % amount)


# ══ 古战场 · 执念 ════════════════════════════════════════════
## 每次击杀敌人时，执念反噬——玩家受到**无视格挡**的伤害。
##
## 这让"清场"不再是无条件的收益：面对多敌人时，
## 你需要考虑"一次杀太多会不会把自己耗死"。
class UndyingGrudge extends Runtime:
	func on_enemy_killed(player: Creature, enemy: Creature) -> void:
		var damage: int = data.param_int("damage", 4)
		player.take_damage(damage, null, DamageType.HP_LOSS)
		announce("%s 的执念反噬，失去 %d 点生命" % [enemy.display_name, damage])


static func create(modifier: ActModifier, battle: BattleManager) -> Runtime:
	var runtime: Runtime = null
	match modifier.id:
		&"arena_crowd_cheer":
			runtime = CrowdCheer.new()
		&"battlefield_momentum":
			runtime = WarMomentum.new()
		&"ancient_grudge":
			runtime = UndyingGrudge.new()
		_:
			push_warning("ActModifiers: 未知幕环境机制「%s」" % modifier.id)
			return null

	runtime.setup(modifier, battle)
	return runtime


static func is_known(modifier_id: StringName) -> bool:
	return modifier_id in [
		&"arena_crowd_cheer", &"battlefield_momentum", &"ancient_grudge",
	]
