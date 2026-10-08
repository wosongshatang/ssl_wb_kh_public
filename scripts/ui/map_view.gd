class_name MapView
extends Control
## 地图视图（用户要求：「线形地图选择节点，每个节点有个简单样式」）
##
## ## 为什么用 `_draw()` 而不是给每个节点建 Button
## 节点要按"层 + 列"排布并画连线，用容器布局反而要跟锚点搏斗；
## 而且节点数量在二十几个，一次 `_draw()` 全部画完比二十几个 Control 更省。
## 代价是点击要自己做命中测试——但那只用几行距离判断。
##
## ## 坐标系
## 第 0 层在最上方，Boss 在最下方（与参考视频一致：自上而下推进）。

signal node_selected(node_id: int)

const NODE_RADIUS: float = 20.0
const TOP_MARGIN: float = 56.0
const BOTTOM_MARGIN: float = 64.0
const COLUMN_SPACING: float = 96.0
const LEGEND_WIDTH: float = 168.0

var _map: MapManager = null
var _positions: Dictionary = {}
var _available: Dictionary = {}
var _hover_id: int = -1
var _legend_panel: PanelContainer
var _legend_box: VBoxContainer
## 节点图标子节点（node_id → TextureRect）。
## 只有**真的有图**的节点才会在这里；缺图的节点交给 `_draw()` 画几何图形。
var _icon_nodes: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# ⚠️ **不要**在这里 set_anchors_preset(PRESET_FULL_RECT)。
	# 调用方（场景的 _layout()）会用 position/size 定位本控件；
	# 一旦锚点是"左右/上下不相等"的全屏锚点，Godot 会在 _ready 之后
	# **用锚点重新覆盖 size**，并报 "Nodes with non-equal opposite anchors
	# will have their size overridden after _ready()"。
	# 症状：布局代码看起来生效了，实际尺寸还是被改回去了。
	_build_legend()


func build_map(map: MapManager) -> void:
	_map = map
	_recompute_positions()
	_refresh_availability()
	queue_redraw()


func refresh(map: MapManager) -> void:
	_map = map
	_refresh_availability()
	# 刷新时也要重算坐标：调用方可能刚改过 size（例如 _layout() 之后立刻 refresh）
	_recompute_positions()
	queue_redraw()


func _refresh_availability() -> void:
	_available.clear()
	if _map == null:
		return
	for node: MapNode in _map.available_nodes():
		_available[node.id] = true


## 已算出坐标的节点数。供测试断言用——
## 「尺寸为 0 导致整张地图空白」是个"看起来在跑、其实什么都没画"的 bug，
## 必须有办法在不渲染的情况下验证它。
func positioned_node_count() -> int:
	return _positions.size()


func node_position(node_id: int) -> Vector2:
	return _positions.get(node_id, Vector2.ZERO)


# ══ 布局 ════════════════════════════════════════════════════

func _recompute_positions() -> void:
	_positions.clear()
	if _map == null or _map.rows.is_empty():
		# 地图没了也要清图标节点——否则旧图标会留在地图上"飘着"
		_clear_icon_nodes()
		return

	var rows: int = _map.rows.size()
	var usable_height: float = maxf(size.y - TOP_MARGIN - BOTTOM_MARGIN, 100.0)
	var row_step: float = usable_height / float(maxi(rows - 1, 1))
	var center_x: float = (size.x - LEGEND_WIDTH) * 0.5

	for r: int in rows:
		var row_ids: Array = _map.rows[r]
		var count: int = row_ids.size()
		for c: int in count:
			var offset: float = (float(c) - float(count - 1) * 0.5) * COLUMN_SPACING
			_positions[row_ids[c]] = Vector2(center_x + offset, TOP_MARGIN + float(r) * row_step)

	_sync_icon_nodes()


