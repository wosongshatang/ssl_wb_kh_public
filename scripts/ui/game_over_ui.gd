class_name GameOverUI
extends Control
## 结算画面（胜利 / 战败）
##
## 这里没有战斗逻辑，只读 GameState 的单局状态，所以放在 ui/ 不违反分层铁律。

signal back_to_boot_pressed

@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var detail_label: Label = %DetailLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_to_boot_pressed.emit())
	_refresh()


func _refresh() -> void:
	var run: RunState = GameState.run
	if run == null:
		title_label.text = "无进行中的对局"
		summary_label.text = ""
		detail_label.text = ""
		return

	if run.victory:
		title_label.text = "弑神"
		summary_label.text = "你击败了规则本身。"
	else:
		title_label.text = "陨落"
		summary_label.text = "你的旅程止步于此。"

	detail_label.text = "%s　最终生命 %d/%d　金币 %d　牌组 %d 张　抵达第 %d 幕" % [
		_character_name(run.character_class),
		run.hp, run.max_hp, run.gold, run.deck_card_ids.size(), run.current_act,
	]


func _character_name(character: StringName) -> String:
	match character:
		&"warrior":
			return "战士"
		&"hunter":
			return "猎人"
		&"mage":
			return "法师"
		_:
			return "无名者"
