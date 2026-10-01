class_name RestChoicePanel
extends OverlayPanel
## 休息点选择弹层（用户要求：休息应该能回 30% 血 **或** 升级卡牌）
##
## ## 为什么给两个选项而不是只回血
## 只回血的休息点会变成"血少就来、血多就跳过"的机械决策；
## 加入「锻造」后，玩家在**续航**与**牌组质量**之间做取舍——
## 这才是 Roguelike 里休息点真正有意思的地方。
##
## 升级目标由场景通过 [method setup] 传进来；没有可升级的牌时该选项置灰。

signal rest_chosen
signal upgrade_chosen
signal cancelled

var _heal_amount: int = 0
var _max_hp: int = 0
var _upgradable_count: int = 0


func setup(heal_amount: int, max_hp: int, upgradable_count: int) -> void:
	_heal_amount = heal_amount
	_max_hp = max_hp
	_upgradable_count = upgradable_count
	frame_min_width = 420
	rebuild_content()


func _build_content() -> void:
	add_title("休息处")
	add_text("你在篝火旁停下。可以恢复体力，也可以打磨手中的牌。")
	add_separator()

	add_button("休息：回复 %d 点生命（最大生命的 %d%%）" % [
		_heal_amount, int(RestChoicePanel.HEAL_RATIO * 100.0),
	], _on_rest_pressed)

	if _upgradable_count > 0:
		add_button("锻造：升级一张牌（可升级 %d 张）" % _upgradable_count, _on_upgrade_pressed)
	else:
		add_text("锻造：牌组里已经没有可升级的牌了。")

	add_separator()
	add_button("离开（ESC）", _cancel)


## 回复比例。放常量里，方便与 MapScene 的结算保持一致。
const HEAL_RATIO: float = 0.3


func _on_rest_pressed() -> void:
	rest_chosen.emit()
	queue_free()


func _on_upgrade_pressed() -> void:
	upgrade_chosen.emit()
	queue_free()


func _cancel() -> void:
	cancelled.emit()
	queue_free()
