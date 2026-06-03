# settings_menu.gd
# 设置菜单 — % 唯一名称 + @onready 节点引用
#
# 挂载位置：CanvasLayer → Content (Control)

extends Control

## 用户点击返回 / 点击背景时发出（已自动调用 hide_menu）
signal back_pressed
## 开发者测试按钮被点击
signal dev_test_pressed

const ANIM_DURATION: float = 0.15
const SETTINGS_PATH: String = "user://settings.cfg"

# ── 文字速度映射 ──────────────────────────────────────────
const SPEED_LABELS: PackedStringArray = ["", "很慢", "较慢", "普通", "较快", "很快"]
const SPEED_CPS: Array[int] = [0, 15, 22, 30, 40, 55]

# ── @onready（% 唯一名称）────────────────────────────────
@onready var bgm_slider: HSlider = $"%BgmSlider"
@onready var bgm_value: Label = $"%BgmValue"
@onready var sfx_slider: HSlider = $"%SfxSlider"
@onready var sfx_value: Label = $"%SfxValue"
@onready var voice_slider: HSlider = $"%VoiceSlider"
@onready var voice_value: Label = $"%VoiceValue"
@onready var text_speed_slider: HSlider = $"%TextSpeedSlider"
@onready var text_speed_value: Label = $"%TextSpeedValue"
@onready var auto_play_check: CheckButton = $"%AutoPlayCheck"
@onready var skip_check: CheckButton = $"%SkipCheck"
@onready var fullscreen_check: CheckButton = $"%FullscreenCheck"
@onready var back_btn: Button = $"%BackBtn"
@onready var dev_test_btn: Button = $"%DevTestBtn"

var _config: ConfigFile


# ═══════════════════════════════════════════════════════════
# 生命周期
# ═══════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	modulate.a = 0.0
	hide()

	_config = ConfigFile.new()
	_load_settings()
	_wire_signals()


func _wire_signals() -> void:
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	voice_slider.value_changed.connect(_on_voice_changed)
	text_speed_slider.value_changed.connect(_on_text_speed_changed)

	auto_play_check.toggled.connect(_on_auto_play_toggled)
	skip_check.toggled.connect(_on_skip_toggled)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	back_btn.pressed.connect(_on_back)
	dev_test_btn.pressed.connect(_on_dev_test)


# ═══════════════════════════════════════════════════════════
# 显示 / 隐藏
# ═══════════════════════════════════════════════════════════

func show_menu() -> void:
	show()
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, ANIM_DURATION)


func hide_menu() -> void:
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, ANIM_DURATION)
	t.tween_callback(hide)


# ═══════════════════════════════════════════════════════════
# 设置存取
# ═══════════════════════════════════════════════════════════

func _load_settings() -> void:
	if _config.load(SETTINGS_PATH) != OK:
		_apply_defaults()
		return

	bgm_slider.value          = _config.get_value("audio",    "bgm_volume",   80)
	sfx_slider.value          = _config.get_value("audio",    "sfx_volume",   80)
	voice_slider.value        = _config.get_value("audio",    "voice_volume",  80)
	text_speed_slider.value   = _config.get_value("gameplay", "text_speed",    3)
	auto_play_check.button_pressed    = _config.get_value("gameplay", "auto_play",     false)
	skip_check.button_pressed         = _config.get_value("gameplay", "skip_read",     false)
	fullscreen_check.button_pressed   = _config.get_value("display",  "fullscreen",    false)

	_refresh_all_displays()
	_apply_audio_settings()


func _apply_defaults() -> void:
	bgm_slider.value = 80
	sfx_slider.value = 80
	voice_slider.value = 80
	text_speed_slider.value = 3
	auto_play_check.button_pressed = false
	skip_check.button_pressed = false
	fullscreen_check.button_pressed = false


