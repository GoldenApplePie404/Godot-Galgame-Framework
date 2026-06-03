# choice_menu.gd
extends Control

signal option_selected(index: int)

const ChoiceButtonScene := preload("res://scenes/ui/choice_button.tscn")

@onready var prompt_label: Label = $"%PromptLabel"
@onready var button_container: VBoxContainer = $"%ButtonContainer"
@onready var h_separator: HSeparator = $"%HSeparator"
@onready var overlay: ColorRect = $Overlay

var _buttons: Array[Button] = []


func _ready() -> void:
	hide()


## 显示选择菜单
## [param prompt] 可选的提示文本（显示在选项上方）
func show_choice(options: Array[String], prompt: String = "") -> void:
	# 清空所有子节点（包括场景编辑器里的占位按钮）
	_clear_button_container()
	
	# 显示提示文本
	if prompt.is_empty():
		prompt_label.hide()
		h_separator.hide()
	else:
		prompt_label.text = prompt
		prompt_label.show()
		h_separator.show()
	
	# 为每个选项创建按钮
	for i in options.size():
		var btn := _make_choice_button(options[i], i)
		_buttons.append(btn)
		button_container.add_child(btn)
	
	show()


## 隐藏选择菜单
func hide_choice() -> void:
	_clear_button_container()
	hide()


func _clear_button_container() -> void:
	# 清除 ButtonContainer 下所有子节点
	# 包括：运行时生成的按钮 + 场景编辑器里的占位按钮
	for child in button_container.get_children():
		if child and child.get_parent():
			child.queue_free()
	_buttons.clear()


func _make_choice_button(text: String, index: int) -> Button:
	var btn := ChoiceButtonScene.instantiate() as Button
	if btn == null:
		push_error("choice_menu: 无法实例化 choice_button 场景")
		return Button.new()
	
	btn.text = text
	
	# 点击时发射信号
	btn.pressed.connect(_on_button_pressed.bind(index))
	
	return btn


func _on_button_pressed(index: int) -> void:
	get_node("/root/AudioManager").play_sfx("ui_confirm")
	option_selected.emit(index)
	hide_choice()
