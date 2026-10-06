class_name BattleBackground
extends Control
## 战斗背景：**按「角色线 + 幕」绘制不同场景**（阶段 6 程序化 → 阶段 8 接真图）
##
## ## 背景不只是装饰
## 它告诉玩家「我现在在哪张图上」——而幕环境机制正是绑定在「图」上的。
## 纯黑背景会让三幕看起来完全一样，玩家也就感受不到"我推进到下一幕了"。
##
## ## 两层：真图优先，程序化兜底
## - `assets/backgrounds/<角色>_act<幕>.png` 存在 → 画真图（[member _image] 节点）
## - 不存在 → 回退 `_draw()` 程序生成（天空色带 + 地面 + 剪影道具）
##
## 这样**美术可以分批到位**：九张图做了一张就先亮一张，
## 其余六张继续用程序化背景，**不会出现黑屏或空白**。
##
## ## ⚠️ 真图必须用节点画，不能用 `_draw()`（D35）
## `draw_texture_rect*` 在本项目 `gl_compatibility` + Intel 驱动下，
## 于 BattleScene 里画大图会**整块渲染成纯白**（孤立场景却正常）。
## 所以真图走 [TextureRect] 节点——这也是本类保留 `_draw()` 只做程序化的原因。

## 每幕的配色与道具风格（**程序化兜底用**；有真图时不参与绘制）
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

## 每张背景图里「可站立地面」从图高的百分之几开始（0~1）。
##
## ## 为什么需要这张表
## 角色站在**固定的屏幕高度**（见 [constant GROUND_LINE_MAX]），
## 而每张图的地面线高低不同。地面线若跑到角色脚底**下面**，
## 角色就**浮在半空**——而且这不会报任何错，只是"看着不对"。
##
## ## 值是怎么来的
## **量出来的**，不是拍脑袋：逐行算平均亮度，从底部往上找
## "亮度骤升"的行（近景地面 → 雾/天的分界）。
## 换图之后要重新量——所以新增背景时别忘了补一行。
const BACKGROUND_GROUND_RATIO: Dictionary = {
	"warrior_act1": 0.337,  # 竞技场：沙地起步早，地面线偏高（无需调整）
	"mage_act2": 0.741,     # 元素裂隙：石台只占底部 26%，**必须放大裁切**
	"hunter_act3": 0.500,   # 万兽冢：沼泽过渡平缓，取目测值
}
## 表里没有的图用这个（与程序化背景的 [constant GROUND_RATIO] 保持一致）
const DEFAULT_GROUND_RATIO: float = 0.62

## 地面线**最多**落在视口高度的百分之几。
##
## 角色脚底约在 **0.48**（battle_scene 的 `ACTOR_Y_RATIO` 算出来是 y≈346/720）。
## 取 0.44 而不是 0.48：要让地面线**高于**脚底，
## 角色才像"站在场景里"，而不是"站在地平线上"。
const GROUND_LINE_MAX: float = 0.44

## 放大倍数超过它就在日志里告警。
## 超过说明这张图的构图**不适合当战斗背景**（地面太少），正解是**重生成**，
## 而不是靠放大硬凑——放大是有画质代价的。
const UPSCALE_WARN: float = 1.25

var _character: StringName = &""
var _act: int = 1
## 真背景图节点。没有对应 PNG 时隐藏，露出 `_draw()` 的程序化背景。
var _image: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ⚠️ **不要**用 `set_anchors_preset(PRESET_FULL_RECT)` 来撑满。
	# 本控件的父节点是**普通 Node**（不是 Control），锚点算出来的父区域在
	# `_ready` 那一刻可能是 0×0，于是 size 停在 (0,0)、`_draw()` 直接 return——
	# 表现就是"背景根本没画"，而且**不报任何错**。
	# 改成由场景的 `_layout()` 显式设 position/size（与 MapView 同一套做法）。
	resized.connect(queue_redraw)

	# 真图节点**第一个加**——同层级下先加的在下层。
	# 背景是整屏最底层元素，不能盖住任何东西。
	_image = TextureRect.new()
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# COVERED：等比铺满。图已在 `_crop_to_viewport_aspect()` 里裁成视口比例，
	# 所以这里其实是"正好铺满"，不会再有裁切。
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# ⚠️ 必须 IGNORE：背景若吃掉鼠标事件，整个战斗界面的点击都会失效
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.visible = false
	add_child(_image)

	# ⚠️ 补一次刷新：`set_scene()` 可能在 `_ready()` **之前**被调用
	# （先 `new()` → `set_scene()` → 再 `add_child()`）。
	# 那种顺序下 `_image` 还是 null，图就永远贴不上——
	# 而这类"生命周期顺序"的 bug **不报任何错**（同 CardView 的教训）。
	_refresh_image()


## 设置当前场景（角色线 + 幕）。**两者都要**——同一个「第 1 幕」，
## 战士在竞技场、法师在学徒白塔、猎人在翠林猎场，是三个完全不同的地方。
func set_scene(character: StringName, act: int) -> void:
	_character = character
	_act = act
	_refresh_image()
	queue_redraw()