func _save_settings() -> void:
	_config.set_value("audio",    "bgm_volume",   bgm_slider.value)
	_config.set_value("audio",    "sfx_volume",   sfx_slider.value)
	_config.set_value("audio",    "voice_volume",  voice_slider.value)
	_config.set_value("gameplay", "text_speed",    text_speed_slider.value)
	_config.set_value("gameplay", "auto_play",    auto_play_check.button_pressed)
	_config.set_value("gameplay", "skip_read",    skip_check.button_pressed)
	_config.set_value("display",  "fullscreen",   fullscreen_check.button_pressed)
	_config.save(SETTINGS_PATH)


# ═══════════════════════════════════════════════════════════
# 音频控制
# ═══════════════════════════════════════════════════════════

func _set_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var vol := value / 100.0
	AudioServer.set_bus_volume_db(idx, linear_to_db(vol))
	AudioServer.set_bus_mute(idx, value == 0)


func _apply_audio_settings() -> void:
	_set_bus_volume("BGM",  bgm_slider.value)
	_set_bus_volume("SFX",  sfx_slider.value)
	_set_bus_volume("Voice", voice_slider.value)


func _on_bgm_changed(_v: float) -> void:
	bgm_value.text = str(int(_v))
	_apply_audio_settings()
	_save_settings()


func _on_sfx_changed(_v: float) -> void:
	sfx_value.text = str(int(_v))
	_apply_audio_settings()
	_save_settings()


func _on_voice_changed(_v: float) -> void:
	voice_value.text = str(int(_v))
	_apply_audio_settings()
	_save_settings()


# ═══════════════════════════════════════════════════════════
# 文字速度
# ═══════════════════════════════════════════════════════════

func _on_text_speed_changed(_v: float) -> void:
	_refresh_text_speed_display()
	_save_settings()


func get_text_speed_cps() -> float:
	var idx := int(text_speed_slider.value)
	if idx >= 1 and idx < SPEED_CPS.size():
		return float(SPEED_CPS[idx])
	return 30.0


# ═══════════════════════════════════════════════════════════
# 开关回调
# ═══════════════════════════════════════════════════════════

func _on_auto_play_toggled(_p: bool) -> void:
	auto_play_check.text = "开启" if auto_play_check.button_pressed else "关闭"
	_save_settings()


func _on_skip_toggled(_p: bool) -> void:
	skip_check.text = "开启" if skip_check.button_pressed else "关闭"
	_save_settings()


func _on_fullscreen_toggled(pressed: bool) -> void:
	fullscreen_check.text = "开启" if pressed else "关闭"
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if pressed
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_save_settings()


# ═══════════════════════════════════════════════════════════
# 显示刷新
# ═══════════════════════════════════════════════════════════

func _refresh_all_displays() -> void:
	bgm_value.text = str(int(bgm_slider.value))
	sfx_value.text = str(int(sfx_slider.value))
	voice_value.text = str(int(voice_slider.value))
	_refresh_text_speed_display()
	auto_play_check.text = "开启" if auto_play_check.button_pressed else "关闭"
	skip_check.text = "开启" if skip_check.button_pressed else "关闭"
	fullscreen_check.text = "开启" if fullscreen_check.button_pressed else "关闭"


func _refresh_text_speed_display() -> void:
	var idx := int(text_speed_slider.value)
	if idx >= 1 and idx < SPEED_LABELS.size():
		text_speed_value.text = SPEED_LABELS[idx]


# ═══════════════════════════════════════════════════════════
# 返回（先 hide_menu，再发信号）
# ═══════════════════════════════════════════════════════════

func _on_back() -> void:
	hide_menu()
	back_pressed.emit()


## 开发者测试按钮：设置标志后切换到游戏场景
func _on_dev_test() -> void:
	var eb: Node = get_node("/root/EventBus")
	eb.dev_test_mode = true
	print("[SettingsMenu] 开发者测试模式开启")
	hide_menu()
	await get_tree().create_timer(0.2).timeout
	print("[SettingsMenu] 切换到 main.tscn")
	get_tree().change_scene_to_file("res://scenes/game/main.tscn")
