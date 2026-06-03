# button_sfx.gd
# 按钮音效组件 — 挂载到包含 Button 子节点的父节点上
# 自动为所有 Button 子节点（递归）绑定点击/悬停音效

extends Node

## 点击音效名
@export var click_sfx: String = "ui_click"
## 悬停音效名
@export var hover_sfx: String = "ui_hover"

var _wired: Array[Node] = []


func _ready() -> void:
	var root := get_parent()
	_wire_buttons(root)


## 手动为动态创建的按钮绑定音效（用于运行时实例化的按钮）
func wire_node(node: Node) -> void:
	_wire_buttons(node)


## 递归搜索 Button 子节点并绑定音效
func _wire_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton and not child in _wired:
			_wired.append(child)
			child.pressed.connect(_on_button_pressed.bind(child))
			if child is Button and hover_sfx:
				child.mouse_entered.connect(_on_button_hover.bind(child))
		# 递归
		if child.get_child_count() > 0:
			_wire_buttons(child)


func _on_button_pressed(_btn: Button) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(click_sfx)
	else:
		push_warning("[ButtonSfx] AudioManager 未找到")


func _on_button_hover(_btn: Button) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx(hover_sfx)
