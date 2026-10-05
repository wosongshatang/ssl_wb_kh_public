class_name ConfirmPanel
extends OverlayPanel
## 通用二次确认弹层
##
## ## 为什么删牌需要确认
## 删牌是**不可逆**的，而且玩家常常是在"随便点点看"的心态下点的——
## 没有确认的话，一次误触就永久少一张牌，而牌组是一局的核心资产。
##
## **代价越大的操作，越需要一次确认。**

signal confirmed
signal cancelled

var _title: String = ""
var _message: String = ""
var _confirm_text: String = "确认"
var _cancel_text: String = "取消"


func setup(
	title: String,
	message: String,
	confirm_text: String = "确认",
	cancel_text: String = "取消"
) -> void:
	_title = title
	_message = message
	_confirm_text = confirm_text
	_cancel_text = cancel_text
	frame_min_width = 420
	rebuild_content()


func _build_content() -> void:
	add_title(_title)
	add_text(_message)

	# 确认 / 取消都放**固定页脚**——它们是这个弹层唯一要做的事，不能被内容挤走
	add_footer_button(_cancel_text, _on_cancel)
	add_footer_button(_confirm_text, _on_confirm, true)


func _on_confirm() -> void:
	confirmed.emit()
	queue_free()


func _on_cancel() -> void:
	cancelled.emit()
	queue_free()
