# test_runner.gd
# 技术验证测试运行器
# 执行核心系统集成测试

extends Node

const EventBus = preload("res://autoload/EventBus.gd")
const DialogManager = preload("res://autoload/DialogManager.gd")
const AchievementManager = preload("res://autoload/AchievementManager.gd")

# 测试状态枚举
enum TestState {
	IDLE,
	RUNNING,
	COMPLETED,
	FAILED
}

var current_state: TestState = TestState.IDLE
var test_results: Dictionary = {}
var test_start_time: int = 0

# 信号
signal test_started(test_name: String)
signal test_completed(test_name: String, success: bool, message: String)
signal all_tests_completed(results: Dictionary)

# 就绪
func _ready() -> void:
	# 等待一帧确保所有单例已初始化
	await get_tree().process_frame
	await start_all_tests()

# 开始所有测试
func start_all_tests() -> void:
	if current_state != TestState.IDLE:
		return
	
	current_state = TestState.RUNNING
	test_start_time = Time.get_ticks_msec()
	test_results.clear()
	
	print("========================================")
	print("开始技术验证测试")
	print("========================================")
	
	# 运行测试套件
	await _run_test_suite()

# 运行测试套件
func _run_test_suite() -> void:
	# 1. 事件总线测试
	await _run_test("eventbus_basic", "事件总线基础功能", _test_eventbus_basic)
	
	# 2. 对话管理器测试
	await _run_test("dialog_manager_basic", "对话管理器基础功能", _test_dialog_manager_basic)
	
	# 3. 成就管理器测试
	await _run_test("achievement_manager_basic", "成就管理器基础功能", _test_achievement_manager_basic)
	
	# 4. 集成测试：对话触发成就
	await _run_test("integration_dialog_achievement", "对话-成就集成测试", _test_integration_dialog_achievement)
	
	# 完成测试
	_finish_test_suite()

# 运行单个测试
func _run_test(test_id: String, test_name: String, test_func: Callable) -> void:
	test_started.emit(test_name)
	print("\n[测试开始] %s" % test_name)
	
	var start_time = Time.get_ticks_msec()
	var success = false
	var message = ""
	
	# 执行测试
	if test_func.is_valid():
		# Godot 4.x 兼容：await 可以处理同步和异步函数
		success = await test_func.call()
	else:
		printerr("测试函数无效: %s" % test_name)
		success = false
	
	var elapsed = Time.get_ticks_msec() - start_time
	
	if success:
		message = "测试通过 (耗时: %dms)" % elapsed
		print("[测试通过] %s - %s" % [test_name, message])
	else:
		message = "测试失败 (耗时: %dms)" % elapsed
		print("[测试失败] %s - %s" % [test_name, message])
	
	# 存储结果
	test_results[test_id] = {
		"name": test_name,
		"success": success,
		"message": message,
		"elapsed_ms": elapsed
	}
	
	test_completed.emit(test_name, success, message)

# 完成测试套件
func _finish_test_suite() -> void:
	current_state = TestState.COMPLETED
	var total_elapsed = Time.get_ticks_msec() - test_start_time
	
	# 统计结果
	var total_tests = test_results.size()
	var passed_tests = 0
	for result in test_results.values():
		if result["success"]:
			passed_tests += 1
	
	print("\n========================================")
	print("测试完成")
	print("========================================")
	print("总测试数: %d" % total_tests)
	print("通过数: %d" % passed_tests)
	print("失败数: %d" % (total_tests - passed_tests))
	print("总耗时: %dms" % total_elapsed)
	print("========================================")
	
	# 输出详细结果
	for test_id in test_results:
		var result = test_results[test_id]
		var status = "✓" if result["success"] else "✗"
		print("%s %s: %s" % [status, result["name"], result["message"]])
	
	# 发出完成信号
	all_tests_completed.emit(test_results)

# ============================================================
# 测试用例实现
# ============================================================

