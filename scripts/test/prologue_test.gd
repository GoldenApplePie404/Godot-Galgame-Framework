# prologue_test.gd
# 序章对话测试脚本

extends Node

# 注意：直接用 Autoload 节点路径，不用 preload + 静态变量
# 因为 Autoload 节点在 /root/DialogManager，这是最可靠的访问方式

@onready var dialog_ui: Control = $CanvasLayer/DialogUI

func _get_dm() -> Node:
	return get_node("/root/DialogManager")

func _ready() -> void:
	print("=== 序章对话测试开始 ===")
	
	# 等待一帧确保所有节点就绪
	await get_tree().process_frame
	
	var dm = _get_dm()
	if dm == null:
		push_error("找不到 DialogManager Autoload！")
		return
	
	# 加载序章对话脚本
	var script_path = "res://resources/scripts/prologue_chapter1.txt"
	print("脚本路径: ", script_path)
	print("文件存在: ", FileAccess.file_exists(script_path))
	
	if not dm.load_dialog_script(script_path):
		push_error("无法加载对话脚本: " + script_path)
		return
	print("对话脚本加载成功: " + script_path)
	
	# 开始对话
	dm.start_dialog("start")
	print("对话已开始，等待用户交互...")

# 键盘 Enter/Space 也可以推进对话（备用，主要用 ContinueButton）
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var dm = _get_dm()
		if dm == null:
			return
		var state = dm.get_state()
		# 使用 int 比较，避免跨脚本枚举引用问题
		if state == 1:  # PLAYING = 1
			dm.next_line()
			print("下一句对话")
		elif state == 0:  # IDLE = 0
			dm.start_dialog("start")
			print("重新开始对话")
