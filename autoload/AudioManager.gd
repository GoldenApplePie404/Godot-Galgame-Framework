# AudioManager.gd
# 音频管理器 — Autoload 单例
# 负责播放 SFX 音效，管理音频总线
# 使用方法：AudioManager.play_sfx("ui_click")

extends Node

## SFX 注册表 — 音效名 → 文件路径
const SFX_REGISTRY := {
	"ui_click":   "res://resources/audio/sfx/ui_click.wav",
	"ui_confirm": "res://resources/audio/sfx/ui_confirm.wav",
	"ui_cancel":  "res://resources/audio/sfx/ui_cancel.wav",
	"ui_hover":   "res://resources/audio/sfx/ui_hover.wav",
	"ui_popup":   "res://resources/audio/sfx/ui_popup.wav",
}

## SFX 播放器池（预加载，避免每��播放都 load）
var _players: Dictionary = {}
var _sfx_bus_idx: int = -1


func _ready() -> void:
	_sfx_bus_idx = AudioServer.get_bus_index("Master")
	_preload_sfx()


## 预加载所有 SFX 到内存
func _preload_sfx() -> void:
	for name in SFX_REGISTRY:
		var path: String = SFX_REGISTRY[name]
		var stream: AudioStream = load(path)
		if stream:
			var player := AudioStreamPlayer.new()
			player.stream = stream
			player.volume_db = 0.0
			player.bus = "SFX"
			player.process_mode = PROCESS_MODE_ALWAYS
			add_child(player)
			_players[name] = player

## 播放音效
func play_sfx(name: String) -> void:
	var player: AudioStreamPlayer = _players.get(name)
	if player == null:
		push_warning("AudioManager: 未知音效 '%s'" % name)
		return
	player.stop()
	player.play()
