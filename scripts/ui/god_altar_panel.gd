class_name GodAltarPanel
extends OverlayPanel
## 神坛（P6-10）—— 向神献祭，换力量，代价是侵蚀
##
## ## 与「窃权事件」的分工
## - 窃权事件 = 一次性事件，给**神格遗物**
## - 神坛 = 地图上的固定节点，给**永久属性**（力量），代价是神性
##
## 两者都在推高侵蚀，但神坛更"日常"——玩家每次看到它都要重新权衡一次。
## **这就是它存在的意义**：让侵蚀不是一次性选择，而是反复的小决定累积出来的。

signal sacrifice_chosen
signal leave_chosen

## 献祭：失去当前最大生命的这个比例
const HP_COST_RATIO: float = 0.25
const STRENGTH_GAIN: int = 3
const DIVINITY_GAIN: int = 8
## 拒绝：回复最大生命的这个比例（不是白跑一趟）
const LEAVE_HEAL_RATIO: float = 0.1

var _hp_cost: int = 0
var _heal: int = 0


func setup(max_hp: int) -> void:
	_hp_cost = maxi(1, int(ceil(float(max_hp) * HP_COST_RATIO)))
	_heal = maxi(1, int(ceil(float(max_hp) * LEAVE_HEAL_RATIO)))
	frame_min_width = 460
	rebuild_content()


func _build_content() -> void:
	add_node_banner(MapNode.Kind.GOD_ALTAR, "神坛",
		"石台上刻着一行字：「力量从不免费。」")

	add_text("献祭：失去 %d 点生命，获得 %d 点力量（永久）。\n神性 +%d。" % [
		_hp_cost, STRENGTH_GAIN, DIVINITY_GAIN])
	add_button("献祭生命，换取力量", _on_sacrifice)

	add_separator()

	add_text("离开：回复 %d 点生命。" % _heal)
	add_button("转身离开", _on_leave)


func _on_sacrifice() -> void:
	sacrifice_chosen.emit()
	queue_free()


func _on_leave() -> void:
	leave_chosen.emit()
	queue_free()