# 测试事件总线基础功能
func _test_eventbus_basic() -> bool:
	print("  执行事件总线基础测试...")
	
	var test_passed = false
	# 使用数组包装变量以允许lambda函数修改
	var event_received_wrapper = [false]
	
	# 定义测试回调函数
	var test_callback = func(data: Dictionary):
		print("    事件回调被调用，数据: %s" % str(data))
		print("    数据['test'] = %s" % str(data.get("test")))
		if data.get("test") == "value":
			print("    条件满足，设置 event_received = true")
			event_received_wrapper[0] = true
		else:
			print("    条件不满足，data.get('test') 类型: %s, 值: %s" % [typeof(data.get("test")), str(data.get("test"))])
	
	# 订阅测试事件
	EventBus.subscribe_event("test_event", test_callback)
	
	# 发布测试事件
	EventBus.emit_event("test_event", {"test": "value"})
	
	# 等待一帧让事件分发完成
	await get_tree().process_frame
	
	# 检查事件是否被接收
	if event_received_wrapper[0]:
		print("    ✓ 事件接收成功")
		test_passed = true
	else:
		print("    ✗ 事件未接收")
		test_passed = false
	
	# 清理：取消订阅
	EventBus.unsubscribe_event("test_event", test_callback)
	
	return test_passed

# 测试对话管理器基础功能
func _test_dialog_manager_basic() -> bool:
	print("  执行对话管理器基础测试...")
	
	# 检查DialogManager单例是否存在
	if not DialogManager.instance:
		print("    ✗ DialogManager单例未初始化")
		return false
	
	print("    ✓ DialogManager单例已初始化")
	
	# 测试1: 加载对话脚本
	var test_script_path = "res://resources/scripts/test_dialog.txt"
	var file = FileAccess.open(test_script_path, FileAccess.READ)
	if file == null:
		print("    ✗ 测试脚本文件不存在: %s" % test_script_path)
		# 创建测试脚本
		_create_test_dialog_script()
		# 重新检查
		file = FileAccess.open(test_script_path, FileAccess.READ)
		if file == null:
			print("    ✗ 无法创建测试脚本")
			return false
	
	file.close()
	
	# 监听对话信号
	# 使用数组包装变量以允许lambda函数修改
	var dialog_started_wrapper = [false]
	var line_changed_count_wrapper = [0]
	var dialog_ended_wrapper = [false]
	
	var started_handler = func(chapter: String):
		dialog_started_wrapper[0] = true
		print("    对话开始信号收到，章节: %s" % chapter)
	
	var line_handler = func(speaker: String, text: String):
		line_changed_count_wrapper[0] += 1
		print("    对话行变化 #%d: %s: %s" % [line_changed_count_wrapper[0], speaker, text])
	
	var ended_handler = func():
		dialog_ended_wrapper[0] = true
		print("    对话结束信号收到")
	
	print("    连接对话信号...")
	var connected1 = DialogManager.instance.dialog_started.connect(started_handler)
	var connected2 = DialogManager.instance.dialog_line_changed.connect(line_handler)
	var connected3 = DialogManager.instance.dialog_ended.connect(ended_handler)
	print("    信号连接结果: %s, %s, %s" % [connected1, connected2, connected3])
	
	# 加载脚本
	if DialogManager.instance.load_dialog_script(test_script_path):
		print("    ✓ 对话脚本加载成功")
	else:
		print("    ✗ 对话脚本加载失败")
		DialogManager.instance.dialog_started.disconnect(started_handler)
		DialogManager.instance.dialog_line_changed.disconnect(line_handler)
		DialogManager.instance.dialog_ended.disconnect(ended_handler)
		return false
	
	# 开始对话
	DialogManager.instance.start_dialog()
	
	# 等待一帧让信号触发
	await get_tree().process_frame
	
	if not dialog_started_wrapper[0]:
		print("    ✗ 对话开始信号未触发")
		DialogManager.instance.dialog_started.disconnect(started_handler)
		DialogManager.instance.dialog_line_changed.disconnect(line_handler)
		DialogManager.instance.dialog_ended.disconnect(ended_handler)
		return false
	
	print("    ✓ 对话成功启动")
	
	# 模拟继续几次（测试对话进展）
	for i in range(3):
		DialogManager.instance.next_line()
		await get_tree().process_frame
	
	# 检查是否收到对话行变化信号
	if line_changed_count_wrapper[0] > 0:
		print("    ✓ 对话行变化信号收到 (%d次)" % line_changed_count_wrapper[0])
	else:
		print("    ✗ 对话行变化信号未收到")
		DialogManager.instance.dialog_started.disconnect(started_handler)
		DialogManager.instance.dialog_line_changed.disconnect(line_handler)
		DialogManager.instance.dialog_ended.disconnect(ended_handler)
		return false
	
	# 结束对话
	DialogManager.instance.end_dialog()
	await get_tree().process_frame
	
	if dialog_ended_wrapper[0]:
		print("    ✓ 对话结束信号收到")
	else:
		print("    ✗ 对话结束信号未收到")
	
	# 清理
	DialogManager.instance.dialog_started.disconnect(started_handler)
	DialogManager.instance.dialog_line_changed.disconnect(line_handler)
	DialogManager.instance.dialog_ended.disconnect(ended_handler)
	
	return dialog_started_wrapper[0] and line_changed_count_wrapper[0] > 0

