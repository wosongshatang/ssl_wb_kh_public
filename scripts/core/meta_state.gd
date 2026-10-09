extends Node
## 元进度（阶段 7 · P7-04 / P7-05）—— **跨局持久化**
##
## ## 与 GameState / RunState 的分工
## | 层 | 生命周期 | 装什么 |
## |---|---|---|
## | `RunState` | **一局** | 血量 / 金币 / 牌组 / 遗物 / 幕 |
## | `GameState` | **一局** | 转职路径 / 神性人性 / 结局判定 |
## | `MetaState` | **永久** | 结局计数 / 解锁 / 成就 |
##
## 混在一起会出现"开新局把成就清了"这种事——**分层是为了让清除边界明确**。

const SAVE_PATH: String = "user://meta.json"

## 解锁一件东西时发出（UI 可以弹提示）
signal unlocked(kind: String, id: StringName)

var ending_counts: Dictionary = {}
var unlocked_cards: Array[StringName] = []
var unlocked_relics: Array[StringName] = []

## 进阶解锁进度：角色 id → **已解锁的最高进阶等级**（0 = 只有进阶 0）
##
## ⚠️ 存的是"最高已解锁"而不是"已通关过的等级集合"：
## 进阶是**线性累积**的，通关进阶 N 必然意味着 1..N-1 都通关过。
## 存集合会多出一堆冗余状态，且迟早和真实进度对不上。
var ascension_unlocked: Dictionary = {}

## ★ 调试开关：打开后**所有角色的全部进阶**立刻可选。
##
## 为什么要有它：验证进阶 10 的"无法探知敌人意图"必须**先通关 9 级**，
## 正常流程下这是几十小时的事。没有开关的话，高进阶效果在开发期
## 等于**永远不会被跑到**——所有 bug 都会留到玩家手里才出现。
##
## ⚠️ 它**不进存档**（[method to_dict] 里没写它）：调试开关一旦被存下来，
## 下次启动就是"我以为我在玩普通模式，其实全解锁了"，而且**不会报错**。
var unlock_all_ascension: bool = false


func _ready() -> void:
	load_meta()


# ══ 结局计数（P7-04）════════════════════════════════════════

func record_ending(ending: StringName) -> void:
	if ending == &"":
		return
	ending_counts[String(ending)] = int(ending_counts.get(String(ending), 0)) + 1
	save_meta()


func ending_count(ending: StringName) -> int:
	return int(ending_counts.get(String(ending), 0))


func total_runs_finished() -> int:
	var total: int = 0
	for key: Variant in ending_counts:
		total += int(ending_counts[key])
	return total


## 是否三种结局都达成过——这是元进度的"通关"标志
func has_seen_all_endings() -> bool:
	for ending: StringName in [&"godslayer", &"ascension", &"mortal"]:
		if ending_count(ending) <= 0:
			return false
	return true


# ══ 成就（P7-04）—— **由数据推导，不单独维护一份状态** ══════

## 成就定义：id → {名称, 达成条件}
##
## ⚠️ 成就是**从已有状态推导**的，不是另一份要同步的状态。
## 单独存一份"已解锁成就列表"的话，它迟早会和真实进度对不上——
## 而那种不一致极难发现（成就看起来是解锁的，但其实条件没达成）。
const ACHIEVEMENTS: Dictionary = {
	&"first_blood": "初次弑神",
	&"ascend": "登神",
	&"stay_mortal": "保持为人",
	&"all_endings": "三种结局",
}


func is_achievement_unlocked(achievement_id: StringName) -> bool:
	match achievement_id:
		&"first_blood":
			return ending_count(&"godslayer") > 0
		&"ascend":
			return ending_count(&"ascension") > 0
		&"stay_mortal":
			return ending_count(&"mortal") > 0
		&"all_endings":
			return has_seen_all_endings()
		_:
			return false


func unlocked_achievements() -> Array[StringName]:
	var out: Array[StringName] = []
	for key: Variant in ACHIEVEMENTS:
		var achievement_id := StringName(str(key))
		if is_achievement_unlocked(achievement_id):
			out.append(achievement_id)
	return out


# ══ 解锁（P7-05）════════════════════════════════════════════

func is_card_unlocked(card_id: StringName) -> bool:
	return unlocked_cards.has(card_id)


