# character_data.gd
# 角色配置资源 — 在 Godot 编辑器中右键 → 新建 Resource → CharacterData 来创建
# 通过 .tres 文件管理每个角色的立绘、表情、表演配置
class_name CharacterData
extends Resource

## 角色标识（如 "xuena", "xinghe"）
@export var character_id: String = ""
## 显示名称（如 "雪乃", "星河"）
@export var display_name: String = ""

## 表情叠加层在身体上的偏移位置
## 所有姿态图的脸部空洞应在同一坐标，只需设一个 offset
@export var face_offset: Vector2 = Vector2.ZERO
## 表情叠加层的缩放
@export var face_scale: Vector2 = Vector2(1, 1)

## 目标显示高度（像素，约等于 Screen Pixels）
## 立绘自动缩放至此高度，可在编辑器里调此值控制角色大小
@export var target_height: float = 380.0

## 姿态纹理集：{ "stand": Texture2D, "hands_on_hips": Texture2D, ... }
## 注意：身体姿态图的脸部区域需预留透明空洞，表情从 face_offset 处覆盖
@export var poses: Dictionary = {}

## 表情纹理集：{ "normal": Texture2D, "smile": Texture2D, ... }
## 这些是仅含面部的小尺寸纹理，会被缩放到 face_scale 并定位到 face_offset
@export var expressions: Dictionary = {}

## 表演整图集（可选）：{ "greet_smile": Texture2D, "surprise_back": Texture2D, ... }
## 使用 @perform 指令时激活，会隐藏 body+face 层，显示完整立绘
@export var performances: Dictionary = {}


## 获取指定姿态纹理
func get_pose(name: String) -> Texture2D:
	var tex: Texture2D = poses.get(name) as Texture2D
	if tex == null:
		push_warning("CharacterData[%s]: 未找到姿态 '%s'" % [character_id, name])
	return tex


## 获取指定表情纹理
func get_expression(name: String) -> Texture2D:
	var tex: Texture2D = expressions.get(name) as Texture2D
	if tex == null:
		push_warning("CharacterData[%s]: 未找到表情 '%s'" % [character_id, name])
	return tex


## 获取指定表演整图
func get_performance(name: String) -> Texture2D:
	var tex: Texture2D = performances.get(name) as Texture2D
	if tex == null:
		push_warning("CharacterData[%s]: 未找到表演 '%s'" % [character_id, name])
	return tex


## 检查姿态是否存在
func has_pose(name: String) -> bool:
	return poses.has(name)


## 检查表情是否存在
func has_expression(name: String) -> bool:
	return expressions.has(name)


## 检查表演是否存在
func has_performance(name: String) -> bool:
	return performances.has(name)


## 获取所有姿态名列表
func get_pose_names() -> Array[String]:
	var names: Array[String] = []
	for key in poses:
		names.append(key)
	return names


## 获取所有表情名列表
func get_expression_names() -> Array[String]:
	var names: Array[String] = []
	for key in expressions:
		names.append(key)
	return names


## 获取所有表演名列表
func get_performance_names() -> Array[String]:
	var names: Array[String] = []
	for key in performances:
		names.append(key)
	return names
