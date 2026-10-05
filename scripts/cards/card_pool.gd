class_name CardPool
extends RefCounted
## 卡牌奖励池
##
## 阶段 5：按**稀有度权重**抽不重复的 N 张。
## 权重由用户指定：白 50% / 绿 30% / 蓝 15% / 紫 5%。
##
## ⚠️ 卡池是「只读数据 + 注入 RNG」的组合：所有随机都走注入的
## RandomNumberGenerator，否则「同一局同一种子抽出同样的牌」无法保证，
## 测试也无从断言。

const DEFAULT_OFFER_COUNT: int = 3
const SHOP_OFFER_COUNT: int = 5

## 战斗奖励的稀有度权重（用户指定）
const REWARD_WEIGHTS: Dictionary = {
	CardData.Rarity.COMMON: 50,
	CardData.Rarity.UNCOMMON: 30,
	CardData.Rarity.RARE: 15,
	CardData.Rarity.EPIC: 5,
}

## 不出现在战斗奖励里的稀有度：
## 灰是初始牌、金是转职专属、无色只能靠特殊事件、黑是诅咒
const REWARD_EXCLUDED: Array[int] = [
	CardData.Rarity.STARTER,
	CardData.Rarity.GOLD,
	CardData.Rarity.COLORLESS,
	CardData.Rarity.CURSE,
]

var _rng: RandomNumberGenerator
## 只抽这个角色的牌。空串 = 不过滤（调试 / 测试用）。
var character: StringName = &""


func _init(rng: RandomNumberGenerator = null, p_character: StringName = &"") -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	character = p_character


## 某张牌是否属于该角色。
##
## 判据是 `card_pool_tags` 里有没有这个角色的标签。
## **标签为空 = 通用牌**（无色卡、诅咒、特殊牌），任何角色都能拿——
## 靠"没有标签就排除"会让这些牌永远抽不到。
func _belongs_to_character(card: CardData) -> bool:
	if character == &"":
		return true
	if card.card_pool_tags.is_empty():
		return true
	return card.card_pool_tags.has(character)


## 抽 count 张**不重复**的卡
func roll(count: int = DEFAULT_OFFER_COUNT) -> Array[CardData]:
	var out: Array[CardData] = []
	var candidates: Array[CardData] = reward_candidates()

	if candidates.is_empty():
		push_warning("CardPool: 奖励卡池为空——检查 data/cards/ 下是否有白/绿/蓝/紫卡")
		return out

	while out.size() < count and not candidates.is_empty():
		var picked: CardData = _pick_weighted(candidates)
		out.append(picked)
		candidates.erase(picked)

	return out


## 可作为战斗奖励的卡（排除灰 / 金 / 无色 / 诅咒）
func reward_candidates() -> Array[CardData]:
	var out: Array[CardData] = []
	for card: CardData in ContentRegistry.all_cards():
		if REWARD_EXCLUDED.has(card.rarity):
			continue
		# ⚠️ 必须按角色过滤：不过滤的话法师的三选一会给出"打击 / 防御"
		if not _belongs_to_character(card):
			continue
		# 特殊牌（神化/契约/神谕/考题）**不进普通奖励池**——
		# 它们是特定来源的产物，混进常规三选一会让"特殊"两个字失去意义
		if card.is_special():
			continue
		out.append(card)
	return out


func _pick_weighted(candidates: Array[CardData]) -> CardData:
	var total: int = 0
	for card: CardData in candidates:
		total += weight_of(card)

	if total <= 0:
		# 所有权重都是 0（例如卡池里全是没配权重的稀有度）→ 退化成均匀抽取，
		# 而不是返回 null 让调用方拿到一张空牌
		return candidates[_rng.randi_range(0, candidates.size() - 1)]

	var roll_value: int = _rng.randi_range(1, total)
	var cumulative: int = 0
	for card: CardData in candidates:
		cumulative += weight_of(card)
		if roll_value <= cumulative:
			return card

	return candidates[candidates.size() - 1]


## 某张牌的抽取权重（公开：UI 展示掉率、平衡调参都要用）
func weight_of(card: CardData) -> int:
	return int(REWARD_WEIGHTS.get(card.rarity, 0))


## 卡牌价值（商店定价用）。稀有度越高越贵。
static func price_of(card: CardData) -> int:
	match card.rarity:
		CardData.Rarity.COLORLESS:
			return 160
		CardData.Rarity.GOLD:
			return 130
		CardData.Rarity.EPIC:
			return 110
		CardData.Rarity.RARE:
			return 85
		CardData.Rarity.UNCOMMON:
			return 62
		_:
			return 45
