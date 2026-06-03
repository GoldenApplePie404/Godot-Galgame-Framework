# achievement_popup.gd
extends CanvasLayer

const POPUP_DURATION: float = 3.0      # 显示停留时间（秒）
const SLIDE_DURATION: float = 0.3       # 滑入/滑出时长（秒）
const RIGHT_MARGIN: float = 16          # 右侧边距

@onready var card: Panel = $"%Card"
@onready var name_label: Label = $"%NameLabel"
@onready var desc_label: Label = $"%DescLabel"

var _screen_width: float = 0.0


func _ready() -> void:
	_screen_width = get_viewport().get_visible_rect().size.x
	# 初始偏移到屏幕右侧外
	_apply_offset(_screen_width + 20)
	card.hide()


## 外部入口：启动弹窗动画
func show_popup(data: Dictionary) -> void:
	name_label.text = data.get("name", "未知成就")
	if desc_label:
		desc_label.text = data.get("description", "")
	
	card.show()
	
	# 计算滑入/滑出的 CanvasLayer.offset 值
	# Card 在场景中的 offset_left=810，目标可见位置为 screen_width - card_width - margin
	var card_width := card.size.x
	var target_offset: float = _screen_width - card_width - RIGHT_MARGIN - card.offset_left
	var start_offset: float = _screen_width + 20 - card.offset_left
	
	# 从右侧外滑入
	self.offset = Vector2(start_offset, 0)
	await get_tree().process_frame  # 确保位置已应用
	
	var tween_in := create_tween()
	tween_in.tween_property(self, "offset:x", target_offset, SLIDE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween_in.finished
	
	# 停留
	await get_tree().create_timer(POPUP_DURATION).timeout
	
	# 滑出
	var tween_out := create_tween()
	tween_out.tween_property(self, "offset:x", start_offset, SLIDE_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween_out.finished
	
	queue_free()


## 设置 CanvasLayer 的整体偏移
func _apply_offset(x_offset: float) -> void:
	self.offset = Vector2(x_offset - card.offset_left, 0)
