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
	back_button.pressed.connect(_on_back_pressed)
	_refresh()


## ⚠️ 这里必须**自己**处理导航。
## GameOverUI 就是场景根节点，没有组合根帮它接线——之前只 emit 了一个
## 没人监听的信号，按钮点了完全没反应。这类"信号发了但没人听"的 bug
## 不会报任何错，只能靠"每加一个信号就问谁在听"来避免。
func _on_back_pressed() -> void:
	back_to_boot_pressed.emit()

	# 元进度：结局计数**必须在 reset_run 之前**记——
	# reset 会把本局状态清掉，之后就算不出是哪个结局了。
	# ⚠️ 这里没有 `run` 变量（那是 `_refresh()` 里的局部量），
	# 必须从 GameState 现取。
	var run: RunState = GameState.run
	if run != null and run.victory:
		MetaState.record_ending(GameState.resolve_ending())
		# 进阶解锁（阶段 10）：通关当前进阶 → 解锁下一级。
		# 顺序在 record_ending 之后、reset_run 之前——同样因为 reset 会清掉等级。
		MetaState.record_ascension_clear(run.character_class, run.ascension)

	# 本局已结束（存档在结算时已删除），清掉状态免得标题页读到半截数据
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


func _refresh() -> void:
	var run: RunState = GameState.run
	if run == null:
		title_label.text = "无进行中的对局"
		summary_label.text = ""
		detail_label.text = ""
		return

	if run.victory:
		# 三结局判定（阶段 6）：登神 / 凡人 / 弑神
		var ending: StringName = GameState.resolve_ending()
		title_label.text = GameState.ending_title(ending)
		summary_label.text = GameState.ending_summary(ending)
	else:
		title_label.text = "陨落"
		summary_label.text = "你的旅程止步于此。"

	detail_label.text = "%s　最终生命 %d/%d　金币 %d　牌组 %d 张　抵达第 %d 幕\n神性 %d / 人性 %d" % [
		_character_name(run.character_class),
		run.hp, run.max_hp, run.gold, run.deck_card_ids.size(), run.current_act,
		GameState.divinity, GameState.humanity,
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
