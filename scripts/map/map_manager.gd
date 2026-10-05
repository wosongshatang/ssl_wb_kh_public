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

const ROWS_PER_ACT: int = 6
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

## 每幕的环境机制（阶段 6）。**改变规则，不是改数值**（设计文档 §2.3）。
const ACT_MODIFIERS: Dictionary = {
	1: &"arena_crowd_cheer",
	2: &"battlefield_momentum",
	3: &"ancient_grudge",
}

## 每幕的地图名（设计文档 §5.2 三线九图 · 战士线）
const ACT_NAMES: Dictionary = {
	1: "竞技场",
	2: "战场",
	3: "古战场",
}

## 每幕的普通战斗敌人池。
##
## ⚠️ **毒敌人必须在每一幕的池子里**——否则「克制壁垒的敌人」只存在于单测里，
## 玩家永远遇不到，壁垒的弱点在真实对局中就不会出现。
##
## 池内敌人的**机制要互补**，不能只是数值不同：
## 高攻低血惩罚不格挡 / 带格挡惩罚纯攻击 / 多段惩罚单次大格挡 / 自我强化逼你提速。
const COMBAT_POOLS: Dictionary = {
	1: [&"act1_combat", &"act1_gladiator", &"act1_shieldman", &"act1_poisoner"],
	2: [&"act2_combat", &"act2_archer", &"act2_standard", &"act2_poisoner"],
	3: [&"act3_combat", &"act3_wraith", &"act3_berserker", &"act3_shieldbearer", &"act3_poisoner"],
}

## 事件池。**必须放真实注册的 id**——
## 曾经这里写的是 `placeholder_event_N`，导致两个真事件永远不会被触发。
const EVENT_POOL: Array[StringName] = [
	&"shrine_of_war", &"rebel_broker", &"wandering_alchemist",
	&"god_offer_war", &"god_offer_arcane", &"cursed_altar", &"usurp_power",
	&"god_gift_special",
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

func generate(p_rng: RandomNumberGenerator, p_act: int = 1) -> void:
	_rng = p_rng
	act = p_act
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
	var pool: Array = COMBAT_POOLS.get(act, [])
	if pool.is_empty():
		return "act%d_combat" % act
	return String(pool[_rng.randi_range(0, pool.size() - 1)])


func _pick_event() -> StringName:
	if EVENT_POOL.is_empty():
		return &""
	return EVENT_POOL[_rng.randi_range(0, EVENT_POOL.size() - 1)]


## 幕名（UI 展示用；未配置时回退成"第 N 幕"）
static func act_name(act: int) -> String:
	return str(ACT_NAMES.get(act, "第 %d 幕" % act))


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
