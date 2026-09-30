class_name SettingsPanel
extends OverlayPanel
## 设置弹层
##
## 用户要求：「现在只有回到标题和退出游戏两个选项，点击 esc 回到游戏界面」。
## 所以这里**刻意不做**音量/画面之类的假选项——没实现的功能放上去只会误导。

signal return_to_title_pressed
signal quit_pressed


func setup() -> void:
	frame_min_width = 360
	rebuild_content()


func _build_content() -> void:
	add_title("设置")
	add_text("按 ESC 或点击下方按钮回到游戏。")
	add_separator()

	add_button("回到标题", _on_return_to_title)
	add_button("退出游戏", _on_quit)
	add_separator()
	add_button("继续游戏（ESC）", _close)


func _on_return_to_title() -> void:
	return_to_title_pressed.emit()
	queue_free()


func _on_quit() -> void:
	quit_pressed.emit()


func _close() -> void:
	closed.emit()
	queue_free()
