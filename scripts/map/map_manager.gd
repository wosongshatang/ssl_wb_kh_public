class_name MapManager
extends RefCounted
## 地图生成与节点移动（阶段 3）
##
## 结构：**分层 DAG**（有向无环图）。每层 2~4 个节点，节点连向下一层的 1~2 个，
## 最后一层是 Boss。
##
## 为什么是 DAG 而不是全连接图或线性路径：
##   - 全连接：选择过载，每个选择都"看起来一样"，等于没有选择
##   - 纯线性：失去 Roguelike 的核心乐趣（构筑路线规划）
##   - DAG：每步 1~3 个有意义的分支，且**保证不会走进死路**

signal node_entered(node: MapNode)
signal map_completed()

## 每幕层数。**12 层**（阶段 7 平衡：原为 6 层）。
##
## 为什么加倍：6 层时玩家打 4~5 场就到 Boss，
## **卡牌/遗物的成长窗口不够**——三选一才拿 3~4 张牌，构筑根本没成型。
## 12 层大约对应 9~10 场战斗，是"能凑出一套东西"的最小长度。
const ROWS_PER_ACT: int = 12

## 每幕的**保底**节点数。
##
## 纯随机会出现"12 层里一个休息都没有"的情况——
## 玩家会因为"没有恢复手段"而必败，而这不是他的决策造成的。
## **随机性可以决定过程，但不该决定一局有没有恢复机会。**
const MIN_REST_PER_ACT: int = 3
const MIN_SHOP_PER_ACT: int = 2
const MIN_ELITE_PER_ACT: int = 2
const MIN_NODES_PER_ROW: int = 2
const MAX_NODES_PER_ROW: int = 4
const STARTING_NODES: int = 3

## 中间层的节点类型权重。普通战斗压倒性多数，保证一局的战斗密度。
const KIND_WEIGHTS: Dictionary = {
	MapNode.Kind.COMBAT: 62,
	MapNode.Kind.EVENT: 16,
	MapNode.Kind.REST: 10,
	MapNode.Kind.SHOP: 7,
	MapNode.Kind.ELITE: 5,
	MapNode.Kind.GOD_ALTAR: 5,
	MapNode.Kind.TRAITOR: 3,
}

## ══ 三线九图（设计文档 §5.2）═══════════════════════════════
##
## 角色 → 该角色的三张地图，每张 = 名字 + 环境机制 + 敌人池。
##
## ## ⚠️ 为什么键是 (角色, 幕) 而不是只按幕
## 只按幕索引的话，**猎人会走进战士的竞技场**——
## "三线九图"在数据结构上就根本不存在。
## 这不是"以后再说"的问题：它决定了这个结构**能不能**承载三条线。
const LINES: Dictionary = {
	&"warrior": [
		{
			"name": "竞技场",
			"modifier": &"arena_crowd_cheer",
			"enemies": [
				&"act1_combat", &"act1_gladiator", &"act1_shieldman", &"act1_poisoner",
				&"act1_beast", &"act1_champion", &"act1_javelin",
			],
		},
		{
			"name": "战场",
			"modifier": &"battlefield_momentum",
			"enemies": [
				&"act2_combat", &"act2_archer", &"act2_standard", &"act2_poisoner",
				&"act2_cavalry", &"act2_shieldwall", &"act2_war_drum",
			],
		},
		{
			"name": "古战场",
			"modifier": &"ancient_grudge",
			"enemies": [
				&"act3_combat", &"act3_wraith", &"act3_berserker", &"act3_shieldbearer",
				&"act3_poisoner", &"act3_revenant", &"act3_bone_lord", &"act3_mirror",
			],
		},
	],
	&"mage": [
		{"name": "学徒白塔", "modifier": &"tower_lesson",
			"enemies": [&"mage_act1_acolyte", &"mage_act1_construct", &"mage_act1_shard"]},
		{"name": "元素裂隙", "modifier": &"mana_tide",
			"enemies": [&"mage_act2_wraith", &"mage_act2_devourer", &"mage_act2_tide"]},
		{"name": "万法归墟", "modifier": &"causality_field",
			"enemies": [&"mage_act3_arbiter", &"mage_act3_echo", &"mage_act3_voice"]},
	],
}


## 取某角色第 act 幕（**1 起**）的线路配置。
##
## 找不到时**告警并回退到战士线**——内容还没做的角色不该直接崩，
## 但也不能**静默**走进别人的图（那样测试会全绿而玩家看到竞技场）。
static func line_for(character: StringName, act: int) -> Dictionary:
	var lines: Array = LINES.get(character, [])
	var index: int = act - 1

	if index < 0 or index >= lines.size():
		push_error("MapManager: 角色「%s」没有第 %d 幕的线路配置" % [character, act])
		var fallback: Array = LINES.get(&"warrior", [])
		if index < 0 or index >= fallback.size():
			return {}
		return fallback[index] as Dictionary

	return lines[index] as Dictionary


## 幕名（UI 展示用；未配置时回退成"第 N 幕"）
static func act_name(character: StringName, act: int) -> String:
	var line: Dictionary = line_for(character, act)
	return str(line.get("name", "第 %d 幕" % act))


