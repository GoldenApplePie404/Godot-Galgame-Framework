# EventBus.gd
# 全局事件总线系统，用于系统间解耦通信
# 使用发布-订阅模式，支持异步事件分发

extends Node

# 单例实例
static var instance

# 事件订阅者字典：事件名 -> 回调函数数组
var _subscribers: Dictionary = {}

# 初始化
func _init() -> void:
	if instance == null:
		instance = self
	else:
		push_error("EventBus is a singleton! Multiple instances detected.")

# 订阅事件
func subscribe(event_name: String, callback: Callable) -> void:
	if not _subscribers.has(event_name):
		_subscribers[event_name] = []
	
	# 避免重复订阅
	if not _subscribers[event_name].has(callback):
		_subscribers[event_name].append(callback)
		print_debug("EventBus: Subscribed to event '%s'" % event_name)

# 取消订阅
func unsubscribe(event_name: String, callback: Callable) -> void:
	if _subscribers.has(event_name):
		_subscribers[event_name].erase(callback)
		if _subscribers[event_name].is_empty():
			_subscribers.erase(event_name)
		print_debug("EventBus: Unsubscribed from event '%s'" % event_name)

# 发布事件（同步）
func emit(event_name: String, data: Dictionary = {}) -> void:
	if not _subscribers.has(event_name):
		# 没有订阅者，正常情况，不报错
		return
	
	print_debug("EventBus: Emitting event '%s' with data: %s" % [event_name, str(data)])
	
	# 复制数组，防止在迭代过程中修改
	var callbacks = _subscribers[event_name].duplicate()
	for callback in callbacks:
		# 安全调用，防止回调函数出错影响其他订阅者
		if callback.is_valid():
			callback.call(data)
		else:
			push_warning("EventBus: Invalid callback for event '%s'" % event_name)

# 清空所有订阅（用于游戏重置）
func clear_all() -> void:
	_subscribers.clear()
	print_debug("EventBus: Cleared all subscriptions")

# 获取事件订阅者数量（调试用）
func get_subscriber_count(event_name: String) -> int:
	if _subscribers.has(event_name):
		return _subscribers[event_name].size()
	return 0

# 获取所有事件列表（调试用）
func get_event_list() -> Array:
	return _subscribers.keys()

# 预定义事件常量（可在外部扩展）
class Events:
	# 对话相关
	const DIALOG_STARTED = "dialog_started"
	const DIALOG_ENDED = "dialog_ended"
	const CHOICE_TRIGGERED = "choice_triggered"
	
	# 成就相关
	const ACHIEVEMENT_UNLOCKED = "achievement_unlocked"
	const ACHIEVEMENT_PROGRESS_UPDATED = "achievement_progress_updated"
	
	# 好感度相关
	const AFFECTION_CHANGED = "affection_changed"
	const AFFECTION_DIMENSION_UNLOCKED = "affection_dimension_unlocked"
	
	# 游戏状态
	const GAME_SAVED = "game_saved"
	const GAME_LOADED = "game_loaded"
	const CHAPTER_STARTED = "chapter_started"
	const CHAPTER_COMPLETED = "chapter_completed"
	
	# UI相关
	const UI_SHOW_ACHIEVEMENT_POPUP = "ui_show_achievement_popup"
	const UI_SHOW_CHOICE_MENU = "ui_show_choice_menu"

# 全局标志：是否以开发者测试模式启动游戏
var dev_test_mode: bool = false

# 便捷访问方法（静态方法）
static func subscribe_event(event_name: String, callback: Callable) -> void:
	if instance:
		instance.subscribe(event_name, callback)

static func unsubscribe_event(event_name: String, callback: Callable) -> void:
	if instance:
		instance.unsubscribe(event_name, callback)

static func emit_event(event_name: String, data: Dictionary = {}) -> void:
	if instance:
		instance.emit(event_name, data)

static func clear_events() -> void:
	if instance:
		instance.clear_all()