func is_relic_unlocked(relic_id: StringName) -> bool:
	return unlocked_relics.has(relic_id)


func unlock_card(card_id: StringName) -> void:
	if card_id == &"" or unlocked_cards.has(card_id):
		return
	unlocked_cards.append(card_id)
	unlocked.emit("card", card_id)
	save_meta()


func unlock_relic(relic_id: StringName) -> void:
	if relic_id == &"" or unlocked_relics.has(relic_id):
		return
	unlocked_relics.append(relic_id)
	unlocked.emit("relic", relic_id)
	save_meta()


# ══ 进阶解锁（阶段 10）══════════════════════════════════════

## 该角色**当前可选**的最高进阶等级。
##
## 调试开关打开时直接返回上限——所以 UI 与开局逻辑**只需要读这一个函数**，
## 不用在每处再判一次开关（那种"每处都记得判"的写法迟早漏一处）。
func unlocked_ascension_level(character: StringName) -> int:
	if unlock_all_ascension:
		return Ascension.MAX_LEVEL
	return clampi(int(ascension_unlocked.get(String(character), 0)), 0, Ascension.MAX_LEVEL)


## 通关某一进阶后调用：解锁下一级。
##
## 只做"往高解锁"，**不降级**——重打低进阶不该把进度打回去。
func record_ascension_clear(character: StringName, cleared_level: int) -> void:
	if character == &"":
		return
	var next: int = clampi(cleared_level + 1, 0, Ascension.MAX_LEVEL)
	if next <= unlocked_ascension_level(character):
		return
	ascension_unlocked[String(character)] = next
	unlocked.emit("ascension", character)
	save_meta()


## 调试用：一次性开启 / 关闭全部进阶。
##
## 关闭时**回到真实进度**（不是清零）——否则调完忘了关会把玩家的解锁记录抹掉。
func set_unlock_all_ascension(enabled: bool) -> void:
	unlock_all_ascension = enabled


# ══ 存档 ════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	var cards: Array[String] = []
	for card_id: StringName in unlocked_cards:
		cards.append(String(card_id))

	var relics: Array[String] = []
	for relic_id: StringName in unlocked_relics:
		relics.append(String(relic_id))

	return {
		# ⚠️ **必须 duplicate()**：直接返回引用的话，
	# 调用方拿到快照之后一旦 reset()，快照会跟着一起被清空。
	# 这类别名 bug 不会报错，只会让"我刚存的数据呢"变成玄学。
		"ending_counts": ending_counts.duplicate(),
		"unlocked_cards": cards,
		"unlocked_relics": relics,
		# 同样要 duplicate()（理由见上）
		"ascension_unlocked": ascension_unlocked.duplicate(),
		# ⚠️ 故意**不存** `unlock_all_ascension`：调试开关被持久化的话，
		# 下次启动就是"我以为在玩普通模式，其实全解锁了"，且不报错。
	}


func from_dict(data: Dictionary) -> void:
	ending_counts = data.get("ending_counts", {}) as Dictionary
	unlocked_cards.clear()
	unlocked_relics.clear()

	for raw: Variant in (data.get("unlocked_cards", []) as Array):
		unlocked_cards.append(StringName(str(raw)))
	for raw: Variant in (data.get("unlocked_relics", []) as Array):
		unlocked_relics.append(StringName(str(raw)))

	# 老存档没有这个键 → 空字典 → 所有角色只有进阶 0。**这是对的**：
	# 不能"猜"玩家解锁过什么，猜错等于白送难度。
	ascension_unlocked = (data.get("ascension_unlocked", {}) as Dictionary).duplicate()


func save_meta() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		# 元进度存不下来不致命，但**必须让人知道**——
		# 静默丢失会让玩家以为"我明明通关过"
		push_error("MetaState: 无法写入元进度存档 %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(to_dict(), "  "))
	file.close()


func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("MetaState: 元进度存档损坏，已忽略")
		return

	from_dict(parsed as Dictionary)


## 清空元进度（调试 / 玩家主动重置用）
func reset() -> void:
	ending_counts.clear()
	unlocked_cards.clear()
	unlocked_relics.clear()
	ascension_unlocked.clear()
	# 调试开关也一起关掉——"重置"却留着全解锁是最容易让人懵的状态
	unlock_all_ascension = false
	save_meta()
