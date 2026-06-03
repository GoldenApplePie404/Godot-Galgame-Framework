# DialogManager.gd
# 对话系统核心管理器
# 负责加载、解析、执行对话脚本

extends Node

const EventBus = preload("res://autoload/EventBus.gd")

# 单例实例
static var instance

# 当前对话状态
enum DialogState {
	IDLE,          # 空闲
	PLAYING,       # 播放中
	WAITING_CHOICE # 等待选择
}

var current_state: DialogState = DialogState.IDLE
var current_script: Dictionary = {}           # 解析后的脚本数据
var current_line_index: int = 0               # 当前行索引
var is_text_animating: bool = false           # 文本是否在动画显示中
var current_speaker: String = ""              # 当前说话者
var current_text: String = ""                 # 当前显示的文本
var _current_jump_targets: Array[String] = []  # 当前选项对应的跳转目标列表
var _current_prompt: String = ""               # 当前选项的提示文本（@choice 后的第一行）

# 存档状态 io — 记录当前加载的脚本路径（由外部设置）
var _current_script_path: String = ""

# 对话回调信号
signal dialog_started(chapter_name: String)
signal dialog_line_changed(speaker: String, text: String)
signal dialog_ended()
signal choice_triggered(options: Array[String], prompt: String)
signal choice_selected(choice_index: int)
signal text_animation_skip()  # 通知UI跳过逐字动画，立即显示完整文本

# 初始化
func _init() -> void:
	if instance == null:
		instance = self
	else:
		push_error("DialogManager is a singleton! Multiple instances detected.")


## 重置对话状态（开始新游戏时调用）
func reset() -> void:
	current_state = DialogState.IDLE
	current_script = {}
	current_line_index = 0
	is_text_animating = false
	current_speaker = ""
	current_text = ""
	_current_jump_targets.clear()
	_current_prompt = ""
	_current_script_path = ""
	print("[DialogManager] 状态已重置")


# 加载对话脚本文件
func load_dialog_script(file_path: String) -> bool:
	# 先尝试从文件系统加载
	var file = FileAccess.open(file_path, FileAccess.READ)
	var script_text: String = ""
	
	if file:
		script_text = file.get_as_text()
		file.close()
	else:
		# 兜底：从内嵌的 GDScript 包中获取（确保导出版可用）
		script_text = ScriptTexts.get_text(file_path)
		if script_text.is_empty():
			push_error("DialogManager: Failed to load dialog script: %s" % file_path)
			return false
		print("DialogManager: 从内嵌包加载脚本: %s" % file_path)
	
	# 解析脚本
	current_script = _parse_script(script_text)
	if current_script.is_empty():
		push_error("DialogManager: Failed to parse script: %s" % file_path)
		return false
	
	_current_script_path = file_path
	print_debug("DialogManager: Loaded script '%s' with %d lines" % [file_path, current_script.get("lines", []).size()])
	return true

# 开始对话
func start_dialog(start_label: String = "start") -> void:
	if current_state != DialogState.IDLE:
		push_warning("DialogManager: Attempted to start dialog while not idle")
		return
	
	if current_script.is_empty():
		push_error("DialogManager: No script loaded")
		return
	
	# 查找起始标签
	var start_index = _find_label_index(start_label)
	if start_index == -1:
		push_error("DialogManager: Label '%s' not found" % start_label)
		return
	
	current_line_index = start_index + 1  # 从标签的下一行开始
	current_state = DialogState.PLAYING
	
	# 发出信号
	dialog_started.emit(current_script.get("chapter", "unknown"))
	EventBus.emit_event(EventBus.Events.DIALOG_STARTED, {
		"chapter": current_script.get("chapter", "unknown"),
		"label": start_label
	})
	
	# 处理第一行
	_process_current_line()

# 继续到下一句对话
func next_line() -> void:
	if current_state != DialogState.PLAYING:
		push_warning("DialogManager: Attempted to continue dialog while not playing")
		return
	
	if is_text_animating:
		# 文本正在逐字显示：发信号让UI跳过动画，显示完整文本，不推进对话
		is_text_animating = false
		text_animation_skip.emit()
		return
	
	current_line_index += 1
	
	if current_line_index >= current_script.get("lines", []).size():
		# 对话结束
		_end_dialog()
		return
	
	_process_current_line()