## 按当前 `_positions` 同步图标子节点。
##
## ## 为什么用节点而不是 `_draw()`
## ⚠️ **D35**：本项目里 `_draw()` 画贴图会渲染成纯白方块。
##
## ## 为什么"缺图就删节点"而不是"建好再隐藏"
## 没图时必须让 `_draw()` 的几何图形**露出来**。
## 留一个空 TextureRect 盖在上面，会把兜底图形挡住 → 那个节点变成空白，
## 比"没有图标"更糟。
##
## ## 为什么要做增量更新而不是全删重建
## 本函数在 `NOTIFICATION_RESIZED` 里被调用，拖动窗口时会高频触发。
## 全删重建会让图标每帧闪一下。
func _sync_icon_nodes() -> void:
	if _map == null:
		_clear_icon_nodes()
		return

	# 1) 收集"这一帧应该有图"的节点
	var wanted: Dictionary = {}
	for node_id: int in _positions:
		var node: MapNode = _map.nodes.get(node_id)
		if node == null:
			continue
		var tex: Texture2D = ContentRegistry.get_map_icon(MapNode.kind_key(node.kind))
		if tex != null:
			wanted[node_id] = tex

	# 2) 删掉不再需要的（地图换了 / 图被撤了）
	for node_id: int in _icon_nodes.keys():
		if not wanted.has(node_id):
			var stale: Variant = _icon_nodes[node_id]
			if is_instance_valid(stale):
				(stale as Node).queue_free()
			_icon_nodes.erase(node_id)

	# 3) 建新的 / 更新已有的位置
	for node_id: int in wanted:
		var rect: TextureRect = _icon_nodes.get(node_id)
		if rect == null or not is_instance_valid(rect):
			rect = TextureRect.new()
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# 图标不能吃鼠标事件——否则点节点会被图标拦下，地图点不动
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.size = Vector2(ICON_SIZE, ICON_SIZE)
			add_child(rect)
			_icon_nodes[node_id] = rect
		rect.texture = wanted[node_id]
		rect.position = _positions[node_id] - Vector2(ICON_SIZE, ICON_SIZE) * 0.5


func _clear_icon_nodes() -> void:
	for node_id: int in _icon_nodes:
		var stale: Variant = _icon_nodes[node_id]
		if is_instance_valid(stale):
			(stale as Node).queue_free()
	_icon_nodes.clear()


## 当前显示的图标节点数。供测试断言"有图时确实建了节点"。
func icon_node_count() -> int:
	return _icon_nodes.size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recompute_positions()
		_reposition_legend()
		queue_redraw()


## 图例贴右上角。**必须跟着 size 走**——_ready() 时 size 还是 0，
## 那一刻算出来的位置会把图例甩到屏幕外。
func _reposition_legend() -> void:
	if _legend_panel == null:
		return
	_legend_panel.position = Vector2(maxf(size.x - LEGEND_WIDTH - 16.0, 8.0), 20.0)


# ══ 绘制 ════════════════════════════════════════════════════

func _draw() -> void:
	if _map == null:
		return

	_draw_connections()
	_draw_nodes()


## 连线：用虚线感（短线）表示路径。已走过的路径高亮。
func _draw_connections() -> void:
	for node_id: int in _map.nodes:
		var from_node: MapNode = _map.nodes[node_id]
		if not _positions.has(node_id):
			continue
		var from_pos: Vector2 = _positions[node_id]

		for child_id: int in from_node.next_ids:
			if not _positions.has(child_id):
				continue
			var to_pos: Vector2 = _positions[child_id]
			var walked: bool = from_node.is_visited and (_map.nodes[child_id] as MapNode).is_visited
			var line_color: Color = UiPalette.GOLD.darkened(0.2) if walked else UiPalette.BORDER_DIM
			_draw_dashed_line(from_pos, to_pos, line_color)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var delta := to - from
	var distance: float = delta.length()
	if distance <= 1.0:
		return
	var direction := delta / distance
	var dash: float = 7.0
	var gap: float = 6.0
	var travelled: float = 0.0
	while travelled < distance:
		var seg_end: float = minf(travelled + dash, distance)
		draw_line(from + direction * travelled, from + direction * seg_end, color, 2.0)
		travelled = seg_end + gap


func _draw_nodes() -> void:
	var font := ThemeDB.fallback_font

	for node_id: int in _map.nodes:
		if not _positions.has(node_id):
			continue
		var node: MapNode = _map.nodes[node_id]
		var pos: Vector2 = _positions[node_id]
		var reachable: bool = _available.has(node_id)

		var fill: Color = UiPalette.color_for_node_kind(node.kind)
		if node.is_visited:
			fill = UiPalette.NODE_DONE
		elif not reachable:
			fill = fill.darkened(0.45)

		# 底座圆
		draw_circle(pos, NODE_RADIUS, Color(0.1, 0.09, 0.11))
		draw_circle(pos, NODE_RADIUS - 2.0, fill)
		# 可前往的节点加一圈金边 + 呼吸感（用固定高亮，避免每帧重绘）
		if reachable:
			draw_arc(pos, NODE_RADIUS + 2.0, 0.0, TAU, 40, UiPalette.GOLD, 2.0)

		_draw_node_glyph(node.kind, pos, font)

		# 当前位置标记：一个下指的三角
		if node_id == _map.current_node_id:
			var tip := pos + Vector2(0, -NODE_RADIUS - 4.0)
			draw_colored_polygon(PackedVector2Array([
				tip, tip + Vector2(-7, -10), tip + Vector2(7, -10),
			]), Color(0.85, 0.25, 0.25))

		# 鼠标悬停：加亮外圈
		if node_id == _hover_id:
			draw_arc(pos, NODE_RADIUS + 5.0, 0.0, TAU, 40, Color(1, 1, 1, 0.6), 1.5)


