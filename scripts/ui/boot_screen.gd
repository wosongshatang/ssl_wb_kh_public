extends Control
## 启动画面 / 主菜单
##
## 阶段 3 起：这里是「一局」的入口——新游戏 / 继续游戏。
## 具体流程编排在 MapScene 与 BattleScene（组合根），本类只负责按钮与状态展示。

const GAME_TITLE: String = "弑神律"
const BUILD_STAGE: String = "阶段 3 · 单局骨架"

@onready var title_label: Label = %TitleLabel
@onready var stage_label: Label = %StageLabel
@onready var content_label: Label = %ContentLabel
@onready var new_game_button: Button = %NewGameButton
@onready var continue_button: Button = %ContinueButton
@onready var debug_battle_button: Button = %DebugBattleButton

var _select_panel: CharacterSelectPanel = null


func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	debug_battle_button.pressed.connect(_on_debug_battle_pressed)

	title_label.text = GAME_TITLE
	stage_label.text = BUILD_STAGE

	var counts: Dictionary = ContentRegistry.summary()
	content_label.text = "内容注册表：卡牌 %d / 遗物 %d / 职业 %d / 敌人 %d / 幕 %d" % [
		counts["cards"],
		counts["relics"],
		counts["jobs"],
		counts["enemies"],
		counts["acts"],
	]

	# 没有存档时「继续游戏」直接置灰——比点了没反应好
	continue_button.disabled = not SaveManager.has_save()

	print("[Boot] %s —— %s" % [GAME_TITLE, BUILD_STAGE])
	print("[Boot] Godot %s" % Engine.get_version_info()["string"])
	print("[Boot] 引擎版本 4.6 / 渲染后端 GL Compatibility")


## 新游戏 → **先选角色**（多角色前置 ③）。
## 之前写死 `&"warrior"`，加多少角色都只有战士能玩。
func _on_new_game_pressed() -> void:
	if _select_panel != null:
		return

	_select_panel = CharacterSelectPanel.new()
	add_child(_select_panel)
	_select_panel.setup()
	_select_panel.character_chosen.connect(_on_character_chosen)
	_select_panel.closed.connect(_close_select)


func _on_character_chosen(character: StringName, ascension_level: int) -> void:
	_close_select()
	GameState.start_new_run(character, randi(), ascension_level)
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")


func _close_select() -> void:
	if _select_panel != null:
		_select_panel.queue_free()
		_select_panel = null


func _on_continue_pressed() -> void:
	var restored: Array = SaveManager.restore()
	if restored.size() != 2:
		content_label.text = "存档无法读取，已按「无存档」处理。"
		continue_button.disabled = true
		return

	GameState.adopt_run(restored[0] as RunState, restored[1] as MapManager)

	# 存档记录着"有一场没结算的战斗"→ 回到战斗，而不是跳过它去地图
	var restored_run := restored[0] as RunState
	if restored_run.in_battle:
		get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/map/map.tscn")


func _on_debug_battle_pressed() -> void:
	if GameState.run == null:
		GameState.start_new_run(&"warrior", randi())
	get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
