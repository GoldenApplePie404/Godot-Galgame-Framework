# save_menu.gd
# 存档菜单 — 6 槽位存档界面
# 点击空槽位 → 保存；点击已用槽位 → 弹出确认框（覆盖/读取/取消）

extends Control

signal back_pressed
signal load_and_close       # 读档完成后应关闭整个菜单返回游戏

const ANIM_DURATION: float = 0.15
const ConfirmPopupScene = preload("res://scenes/ui/confirm_popup.tscn")

# ── 节点引用 ──────────────────────────────────────
var slot_01: Button
var slot_02: Button
var slot_03: Button
var slot_04: Button
var slot_05: Button
var slot_06: Button
var back_btn: Button

var _slots: Array[Button] = []
var _confirm_popup: Control = null      # 确认弹窗（实例化场景）
var _pending_slot: int = -1             # 当前操作的槽位


# ══════════════════════════════════════════════════════
#  生命周期
# ══════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	modulate.a = 0.0
	hide()

	_inject_nodes()
	_slots = [slot_01, slot_02, slot_03, slot_04, slot_05, slot_06]
	_init_signal_connections()
	_init_confirm_popup()


func _inject_nodes() -> void:
	var base := "PanelContainer/VBoxContainer/ScrollContainer/SlotContainer"
	slot_01 = _safe_get(base + "/Slot01")
	slot_02 = _safe_get(base + "/Slot02")
	slot_03 = _safe_get(base + "/Slot03")
	slot_04 = _safe_get(base + "/Slot04")
	slot_05 = _safe_get(base + "/Slot05")
	slot_06 = _safe_get(base + "/Slot06")
	back_btn = _safe_get("PanelContainer/VBoxContainer/BackBtn")


func _safe_get(path: String) -> Node:
	var node := get_node(path)
	if node == null:
		push_error("SaveMenu: 节点未找到 → %s" % path)
	return node


func _init_signal_connections() -> void:
	for i in _slots.size():
		var idx := i
		if _slots[i]:
			_slots[i].pressed.connect(_on_slot_pressed.bind(idx))

	if back_btn:
		back_btn.pressed.connect(_on_back)


# ══════════════════════════════════════════════════════
#  确认弹窗（实例化场景）
# ══════════════════════════════════════════════════════

func _init_confirm_popup() -> void:
	_confirm_popup = ConfirmPopupScene.instantiate()
	add_child(_confirm_popup)
	_confirm_popup.save_pressed.connect(_on_confirm_save)
	_confirm_popup.load_pressed.connect(_on_confirm_load)
	_confirm_popup.cancel_pressed.connect(_on_confirm_cancel)


# ══════════════════════════════════════════════════════
#  显示 / 隐藏
# ══════════════════════════════════════════════════════

func show_menu() -> void:
	show()
	_refresh_all_slots()
	_confirm_popup.hide_popup()
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, ANIM_DURATION)


func hide_menu() -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, ANIM_DURATION)
	t.tween_callback(hide)


# ══════════════════════════════════════════════════════
#  槽位刷新
# ══════════════════════════════════════════════════════

func _refresh_all_slots() -> void:
	var sm := _get_sm()
	if sm == null:
		return

	for i in range(6):
		var data: SaveData = sm.get_slot_info(i)
		if data.is_empty():
			_show_empty_slot(i)
		else:
			_show_filled_slot(i, data)


func _show_empty_slot(index: int) -> void:
	if _slots[index] == null:
		return
	_slots[index].text = "存档 %02d  ——  空  ——" % (index + 1)
	_slots[index].add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 1))


func _show_filled_slot(index: int, data: SaveData) -> void:
	if _slots[index] == null:
		return
	_slots[index].text = "存档 %02d  |  %s  |  %s" % [
		index + 1,
		data.get_display_date(),
		data.chapter_name,
	]
	_slots[index].add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 1))


# ══════════════════════════════════════════════════════
#  槽位点击处理
# ══════════════════════════════════════════════════════

func _on_slot_pressed(index: int) -> void:
	var sm := _get_sm()
	if sm == null:
		return

	var data: SaveData = sm.get_slot_info(index)

	if data.is_empty():
		# 空槽位 → 直接保存
		print("[SaveMenu] 槽位 %d 为空，直接保存" % (index + 1))
		sm.save_game(index)
		_refresh_all_slots()
	else:
		# 已用槽位 → 弹出确认框
		print("[SaveMenu] 槽位 %d 已有存档，弹出确认框" % (index + 1))
		_pending_slot = index
		_confirm_popup.show_popup("存档 %02d — %s\n%s" % [
			index + 1,
			data.get_display_date(),
			data.chapter_name,
		])


# ══════════════════════════════════════════════════════
#  确认弹窗按钮（由场景信号触发）
# ══════════════════════════════════════════════════════

func _on_confirm_save() -> void:
	var sm := _get_sm()
	if sm and _pending_slot >= 0:
		sm.save_game(_pending_slot)
		_refresh_all_slots()
	_pending_slot = -1


func _on_confirm_load() -> void:
	var sm := _get_sm()
	if sm and _pending_slot >= 0:
		sm.load_game(_pending_slot)
		# 读档后直接隐藏菜单（此时游戏可能处于暂停状态，tween 不会正确执行）
		hide()
		modulate.a = 1.0
		load_and_close.emit()
	_pending_slot = -1


func _on_confirm_cancel() -> void:
	_pending_slot = -1


func _on_back() -> void:
	hide_menu()
	back_pressed.emit()


# ══════════════════════════════════════════════════════
#  工具
# ══════════════════════════════════════════════════════

func _get_sm() -> Node:
	return get_node_or_null("/root/SaveManager")