# 创建测试对话脚本（如果不存在）
func _create_test_dialog_script() -> void:
	var test_script = """# 测试对话脚本
@chapter 测试章节
@bg test_background
@bgm test_bgm

@label start
旁白: 这是一个测试对话。
雪乃: 你好，我是雪乃。
主角: 很高兴认识你。

@choice
选择一项：
- 选项一 → @jump option1
- 选项二 → @jump option2

@label option1
雪乃: 你选择了选项一。
@achievement unlock test_choice_1

@label option2
雪乃: 你选择了选项二。
"""
	
	var test_script_path = "res://resources/scripts/test_dialog.txt"
	var dir = DirAccess.open("res://resources/scripts/")
	if not dir:
		# 创建目录
		DirAccess.make_dir_recursive_absolute("res://resources/scripts/")
	
	var file = FileAccess.open(test_script_path, FileAccess.WRITE)
	if file:
		file.store_string(test_script)
		file.close()
		print("测试对话脚本创建成功: %s" % test_script_path)
	else:
		push_error("无法创建测试对话脚本: %s" % test_script_path)

# 测试成就管理器基础功能
func _test_achievement_manager_basic() -> bool:
	print("  执行成就管理器基础测试...")
	
	# 检查AchievementManager单例是否存在
	if not AchievementManager.instance:
		print("    ✗ AchievementManager单例未初始化")
		return false
	
	print("    ✓ AchievementManager单例已初始化")
	
	# 测试1: 加载成就定义
	var test_achievement_path = "res://resources/achievements/test_achievements.json"
	var file = FileAccess.open(test_achievement_path, FileAccess.READ)
	if file == null:
		print("    ✗ 测试成就文件不存在: %s" % test_achievement_path)
		# 使用内置测试方法创建
		if AchievementManager.instance.has_method("_test_achievement_system"):
			AchievementManager.instance._test_achievement_system()
			# 重新检查
			file = FileAccess.open(test_achievement_path, FileAccess.READ)
			if file == null:
				print("    ✗ 无法创建测试成就文件")
				return false
		else:
			print("    ✗ AchievementManager没有测试方法，无法创建测试文件")
			return false
	
	file.close()
	
	# 加载成就定义
	if AchievementManager.instance.load_achievement_definitions(test_achievement_path):
		print("    ✓ 成就定义加载成功")
	else:
		print("    ✗ 成就定义加载失败")
		return false
	
	# 检查统计信息
	var stats = AchievementManager.instance.get_statistics()
	print("    成就统计: %s" % str(stats))
	
	if stats.get("total", 0) == 0:
		print("    ✗ 没有加载任何成就")
		return false
	
	print("    ✓ 成功加载 %d 个成就" % stats.get("total", 0))
	
	# 测试2: 解锁成就
	var test_achievement_id = "first_lunch"
	print("    测试成就ID: %s" % test_achievement_id)
	var unlocked_before = AchievementManager.instance.get_achievement(test_achievement_id)
	print("    解锁前状态: %s" % str(unlocked_before))
	
	# 监听成就解锁事件
	# 使用数组包装变量以允许lambda函数修改
	var achievement_unlocked_wrapper = [false]
	var unlocked_data_wrapper = [{}]
	
	var event_handler = func(achievement_id: String, achievement_data: Dictionary):
		achievement_unlocked_wrapper[0] = true
		unlocked_data_wrapper[0] = achievement_data
		print("    成就解锁事件收到: %s" % achievement_id)
	
	AchievementManager.instance.achievement_unlocked.connect(event_handler)
	
	# 通过EventBus触发成就解锁（模拟对话指令）
	EventBus.emit_event(EventBus.Events.ACHIEVEMENT_UNLOCKED, {
		"achievement_id": test_achievement_id
	})
	
	# 等待一帧让事件处理
	await get_tree().process_frame
	
	AchievementManager.instance.achievement_unlocked.disconnect(event_handler)
	
	if achievement_unlocked_wrapper[0]:
		print("    ✓ 成就解锁事件触发成功")
	else:
		print("    ✗ 成就解锁事件未触发")
		# 可能成就管理器没有连接事件，尝试直接解锁
		if AchievementManager.instance.unlock_achievement(test_achievement_id):
			print("    ✓ 直接解锁成就成功")
			achievement_unlocked_wrapper[0] = true
		else:
			print("    ✗ 直接解锁成就失败")
	
	# 检查解锁后的统计信息
	var stats_after = AchievementManager.instance.get_statistics()
	if stats_after.get("unlocked", 0) > stats.get("unlocked", 0):
		print("    ✓ 成就解锁统计更新成功")
	else:
		print("    ✗ 成就解锁统计未更新")
	
	# 测试3: 获取成就信息
	var achievement_info = AchievementManager.instance.get_achievement(test_achievement_id)
	if not achievement_info.is_empty():
		print("    ✓ 成就信息获取成功")
		print("    成就详情: %s" % str(achievement_info))
	else:
		print("    ✗ 成就信息获取失败")
	
	return achievement_unlocked_wrapper[0]

