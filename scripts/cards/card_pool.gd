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

## 进阶 2：稀有度下移。打开后稀有 / 史诗的抽取权重被削减。
##
## ⚠️ 这里**不读 GameState**：`cards/` 与 `core/` 保持单向依赖，
## 由调用方（战斗场景）按当前进阶等级决定要不要打开。
## 好处是 CardPool 仍能在没有 RunState 的测试里单独构造。
var rarity_shift: bool = false

## 削减系数（1.0 = 不削）。由 [method for_run] 按进阶等级填。
var rarity_weight_multiplier: float = 1.0


func _init(rng: RandomNumberGenerator = null, p_character: StringName = &"",
		p_rarity_shift: bool = false, p_rarity_multiplier: float = 1.0) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	character = p_character
	rarity_shift = p_rarity_shift
	rarity_weight_multiplier = p_rarity_multiplier


## 按当前局的进阶状态构造卡池 —— **奖励类抽取的唯一入口**。
##
## 存在的理由：进阶 2 的"稀有度下移"如果靠每个调用点自己判，
## 迟早有一处忘了判（表现成"某个来源的奖励不受进阶影响"），
## 而且**不报错**。收在一个函数里就没有"忘了"这个可能。
static func for_run(rng: RandomNumberGenerator, run: RunState) -> CardPool:
	if run == null:
		return CardPool.new(rng)
	return CardPool.new(rng, run.character_class,
		run.has_ascension(&"worse_card_rarity"),
		Ascension.rarity_weight_multiplier(run.ascension))


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
##
## 进阶 2 打开时，**稀有度高于白色**的档位权重乘以 `rarity_weight_multiplier`。
## 白色是地板，不再削——否则高进阶会变成"全是灰牌"，那不是变难是变没得选。
##
## ⚠️⚠️ 判"是不是高于白色"必须比**稀有度枚举**，不能比**权重**。
## 白色的权重（50）本来就是全表最高的，拿权重当稀有度比的话
## `15 <= 50` 成立 → 蓝卡会被当成"已在地板上"而**完全不被削**，
## 表现成"进阶 2 开了但奖励一点没变差"，且不报错。（第一版就是这么写的，被测试抓到。）
func weight_of(card: CardData) -> int:
	var base: int = int(REWARD_WEIGHTS.get(card.rarity, 0))
	if not rarity_shift or base <= 0:
		return base
	if card.rarity <= CardData.Rarity.COMMON:
		return base
	# 下界是 **1**：削到 0 会让这一档永远抽不到，等于把内容删了。
	return maxi(1, int(round(float(base) * rarity_weight_multiplier)))


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
