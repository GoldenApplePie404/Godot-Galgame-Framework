# fade_from_black.gd
# 从黑渐变还原转场 — 画面从全黑逐渐恢复正常显示

extends CanvasLayer

signal finished

@onready var overlay: ColorRect = $ColorRect


func play(duration: float = 1.0) -> void:
	overlay.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	finished.emit()
	queue_free()
