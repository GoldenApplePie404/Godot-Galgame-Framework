extends Control
## 标题界面 — 左上标题 + 右侧不规则按钮列

# 预加载子场景
const SaveMenuScene = preload("res://scenes/ui/save_menu.tscn")
const SettingsMenuScene = preload("res://scenes/ui/settings_menu.tscn")
const NotificationPopup = preload("res://scenes/ui/notification_popup.tscn")

# 节点引用
var _title_group: Control = null
var _button_vbox: VBoxContainer = null
var _start_btn: Button = null
var _load_btn: Button = null
var _settings_btn: Button = null
var _gallery_btn: Button = null
var _about_btn: Button = null
var _quit_btn: Button = null

# 子菜单实例
var _save_menu: Control = null
var _settings_menu: Control = null

# 状态
var _is_sub_menu_open := false


func _ready() -> void:
	_inject_nodes()
	_connect_signals()
	_create_sub_menus()
	_play_enter_animation()


func _inject_nodes() -> void:
	_title_group = _safe_get("TitleGroup")
	_button_vbox = _safe_get("ButtonVBox")
	_start_btn = _safe_get("ButtonVBox/StartMargin/StartBtn")
	_load_btn = _safe_get("ButtonVBox/LoadMargin/LoadBtn")
	_settings_btn = _safe_get("ButtonVBox/SettingsMargin/SettingsBtn")
	_gallery_btn = _safe_get("ButtonVBox/GalleryMargin/GalleryBtn")
	_about_btn = _safe_get("ButtonVBox/AboutMargin/AboutBtn")
	_quit_btn = _safe_get("ButtonVBox/QuitMargin/QuitBtn")


func _safe_get(path: String) -> Node:
	var node = get_node(path)
	if node == null:
		push_error("TitleScreen: 节点未找到 → %s" % path)
	return node


func _connect_signals() -> void:
	if _start_btn: _start_btn.pressed.connect(_on_start)
	if _load_btn: _load_btn.pressed.connect(_on_load)
	if _settings_btn: _settings_btn.pressed.connect(_on_settings)
	if _gallery_btn: _gallery_btn.pressed.connect(_on_gallery)
	if _about_btn: _about_btn.pressed.connect(_on_about)
	if _quit_btn: _quit_btn.pressed.connect(_on_quit)


func _create_sub_menus() -> void:
	# 创建存档子菜单
	_save_menu = SaveMenuScene.instantiate()
	_save_menu.hide()
	add_child(_save_menu)
	_save_menu.back_pressed.connect(_on_sub_menu_back)
	_save_menu.load_and_close.connect(_on_save_menu_load)

	# 创建设置子菜单（CanvasLayer 外壳 → Content 才是带脚本的 Control）
	var settings_layer = SettingsMenuScene.instantiate()
	add_child(settings_layer)
	_settings_menu = settings_layer.get_node("Content") as Control
	if _settings_menu:
		_settings_menu.hide()
		_settings_menu.back_pressed.connect(_on_sub_menu_back)
	else:
		push_error("TitleScreen: 无法获取设置菜单 Content 节点")


func _play_enter_animation() -> void:
	# 标题组淡入
	if _title_group:
		_title_group.modulate.a = 0.0
		var t = create_tween()
		t.tween_property(_title_group, "modulate:a", 1.0, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 按钮逐次错开淡入
	var buttons = [_start_btn, _load_btn, _settings_btn, _gallery_btn, _about_btn, _quit_btn]
	var delay := 0.1
	for btn in buttons:
		if btn:
			btn.modulate.a = 0.0
			var bt = create_tween()
			bt.tween_property(btn, "modulate:a", 1.0, 0.3) \
				.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		delay += 0.07


# ── 按钮事件 ──────────────────────────────────────────

func _on_start() -> void:
	# 开始新游戏前重置 DialogManager，防止继承旧对话状态
	var dm := get_node_or_null("/root/DialogManager")
	if dm and dm.has_method("reset"):
		dm.reset()
	
	var err = get_tree().change_scene_to_file("res://scenes/game/main.tscn")
	if err != OK:
		push_error("TitleScreen: 无法加载游戏场景 → main.tscn (err=%d)" % err)


func _on_load() -> void:
	if _save_menu == null:
		return
	_is_sub_menu_open = true
	_save_menu.show_menu()


## 从标题画面读档后直接进入游戏
func _on_save_menu_load() -> void:
	print("TitleScreen: 读档完成，进入游戏")
	_is_sub_menu_open = false
	var err := get_tree().change_scene_to_file("res://scenes/game/main.tscn")
	if err != OK:
		push_error("TitleScreen: 进入游戏失败 (err=%d)" % err)


func _on_settings() -> void:
	if _settings_menu == null:
		return
	_is_sub_menu_open = true
	_settings_menu.show_menu()


func _on_gallery() -> void:
	_show_coming_soon()


## 显示"功能开发中"弹窗 — 使用可复用的 NotificationPopup
func _show_coming_soon() -> void:
	var popup: NotificationPopup = NotificationPopup.instantiate()
	popup.message = "此功能开发中……"
	popup.font = load("res://resources/font/font2.ttf")
	popup.font_size = 44
	popup.font_color = Color(0.969, 0.106, 0.0, 1.0)
	popup.bg_color = Color(0, 0, 0, 0.2)
	popup.outline_color = Color(0, 0, 0, 0.5)
	popup.outline_size = 4
	popup.display_seconds = 1.2
	add_child(popup)
	popup.finished.connect(func():
		print("[TitleScreen] 开发中弹窗已关闭")
	)


func _on_about() -> void:
	var url := "https://blog.goldenapplepie.xyz/"
	print("[TitleScreen] 打开链接: %s" % url)
	OS.shell_open(url)


func _on_quit() -> void:
	get_tree().quit()


# ── 子菜单回调 ────────────────────────────────────────

func _on_sub_menu_back() -> void:
	_is_sub_menu_open = false
	_play_enter_animation()


# ── ESC 键处理 ────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _is_sub_menu_open:
			if _save_menu and _save_menu.visible:
				_save_menu.hide_menu()
				_save_menu.back_pressed.emit()
			elif _settings_menu and _settings_menu.visible:
				_settings_menu.hide_menu()
				_settings_menu.back_pressed.emit()
		get_viewport().set_input_as_handled()
