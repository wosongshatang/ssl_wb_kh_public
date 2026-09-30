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
	return divinity >= 90
