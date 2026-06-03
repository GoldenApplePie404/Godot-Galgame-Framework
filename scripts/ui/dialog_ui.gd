# dialog_ui.gd
# 简单对话UI控制器
extends Control

const DialogManager = preload("res://autoload/DialogManager.gd")
const EventBus = preload("res://autoload/EventBus.gd")
const ChoiceMenuScene = preload("res://scenes/ui/choice_menu.tscn")
const CharacterRendererScene = preload("res://scenes/ui/character_renderer.tscn")

@onready var background: TextureRect = $BackgroundLayer/Background
@onready var speaker_label: Label = $VBoxContainer/SpeakerLabel
@onready var text_label: Label = $VBoxContainer/TextLabel
@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var menu_button: Button = $MenuButton

# 背景ID到文件路径的映射
const BACKGROUND_MAP = {
	"bg_1": "res://resources/backgrounds/bg1.png",
	"bg_2": "res://resources/backgrounds/bg2.png",
	"bg_3": "res://resources/backgrounds/bg3.png",
	"bg_4": "res://resources/backgrounds/bg4.png",
	"bg_5": "res://resources/backgrounds/bg5.png",
}

# ── 分层立绘系统 ──────────────────────────────────────
# 左右固定槽位
@onready var left_character_container: Node2D = $CharacterLayer/LeftCharacter
@onready var left_character_label: Label = $CharacterLayer/LeftCharacter/LeftCharacterLabel
@onready var right_character_container: Node2D = $CharacterLayer/RightCharacter
@onready var right_character_label: Label = $CharacterLayer/RightCharacter/RightCharacterLabel

# 渲染器字典：{"left": CharacterRenderer, "right": CharacterRenderer}
# 用字典替代 @onready，避免引用失效的问题
var _side_renderers: Dictionary = {
	"left": null,
	"right": null,
}

## 获取指定侧的渲染器（首次调用时从场景获取或动态创建）
func _get_side_renderer(side: String) -> CharacterRenderer:
	if _side_renderers.has(side) and _side_renderers[side] != null:
		return _side_renderers[side]
	
	var container := left_character_container if side == "left" else right_character_container
	if container == null:
		return null
	
	# 先看场景里有没有实例
	var existing := container.get_node_or_null("Renderer") as CharacterRenderer
	if existing:
		_side_renderers[side] = existing
		return existing
	
	# 没有就动态创建
	var new_renderer := CharacterRendererScene.instantiate()
	new_renderer.name = "Renderer"
	container.add_child(new_renderer)
	_side_renderers[side] = new_renderer
	print("[DialogUI] 动态创建 %s 侧渲染器" % side)
	return new_renderer

# 当前角色归属（哪个角色在哪个侧）
var _character_side: Dictionary = {}  # character_id → "left"/"right"

var is_visible: bool = false

# 分支选择菜单（模块化场景，运行时实例化）
var _choice_menu: Control = null

# ── 打字机动画相关 ──────────────────────────────────────
var _typewriter_tween: Tween = null   # 当前逐字 Tween
var _full_text: String = ""           # 当前句子完整文本
const CHARS_PER_SECOND: float = 30.0 # 打字速度（字/秒）

# 角色位置映射（根据角色设定）
var character_side_map = {
	"雪乃": "left",      
	"晓霜": "left",      
	"玲音": "right",    
	"夜雨": "right",     
	"星河": "right",    
	"夏奈": "left",
	"GAP": "left",
	"金苹果派": "left",      
}