## 该幕的环境机制 id（阶段 6）。未配置时返回空串——机制是可选增强，不是必需依赖。
static func act_modifier_id(character: StringName, act: int) -> StringName:
	var line: Dictionary = line_for(character, act)
	return StringName(str(line.get("modifier", "")))


## 该幕的普通战斗敌人池
static func combat_pool(character: StringName, act: int) -> Array:
	var line: Dictionary = line_for(character, act)
	return line.get("enemies", []) as Array


## 事件池。**必须放真实注册的 id**——
## 曾经这里写的是 `placeholder_event_N`，导致两个真事件永远不会被触发。
const EVENT_POOL: Array[StringName] = [
	&"shrine_of_war", &"rebel_broker", &"wandering_alchemist",
	&"god_offer_war", &"god_offer_arcane", &"cursed_altar", &"usurp_power",
	&"god_gift_special", &"wandering_merchant", &"blood_oath",
	&"forgotten_library", &"broken_statue",
]

## id -> MapNode
var nodes: Dictionary = {}
## 每层的节点 id 列表
var rows: Array[Array] = []
var current_node_id: int = -1
var act: int = 1

var _rng: RandomNumberGenerator
var _next_id: int = 0


# ── 生成 ────────────────────────────────────────────────────

## 本局地图属于哪个角色。**决定用哪条线的名字 / 机制 / 敌人池。**
var character: StringName = &"warrior"


func generate(
	p_rng: RandomNumberGenerator,
	p_act: int = 1,
	p_character: StringName = &"warrior"
) -> void:
	_rng = p_rng
	act = p_act
	character = p_character
	nodes.clear()
	rows.clear()
	current_node_id = -1
	_next_id = 0

	# 1) 先建层与节点（此时还不知道类型——类型依赖层结构）
	for r: int in ROWS_PER_ACT:
		var count: int = _node_count_for_row(r)
		var row_ids: Array = []
		for c: int in count:
			var node := MapNode.new()
			node.id = _next_id
			_next_id += 1
			node.row = r
			node.column = c
			nodes[node.id] = node
			row_ids.append(node.id)
		rows.append(row_ids)

	# 2) 连边
	for r: int in ROWS_PER_ACT - 1:
		_connect_rows(r)

	# 3) 定类型与内容
	for r: int in ROWS_PER_ACT:
		for node_id: int in rows[r]:
			_assign_kind(nodes[node_id] as MapNode, r)

	# 4) 保底补齐：随机不该决定一局有没有恢复机会
	_ensure_minimum_kinds()


func _node_count_for_row(r: int) -> int:
	if r == 0:
		return STARTING_NODES
	if r == ROWS_PER_ACT - 1:
		return 1  # Boss 层
	return _rng.randi_range(MIN_NODES_PER_ROW, MAX_NODES_PER_ROW)


func _connect_rows(r: int) -> void:
	var upper: Array = rows[r]
	var lower: Array = rows[r + 1]
	var n: int = upper.size()
	var m: int = lower.size()
	if n == 0 or m == 0:
		return

	# ① 保证下层每个节点至少有一个父节点（不出现孤岛）
	for j: int in m:
		var parent_idx: int = mini(int(float(j) * n / m), n - 1)
		_add_edge(upper[parent_idx], lower[j])

	# ② 保证上层每个节点至少有一个子节点（不出现死路）
	for i: int in n:
		var child_idx: int = mini(int(float(i) * m / n), m - 1)
		_add_edge(upper[i], lower[child_idx])

	# ③ 随机补边，制造真正的「路线选择」而非唯一路径
	if n >= 2 and m >= 2:
		var extra: int = _rng.randi_range(1, 2)
		for _k: int in extra:
			var i2: int = _rng.randi_range(0, n - 1)
			var j2: int = clampi(i2 + _rng.randi_range(-1, 1), 0, m - 1)
			_add_edge(upper[i2], lower[j2])


func _add_edge(from_id: int, to_id: int) -> void:
	var node: MapNode = nodes[from_id]
	if not node.next_ids.has(to_id):
		node.next_ids.append(to_id)


func _assign_kind(node: MapNode, r: int) -> void:
	if r == ROWS_PER_ACT - 1:
		node.kind = MapNode.Kind.BOSS
		node.payload = {"enemy_id": "act%d_boss" % act}
		return
	if r == 0:
		node.kind = MapNode.Kind.COMBAT
		node.payload = {"enemy_id": _pick_combat_enemy()}
		return

	var weights: Dictionary = KIND_WEIGHTS.duplicate()
	# 前两层不刷精英，避免开局劝退
	if r <= 1:
		weights.erase(MapNode.Kind.ELITE)

	node.kind = _pick_kind(weights)
	node.payload = _payload_for(node.kind, r)


