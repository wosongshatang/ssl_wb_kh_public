extends Node
## 地图场景控制器（组合根）
##
## 把 GameState 里的单局状态 + 地图，翻译成 [MapUI] 的展示与交互。
## 节点类型分派也在这里——[MapUI] 只知道「玩家点了哪个节点」。

const REST_HEAL_RATIO: float = 0.3

@onready var ui: MapUI = %MapUI

var _run: RunState
var _map: MapManager


func _ready() -> void:
	ui.node_selected.connect(_on_node_selected)
	ui.save_and_exit_pressed.connect(_on_save_and_exit)
	ui.abandon_pressed.connect(_on_abandon)

	_run = GameState.run
	_map = GameState.map

	# 直接运行本场景（调试）时自动开一局，避免空指针
	if _run == null or _map == null:
		GameState.start_new_run(&"warrior", randi())
		_run = GameState.run
		_map = GameState.map

	ui.build_map(_map)
	_refresh()


func _refresh() -> void:
	ui.set_status("%s  %d/%d 生命   %d 金币   第 %d 幕   牌组 %d 张" % [
		_character_display_name(),
		_run.hp, _run.max_hp, _run.gold, _run.current_act, _run.deck_card_ids.size(),
	])

	var current: MapNode = _map.current_node()
	if current == null:
		ui.set_hint("选择起点。高亮为可前往，灰色为已访问。")
	else:
		ui.set_hint("当前位置：%s。请选择下一个节点。" % current.kind_label())

	ui.refresh(_map)


func _on_node_selected(node_id: int) -> void:
	if not _map.enter_node(node_id):
		return

	var node: MapNode = _map.nodes[node_id]
	match node.kind:
		MapNode.Kind.COMBAT, MapNode.Kind.ELITE, MapNode.Kind.BOSS:
			# 进战斗前存档——万一崩了还能从这一步重来
			SaveManager.save_run(_run, _map)
			get_tree().change_scene_to_file("res://scenes/battle/battle_log.tscn")

		MapNode.Kind.REST:
			var healed: int = int(ceil(float(_run.max_hp) * REST_HEAL_RATIO))
			_run.heal(healed)
			ui.set_hint("休息：回复 %d 点生命。" % healed)
			_refresh()

		_:
			ui.set_hint("「%s」在阶段 3 尚未实现（阶段 6 填充）。" % node.kind_label())
			_refresh()


func _on_save_and_exit() -> void:
	SaveManager.save_run(_run, _map)
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


func _on_abandon() -> void:
	SaveManager.delete_save()
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


func _character_display_name() -> String:
	match _run.character_class:
		&"warrior":
			return "战士"
		&"hunter":
			return "猎人"
		&"mage":
			return "法师"
		_:
			return "无名者"