# 就绪
func _ready() -> void:
	# 预热两侧渲染器（自动从场景获取或动态创建）
	_get_side_renderer("left")
	_get_side_renderer("right")
	
	print("DialogUI: 节点初始化检查")
	print("  background: ", background)
	print("  left_character_container: ", left_character_container)
	print("  right_character_container: ", right_character_container)
	print("  left_renderer: ", _side_renderers.get("left"))
	print("  right_renderer: ", _side_renderers.get("right"))
	print("  speaker_label: ", speaker_label)
	print("  text_label: ", text_label)
	print("  continue_button: ", continue_button)

	# 初始状态：隐藏角色占位符，但保持 UI 可见（等待对话开始信号）
	# 注意：不在此处调用 hide_ui()，否则若信号连接失败 UI 将永远不可见
	hide_all_characters()

	# 连接按钮信号；禁用键盘焦点避免与 _unhandled_input 双重触发
	if continue_button:
		continue_button.focus_mode = Control.FOCUS_NONE
		continue_button.pressed.connect(_on_continue_pressed)
	else:
		push_warning("DialogUI: continue_button 为空，无法连接信号")
	
	if menu_button:
		menu_button.pressed.connect(_on_menu_button_pressed)
	else:
		push_warning("DialogUI: menu_button 为空")

	# 连接 DialogManager 信号
	# 因为 DialogManager 是 Autoload，_ready() 时已经存在于场景树
	# 直接通过 get_node 获取，比依赖静态 instance 更可靠
	var dm = get_node_or_null("/root/DialogManager")
	if dm:
		dm.dialog_line_changed.connect(_on_dialog_line_changed)
		dm.dialog_started.connect(_on_dialog_started)
		dm.dialog_ended.connect(_on_dialog_ended)
		dm.choice_triggered.connect(_on_choice_triggered)
		dm.text_animation_skip.connect(_on_text_animation_skip)
		print("DialogUI: 已连接 DialogManager 信号")
	elif DialogManager.instance:
		DialogManager.instance.dialog_line_changed.connect(_on_dialog_line_changed)
		DialogManager.instance.dialog_started.connect(_on_dialog_started)
		DialogManager.instance.dialog_ended.connect(_on_dialog_ended)
		DialogManager.instance.choice_triggered.connect(_on_choice_triggered)
		DialogManager.instance.text_animation_skip.connect(_on_text_animation_skip)
		print("DialogUI: 已通过静态实例连接 DialogManager 信号")
	else:
		push_warning("DialogUI: DialogManager instance not found，信号未连接")

	# 订阅事件
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.subscribe("background_changed", _on_background_changed)
		eb.subscribe("character_pose_changed", _on_character_pose_changed)
		eb.subscribe("character_expression_changed", _on_character_expression_changed)
		eb.subscribe("character_performance_changed", _on_character_performance_changed)
		eb.subscribe("character_flipped", _on_character_flipped)
		eb.subscribe("character_side_changed", _on_character_side_changed)
		eb.subscribe("character_scale_changed", _on_character_scale_changed)
		print("DialogUI: 已订阅 EventBus 事件")
	elif EventBus.instance:
		EventBus.instance.subscribe("background_changed", _on_background_changed)
		EventBus.instance.subscribe("character_pose_changed", _on_character_pose_changed)
		EventBus.instance.subscribe("character_expression_changed", _on_character_expression_changed)
		EventBus.instance.subscribe("character_performance_changed", _on_character_performance_changed)
		EventBus.instance.subscribe("character_flipped", _on_character_flipped)
		EventBus.instance.subscribe("character_side_changed", _on_character_side_changed)
		EventBus.instance.subscribe("character_scale_changed", _on_character_scale_changed)
		print("DialogUI: 已通过静态实例订阅 EventBus 事件")
	else:
		push_warning("DialogUI: EventBus 未找到，事件订阅失败")

	# 实例化分支选择菜单
	_choice_menu = ChoiceMenuScene.instantiate()
	add_child(_choice_menu)
	_choice_menu.option_selected.connect(_on_choice_selected)

# 显示UI
func show_ui() -> void:
	show()
	is_visible = true

# 隐藏UI
func hide_ui() -> void:
	hide()
	is_visible = false

# 隐藏所有角色占位符
func hide_all_characters() -> void:
	if left_character_container:
		left_character_container.hide()
	if right_character_container:
		right_character_container.hide()

# 角色ID映射（中文名 → 资源目录名）
var _character_id_map = {
	"雪乃": "xuena", "snow": "xuena",
	"玲音": "lingyin", "lin": "lingyin",
	"晓霜": "xiaoshuang", "xiaoshuang": "xiaoshuang",
	"夜雨": "yeyu", "yeyu": "yeyu",
	"星河": "xinghe", "xinghe": "xinghe",
	"夏奈": "xinghe", "xianai": "xinghe",
	"GAP": "gap", "gap": "gap", "金苹果派": "gap",
}

