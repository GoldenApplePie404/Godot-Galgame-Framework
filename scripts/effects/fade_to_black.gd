# fade_to_black.gd
# 渐变黑屏转场 — 画面从正常逐渐变为全黑
# 模块化设计：实例化后调用 play(duration)，完成后自动销毁

extends CanvasLayer

signal finished

@onready var overlay: ColorRect = $ColorRect


func play(duration: float = 1.0) -> void:
	overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, duration)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	finished.emit()
	queue_free()
