class_name PotionResolver
extends RefCounted
## 药水效果结算
##
## ## 为什么单独成类
## 药水要在**两个场景**（地图 / 战斗）里用。效果逻辑写进任何一个场景，
## 另一个就得复制一份——而"复制的那份忘了同步"是最常见的一类玩法 bug。
##
## ## can_use 与 apply 严格分开
## UI 先用 [method can_use] 判断能不能用（并拿到**原因**），再调 [method apply]。
## 这样"点了没反应"永远能变成"点了告诉你为什么不行"——
## 玩家最讨厌的不是不能做，是不知道能不能做。

## 结算结果
##
## `needs_card_choice` 为 true 时，调用方需要弹选牌界面，
## 玩家选完再调 [method grant_card_to_hand]。
class Result extends RefCounted:
	var success: bool = false
	var message: String = ""
	var needs_card_choice: bool = false
	var offered_card_ids: Array[StringName] = []


## 能不能用。返回**空字符串 = 可以用**；否则返回给玩家看的原因。
static func can_use(potion: PotionData, in_battle: bool, has_enemy: bool) -> String:
	if potion == null:
		return "药水数据缺失"
	if potion.battle_only and not in_battle:
		return "只能在战斗中使用"
	if potion.needs_enemy_target() and not has_enemy:
		return "没有可以指定的敌人"
	return ""


## 结算药水效果。**调用方负责扣除药水**（一次性资源）。
static func apply(
	potion: PotionData,
	user: Creature,
	target: Creature,
	deck: DeckManager,
	rng: RandomNumberGenerator
) -> Result:
	var result := Result.new()

	if user == null:
		result.message = "没有可作用的对象"
		return result

	match potion.effect:
		PotionData.Effect.DAMAGE:
			if target == null:
				result.message = "没有可指定的敌人"
				return result
			target.take_damage(potion.value, user, DamageType.NORMAL)
			result.success = true
			result.message = "对 %s 造成 %d 点伤害" % [target.display_name, potion.value]

		PotionData.Effect.DRAW_CARDS:
			if deck == null:
				result.message = "现在抽不了牌"
				return result
			var drawn: Array[CardData] = deck.draw(potion.value)
			result.success = true
			result.message = "抽了 %d 张牌" % drawn.size()

		PotionData.Effect.ADD_CARD_FROM_POOL:
			# 只是"抽出来给玩家看"，真正入手在 grant_card_to_hand
			var offers: Array[CardData] = CardPool.new(rng).roll(potion.value)
			if offers.is_empty():
				result.message = "卡池为空"
				return result
			for card: CardData in offers:
				result.offered_card_ids.append(card.id)
			result.success = true
			result.needs_card_choice = true
			result.message = "从牌库中选一张加入手牌"

		PotionData.Effect.STRENGTH:
			user.apply_power(BasePowers.Strength.new(potion.value))
			result.success = true
			result.message = "获得 %d 点力量" % potion.value

		PotionData.Effect.BLOCK:
			var gained: int = user.gain_block(potion.value)
			result.success = true
			result.message = "获得 %d 点格挡" % gained

		PotionData.Effect.HEAL_PERCENT:
			var amount: int = int(ceil(float(user.max_hp) * float(potion.value) / 100.0))
			user.heal(amount)
			result.success = true
			result.message = "回复 %d 点生命（最大生命的 %d%%）" % [amount, potion.value]

		PotionData.Effect.HEAL_FLAT:
			user.heal(potion.value)
			result.success = true
			result.message = "回复 %d 点生命" % potion.value

		PotionData.Effect.ENERGY:
			# 能量是玩家独有的资源，敌人没有——所以这里必须窄化类型
			var player := user as Player
			if player == null:
				result.message = "目标没有能量资源"
				return result
			player.gain_energy(potion.value)
			result.success = true
			result.message = "获得 %d 点能量" % potion.value

		PotionData.Effect.CLEANSE:
			var cleared: int = user.clear_negative_powers()
			result.success = true
			result.message = "清除了 %d 个负面状态" % cleared if cleared > 0 else "没有需要清除的状态"

		PotionData.Effect.APPLY_POWER:
			if potion.power_id == &"":
				result.message = "这瓶药水没有配置要施加的状态"
				return result
			var power: AbstractPower = PowerFactory.create(potion.power_id, potion.value)
			if power == null:
				result.message = "未知状态「%s」" % potion.power_id
				return result
			(user if potion.targeting == PotionData.Targeting.SELF else target).apply_power(power)
			result.success = true
			result.message = "获得 %s ×%d" % [power.display_name, power.amount]

		_:
			result.message = "该药水效果尚未实现"

	return result


## 把玩家选中的牌加入手牌。
##
## **临时牌**：战斗结束自然消失——因为每场战斗的牌组都由
## `RunState.build_deck()` 重新构建，临时牌从未进过 `deck_card_ids`。
## 这就是"战斗结束后移除"不需要任何额外清理代码的原因。
static func grant_card_to_hand(card_id: StringName, deck: DeckManager) -> bool:
	if deck == null:
		return false

	var source: Variant = ContentRegistry.get_card(card_id)
	if not (source is CardData):
		push_warning("PotionResolver: 找不到卡牌 %s" % card_id)
		return false

	deck.hand.append((source as CardData).duplicate() as CardData)
	return true
