# character_renderer.gd
# 分层立绘渲染器 — 支持 Sprite2D 身体+表情叠加、Tween 过渡、微动动画、滑入滑出、表演整图
#
# 节点结构:
#   CharacterRenderer (Node2D)
#   ├── BodySprite (Sprite2D)       ← 身体姿态（脸部镂空）
#   ├── FaceSprite (Sprite2D)       ← 表情叠加层（通过 face_offset 定位）
#   └── PerformSprite (Sprite2D)    ← 表演整图（@perform 时显示，默认隐藏）
class_name CharacterRenderer
extends Node2D

signal pose_changed(pose_name: String)
signal expression_changed(expression_name: String)
signal performance_started(performance_name: String)
signal performance_ended()

## 角色的配置数据
var character_data: CharacterData = null

## 当前状态
var current_pose: String = "stand"
var current_expression: String = "normal"
var is_perform_mode: bool = false

@onready var body_sprite: Sprite2D = $BodySprite
@onready var face_sprite: Sprite2D = $FaceSprite
@onready var perform_sprite: Sprite2D = $PerformSprite

# ── 微动动画 ──────────────────────────────────────────
var _breathing_tween: Tween = null
var _blink_timer: Timer = null
var _is_blinking: bool = false

# 运行时缩放覆盖（@char_scale 指令动态调整）
var _scale_override: float = 1.0

# 呼吸参数
const BREATH_AMPLITUDE: float = 2.0
const BREATH_DURATION: float = 3.0

# 眨眼参数
const BLINK_INTERVAL_MIN: float = 2.5
const BLINK_INTERVAL_MAX: float = 5.0
const BLINK_DURATION: float = 0.1


func _ready() -> void:
	# 初始化 Sprite2D 默认居中
	body_sprite.centered = true
	face_sprite.centered = true
	perform_sprite.centered = true
	perform_sprite.hide()
	
	# 启动微动动画
	_start_breathing()
	_start_blinking()


## 绑定角色数据
func setup(data: CharacterData) -> void:
	character_data = data
	current_pose = "stand"
	current_expression = "normal"
	is_perform_mode = false
	
	# 重置位置和缩放（清除前一个角色的残留）
	position = Vector2.ZERO
	scale = Vector2.ONE
	modulate.a = 1.0
	
	if _has_layered_data():
		# 分层素材就绪 → 完整模式
		perform_sprite.hide()
		body_sprite.show()
		face_sprite.show()
		_update_body_texture()
		_update_face_texture()
		_auto_scale(body_sprite)
		_auto_scale(face_sprite)
	else:
		# 分层素材未就绪 → 降级到表演图（用已有的完整立绘）
		body_sprite.hide()
		face_sprite.hide()
		_show_first_performance()


## 检查是否有分层素材
func _has_layered_data() -> bool:
	if character_data == null:
		return false
	return not character_data.poses.is_empty() and not character_data.expressions.is_empty()


## 降级模式：显示第一张可用的表演整图
func _show_first_performance() -> void:
	if character_data == null:
		return
	var perf_names: Array[String] = character_data.get_performance_names()
	if perf_names.is_empty():
		push_warning("CharacterRenderer[%s]: 没有任何可用素材" % [character_data.character_id if character_data else "?"])
		return
	perform_sprite.texture = character_data.get_performance(perf_names[0])
	_auto_scale(perform_sprite)
	perform_sprite.modulate.a = 1.0
	perform_sprite.show()
	is_perform_mode = true


## 自动缩放 Sprite2D 到合适的画面占比
## 用 character_data.target_height * _scale_override 计算
func _auto_scale(sprite: Sprite2D) -> void:
	if sprite == null or sprite.texture == null:
		return
	var tex_w: float = sprite.texture.get_width()
	var tex_h: float = sprite.texture.get_height()
	if tex_w > 0 and tex_h > 0:
		var max_dim: float = max(tex_w, tex_h)
		# 目标高度优先从角色配置取，兜底 380
		var base: float = 380.0
		if character_data and character_data.target_height > 0:
			base = character_data.target_height
		var target: float = base * _scale_override
		var s: float = target / max_dim
		sprite.scale = Vector2(s, s)


## 设置运行时缩放覆盖（@char_scale 指令调用）
## 1.0 = 正常大小，>1 = 放大，<1 = 缩小
func set_scale_override(factor: float) -> void:
	_scale_override = factor
	# 立即重新缩放所有子 Sprite
	if not is_perform_mode:
		if body_sprite and body_sprite.texture:
			_auto_scale(body_sprite)
		if face_sprite and face_sprite.texture:
			_auto_scale(face_sprite)
	else:
		if perform_sprite and perform_sprite.texture:
			_auto_scale(perform_sprite)


## 切换身体姿态（带 Tween 淡入淡出）
func set_pose(pose_name: String, animated: bool = true) -> void:
	if not _has_layered_data():
		return  # 分层素材未就绪，静默跳过
	
	if character_data == null or not character_data.has_pose(pose_name):
		push_warning("CharacterRenderer[%s]: 未知姿态 '%s'" % [character_data.character_id if character_data else "?", pose_name])
		return
	
	if is_perform_mode:
		_exit_perform_mode()
	
	if current_pose == pose_name:
		return
	
	current_pose = pose_name
	
	if animated:
		_swap_texture_with_tween(body_sprite, character_data.get_pose(pose_name), 0.25)
	else:
		body_sprite.texture = character_data.get_pose(pose_name)
	
	pose_changed.emit(pose_name)


