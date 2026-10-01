class_name CombatActorView
extends Control
## 战斗单位视图：立绘 + 名字 + 血条 + 格挡徽标 + 状态图标
##
## ## 铁律：视图不参与任何数值计算
## 它只**订阅** [Creature] 的信号来刷新。这样"数值改了但界面没变"
## 这类 bug 在结构上不可能发生——而不是靠每个改数值的地方记得调 `refresh()`。
##
## ## 立绘
## 阶段 5 无美术资源，用 `_draw()` 程序生成的几何图形占位（战士 / 史莱姆 / 神）。
## 阶段 8 接真图时把 [method _draw] 换成 TextureRect 即可，动画逻辑不用动。
##
## ## 位置
## ⚠️ 本控件**必须放在非容器父节点下**（绝对定位），否则 Tween 改 `position`
## 会被容器的布局系统立刻覆盖，动画看起来"没生效"。

## 玩家把牌拖到本单位身上释放
signal card_dropped_on_actor(card: CardData, actor: Creature)
## 玩家把药水拖到本单位身上使用（战斗式药水）
signal potion_dropped_on_actor(slot_index: int, actor: Creature)
## 点击状态图标 → 查看状态详情
signal status_pressed(actor: Creature)

const VIEW_SIZE := Vector2(168, 214)
const BODY_HEIGHT := 128.0
const BAR_HEIGHT := 12.0
const LUNGE_DISTANCE := 26.0

enum Look {
	WARRIOR,   ## 战士（玩家）
	SLIME,     ## 软泥类
	BRUTE,     ## 人形敌人
	GOD,       ## 神（Boss）
}

var creature: Creature = null
var look: Look = Look.WARRIOR
var is_player_side: bool = true

var _name_label: Label
var _status_box: HBoxContainer
## 受击闪白的强度（0 = 正常）
var _flash: float = 0.0


func _ready() -> void:
	custom_minimum_size = VIEW_SIZE
	size = VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_labels()


func _build_labels() -> void:
	_name_label = Label.new()
	_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_name_label.position = Vector2(0, BODY_HEIGHT + BAR_HEIGHT + 8)
	_name_label.size = Vector2(VIEW_SIZE.x, 18)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", UiPalette.TEXT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	_status_box = HBoxContainer.new()
	_status_box.position = Vector2(0, BODY_HEIGHT + BAR_HEIGHT + 28)
	_status_box.size = Vector2(VIEW_SIZE.x, 20)
	_status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_box.add_theme_constant_override("separation", 4)
	_status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_box)


## 绑定战斗单位并订阅其信号
func bind(target: Creature, look_kind: Look = Look.WARRIOR, player_side: bool = true) -> void:
	creature = target
	look = look_kind
	is_player_side = player_side

	target.health_changed.connect(_on_any_change)
	target.block_changed.connect(_on_any_change)
	target.power_added.connect(_on_powers_changed)
	target.power_removed.connect(_on_powers_changed)
	target.health_lost.connect(_on_health_lost)
	target.block_gained.connect(_on_block_gained)

	_name_label.text = target.display_name
	_refresh_powers()
	queue_redraw()


func _on_any_change(_a: int = 0, _b: int = 0) -> void:
	queue_redraw()


func _on_powers_changed(_power: AbstractPower) -> void:
	_refresh_powers()
	queue_redraw()


func _on_health_lost(amount: int) -> void:
	play_hit()
	show_floating_text("-%d" % amount, UiPalette.HP_RED)


func _on_block_gained(amount: int) -> void:
	if amount <= 0:
		return
	play_block_gain()
	show_floating_text("+%d 格挡" % amount, UiPalette.BLOCK_BLUE)


## 飘字：伤害 / 格挡数字从身上冒出来然后淡出。
##
## 为什么需要它：日志挂在屏幕中间时，玩家要看伤害得把视线从敌人身上移开。
## 飘字把反馈**放在事件发生的位置**，这是"手感"里最便宜也最有效的一环。
func show_floating_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(VIEW_SIZE.x * 0.5 - 14, BODY_HEIGHT * 0.25)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 44.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


# ══ 动画 ════════════════════════════════════════════════════

