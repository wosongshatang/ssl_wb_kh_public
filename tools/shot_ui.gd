extends SceneTree
## UI 截图工具（**非测试**）—— 给"新建的界面"做肉眼验收
##
## ## 为什么需要它
## 界面接线是「逻辑对了但看起来不对」最容易发生的区域——
## 文字被裁掉、控件挤成 0 宽、配色和主题打架，这些**测试断言不出来**。
## 进阶选择器尤其如此：它有三个并排卡片 + 每个卡片内两行小字，
## 布局问题（比如"进阶 10"的说明文字被卡片截断）只能渲染一帧才发现。
##
## 用法：
##   <godot> -s tools/shot_ui.gd --path <proj> -- <ui> <out.png> [ascension_level]
##
## 例：角色选择面板（带进阶选择器）
##   <godot> -s tools/shot_ui.gd --path <proj> -- character_select out.png 7
##
## ⚠️ 必须用**带窗口**的方式跑（不能 --headless），否则 `get_texture().get_image()`
## 拿到的是空图。
##
## ⚠️ Autoload 在 `-s` 独立脚本模式下**不注册**（D25 同源问题），
## 所以只能 `root.get_node_or_null("/root/Xxx")` 运行时取。

var _ui: StringName = &"character_select"
var _out_path: String = "user://shot_ui.png"
## 用哪个进阶等级渲染（用来验证说明文字不会溢出卡片）
var _level: int = 0
var _frames: int = 0
var _booted: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 1:
		_ui = StringName(args[0])
	if args.size() >= 2:
		_out_path = args[1]
	if args.size() >= 3:
		_level = int(args[2])


func _boot() -> void:
	var registry: Node = root.get_node_or_null("/root/ContentRegistry")
	if registry == null:
		push_error("找不到 ContentRegistry Autoload——请确认用 --path 指向项目根目录")
		quit(1)
		return
	registry.call("load_all")

	var meta: Node = root.get_node_or_null("/root/MetaState")
	if meta == null:
		push_error("找不到 MetaState Autoload")
		quit(1)
		return
	# 解锁到指定等级，这样选择器能显示出"已解锁"的样子
	# （全 0 的话左右箭头都是灰的，看不出布局问题）
	meta.call("reset")
	meta.call("record_ascension_clear", &"warrior", _level)
	meta.call("record_ascension_clear", &"mage", _level)
	meta.call("record_ascension_clear", &"hunter", _level)

	# ⚠️ 用 `load()` 拿脚本，**不能**直接写 `CharacterSelectPanel.new()`：
	# `-s` 独立脚本模式下全局 class_name 注册表不可用，
	# 会报「Nonexistent function 'new' in base 'GDScript'」——指向完全无关的地方。
	var script: GDScript = load("res://scripts/ui/character_select_panel.gd") as GDScript
	if script == null:
		push_error("找不到角色选择面板脚本")
		quit(1)
		return
	var panel: Control = script.new() as Control
	panel.call("setup")
	root.add_child(panel)
	# OverlayPanel 是铺满全屏的遮罩 + 居中卡片，给足尺寸才能看到完整布局
	panel.size = Vector2(1280, 720)

	# 把每个角色的选择器拨到指定等级——**这一步才是这个工具的重点**：
	# 进阶 10 的说明文字有 10 行，卡片高度是固定的，
	# 溢出/裁切只有渲染出来才看得见（`_effect_summary` 本身永远返回正确字符串）。
	for character: StringName in [&"warrior", &"mage", &"hunter"]:
		for _i: int in _level:
			panel.call("_on_level_step", character, 1)


func _process(_delta: float) -> bool:
	_frames += 1
	if not _booted:
		_booted = true
		_boot()
		return false

	# 等几帧：让 _ready 跑完、布局稳定、字体上传到 GPU
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
