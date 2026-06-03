# Godot Galgame Framework

> **引擎**：Godot 4.4.1~4.6.0  
> **类型**：视觉小说（Visual Novel）通用框架  
> **项目定位**：可复用的 Galgame 开发框架 — 自定义剧本解析、分层立绘渲染、分支选择、成就/存档/好感度/转场/音频全套系统开箱即用

### 目录结构

```
├── autoload/                    # 全局单例（Autoload）
│   ├── EventBus.gd              # 事件总线
│   ├── DialogManager.gd         # 对话管理器
│   ├── AchievementManager.gd    # 成就管理器
│   ├── SaveManager.gd           # 存档管理器
│   ├── TransitionManager.gd     # 转场管理器
│   └── AudioManager.gd          # 音频管理器
├── scenes/
│   ├── game/
│   │   └── main.tscn            # 游戏主框架
│   ├── ui/                      # UI 场景
│   │   ├── title_screen.tscn    # 标题界面
│   │   ├── dialog_ui.tscn       # 对话界面
│   │   ├── choice_menu.tscn     # 分支选择菜单
│   │   ├── achievement_popup.tscn  # 成就弹窗
│   │   ├── menu.tscn            # 暂停菜单
│   │   ├── save_menu.tscn       # 存档菜单
│   │   ├── settings_menu.tscn   # 设置菜单
│   │   ├── choice_button.tscn   # 选项按钮
│   │   ├── character_renderer.tscn  # 分层立绘渲染器
│   │   └── confirm_popup.tscn   # 确认弹窗
│   └── effects/                 # 转场效果场景
│       ├── fade_to_black.tscn
│       └── fade_from_black.tscn
├── scripts/
│   ├── game/main.gd             # 游戏主控逻辑
│   ├── ui/                      # UI 逻辑脚本
│   ├── effects/                 # 转场逻辑脚本
│   └── ui/character_data.gd     # 角色配置 Resource 类
├── resources/
│   ├── scripts/                 # 剧本文件 (.txt)
│   ├── audio/                   # 音频资源
│   ├── backgrounds/             # 背景图
│   ├── characters/              # 角色立绘（按角色ID分目录）
│   ├── achievements/            # 成就定义 JSON
│   ├── ui/                      # UI 素材
│   └── font/                    # 字体
├── tools/                       # 辅助工具
│   ├── sprite_sheet_cropper.py  # 立绘裁剪工具
│   └── gen_one_char.py          # 单张生成工具
└── project.godot                # 项目配置
```


---

## 📜 剧本指令系统 ⭐⭐⭐

剧本使用 `.txt` 文件（`resources/scripts/`），自定义指令驱动，可直接编辑修改。此功能也是此项目的框架核心。

### 基本结构

```
@chapter chapter_name

@label start
@bg bg_1
@bgm bgm_track
@transition fade_from_black 0.8

@perform char_id pose_name
角色名: 你好呀！

旁白: 这是一个旁白。

@choice
你想做什么？
选项A → @jump route_a
选项B → @jump route_b

@label route_a
@chapter_end
```

### 完整指令表