# 选择选项
func select_choice(choice_index: int) -> void:
	if current_state != DialogState.WAITING_CHOICE:
		push_warning("DialogManager: Attempted to select choice while not waiting")
		return

	if choice_index < 0 or choice_index >= _current_jump_targets.size():
		push_error("DialogManager: Invalid choice index %d (have %d targets)" % [choice_index, _current_jump_targets.size()])
		return

	var target_label: String = _current_jump_targets[choice_index]
	choice_selected.emit(choice_index)
	_current_jump_targets.clear()
	_jump_to_label(target_label)

# 结束当前对话
func end_dialog() -> void:
	_end_dialog()

# 获取当前对话状态
func get_state() -> DialogState:
	return current_state

# 获取当前说话者和文本
func get_current_line() -> Dictionary:
	return {
		"speaker": current_speaker,
		"text": current_text
	}


## 刷新对话显示（场景重新加载后重发当前行信号）
## 从标题画面读档时，restore_from_save() 已在场景加载前执行，
## dialog_line_changed 信号被错过，需要重新触发 DialogUI 更新
func refresh_display() -> void:
	if current_state == DialogState.PLAYING:
		dialog_line_changed.emit(current_speaker, current_text)
		is_text_animating = true
		print("[DialogManager] 刷新对话显示: %s → %s" % [current_speaker, current_text])
	elif current_state == DialogState.WAITING_CHOICE:
		choice_triggered.emit(_current_jump_targets.duplicate(), _current_prompt)
		print("[DialogManager] 刷新选择显示: %d 个选项" % _current_jump_targets.size())

# 由UI在逐字动画播放完毕后调用，重置动画标志
func notify_text_animation_finished() -> void:
	is_text_animating = false


# ── 存档系统接口 ──────────────────────────────────

## 供 SaveManager 调用：获取当前脚本路径
func _get_current_script_path() -> String:
	return _current_script_path


## 供 SaveManager 调用：从存档数据恢复对话状态
func restore_from_save(save_data: Resource) -> bool:
	if save_data == null:
		return false
	
	# 获取脚本路径
	var path: String = save_data.get("script_path")
	if path.is_empty():
		push_error("DialogManager: 存档中无脚本路径")
		return false
	
	# 重新加载脚本
	if not load_dialog_script(path):
		return false
	
	# 恢复行索引
	var saved_line_idx: int = save_data.get("line_index")
	current_line_index = saved_line_idx
	
	# 恢复状态
	var saved_state: int = save_data.get("dialog_state")
	current_state = saved_state as DialogState
	_current_jump_targets.clear()
	is_text_animating = false
	
	print("[DialogManager] 恢复存档 — %s 行%d 状态%d" % [path, saved_line_idx, saved_state])

	# ── 恢复视觉状态（背景 / BGM / 角色）— 在开始处理对话行之前 ──
	# 这是兜底路径：即使 SaveManager 在外部发射的事件因某种时序未生效，
	# DialogManager 内部也会在 _process_current_line() 之前恢复视觉状态
	var sd: SaveData = save_data as SaveData
	if sd:
		if not sd.current_background.is_empty():
			EventBus.emit_event("background_changed", {"background": sd.current_background})
			print("[DialogManager] 恢复背景: %s" % sd.current_background)

		if not sd.current_bgm.is_empty():
			EventBus.emit_event("bgm_changed", {"track": sd.current_bgm})

		for cid in sd.character_states:
			var cs: Dictionary = sd.character_states[cid]
			EventBus.emit_event("character_updated", {
				"character_id": cid,
				"position": cs.get("position", ""),
				"expression": cs.get("expression", "neutral"),
			})

	# 从当前行继续处理（跳到下一句对话或指令）
	_process_current_line()
	
	return true

# ============================================================
# 私有方法
# ============================================================

# 解析脚本文本
func _parse_script(script_text: String) -> Dictionary:
	var result = {
		"chapter": "unknown",
		"lines": []
	}
	
	var lines = script_text.split("\n")
	var line_number = 0
	
	for line in lines:
		line_number += 1
		line = line.strip_edges()
		
		# 跳过空行和注释
		if line.is_empty() or line.begins_with("#"):
			continue
		
		# 解析章节标记
		if line.begins_with("@chapter "):
			result["chapter"] = line.substr(9).strip_edges()
			continue
		
		# 解析指令
		if line.begins_with("@"):
			var instruction = _parse_instruction(line, line_number)
			if instruction:
				result["lines"].append(instruction)
			continue
		
		# 解析对话行
		var dialog_line = _parse_dialog_line(line, line_number)
		if dialog_line:
			result["lines"].append(dialog_line)
	
	return result

