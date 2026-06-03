# main.gd
# 游戏主控制器 — 管理章节加载、场景协调、游戏状态
extends Node

## 游戏状态枚举
enum GameState {
	LOADING,      # 加载中
	PLAYING,      # 游戏中
	PAUSED,       # 暂停（菜单打开）
}

# ── 节点引用 ──────────────────────────────────────────

var _dialog_layer: CanvasLayer
var _menu_layer: CanvasLayer

# ── 资源预加载 ────────────────────────────────────────

const AchievementPopupScene := preload("res://scenes/ui/achievement_popup.tscn")

# ── 状态 ──────────────────────────────────────────────

var current_state: GameState = GameState.LOADING
var current_chapter_path: String = ""
var current_section: String = "start"

# 章节映射（后续可扩展为章节选择/跳转）
var chapter_scripts := {
	"prologue": "res://resources/scripts/prologue_chapter1.txt",
}
# 测试脚本（开发者测试模式下使用）
const DEV_TEST_SCRIPT := "res://resources/scripts/framework_test.txt"


# ══════════════════════════════════════════════════════
#  生命周期
# ══════════════════════════════════════════════════════

func _ready() -> void:
	print("[Main] 游戏主控初始化...")

	_inject_nodes()
	_connect_signals()
	
	# 等 Autoload 就绪
	await get_tree().process_frame
	
	# 进入游戏
	current_state = GameState.PLAYING
	
	# 检查开发者测试模式（优先于读档恢复）
	var eb := get_node_or_null("/root/EventBus")
	if eb and eb.dev_test_mode:
		eb.dev_test_mode = false
		print("[Main] 开发者测试模式，加载测试脚本")
		# 重置 DialogManager，避免残留状态干扰
		var dm_reset := get_node_or_null("/root/DialogManager")
		if dm_reset:
			dm_reset.reset()
		start_chapter_file(DEV_TEST_SCRIPT)
		return
	
	# 检查是否已有加载的对话状态（从标题画面读档进入）
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.get_state() != 0:  # 0 = IDLE，非 IDLE 说明已有存档恢复
		print("[Main] 检测到已有对话状态，跳过章节启动")
		# 等待一帧让 DialogUI 完成信号连接，然后刷新对话显示
		await get_tree().process_frame
		dm.refresh_display()
	else:
		# 正常开始新游戏
		print("[Main] 开始加载序章...")
		start_chapter("prologue")


# ══════════════════════════════════════════════════════
#  节点注入
# ══════════════════════════════════════════════════════

func _inject_nodes() -> void:
	_dialog_layer = _safe_get("DialogLayer")
	_menu_layer = _safe_get("MenuLayer")


func _safe_get(path: String) -> Node:
	var node = get_node(path)
	if node == null:
		push_error("[Main] 节点未找到 → %s" % path)
	return node


# ══════════════════════════════════════════════════════
#  信号连接
# ══════════════════════════════════════════════════════

func _connect_signals() -> void:
	var dm = _get_dm()
	if dm:
		if not dm.dialog_ended.is_connected(_on_dialog_ended):
			dm.dialog_ended.connect(_on_dialog_ended)
	
	# 监听菜单/返回标题事件
	var eb = _get_eb()
	if eb:
		eb.subscribe("menu_opened", _on_menu_opened)
		eb.subscribe("menu_closed", _on_menu_closed)
		eb.subscribe("game_quit_to_title", _on_quit_to_title)
		eb.subscribe("game_loaded", _on_game_loaded)
		eb.subscribe("ui_show_achievement_popup", _on_achievement_popup)


# ══════════════════════════════════════════════════════
#  DialogManager 访问
# ══════════════════════════════════════════════════════

func _get_dm() -> Node:
	return get_node_or_null("/root/DialogManager")


func _get_eb() -> Node:
	return get_node_or_null("/root/EventBus")


# ══════════════════════════════════════════════════════
#  章节管理 — 公开 API
# ══════════════════════════════════════════════════════

