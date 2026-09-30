class_name SaveManager
extends RefCounted
## 单局存档（JSON，人类可读——出问题能直接打开看，比二进制好排查）
##
## ## 日志级别的取舍
## 存档损坏 / 缺段 / 格式异常 —— 用 `push_warning`。理由：这些是**野外一定会发生**
## 且**游戏能优雅降级**的情况（写盘途中崩溃、跨版本旧存档）。用 error 级会让玩家
## 每次启动都看到红色报错，而实际体验是"没有可继续的存档"——这不叫错误，叫状态。
##
## 写盘失败 —— 用 `push_error`。理由：这会让玩家**静默丢失进度**，
## 属于真正的问题（磁盘满 / 权限不足），必须显眼。

const SAVE_PATH: String = "user://run_save.json"
const FILE_NAME: String = "run_save.json"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func save_run(run: RunState, map: MapManager) -> bool:
	var payload: Dictionary = {
		"run": run.to_dict(),
		"map": map.to_dict(),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法写入 %s（错误码 %d）" % [
			SAVE_PATH, FileAccess.get_open_error(),
		])
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


static func load_payload() -> Dictionary:
	if not has_save():
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("SaveManager: 存档解析失败（第 %d 行）：%s；将按「无存档」处理" % [
			json.get_error_line(), json.get_error_message(),
		])
		return {}
	if not (json.data is Dictionary):
		push_warning("SaveManager: 存档顶层不是字典；将按「无存档」处理")
		return {}

	return json.data as Dictionary


## 读档。返回 `[RunState, MapManager]`；失败返回空数组，
## 调用方据此决定「继续游戏」按钮是否可点。
static func restore() -> Array:
	var payload: Dictionary = load_payload()
	if payload.is_empty():
		return []
	if not payload.has("run") or not payload.has("map"):
		push_warning("SaveManager: 存档缺少 run 或 map 段；将按「无存档」处理")
		return []

	var run := RunState.new()
	run.from_dict(payload["run"] as Dictionary)

	var map := MapManager.new()
	map.from_dict(payload["map"] as Dictionary)

	return [run, map]


static func delete_save() -> void:
	if not has_save():
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: 无法打开 user:// 目录")
		return
	dir.remove(FILE_NAME)