# 角色数据缓存（避免重复加载 CharacterData Resource）
var _character_data_cache: Dictionary = {}  # dir_name → CharacterData

## 获取角色的 CharacterData
func _get_character_data(character_name_or_id: String) -> CharacterData:
	var dir: String = _character_id_map.get(character_name_or_id, character_name_or_id)
	
	if _character_data_cache.has(dir):
		return _character_data_cache[dir]
	
	var path: String = "res://resources/characters/%s/character.tres" % dir
	var data: CharacterData = load(path) as CharacterData if ResourceLoader.exists(path) else null
	if data:
		_character_data_cache[dir] = data
	else:
		push_warning("DialogUI: 未找到角色配置: %s" % path)
	return data


# 显示左侧角色（首次出现带滑入动画）
func show_left_character(character_name: String = "") -> void:
	if left_character_container:
		left_character_container.show()
	if right_character_container:
		right_character_container.hide()
	
	if not character_name.is_empty():
		var char_dir: String = _get_character_dir(character_name)
		var prev_side: String = _character_side.get(char_dir, "")
		var is_new: bool = (prev_side != "left")
		_character_side[char_dir] = "left"
		
		if left_character_label:
			left_character_label.text = character_name
		
		if is_new:
			var renderer := _get_side_renderer("left")
			var data: CharacterData = _get_character_data(character_name)
			if renderer and data:
				renderer.setup(data)
				renderer.set_flip_h(false)
				renderer.play_slide_in(true)


# 显示右侧角色（首次出现带滑入动画）
func show_right_character(character_name: String = "") -> void:
	if right_character_container:
		right_character_container.show()
	if left_character_container:
		left_character_container.hide()
	
	if not character_name.is_empty():
		var char_dir: String = _get_character_dir(character_name)
		var prev_side: String = _character_side.get(char_dir, "")
		var is_new: bool = (prev_side != "right")
		_character_side[char_dir] = "right"
		
		if right_character_label:
			right_character_label.text = character_name
		
		if is_new:
			var renderer := _get_side_renderer("right")
			var data: CharacterData = _get_character_data(character_name)
			if renderer and data:
				renderer.setup(data)
				renderer.set_flip_h(true)
				renderer.play_slide_in(false)

# 获取角色对应的资源目录名
func _get_character_dir(name: String) -> String:
	return _character_id_map.get(name, name.to_lower())

# 更新角色显示（根据说话者）
func update_character_display(speaker: String) -> void:
	if speaker.is_empty():
		hide_all_characters()
		return
	
	# 先查_character_side缓存（@char_side等指令可能改变了角色位置）
	var char_dir: String = _get_character_dir(speaker)
	var cached_side: String = _character_side.get(char_dir, "")
	
	var side: String
	if not cached_side.is_empty():
		side = cached_side
	else:
		side = character_side_map.get(speaker, "left")
	
	if side == "left":
		show_left_character(speaker)
	else:
		show_right_character(speaker)

# ── 立绘姿态/表情控制 ──────────────────────────────────

## 切换指定角色的身体姿态（供 @pose 指令调用）
func set_character_pose(character_id: String, pose_name: String) -> void:
	var renderer := _get_character_renderer(character_id)
	if renderer:
		renderer.set_pose(pose_name)
	else:
		push_warning("DialogUI: 角色 %s 不在场，无法切换姿态" % character_id)

## 切换指定角色的面部表情（供 @expression 指令调用）
func set_character_expression(character_id: String, expression_name: String) -> void:
	var renderer := _get_character_renderer(character_id)
	if renderer:
		renderer.set_expression(expression_name)
	else:
		push_warning("DialogUI: 角色 %s 不在场，无法切换表情" % character_id)

## 切换为表演整图（供 @perform 指令调用）
## 若角色不在场，自动显示角色
var _perform_recursion_depth: int = 0

