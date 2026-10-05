extends SceneTree
## 战斗截图工具（阶段 8 立绘验证用，**非测试**）
##
## ## 为什么需要它
## 立绘是「接线对了但看起来不对」最容易发生的区域——
## 比例拉伸、裁切把脸切掉、透明通道变成黑块，这些**测试断言不出来**。
## 只能真的渲染一帧看一眼。
##
## 用法：
##   <godot> -s tools/shot_battle.gd --path <proj> -- <character> <out.png>
##
## ⚠️ 必须用**带窗口**的方式跑（不能 --headless），否则 `get_texture().get_image()`
## 拿到的是空图。
##
## ⚠️ Autoload 在 `-s` 独立脚本模式下**不注册**（D25 同源问题）。
## 所以这里不能直接写 `ContentRegistry.load_all()`——
## 会报 "Identifier not found: ContentRegistry"。
## 改用 `root.get_node("/root/ContentRegistry")` 运行时取。

var _character: StringName = &"warrior"
var _out_path: String = "user://shot.png"
var _frames: int = 0
## 初始化只在第一帧做——`_initialize()` 时场景树还没进入活动状态，
## 用绝对路径 `get_node("/root/...")` 会报
## "Can't use get_node() with absolute paths from outside the active scene tree"（D25）。
var _booted: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1:
		_character = StringName(args[0])
	if args.size() >= 2:
		_out_path = args[1]


func _boot() -> void:
	var registry: Node = root.get_node_or_null("/root/ContentRegistry")
	if registry == null:
		push_error("找不到 ContentRegistry Autoload——请确认用 --path 指向项目根目录")
		quit(1)
		return
	registry.call("load_all")

	var game_state: Node = root.get_node_or_null("/root/GameState")
	if game_state == null:
		push_error("找不到 GameState Autoload")
		quit(1)
		return
	game_state.call("start_new_run", _character, 12345)

	var scene: PackedScene = load("res://scenes/battle/battle.tscn") as PackedScene
	var inst: Node = scene.instantiate()
	root.add_child(inst)


func _process(_delta: float) -> bool:
	_frames += 1
	if not _booted:
		_booted = true
		_boot()
		return false

	# 等几帧：让 _ready 跑完、布局稳定、Tween 归位、贴图上传到 GPU
	if _frames < 12:
		return false

	var img: Image = root.get_texture().get_image()
	if img == null:
		push_error("截图失败：拿到空图（是否用了 --headless？）")
		quit(1)
		return true

	var abs_path: String = ProjectSettings.globalize_path(_out_path)
	var err: int = img.save_png(abs_path)
	if err != OK:
		push_error("保存失败 %s (err=%d)" % [abs_path, err])
		quit(1)
	else:
		print("已保存 %s  (%dx%d)" % [abs_path, img.get_width(), img.get_height()])
	quit(0)
	return true
