# SaveData.gd
# 存档数据结构 — 序列化所有需要保存的游戏状态
# 作为 Godot Resource 可直接写入 user:// 目录

class_name SaveData
extends Resource

## 存档元数据
@export var timestamp: String = ""          # 保存时间戳
@export var chapter_name: String = ""        # 当前章节名
@export var save_version: String = "1.0"     # 存档格式版本

## 对话状态
@export var script_path: String = ""         # 当前脚本文件路径
@export var line_index: int = 0              # 当前行索引
@export var dialog_state: int = 0            # DialogState 枚举值

## 场景状态
@export var current_background: String = ""  # 当前背景图ID
@export var current_bgm: String = ""         # 当前BGM ID

## 角色状态 — {char_id: {position: "left"|"right", expression: "smile"}}
@export var character_states: Dictionary = {}

## 好感度数据 — {char_id: int}
@export var affection_data: Dictionary = {}

## 成就数据（由 AchievementManager 序列化）
@export var achievement_data: Dictionary = {}


## 是否有有效数据（非空存档）
func is_empty() -> bool:
	return script_path.is_empty() and timestamp.is_empty()


## 格式化保存时间用于 UI 显示
func get_display_date() -> String:
	if timestamp.is_empty():
		return ""
	# 截取 "YYYY-MM-DD HH:MM" 格式
	return timestamp.substr(0, 16)


## 获取摘要信息
func get_summary() -> String:
	if is_empty():
		return "空"
	return "%s | %s" % [get_display_date(), chapter_name]
