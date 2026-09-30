extends Node
## GameState —— 跨场景全局状态（Autoload）
##
## 职责：角色 / 转职路径 / 侵蚀（神性与人性）/ 遗物 等「跨场景」状态。
##
## 纪律（工程书 §2.2）：禁止放战斗逻辑。任何能放进实例化场景的逻辑都不该进 Autoload。
##
## 身份层契约（工程书 §3.2）：本对象是身份能力「不可剥夺」的物理源头。
## 身份能力的权威数据挂在 [member identity_power_ids]（来自 JobData），
## 每场战斗初始化玩家 Creature 时重新实例化注入。任何战斗内效果
## （沉默 / 驱散 / 夺能）都接触不到本对象，因此身份能力天然不可被移除。

signal job_advanced(job_id: StringName)

## 神性 / 人性进度条上限（共用同一条进度条，双向对比，设计文档 §8.3）
const DIVINITY_MAX: int = 100
const HUMANITY_MAX: int = 100

## 当前角色 id（warrior / hunter / mage）；空串表示尚未选角
var character_class: StringName = &""

## 转职路径：按顺序记录已刻入灵魂的规则（[0] 一阶 → [1] 二阶终职）
var job_path: Array[StringName] = []

## 神性：侵蚀进度。>= 90 时结局锁定为「登神」（设计文档 §8.4）
var divinity: int = 0

## 人性：凡人结局需 humanity >= 3 且 divinity < 60（设计文档 §1.5）
var humanity: int = 0

## 本局持有的遗物 id
var relics: Array[StringName] = []

## 本局持有的身份能力 id（身份层权威来源，战斗开始时重新实例化注入）
var identity_power_ids: Array[StringName] = []


## 开新局：清空全部跨场景状态
func reset_run() -> void:
	character_class = &""
	job_path.clear()
	divinity = 0
	humanity = 0
	relics.clear()
	identity_power_ids.clear()


## 转职：刻入一条规则。不可逆、不可重选、不可跨分支（设计文档 §2.1）
func advance_job(job_id: StringName) -> void:
	if job_path.has(job_id):
		push_warning("GameState.advance_job: 重复转职 %s，已忽略" % job_id)
		return
	job_path.append(job_id)
	job_advanced.emit(job_id)


## 是否已达成二阶终职
func is_final_job_reached() -> bool:
	return job_path.size() >= 2


## 神性增长（转职 / 神格遗物 / 神坛 / 神化牌）
func add_divinity(amount: int) -> void:
	divinity = clampi(divinity + amount, 0, DIVINITY_MAX)


## 人性增长（拒绝神恩 / 帮助叛神者 / 归还遗物）
func add_humanity(amount: int) -> void:
	humanity = clampi(humanity + amount, 0, HUMANITY_MAX)


## 凡人结局判定：以人之身承载规则而不被同化（设计文档 §1.5）
func can_unlock_mortal_ending() -> bool:
	return humanity >= 3 and divinity < 60


## 神性 >= 90：已无法拒绝成为规则，结局锁定「登神」
func is_ascension_locked() -> bool:
	return divinity >= 90
