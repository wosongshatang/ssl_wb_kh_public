extends Node
## EventBus —— 跨场景信号总线（Autoload）
##
## 纪律（工程书 §2.2）：**只放真正跨场景的事件**。
## 场景内事件（例如「某张牌被打出」「某个敌人死亡」）请用场景或对象自己的信号，
## 不要往这里塞——否则总线会退化成垃圾场，且难以追踪事件来源。

## 一局开始（选角完成）
@warning_ignore("unused_signal")
signal run_started(character_class: StringName)

## 一局结束（ending_id: slay_god / ascend / mortal）
@warning_ignore("unused_signal")
signal run_ended(ending_id: StringName)

## 请求切换场景（由 Boot / Map / Battle 的流程层消费）
@warning_ignore("unused_signal")
signal scene_change_requested(scene_path: String)

## 推进到下一幕
@warning_ignore("unused_signal")
signal act_advanced(act_index: int)

## 神性 / 人性发生变化（供侵蚀进度条 UI 监听）
@warning_ignore("unused_signal")
signal erosion_changed(divinity: int, humanity: int)
