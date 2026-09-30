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


func _ready() -> void:
	load_all()


## 全量重建索引（数据变更后可手动调用）
func load_all() -> void:
	_cards = _load_dir("cards")
	_relics = _load_dir("relics")
	_jobs = _load_dir("jobs")
	_enemies = _load_dir("enemies")
	_acts = _load_dir("acts")


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


func get_relic(id: StringName) -> Variant:
	return _relics.get(String(id))


func get_job(id: StringName) -> Variant:
	return _jobs.get(String(id))


func get_enemy(id: StringName) -> Variant:
	return _enemies.get(String(id))


func get_act(id: StringName) -> Variant:
	return _acts.get(String(id))


## 供调试 / 内容盘点：各分类已注册数量
func summary() -> Dictionary:
	return {
		"cards": _cards.size(),
		"relics": _relics.size(),
		"jobs": _jobs.size(),
		"enemies": _enemies.size(),
		"acts": _acts.size(),
	}
