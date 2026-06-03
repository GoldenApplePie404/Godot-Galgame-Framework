# AchievementManager.gd
# 成就系统核心管理器
# 负责成就定义、进度追踪、解锁触发和UI反馈

extends Node

const EventBus = preload("res://autoload/EventBus.gd")

# 单例实例
static var instance

# 成就状态枚举
enum AchievementState {
	LOCKED,      # 未解锁
	UNLOCKED,    # 已解锁
	HIDDEN       # 隐藏（未发现）
}

# 成就数据结构
class Achievement:
	var id: String
	var name: String
	var description: String
	var icon_path: String
	var achievement_type: String  # story, affection, puzzle, collection
	var hidden: bool
	var conditions: Array        # 条件数组
	var reward: Dictionary       # 奖励数据
	var state: AchievementState = AchievementState.LOCKED
	var progress_current: float = 0.0
	var progress_target: float = 1.0
	var unlock_time: String = ""  # 解锁时间戳
	var is_new: bool = false      # 是否为新解锁（未查看）
	
	func _init(data: Dictionary):
		id = data.get("id", "")
		name = data.get("name", "")
		description = data.get("description", "")
		icon_path = data.get("icon", "")
		achievement_type = data.get("type", "story")
		hidden = data.get("hidden", false)
		conditions = data.get("conditions", [])
		reward = data.get("reward", {})
		
		if hidden:
			state = AchievementState.HIDDEN
	
	# 检查是否满足解锁条件
	func check_conditions() -> bool:
		# 如果已经解锁，直接返回true
		if state == AchievementState.UNLOCKED:
			return true
		
		# TODO: 根据条件类型检查
		# 这里需要实现具体的条件检查逻辑
		return false
	
	# 更新进度
	func update_progress(new_progress: float) -> void:
		progress_current = new_progress
		if progress_current >= progress_target:
			progress_current = progress_target
	
	# 解锁成就
	func unlock(unlock_time_str: String) -> void:
		if state != AchievementState.UNLOCKED:
			state = AchievementState.UNLOCKED
			unlock_time = unlock_time_str
			is_new = true
			print_debug("Achievement unlocked: %s" % name)
	
	# 获取进度百分比
	func get_progress_percentage() -> float:
		if progress_target <= 0:
			return 0.0
		return min(progress_current / progress_target, 1.0)
	
	# 获取显示状态文本
	func get_state_text() -> String:
		match state:
			AchievementState.LOCKED:
				return "未解锁"
			AchievementState.UNLOCKED:
				return "已解锁"
			AchievementState.HIDDEN:
				return "？？？"
			_:
				return "未知"

# 成就数据库
var _achievements: Dictionary = {}  # id -> Achievement实例
var _unlocked_count: int = 0
var _total_count: int = 0

# 信号
signal achievement_loaded(count: int)
signal achievement_unlocked(achievement_id: String, achievement_data: Dictionary)
signal achievement_progress_updated(achievement_id: String, progress: float, target: float)
signal achievement_new_status_changed(achievement_id: String, is_new: bool)

# 初始化
func _init() -> void:
	if instance == null:
		instance = self
	else:
		push_error("AchievementManager is a singleton! Multiple instances detected.")

# 就绪
func _ready() -> void:
	# 连接事件总线
	EventBus.subscribe_event(EventBus.Events.ACHIEVEMENT_UNLOCKED, _on_achievement_unlocked_event)
	EventBus.subscribe_event(EventBus.Events.AFFECTION_CHANGED, _on_affection_changed)
	EventBus.subscribe_event(EventBus.Events.CHAPTER_COMPLETED, _on_chapter_completed)
	EventBus.subscribe_event(EventBus.Events.GAME_LOADED, _on_game_loaded)

