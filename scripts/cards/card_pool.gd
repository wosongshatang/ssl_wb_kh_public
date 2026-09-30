class_name CardPool
extends RefCounted
## 卡牌奖励池
##
## 阶段 3：从 [ContentRegistry] 里按**稀有度权重**抽不重复的 N 张。
## 阶段 5 起：按职业标签解锁权重（设计文档 §9.2「转职后按职业标签解锁卡池权重」）。
##
## ⚠️ 卡池是「只读数据 + 注入 RNG」的组合：所有随机都走注入的 RandomNumberGenerator，
## 否则「同一局同一种子抽出同样的牌」就无法保证，测试也无从断言。

const DEFAULT_OFFER_COUNT: int = 3
const SHOP_OFFER_COUNT: int = 5

## 稀有度权重（下标 = CardData.rarity）。稀有卡出现率低，但抽到就是构筑核心。
const RARITY_WEIGHTS: Array[int] = [100, 42, 14]

var _rng: RandomNumberGenerator


func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()


## 抽 count 张**不重复**的卡
func roll(count: int = DEFAULT_OFFER_COUNT) -> Array[CardData]:
	var out: Array[CardData] = []
	var candidates: Array[CardData] = ContentRegistry.all_cards()

	if candidates.is_empty():
		push_warning("CardPool: 卡池为空——检查 res://data/cards/ 下是否有 .tres")
		return out

	while out.size() < count and not candidates.is_empty():
		var picked: CardData = _pick_weighted(candidates)
		out.append(picked)
		candidates.erase(picked)

	return out


func _pick_weighted(candidates: Array[CardData]) -> CardData:
	var total: int = 0
	for card: CardData in candidates:
		total += weight_of(card)

	if total <= 0:
		return candidates[0]

	var roll_value: int = _rng.randi_range(1, total)
	var cumulative: int = 0
	for card: CardData in candidates:
		cumulative += weight_of(card)
		if roll_value <= cumulative:
			return card

	return candidates[candidates.size() - 1]


## 某张牌的抽取权重（公开：UI 展示掉率、平衡调参都要用）
func weight_of(card: CardData) -> int:
	var idx: int = clampi(card.rarity, 0, RARITY_WEIGHTS.size() - 1)
	return RARITY_WEIGHTS[idx]


## 卡牌价值（商店定价用）。稀有度越高越贵。
static func price_of(card: CardData) -> int:
	match card.rarity:
		2:
			return 110
		1:
			return 75
		_:
			return 48