# 解析指令
func _parse_instruction(line: String, line_number: int) -> Dictionary:
	var parts = line.substr(1).split(" ", false, 1)
	var instruction_type = parts[0]
	
	match instruction_type:
		"bg":
			if parts.size() > 1:
				return {
					"type": "instruction",
					"instruction": "set_background",
					"value": parts[1],
					"line": line_number
				}
		
		"bgm":
			if parts.size() > 1:
				return {
					"type": "instruction",
					"instruction": "set_bgm",
					"value": parts[1],
					"line": line_number
				}
		
		"char":
			# BUG-02 修复：@char 至少需要 character_id 和 position 两个参数，不足时给出明确警告
			# BUG-03 修复：expression 可能包含空格（如 "slightly embarrassed"），使用最多分割3段
			if parts.size() > 1:
				var char_parts = parts[1].split(" ", false, 2)  # 最多分割为 [char_id, position, expression]
				if char_parts.size() < 2:
					push_warning("DialogManager: @char requires at least 2 args (character_id, position) at line %d: %s" % [line_number, line])
					return {}
				return {
					"type": "instruction",
					"instruction": "set_character",
					"character_id": char_parts[0],
					"position": char_parts[1],
					"expression": char_parts[2] if char_parts.size() > 2 else "neutral",
					"line": line_number
				}
			else:
				push_warning("DialogManager: @char requires arguments at line %d" % line_number)
				return {}
		
		"choice":
			return {
				"type": "choice_start",
				"line": line_number
			}
		
		"label":
			if parts.size() > 1:
				return {
					"type": "label",
					"label_name": parts[1],
					"line": line_number
				}
		
		"jump":
			if parts.size() > 1:
				return {
					"type": "jump",
					"target_label": parts[1],
					"line": line_number
				}
		
		"event":
			# BUG-01 修复：@event 指令实现
			# 格式: @event event_name [key value ...]
			# 例如: @event puzzle_solved   /   @event flag_set key solved
			if parts.size() > 1:
				var event_parts = parts[1].split(" ", false)
				var event_name: String = event_parts[0]
				var event_data := {}
				# 解析可选的 key value 对（必须成对出现）
				var j: int = 1
				while j + 1 < event_parts.size():
					event_data[event_parts[j]] = event_parts[j + 1]
					j += 2
				return {
					"type": "instruction",
					"instruction": "fire_event",
					"event_name": event_name,
					"event_data": event_data,
					"line": line_number
				}
			else:
				push_warning("DialogManager: @event requires an event_name at line %d" % line_number)
				return {}
		
		"chapter_end":
			# BUG-05 修复：@chapter_end 指令实现，标记当前章节结束
			return {
				"type": "instruction",
				"instruction": "chapter_end",
				"line": line_number
			}
		
		"achievement":
			if parts.size() > 1:
				# 格式: @achievement unlock <id> [名称] [描述]
				var achievement_parts = parts[1].split(" ", false, 3)
				if achievement_parts.size() >= 2 and achievement_parts[0] == "unlock":
					var result := {
						"type": "instruction",
						"instruction": "unlock_achievement",
						"achievement_id": achievement_parts[1],
						"line": line_number,
					}
					if achievement_parts.size() >= 3:
						result["achievement_name"] = achievement_parts[2]
					if achievement_parts.size() >= 4:
						result["achievement_description"] = achievement_parts[3]
					return result
		
		"transition":
			# 格式: @transition <效果名> [时长]
			if parts.size() > 1:
				var t_parts = parts[1].split(" ", false, 2)
				return {
					"type": "instruction",
					"instruction": "play_transition",
					"effect": t_parts[0],
					"duration": float(t_parts[1]) if t_parts.size() >= 2 else 1.0,
					"line": line_number,
				}
		
		"pose":
			# 格式: @pose <角色ID> <姿态名>
			if parts.size() > 1:
				var p_parts = parts[1].split(" ", false, 2)
				if p_parts.size() >= 2:
					return {
						"type": "instruction",
						"instruction": "set_pose",
						"character_id": p_parts[0],
						"pose_name": p_parts[1],
						"line": line_number,
					}
				else:
					push_warning("DialogManager: @pose requires 2 args (character_id, pose_name) at line %d" % line_number)
					return {}
		
		"expression":
			# 格式: @expression <角色ID> <表情名>
			if parts.size() > 1:
				var e_parts = parts[1].split(" ", false, 2)
				if e_parts.size() >= 2:
					return {
						"type": "instruction",
						"instruction": "set_expression",
						"character_id": e_parts[0],
						"expression_name": e_parts[1],
						"line": line_number,
					}
				else:
					push_warning("DialogManager: @expression requires 2 args (character_id, expression_name) at line %d" % line_number)
					return {}
		
		"perform":
			# 格式: @perform <角色ID> <表演名>
			if parts.size() > 1:
				var perf_parts = parts[1].split(" ", false, 2)
				if perf_parts.size() >= 2:
					return {
						"type": "instruction",
						"instruction": "set_performance",
						"character_id": perf_parts[0],
						"performance_name": perf_parts[1],
						"line": line_number,
					}
				else:
					push_warning("DialogManager: @perform requires 2 args (character_id, performance_name) at line %d" % line_number)
					return {}
		
		"char_flip":
			# 格式: @char_flip <角色ID>
			# 翻转指定角色的水平朝向
			if parts.size() > 1:
				return {
					"type": "instruction",
					"instruction": "char_flip",
					"character_id": parts[1],
					"line": line_number,
				}
		
		"char_side":
			# 格式: @char_side <角色ID> <left|right>
			# 将角色移动到指定侧
			if parts.size() > 1:
				var side_parts = parts[1].split(" ", false, 2)
				if side_parts.size() >= 2:
					return {
						"type": "instruction",
						"instruction": "char_side",
						"character_id": side_parts[0],
						"side": side_parts[1],
						"line": line_number,
					}
		
		"char_scale":
			# 格式: @char_scale <角色ID> <缩放倍率>
			# 运行时动态改变角色立绘大小
			# >1 = 放大（如 1.3），<1 = 缩小（如 0.7）
			if parts.size() > 1:
				var scale_parts = parts[1].split(" ", false, 2)
				if scale_parts.size() >= 2:
					var factor: float = scale_parts[1].to_float()
					if factor > 0:
						return {
							"type": "instruction",
							"instruction": "char_scale",
							"character_id": scale_parts[0],
							"scale": factor,
							"line": line_number,
						}
					else:
						push_warning("DialogManager: @char_scale requires a positive number (arg2) at line %d" % line_number)
						return {}
		
		"affection":
			if parts.size() > 1:
				var aff_parts = parts[1].split(" ")
				if aff_parts.size() >= 2:
					var char_id = aff_parts[0]
					var val_str = aff_parts[1]
					# 支持 +5 或 -3 格式
					var val := 0
					if val_str.begins_with("+"):
						val = val_str.substr(1).to_int()
					elif val_str.begins_with("-"):
						val = -val_str.substr(1).to_int()
					else:
						val = val_str.to_int()
					return {
						"type": "instruction",
						"instruction": "change_affection",
						"character_id": char_id,
						"value": val,
						"line": line_number
					}
	
	push_warning("DialogManager: Unknown instruction at line %d: %s" % [line_number, line])
	return {}