## 切换面部表情
func set_expression(expression_name: String, animated: bool = true) -> void:
	if not _has_layered_data():
		return  # 分层素材未就绪，静默跳过
	
	if character_data == null or not character_data.has_expression(expression_name):
		push_warning("CharacterRenderer[%s]: 未知表情 '%s'" % [character_data.character_id if character_data else "?", expression_name])
		return
	
	if is_perform_mode:
		_exit_perform_mode()
	
	if current_expression == expression_name:
		return
	
	current_expression = expression_name
	
	if animated:
		_swap_texture_with_tween(face_sprite, character_data.get_expression(expression_name), 0.15)
	else:
		face_sprite.texture = character_data.get_expression(expression_name)
	
	expression_changed.emit(expression_name)


## 切换为表演整图（隐藏 body+face，显示完整立绘）
func set_performance(performance_name: String) -> void:
	if character_data == null or not character_data.has_performance(performance_name):
		push_warning("CharacterRenderer[%s]: 未知表演 '%s'" % [character_data.character_id if character_data else "?", performance_name])
		return
	
	is_perform_mode = true
	perform_sprite.texture = character_data.get_performance(performance_name)
	_auto_scale(perform_sprite)
	perform_sprite.modulate.a = 0.0
	perform_sprite.show()
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(body_sprite, "modulate:a", 0.0, 0.2)
	tween.tween_property(face_sprite, "modulate:a", 0.0, 0.2)
	tween.tween_property(perform_sprite, "modulate:a", 1.0, 0.3)
	
	performance_started.emit(performance_name)


## 水平翻转（切换角色朝向）
func set_flip_h(flipped: bool) -> void:
	var sx: float = -abs(scale.x) if flipped else abs(scale.x)
	scale.x = sx


## 退出表演模式，恢复分层渲染
func exit_perform_mode(animated: bool = true) -> void:
	_exit_perform_mode(animated)


## 从画面滑入（出场动画）
func play_slide_in(from_left: bool = true, duration: float = 0.4) -> void:
	var start_x: float = -600.0 if from_left else 1200.0
	var target_x: float = position.x
	position.x = start_x
	modulate.a = 0.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", target_x, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, duration * 0.6)


## 滑出画面（退场动画）
func play_slide_out(to_left: bool = true, duration: float = 0.3) -> void:
	var target_x: float = -600.0 if to_left else 1200.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", target_x, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.5)
	await tween.finished
	hide()


# ── 私有方法 ──────────────────────────────────────────

func _update_body_texture() -> void:
	if character_data:
		body_sprite.texture = character_data.get_pose(current_pose)

func _update_face_texture() -> void:
	if character_data:
		face_sprite.texture = character_data.get_expression(current_expression)
		face_sprite.position = character_data.face_offset
		face_sprite.scale = character_data.face_scale


# 淡入淡出切换纹理
func _swap_texture_with_tween(sprite: Sprite2D, new_texture: Texture2D, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, duration * 0.4)
	tween.tween_callback(func():
		sprite.texture = new_texture
	)
	tween.tween_property(sprite, "modulate:a", 1.0, duration * 0.6)


# 退出表演模式
func _exit_perform_mode(animated: bool = true) -> void:
	if not is_perform_mode:
		return
	is_perform_mode = false
	
	if animated:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(perform_sprite, "modulate:a", 0.0, 0.2)
		tween.tween_property(body_sprite, "modulate:a", 1.0, 0.3)
		tween.tween_property(face_sprite, "modulate:a", 1.0, 0.3)
		tween.tween_callback(func():
			perform_sprite.hide()
		)
	else:
		perform_sprite.hide()
		body_sprite.modulate.a = 1.0
		face_sprite.modulate.a = 1.0
	
	performance_ended.emit()


# ── 微动动画 ──────────────────────────────────────────

# 呼吸：身体小幅上下浮动
func _start_breathing() -> void:
	_breathing_tween = create_tween().set_loops()
	_breathing_tween.tween_property(body_sprite, "offset:y", -BREATH_AMPLITUDE, BREATH_DURATION * 0.5).set_ease(Tween.EASE_IN_OUT)
	_breathing_tween.tween_property(body_sprite, "offset:y", BREATH_AMPLITUDE, BREATH_DURATION * 0.5).set_ease(Tween.EASE_IN_OUT)


# 眨眼：按随机间隔切换表情透明度
func _start_blinking() -> void:
	_blink_timer = Timer.new()
	_blink_timer.one_shot = true
	_blink_timer.timeout.connect(_do_blink)
	add_child(_blink_timer)
	_schedule_next_blink()


func _do_blink() -> void:
	if is_perform_mode:
		_schedule_next_blink()
		return
	
	# 闭眼：表情快速消失又出现
	var tween := create_tween()
	tween.tween_property(face_sprite, "modulate:a", 0.0, BLINK_DURATION)
	tween.tween_property(face_sprite, "modulate:a", 1.0, BLINK_DURATION)
	
	_schedule_next_blink()


func _schedule_next_blink() -> void:
	var interval: float = randf_range(BLINK_INTERVAL_MIN, BLINK_INTERVAL_MAX)
	_blink_timer.start(interval)


func _exit_tree() -> void:
	if _breathing_tween and _breathing_tween.is_valid():
		_breathing_tween.kill()
	if _blink_timer:
		_blink_timer.stop()
