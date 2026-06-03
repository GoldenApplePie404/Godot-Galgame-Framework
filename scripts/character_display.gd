extends Node2D

# 角色显示测试脚本
# 用于测试角色立绘在游戏中的显示效果
# 使用方法：将此脚本挂载到任何 Node2D 节点上

@onready var sprite_2d = $Sprite2D
@onready var label_name = $UI/NameLabel
@onready var label_expression = $UI/ExpressionLabel

# 角色列表
var characters = ["xuena", "lingyin", "xiaoshuang", "yeyu", "xinghe"]

# 表情列表
var expressions = ["default", "serious", "shy", "angry", "sad", "happy"]

# 当前显示的角色和表情
var current_character: String = "xuena"
var current_expression: String = "default"

# 初始化
func _ready():
    set_process_input(true)
    update_character_display()
    print("角色显示测试 - 按键说明:")
    print("  1 - 切换角色")
    print("  2 - 切换表情")
    print("  3 - 左侧显示")
    print("  4 - 右侧显示")
    print("  ESC - 退出")

# 输入处理
func _input(event):
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_1: # 切换角色
                switch_character()
            KEY_2: # 切换表情
                switch_expression()
            KEY_3: # 左侧显示
                position_character(-1)
            KEY_4: # 右侧显示
                position_character(1)
            KEY_ESCAPE: # 退出
                get_tree().quit()

# 切换角色
func switch_character():
    var idx = characters.find(current_character)
    idx = (idx + 1) % characters.size()
    current_character = characters[idx]
    current_expression = "default" # 重置为默认表情
    update_character_display()
    print("切换角色: ", current_character)

# 切换表情
func switch_expression():
    var idx = expressions.find(current_expression)
    idx = (idx + 1) % expressions.size()
    current_expression = expressions[idx]
    update_character_display()
    print("切换表情: ", current_expression)

# 定位角色（左/右）
func position_character(direction: int):
    var screen_width = get_viewport_rect().size.x
    var screen_height = get_viewport_rect().size.y
    
    if direction < 0:
        sprite_2d.position.x = screen_width * 0.25
    else:
        sprite_2d.position.x = screen_width * 0.75
    
    sprite_2d.position.y = screen_height * 0.6

# 更新角色显示
func update_character_display():
    # 构建文件路径
    var path = "res://resources/characters/%s/%s_%s.png" % [current_character, current_character, current_expression]
    
    # 尝试加载纹理
    var texture = load(path)
    
    if texture:
        sprite_2d.texture = texture
        label_name.text = current_character
        label_expression.text = current_expression
        print("成功加载: ", path)
    else:
        # 如果指定表情不存在，尝试default
        if current_expression != "default":
            current_expression = "default"
            update_character_display()
        else:
            printerr("无法加载纹理: ", path)
            label_name.text = "未找到: " + current_character
            label_expression.text = current_expression
