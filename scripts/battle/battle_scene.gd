extends Node
## 战斗场景控制器（组合根）
##
## 负责把 BattleManager（逻辑）与一堆视图控件接起来。视图只发信号，
## 数值与状态全部由 BattleManager / DamagePipeline 决定。
##
## 布局参考用户提供的视频：角色在左、敌人在右，底部是手牌区与能量球，
## 左下弃牌堆、右下抽牌堆，顶部是本局 HUD。

const GOLD_REWARD_COMBAT: int = 12
const GOLD_REWARD_ELITE: int = 30
const MAX_ACTS: int = 3
const POTION_DROP_CHANCE: float = 0.35
const HAND_CARD_SPACING: int = 6
const ENEMY_SLOT_SPACING: float = 190.0
const ACTOR_Y_RATIO: float = 0.56

var _run: RunState
var _node_kind: int = MapNode.Kind.COMBAT
var _battle: BattleManager
var _player: Player
var _enemies: Array[Enemy] = []

var _hud: RunHUD
var _field: Control
var _player_view: CombatActorView
var _enemy_views: Array[CombatActorView] = []
var _hand_box: HBoxContainer
var _energy_label: Label
var _draw_pile_label: Label
var _discard_pile_label: Label
var _turn_banner: Label
var _end_turn_button: Button
## 本场战斗的完整日志。用户要求：日志收进可滑动面板，不挂在屏幕中间——
## 战斗中玩家的注意力在敌人意图和手牌上，实时日志反而挡视线。
var _log_lines: PackedStringArray = PackedStringArray()

var _job_panel: JobChoicePanel = null
var _overlay: OverlayPanel = null
var _busy: bool = false


func _ready() -> void:
	_run = GameState.run
	if _run == null:
		GameState.start_new_run(&"warrior", randi())
		_run = GameState.run

	var node: MapNode = GameState.map.current_node() if GameState.map != null else null
	_node_kind = node.kind if node != null else MapNode.Kind.COMBAT

	_build_ui()
	_start_battle()
	get_viewport().size_changed.connect(_layout)


# ══ 界面构建 ════════════════════════════════════════════════

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = UiPalette.BG_DEEP
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# 战场层用绝对定位——立绘要能被 Tween 挪动，放进容器会被布局系统覆盖
	_field = Control.new()
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)

	_hand_box = HBoxContainer.new()
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_box.add_theme_constant_override("separation", HAND_CARD_SPACING)
	add_child(_hand_box)

	_energy_label = _make_corner_label(UiPalette.ENERGY_ORB)
	add_child(_energy_label)
	_discard_pile_label = _make_corner_label(UiPalette.TEXT_DIM)
	add_child(_discard_pile_label)
	_draw_pile_label = _make_corner_label(UiPalette.BLOCK_BLUE)
	add_child(_draw_pile_label)

	_turn_banner = Label.new()
	_turn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_banner.add_theme_font_size_override("font_size", 40)
	_turn_banner.add_theme_color_override("font_color", UiPalette.GOLD)
	_turn_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_banner.modulate = Color(1, 1, 1, 0)
	add_child(_turn_banner)

	_end_turn_button = Button.new()
	_end_turn_button.text = "结束回合"
	_end_turn_button.custom_minimum_size = Vector2(120, 42)
	_end_turn_button.focus_mode = Control.FOCUS_NONE
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(_end_turn_button)

	_hud = RunHUD.new()
	add_child(_hud)
	_hud.bind_run(_run)
	_hud.set_time_running(true)
	_hud.deck_pressed.connect(_open_deck)
	_hud.relics_pressed.connect(_open_relics)
	_hud.settings_pressed.connect(_open_settings)
	_hud.map_pressed.connect(_open_map_overlay)
	_hud.potion_pressed.connect(_on_potion_clicked)
	_hud.potion_double_clicked.connect(_on_potion_double_clicked)
	_hud.log_pressed.connect(_open_battle_log)


