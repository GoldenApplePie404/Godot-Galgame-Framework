# notification_popup.gd
# 可复用的通知弹窗 — 显示消息后自动动画消失
# 支持自定义字体、字号、字色、背景色、停留时间
class_name NotificationPopup
extends Panel

## 显示的文字
@export var message: String = ""
## 字体文件
@export var font: FontFile = null
## 字号
@export var font_size: int = 44
## 文字颜色
@export var font_color: Color = Color(0.969, 0.118, 0.0, 1.0)
## 背景色
@export var bg_color: Color = Color(0, 0, 0, 0.2)
## 描边色
@export var outline_color: Color = Color(0, 0, 0, 0.6)
## 描边粗细
@export var outline_size: int = 4
## 停留时间（秒）
@export var display_seconds: float = 2.0

## 播放完毕信号
signal finished


func _ready() -> void:
	# 全屏遮罩
	var vr := get_viewport_rect()
	set_position(Vector2.ZERO)
	set_size(vr.size)
	mouse_filter = MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_style())
	
	# 文字 — 用绝对坐标居中于视口
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	# 计算文本区域居中于视口
	var label_w: float = vr.size.x * 0.8
	var label_h: float = font_size * 2
	label.set_size(Vector2(label_w, label_h))
	label.set_position(Vector2(vr.size.x * 0.1, vr.size.y * 0.5 - label_h * 0.5))
	label.mouse_filter = MOUSE_FILTER_IGNORE
	
	add_child(label)
	
	# 遮罩淡入
	modulate.a = 0.0
	var tween_in := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween_in.tween_property(self, "modulate:a", 1.0, 0.25)
	
	# 文字弹入
	label.scale = Vector2(0.8, 0.8)
	var tween_bounce := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_bounce.tween_property(label, "scale", Vector2(1.0, 1.0), 0.35)
	
	# 停留后淡出
	var tween_out: Tween = create_tween()
	tween_out.tween_interval(display_seconds)
	tween_out.tween_property(self, "modulate:a", 0.0, 0.4)
	tween_out.tween_callback(func():
		finished.emit()
		queue_free()
	)


func _make_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	return style