| 指令 | 格式 | 说明 | 示例 |
|------|------|------|------|
| **对话** | `角色名: 内容` | 角色对话 | `金苹果派: 早上好。` |
| **旁白** | `旁白: 内容` | 叙述性文字 | `旁白: 风吹过校园。` |
| **章节** | `@chapter <ID>` | 标记章节开始 | `@chapter act1` |
| **标签** | `@label <名称>` | 定义跳转目标 | `@label start` |
| **跳转** | `@jump <标签>` | 跳转到指定标签 | `@jump rooftop` |
| **背景** | `@bg <ID>` | 切换背景图像 | `@bg bg_1` |
| **BGM** | `@bgm <ID>` | 切换背景音乐 | `@bgm peaceful_day` |
| **转场** | `@transition <效果> [时长]` | 播放转场动画 | `@transition fade_to_black 1.0` |
| **表演整图** | `@perform <角色ID> <表演名>` | 显示完整表演立绘 | `@perform hero wink` |
| **身体姿态** | `@pose <角色ID> <姿态名>` | 切换身体姿态（分层模式） | `@pose hero stand` |
| **面部表情** | `@expression <角色ID> <表情名>` | 切换面部表情（分层模式） | `@expression hero smile` |
| **水平翻转** | `@char_flip <角色ID>` | 翻转角色左右朝向 | `@char_flip hero` |
| **移动侧位** | `@char_side <角色ID> <left\|right>` | 将角色移动到指定侧 | `@char_side hero right` |
| **运行时缩放** | `@char_scale <角色ID> <倍率>` | 动态缩放立绘大小 | `@char_scale hero 1.3` |
| **好感度** | `@affection <角色ID> <数值>` | 增减好感度 | `@affection hero +5` |
| **成就** | `@achievement unlock <ID> [名称] [描述]` | 解锁成就 | `@achievement unlock first_meet 初次见面` |
| **事件** | `@event <事件名>` | 触发自定义事件 | `@event story_progress` |
| **选项** | `@choice` → 提示 → 选项列表 | 分支选择 | 见下方示例 |
| **章节结束** | `@chapter_end` | 标记当前章节结束 | `@chapter_end` |

### 选项分支

```
@choice
和谁一起去食堂？
和雪乃一起 → @jump lunch_snow
去找玲音 → @jump lunch_lin

@label lunch_snow
雪乃: 那我们走吧！
```
备注：
- `@choice` 后第一行为提示文本（可选）
- 每行一个选项，`选项文字 → @jump 标签`
- 支持多级嵌套选择

### 转场效果

| 效果名 | 说明 | 默认时长 |
|--------|------|---------|
| `fade_to_black` | 画面渐变到全黑 | 1.0s |
| `fade_from_black` | 从全黑渐变为画面 | 1.0s |

可在 `TransitionManager.gd` 的 `TRANSITIONS` 字典中注册新效果。

### 角色资源目录约定

```
resources/characters/<角色ID>/
├── character.tres              ← CharacterData 资源配置
├── pose_stand.png              ← 姿态图（脸部镂空）
├── pose_wave.png               ← 其他姿态
├── expression_normal.png       ← 表情图（仅五官）
├── expression_smile.png        ← 其他表情
└── perform_greet.png           ← 表演整图（可选，未提供分层素材时自动降级至此）
```
说明：姿态图（脸部镂空）+表情图（仅五官）= 表演整图（通过程序拼接）——>这样可以实现角色的动态表情切换，且更灵活，美术资源也相对较少，减轻负担。可能以后会考虑使用live2d模型，以实现更丰富的表情切换（flag）

注：当前版本使用的依然是表演整图（即完整立绘），暂时未对分层素材进行拼接程序的开发测试。

---

## 🛠 API 速查

### EventBus — 全局事件总线

```gdscript
# 订阅 / 发射 / 取消
EventBus.subscribe("event_name", callback)
EventBus.emit_event("event_name", {key = "value"})
EventBus.unsubscribe("event_name", callback)
```

| 事件名 | 数据字段 | 说明 |
|--------|---------|------|
| `background_changed` | `background` | 背景切换 |
| `bgm_changed` | `track` | BGM 切换 |
| `character_pose_changed` | `character_id, pose` | 姿态切换 |
| `character_expression_changed` | `character_id, expression` | 表情切换 |
| `character_performance_changed` | `character_id, performance` | 表演整图切换 |
| `character_flipped` | `character_id` | 角色翻转 |
| `character_side_changed` | `character_id, side` | 角色侧位移动 |
| `character_scale_changed` | `character_id, scale` | 角色缩放 |
| `achievement_unlocked` | `achievement_id, name, description` | 成就解锁 |
| `affection_changed` | `character_id, value` | 好感度变化 |
| `game_saved` | `slot, timestamp` | 存档完成 |
| `game_loaded` | `slot` | 读档完成 |

### DialogManager — 对话管理器

