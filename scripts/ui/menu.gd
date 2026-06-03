# menu.gd
# 游戏内菜单（暂停菜单）+ 子菜单管理
# ESC 键唤起/关闭，唤起时游戏暂停

extends Control

const DialogManager = preload("res://autoload/DialogManager.gd")

# 预加载子菜单场景
const SaveMenuScene = preload("res://scenes/ui/save_menu.tscn")
const SettingsMenuScene = preload("res://scenes/ui/settings_menu.tscn")

@onready var panel: PanelContainer = $PanelContainer
@onready var resume_btn: Button = $PanelContainer/VBoxContainer/ResumeBtn
@onready var save_btn: Button = $PanelContainer/VBoxContainer/SaveBtn
@onready var load_btn: Button = $PanelContainer/VBoxContainer/LoadBtn
@onready var settings_btn: Button = $PanelContainer/VBoxContainer/SettingsBtn
@onready var quit_btn: Button = $PanelContainer/VBoxContainer/QuitBtn
@onready var overlay: ColorRect = $BackgroundOverlay

# 子菜单节点
var _save_menu: Control = null
var _settings_menu: Control = null

const ANIM_DURATION: float = 0.2


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	modulate.a = 0.0
	hide()

	# 创建子菜单实例
	_save_menu = SaveMenuScene.instantiate()
	_save_menu.back_pressed.connect(_on_save_menu_back)
	_save_menu.load_and_close.connect(_on_save_menu_load)
	add_child(_save_menu)

	var settings_layer = SettingsMenuScene.instantiate()
	add_child(settings_layer)
	_settings_menu = settings_layer.get_node("Content") as Control
	if _settings_menu:
		_settings_menu.back_pressed.connect(_on_settings_menu_back)
	else:
		push_error("Menu: 无法获取设置菜单 Content 节点")

	# 连接按钮信号
	resume_btn.pressed.connect(_on_resume)
	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)


# ── 输入处理 ──────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	
	if _save_menu.visible:
		_on_save_menu_back()
		get_viewport().set_input_as_handled()
		return
	
	if _settings_menu.visible:
		# ESC 关闭设置菜单：先隐藏菜单，再恢复主面板
		_settings_menu.hide_menu()
		panel.show()
		get_viewport().set_input_as_handled()
		return
	
	_toggle_menu()
	get_viewport().set_input_as_handled()


# ── 菜单开关 ──────────────────────────────────────────

func _toggle_menu() -> void:
	if visible:
		_close_menu()
	else:
		_open_menu()


func _open_menu() -> void:
	show()
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, ANIM_DURATION)
	t.tween_callback(func(): get_tree().paused = true)
	print("Menu: 菜单已打开，游戏已暂停")


func _close_menu() -> void:
	get_tree().paused = false
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, ANIM_DURATION)
	t.tween_callback(hide)
	print("Menu: 菜单已关闭，游戏已恢复")


# ── 主菜单按钮处理 ──────────────────────────────────────

func _on_resume() -> void:
	_close_menu()


func _on_save() -> void:
	panel.hide()
	_save_menu.show_menu()
	print("Menu: 打开存档菜单")


func _on_load() -> void:
	print("Menu: 打开存档菜单（读档模式）")
	panel.hide()
	_save_menu.show_menu()


func _on_settings() -> void:
	panel.hide()
	_settings_menu.show_menu()
	print("Menu: 打开设置菜单")


func _on_quit() -> void:
	print("Menu: 返回标题画面")
	
	# 用遮罩淡出黑屏再切换，避免闪白
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(overlay, "color", Color(0, 0, 0, 1), 0.25)
	
	await t.finished
	
	get_tree().paused = false
	var err := get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
	if err != OK:
		push_error("Menu: 返回标题失败 (err=%d)" % err)


# ── 子菜单返回 ──────────────────────────────────────────

func _on_save_menu_back() -> void:
	_save_menu.hide_menu()
	panel.show()
	print("Menu: 关闭存档菜单")


func _on_save_menu_load() -> void:
	# 读档后直接关闭整个暂停菜单，回到游戏
	# 注意：此时游戏仍处于暂停状态，tween 不会正确执行
	# 因此直接 hide() 而非依赖 tween
	_save_menu.hide()
	_save_menu.modulate.a = 1.0
	
	# 恢复面板显示（之前被 _on_load() 的 panel.hide() 隐藏了）
	panel.show()
	
	# 重置自身状态：直接隐藏，不依赖 tween
	hide()
	modulate.a = 1.0
	get_tree().paused = false
	print("Menu: 读档完成，关闭菜单返回游戏")


func _on_settings_menu_back() -> void:
	# hide_menu() 已由 settings_menu.gd 的 _on_back() 内部调用，这里只恢复主面板
	panel.show()
	print("Menu: 关闭设置菜单")
