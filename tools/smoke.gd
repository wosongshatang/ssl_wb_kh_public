extends SceneTree
## 脚本与场景冒烟测试
##
## 用法（Windows 必须用 _console.exe，否则抓不到 stdout）：
##   GODOT="***REMOVED***/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64_console.exe"
##   "$GODOT" --headless --path "***REMOVED***" --script tools/smoke.gd
##
## 退出码 0 = 全部通过；非 0 = 有失败。
## 每新增一个「必须能打开」的场景，就往 SCENES 里加一行。
##
## ## 三个真实踩过的坑（合起来曾让这道门禁变成摆设）
## 1. **只加载场景不足以发现脚本错误**：不在场景依赖图里的脚本根本不会被编译。
##    `map_scene.gd` 编译失败时，`--quit` 那步毫无反应。
##    → 所以这里**逐个编译 scripts/ 下所有 .gd**。
## 2. **`SceneTree._initialize()` 里加进树的节点不会触发 `_ready()`**。
##    那时场景树还没进入活动状态，`_ready` 被推迟到第一帧。
##    所以"挂进树就验证了 _ready"是错的——检查必须放到**第一帧之后**。
## 3. **实例化失败后根节点没有脚本，但没人检查**。
##    → 所以这里断言 `instance.get_script() != null`。

const SCENES: Array[String] = [
	"res://scenes/boot/main.tscn",
	"res://scenes/map/map.tscn",
	"res://scenes/battle/battle.tscn",
	"res://scenes/ui/game_over.tscn",
]

const SCRIPT_ROOT: String = "res://scripts"

var _script_failures: int = 0
var _ran_scene_checks: bool = false


func _initialize() -> void:
	# 脚本编译检查不依赖场景树，可以立刻做
	_script_failures = _check_all_scripts()


## 场景检查放到第一帧——只有这样 `_ready()` 才会真的被调用
func _process(_delta: float) -> bool:
	if _ran_scene_checks:
		return true
	_ran_scene_checks = true

	var failed: int = _script_failures + _check_scenes()
	if failed > 0:
		push_error("smoke: %d 项失败" % failed)
	else:
		print("smoke: 全部通过")
	quit(0 if failed == 0 else 1)
	return true


## 编译 scripts/ 下的每一个 .gd。
## 这是**唯一**能保证「没有任何第一方脚本编译失败」的方法。
func _check_all_scripts() -> int:
	var paths: Array[String] = []
	_collect_scripts(SCRIPT_ROOT, paths)

	var failures: int = 0
	for path: String in paths:
		var script: Resource = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null or not _is_script_valid(script):
			push_error("FAIL compile: %s" % path)
			failures += 1

	print("scripts: %d 个已编译，%d 个失败" % [paths.size(), failures])
	return failures


## 编译失败的 GDScript 仍是个 Resource，但拿不到基类类型——用它判断
func _is_script_valid(script: Resource) -> bool:
	var gd := script as GDScript
	if gd == null:
		return false
	return gd.get_instance_base_type() != &""


func _collect_scripts(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_scripts(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _check_scenes() -> int:
	var failures: int = 0
	for scene_path: String in SCENES:
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			push_error("FAIL load: %s" % scene_path)
			failures += 1
			continue

		var instance: Node = packed.instantiate()
		if instance == null:
			push_error("FAIL instantiate: %s" % scene_path)
			failures += 1
			continue

		# 场景根节点在 .tscn 里声明了脚本，但脚本没挂上 → 脚本编译失败
		if instance.get_script() == null:
			push_error("FAIL script: %s 的根节点脚本未加载（编译失败？）" % scene_path)
			failures += 1
			instance.free()
			continue

		# 现在是第一帧之后，add_child 会**同步**触发 _ready()
		get_root().add_child(instance)
		var child_count: int = instance.get_child_count()
		if child_count == 0:
			push_error("FAIL empty: %s 进树后没有任何子节点（_ready 没跑？）" % scene_path)
			failures += 1
		else:
			print("OK %s (children=%d)" % [scene_path, child_count])
		get_root().remove_child(instance)
		instance.free()

	if failures == 0:
		print("smoke: %d/%d 场景通过" % [SCENES.size(), SCENES.size()])
	return failures