func set_character_performance(character_id: String, performance_name: String) -> void:
	var renderer := _get_character_renderer(character_id)
	if renderer:
		renderer.set_performance(performance_name)
		_perform_recursion_depth = 0
		return
	
	# 递归防护
	_perform_recursion_depth += 1
	if _perform_recursion_depth > 3:
		push_error("[DialogUI] set_character_performance 递归过深！字符 %s 可能无法显示" % character_id)
		_perform_recursion_depth = 0
		return
	
	# 角色不在场 → 自动登台，左侧优先
	_auto_show_character(character_id)
	set_character_performance(character_id, performance_name)


## 自动将角色显示在场景上（供 @perform 等指令自动调用）
func _auto_show_character(character_id: String) -> void:
	var data: CharacterData = _get_character_data(character_id)
	if data == null:
		return
	
	var side := "left"
	if character_side_map.get(data.display_name, "left") == "right":
		side = "right"
	
	var container := left_character_container if side == "left" else right_character_container
	var label := left_character_label if side == "left" else right_character_label
	var other_container := right_character_container if side == "left" else left_character_container
	var renderer := _get_side_renderer(side)
	
	if container:
		container.show()
	if other_container:
		other_container.hide()
	
	if label:
		label.text = data.display_name
	
	if renderer:
		renderer.setup(data)
		renderer.set_flip_h(side == "right")
		renderer.play_slide_in(side == "left")
	
	_character_side[character_id] = side

# 更新对话行
func update_dialog_line(speaker: String, text: String) -> void:
	if not is_visible:
		show_ui()
	
	# 更新角色显示
	update_character_display(speaker)
	
	# 更新说话者标签
	if speaker_label:
		if speaker.is_empty():
			speaker_label.text = ""
		else:
			speaker_label.text = "%s：" % speaker
	else:
		push_warning("DialogUI: speaker_label 为空，无法更新说话者标签")
	
	# 启动打字机动画
	_start_typewriter(text)

# 打字机动画
func _start_typewriter(full_text: String) -> void:
	_full_text = full_text
	
	# 停止上一句残留的 Tween
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	
	if not text_label:
		push_warning("DialogUI: text_label 为空，无法启动打字机动画")
		_notify_animation_done()
		return
	
	# 清空文本，准备逐字填入
	text_label.text = ""
	
	# 计算动画时长（按字符数 / 速度）
	var duration: float = float(full_text.length()) / CHARS_PER_SECOND
	if duration <= 0.0:
		# 空文本直接完成
		text_label.text = full_text
		_notify_animation_done()
		return
	
	# 用 Tween 驱动一个 0→length 的整数，每帧截取子串
	_typewriter_tween = create_tween()
	var counter = {"value": 0}
	_typewriter_tween.tween_method(
		_typewriter_step.bind(full_text),
		0,
		full_text.length(),
		duration
	)
	_typewriter_tween.finished.connect(_on_typewriter_finished, CONNECT_ONE_SHOT)

# Tween 每步回调：更新 Label 显示前 n 个字符
func _typewriter_step(n: int, full_text: String) -> void:
	if text_label:
		text_label.text = full_text.substr(0, n)

# 打字机动画自然播完
func _on_typewriter_finished() -> void:
	if text_label:
		text_label.text = _full_text   # 确保末尾完整
	_notify_animation_done()

# 通知 DialogManager 动画已完成
func _notify_animation_done() -> void:
	var dm = _get_dialog_manager()
	if dm:
		dm.notify_text_animation_finished()

# 跳过动画（DialogManager 发出 text_animation_skip 信号时调用）
func _on_text_animation_skip() -> void:
	# 停止 Tween，立即显示完整文本
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
		_typewriter_tween = null
	if text_label:
		text_label.text = _full_text
	# 此时 DialogManager 已把 is_text_animating 置为 false，无需再调 notify
	print("DialogUI: 打字机动画已跳过")

# 兼容旧调用（无需改动调用方）
func complete_text_animation() -> void:
	_on_text_animation_skip()

# ============================================================
# 信号处理
# ============================================================

# 对话行变化
func _on_dialog_line_changed(speaker: String, text: String) -> void:
	update_dialog_line(speaker, text)

# 对话开始
func _on_dialog_started(chapter_name: String) -> void:
	print("DialogUI: 对话开始 - %s" % chapter_name)
	show_ui()