## 攻击前冲（方向由站位决定：玩家向右冲，敌人向左冲）
func play_attack() -> void:
	var direction: float = 1.0 if is_player_side else -1.0
	var origin: Vector2 = position
	var tween := create_tween()
	tween.tween_property(self, "position", origin + Vector2(direction * LUNGE_DISTANCE, 0), 0.1)
	tween.tween_property(self, "position", origin, 0.16)


## 受击：闪白 + 抖动
func play_hit() -> void:
	var origin: Vector2 = position
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(2.2, 0.75, 0.75), 0.04)
	tween.tween_property(self, "position", origin + Vector2(7, 0), 0.04)
	tween.chain().tween_property(self, "position", origin - Vector2(5, 0), 0.05)
	tween.chain().tween_property(self, "position", origin, 0.06)
	tween.chain().tween_property(self, "modulate", Color.WHITE, 0.12)


## 格挡获得：蓝色脉冲
func play_block_gain() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.7, 0.85, 1.3), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.18)


## 死亡：倒下 + 淡出（不销毁节点——战斗日志还要引用它）
func play_death() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(0.5, 0.5, 0.5, 0.25), 0.4)
	tween.tween_property(self, "rotation", -0.5 if is_player_side else 0.5, 0.4)


# ══ 绘制 ════════════════════════════════════════════════════

func _draw() -> void:
	if creature == null:
		return

	_draw_body()
	_draw_hp_bar()


func _draw_body() -> void:
	var body_rect := Rect2(Vector2(0, 0), Vector2(VIEW_SIZE.x, BODY_HEIGHT))
	var center := Vector2(VIEW_SIZE.x * 0.5, BODY_HEIGHT * 0.55)

	if not creature.is_alive():
		# 死亡后只留一个暗影轮廓，不再画细节
		draw_rect(Rect2(center - Vector2(30, 30), Vector2(60, 60)),
			Color(0.2, 0.2, 0.24, 0.5), true)
		return

	match look:
		Look.WARRIOR:
			_draw_humanoid(center, Color(0.62, 0.52, 0.4), Color(0.35, 0.38, 0.45))
		Look.SLIME:
			_draw_slime(center, Color(0.35, 0.62, 0.55))
		Look.BRUTE:
			_draw_humanoid(center, Color(0.5, 0.35, 0.35), Color(0.3, 0.25, 0.3))
		Look.GOD:
			_draw_god(center)


## 人形：躯干 + 头 + 武器（战士有剑，蛮兵有锤）
func _draw_humanoid(center: Vector2, skin: Color, armor: Color) -> void:
	var facing: float = 1.0 if is_player_side else -1.0
	# 腿
	draw_rect(Rect2(center + Vector2(-13, 24), Vector2(10, 34)), armor.darkened(0.2), true)
	draw_rect(Rect2(center + Vector2(3, 24), Vector2(10, 34)), armor.darkened(0.2), true)
	# 躯干
	draw_rect(Rect2(center + Vector2(-16, -14), Vector2(32, 42)), armor, true)
	# 头
	draw_circle(center + Vector2(0, -26), 13.0, skin)
	# 武器（朝面向方向）
	var weapon_origin := center + Vector2(facing * 18, -6)
	draw_line(weapon_origin, weapon_origin + Vector2(facing * 6, -44), Color(0.82, 0.84, 0.88), 4.0)


## 软泥：一坨带高光的椭圆 + 两只眼
func _draw_slime(center: Vector2, body: Color) -> void:
	draw_circle(center + Vector2(0, 8), 30.0, body)
	draw_circle(center + Vector2(0, 20), 22.0, body.darkened(0.15))
	draw_circle(center + Vector2(-9, -2), 4.0, Color(0.95, 0.95, 0.9))
	draw_circle(center + Vector2(9, -2), 4.0, Color(0.95, 0.95, 0.9))
	draw_circle(center + Vector2(-9, -2), 2.0, Color(0.1, 0.1, 0.1))
	draw_circle(center + Vector2(9, -2), 2.0, Color(0.1, 0.1, 0.1))


## 神：高大人形 + 光环 + 权杖
func _draw_god(center: Vector2) -> void:
	var facing: float = 1.0 if is_player_side else -1.0
	draw_arc(center + Vector2(0, -34), 34.0, 0.0, TAU, 48, Color(0.95, 0.85, 0.5, 0.55), 3.0)
	draw_rect(Rect2(center + Vector2(-20, -6), Vector2(40, 52)), Color(0.32, 0.28, 0.4), true)
	draw_circle(center + Vector2(0, -30), 15.0, Color(0.78, 0.72, 0.62))
	var staff := center + Vector2(facing * 26, 4)
	draw_line(staff, staff + Vector2(facing * 4, -58), Color(0.9, 0.8, 0.5), 4.0)
	draw_circle(staff + Vector2(facing * 4, -58), 6.0, Color(1.0, 0.9, 0.55))


