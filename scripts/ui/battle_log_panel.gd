class_name BattleLogPanel
extends OverlayPanel
## 整场战斗的日志（可滚动）
##
## 用户要求：战斗日志不该挂在屏幕中间，改成 HUD 上的一个按钮，
## 点开看完整日志并支持滑动。
##
## 为什么"完整日志"比"实时单行"更好用：
## 战斗中玩家的注意力在敌人意图和手牌上，实时日志反而挡视线；
## 而**打完之后想复盘"刚才那 6 点伤害怎么算的"**时，完整日志才有价值。

var _lines: PackedStringArray = PackedStringArray()


func setup(lines: PackedStringArray) -> void:
	_lines = lines
	frame_min_width = 660
	rebuild_content()


func _build_content() -> void:
	add_title("战斗日志（%d 条）" % _lines.size())

	if _lines.is_empty():
		add_text("（本场战斗还没有记录）")
		add_separator()
		add_button("关闭（ESC）", _close)
		return

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_box.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(580, 0)
	scroll.add_child(box)

	for line: String in _lines:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(570, 0)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", UiPalette.TEXT)
		box.add_child(label)

	# 默认滚到**最新**一条（复盘时最关心的是刚发生的）
	scroll.set_deferred("scroll_vertical", 1 << 20)

	add_separator()
	add_button("关闭（ESC）", _close)


func _close() -> void:
	closed.emit()
	queue_free()
