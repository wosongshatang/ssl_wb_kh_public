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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func set_act(act: int) -> void:
	_act = act
	queue_redraw()


func _theme() -> Dictionary:
	return ACT_THEMES.get(_act, ACT_THEMES[1]) as Dictionary


func _draw() -> void:
	var size_now := size
	if size_now.x <= 1.0 or size_now.y <= 1.0:
		return

	var theme: Dictionary = _theme()
	var ground_y: float = size_now.y * GROUND_RATIO

	_draw_sky(theme, ground_y)
	_draw_ground(theme, ground_y)

	match str(theme["prop"]):
		"stands":
			_draw_stands(theme, ground_y)
		"banners":
			_draw_banners(theme, ground_y)
		"ruins":
			_draw_ruins(theme, ground_y)


## 天空：用色带模拟渐变（比真渐变便宜，而且更有"像素画"的粗粝感）
func _draw_sky(theme: Dictionary, ground_y: float) -> void:
	var top: Color = theme["sky_top"]
	var bottom: Color = theme["sky_bottom"]
	var band_height: float = ground_y / float(SKY_BANDS)

	for i: int in SKY_BANDS:
		var t: float = float(i) / float(SKY_BANDS - 1)
		draw_rect(
			Rect2(0.0, float(i) * band_height, size.x, band_height + 1.0),
			top.lerp(bottom, t), true)


func _draw_ground(theme: Dictionary, ground_y: float) -> void:
	var ground: Color = theme["ground"]
	draw_rect(Rect2(0.0, ground_y, size.x, size.y - ground_y), ground, true)

	# 地面上的横向纹理，避免一大块纯色
	var accent: Color = theme["accent"]
	for i: int in 9:
		var y: float = ground_y + (size.y - ground_y) * (float(i) / 9.0)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), accent.darkened(0.5), 1.0)


## 竞技场：两侧看台 + 火把
func _draw_stands(theme: Dictionary, ground_y: float) -> void:
	var accent: Color = theme["accent"]
	var stand_width: float = size.x * 0.18

	for side: int in 2:
		var x: float = 0.0 if side == 0 else size.x - stand_width
		# 看台阶梯
		for tier: int in 5:
			var tier_y: float = ground_y - 26.0 - float(tier) * 26.0
			var inset: float = float(tier) * 6.0
			draw_rect(Rect2(x + inset, tier_y, stand_width - inset * 2.0, 22.0),
				accent.darkened(0.62), true)
			draw_rect(Rect2(x + inset, tier_y, stand_width - inset * 2.0, 22.0),
				accent.darkened(0.3), false, 1.0)

	# 火把光点
	for i: int in 6:
		var fx: float = size.x * (0.08 + 0.84 * float(i) / 5.0)
		var fy: float = ground_y - 34.0
		draw_circle(Vector2(fx, fy), 5.0, Color(1.0, 0.72, 0.32, 0.5))
		draw_circle(Vector2(fx, fy), 2.5, Color(1.0, 0.88, 0.55))


## 战场：插在地上的旌旗
func _draw_banners(theme: Dictionary, ground_y: float) -> void:
	var accent: Color = theme["accent"]
	for i: int in 7:
		var bx: float = size.x * (0.06 + 0.88 * float(i) / 6.0)
		var height: float = 54.0 + float(i % 3) * 16.0
		draw_line(Vector2(bx, ground_y), Vector2(bx, ground_y - height),
			Color(0.24, 0.2, 0.18), 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx + 2.0, ground_y - height),
			Vector2(bx + 26.0, ground_y - height + 10.0),
			Vector2(bx + 2.0, ground_y - height + 22.0),
		]), accent.darkened(0.2))


## 古战场：断裂的石柱 + 幽绿雾
func _draw_ruins(theme: Dictionary, ground_y: float) -> void:
	var accent: Color = theme["accent"]
	for i: int in 5:
		var cx: float = size.x * (0.12 + 0.76 * float(i) / 4.0)
		var height: float = 60.0 + float(i % 2) * 40.0
		draw_rect(Rect2(cx, ground_y - height, 22.0, height),
			accent.darkened(0.68), true)
		# 断口
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, ground_y - height),
			Vector2(cx + 22.0, ground_y - height),
			Vector2(cx + 14.0, ground_y - height - 12.0),
		]), accent.darkened(0.68))

	# 低垂的雾
	draw_rect(Rect2(0.0, ground_y - 30.0, size.x, 30.0),
		Color(accent.r, accent.g, accent.b, 0.12), true)