# 对话结束
func _on_dialog_ended() -> void:
	print("DialogUI: 对话结束")
	hide_ui()
	hide_all_characters()
	if _choice_menu:
		_choice_menu.hide_choice()

# 获取 DialogManager（优先走 Autoload 节点路径）
func _get_dialog_manager() -> Node:
	var dm = get_node_or_null("/root/DialogManager")
	if dm:
		return dm
	return DialogManager.instance

# 选择触发
func _on_choice_triggered(options: Array[String], prompt: String = "") -> void:
	print("DialogUI: 选择触发 - %s" % str(options))
	if _choice_menu:
		_choice_menu.show_choice(options, prompt)


# 选择完成（用户点击了某个选项）
func _on_choice_selected(index: int) -> void:
	print("DialogUI: 用户选择了选项 %d" % index)
	var dm = _get_dialog_manager()
	if dm:
		dm.select_choice(index)

# 背景变更处理
func _on_background_changed(data: Dictionary) -> void:
	var bg_id = data.get("background", "")
	if bg_id.is_empty():
		push_warning("DialogUI: background_changed 事件缺少 background 字段")
		return
	
	var bg_path = BACKGROUND_MAP.get(bg_id, "")
	if bg_path.is_empty():
		push_warning("DialogUI: 未找到背景映射: %s" % bg_id)
		return
	
	if not background:
		push_warning("DialogUI: background 节点为空，无法切换背景")
		return
	
	var texture = load(bg_path)
	if texture:
		background.texture = texture
		print("DialogUI: 背景已切换至 %s (%s)" % [bg_id, bg_path])
	else:
		push_warning("DialogUI: 无法加载背景纹理: %s" % bg_path)

# 继续按钮按下
func _on_continue_pressed() -> void:
	get_viewport().set_input_as_handled()  # 防止事件穿透到 _unhandled_input
	var dm = _get_dialog_manager()
	if dm and dm.get_state() == 1:  # PLAYING = 1
		dm.next_line()
	else:
		print("DialogUI: 没有活动对话")


## 左上角菜单按钮：效果同按 ESC
func _on_menu_button_pressed() -> void:
	var menu = get_node_or_null("/root/Main/MenuLayer/Menu")
	if menu and menu.has_method("_toggle_menu"):
		menu._toggle_menu()
	else:
		push_warning("DialogUI: 找不到 Menu 场景")

# ── 姿态/表情事件处理 ──────────────────────────────────

func _on_character_pose_changed(data: Dictionary) -> void:
	var char_id: String = data.get("character_id", "")
	var pose: String = data.get("pose", "")
	if not char_id.is_empty() and not pose.is_empty():
		set_character_pose(char_id, pose)

func _on_character_expression_changed(data: Dictionary) -> void:
	var char_id: String = data.get("character_id", "")
	var expression: String = data.get("expression", "")
	if not char_id.is_empty() and not expression.is_empty():
		set_character_expression(char_id, expression)

func _on_character_performance_changed(data: Dictionary) -> void:
	var char_id: String = data.get("character_id", "")
	var performance: String = data.get("performance", "")
	if not char_id.is_empty() and not performance.is_empty():
		set_character_performance(char_id, performance)

func _on_character_flipped(data: Dictionary) -> void:
	var char_id: String = data.get("character_id", "")
	flip_character(char_id)

func _on_character_side_changed(data: Dictionary) -> void:
	var char_id: String = data.get("character_id", "")
	var side: String = data.get("side", "left")
	print("[DialogUI] 移动角色: %s → %s" % [char_id, side])
	
	# 隐藏另一侧
	var other_container := right_character_container if side == "left" else left_character_container
	if other_container:
		other_container.hide()
	
	# 获取目标侧渲染器（自动创建）
	var renderer := _get_side_renderer(side)
	if renderer == null:
		return
	
	var data_res: CharacterData = _get_character_data(char_id)
	if data_res == null:
		return
	
	var container := left_character_container if side == "left" else right_character_container
	var label := left_character_label if side == "left" else right_character_label
	
	if container:
		container.show()
	if label:
		label.text = data_res.display_name
	
	renderer.setup(data_res)
	renderer.set_flip_h(side == "right")
	renderer.position = Vector2.ZERO
	renderer.modulate.a = 1.0
	
	_character_side[char_id] = side
	print("[DialogUI] 完成，角色 %s 现在在 %s 侧" % [char_id, side])

