# confirm_popup.gd
# 存档确认弹窗 — 点击已有存档槽位时弹出
# 提供覆盖保存 / 读取存档 / 取消 三个操作

extends Control

signal save_pressed
signal load_pressed
signal cancel_pressed

const FONT := preload("res://resources/font/font.ttf")

@onready var confirm_label: Label = $"%ConfirmLabel"
@onready var save_btn: Button = $"%SaveBtn"
@onready var load_btn: Button = $"%LoadBtn"
@onready var cancel_btn: Button = $"%CancelBtn"
@onready var overlay: ColorRect = $Overlay


func _ready() -> void:
	_setup_button_style(save_btn, "覆 盖 保 存", Color(0.85, 0.35, 0.25))   # 珊瑚红
	_setup_button_style(load_btn, "读 取 存 档", Color(0.25, 0.55, 0.82))   # 天蓝
	_setup_button_style(cancel_btn, "取    消", Color(0.75, 0.5, 0.5))      # 浅玫瑰

	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)
	cancel_btn.pressed.connect(_on_cancel)

	hide()


func show_popup(text: String) -> void:
	confirm_label.text = text
	show()


func hide_popup() -> void:
	hide()


func _on_save() -> void:
	save_pressed.emit()
	hide_popup()


func _on_load() -> void:
	load_pressed.emit()
	hide_popup()


func _on_cancel() -> void:
	cancel_pressed.emit()
	hide_popup()


func _setup_button_style(btn: Button, text: String, tint: Color) -> void:
	btn.text = text
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_color_override("font_color", tint)
	btn.add_theme_color_override("font_hover_color", tint * 1.15)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(1, 1, 1, 1)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(tint, 0.4)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.content_margin_left = 14
	normal_style.content_margin_top = 8
	normal_style.content_margin_right = 14
	normal_style.content_margin_bottom = 8

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(tint, 0.06)
	hover_style.border_color = Color(tint, 0.8)

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