# 解析对话行
func _parse_dialog_line(line: String, line_number: int) -> Dictionary:
	# 格式: 说话者: 文本
	var colon_pos = line.find(":")
	if colon_pos == -1:
		# 没有冒号，可能是旁白
		return {
			"type": "dialogue",
			"speaker": "",
			"text": line,
			"line": line_number
		}
	
	var speaker = line.substr(0, colon_pos).strip_edges()
	var text = line.substr(colon_pos + 1).strip_edges()
	
	return {
		"type": "dialogue",
		"speaker": speaker,
		"text": text,
		"line": line_number
	}

# 查找标签索引
func _find_label_index(label_name: String) -> int:
	var lines = current_script.get("lines", [])
	for i in range(lines.size()):
		var line = lines[i]
		if line.get("type") == "label" and line.get("label_name") == label_name:
			return i
	return -1

# 处理当前行
func _process_current_line() -> void:
	var lines = current_script.get("lines", [])
	if current_line_index >= lines.size():
		_end_dialog()
		return
	
	var current_line = lines[current_line_index]
	
	match current_line.get("type"):
		"dialogue":
			current_speaker = current_line.get("speaker", "")
			current_text = current_line.get("text", "")
			
			# 标记文本动画开始，UI收到信号后负责实际的逐字动画
			# 动画完成后UI应调用 notify_text_animation_finished() 来重置此标志
			is_text_animating = true
			
			# 发出信号（UI收到后启动逐字动画）
			dialog_line_changed.emit(current_speaker, current_text)
		
		"instruction":
			_execute_instruction(current_line)
			# 指令可能已改变对话状态（如 @chapter_end → IDLE），
			# 状态非 PLAYING 时立即停止，避免递归重播整个脚本
			if current_state != DialogState.PLAYING:
				return
			current_line_index += 1
			_process_current_line()
		
		"choice_start":
			current_state = DialogState.WAITING_CHOICE
			_current_jump_targets.clear()
			_current_prompt = ""
			var options: Array[String] = []
			
			# 收集选项行和对应的跳转目标
			# 格式：对话行(选项文本) 紧跟 jump 类型行
			# 第一个非选项的对话行被视为提示文本（显示在选项上方）
			var i: int = current_line_index + 1
			var prompt_found: bool = false
			while i < lines.size():
				var option_line = lines[i]
				if option_line.get("type") != "dialogue":
					break
				
				var option_text: String = option_line.get("text", "")
				# jump 是独立类型，不是 instruction 子类型
				if i + 1 < lines.size() and lines[i + 1].get("type") == "jump":
					options.append(option_text)
					_current_jump_targets.append(lines[i + 1].get("target_label", ""))
					i += 2
					continue
				
				# 非选项对话行：作为提示文本（仅取第一行）
				if not prompt_found:
					_current_prompt = option_text
					prompt_found = true
				i += 1
			
			if options.size() == 0:
				push_warning("DialogManager: No options found after @choice at line %d" % current_line.get("line", -1))
				_end_dialog()
				return
			
			choice_triggered.emit(options, _current_prompt)
			# current_line_index 不动，等待用户选择
			return
		
		"label":
			# 标签行，跳过并继续
			current_line_index += 1
			_process_current_line()
			return

		"jump":
			# 普通流程中的跳转指令
			var target_label: String = current_line.get("target_label", "")
			_jump_to_label(target_label)
			return

		_:
			push_warning("DialogManager: Unknown line type: %s" % current_line.get("type"))