# 加载成就定义
func load_achievement_definitions(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("AchievementManager: Failed to load achievement definitions: %s" % file_path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("AchievementManager: Failed to parse JSON: %s" % json.get_error_message())
		return false
	
	var data = json.get_data()
	if not data.has("achievements"):
		push_error("AchievementManager: Invalid achievement data format")
		return false
	
	_achievements.clear()
	_unlocked_count = 0
	_total_count = 0
	
	for achievement_data in data["achievements"]:
		var achievement = Achievement.new(achievement_data)
		_achievements[achievement.id] = achievement
		_total_count += 1
		
		if achievement.state == AchievementState.UNLOCKED:
			_unlocked_count += 1
	
	print_debug("AchievementManager: Loaded %d achievements (%d unlocked)" % [_total_count, _unlocked_count])
	achievement_loaded.emit(_total_count)
	
	return true

# 检查并解锁成就
func check_and_unlock_achievements() -> void:
	var unlocked_any = false
	
	for achievement_id in _achievements:
		var achievement = _achievements[achievement_id]
		
		# 跳过已解锁的成就
		if achievement.state == AchievementState.UNLOCKED:
			continue
		
		# 检查条件
		if achievement.check_conditions():
			unlock_achievement(achievement_id)
			unlocked_any = true
	
	if unlocked_any:
		save_achievement_progress()

# 解锁指定成就
# [event_data] 可选，来自 DialogManager 的 @achievement unlock 指令，可含 achievement_name / achievement_description
func unlock_achievement(achievement_id: String, event_data: Dictionary = {}) -> bool:
	# 如果成就未定义，自动创建一个最小条目（方便测试和开发）
	if not _achievements.has(achievement_id):
		print("[AchievementManager] 成就 '%s' 未定义，自动创建最小条目" % achievement_id)
		# 如果指令中传了名称和描述，就用它们
		var ach_name: String = event_data.get("achievement_name", achievement_id)
		var ach_desc: String = event_data.get("achievement_description", "")
		var auto_ach := Achievement.new({
			"id": achievement_id,
			"name": ach_name,
			"description": ach_desc,
			"type": "story",
		})
		_achievements[achievement_id] = auto_ach
		_total_count += 1

	var achievement = _achievements[achievement_id]
	
	# 如果已经是解锁状态，仍发射弹窗事件（新实例需要显示）
	if achievement.state == AchievementState.UNLOCKED:
		EventBus.emit_event(EventBus.Events.UI_SHOW_ACHIEVEMENT_POPUP, {
			"id": achievement.id,
			"name": achievement.name,
			"description": achievement.description,
			"icon_path": achievement.icon_path,
			"unlock_time": achievement.unlock_time,
		})
		return true
	
	# 生成解锁时间戳
	var current_time = Time.get_datetime_string_from_system()
	
	# 解锁成就
	achievement.unlock(current_time)
	_unlocked_count += 1
	
	# 应用奖励
	_apply_reward(achievement.reward)
	
	# 发出信号
	var achievement_data = {
		"id": achievement.id,
		"name": achievement.name,
		"description": achievement.description,
		"icon_path": achievement.icon_path,
		"unlock_time": achievement.unlock_time
	}
	
	achievement_unlocked.emit(achievement_id, achievement_data)
	
	# 通过事件总线广播
	EventBus.emit_event(EventBus.Events.ACHIEVEMENT_UNLOCKED, {
		"achievement_id": achievement_id,
		"achievement_name": achievement.name,
		"unlock_time": achievement.unlock_time
	})
	
	# 显示UI弹窗
	EventBus.emit_event(EventBus.Events.UI_SHOW_ACHIEVEMENT_POPUP, achievement_data)
	
	print_debug("AchievementManager: Achievement unlocked - %s" % achievement.name)
	return true

# 更新成就进度
func update_achievement_progress(achievement_id: String, progress_delta: float = 1.0) -> bool:
	if not _achievements.has(achievement_id):
		push_warning("AchievementManager: Attempted to update progress for unknown achievement: %s" % achievement_id)
		return false
	
	var achievement = _achievements[achievement_id]
	
	# 如果已经解锁，不再更新进度
	if achievement.state == AchievementState.UNLOCKED:
		return false
	
	# 更新进度
	var old_progress = achievement.progress_current
	achievement.update_progress(old_progress + progress_delta)
	
	# 发出进度更新信号
	achievement_progress_updated.emit(
		achievement_id,
		achievement.progress_current,
		achievement.progress_target
	)
	
	# 检查是否达到目标
	if achievement.progress_current >= achievement.progress_target:
		unlock_achievement(achievement_id)
	
	return true

# 获取成就信息
func get_achievement(achievement_id: String) -> Dictionary:
	if not _achievements.has(achievement_id):
		return {}
	
	var achievement = _achievements[achievement_id]
	return {
		"id": achievement.id,
		"name": achievement.name,
		"description": achievement.description,
		"icon_path": achievement.icon_path,
		"state": achievement.state,
		"progress_current": achievement.progress_current,
		"progress_target": achievement.progress_target,
		"progress_percentage": achievement.get_progress_percentage(),
		"unlock_time": achievement.unlock_time,
		"is_new": achievement.is_new,
		"hidden": achievement.hidden
	}

# 获取所有成就列表
func get_all_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for achievement_id in _achievements:
		result.append(get_achievement(achievement_id))
	
	return result

# 获取已解锁成就列表
func get_unlocked_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for achievement_id in _achievements:
		var achievement = _achievements[achievement_id]
		if achievement.state == AchievementState.UNLOCKED:
			result.append(get_achievement(achievement_id))
	
	return result

# 获取成就统计
func get_statistics() -> Dictionary:
	return {
		"total": _total_count,
		"unlocked": _unlocked_count,
		"locked": _total_count - _unlocked_count,
		"completion_percentage": float(_unlocked_count) / float(_total_count) * 100.0 if _total_count > 0 else 0.0
	}

# 标记成就为已查看（清除新状态）
func mark_achievement_as_viewed(achievement_id: String) -> bool:
	if not _achievements.has(achievement_id):
		return false
	
	var achievement = _achievements[achievement_id]
	if achievement.is_new:
		achievement.is_new = false
		achievement_new_status_changed.emit(achievement_id, false)
		return true
	
	return false

# 保存成就进度
func save_achievement_progress() -> void:
	var save_data = {
		"version": "1.0",
		"timestamp": Time.get_datetime_string_from_system(),
		"achievements": {}
	}
	
	for achievement_id in _achievements:
		var achievement = _achievements[achievement_id]
		save_data["achievements"][achievement_id] = {
			"state": achievement.state,
			"progress_current": achievement.progress_current,
			"unlock_time": achievement.unlock_time,
			"is_new": achievement.is_new
		}
	
	# 这里应该调用存档系统保存数据
	print_debug("AchievementManager: Achievement progress saved")
	
	# 通过事件总线通知
	EventBus.emit_event("achievement_progress_saved", {
		"unlocked_count": _unlocked_count,
		"total_count": _total_count
	})

# 加载成就进度
func load_achievement_progress(progress_data: Dictionary) -> void:
	if not progress_data.has("achievements"):
		push_warning("AchievementManager: Invalid progress data format")
		return
	
	var achievements_data = progress_data["achievements"]
	
	for achievement_id in achievements_data:
		if _achievements.has(achievement_id):
			var achievement = _achievements[achievement_id]
			var data = achievements_data[achievement_id]
			
			# 恢复状态
			achievement.state = data.get("state", AchievementState.LOCKED)
			achievement.progress_current = data.get("progress_current", 0.0)
			achievement.unlock_time = data.get("unlock_time", "")
			achievement.is_new = data.get("is_new", false)
			
			if achievement.state == AchievementState.UNLOCKED:
				_unlocked_count += 1
	
	print_debug("AchievementManager: Achievement progress loaded")

# 重置所有成就（用于测试）
func reset_all_achievements() -> void:
	for achievement_id in _achievements:
		var achievement = _achievements[achievement_id]
		achievement.state = AchievementState.LOCKED
		if achievement.hidden:
			achievement.state = AchievementState.HIDDEN
		achievement.progress_current = 0.0
		achievement.unlock_time = ""
		achievement.is_new = false
	
	_unlocked_count = 0
	print_debug("AchievementManager: All achievements reset")

# ============================================================
# 私有方法
# ============================================================

# 应用成就奖励
func _apply_reward(reward: Dictionary) -> void:
	var reward_type = reward.get("type", "")
	
	match reward_type:
		"affection":
			var target = reward.get("target", "")
			var value = reward.get("value", 0)
			if target and value != 0:
				# 这里应该调用好感度系统增加好感度
				print_debug("AchievementManager: Reward - Affection +%d for %s" % [value, target])
				EventBus.emit_event("affection_increased", {
					"target": target,
					"amount": value
				})
		
		"unlock":
			var content = reward.get("content", "")
			if content:
				print_debug("AchievementManager: Reward - Unlock content: %s" % content)
				EventBus.emit_event("content_unlocked", {
					"content_id": content
				})
		
		"item":
			var item_id = reward.get("item_id", "")
			var quantity = reward.get("quantity", 1)
			if item_id:
				print_debug("AchievementManager: Reward - Item %s x%d" % [item_id, quantity])
				EventBus.emit_event("item_granted", {
					"item_id": item_id,
					"quantity": quantity
				})
		
		_:
			print_debug("AchievementManager: Unknown reward type: %s" % reward_type)

# 事件处理函数
func _on_achievement_unlocked_event(data: Dictionary) -> void:
	var achievement_id = data.get("achievement_id", "")
	if achievement_id:
		unlock_achievement(achievement_id, data)

func _on_affection_changed(data: Dictionary) -> void:
	# 检查好感度相关成就
	var target = data.get("target", "")
	var new_value = data.get("new_value", 0)
	
	# TODO: 实现好感度成就检查
	print_debug("AchievementManager: Affection changed for %s to %d" % [target, new_value])

func _on_chapter_completed(data: Dictionary) -> void:
	var chapter = data.get("chapter", 0)
	
	# 检查章节完成成就
	# TODO: 实现章节成就检查
	print_debug("AchievementManager: Chapter %d completed" % chapter)

func _on_game_loaded(data: Dictionary) -> void:
	# 游戏加载时恢复成就进度
	if data.has("achievement_data"):
		load_achievement_progress(data["achievement_data"])

# 测试用的便捷方法（开发完成后删除）
func _test_achievement_system() -> void:
	# 创建测试成就定义
	var test_achievements = {
		"achievements": [
			{
				"id": "test_first_lunch",
				"name": "第一次共进午餐",
				"description": "与雪乃一起享用午餐",
				"icon": "res://resources/achievements/lunch_icon.png",
				"type": "story",
				"hidden": false,
				"conditions": [
					{"type": "event_triggered", "event_id": "lunch_with_snow"}
				],
				"reward": {"type": "affection", "target": "snow", "value": 10}
			},
			{
				"id": "test_collector",
				"name": "收藏家",
				"description": "收集10个不同的物品",
				"icon": "res://resources/achievements/collector_icon.png",
				"type": "collection",
				"hidden": false,
				"conditions": [
					{"type": "collect_items", "item_count": 10}
				],
				"reward": {"type": "unlock", "content": "secret_cg_01"}
			}
		]
	}
	
	# 将测试数据写入临时文件
	var test_file = "res://resources/achievements/test_achievements.json"
	var file = FileAccess.open(test_file, FileAccess.WRITE)
	if file:
		var json = JSON.new()
		file.store_string(json.stringify(test_achievements, "  "))
		file.close()
		
		# 加载成就定义
		if load_achievement_definitions(test_file):
			print_debug("AchievementManager: Test achievements loaded")
		else:
			push_error("AchievementManager: Failed to load test achievements")
	else:
		push_error("AchievementManager: Failed to create test file")
