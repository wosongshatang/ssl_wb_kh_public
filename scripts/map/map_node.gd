class_name MapNode
extends RefCounted
## 地图上的一个节点

enum Kind {
	COMBAT,   ## 普通战斗
	ELITE,    ## 精英战斗
	REST,     ## 休息（回血 / 升级牌）
	SHOP,     ## 商店
	EVENT,    ## 事件
	BOSS,     ## 幕 Boss（必为最后一层）
	GOD_ALTAR, ## 神坛：献祭生命换力量，代价是侵蚀（P6-10）
	TRAITOR,   ## 叛神者：**唯一能主动降低神性**的地方（P6-10）
}

var id: int = -1
var row: int = 0
## 同层内的横向序号，用于 UI 排布
var column: int = 0
var kind: Kind = Kind.COMBAT
## 可前往的下一层节点 id
var next_ids: Array[int] = []
var is_visited: bool = false
## 具体内容：敌人 id / 事件 id 等，由生成时填入
var payload: Dictionary = {}


func kind_label() -> String:
	return kind_label_of(kind)


## 静态版：只有 kind 值（没有节点实例）时也要能拿到中文名。
## 单一数据源——两处各写一遍迟早会不一致。
static func kind_label_of(node_kind: Kind) -> String:
	match node_kind:
		Kind.COMBAT:
			return "战斗"
		Kind.ELITE:
			return "精英"
		Kind.REST:
			return "休息"
		Kind.SHOP:
			return "商店"
		Kind.EVENT:
			return "事件"
		Kind.BOSS:
			return "BOSS"
		Kind.GOD_ALTAR:
			return "神坛"
		Kind.TRAITOR:
			return "叛神者"
		_:
			return "?"


## 图标文件名用的**短名**（阶段 8）——对应 `assets/icons/map/<key>.png`。
##
## 为什么不直接用 `Kind` 的枚举名（`COMBAT`）：文件名要小写、可读，
## 而且**改动枚举名不该让一批美术文件集体失效**。
## 这层映射把"代码里的枚举"和"磁盘上的文件名"解耦开。
##
## 返回空串表示"这个 kind 没有对应图标"——调用方回退几何图形。
static func kind_key(node_kind: Kind) -> StringName:
	match node_kind:
		Kind.COMBAT:
			return &"combat"
		Kind.ELITE:
			return &"elite"
		Kind.REST:
			return &"rest"
		Kind.SHOP:
			return &"shop"
		Kind.EVENT:
			return &"event"
		Kind.BOSS:
			return &"boss"
		Kind.GOD_ALTAR:
			return &"god_altar"
		Kind.TRAITOR:
			return &"traitor"
		_:
			return &""


## 全部 kind（供门禁遍历用）。**新增 Kind 时必须同步这里**——
## 否则新节点类型会静默地没有图标，而且测试也不会发现。
static func all_kinds() -> Array[Kind]:
	return [
		Kind.COMBAT, Kind.ELITE, Kind.REST, Kind.SHOP,
		Kind.EVENT, Kind.BOSS, Kind.GOD_ALTAR, Kind.TRAITOR,
	]


func to_dict() -> Dictionary:
	return {
		"id": id,
		"row": row,
		"column": column,
		"kind": kind,
		"next_ids": next_ids.duplicate(),
		"is_visited": is_visited,
		"payload": payload.duplicate(true),
	}


static func from_dict(data: Dictionary) -> MapNode:
	var node := MapNode.new()
	node.id = int(data.get("id", -1))
	node.row = int(data.get("row", 0))
	node.column = int(data.get("column", 0))
	node.kind = int(data.get("kind", Kind.COMBAT)) as Kind
	node.is_visited = bool(data.get("is_visited", false))
	node.payload = (data.get("payload", {}) as Dictionary).duplicate(true)
	node.next_ids.clear()
	for raw: Variant in (data.get("next_ids", []) as Array):
		node.next_ids.append(int(raw))
	return node


func _to_string() -> String:
	return "MapNode#%d(第%d层 %s)" % [id, row, kind_label()]