# 执行指令
func _execute_instruction(instruction: Dictionary) -> void:
	var instr_type = instruction.get("instruction", "")
	
	match instr_type:
		"set_background":
			print_debug("DialogManager: Setting background to %s" % instruction.get("value"))
			# 触发背景变更事件
			EventBus.emit_event("background_changed", {
				"background": instruction.get("value")
			})
		
		"set_bgm":
			print_debug("DialogManager: Setting BGM to %s" % instruction.get("value"))
			EventBus.emit_event("bgm_changed", {
				"track": instruction.get("value")
			})
		
		"set_character":
			print_debug("DialogManager: Setting character %s at %s with expression %s" % [
				instruction.get("character_id"),
				instruction.get("position"),
				instruction.get("expression")
			])
			EventBus.emit_event("character_updated", {
				"character_id": instruction.get("character_id"),
				"position": instruction.get("position"),
				"expression": instruction.get("expression")
			})
		
		"set_pose":
			var char_id: String = instruction.get("character_id", "")
			var pose_name: String = instruction.get("pose_name", "")
			print_debug("DialogManager: Setting pose for %s to %s" % [char_id, pose_name])
			EventBus.emit_event("character_pose_changed", {
				"character_id": char_id,
				"pose": pose_name,
			})
		
		"set_expression":
			var char_id: String = instruction.get("character_id", "")
			var expr_name: String = instruction.get("expression_name", "")
			print_debug("DialogManager: Setting expression for %s to %s" % [char_id, expr_name])
			EventBus.emit_event("character_expression_changed", {
				"character_id": char_id,
				"expression": expr_name,
			})
		
		"set_performance":
			var char_id: String = instruction.get("character_id", "")
			var perf_name: String = instruction.get("performance_name", "")
			print_debug("DialogManager: Setting performance for %s to %s" % [char_id, perf_name])
			EventBus.emit_event("character_performance_changed", {
				"character_id": char_id,
				"performance": perf_name,
			})
		
		"char_flip":
			var char_id: String = instruction.get("character_id", "")
			print_debug("DialogManager: Flipping character %s" % char_id)
			EventBus.emit_event("character_flipped", {
				"character_id": char_id,
			})
		
		"char_side":
			var char_id: String = instruction.get("character_id", "")
			var side: String = instruction.get("side", "left")
			print_debug("DialogManager: Moving character %s to %s" % [char_id, side])
			EventBus.emit_event("character_side_changed", {
				"character_id": char_id,
				"side": side,
			})
		
		"char_scale":
			var char_id: String = instruction.get("character_id", "")
			var factor: float = instruction.get("scale", 1.0)
			print_debug("DialogManager: Scaling character %s to %s" % [char_id, factor])
			EventBus.emit_event("character_scale_changed", {
				"character_id": char_id,
				"scale": factor,
			})
		
		"unlock_achievement":
			var achievement_id = instruction.get("achievement_id", "")
			var event_data: Dictionary = {
				"achievement_id": achievement_id,
			}
			# 可选字段：名称和描述（来自 @achievement unlock <id> <name> <desc>）
			if instruction.has("achievement_name"):
				event_data["achievement_name"] = instruction.get("achievement_name")
			if instruction.has("achievement_description"):
				event_data["achievement_description"] = instruction.get("achievement_description")
			print_debug("DialogManager: Unlocking achievement %s" % achievement_id)
			EventBus.emit_event(EventBus.Events.ACHIEVEMENT_UNLOCKED, event_data)

		"play_transition":
			var effect: String = instruction.get("effect", "")
			var duration: float = instruction.get("duration", 1.0)
			print_debug("DialogManager: Playing transition '%s' (%.1fs)" % [effect, duration])
			var tm := get_node("/root/TransitionManager")
			if tm and tm.has_method("play"):
				tm.play(effect, duration)

		"fire_event":
			# BUG-01 修复对应的执行逻辑：通过 EventBus 发出自定义事件
			var event_name: String = instruction.get("event_name", "")
			var event_data: Dictionary = instruction.get("event_data", {})
			print_debug("DialogManager: Firing event '%s' with data %s" % [event_name, event_data])
			EventBus.emit_event(event_name, event_data)

		"chapter_end":
			# BUG-05 修复对应的执行逻辑：发出章节结束事件，然后结束对话
			var chapter_name: String = current_script.get("chapter", "unknown")
			print_debug("DialogManager: Chapter '%s' ended via @chapter_end" % chapter_name)
			EventBus.emit_event("chapter_ended", {
				"chapter": chapter_name
			})
			_end_dialog()
			return

		"change_affection":
			var char_id: String = instruction.get("character_id", "")
			var val: int = instruction.get("value", 0)
			print_debug("DialogManager: Changing affection for %s by %d" % [char_id, val])
			EventBus.emit_event("affection_changed", {
				"character_id": char_id,
				"value": val
			})
		
		_:
			push_warning("DialogManager: Unknown instruction type: %s" % instr_type)

