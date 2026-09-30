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

const RARITY_COMMON := Color(0.62, 0.63, 0.68)
const RARITY_UNCOMMON := Color(0.5, 0.72, 0.52)
const RARITY_RARE := Color(0.85, 0.7, 0.3)

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
	match rarity:
		2:
			return RARITY_RARE
		1:
			return RARITY_UNCOMMON
		_:
			return RARITY_COMMON


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
