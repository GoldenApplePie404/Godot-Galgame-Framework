# 角色立绘资源说明

本文件夹存放所有角色立绘资源，每个角色有独立的子文件夹。

## 文件夹结构

```
characters/
├── xuena/          # 雪乃（妈系学姐）
├── lingyin/        # 玲音（萝莉系学妹）
├── xiaoshuang/     # 晓霜（傲娇系同班）
├── yeyu/           # 夜雨（神秘系转学生）
├── xinghe/         # 星河/夏奈（元气系好友）
└── README.md       # 本文件
```

## 角色与文件对应表

| 角色名 | 文件夹 | 默认立绘文件名 | 描述 |
|--------|--------|----------------|------|
| 雪乃 | `xuena/` | `xuena_default.png` | 妈系学姐，温柔照顾人 |
| 玲音 | `lingyin/` | `lingyin_default.png` | 萝莉系学妹，呆萌撒娇 |
| 晓霜 | `xiaoshuang/` | `xiaoshuang_default.png` | 傲娇系同班，毒舌嘴硬心软 |
| 夜雨 | `yeyu/` | `yeyu_default.png` | 神秘系转学生，高冷难以捉摸 |
| 星河/夏奈 | `xinghe/` | `xinghe_default.png` | 元气系好友，开朗吐槽 |

## 立绘规格建议

- **尺寸**: 1024x1536 或 2048x3072 (竖版立绘)
- **格式**: PNG (支持透明背景)
- **姿势/表情**: 每个角色建议准备多张不同表情的立绘
  - 默认/微笑: `*_default.png`
  - 严肃: `*_serious.png`
  - 生气: `*_angry.png`
  - 害羞: `*_shy.png`
  - 难过: `*_sad.png`

## 在Godot中使用

```gdscript
# 加载角色立绘
var texture = load("res://resources/characters/xuena/xuena_default.png")

# 在Sprite2D中显示
$Sprite2D.texture = texture
```

## 注意事项

1. 当前立绘为AI生成的概念图，仅供开发阶段使用
2. 正式版需要请画师绘制风格统一的立绘
3. AI生成的图片可能存在版权问题，正式发布前务必替换
4. 建议为每个角色建立表情/姿势变体文件夹

---

*创建时间: 2026-04-30*
*最后更新: 2026-04-30*