# 跳转到指定标签
func _jump_to_label(label_name: String) -> void:
	var target_idx: int = _find_label_index(label_name)
	if target_idx == -1:
		push_error("DialogManager: Label '%s' not found" % label_name)
		_end_dialog()
		return

	current_line_index = target_idx + 1
	current_state = DialogState.PLAYING
	_process_current_line()


# 结束对话
func _end_dialog() -> void:
	current_state = DialogState.IDLE
	current_line_index = 0
	current_speaker = ""
	current_text = ""
	
	# 发出信号
	dialog_ended.emit()
	EventBus.emit_event(EventBus.Events.DIALOG_ENDED, {})

# 测试用的便捷方法（开发完成后删除）
func _test_load_and_start() -> void:
	# 测试加载一个示例脚本
	var test_script = """
# 测试对话
@bg school_classroom
@bgm peaceful_day
@char snow left smile

雪乃: 早上好，今天天气真不错呢。
主角: 是啊，很适合去天台吃午饭。

@choice
你想和谁一起吃午饭？
- 和雪乃一起 → @jump lunch_snow
- 去找玲音 → @jump lunch_lin

@label lunch_snow
雪乃: 真的吗？那我去买两份便当！
@achievement unlock first_lunch
"""
	
	# 将测试脚本写入临时文件
	var test_file = "res://resources/scripts/test_dialog.txt"
	var file = FileAccess.open(test_file, FileAccess.WRITE)
	if file:
		file.store_string(test_script)
		file.close()
		
		# 加载并开始对话
		if load_dialog_script(test_file):
			start_dialog()
		else:
			push_error("DialogManager: Failed to load test script")
	else:
		push_error("DialogManager: Failed to create test file")