func _on_character_scale_changed(data: Dictionary) -> void:
	var char_id: String = data.get("character_id", "")
	var factor: float = data.get("scale", 1.0)
	print("[DialogUI] 缩放角色: %s × %.2f" % [char_id, factor])
	var renderer := _get_character_renderer(char_id)
	if renderer:
		renderer.set_scale_override(factor)
	else:
		push_warning("[DialogUI] 角色 %s 不在场，无法缩放" % char_id)

func flip_character(character_id: String) -> void:
	var renderer: CharacterRenderer = _get_character_renderer(character_id)
	if renderer:
		var is_flipped: bool = renderer.scale.x < 0
		renderer.set_flip_h(not is_flipped)


## 将角色移动到指定侧（@char_side 指令）
func move_character_to_side(character_id: String, side: String) -> void:
	print("[DialogUI] move: %s → %s" % [character_id, side])
	
	var data: CharacterData = _get_character_data(character_id)
	if data == null:
		return
	
	# 隐藏所有角色
	if left_character_container:
		left_character_container.hide()
	if right_character_container:
		right_character_container.hide()
	_character_side.erase(character_id)
	
	# 用现有的显示函数处理
	var display_name: String = data.display_name
	if side == "left":
		show_left_character(display_name)
	else:
		show_right_character(display_name)
	
	# 翻转处理（右侧角色面朝左）
	var renderer := _get_side_renderer(side)
	if renderer and side == "right":
		renderer.set_flip_h(true)


## 根据角色ID获取对应的渲染器
func _get_character_renderer(character_id: String) -> CharacterRenderer:
	var side: String = _character_side.get(character_id, "")
	if side.is_empty():
		return null
	return _get_side_renderer(side)

# ============================================================
# 立绘动画辅助（方案A：Node2D 自由控制）
# ============================================================

# 立绘从屏幕外滑入（x方向，duration秒）
func slide_in_character(node: Node2D, from_left: bool = true, duration: float = 0.3) -> void:
	if not node:
		return
	var screen_w = get_viewport_rect().size.x
	var original_pos = node.position
	node.position.x = -200.0 if from_left else screen_w + 200.0
	node.show()
	var tween = create_tween()
	tween.tween_property(node, "position:x", original_pos.x, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# 立绘滑出并隐藏
func slide_out_character(node: Node2D, to_left: bool = true, duration: float = 0.2) -> void:
	if not node:
		return
	var screen_w = get_viewport_rect().size.x
	var target_x = -200.0 if to_left else screen_w + 200.0
	var tween = create_tween()
	tween.tween_property(node, "position:x", target_x, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	node.hide()

# 测试方法：模拟对话显示
func test_display() -> void:
	print("DialogUI: 测试显示")
	update_dialog_line("雪乃", "早上好，今天天气真不错呢。")
	
	# 3秒后隐藏
	var timer = get_tree().create_timer(3.0)
	await timer.timeout
	hide_ui()
	print("DialogUI: 测试完成")

# 测试方法：测试角色切换
func test_character_switching() -> void:
	print("DialogUI: 测试角色切换")
	
	# 测试左侧角色
	update_dialog_line("雪乃", "我是雪乃，在左侧显示。")
	await get_tree().create_timer(1.5).timeout
	
	# 测试右侧角色
	update_dialog_line("玲音", "我是玲音，在右侧显示。")
	await get_tree().create_timer(1.5).timeout
	
	# 测试另一个左侧角色
	update_dialog_line("晓霜", "哼，我才不是特意来跟你说话的！")
	await get_tree().create_timer(1.5).timeout
	
	# 测试另一个右侧角色
	update_dialog_line("夜雨", "...（沉默地看着你）")
	await get_tree().create_timer(1.5).timeout
	
	# 隐藏
	hide_ui()
	print("DialogUI: 角色切换测试完成")
