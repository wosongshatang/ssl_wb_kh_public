class_name BattleLogUI
extends Control
## 战斗日志界面（阶段 1 薄切片版）
##
## 分层铁律（工程书 §2.3）：ui/ 目录**不得** import battle/ 或 pipeline/ 的逻辑。
## 本类只做两件事：
##   1. 暴露信号，把「玩家意图」抛出去
##   2. 提供纯展示接口（append_log / set_status / ...）
## 逻辑编排由 scripts/battle/battle_scene.gd（组合根）负责。

signal attack_pressed
signal defend_pressed
signal end_turn_pressed
signal back_pressed

@onready var log_view: RichTextLabel = %LogView
@onready var status_label: Label = %StatusLabel
@onready var hand_label: Label = %HandLabel
@onready var attack_button: Button = %AttackButton
@onready var defend_button: Button = %DefendButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	attack_button.pressed.connect(func() -> void: attack_pressed.emit())
	defend_button.pressed.connect(func() -> void: defend_pressed.emit())
	end_turn_button.pressed.connect(func() -> void: end_turn_pressed.emit())
	back_button.pressed.connect(func() -> void: back_pressed.emit())


# ── 展示接口（纯赋值，无逻辑）────────────────────────────────

func append_log(text: String) -> void:
	log_view.append_text(text + "\n")


func clear_log() -> void:
	log_view.clear()


func set_status(text: String) -> void:
	status_label.text = text


func set_hand(text: String) -> void:
	hand_label.text = text


func set_actions_enabled(enabled: bool) -> void:
	attack_button.disabled = not enabled
	defend_button.disabled = not enabled
	end_turn_button.disabled = not enabled
