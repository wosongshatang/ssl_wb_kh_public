class_name PotionInfoPanel
extends OverlayPanel
## 药水信息弹层（单击药水栏时弹出）
##
## 用户要求：「点击药水栏里的药水即可查看药水信息」。
## 所以**单击 = 看信息，不是直接用**。使用有三个入口：
## 双击槽位 / 拖到敌人身上 / 点这里的「使用」按钮。
##
## 为什么要三个入口：药水是一次性资源，误触消耗掉一瓶是不可逆的损失。
## 多一个确认步骤，比事后让玩家心疼要好。

signal use_requested(slot_index: int)

var _potion: PotionData = null
var _slot_index: int = -1
var _blocked_reason: String = ""


func setup(potion: PotionData, slot_index: int, blocked_reason: String) -> void:
	_potion = potion
	_slot_index = slot_index
	_blocked_reason = blocked_reason
	frame_min_width = 400
	rebuild_content()


func _build_content() -> void:
	if _potion == null:
		add_text("（药水数据缺失）")
		add_button("关闭（ESC）", _close)
		return

	add_title(_potion.display_name)
	add_text(_potion.description)
	add_text("分类：%s　　使用方式：%s" % [
		_potion.category_text(), _potion.targeting_text(),
	])
	add_separator()

	# 「能不能用」与「用」分开：不能用时给出**原因**，
	# 而不是让按钮点了没反应——玩家最讨厌的不是不能做，是不知道能不能做。
	if _blocked_reason != "":
		add_text("现在用不了：%s" % _blocked_reason)
	else:
		add_button("使用", _on_use_pressed)

	add_button("关闭（ESC）", _close)


func _on_use_pressed() -> void:
	use_requested.emit(_slot_index)
	queue_free()


func _close() -> void:
	closed.emit()
	queue_free()
