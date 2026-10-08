class_name PotionSlot
extends Control
## 药水栏槽位：**单击看信息 / 双击使用 / 拖到敌人身上使用**
##
## ## 为什么不用 Button
## 需要同时支持三种交互。Button 的 `pressed` 会把单击吃掉，
## 双击与拖拽要跟它抢事件，协调起来很别扭。自己画 + 自己处理 `_gui_input`
## 反而更简单，而且能完全控制视觉。
##
## ## 拖拽载荷用字典而不是 PotionData
## `ContentRegistry` 里的药水是**全局共享实例**——两瓶同名药水拿到的是同一个对象。
## 用对象本身做载荷，就没法区分"拖的是第几格"。所以载荷带 **槽位下标**。

signal slot_clicked(slot_index: int)
signal slot_double_clicked(slot_index: int)

## 拖拽载荷的键。CombatActorView 用它识别"这是药水，不是卡牌"
const DRAG_KEY: String = "__potion_slot"

const SLOT_SIZE: float = 30.0

var slot_index: int = -1
var potion: PotionData = null

## 药水图标节点（阶段 8）。
##
## ⚠️ **必须用节点，不能在 `_draw()` 里 `draw_texture_rect`**——
## D35：本项目里 `_draw()` 画贴图会渲染成**纯白方块**
## （资源、算式、尺寸全对，换 TextureRect 节点立刻正常）。
## 立绘（D35）与卡图都踩过同一个坑。
var _icon: TextureRect = null


func _ready() -> void:
	custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	size = Vector2(SLOT_SIZE, SLOT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.visible = false
	add_child(_icon)


func set_potion(data: PotionData, index: int) -> void:
	potion = data
	slot_index = index
	tooltip_text = data.description if data != null else "空药水栏"
	_refresh_icon()
	queue_redraw()


## 图标可见性：**有图显示图标，缺图回退到 `_draw()` 的首字**。
## 两者并存不冲突，所以 10 张药水图标可以分批投。
func _refresh_icon() -> void:
	if _icon == null:
		return
	var tex: Texture2D = null
	if potion != null:
		tex = ContentRegistry.get_potion_icon(potion.id)
	_icon.texture = tex
	_icon.visible = tex != null
	if tex != null:
		var s: float = SLOT_SIZE - 8.0
		_icon.size = Vector2(s, s)
		_icon.position = (Vector2(SLOT_SIZE, SLOT_SIZE) - Vector2(s, s)) * 0.5


func _draw() -> void:
	var center := Vector2(SLOT_SIZE, SLOT_SIZE) * 0.5
	var radius := SLOT_SIZE * 0.5 - 1.0
	var filled: bool = potion != null

	draw_circle(center, radius, UiPalette.POTION.darkened(0.45) if filled else UiPalette.BG_SLOT)
	draw_arc(center, radius, 0.0, TAU, 32,
		UiPalette.POTION if filled else UiPalette.BORDER_DIM, 1.5)

	if not filled:
		return

	# 有图标时由子节点画，这里不再叠首字（否则字会压在图标上）
	if _icon != null and _icon.visible:
		return

	var font := ThemeDB.fallback_font
	if font == null:
		return
	var text := potion.display_name.substr(0, 1)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(font, center - text_size * 0.5 + Vector2(0, 5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiPalette.TEXT)


func _gui_input(event: InputEvent) -> void:
	if potion == null:
		return

	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return

	accept_event()
	if mouse.double_click:
		slot_double_clicked.emit(slot_index)
	else:
		slot_clicked.emit(slot_index)


## 拖到敌人身上使用（战斗式药水）。通用式药水拖拽无意义，但这里不拦——
## 拦了反而让玩家以为"这瓶不能拖"，统一交给场景判断更清楚。
func _get_drag_data(_at_position: Vector2) -> Variant:
	if potion == null:
		return null

	var preview := Label.new()
	preview.text = "  %s  " % potion.display_name
	preview.add_theme_color_override("font_color", UiPalette.POTION)
	preview.add_theme_font_size_override("font_size", 15)
	set_drag_preview(preview)

	return {DRAG_KEY: slot_index}
