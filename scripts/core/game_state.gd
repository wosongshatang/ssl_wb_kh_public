extends Node
## GameState —— 跨场景全局状态（Autoload）
##
## ## 职责划分（阶段 3 起）
## | 类别 | 存放位置 |
## |---|---|
## | 单局资源（角色 / 幕 / 节点 / 血量 / 金币 / 牌组 / 遗物） | [RunState] |
## | 地图 | [MapManager] |
## | 身份与侵蚀（转职路径 / 身份能力 id / 神性 / 人性） | 本对象 |
##
## ⚠️ **不要把单局资源在本对象上再抄一份。** 早期版本在 GameState 上有过
## 一份 `character_class`，同时 RunState 里也有一份——这种双份状态必然
## 导致「改了这边、读了那边」的 bug，而且极难定位。
##
## ## 身份层契约（工程书 §3.2）
## 本对象是身份能力「不可剥夺」的物理源头。身份能力的权威数据挂在
## [member identity_power_ids]，每场战斗初始化玩家 Creature 时重新实例化注入。
## 任何战斗内效果（沉默 / 驱散 / 夺能）都接触不到本对象，因此天然不可被移除。
##
## 纪律（工程书 §2.2）：**禁止放战斗逻辑**。

signal job_advanced(job_id: StringName)

const DIVINITY_MAX: int = 100
const HUMANITY_MAX: int = 100
## 显化阈值：神性到了这里，规则开始在你身上外显
const DIVINITY_MANIFEST: int = 70
## 登神阈值：到了这里，你已经无法拒绝成为规则，结局锁定
const DIVINITY_ASCENSION: int = 90
## 派生下一幕地图种子用的步长（质数，避免与别处的种子运算撞车）
const ACT_SEED_STRIDE: int = 104729

## 当前单局状态（未开局时为 null）
var run: RunState = null
## 当前地图（未开局时为 null）
var map: MapManager = null

## 转职路径：按顺序记录已刻入灵魂的规则（[0] 一阶 → [1] 二阶终职）
var job_path: Array[StringName] = []
## 本局持有的身份能力 id（身份层权威来源）
var identity_power_ids: Array[StringName] = []

## 神性：侵蚀进度。>= 90 时结局锁定「登神」
var divinity: int = 0
## 人性：凡人结局需 humanity >= 3 且 divinity < 60
var humanity: int = 0


## 开新局：生成单局状态与地图
func start_new_run(character: StringName, seed_value: int) -> void:
	run = RunState.new()
	run.start_new_run(character, seed_value)

	map = MapManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	map.generate(rng, run.current_act)

	job_path.clear()
	identity_power_ids.clear()
	divinity = 0
	humanity = 0

	EventBus.run_started.emit(character)


## 用已还原的对象接管当前局（读档用）
func adopt_run(restored_run: RunState, restored_map: MapManager) -> void:
	run = restored_run
	map = restored_map


## 清空全部跨场景状态
func reset_run() -> void:
	run = null
	map = null
	job_path.clear()
	identity_power_ids.clear()
	divinity = 0
	humanity = 0


func has_active_run() -> bool:
	return run != null and not run.is_over


## 玩家当前的**终职** id（转职路径的最后一环）。
## 没转职时返回空串——神战镜像据此决定"神该变成什么"。
func final_job_id() -> StringName:
	if job_path.is_empty():
		return &""
	return job_path[job_path.size() - 1]


## 玩家当前的终职数据（没有则返回 null）
func final_job() -> JobData:
	var job_id: StringName = final_job_id()
	if job_id == &"":
		return null
	return JobDatabase.get_job(job_id)


## 当前幕的环境机制（阶段 6）。没有配置时返回 null——机制是可选增强，不是必需依赖。
func current_act_modifier() -> ActModifier:
	if run == null:
		return null
	var modifier_id: StringName = MapManager.ACT_MODIFIERS.get(run.current_act, &"")
	if modifier_id == &"":
		return null
	var loaded: Variant = ContentRegistry.get_act_modifier(modifier_id)
	return loaded as ActModifier


## 进入下一幕：重新生成地图（用「种子 + 幕」派生新种子，保证同局可复现）
func advance_act() -> void:
	if run == null:
		return
	run.current_act += 1
	run.current_node_id = -1

	map = MapManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = run.rng_seed + run.current_act * ACT_SEED_STRIDE
	map.generate(rng, run.current_act)

	EventBus.act_advanced.emit(run.current_act)


## 转职：把职业赋予的身份能力一并记入身份层
func apply_job(job: JobData) -> void:
	if job == null:
		return
	advance_job(job.id)
	for power_id: StringName in job.identity_power_ids:
		if not identity_power_ids.has(power_id):
			identity_power_ids.append(power_id)


# ── 转职（阶段 4 接入 UI，此处先备好逻辑）────────────────────

func advance_job(job_id: StringName) -> void:
	if job_path.has(job_id):
		push_warning("GameState.advance_job: 重复转职 %s，已忽略" % job_id)
		return
	job_path.append(job_id)
	job_advanced.emit(job_id)


func is_final_job_reached() -> bool:
	return job_path.size() >= 2


# ── 侵蚀 ────────────────────────────────────────────────────

func add_divinity(amount: int) -> void:
	divinity = clampi(divinity + amount, 0, DIVINITY_MAX)
	EventBus.erosion_changed.emit(divinity, humanity)


func add_humanity(amount: int) -> void:
	humanity = clampi(humanity + amount, 0, HUMANITY_MAX)
	EventBus.erosion_changed.emit(divinity, humanity)


## 凡人结局判定：以人之身承载规则而不被同化
func can_unlock_mortal_ending() -> bool:
	return humanity >= 3 and divinity < 60


## 神性 >= 90：已无法拒绝成为规则，结局锁定「登神」
func is_ascension_locked() -> bool:
	return divinity >= DIVINITY_ASCENSION


## 神性是否已显化（≥70）——战斗中会外显为强化 + 持续反噬
func is_divinity_manifest() -> bool:
	return divinity >= DIVINITY_MANIFEST


## 神性/人性的综合倾向，UI 用它画进度条（-1 全人性，+1 全神性）
func erosion_ratio() -> float:
	return clampf(float(divinity - humanity) / float(DIVINITY_MAX), -1.0, 1.0)


# ── 结局判定（阶段 6）──────────────────────────────────────

## 判定本局结局。
##
## 顺序**不可调换**：登神是"无法拒绝"，必须最先判定——
## 一个神性 95 的玩家即使人性也满了，也已经不是人了。
func resolve_ending() -> StringName:
	if divinity >= DIVINITY_ASCENSION:
		return &"ascension"
	if can_unlock_mortal_ending():
		return &"mortal"
	return &"godslayer"


static func ending_title(ending: StringName) -> String:
	match ending:
		&"ascension":
			return "登神"
		&"mortal":
			return "凡人"
		_:
			return "弑神"


static func ending_summary(ending: StringName) -> String:
	match ending:
		&"ascension":
			return "你成为了新的规则。从此再没有人能拒绝你——包括你自己。"
		&"mortal":
			return "你杀死了神，却没有成为它。你带着人的重量走了出去。"
		_:
			return "你杀死了神。世界空出了一个位置，而你不打算坐上去。"