## 保底补齐（阶段 7）。
##
## 把普通战斗节点改造成缺的那类，直到每类都达标。
## 只改**中间层**的普通战斗——Boss / 起点 / 已定的休息商店都不动。
func _ensure_minimum_kinds() -> void:
	_ensure_kind(MapNode.Kind.REST, MIN_REST_PER_ACT)
	_ensure_kind(MapNode.Kind.SHOP, MIN_SHOP_PER_ACT)
	_ensure_kind(MapNode.Kind.ELITE, MIN_ELITE_PER_ACT)


func _ensure_kind(kind: MapNode.Kind, minimum: int) -> void:
	var candidates: Array[MapNode] = []

	for r: int in range(2, ROWS_PER_ACT - 1):
		var count: int = 0
		for node_id: int in rows[r]:
			var node: MapNode = nodes[node_id]
			if node.kind == kind:
				count += 1
			elif node.kind == MapNode.Kind.COMBAT:
				candidates.append(node)
		if count >= minimum:
			return

	# 缺多少补多少（候选不够就补到没得补为止）
	var missing: int = minimum - _count_kind(kind)
	var index: int = 0
	while missing > 0 and index < candidates.size():
		var node: MapNode = candidates[index]
		node.kind = kind
		node.payload = _payload_for(kind, node.row)
		index += 1
		missing -= 1


func _count_kind(kind: MapNode.Kind) -> int:
	var total: int = 0
	for node_id: int in nodes:
		if (nodes[node_id] as MapNode).kind == kind:
			total += 1
	return total


func _pick_kind(weights: Dictionary) -> MapNode.Kind:
	var total: int = 0
	for key: Variant in weights:
		total += int(weights[key])
	if total <= 0:
		return MapNode.Kind.COMBAT

	var roll: int = _rng.randi_range(1, total)
	var cumulative: int = 0
	for key: Variant in weights:
		cumulative += int(weights[key])
		if roll <= cumulative:
			return key as MapNode.Kind
	return MapNode.Kind.COMBAT


func _payload_for(kind: MapNode.Kind, _r: int) -> Dictionary:
	match kind:
		MapNode.Kind.COMBAT:
			return {"enemy_id": _pick_combat_enemy()}
		MapNode.Kind.ELITE:
			return {"enemy_id": "act%d_elite" % act}
		MapNode.Kind.EVENT:
			return {"event_id": String(_pick_event())}
		_:
			return {}


func _pick_combat_enemy() -> String:
	var pool: Array = combat_pool(character, act)
	if pool.is_empty():
		return "act%d_combat" % act
	return String(pool[_rng.randi_range(0, pool.size() - 1)])


func _pick_event() -> StringName:
	if EVENT_POOL.is_empty():
		return &""
	return EVENT_POOL[_rng.randi_range(0, EVENT_POOL.size() - 1)]


# ── 移动 ────────────────────────────────────────────────────

## 当前可前往的节点。尚未进入任何节点时返回第一层全部节点。
func available_nodes() -> Array[MapNode]:
	var out: Array[MapNode] = []
	if rows.is_empty():
		return out

	if current_node_id < 0:
		for node_id: int in rows[0]:
			out.append(nodes[node_id] as MapNode)
		return out

	var current: MapNode = current_node()
	if current == null:
		return out
	for node_id: int in current.next_ids:
		out.append(nodes[node_id] as MapNode)
	return out


func enter_node(node_id: int) -> bool:
	if not nodes.has(node_id):
		return false

	var node: MapNode = nodes[node_id]
	if not available_nodes().has(node):
		return false

	node.is_visited = true
	current_node_id = node_id
	node_entered.emit(node)

	if node.kind == MapNode.Kind.BOSS:
		map_completed.emit()
	return true


func current_node() -> MapNode:
	if not nodes.has(current_node_id):
		return null
	return nodes[current_node_id] as MapNode


func boss_node() -> MapNode:
	if rows.is_empty():
		return null
	var last_row: Array = rows[ROWS_PER_ACT - 1]
	if last_row.is_empty():
		return null
	return nodes[last_row[0]] as MapNode


func node_count() -> int:
	return nodes.size()


func is_completed() -> bool:
	var current: MapNode = current_node()
	return current != null and current.kind == MapNode.Kind.BOSS


# ── 存档序列化 ──────────────────────────────────────────────

func to_dict() -> Dictionary:
	var node_list: Array = []
	for node_id: int in nodes:
		node_list.append((nodes[node_id] as MapNode).to_dict())

	var row_list: Array = []
	for row: Array in rows:
		row_list.append(row.duplicate())

	return {
		"act": act,
		"current_node_id": current_node_id,
		"next_id": _next_id,
		"nodes": node_list,
		"rows": row_list,
	}


func from_dict(data: Dictionary) -> void:
	nodes.clear()
	rows.clear()

	act = int(data.get("act", 1))
	current_node_id = int(data.get("current_node_id", -1))
	_next_id = int(data.get("next_id", 0))

	for raw: Variant in (data.get("nodes", []) as Array):
		var node := MapNode.from_dict(raw as Dictionary)
		nodes[node.id] = node

	for raw_row: Variant in (data.get("rows", []) as Array):
		var row: Array = []
		for raw_id: Variant in (raw_row as Array):
			row.append(int(raw_id))
		rows.append(row)
