extends Node
## 战斗结算场景控制器（组合根）
##
## 流程：战斗胜利 → 写入 `GameState.pending_reward` → 切到本场景
##       → 玩家逐项领取 → 点「前进」→ 一次性 commit 回 RunState → 回地图
##
## 「一次性 commit」是刻意的（D24）：玩家还没点前进就崩溃/退出，
## 不会留下半成品存档。

var _run: RunState
var _bundle: RewardBundle
var _ui: RewardUI
var _overlay: OverlayPanel = null


func _ready() -> void:
	_run = GameState.run
	if _run == null:
		# 直接运行本场景（调试）时兜底，避免空指针
		GameState.start_new_run(&"warrior", randi())
		_run = GameState.run

	_bundle = RewardBundle.from_dict(GameState.pending_reward)

	_ui = RewardUI.new()
	add_child(_ui)
	_ui.row_pressed.connect(_on_row_pressed)
	_ui.forward_pressed.connect(_on_forward_pressed)
	_ui.setup(_bundle)


func _on_row_pressed(key: String) -> void:
	match key:
		"gold":
			if _bundle.taken_gold:
				return
			_bundle.taken_gold = true
			_ui.mark_taken(key, "金币 +%d" % _bundle.gold)

		"potion":
			if _bundle.taken_potion:
				return
			if _run.is_potion_bar_full():
				_ui.show_hint("药水栏已满，先喝掉一瓶再来拿。")
				return
			_bundle.taken_potion = true
			_ui.mark_taken(key, RewardBundle.potion_name(_bundle.potion_id))

		"relic":
			if _bundle.taken_relic:
				return
			if _run.relics.has(_bundle.relic_id):
				_ui.show_hint("你已经拥有这件遗物了。")
				return
			_bundle.taken_relic = true
			_ui.mark_taken(key, RewardBundle.relic_name(_bundle.relic_id))

		"card":
			if _bundle.chosen_card_id != &"":
				return
			_open_card_choice()

		_:
			push_warning("RewardScene: 未知奖励行「%s」" % key)


func _open_card_choice() -> void:
	if _overlay != null:
		return

	var cards: Array[CardData] = []
	for card_id: StringName in _bundle.card_offer_ids:
		var loaded: Variant = ContentRegistry.get_card(card_id)
		if loaded is CardData:
			cards.append(loaded as CardData)

	if cards.is_empty():
		_ui.show_hint("没有可选的牌。")
		return

	var panel := CardChoicePanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup("将一张牌添加到你的牌组", cards, true)
	panel.card_chosen.connect(_on_card_chosen)
	panel.cancelled.connect(_close_overlay)


func _on_card_chosen(card_id: StringName) -> void:
	_bundle.chosen_card_id = card_id
	_ui.mark_taken("card", RewardBundle.card_name(card_id))
	_close_overlay()


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


## 前进：把玩家已领取的部分**一次性**写回 RunState
func _on_forward_pressed() -> void:
	var summary: String = _bundle.commit(_run)
	print("[Reward] %s" % summary)

	GameState.pending_reward = {}
	SaveManager.save_run(_run, GameState.map)
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")
