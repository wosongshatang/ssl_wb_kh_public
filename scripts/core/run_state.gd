class_name RunState
extends RefCounted
## 单局状态 —— 一局 = 从选角到结局
##
## **它是单局内所有持久状态的唯一权威来源。** 战斗里用的是 Player 这个
## 临时 Creature，打完必须 sync_from_creature() 把血量同步回来——
## 否则会出现「战斗中掉了血、地图上还是满血」这类经典撕裂。

const DEFAULT_MAX_HP: int = 30
const STARTING_GOLD: int = 99
const SAVE_FORMAT_VERSION: int = 1

var character_class: StringName = &""
var current_act: int = 1
var current_node_id: int = -1
var hp: int = DEFAULT_MAX_HP
var max_hp: int = DEFAULT_MAX_HP
var gold: int = STARTING_GOLD
var deck_card_ids: Array[StringName] = []
var relics: Array[StringName] = []
## 药水栏（最多 MAX_POTIONS 个）
var potions: Array[StringName] = []
const MAX_POTIONS: int = 3
## 本局累计游玩秒数
var play_seconds: float = 0.0
var rng_seed: int = 0
## 永久力量加成（神坛献祭的产物）。每场战斗开始时作为开场 Power 施加。
var bonus_strength: int = 0

var is_over: bool = false
var victory: bool = false

## 是否正处于一场**未结算**的战斗中。
##
## 「继续游戏」据此决定回到战斗还是回到地图。
## 没有这个字段的话，读档时当前节点已被标记为「已访问」，
## 玩家会**直接跳过战斗**落到地图的下一个节点——这正是用户报的 bug。
var in_battle: bool = false

## 待结算的战斗奖励。**随存档持久化**——
## 否则在结算界面退出游戏，奖励就凭空消失了。
var pending_reward: Dictionary = {}

## 牌组用**带后缀的 id** 记录升级状态：`strike` 未升级，`strike+` 已升级。
##
## 为什么不用「id + 独立升级列表」：那样两份数据要同步，
## 一旦错位就会出现「明明升级了却打出未升级的牌」——而且极难查。
## 后缀编码让"这张牌是什么"永远是**一个值**。
const UPGRADE_SUFFIX: String = "+"


func start_new_run(character: StringName, seed_value: int) -> void:
	character_class = character
	rng_seed = seed_value
	current_act = 1
	current_node_id = -1
	max_hp = DEFAULT_MAX_HP
	hp = max_hp
	gold = STARTING_GOLD
	deck_card_ids = _starting_deck_for(character)
	relics = _starting_relics_for(character)
	potions.clear()
	play_seconds = 0.0
	is_over = false
	victory = false
	in_battle = false
	pending_reward = {}
	bonus_strength = 0


