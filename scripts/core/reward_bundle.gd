class_name RewardBundle
extends RefCounted
## 战斗结算奖励包
##
## ## 为什么拆成「该给什么」与「拿走了什么」
## 前者由战斗决定（数据），后者由玩家操作决定（状态）。
## 点「前进」时**一次性**把已选择的部分写回 [RunState]。
##
## 如果做成"点一下就改 RunState"：玩家还没点前进就崩溃/退出，
## 会留下**半成品存档**（拿了金币但没拿牌）。一次性提交让结算成为原子操作（D24）。
##
## 顺带的好处：`commit()` 是纯函数式的，可以脱离场景直接测试。

var gold: int = 0
var potion_id: StringName = &""
var card_offer_ids: Array[StringName] = []
var relic_id: StringName = &""

## 玩家已选择的部分
var taken_gold: bool = false
var taken_potion: bool = false
var chosen_card_id: StringName = &""
var taken_relic: bool = false


static func from_dict(data: Dictionary) -> RewardBundle:
	var bundle := RewardBundle.new()
	bundle.gold = int(data.get("gold", 0))
	bundle.potion_id = StringName(str(data.get("potion_id", "")))
	bundle.relic_id = StringName(str(data.get("relic_id", "")))
	for raw: Variant in (data.get("card_offer_ids", []) as Array):
		bundle.card_offer_ids.append(StringName(str(raw)))
	return bundle


func to_dict() -> Dictionary:
	var offers: Array[String] = []
	for card_id: StringName in card_offer_ids:
		offers.append(String(card_id))
	return {
		"gold": gold,
		"potion_id": String(potion_id),
		"relic_id": String(relic_id),
		"card_offer_ids": offers,
	}


func has_anything() -> bool:
	return gold > 0 or potion_id != &"" or not card_offer_ids.is_empty() or relic_id != &""


## 是否所有奖励都已被领取（UI 据此把「前进」高亮或提示还有东西没拿）
func all_taken() -> bool:
	if gold > 0 and not taken_gold:
		return false
	if potion_id != &"" and not taken_potion:
		return false
	if relic_id != &"" and not taken_relic:
		return false
	if not card_offer_ids.is_empty() and chosen_card_id == &"":
		return false
	return true


## 把已选择的部分写回 RunState。返回人类可读的摘要（日志与测试断言都用它）。
func commit(run: RunState) -> String:
	if run == null:
		return ""

	var parts: PackedStringArray = PackedStringArray()

	if taken_gold and gold != 0:
		run.add_gold(gold)
		parts.append("金币 +%d" % gold)

	if taken_potion and potion_id != &"":
		if run.add_potion(potion_id):
			parts.append("药水「%s」" % potion_name(potion_id))
		else:
			parts.append("药水栏已满，%s 被丢弃" % potion_name(potion_id))

	if chosen_card_id != &"":
		run.add_card(chosen_card_id)
		parts.append("卡牌「%s」" % card_name(chosen_card_id))

	if taken_relic and relic_id != &"":
		# 走 grant_relic 而不是 relics.append：一次性效果（如永久最大生命）
		# 必须在这里结算，且要能拦住重复授予
		if run.grant_relic(relic_id):
			parts.append("遗物「%s」" % relic_name(relic_id))
		else:
			parts.append("遗物「%s」已拥有" % relic_name(relic_id))

	if parts.is_empty():
		return "什么也没拿"
	return "、".join(parts)


# ── 名字查询（找不到时回退成 id，不要显示空白）────────────────

static func potion_name(potion_id: StringName) -> String:
	var loaded: Variant = ContentRegistry.get_potion(potion_id)
	if loaded is PotionData:
		return (loaded as PotionData).display_name
	return String(potion_id)


static func card_name(card_id: StringName) -> String:
	var loaded: Variant = ContentRegistry.get_card(card_id)
	if loaded is CardData:
		return (loaded as CardData).display_name
	return String(card_id)


static func relic_name(relic_id: StringName) -> String:
	var loaded: Variant = ContentRegistry.get_relic(relic_id)
	if loaded is RelicData:
		return (loaded as RelicData).display_name
	return String(relic_id)