## 节点图标（阶段 8）—— 由**子节点**绘制，不在这里画。
##
## ⚠️ **D35：本项目里 `_draw()` 画贴图会渲染成纯白方块**——
## 资源、算式、尺寸全对，换成 TextureRect 节点立刻正常。立绘与卡图都踩过。
## 所以图标走 `_icon_nodes`（见 `_sync_icon_nodes()`），
## 这里只负责**缺图时的几何回退**。
##
## ## 为什么图标要比节点圆小一圈
## 节点圆直径 40（`NODE_RADIUS * 2`）。图标铺满整圆会让相邻节点视觉上粘连；
## 留出内边距后，"圆环是节点、图标是内容"这层结构才读得出来。
const ICON_SIZE: float = 28.0


## 节点样式：**缺图时的回退**（有图时被 `_icon_nodes` 的子节点盖住）
func _draw_node_glyph(kind: MapNode.Kind, pos: Vector2, font: Font) -> void:
	var ink := Color(0.12, 0.1, 0.12)
	match kind:
		MapNode.Kind.COMBAT:
			# 交叉双刃
			draw_line(pos + Vector2(-8, -8), pos + Vector2(8, 8), ink, 3.0)
			draw_line(pos + Vector2(8, -8), pos + Vector2(-8, 8), ink, 3.0)
		MapNode.Kind.ELITE:
			# 三角（比普通更"重"）
			draw_colored_polygon(PackedVector2Array([
				pos + Vector2(0, -9), pos + Vector2(9, 7), pos + Vector2(-9, 7),
			]), ink)
		MapNode.Kind.REST:
			# 篝火：一条竖线 + 一个圆
			draw_line(pos + Vector2(0, 9), pos + Vector2(0, -2), ink, 3.0)
			draw_circle(pos + Vector2(0, -7), 5.0, ink)
		MapNode.Kind.SHOP:
			draw_rect(Rect2(pos + Vector2(-8, -6), Vector2(16, 13)), ink, true)
		MapNode.Kind.EVENT:
			# 问号
			if font != null:
				draw_string(font, pos + Vector2(-5, 7), "?",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		MapNode.Kind.BOSS:
			# 骷髅轮廓
			draw_circle(pos, 9.0, ink)
			draw_circle(pos + Vector2(-4, -2), 2.5, Color(0.75, 0.7, 0.65))
			draw_circle(pos + Vector2(4, -2), 2.5, Color(0.75, 0.7, 0.65))


# ══ 交互 ════════════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if _map == null:
		return

	var motion := event as InputEventMouseMotion
	if motion != null:
		var hit: int = _node_at(motion.position)
		if hit != _hover_id:
			_hover_id = hit
			queue_redraw()
		return

	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		var hit_id: int = _node_at(mouse.position)
		if hit_id >= 0:
			node_selected.emit(hit_id)


## 命中测试：取距离最近且在半径内的节点
func _node_at(point: Vector2) -> int:
	var best_id: int = -1
	var best_distance: float = NODE_RADIUS + 4.0
	for node_id: int in _positions:
		var distance: float = (_positions[node_id] as Vector2).distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best_id = node_id
	return best_id


# ══ 图例 ════════════════════════════════════════════════════

func _build_legend() -> void:
	var panel := PanelContainer.new()
	_legend_panel = panel
	panel.custom_minimum_size = Vector2(LEGEND_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.115, 0.1, 0.92)
	style.border_color = UiPalette.BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_legend_box = VBoxContainer.new()
	_legend_box.add_theme_constant_override("separation", 5)
	_legend_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_legend_box)

	var title := Label.new()
	title.text = "图例"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UiPalette.GOLD)
	_legend_box.add_child(title)

	var entries: Array = [
		[MapNode.Kind.COMBAT, "战斗"],
		[MapNode.Kind.ELITE, "精英"],
		[MapNode.Kind.REST, "休息"],
		[MapNode.Kind.SHOP, "商店"],
		[MapNode.Kind.EVENT, "事件"],
		[MapNode.Kind.BOSS, "BOSS"],
	]
	for entry: Array in entries:
		_legend_box.add_child(_make_legend_row(entry[0] as MapNode.Kind, str(entry[1])))


func _make_legend_row(kind: MapNode.Kind, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var swatch := ColorRect.new()
	swatch.color = UiPalette.color_for_node_kind(kind)
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.size = Vector2(12, 12)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UiPalette.TEXT_DIM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	return row
