class_name EventPanel
extends OverlayPanel
## 事件弹层
##
## 只发信号（选了第几个选项），实际结算由 MapScene 负责——
## 因为结算要改 RunState，而 RunState 不属于 UI 的职责范围。

signal option_chosen(index: int)

var _event: EventData


func setup(event_data: EventData) -> void:
	_event = event_data
	rebuild_content()


func _build_content() -> void:
	if _event == null:
		add_text("（事件数据缺失）")
		return

	add_title(_event.title)
	add_text(_event.description)
	add_separator()

	if not _event.option_a_label.is_empty():
		add_button(
			_option_label(_event.option_a_label, _event.option_a_effect, _event.option_a_value),
			_on_option_a_pressed
		)
	if not _event.option_b_label.is_empty():
		add_button(
			_option_label(_event.option_b_label, _event.option_b_effect, _event.option_b_value),
			_on_option_b_pressed
		)


func _option_label(label: String, effect: EventData.Effect, value: int) -> String:
	return "%s\n　—　%s" % [label, EventData.effect_text(effect, value)]


func _on_option_a_pressed() -> void:
	option_chosen.emit(0)


func _on_option_b_pressed() -> void:
	option_chosen.emit(1)
