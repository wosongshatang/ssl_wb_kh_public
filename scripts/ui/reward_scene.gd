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
var _hud: RunHUD
var _overlay: OverlayPanel = null


func _ready() -> void:
	_run = GameState.run
	if _run == null:
		# 直接运行本场景（调试）时兜底，避免空指针
		GameState.start_new_run(&"warrior", randi())
		_run = GameState.run

	_bundle = RewardBundle.from_dict(GameState.pending_reward)

	_build_hud()

	_ui = RewardUI.new()
	add_child(_ui)
	_ui.row_pressed.connect(_on_row_pressed)
	_ui.forward_pressed.connect(_on_forward_pressed)
	_ui.setup(_bundle)


## 结算界面也要有顶部 HUD（用户要求）：
## 玩家需要**看着路线和牌组**来决定拿哪张牌、拿不拿这瓶药水。
## 没有 HUD 就只能凭记忆选，等于逼玩家做盲选。
func _build_hud() -> void:
	_hud = RunHUD.new()
	add_child(_hud)
	_hud.bind_run(_run)
	# 结算界面不计时——时间是"游玩时长"，卡在结算画面不该被计入
	_hud.set_time_running(false)
	_hud.set_log_available(false)

	RunOverlays.wire(self, _hud, _run, _get_overlay, _set_overlay, _on_return_to_title)
	_hud.potion_pressed.connect(_on_potion_clicked)
	_hud.potion_double_clicked.connect(_on_potion_double_clicked)


func _get_overlay() -> Variant:
	return _overlay


func _set_overlay(panel: Variant) -> void:
	_overlay = panel as OverlayPanel


func _on_return_to_title() -> void:
	SaveManager.save_run(_run, GameState.map)
	get_tree().change_scene_to_file("res://scenes/boot/main.tscn")


# ── 药水（结算界面也能看 / 喝，方便腾出药水栏拿奖励）────────

func _on_potion_clicked(slot_index: int) -> void:
	if _overlay != null:
		return
	var potion: PotionData = _potion_at(slot_index)
	if potion == null:
		return

	# 结算界面没有战斗，按"地图上"处理（只能用通用式）
	var blocked: String = PotionResolver.can_use(potion, false, false)
	var panel := PotionInfoPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(potion, slot_index, blocked)
	panel.use_requested.connect(_on_potion_use_requested)
	panel.closed.connect(_close_overlay)


func _on_potion_use_requested(slot_index: int) -> void:
	_close_overlay()
	_use_potion_on_self(slot_index)


func _on_potion_double_clicked(slot_index: int) -> void:
	_use_potion_on_self(slot_index)


func _potion_at(slot_index: int) -> PotionData:
	if slot_index < 0 or slot_index >= _run.potions.size():
		return null
	var loaded: Variant = ContentRegistry.get_potion(_run.potions[slot_index])
	if loaded is PotionData:
		return loaded as PotionData
	return null


func _use_potion_on_self(slot_index: int) -> void:
	var potion: PotionData = _potion_at(slot_index)
	if potion == null:
		return

	var blocked: String = PotionResolver.can_use(potion, false, false)
	if blocked != "":
		_ui.show_hint("%s 现在用不了：%s" % [potion.display_name, blocked])
		return

	var proxy := Creature.new()
	proxy.max_hp = _run.max_hp
	proxy.reset_for_battle()
	proxy.set_hp(_run.hp)

	var result := PotionResolver.apply(potion, proxy, null, null, RandomNumberGenerator.new())
	if not result.success:
		proxy.free()
		_ui.show_hint("%s 用不了：%s" % [potion.display_name, result.message])
		return

	_run.sync_from_creature(proxy)
	proxy.free()

	_run.remove_potion_at(slot_index)
	_ui.show_hint("使用 %s：%s" % [potion.display_name, result.message])
	_hud.refresh()
	# 药水栏腾出位置后，奖励行要重新判定"能不能拿"
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