extends SceneTree
## 场景冒烟测试 —— 确认关键场景能被加载并实例化。
##
## 用法（Windows 必须用 _console.exe，否则抓不到 stdout）：
##   GODOT="***REMOVED***/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64_console.exe"
##   "$GODOT" --headless --path "***REMOVED***" --script tools/smoke.gd
##
## 退出码 0 = 全部通过；非 0 = 有场景加载失败。
## 每新增一个「必须能打开」的场景，就往 SCENES 里加一行。

const SCENES: Array[String] = [
	"res://scenes/boot/main.tscn",
]


func _initialize() -> void:
	var failed: int = 0
	for scene_path: String in SCENES:
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			push_error("FAIL load: %s" % scene_path)
			failed += 1
			continue

		var instance: Node = packed.instantiate()
		if instance == null:
			push_error("FAIL instantiate: %s" % scene_path)
			failed += 1
			continue

		print("OK %s (children=%d)" % [scene_path, instance.get_child_count()])
		instance.free()

	if failed > 0:
		push_error("smoke: %d/%d 场景失败" % [failed, SCENES.size()])
	else:
		print("smoke: %d/%d 场景通过" % [SCENES.size(), SCENES.size()])
	quit(0 if failed == 0 else 1)
