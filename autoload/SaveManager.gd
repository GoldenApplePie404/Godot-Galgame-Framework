# SaveManager.gd
# 存档系统核心管理器（Autoload 单例）
# 管理 6 个存档槽位的保存 / 加载 / 删除

class_name SaveManager
extends Node

const SAVE_DIR := "user://saves/"
const MAX_SLOTS := 6
const SAVE_VERSION := "1.0"

## 单例
static var instance: SaveManager

## 当前运行时追踪的场景状态（由指令更新）
var _current_background: String = ""
var _current_bgm: String = ""
var _character_states: Dictionary = {}

## 回调 — 存档槽位变化时通知 UI 刷新
signal slot_changed(slot_index: int)
signal save_completed(slot_index: int)
signal load_completed(slot_index: int)

## 待加载存档槽位（主场景启动时检查）
## 标题画面读档时设为此值，main.gd 启动时读取并跳转到该存档
static var pending_load_slot: int = -1


# ══════════════════════════════════════════════════════
#  初始化
# ══════════════════════════════════════════════════════

func _init() -> void:
	instance = self


func _ready() -> void:
	_ensure_save_dir()
	_connect_events()


func _ensure_save_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: 无法访问 user:// 目录")
		return
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
		print("[SaveManager] 创建存档目录 — user://saves/")


func _connect_events() -> void:
	var eb := _get_eb()
	if eb == null:
		return
	eb.subscribe("background_changed", _on_background_changed)
	eb.subscribe("bgm_changed", _on_bgm_changed)
	eb.subscribe("character_updated", _on_character_updated)


# ══════════════════════════════════════════════════════
#  EventBus 快捷访问
# ══════════════════════════════════════════════════════

func _get_eb() -> Node:
	return get_node_or_null("/root/EventBus")


func _get_dm() -> Node:
	return get_node_or_null("/root/DialogManager")


func _get_am() -> Node:
	return get_node_or_null("/root/AchievementManager")


# ══════════════════════════════════════════════════════
#  场景状态追踪
# ══════════════════════════════════════════════════════

func _on_background_changed(data: Dictionary) -> void:
	_current_background = data.get("background", "")


func _on_bgm_changed(data: Dictionary) -> void:
	_current_bgm = data.get("track", "")


func _on_character_updated(data: Dictionary) -> void:
	var char_id: String = data.get("character_id", "")
	if char_id.is_empty():
		return
	_character_states[char_id] = {
		"position": data.get("position", ""),
		"expression": data.get("expression", "neutral"),
	}


# ══════════════════════════════════════════════════════
#  存档操作 — 公开 API
# ══════════════════════════════════════════════════════

## 保存游戏到指定槽位
func save_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("SaveManager: 无效槽位 %d" % slot)
		return false

	var dm := _get_dm()
	if dm == null:
		push_error("SaveManager: 无法访问 DialogManager")
		return false

	var save_data := SaveData.new()
	save_data.save_version = SAVE_VERSION
	save_data.timestamp = Time.get_datetime_string_from_system()

	# ── 对话状态 ──
	var dm_state: int = dm.get_state()
	save_data.dialog_state = dm_state
	save_data.line_index = dm.current_line_index
	save_data.script_path = dm._get_current_script_path()

	# 获取章节名（从脚本数据中提取）
	var script_data: Dictionary = dm.current_script
	save_data.chapter_name = script_data.get("chapter", "未知")

	# ── 场景状态 ──
	save_data.current_background = _current_background
	save_data.current_bgm = _current_bgm
	save_data.character_states = _character_states.duplicate(true)

	# ── 好感度数据 ──
	save_data.affection_data = _collect_affection_data()

	# ── 成就数据 ──
	save_data.achievement_data = _collect_achievement_data()

	# ── 写入文件 ──
	var path := _get_slot_path(slot)
	var err := ResourceSaver.save(save_data, path)
	if err != OK:
		push_error("SaveManager: 保存失败 (err=%d) → %s" % [err, path])
		return false

	print("[SaveManager] 存档成功 — 槽位 %d | %s (%s)" % [slot + 1, save_data.chapter_name, save_data.line_index])
	slot_changed.emit(slot)
	save_completed.emit(slot)

	# 通知其他系统
	var eb := _get_eb()
	if eb:
		eb.emit("game_saved", {"slot": slot, "timestamp": save_data.timestamp})

	return true


