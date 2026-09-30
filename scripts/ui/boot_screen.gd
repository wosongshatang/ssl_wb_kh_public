extends Control
## BootScreen —— 启动画面 / 主场景入口
##
## Phase 0 职责：证明工程能跑起来（显示版本与骨架就绪状态）。
## 阶段 3 起会被替换为真正的主菜单（新游戏 / 继续 / 设置）。

const GAME_TITLE: String = "弑神律"
const BUILD_STAGE: String = "阶段 0 · 骨架就绪"

@onready var title_label: Label = %TitleLabel
@onready var stage_label: Label = %StageLabel
@onready var content_label: Label = %ContentLabel
@onready var enter_battle_button: Button = %EnterBattleButton


func _ready() -> void:
	enter_battle_button.pressed.connect(_on_enter_battle_pressed)

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
	print("[Boot] %s —— %s" % [GAME_TITLE, BUILD_STAGE])
	print("[Boot] Godot %s" % Engine.get_version_info()["string"])
	print("[Boot] 引擎版本 4.6 / 渲染后端 GL Compatibility")


func _on_enter_battle_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/battle/battle_log.tscn")
