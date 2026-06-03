# TransitionManager.gd
# 转场管理器 — Autoload 单例
# 接收 DialogManager 的 @transition 指令，实例化对应转场场景
# 每个转场效果是独立的 .tscn 场景，实现模块化

extends Node

# 转场效果注册表 — 扩展只需在这里加一行 + 创建对应 .tscn
const TRANSITIONS := {
	"fade_to_black":    "res://scenes/effects/fade_to_black.tscn",
	"fade_from_black":  "res://scenes/effects/fade_from_black.tscn",
}


## 播放转场效果
## [param effect_name]  效果名称（对应 TRANSITIONS 的 key）
## [param duration]     持续时间（秒），默认 1.0
## 返回一个信号，可用 await 等待转场完成
func play(effect_name: String, duration: float = 1.0) -> Signal:
	var scene_path: String = TRANSITIONS.get(effect_name, "")
	if scene_path.is_empty():
		push_error("TransitionManager: 未知转场效果 '%s'" % effect_name)
		return Signal()
	
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_error("TransitionManager: 无法加载转场场景 '%s'" % scene_path)
		return Signal()
	
	var instance: CanvasLayer = scene.instantiate() as CanvasLayer
	if instance == null:
		push_error("TransitionManager: 转场场景根节点不是 CanvasLayer")
		return Signal()
	
	get_tree().root.add_child(instance)
	
	if instance.has_method("play"):
		instance.call("play", duration)
		return instance.finished
	else:
		push_error("TransitionManager: 转场场景没有 play() 方法: %s" % scene_path)
		instance.queue_free()
		return Signal()
