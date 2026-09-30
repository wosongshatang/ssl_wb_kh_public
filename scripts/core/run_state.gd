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
var rng_seed: int = 0
var is_over: bool = false
var victory: bool = false


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
	is_over = false
	victory = false


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

func add_card(card_id: StringName) -> void:
	deck_card_ids.append(card_id)


func remove_card(card_id: StringName) -> bool:
	var idx: int = deck_card_ids.find(card_id)
	if idx < 0:
		return false
	deck_card_ids.remove_at(idx)
	return true


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
	for id: StringName in deck_card_ids:
		var source: Variant = ContentRegistry.get_card(id)
		if source is CardData:
			deck.append((source as CardData).duplicate() as CardData)
		else:
			push_warning("RunState.build_deck: 找不到卡牌 %s，已跳过" % id)
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
		"rng_seed": rng_seed,
		"is_over": is_over,
		"victory": victory,
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

	deck_card_ids.clear()
	for raw: Variant in (data.get("deck", []) as Array):
		deck_card_ids.append(StringName(str(raw)))

	relics.clear()
	for raw: Variant in (data.get("relics", []) as Array):
		relics.append(StringName(str(raw)))
