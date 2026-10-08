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


## 职业图标在按钮上的显示边长。
const ICON_PX: int = 40


func _build_content() -> void:
	add_title(_title)
	add_text("规则一旦刻入灵魂，便**不可撤销、不可重选**。请慎重。")
	add_separator()

	if _jobs.is_empty():
		add_text("（没有可选的职业——检查 data/jobs/ 下的 parent_job 是否正确）")
		return

	for job: JobData in _jobs:
		var button := add_button(
			"%s\n　—　%s" % [job.display_name, job.description],
			_on_job_pressed.bind(job.id)
		)
		# 职业图标（阶段 8）。缺图时什么都不做 —— 按钮照常可用。
		var icon: Texture2D = ContentRegistry.get_job_icon(job.id)
		if icon != null:
			button.icon = _scaled_icon(icon, ICON_PX)


## 把 256×256 的图标缩到按钮能用的尺寸。
##
## ⚠️ **不要直接 `button.icon = tex`**：Button 默认按**原始像素**画图标，
## 256×256 会把按钮撑成一堵墙。
##
## 也不用主题常量 `icon_max_width` 兜——那是"主题里没配就静默失效"的一类依赖，
## 表现成"图标突然变得巨大"，而且不报错。自己缩是确定的。
func _scaled_icon(tex: Texture2D, target: int) -> Texture2D:
	var img: Image = tex.get_image()
	if img == null:
		return tex
	img.resize(target, target, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func _on_job_pressed(job_id: StringName) -> void:
	job_chosen.emit(job_id)
