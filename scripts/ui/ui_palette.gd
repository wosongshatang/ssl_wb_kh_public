class_name UiPalette
extends RefCounted
## 全局配色常量 —— 所有 UI 从这里取色，不要在各处硬编码
##
## 阶段 5 的界面改造引入了大量新控件（卡面 / 立绘 / HUD / 地图节点），
## 如果每处各写一遍颜色，很快就会花掉。集中在一处，改一次全局生效。

const BG_DEEP := Color(0.055, 0.05, 0.075)
const BG_PANEL := Color(0.11, 0.115, 0.145)
const BG_PANEL_LIGHT := Color(0.17, 0.18, 0.23)
const BG_SLOT := Color(0.09, 0.09, 0.12)

const BORDER := Color(0.36, 0.33, 0.24)
const BORDER_DIM := Color(0.24, 0.23, 0.2)

const GOLD := Color(0.902, 0.831, 0.6)
const TEXT := Color(0.86, 0.87, 0.91)
const TEXT_DIM := Color(0.58, 0.6, 0.66)

const HP_RED := Color(0.78, 0.24, 0.24)
const HP_GREEN := Color(0.32, 0.62, 0.34)
const BLOCK_BLUE := Color(0.42, 0.62, 0.85)
const ENERGY_ORB := Color(0.82, 0.32, 0.24)
const COIN := Color(0.9, 0.74, 0.3)
const POTION := Color(0.45, 0.75, 0.7)

const TINT_ATTACK := Color(0.52, 0.24, 0.22)
const TINT_SKILL := Color(0.22, 0.34, 0.48)
const TINT_POWER := Color(0.36, 0.28, 0.48)

## 卡牌稀有度配色（用户指定：灰—白—绿—蓝—紫—金 / 无色 / 黑）
## 下标 = CardData.Rarity
const RARITY_COLORS: Array[Color] = [
	Color(0.52, 0.53, 0.57),   # 0 STARTER 灰 —— 初始卡牌
	Color(0.88, 0.89, 0.92),   # 1 COMMON  白
	Color(0.42, 0.78, 0.48),   # 2 UNCOMMON 绿
	Color(0.36, 0.6, 0.94),    # 3 RARE    蓝
	Color(0.72, 0.46, 0.92),   # 4 EPIC    紫
	Color(0.96, 0.78, 0.3),    # 5 GOLD    金（转职专属）
	Color(0.88, 0.93, 0.98),   # 6 COLORLESS 无色（神明赠与）
	Color(0.32, 0.2, 0.24),    # 7 CURSE   黑（诅咒）
]

## 地图节点配色
const NODE_COMBAT := Color(0.7, 0.42, 0.36)
const NODE_ELITE := Color(0.78, 0.32, 0.3)
const NODE_REST := Color(0.55, 0.72, 0.5)
const NODE_SHOP := Color(0.82, 0.7, 0.35)
const NODE_EVENT := Color(0.55, 0.6, 0.75)
const NODE_BOSS := Color(0.85, 0.3, 0.35)
const NODE_DONE := Color(0.32, 0.33, 0.36)


static func tint_for_card_type(card_type: int) -> Color:
	match card_type:
		CardData.CardType.ATTACK:
			return TINT_ATTACK
		CardData.CardType.SKILL:
			return TINT_SKILL
		_:
			return TINT_POWER


static func color_for_rarity(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


## 稀有度越高，边框越粗——"越贵越好看"最省事的做法
static func rarity_border_width(rarity: int) -> int:
	if rarity >= CardData.Rarity.GOLD:
		return 3
	if rarity >= CardData.Rarity.RARE:
		return 2
	return 1


## 稀有度是否"高到值得发光"（金色 / 无色）
static func rarity_is_premium(rarity: int) -> bool:
	return rarity == CardData.Rarity.GOLD or rarity == CardData.Rarity.COLORLESS


static func color_for_node_kind(kind: int) -> Color:
	match kind:
		MapNode.Kind.COMBAT:
			return NODE_COMBAT
		MapNode.Kind.ELITE:
			return NODE_ELITE
		MapNode.Kind.REST:
			return NODE_REST
		MapNode.Kind.SHOP:
			return NODE_SHOP
		MapNode.Kind.EVENT:
			return NODE_EVENT
		MapNode.Kind.BOSS:
			return NODE_BOSS
		_:
			return NODE_DONE


## 血量条颜色：低于 30% 变红
static func hp_color(current: int, maximum: int) -> Color:
	if maximum <= 0:
		return HP_RED
	return HP_GREEN if float(current) / float(maximum) > 0.3 else HP_RED