## 从指定槽位读取存档
func load_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("SaveManager: 无效槽位 %d" % slot)
		return false

	var path := _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: 存档不存在 — 槽位 %d" % (slot + 1))
		return false

	var save_data: SaveData = ResourceLoader.load(path, "SaveData", ResourceLoader.CACHE_MODE_IGNORE)
	if save_data == null:
		push_error("SaveManager: 存档文件损坏 — 槽位 %d" % (slot + 1))
		return false

	print("[SaveManager] 加载存档 — 槽位 %d | %s (行%d)" % [slot + 1, save_data.chapter_name, save_data.line_index])

	# ── 恢复场景状态（内存缓存）──
	_current_background = save_data.current_background
	_current_bgm = save_data.current_bgm
	_character_states = save_data.character_states.duplicate(true)

	# ── 先恢复视觉状态（背景 / BGM / 角色），再恢复对话 ──
	# 时序很重要：如果背景事件在 restore_from_save() 之后才发射，
	# 对话会先显示出来而背景还是默认的（黑的/空的）
	var eb := _get_eb()
	if eb:
		if not _current_background.is_empty():
			eb.emit("background_changed", {"background": _current_background})
		if not _current_bgm.is_empty():
			eb.emit("bgm_changed", {"track": _current_bgm})
		for char_id in _character_states:
			var cs: Dictionary = _character_states[char_id]
			eb.emit("character_updated", {
				"character_id": char_id,
				"position": cs.get("position", ""),
				"expression": cs.get("expression", "neutral"),
			})

	# ── 恢复对话状态 ──
	var dm := _get_dm()
	if dm == null:
		push_error("SaveManager: 无法访问 DialogManager")
		return false

	var restored: bool = dm.restore_from_save(save_data)
	if not restored:
		push_error("SaveManager: 对话状态恢复失败")
		return false

	# ── 恢复好感度 ──
	_restore_affection_data(save_data.affection_data)

	# ── 恢复成就 ──
	_restore_achievement_data(save_data.achievement_data)

	load_completed.emit(slot)
	if eb:
		eb.emit("game_loaded", {
			"slot": slot,
			"bg_id": save_data.current_background,
			"achievement_data": save_data.achievement_data,
		})

	return true


## 删除指定槽位的存档
func delete_save(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false

	var path := _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_error("SaveManager: 删除存档失败 (err=%d) → %s" % [err, path])
		return false

	print("[SaveManager] 存档已删除 — 槽位 %d" % (slot + 1))
	slot_changed.emit(slot)
	return true


## 获取指定槽位的存档信息（用于 UI 显示）
func get_slot_info(slot: int) -> SaveData:
	if slot < 0 or slot >= MAX_SLOTS:
		return SaveData.new()

	var path := _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return SaveData.new()

	var save_data: SaveData = ResourceLoader.load(path, "SaveData", ResourceLoader.CACHE_MODE_IGNORE)
	if save_data == null:
		return SaveData.new()

	return save_data


## 获取所有槽位的存档信息
func get_all_slot_info() -> Array[SaveData]:
	var result: Array[SaveData] = []
	for i in range(MAX_SLOTS):
		result.append(get_slot_info(i))
	return result


# ══════════════════════════════════════════════════════
#  辅助
# ══════════════════════════════════════════════════════

func _get_slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%02d.tres" % (slot + 1)


func _collect_affection_data() -> Dictionary:
	# 好感度数据目前通过 EventBus 事件追踪
	# 预留：后续实现 AffectionManager 后再接入实际数据
	return _character_states.keys().reduce(func(d: Dictionary, char_id: String) -> Dictionary:
		d[char_id] = 0
		return d
	, {})


func _restore_affection_data(data: Dictionary) -> void:
	var eb := _get_eb()
	if eb == null:
		return
	for char_id in data:
		eb.emit("affection_changed", {
			"character_id": char_id,
			"value": data[char_id],
		})


func _collect_achievement_data() -> Dictionary:
	var am := _get_am()
	if am == null:
		return {}

	var result := {}
	result["achievements"] = {}
	for ach in am.get_all_achievements():
		var id: String = ach.get("id", "")
		if id.is_empty():
			continue
		result["achievements"][id] = {
			"state": ach.get("state", 0),
			"progress_current": ach.get("progress_current", 0.0),
			"unlock_time": ach.get("unlock_time", ""),
			"is_new": ach.get("is_new", false),
		}
	result["unlocked_count"] = am._unlocked_count
	return result


func _restore_achievement_data(data: Dictionary) -> void:
	var am := _get_am()
	if am == null:
		return
	if data.has("achievements"):
		am.load_achievement_progress(data)
