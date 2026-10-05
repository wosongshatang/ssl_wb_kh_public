class_name TraitorPanel
extends OverlayPanel
## 叛神者（P6-10）—— **唯一能主动降低神性**的地方
##
## ## 为什么必须有它
## 凡人结局要求「人性 ≥ 3 且 神性 < 60」，
## 但无色卡、神格遗物、神坛**全都在加神性**——
## 一个单向上涨的侵蚀条，等于宣告"凡人结局只是个理论值"。
##
## **看得见却拿不到的目标，比没有目标更让人沮丧。**
## 所以凡人路线必须有一个"出口"，哪怕代价很大。

signal strip_chosen     ## 剥离神性：-20 神性，得一件普通遗物
signal deepen_chosen    ## 加深侵蚀：+20 神性，得 2 瓶药水
signal leave_chosen

const DIVINITY_DELTA: int = 20


func setup() -> void:
	frame_min_width = 460
	rebuild_content()


func _build_content() -> void:
	add_node_banner(MapNode.Kind.TRAITOR, "叛神者",
		"「我背过身去的那天，才第一次看清自己。」")

	add_text("剥离：神性 -%d，获得一件遗物。" % DIVINITY_DELTA)
	add_button("帮我把它拿出去", _on_strip)

	add_separator()

	add_text("加深：神性 +%d，获得 2 瓶药水。" % DIVINITY_DELTA)
	add_button("不，让它长满我", _on_deepen)

	add_separator()
	add_button("什么也不做", _on_leave)


func _on_strip() -> void:
	strip_chosen.emit()
	queue_free()


func _on_deepen() -> void:
	deepen_chosen.emit()
	queue_free()


func _on_leave() -> void:
	leave_chosen.emit()
	queue_free()