## 阶段 4 只有战士；猎人 / 法师的初始牌组在阶段 5 接入
func _starting_deck_for(_character: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for _i: int in 5:
		ids.append(&"strike")
	for _i: int in 5:
		ids.append(&"defend")
	return ids


## 初始遗物（设计文档 §9.5）
func _starting_relics_for(character: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	if character == &"warrior":
		ids.append(&"burning_blood")
	return ids


# ── 牌组 ────────────────────────────────────────────────────

func add_card(card_id: StringName, upgraded: bool = false) -> void:
	deck_card_ids.append(encode_card_id(card_id, upgraded))


static func encode_card_id(card_id: StringName, upgraded: bool) -> StringName:
	if not upgraded:
		return card_id
	return StringName(String(card_id) + UPGRADE_SUFFIX)


static func decode_card_id(entry: StringName) -> StringName:
	var text: String = String(entry)
	if text.ends_with(UPGRADE_SUFFIX):
		return StringName(text.trim_suffix(UPGRADE_SUFFIX))
	return entry


static func is_upgraded_entry(entry: StringName) -> bool:
	return String(entry).ends_with(UPGRADE_SUFFIX)


## 升级牌组里的**第一张**该 id 的未升级牌。返回是否成功。
func upgrade_card(card_id: StringName) -> bool:
	for i: int in deck_card_ids.size():
		var entry: StringName = deck_card_ids[i]
		if is_upgraded_entry(entry) or decode_card_id(entry) != card_id:
			continue
		deck_card_ids[i] = encode_card_id(card_id, true)
		return true
	return false


## 随机升级牌组里的 count 张牌（神化牌的产物）。返回实际升级的 id 列表。
##
## 需要注入 RNG 而不是用全局 randf——否则"同一局同一种子"无法复现，
## 测试也无从断言。
func upgrade_random_cards(count: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var upgraded: Array[StringName] = []

	for _i: int in count:
		var candidates: Array[StringName] = upgradable_card_ids()
		if candidates.is_empty():
			break
		var pick: StringName = candidates[rng.randi_range(0, candidates.size() - 1)]
		if upgrade_card(pick):
			upgraded.append(pick)

	return upgraded


## 可升级的卡 id（去重）。诅咒与已升级的不在内。
func upgradable_card_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var seen: Dictionary = {}

	for entry: StringName in deck_card_ids:
		if is_upgraded_entry(entry):
			continue
		var base_id: StringName = decode_card_id(entry)
		if seen.has(base_id):
			continue
		var loaded: Variant = ContentRegistry.get_card(base_id)
		if loaded is CardData and (loaded as CardData).can_upgrade():
			seen[base_id] = true
			out.append(base_id)

	return out


# ── 药水 ────────────────────────────────────────────────────

## 加一瓶药水。药水栏满了返回 false（调用方据此提示"药水栏已满"）。
func add_potion(potion_id: StringName) -> bool:
	if potions.size() >= MAX_POTIONS:
		return false
	potions.append(potion_id)
	return true


func consume_potion(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= potions.size():
		return &""
	return potions[slot_index]


func remove_potion_at(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < potions.size():
		potions.remove_at(slot_index)


func is_potion_bar_full() -> bool:
	return potions.size() >= MAX_POTIONS


## 从牌组移除**第一张**该 id 的牌。
## 无色卡与金卡删不掉（[method CardData.can_remove]）——它们是刻进灵魂的东西。
func remove_card(card_id: StringName) -> bool:
	var loaded: Variant = ContentRegistry.get_card(card_id)
	if loaded is CardData and not (loaded as CardData).can_remove():
		push_warning("RunState.remove_card: 「%s」不可删除" % card_id)
		return false

	for i: int in deck_card_ids.size():
		if decode_card_id(deck_card_ids[i]) == card_id:
			deck_card_ids.remove_at(i)
			return true
	return false


## 展开成实际的 CardData 列表（从 ContentRegistry 查表）。
## 查不到的 id 会被跳过并告警——不要让一个手滑的 id 静默变成空牌。
##
## ⚠️ **每张牌都 duplicate() 一份**，不能直接返回注册表里的共享实例。
## 理由：`ContentRegistry` 里的卡是全局单例，一副牌组里 5 张「打击」如果共用
## 同一个对象，那么「升级某一张牌」「神化某一张牌」会连带改掉全部 5 张——
## 而且跨局都会受影响（注册表在整个进程里只加载一次）。
## 阶段 3 的卡都是只读的，暂时看不出问题；阶段 6 的卡牌升级一上就爆。
func build_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	for entry: StringName in deck_card_ids:
		var base_id: StringName = decode_card_id(entry)
		var source: Variant = ContentRegistry.get_card(base_id)
		if not (source is CardData):
			push_warning("RunState.build_deck: 找不到卡牌 %s，已跳过" % base_id)
			continue

		var card: CardData = (source as CardData).duplicate() as CardData
		if is_upgraded_entry(entry):
			card = card.create_upgraded()
		deck.append(card)
	return deck


# ── 资源 ────────────────────────────────────────────────────

func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp <= 0:
		is_over = true
		victory = false


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)


func is_alive() -> bool:
	return hp > 0 and not is_over


## 战斗结束后把血量同步回单局状态
func sync_from_creature(creature: Creature) -> void:
	hp = creature.hp
	max_hp = creature.max_hp
	if hp <= 0:
		is_over = true
		victory = false


func finish(victory_achieved: bool) -> void:
	is_over = true
	victory = victory_achieved


# ── 存档序列化 ──────────────────────────────────────────────

func to_dict() -> Dictionary:
	var deck: Array[String] = []
	for id: StringName in deck_card_ids:
		deck.append(String(id))

	var relic_ids: Array[String] = []
	for id: StringName in relics:
		relic_ids.append(String(id))

	var potion_ids: Array[String] = []
	for id: StringName in potions:
		potion_ids.append(String(id))

	return {
		"version": SAVE_FORMAT_VERSION,
		"character_class": String(character_class),
		"current_act": current_act,
		"current_node_id": current_node_id,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"deck": deck,
		"relics": relic_ids,
		"potions": potion_ids,
		"play_seconds": play_seconds,
		"rng_seed": rng_seed,
		"is_over": is_over,
		"victory": victory,
		"in_battle": in_battle,
		"bonus_strength": bonus_strength,
		"pending_reward": pending_reward,
	}


func from_dict(data: Dictionary) -> void:
	character_class = StringName(str(data.get("character_class", "")))
	current_act = int(data.get("current_act", 1))
	current_node_id = int(data.get("current_node_id", -1))
	hp = int(data.get("hp", DEFAULT_MAX_HP))
	max_hp = int(data.get("max_hp", DEFAULT_MAX_HP))
	gold = int(data.get("gold", STARTING_GOLD))
	rng_seed = int(data.get("rng_seed", 0))
	is_over = bool(data.get("is_over", false))
	victory = bool(data.get("victory", false))
	in_battle = bool(data.get("in_battle", false))
	bonus_strength = int(data.get("bonus_strength", 0))
	pending_reward = data.get("pending_reward", {}) as Dictionary

	deck_card_ids.clear()
	for raw: Variant in (data.get("deck", []) as Array):
		deck_card_ids.append(StringName(str(raw)))

	relics.clear()
	for raw: Variant in (data.get("relics", []) as Array):
		relics.append(StringName(str(raw)))

	potions.clear()
	for raw: Variant in (data.get("potions", []) as Array):
		potions.append(StringName(str(raw)))

	play_seconds = float(data.get("play_seconds", 0.0))
