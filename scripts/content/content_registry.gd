extends Node
## ContentRegistry —— 卡牌 / 遗物 / 敌人 / 职业的统一只读查询入口（Autoload）
##
## 纪律（工程书 §2.2）：**禁止放可变状态**。这里只有「查询」。
## 数据来源：res://data/ 下的 .tres（工程书 §3.4 数据外置原则——代码只读不算）。
##
## Phase 0 说明：data/ 各子目录尚为空，本注册表返回空表。
## 阶段 1 引入 CardData 后，_load_dir 会自动按 Resource 的 `id` 字段建索引，
## 无需修改本文件。

const DATA_ROOT: String = "res://data"

var _cards: Dictionary = {}
var _relics: Dictionary = {}
var _jobs: Dictionary = {}
var _enemies: Dictionary = {}
var _acts: Dictionary = {}
var _events: Dictionary = {}
var _potions: Dictionary = {}
var _act_modifiers: Dictionary = {}
var _allies: Dictionary = {}


func _ready() -> void:
	load_all()


## 全量重建索引（数据变更后可手动调用）
func load_all() -> void:
	_cards = _load_dir("cards")
	_relics = _load_dir("relics")
	_jobs = _load_dir("jobs")
	_enemies = _load_dir("enemies")
	_acts = _load_dir("acts")
	_events = _load_dir("events")
	_potions = _load_dir("potions")
	_act_modifiers = _load_dir("act_modifiers")
	_allies = _load_dir("allies")


## 扫描一个数据子目录，按 Resource.id 建索引
func _load_dir(sub: String) -> Dictionary:
	var out: Dictionary = {}
	var dir_path: String = "%s/%s" % [DATA_ROOT, sub]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(dir_path.path_join(file_name))
			if res != null and "id" in res:
				out[String(res.id)] = res
			elif res != null:
				push_warning("ContentRegistry: %s 缺少 id 字段，已跳过" % file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


func get_card(id: StringName) -> Variant:
	return _cards.get(String(id))


## 全部卡牌（奖励池 / 商店抽卡用）。返回的是资源引用，不要修改它们。
func all_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for key: Variant in _cards:
		var card: Variant = _cards[key]
		if card is CardData:
			out.append(card as CardData)
	return out


func all_card_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _cards:
		out.append(StringName(str(key)))
	return out


func all_job_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _jobs:
		out.append(StringName(str(key)))
	return out


func all_relic_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _relics:
		out.append(StringName(str(key)))
	return out


## 某神明的无色卡。`deity_id` 传空则返回全部无色卡。
func divine_cards_for(deity_id: StringName) -> Array[CardData]:
	var out: Array[CardData] = []
	for card: CardData in all_cards():
		if card.rarity != CardData.Rarity.COLORLESS:
			continue
		if deity_id == &"" or card.deity_id == deity_id:
			out.append(card)
	return out


## 全部特殊牌（P6-12）
func special_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for card: CardData in all_cards():
		if card.is_special():
			out.append(card)
	return out


func curse_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for card: CardData in all_cards():
		if card.rarity == CardData.Rarity.CURSE:
			out.append(card)
	return out


func get_relic(id: StringName) -> Variant:
	return _relics.get(String(id))


func get_job(id: StringName) -> Variant:
	return _jobs.get(String(id))


func get_enemy(id: StringName) -> Variant:
	return _enemies.get(String(id))


func get_act(id: StringName) -> Variant:
	return _acts.get(String(id))


func get_event(id: StringName) -> Variant:
	return _events.get(String(id))


func get_potion(id: StringName) -> Variant:
	return _potions.get(String(id))


## 按 id 找立绘（阶段 8）。
##
## **约定优于配置**：`res://assets/portraits/<id>.png` 存在就用它。
## 找不到返回 null —— 调用方回退到几何剪影，**而不是崩**。
##
## 为什么不做成 `.tres` 字段：立绘有 50+ 个，
## 让「丢一张图就生效」比「改 50 个数据文件」重要得多。
func get_portrait(portrait_id: StringName) -> Texture2D:
	if portrait_id == &"":
		return null
	var path: String = "res://assets/portraits/%s.png" % portrait_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 按卡 id 找卡图（阶段 8）。
##
## **约定优于配置**：`res://assets/cards/<卡id>.png` 存在就用它。
## 找不到返回 null —— 调用方回退到几何图形，**而不是崩**。
##
## ⚠️ **卡图与立绘是两套素材，不要混用**：
## 卡图区约 **104×113（接近方形）**，立绘是 **168×128（横向）**。
## 竖版人物立绘塞进方形卡图会只剩一截躯干——**必须单独出图**。
##
## ⚠️ **升级过的卡沿用基础卡的图**：`id` 里带 `+` 后缀（如 `strike+`），
## 但那是同一张牌，没有也不该有第二张图。所以这里**剥掉后缀**再查。
## 否则玩家一升级，卡图就"消失"了——而这类失效**不报任何错**。
func get_card_art(card_id: StringName) -> Texture2D:
	if card_id == &"":
		return null
	var path: String = card_art_path(card_id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## 卡图**路径**推导（与"能不能加载"分开）。
##
## ## 为什么要把路径推导单独拆出来
## `get_card_art()` 在"没图"和"id 写错"两种情况下**都返回 null**——
## 测试分不出"升级牌没剥后缀"和"本来就没图"。
## 拆出路径后，测试可以直接断言 `strike+` 与 `strike` 解析到**同一个路径**，
## **不需要仓库里真的有一张图**。
func card_art_path(card_id: StringName) -> String:
	if card_id == &"":
		return ""
	# 复用 `RunState.decode_card_id()`——`+` 后缀的规则只有一个来源，
	# 不要在这里另写一份 trim 逻辑（两份规则迟早会不一致）。
	var base: StringName = RunState.decode_card_id(card_id)
	return "res://assets/cards/%s.png" % base


func get_ally(id: StringName) -> Variant:
	return _allies.get(String(id))


func get_act_modifier(id: StringName) -> Variant:
	return _act_modifiers.get(String(id))


func all_act_modifier_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _act_modifiers:
		out.append(StringName(str(key)))
	return out


func all_enemy_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _enemies:
		out.append(StringName(str(key)))
	return out


func all_potion_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in _potions:
		out.append(StringName(str(key)))
	return out


## 供调试 / 内容盘点：各分类已注册数量
func summary() -> Dictionary:
	return {
		"cards": _cards.size(),
		"relics": _relics.size(),
		"jobs": _jobs.size(),
		"enemies": _enemies.size(),
		"acts": _acts.size(),
		"events": _events.size(),
		"potions": _potions.size(),
		"act_modifiers": _act_modifiers.size(),
	}
