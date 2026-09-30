class_name MapUI
extends Control
## 地图界面（阶段 3）
##
## 分层铁律：ui/ 只发信号 + 纯展示。逻辑编排在 [MapScene]（组合根）。
##
## 阶段 3 采用**全量重建**：每次进地图重建一遍按钮。
## 地图节点数最多二十几个，重建开销可忽略；阶段 8 若真有卡顿再做增量更新。

signal node_selected(node_id: int)
signal save_and_exit_pressed
signal abandon_pressed

@onready var status_label: Label = %StatusLabel
@onready var rows_container: VBoxContainer = %RowsContainer
@onready var hint_label: Label = %HintLabel
@onready var save_exit_button: Button = %SaveExitButton
@onready var abandon_button: Button = %AbandonButton

## node_id -> Button
var _buttons: Dictionary = {}


func _ready() -> void:
	save_exit_button.pressed.connect(func() -> void: save_and_exit_pressed.emit())
	abandon_button.pressed.connect(func() -> void: abandon_pressed.emit())


# ── 展示接口 ────────────────────────────────────────────────

func set_status(text: String) -> void:
	status_label.text = text


func set_hint(text: String) -> void:
	hint_label.text = text


## 重建整张地图
func build_map(map: MapManager) -> void:
	for child: Node in rows_container.get_children():
		child.queue_free()
	_buttons.clear()

	for r: int in map.rows.size():
		var row_box := HBoxContainer.new()
		row_box.alignment = BoxContainer.ALIGNMENT_CENTER
		row_box.add_theme_constant_override("separation", 10)
		rows_container.add_child(row_box)

		for node_id: int in map.rows[r]:
			var node: MapNode = map.nodes[node_id]
			var button := Button.new()
			button.text = node.kind_label()
			button.custom_minimum_size = Vector2(104, 40)
			# 用 bind 而不是 lambda 捕获 node_id：lambda 捕获循环变量的行为容易踩坑
			button.pressed.connect(_on_node_button_pressed.bind(node_id))
			row_box.add_child(button)
			_buttons[node_id] = button

	refresh(map)


## 只刷新可达 / 已访问状态，不重建节点
func refresh(map: MapManager) -> void:
	var available: Dictionary = {}
	for node: MapNode in map.available_nodes():
		available[node.id] = true

	for node_id: Variant in _buttons:
		var button: Button = _buttons[node_id]
		var node: MapNode = map.nodes[node_id]
		button.disabled = not available.has(node_id)
		button.modulate = Color(0.55, 0.55, 0.6) if node.is_visited else Color.WHITE


func _on_node_button_pressed(node_id: int) -> void:
	node_selected.emit(node_id)