func _make_corner_label(accent: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", accent)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var field_top: float = RunHUD.HUD_HEIGHT + 20.0
	var hand_height: float = 200.0
	var field_height: float = viewport_size.y - field_top - hand_height
	var actor_y: float = field_top + field_height * ACTOR_Y_RATIO - CombatActorView.VIEW_SIZE.y * 0.5

	if _player_view != null:
		_player_view.position = Vector2(
			viewport_size.x * 0.24 - CombatActorView.VIEW_SIZE.x * 0.5, actor_y)

	for i: int in _enemy_views.size():
		var count: int = _enemy_views.size()
		var center_x: float = viewport_size.x * 0.68 + float(i) * ENEMY_SLOT_SPACING
		if count > 1:
			center_x = viewport_size.x * 0.62 + (float(i) - float(count - 1) * 0.5) * ENEMY_SLOT_SPACING
		_enemy_views[i].position = Vector2(
			center_x - CombatActorView.VIEW_SIZE.x * 0.5, actor_y)

	var hand_width: float = viewport_size.x * 0.72
	_hand_box.position = Vector2((viewport_size.x - hand_width) * 0.5, viewport_size.y - hand_height + 24.0)
	_hand_box.size = Vector2(hand_width, 170)

	_energy_label.position = Vector2(34, viewport_size.y - 214)
	_discard_pile_label.position = Vector2(30, viewport_size.y - 64)
	_draw_pile_label.position = Vector2(viewport_size.x - 108, viewport_size.y - 64)
	_turn_banner.position = Vector2(0, field_top + field_height * 0.16)
	_turn_banner.size = Vector2(viewport_size.x, 60)
	_end_turn_button.position = Vector2(viewport_size.x - 152, viewport_size.y - 110)


# ══ 开战 ════════════════════════════════════════════════════

func _start_battle() -> void:
	_battle = BattleManager.new()
	add_child(_battle)
	_battle.log_message.connect(_on_log)
	_battle.battle_ended.connect(_on_battle_ended)
	_battle.phase_changed.connect(_on_phase_changed)
	_battle.potion_granted.connect(_on_potion_granted)

	_player = Player.new()
	_player.display_name = _character_display_name()
	_player.max_hp = _run.max_hp
	add_child(_player)

	_player_view = CombatActorView.new()
	_field.add_child(_player_view)

	var enemy_data := _build_enemy_data()
	var enemy := Enemy.new()
	enemy.setup_from_data(enemy_data)
	add_child(enemy)
	_enemies = [enemy]

	var enemy_view := CombatActorView.new()
	enemy_view.is_player_side = false
	enemy_view.card_dropped_on_actor.connect(_on_card_dropped)
	enemy_view.potion_dropped_on_actor.connect(_on_potion_dropped)
	_field.add_child(enemy_view)
	_enemy_views = [enemy_view]

	_battle.start_battle(_player, _enemies, _run.build_deck())

	# ⚠️ 下面全部必须在 start_battle **之后**——它内部会 reset_for_battle()
	_inject_identity_and_relics()
	_player.set_hp(_run.hp)
	enemy.apply_starting_powers()
	_assign_opponents()
	_player.notify_battle_start()
	enemy.notify_battle_start()

	_player_view.bind(_player, CombatActorView.Look.WARRIOR, true)
	enemy_view.bind(enemy, _look_for(enemy_data), false)

	_layout()
	_refresh_all()


func _look_for(data: EnemyData) -> CombatActorView.Look:
	if data.is_boss:
		return CombatActorView.Look.GOD
	if data.id == &"act1_combat" or data.id == &"act2_combat":
		return CombatActorView.Look.SLIME
	return CombatActorView.Look.BRUTE


func _build_enemy_data() -> EnemyData:
	var enemy_id := _node_enemy_id()
	var loaded: Variant = ContentRegistry.get_enemy(enemy_id)
	if loaded is EnemyData:
		return loaded as EnemyData

	push_warning("BattleScene: 找不到敌人配置「%s」，使用兜底敌人" % enemy_id)
	var data := EnemyData.new()
	data.id = &"fallback_enemy"
	data.display_name = "无名的拦路者"
	data.max_hp = 24
	var intents: Array[IntentData] = [IntentData.make_attack(7)]
	data.intents = intents
	return data


func _node_enemy_id() -> StringName:
	if GameState.map == null:
		return &""
	var node: MapNode = GameState.map.current_node()
	if node == null:
		return &""
	return StringName(str(node.payload.get("enemy_id", "")))


## 身份能力的源头是 GameState.identity_power_ids——每场战斗重新实例化注入
func _inject_identity_and_relics() -> void:
	_player.clear_identity_powers()
	for power_id: StringName in GameState.identity_power_ids:
		var power := IdentityPowers.create(power_id)
		if power != null:
			_player.apply_identity_power(power)

	_player.clear_relics()
	for relic_id: StringName in _run.relics:
		var relic := RelicFactory.create(relic_id)
		if relic != null:
			_player.add_relic(relic)


func _assign_opponents() -> void:
	var player_side: Array[Creature] = [_player]
	var enemy_side: Array[Creature] = []
	for enemy: Enemy in _enemies:
		enemy_side.append(enemy)

	_player.set_opponents(enemy_side)
	for enemy: Enemy in _enemies:
		enemy.set_opponents(player_side)


# ══ 刷新 ════════════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_hand()
	_refresh_piles()
	_refresh_energy()
	_hud.refresh()


func _refresh_hand() -> void:
	for child: Node in _hand_box.get_children():
		_hand_box.remove_child(child)
		child.queue_free()

	if _battle.deck == null:
		return

	var can_act: bool = _battle.flow.is_player_turn() and not _busy
	for card: CardData in _battle.deck.hand:
		var view := CardView.new()
		_hand_box.add_child(view)
		view.set_card(card)
		view.set_playable(can_act and _player.can_afford(card.cost))
		view.card_activated.connect(_on_card_double_clicked)


func _refresh_piles() -> void:
	if _battle.deck == null:
		return
	_draw_pile_label.text = "抽牌堆 %d" % _battle.deck.draw_pile.size()
	_discard_pile_label.text = "弃牌堆 %d" % _battle.deck.discard_pile.size()


func _refresh_energy() -> void:
	_energy_label.text = "能量 %d/%d" % [_player.energy, _player.max_energy]


func _show_banner(text: String) -> void:
	_turn_banner.text = text
	var tween := create_tween()
	tween.tween_property(_turn_banner, "modulate", Color(1, 1, 1, 1), 0.15)
	tween.tween_interval(0.7)
	tween.tween_property(_turn_banner, "modulate", Color(1, 1, 1, 0), 0.35)


# ══ 出牌 ════════════════════════════════════════════════════

## 双击出牌：默认打第一个存活敌人（用户要求）
func _on_card_double_clicked(card: CardData) -> void:
	_play_card_on(card, _battle.first_alive_enemy())


## 拖拽出牌：拖到哪个敌人身上就打哪个（用户要求）
func _on_card_dropped(card: CardData, actor: Creature) -> void:
	_play_card_on(card, actor)


func _play_card_on(card: CardData, target: Creature) -> void:
	if _busy or not _battle.flow.is_player_turn():
		return

	if target is Enemy:
		var target_index: int = _enemies.find(target as Enemy)
		if target_index >= 0:
			_player_view.play_attack()
			if target_index < _enemy_views.size():
				_enemy_views[target_index].play_hit()

	if not _battle.play_card(card, target):
		return

	_refresh_all()


func _on_end_turn_pressed() -> void:
	if _busy:
		return
	_battle.end_player_turn()
	_refresh_all()


# ══ 药水 ════════════════════════════════════════════════════

## 单击：**查看信息**，不消耗（用户要求）
func _on_potion_clicked(slot_index: int) -> void:
	if _busy or _overlay != null:
		return
	var potion: PotionData = _potion_at(slot_index)
	if potion == null:
		return

	var blocked: String = PotionResolver.can_use(
		potion, true, _battle.first_alive_enemy() != null)

	var panel := PotionInfoPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(potion, slot_index, blocked)
	panel.use_requested.connect(_on_potion_use_requested)
	panel.closed.connect(_close_overlay)


func _on_potion_use_requested(slot_index: int) -> void:
	_close_overlay()
	_use_potion(slot_index, _default_target_for(_potion_at(slot_index)))


## 双击：直接使用。**战斗式默认打第一个敌人**（用户要求）
func _on_potion_double_clicked(slot_index: int) -> void:
	if _busy:
		return
	var potion: PotionData = _potion_at(slot_index)
	if potion == null:
		return

	var blocked: String = PotionResolver.can_use(
		potion, true, _battle.first_alive_enemy() != null)
	if blocked != "":
		_on_log("（%s 现在用不了：%s）" % [potion.display_name, blocked])
		return

	_use_potion(slot_index, _default_target_for(potion))


## 拖到敌人身上：用那个敌人当目标（用户要求）
func _on_potion_dropped(slot_index: int, actor: Creature) -> void:
	if _busy:
		return
	_use_potion(slot_index, actor)


func _default_target_for(potion: PotionData) -> Creature:
	if potion == null:
		return null
	if potion.needs_enemy_target():
		return _battle.first_alive_enemy()
	return _player


func _potion_at(slot_index: int) -> PotionData:
	if slot_index < 0 or slot_index >= _run.potions.size():
		return null
	var loaded: Variant = ContentRegistry.get_potion(_run.potions[slot_index])
	if loaded is PotionData:
		return loaded as PotionData
	return null


func _use_potion(slot_index: int, target: Creature) -> void:
	var potion: PotionData = _potion_at(slot_index)
	if potion == null:
		return

	# 一次性资源：**先结算，成功了再扣**。失败不扣——
	# "用了没效果还把药水吃掉"是最不能忍的一类 bug。
	var result := PotionResolver.apply(
		potion, _player, target, _battle.deck, RandomNumberGenerator.new())

	if not result.success:
		_on_log("（%s 用不了：%s）" % [potion.display_name, result.message])
		return

	_run.remove_potion_at(slot_index)
	_on_log("使用 %s：%s" % [potion.display_name, result.message])

	if target is Enemy:
		var index: int = _enemies.find(target as Enemy)
		if index >= 0 and index < _enemy_views.size():
			_enemy_views[index].play_hit()

	_refresh_all()

	if result.needs_card_choice:
		_offer_potion_cards(result.offered_card_ids)


## 得牌类药水：从牌库展示 N 张，选一张加入手牌。
## 加入的是**临时牌**——它从未进过 `RunState.deck_card_ids`，
## 所以战斗结束自然消失，不需要任何清理代码。
func _offer_potion_cards(card_ids: Array[StringName]) -> void:
	var cards: Array[CardData] = []
	for card_id: StringName in card_ids:
		var loaded: Variant = ContentRegistry.get_card(card_id)
		if loaded is CardData:
			cards.append(loaded as CardData)

	if cards.is_empty():
		return

	var panel := CardChoicePanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup("选择一张加入手牌（战斗结束后消失）", cards)
	panel.card_chosen.connect(_on_potion_card_chosen)
	panel.cancelled.connect(_close_overlay)


func _on_potion_card_chosen(card_id: StringName) -> void:
	PotionResolver.grant_card_to_hand(card_id, _battle.deck)
	_close_overlay()
	_refresh_all()


## 卡牌给药水（如「力量药剂」）。药水栏满了就丢弃并**明确告诉玩家**——
## 静默丢弃是最容易让玩家以为"卡牌没生效"的处理方式。
func _on_potion_granted(potion_id: StringName) -> void:
	if _run.is_potion_bar_full():
		_on_log("药水栏已满，这瓶药水被丢弃了。")
		return
	_run.add_potion(potion_id)
	_hud.refresh()


# ══ BattleManager 回调 ══════════════════════════════════════

func _on_log(text: String) -> void:
	_log_lines.append(text)


func _on_phase_changed(next_phase: TurnFlow.Phase) -> void:
	if next_phase == TurnFlow.Phase.PLAYER_TURN:
		_show_banner("玩家回合")
	elif next_phase == TurnFlow.Phase.ENEMY_TURN:
		_show_banner("敌方回合")
	_refresh_all()


func _on_battle_ended(player_won: bool) -> void:
	# ⚠️ 遗物结算必须在同步血量**之前**——燃烧之血会在胜利时回血
	_player.notify_battle_end(player_won)
	_run.sync_from_creature(_player)
	_hud.refresh()

	if not player_won:
		_run.finish(false)
		SaveManager.delete_save()
		_go_to_game_over()
		return

	_busy = true
	var gold: int = _gold_reward()

	if _node_kind == MapNode.Kind.BOSS:
		_run.add_gold(gold)
		if _run.current_act >= MAX_ACTS:
			_run.finish(true)
			SaveManager.delete_save()
			_go_to_game_over()
			return
		_start_job_transfer()
		return

	_go_to_reward(gold)


## 普通战斗 → **独立的结算场景**（用户要求）。
## 奖励数据通过 GameState.pending_reward 跨场景传递，
## 真正的写回在结算场景点「前进」时一次性完成（D24）。
func _go_to_reward(gold: int) -> void:
	var bundle := RewardBundle.new()
	bundle.gold = gold
	bundle.potion_id = _roll_potion_drop()
	bundle.relic_id = _roll_relic_drop()
	for card: CardData in CardPool.new(RandomNumberGenerator.new()).roll():
		bundle.card_offer_ids.append(card.id)

	GameState.pending_reward = bundle.to_dict()
	_hud.set_time_running(false)
	get_tree().change_scene_to_file("res://scenes/ui/reward.tscn")


## 遗物掉落：精英必掉，普通战斗小概率。
## 已拥有的遗物不会再掉（RelicFactory.droppable_ids 负责过滤）。
func _roll_relic_drop() -> StringName:
	var chance: float = 1.0 if _node_kind == MapNode.Kind.ELITE else 0.18
	if randf() > chance:
		return &""

	var pool: Array[StringName] = RelicFactory.droppable_ids(_run.relics)
	if pool.is_empty():
		return &""
	return pool[randi_range(0, pool.size() - 1)]


func _gold_reward() -> int:
	match _node_kind:
		MapNode.Kind.ELITE:
			return GOLD_REWARD_ELITE
		MapNode.Kind.BOSS:
			return 0
		_:
			return GOLD_REWARD_COMBAT


func _roll_potion_drop() -> StringName:
	if randf() > POTION_DROP_CHANCE:
		return &""
	var pool: Array[StringName] = ContentRegistry.all_potion_ids()
	if pool.is_empty():
		return &""
	return pool[randi_range(0, pool.size() - 1)]


# ══ 战斗日志 ════════════════════════════════════════════════

## 完整日志收进可滑动面板（用户要求：不要挂在屏幕中间）
func _open_battle_log() -> void:
	if _overlay != null:
		return
	var panel := BattleLogPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(_log_lines)
	panel.closed.connect(_close_overlay)


# ══ 转职（第 1、2 幕 Boss 后固定触发）═══════════════════════

func _start_job_transfer() -> void:
	var jobs: Array[JobData] = _pending_jobs()
	if jobs.is_empty():
		_advance_act()
		return

	_job_panel = JobChoicePanel.new()
	_job_panel.setup("选择一条要刻进灵魂的规则", jobs)
	_job_panel.job_chosen.connect(_on_job_chosen)
	add_child(_job_panel)


func _pending_jobs() -> Array[JobData]:
	var transfers_done: int = GameState.job_path.size()
	if transfers_done == 0:
		return JobDatabase.first_tier_jobs(_run.character_class)
	if transfers_done == 1:
		return JobDatabase.final_jobs(GameState.job_path[0])
	var none: Array[JobData] = []
	return none


func _on_job_chosen(job_id: StringName) -> void:
	var job: JobData = JobDatabase.get_job(job_id)
	if job == null:
		return

	GameState.apply_job(job)
	if _job_panel != null:
		_job_panel.queue_free()
		_job_panel = null

	var offers: Array[CardData] = []
	for card_id: StringName in job.job_card_ids:
		var card: Variant = ContentRegistry.get_card(card_id)
		if card is CardData:
			offers.append(card as CardData)

	if offers.is_empty():
		_advance_act()
		return

	# 转职附赠只是"纯粹的选牌"，复用通用选牌面板即可
	var panel := CardChoicePanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup("转职附赠：选择一张职业牌加入牌组", offers, false)
	panel.card_chosen.connect(_on_job_card_chosen)


func _on_job_card_chosen(card_id: StringName) -> void:
	_run.add_card(card_id)
	_close_overlay()
	_advance_act()


func _advance_act() -> void:
	GameState.advance_act()
	_busy = false
	SaveManager.save_run(_run, GameState.map)
	_go_to_map()


# ══ 弹层 ════════════════════════════════════════════════════

func _open_deck() -> void:
	if _overlay != null:
		return
	var panel := DeckViewPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(_run.build_deck())
	panel.closed.connect(_close_overlay)


func _open_relics() -> void:
	if _overlay != null:
		return
	var panel := RelicViewPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup(_run.relics)
	panel.closed.connect(_close_overlay)


func _open_settings() -> void:
	if _overlay != null:
		return
	var panel := SettingsPanel.new()
	_overlay = panel
	add_child(panel)
	panel.setup()
	panel.closed.connect(_close_overlay)
	panel.return_to_title_pressed.connect(_return_to_title)
	panel.quit_pressed.connect(func() -> void: get_tree().quit())


## 战斗中查看地图：**只读**——能看但点不了节点（用户要求）
func _open_map_overlay() -> void:
	if _overlay != null or GameState.map == null:
		return

	var panel := OverlayPanel.new()
	_overlay = panel
	panel.frame_min_width = 660
	add_child(panel)

	var map_view := MapView.new()
	map_view.custom_minimum_size = Vector2(600, 380)
	map_view.size = Vector2(600, 380)
	# 战斗中只读：把交互整个吃掉
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.content_box.add_child(map_view)
	map_view.build_map(GameState.map)

	var hint := Label.new()
	hint.text = "战斗中只能查看地图，无法选择节点。"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	panel.content_box.add_child(hint)

	panel.add_button("返回战斗（ESC）", _close_overlay)
	panel.closed.connect(_close_overlay)


func _close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


# ══ 导航 ════════════════════════════════════════════════════

func _go_to_map() -> void:
	_hud.set_time_running(false)
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")


func _go_to_game_over() -> void:
	_hud.set_time_running(false)
	get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")


func _return_to_title() -> void:
	SaveManager.save_run(_run, GameState.map)
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