## 通过章节 key 启动对话
func start_chapter(chapter_key: String, section: String = "start") -> void:
	var path = chapter_scripts.get(chapter_key, "")
	if path.is_empty():
		push_error("[Main] 未知章节: %s" % chapter_key)
		return
	
	# 加载对应章节的成就定义
	var achievement_path = "res://resources/achievements/%s_achievements.json" % chapter_key
	var am := get_node_or_null("/root/AchievementManager")
	if am and am.has_method("load_achievement_definitions"):
		am.load_achievement_definitions(achievement_path)
		print("[Main] 加载章节成就: %s" % achievement_path)
	
	_start_chapter_file(path, section)


## 通过文件路径启动对话
func start_chapter_file(file_path: String, section: String = "start") -> void:
	_start_chapter_file(file_path, section)


func _start_chapter_file(path: String, section: String) -> void:
	current_chapter_path = path
	current_section = section
	
	var dm = _get_dm()
	if dm == null:
		push_error("[Main] 无法访问 DialogManager！")
		return
	
	if not dm.load_dialog_script(path):
		push_error("[Main] 无法加载对话脚本: " + path)
		return
	
	print("[Main] 启动章节: %s (section=%s)" % [path, section])
	dm.start_dialog(section)
	current_state = GameState.PLAYING


# ══════════════════════════════════════════════════════
#  信号回调
# ══════════════════════════════════════════════════════

func _on_dialog_ended() -> void:
	print("[Main] 当前章节对话结束 → %s" % current_chapter_path)
	# TODO: 根据章节配置决定下一步（下一章 / 返回标题 / 进入结局分支）
	# 目前暂时不做任何操作，等待后续章节流程图设计


func _on_menu_opened(_data = null) -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		print("[Main] 菜单打开，游戏暂停")


func _on_menu_closed(_data = null) -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		print("[Main] 菜单关闭，继续游戏")


func _on_quit_to_title(_data = null) -> void:
	print("[Main] 返回标题界面")
	var err = get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
	if err != OK:
		push_error("[Main] 返回标题失败 (err=%d)" % err)


## 读档完成后直接恢复场景视觉效果（兜底路径）
## 绕过 EventBus，直接通过节点路径设置背景纹理，确保读档后背景始终可用
func _on_game_loaded(data: Dictionary) -> void:
	var bg_id: String = data.get("bg_id", "")
	if bg_id.is_empty():
		return
	
	print("[Main] 读档完成，直接恢复背景: %s" % bg_id)
	
	# 构建背景图路径
	var bg_map := {
		"bg_1": "res://resources/backgrounds/bg1.png",
		"bg_3": "res://resources/backgrounds/bg3.png",
		"bg_4": "res://resources/backgrounds/bg4.png",
		"bg_5": "res://resources/backgrounds/bg5.png",
	}
	var bg_path: String = bg_map.get(bg_id, "")
	if bg_path.is_empty():
		push_warning("[Main] 未找到背景路径: %s" % bg_id)
		return
	
	# 直接在 DialogUI 的 Background 节点上设置纹理
	var bg_node = get_node_or_null("DialogLayer/DialogUI/BackgroundLayer/Background")
	if bg_node == null:
		push_warning("[Main] 找不到背景节点")
		return
	
	var texture = load(bg_path)
	if texture:
		bg_node.texture = texture
		print("[Main] 背景已直接设置: %s" % bg_path)
	else:
		push_warning("[Main] 无法加载背景纹理: %s" % bg_path)


## 成就弹窗 — 动态实例化，动画完成后自动销毁
func _on_achievement_popup(data: Dictionary) -> void:
	get_node("/root/AudioManager").play_sfx("ui_popup")
	var popup := AchievementPopupScene.instantiate()
	add_child(popup)
	popup.show_popup(data)


# ══════════════════════════════════════════════════════
#  输入处理 — 备用键盘推进
# ══════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if current_state != GameState.PLAYING:
		return
	
	if event.is_action_pressed("ui_accept"):
		var dm = _get_dm()
		if dm == null:
			return
		if dm.get_state() == 1:  # PLAYING → 若类型机在播，跳过；否则推进下一句
			dm.next_line()
		# IDLE 状态下不做任何事 — 避免对话结束后按回车自动重开
