class_name BattleBackground
extends Control
## 战斗背景：**按幕绘制不同场景**（阶段 6）
##
## ## 背景不只是装饰
## 它告诉玩家「我现在在哪张图上」——而幕环境机制正是绑定在「图」上的。
## 纯黑背景会让三幕看起来完全一样，玩家也就感受不到"我推进到下一幕了"。
##
## ## 无美术资源
## 用 `_draw()` 程序生成：天空色带 + 地面 + 每幕特有的剪影道具。
## 阶段 8 接真图时把 [method _draw] 换成 TextureRect 即可，不用动别的。

## 每幕的配色与道具风格
const ACT_THEMES: Dictionary = {
	1: {  # 竞技场：暖沙 + 看台 + 火把
		"sky_top": Color(0.24, 0.18, 0.14),
		"sky_bottom": Color(0.42, 0.32, 0.2),
		"ground": Color(0.5, 0.4, 0.26),
		"accent": Color(0.85, 0.62, 0.3),
		"prop": "stands",
	},
	2: {  # 战场：灰天 + 焦土 + 旌旗
		"sky_top": Color(0.16, 0.15, 0.17),
		"sky_bottom": Color(0.32, 0.24, 0.22),
		"ground": Color(0.3, 0.24, 0.2),
		"accent": Color(0.7, 0.3, 0.26),
		"prop": "banners",
	},
	3: {  # 古战场：幽绿雾 + 残柱
		"sky_top": Color(0.1, 0.13, 0.15),
		"sky_bottom": Color(0.18, 0.26, 0.26),
		"ground": Color(0.2, 0.24, 0.22),
		"accent": Color(0.4, 0.72, 0.62),
		"prop": "ruins",
	},
}

const SKY_BANDS: int = 14
const GROUND_RATIO: float = 0.62

var _act: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠️ **不要**用 `set_anchors_preset(PRESET_FULL_RECT)` 来撑满。
	# 本控件的父节点是**普通 Node**（不是 Control），锚点算出来的父区域在
	# `_ready` 那一刻可能是 0×0，于是 size 停在 (0,0)、`_draw()` 直接 return——
	# 表现就是"背景根本没画"，而且**不报任何错**。
	# 改成由场景的 `_layout()` 显式设 position/size（与 MapView 同一套做法）。
	resized.connect(queue_redraw)


func set_act(act: int) -> void:
	_act = act
	queue_redraw()


func _theme() -> Dictionary:
	return ACT_THEMES.get(_act, ACT_THEMES[1]) as Dictionary


## 实际绘制区域。size 退化时回退到视口尺寸——
## 背景是整屏元素，"画大一点"永远比"什么都没画"好。
func _draw_rect_area() -> Rect2:
	if size.x > 1.0 and size.y > 1.0:
		return Rect2(Vector2.ZERO, size)
	var viewport_size: Vector2 = get_viewport_rect().size
	return Rect2(Vector2.ZERO, viewport_size)


func _draw() -> void:
	var area := _draw_rect_area()
	if area.size.x <= 1.0 or area.size.y <= 1.0:
		return

	var theme: Dictionary = _theme()
	var ground_y: float = area.size.y * GROUND_RATIO

	_draw_sky(theme, area, ground_y)
	_draw_ground(theme, area, ground_y)

	match str(theme["prop"]):
		"stands":
			_draw_stands(theme, area, ground_y)
		"banners":
			_draw_banners(theme, area, ground_y)
		"ruins":
			_draw_ruins(theme, area, ground_y)


## 天空：用色带模拟渐变（比真渐变便宜，而且更有"像素画"的粗粝感）
func _draw_sky(theme: Dictionary, area: Rect2, ground_y: float) -> void:
	var top: Color = theme["sky_top"]
	var bottom: Color = theme["sky_bottom"]
	var band_height: float = ground_y / float(SKY_BANDS)

	for i: int in SKY_BANDS:
		var t: float = float(i) / float(SKY_BANDS - 1)
		draw_rect(
			Rect2(area.position.x, area.position.y + float(i) * band_height,
				area.size.x, band_height + 1.0),
			top.lerp(bottom, t), true)


func _draw_ground(theme: Dictionary, area: Rect2, ground_y: float) -> void:
	var ground: Color = theme["ground"]
	draw_rect(Rect2(area.position.x, area.position.y + ground_y,
		area.size.x, area.size.y - ground_y), ground, true)

	# 地面上的横向纹理，避免一大块纯色
	var accent: Color = theme["accent"]
	for i: int in 9:
		var y: float = area.position.y + ground_y + (area.size.y - ground_y) * (float(i) / 9.0)
		draw_line(Vector2(area.position.x, y), Vector2(area.position.x + area.size.x, y),
			accent.darkened(0.5), 1.0)


## 竞技场：两侧看台 + 火把
func _draw_stands(theme: Dictionary, area: Rect2, ground_y: float) -> void:
	var accent: Color = theme["accent"]
	var stand_width: float = area.size.x * 0.18
	var base_y: float = area.position.y + ground_y

	for side: int in 2:
		var x: float = area.position.x if side == 0 else area.position.x + area.size.x - stand_width
		for tier: int in 5:
			var tier_y: float = base_y - 26.0 - float(tier) * 26.0
			var inset: float = float(tier) * 6.0
			draw_rect(Rect2(x + inset, tier_y, stand_width - inset * 2.0, 22.0),
				accent.darkened(0.62), true)
			draw_rect(Rect2(x + inset, tier_y, stand_width - inset * 2.0, 22.0),
				accent.darkened(0.3), false, 1.0)

	for i: int in 6:
		var fx: float = area.position.x + area.size.x * (0.08 + 0.84 * float(i) / 5.0)
		var fy: float = base_y - 34.0
		draw_circle(Vector2(fx, fy), 5.0, Color(1.0, 0.72, 0.32, 0.5))
		draw_circle(Vector2(fx, fy), 2.5, Color(1.0, 0.88, 0.55))


## 战场：插在地上的旌旗
func _draw_banners(theme: Dictionary, area: Rect2, ground_y: float) -> void:
	var accent: Color = theme["accent"]
	var base_y: float = area.position.y + ground_y

	for i: int in 7:
		var bx: float = area.position.x + area.size.x * (0.06 + 0.88 * float(i) / 6.0)
		var height: float = 54.0 + float(i % 3) * 16.0
		draw_line(Vector2(bx, base_y), Vector2(bx, base_y - height),
			Color(0.24, 0.2, 0.18), 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx + 2.0, base_y - height),
			Vector2(bx + 26.0, base_y - height + 10.0),
			Vector2(bx + 2.0, base_y - height + 22.0),
		]), accent.darkened(0.2))


## 古战场：断裂的石柱 + 幽绿雾
func _draw_ruins(theme: Dictionary, area: Rect2, ground_y: float) -> void:
	var accent: Color = theme["accent"]
	var base_y: float = area.position.y + ground_y

	for i: int in 5:
		var cx: float = area.position.x + area.size.x * (0.12 + 0.76 * float(i) / 4.0)
		var height: float = 60.0 + float(i % 2) * 40.0
		draw_rect(Rect2(cx, base_y - height, 22.0, height), accent.darkened(0.68), true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, base_y - height),
			Vector2(cx + 22.0, base_y - height),
			Vector2(cx + 14.0, base_y - height - 12.0),
		]), accent.darkened(0.68))

	draw_rect(Rect2(area.position.x, base_y - 30.0, area.size.x, 30.0),
		Color(accent.r, accent.g, accent.b, 0.12), true)