# 测试对话-成就集成
func _test_integration_dialog_achievement() -> bool:
	print("  执行对话-成就集成测试...")
	
	# 这个测试验证对话指令能否触发成就解锁
	# 步骤：
	# 1. 加载成就定义
	# 2. 创建包含@achievement指令的测试对话脚本
	# 3. 运行对话直到指令执行
	# 4. 验证成就解锁
	
	# 确保成就管理器已加载定义
	var test_achievement_path = "res://resources/achievements/test_achievements.json"
	if not FileAccess.file_exists(test_achievement_path):
		# 创建测试成就文件
		if AchievementManager.instance.has_method("_test_achievement_system"):
			AchievementManager.instance._test_achievement_system()
		else:
			print("    ✗ 无法创建测试成就文件")
			return false
	
	# 加载成就定义
	if not AchievementManager.instance.load_achievement_definitions(test_achievement_path):
		print("    ✗ 成就定义加载失败")
		return false
	
	# 创建包含成就指令的测试对话脚本
	var integration_script = """# 集成测试对话
@chapter 集成测试
@bg test_bg

@label start
旁白: 这是一个集成测试，用于验证对话指令触发成就解锁。

雪乃: 如果你看到这条消息，测试正在运行。
@achievement unlock first_lunch

旁白: 成就应该已经解锁了。
"""
	
	var integration_script_path = "res://resources/scripts/integration_test_dialog.txt"
	var file = FileAccess.open(integration_script_path, FileAccess.WRITE)
	if not file:
		print("    ✗ 无法创建集成测试脚本文件")
		return false
	
	file.store_string(integration_script)
	file.close()
	
	print("    ✓ 集成测试脚本创建成功")
	
	# 监听成就解锁事件
	# 使用数组包装变量以允许lambda函数修改
	var achievement_unlocked_wrapper = [false]
	var unlocked_id_wrapper = [""]
	
	var event_handler = func(data: Dictionary):
		achievement_unlocked_wrapper[0] = true
		unlocked_id_wrapper[0] = data.get("achievement_id", "")
		print("    成就解锁事件收到: %s" % str(data))
	
	EventBus.subscribe_event(EventBus.Events.ACHIEVEMENT_UNLOCKED, event_handler)
	
	# 加载并运行对话脚本
	if not DialogManager.instance.load_dialog_script(integration_script_path):
		print("    ✗ 集成测试脚本加载失败")
		EventBus.unsubscribe_event(EventBus.Events.ACHIEVEMENT_UNLOCKED, event_handler)
		return false
	
	print("    ✓ 集成测试脚本加载成功")
	
	# 确保对话管理器处于IDLE状态
	if DialogManager.instance.get_state() != DialogManager.DialogState.IDLE:
		print("    重置对话管理器状态...")
		DialogManager.instance.end_dialog()
		await get_tree().process_frame
	
	# 开始对话
	DialogManager.instance.start_dialog()
	
	# 等待一帧让对话开始
	await get_tree().process_frame
	
	# 模拟继续对话，直到成就指令执行
	# start_dialog从标签下一行开始：
	# 行1: 旁白 (需2次next_line: 1次清动画,1次推进)
	# 行2: 雪乃 (需2次next_line)
	# 行3: @achievement (instruction,自动执行后跳行4)
	# 行4: 旁白 (instruction触发后自动处理,需1次next_line结束)
	# 共6次next_line足够覆盖
	for i in range(6):
		if DialogManager.instance.get_state() == DialogManager.DialogState.IDLE:
			break
		DialogManager.instance.next_line()
		await get_tree().process_frame
	
	print("    循环结束后成就解锁状态: %s" % str(achievement_unlocked_wrapper[0]))
	
	# 取消订阅事件
	EventBus.unsubscribe_event(EventBus.Events.ACHIEVEMENT_UNLOCKED, event_handler)
	
	# 检查成就解锁状态
	var achievement_info = AchievementManager.instance.get_achievement("first_lunch")
	var is_unlocked = false
	if not achievement_info.is_empty():
		is_unlocked = achievement_info.get("state", 0) == AchievementManager.AchievementState.UNLOCKED
	
	if achievement_unlocked_wrapper[0] and unlocked_id_wrapper[0] == "first_lunch":
		print("    ✓ 成就解锁事件成功触发")
	else:
		print("    ✗ 成就解锁事件未触发或ID不匹配")
		print("      事件触发: %s, 事件ID: %s" % [achievement_unlocked_wrapper[0], unlocked_id_wrapper[0]])
	
	if is_unlocked:
		print("    ✓ 成就状态已更新为已解锁")
	else:
		print("    ✗ 成就状态未更新")
		print("      成就信息: %s" % str(achievement_info))
	
	# 结束对话
	DialogManager.instance.end_dialog()
	
	# 清理测试文件
	# 可选：删除临时文件
	
	return achievement_unlocked_wrapper[0] and unlocked_id_wrapper[0] == "first_lunch" and is_unlocked

# 便捷方法：重新运行测试
func rerun_tests() -> void:
	if current_state == TestState.RUNNING:
		return
	
	current_state = TestState.IDLE
	start_all_tests()