## 贴真图 / 藏起来让程序化背景接管。**两者互斥**。
func _refresh_image() -> void:
	if _image == null:
		return
	var texture: Texture2D = ContentRegistry.get_battle_background(_character, _act)
	if texture == null:
		_image.texture = null
		_image.visible = false
		return

	# 放大过多 = 这张图地面太少，靠放大硬凑。**正解是重生成**。
	# 用 push_warning 而不是 push_error：能玩，只是不好看（D15）。
	var factor: float = _upscale_factor(texture)
	if factor > UPSCALE_WARN:
		push_warning("BattleBackground: %s 为对齐地面被放大 %.2f×，构图可能不适合当战斗背景（建议重生成：地面应占下半部）"
			% [_background_key(), factor])

	_image.texture = _crop_to_viewport_aspect(texture)
	_image.visible = true


## 把背景图裁成**视口比例**，并把**地面线对齐到角色脚下**。
##
## ## 两步
## 1. **贴底**：窗口贴在图片底部——这样地面一定在框内（"从顶部裁"的另一种说法）。
## 2. **对齐**：若地面线落在 [constant GROUND_LINE_MAX] 之下（角色会浮空），
##    就缩小窗口（=放大）把它顶上去。
##
## ## 为什么第 2 步要缩小窗口而不是"再往上裁一点"
## 窗口已经贴底了，再往上裁会**把地面裁出框外**。
## 唯一能同时"保住地面"又"把地面顶上去"的办法，是缩小窗口——
## 代价是放大，所以 [constant UPSCALE_WARN] 会盯着它。
##
## ## 为什么不能统一"从正中裁"（即交给 COVERED 自动处理）
## 环境图的构图约定是「下半部是地面」，正中裁会把地面切掉一截。
func _crop_to_viewport_aspect(texture: Texture2D) -> Texture2D:
	var src: Vector2 = texture.get_size()
	if src.x <= 0.0 or src.y <= 0.0:
		return texture

	var aspect: float = _viewport_aspect()

	# 1) 最大可用窗口：受图高与视口比例双重限制
	var h: float = minf(src.y, src.x / aspect)
	var top: float = src.y - h   # 贴底

	# 2) 地面线太低 → 缩小窗口把它顶上来
	var ground_row: float = src.y * _ground_ratio()
	if h > 0.0 and (ground_row - top) / h > GROUND_LINE_MAX:
		var shrink: float = (src.y - ground_row) / maxf(1.0 - GROUND_LINE_MAX, 0.01)
		h = minf(h, shrink)
		h = maxf(h, 32.0)
		top = src.y - h

	var w: float = minf(src.x, h * aspect)
	h = w / aspect
	var left: float = (src.x - w) * 0.5

	# 完全没裁就不用包 AtlasTexture（省一层间接）
	if is_equal_approx(w, src.x) and is_equal_approx(h, src.y):
		return texture

	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(left, top, w, h)
	# filter_clip：超出 region 的采样被裁掉，避免把邻图内容拖进来（边缘发虚）
	atlas.filter_clip = true
	return atlas


## 当前背景的地面线比例（图高占比）
func _ground_ratio() -> float:
	return float(BACKGROUND_GROUND_RATIO.get(_background_key(), DEFAULT_GROUND_RATIO))


## 当前背景的查表键，同时也是配置表的键
func _background_key() -> String:
	return "%s_act%d" % [_character, _act]


## 这张图**实际被放大**了多少倍（1.0 = 没放大，只有画质代价才算）。
##
## ## 为什么不是 "原图宽 / 裁剪后宽"
## 那量的是"丢掉了多少"，不是"放大多少"。
## 真正决定画质的是**裁出来的像素要撑多大的屏幕**：
## 裁到 842 宽却要铺 1280 的屏 = 放大 1.52×。
## 而 1536 宽铺 1280 的屏是**缩小**（0.83×）——缩小不掉画质，不算数。
func _upscale_factor(texture: Texture2D) -> float:
	if texture == null:
		return 1.0
	var src: Vector2 = texture.get_size()
	if src.x <= 0.0 or src.y <= 0.0:
		return 1.0
	var cropped: Vector2 = _crop_to_viewport_aspect(texture).get_size()
	if cropped.x <= 0.0:
		return 1.0
	var display_w: float = float(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	return maxf(1.0, display_w / cropped.x)


## 视口宽高比。从项目设置读——**不要硬编码 1280/720**，
## 否则改了窗口尺寸这里就悄悄不对了（而且是"看起来还行"的那种不对）。
func _viewport_aspect() -> float:
	var w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	if w <= 0.0 or h <= 0.0:
		return 16.0 / 9.0
	return w / h


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
	# 有真图就什么都不用画——图会完整盖住这块区域，画了纯属浪费。
	# 用 `visible` 判断而不是再查一次资源，避免"取图"和"判断"两次状态不一致。
	if _image != null and _image.visible:
		return

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