## 血条：格挡徽标 + 血量条 + 数值
func _draw_hp_bar() -> void:
	var bar_rect := Rect2(Vector2(16, BODY_HEIGHT), Vector2(VIEW_SIZE.x - 32, BAR_HEIGHT))
	draw_rect(bar_rect, Color(0.12, 0.1, 0.12), true)

	if creature.max_hp > 0:
		var ratio: float = clampf(float(creature.hp) / float(creature.max_hp), 0.0, 1.0)
		var fill := Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y))
		draw_rect(fill, UiPalette.hp_color(creature.hp, creature.max_hp), true)

	draw_rect(bar_rect, UiPalette.BORDER_DIM, false, 1.0)

	# 血量数值（画在条内右侧）
	var font := ThemeDB.fallback_font
	if font != null:
		var text := "%d/%d" % [creature.hp, creature.max_hp]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_string(font,
			bar_rect.position + Vector2(bar_rect.size.x - text_size.x - 4, BAR_HEIGHT - 2),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiPalette.TEXT)

	# 格挡徽标（血条左侧）
	if creature.block > 0:
		var badge_center := Vector2(bar_rect.position.x - 14, bar_rect.position.y + BAR_HEIGHT * 0.5)
		draw_circle(badge_center, 13.0, UiPalette.BLOCK_BLUE)
		draw_circle(badge_center, 13.0, Color(0.9, 0.95, 1.0, 0.7), false, 1.5)
		if font != null:
			var block_text := str(creature.block)
			var bs := font.get_string_size(block_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			draw_string(font, badge_center - bs * 0.5 + Vector2(0, 5),
				block_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


## 状态图标：每个 Power 一个小色片（名字首字 + 层数），**可点击查看详情**。
##
## 用户反馈：拿到敏捷后看到 `敏2` 完全不知道它在做什么。
## 只显示首字 + 层数就必然需要一条"点开看解释"的路径。
func _refresh_powers() -> void:
	for child: Node in _status_box.get_children():
		_status_box.remove_child(child)
		child.queue_free()

	if creature == null:
		return

	for power: AbstractPower in creature.all_powers():
		var chip := Button.new()
		var label_text: String = power.display_name.substr(0, 1)
		if power.amount > 0:
			label_text += str(power.amount)
		chip.text = label_text
		chip.focus_mode = Control.FOCUS_NONE
		chip.tooltip_text = "%s（%d）\n%s" % [power.display_name, power.amount, power.description]
		chip.add_theme_font_size_override("font_size", 10)
		chip.add_theme_color_override("font_color", Color.WHITE)

		var style := StyleBoxFlat.new()
		style.bg_color = UiPalette.GOLD.darkened(0.35) if power.is_identity else UiPalette.TINT_POWER
		style.set_corner_radius_all(3)
		style.content_margin_left = 4
		style.content_margin_right = 4
		chip.add_theme_stylebox_override("normal", style)
		chip.add_theme_stylebox_override("hover", style)
		chip.add_theme_stylebox_override("pressed", style)

		chip.pressed.connect(_on_status_chip_pressed)
		_status_box.add_child(chip)


func _on_status_chip_pressed() -> void:
	if creature != null:
		status_pressed.emit(creature)


# ══ 卡牌投放目标 ════════════════════════════════════════════

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if creature == null or not creature.is_alive():
		return false
	if data is CardData:
		return true
	return _is_potion_payload(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is CardData:
		card_dropped_on_actor.emit(data as CardData, creature)
		return
	if _is_potion_payload(data):
		potion_dropped_on_actor.emit(int((data as Dictionary)[PotionSlot.DRAG_KEY]), creature)


## 药水拖拽载荷是 `{槽位下标: int}` 的字典，不是 PotionData——
## 因为注册表里的药水是共享实例，用对象没法区分"拖的是第几格"。
func _is_potion_payload(data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(PotionSlot.DRAG_KEY)