```gdscript
DialogManager.load_dialog_script("res://resources/scripts/story.txt")
DialogManager.start_dialog("start")   # 从标签开始
DialogManager.next_line()              # 推进到下一行
DialogManager.get_state()              # 获取状态（IDLE/PLAYING/PAUSED）
DialogManager.get_current_script_path()  # 获取当前脚本路径
DialogManager.restore_from_save(data)    # 从存档恢复

# 信号
dialog_started.connect(_on_started)       # dialog开始(chapter_name)
dialog_line_changed.connect(_on_line)     # 行变化(speaker, text)
dialog_ended.connect(_on_ended)           # 对话结束
choice_triggered.connect(_on_choice)      # 选项触发(options, prompt)
text_animation_skip.connect(_on_skip)     # 跳过逐字动画
```

### CharacterData — 角色配置 Resource

Godot 编辑器 → 右键 → 新建 Resource → CharacterData

```gdscript
@export var character_id: String         # 角色标识
@export var display_name: String         # 显示名称
@export var face_offset: Vector2         # 表情叠加偏移
@export var target_height: float         # 目标显示高度（默认 380px）

@export var poses: Dictionary            # 姿态纹理集
@export var expressions: Dictionary      # 表情纹理集
@export var performances: Dictionary     # 表演整图集

data.get_pose_names()                    # 获取所有姿态名
data.has_pose("stand")                   # 检查姿态是否存在
```

### CharacterRenderer — 分层立绘渲染器

```
节点结构:
CharacterRenderer (Node2D)
├── BodySprite    ← 身体姿态（脸部镂空）
├── FaceSprite    ← 表情叠加层
└── PerformSprite ← 表演整图
```

```gdscript
renderer.setup(character_data)                     # 初始化
renderer.set_pose("stand")                         # 切换姿态（Tween淡入淡出）
renderer.set_expression("smile")                   # 切换表情
renderer.set_performance("wink")                   # 表演整图
renderer.set_flip_h(true)                          # 水平翻转
renderer.set_scale_override(1.3)                   # 运行时缩放
renderer.play_slide_in(from_left)                  # 滑入动画
renderer.play_slide_out(to_left)                   # 滑出动画

# 信号
pose_changed, expression_changed, performance_started, performance_ended
```

### AchievementManager — 成就管理器

```gdscript
AchievementManager.unlock(achievement_id)
AchievementManager.is_unlocked(achievement_id)
AchievementManager.get_achievement_info(achievement_id)
AchievementManager.get_statistics()
AchievementManager.load_achievement_definitions("res://path.json")
```

### SaveManager — 存档管理器

```gdscript
SaveManager.save_game(slot)           # 0~5
SaveManager.load_game(slot)
SaveManager.get_slot_info(slot)       # 返回 SaveData
SaveManager.delete_slot(slot)
SaveManager.pending_load_slot         # 标题画面读档用
```

### TransitionManager — 转场管理器

```gdscript
TransitionManager.play_transition("effect_name", duration)
# 注册新效果：在 TRANSITIONS 字典添加 {"name": "res://path.tscn"}
```

### AudioManager — 音频管理器

```gdscript
AudioManager.play_bgm("track_id")
AudioManager.play_sfx("sfx_name")
AudioManager.play_voice("voice_name")
AudioManager.set_bgm_volume(0.0~1.0)
AudioManager.set_sfx_volume(0.0~1.0)
AudioManager.set_voice_volume(0.0~1.0)
```

---


## 🛠 扩展开发 ⭐

### 添加剧本指令

在 `DialogManager.gd` 的两处添加：

```gdscript
# _parse_instruction() 中：
"my_command":
    return {"type": "instruction", "instruction": "my_command", "value": parts[1]}
```

```gdscript
# _execute_instruction() 中：
"my_command":
    EventBus.emit_event("my_event", {"value": instruction.get("value")})
```

### 添加转场效果

1. 创建脚本：`scripts/effects/my_effect.gd`（extends CanvasLayer，实现 `play(duration)`）
2. 创建场景：`scenes/effects/my_effect.tscn`
3. 注册：在 `TransitionManager.gd` 的 `TRANSITIONS` 字典添加一行
4. 剧本中使用：`@transition my_effect 1.0`

### 添加新系统

1. 创建脚本放入 `autoload/`，实现 `_init()` 中注册到 EventBus
2. 在 `project.godot` 的 `[autoload]` 中添加
3. 通过 EventBus 与现有系统通信

---


