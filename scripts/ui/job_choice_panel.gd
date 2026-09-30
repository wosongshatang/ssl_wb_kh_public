class_name JobChoicePanel
extends OverlayPanel
## 转职仪式面板 —— 选择一条要刻进灵魂的规则
##
## 转职**不可逆、不可重选、不可跨分支**（设计文档 §2.1）。
## 所以面板上必须把「不可退还」讲清楚——这是「神性侵蚀」系统的叙事根基：
## 你无法被夺走力量，也无法拒绝力量带来的同化。
##
## 只发信号，不碰 GameState。

signal job_chosen(job_id: StringName)

var _jobs: Array[JobData] = []
var _title: String = "转职仪式"


func setup(title: String, jobs: Array[JobData]) -> void:
	_title = title
	_jobs = jobs
	rebuild_content()


func _build_content() -> void:
	add_title(_title)
	add_text("规则一旦刻入灵魂，便**不可撤销、不可重选**。请慎重。")
	add_separator()

	if _jobs.is_empty():
		add_text("（没有可选的职业——检查 data/jobs/ 下的 parent_job 是否正确）")
		return

	for job: JobData in _jobs:
		add_button(
			"%s\n　—　%s" % [job.display_name, job.description],
			_on_job_pressed.bind(job.id)
		)


func _on_job_pressed(job_id: StringName) -> void:
	job_chosen.emit(job_id)
