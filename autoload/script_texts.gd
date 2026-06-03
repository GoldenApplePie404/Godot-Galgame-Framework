# script_texts.gd
# 对话脚本文本内嵌包 — 确保导出版中所有剧本内容 100% 存在
# GDScript 文件会被编译进导出版，不受 .txt 导入问题影响

class_name ScriptTexts
extends Node

## 根据路径获取对应的剧本全文（如果 FileAccess 加载失败时的兜底）
static func get_text(file_path: String) -> String:
	match file_path:
		"res://resources/scripts/framework_test.txt":
			return _FRAMEWORK_TEST
		"res://resources/scripts/prologue_chapter1.txt":
			return _PROLOGUE
		"res://resources/scripts/chapter1_spring_breeze_draft.txt":
			return _CH1_DRAFT
		"res://resources/scripts/chapter2_spring_breeze.txt":
			return _CH2
		"res://resources/scripts/chapter3_glimmer.txt":
			return _CH3
		"res://resources/scripts/test_dialog.txt":
			return _TEST
		"res://resources/scripts/integration_test_dialog.txt":
			return _INTEGRATION
	return ""


## 框架综合测试脚本（完整内容在 resources/scripts/framework_test.txt）
const _FRAMEWORK_TEST := """
# 框架综合测试脚本
# 覆盖全部功能指令 + 左右两侧
# 金苹果派的青春可爱演绎

@chapter framework_test

@label start
@bg bg_1
@bgm peaceful_day
@transition fade_from_black 0.8

旁白: 诶，好像有人在那边——
旁白: 哦，原来是你呀！今天要一起测试新功能对吧？
@perform gap wink
金苹果派: 喵~等你半天啦！我准备了好多好玩的！

@choice
要开始吗？
好呀好呀！
@jump test_basic
再等一下下…
@jump test_delay1

# ── 等等×1 ──
@label test_delay1
@perform gap stand
金苹果派: 唔…还要等哦？
金苹果派: 好吧好吧，那你快点哦！
@choice
还测试吗？
开始啦！
@jump test_basic
再一下下…
@jump test_delay2

# ── 等等×2 ──
@label test_delay2
@perform gap smile2
金苹果派: 又等一下！！q(≧口≦)q
金苹果派: 我站在这儿好无聊的！
@choice
还测试吗？
开始吧！
@jump test_basic
等等啦
@jump test_delay3

# ── 等等×3 ──
@label test_delay3
@perform gap wink
金苹果派: 第三次了！第三次了哦！
金苹果派: 你再不开始我就一个人玩了哼！
@choice
还测试吗？
开始开始！
@jump test_basic
再一下下嘛
@jump test_delay4

# ── 等等×4 ──
@label test_delay4
@perform gap smile2
金苹果派: ………………
金苹果派: 我什么都没说，你自己看着办(￣▽￣)"
@choice
还测试吗？
好啦我错了开始吧
@jump test_basic
再等一下……
@jump test_delay5

# ── 等等×5（最后一次） ──
@label test_delay5
@perform gap stand
金苹果派: ……第五次。
金苹果派: 这是最后的最后的机会了哦！
@choice
还测试吗？
进行测试（没有别的选项啦！）
@jump test_basic

# ═══════════════════════════════════════════════════════
# 测试1：基础对话 + 左侧表演
# ═══════════════════════════════════════════════════════

@label test_basic
@perform gap wink
金苹果派: 好哒！终于开始了！ヾ(^▽^)ノ
金苹果派: 第一回合！基础对话测试——走起！

@perform gap stand
金苹果派: 喵~我先站好，默认姿势~你看到的对吧？
@perform gap smile
金苹果派: 嘿嘿，笑一个~怎么样怎么样？
@perform gap smile2
金苹果派: 这个是眯眯眼笑~看起来是不是有点小狡猾？
@perform gap wink
金苹果派: OK手势加眨眼！耶！
@perform gap welcome
金苹果派: 张开双手！欢迎光临！嘿嘿~

@perform gap stand
金苹果派: 好惹，五个姿势都换了一遍！全部OK！

@perform gap smile
金苹果派: 对了对了！还有个新功能——缩放！
@char_scale gap 1.3
金苹果派: 哇！变大啦！！是不是超有冲击力的！✧
@perform gap wink
金苹果派: 这个适合「震惊！」或者「超级得意！」的时候用~
@char_scale gap 0.7
金苹果派: 诶嘿~变小啦…委屈巴巴的感觉？
@perform gap smile2
金苹果派: 像这样缩成一团~可爱吧喵！
@char_scale gap 1.0
金苹果派: 好惹~变回正常大小！还是这个最舒服！

@choice
基础对话测试通过了吗？
全部OK！继续~
@jump begin_test2
好像有Bug……
@jump report_bug

@label report_bug
@perform gap stand
金苹果派: 诶？！有Bug吗…
金苹果派: 好吧我记下来了，后面就不测了。
@jump bad_ending

@label begin_test2
金苹果派: 耶！第一个测试完美通过！
@transition fade_to_black 0.5

# ═══════════════════════════════════════════════════════
# 测试2：右侧展示 + 翻转
# ═══════════════════════════════════════════════════════

@transition fade_from_black 0.5
@char_side gap right
@perform gap stand
金苹果派: 哇！我现在在右边啦！↖(^ω^)↗
金苹果派: 看，面朝你的方向哦！

@char_flip gap
金苹果派: 嘿！转过去啦——现在看另一边了！
金苹果派: 剧情里想让我转身的话，就用这个指令~

@char_flip gap
金苹果派: 转回来！嘿嘿好玩吧？

@perform gap smile
金苹果派: 右边也能笑！功能完全正常！

@perform gap wink
金苹果派: 右边也能wink！怎么样，厉害吧！

@choice
右侧+翻转测试通过了吗？
完全OK！
@jump right_ok
有问题！
@jump report_bug2

@label report_bug2
金苹果派: 啊…右侧有问题吗…记下来了…
@jump bad_ending

@label right_ok
金苹果派: 好耶！右侧测试通过！(๑•̀ㅂ•́)و✧
@transition fade_to_black 0.5

# ═══════════════════════════════════════════════════════
# 测试3：背景/BGM切换
# ═══════════════════════════════════════════════════════

@transition fade_from_black 0.5
@char_side gap left
@perform gap wink
金苹果派: 回来啦！左边还是熟悉的感觉~
金苹果派: 现在试试换背景和音乐！

@bg bg_2
旁白: 背景从校门口变成了校园内~
@bgm track_test
旁白: BGM也切换啦！气氛不一样了~
@bg bg_3
旁白: 又换到食堂了！闻到了炸猪排的味道~
@bg bg_1
@bgm peaceful_day
旁白: 换回原来的~一切正常！

金苹果派: 背景和BGM都没问题！棒棒的！

@choice
背景/BGM测试通过了吗？
没问题！
@jump bg_ok
有Bug！
@jump report_bug3

@label report_bug3
金苹果派: 诶…背景有问题吗…好吧…
@jump bad_ending

@label bg_ok
金苹果派: 背景BGM通过！Y(^o^)Y
@transition fade_to_black 0.3

# ═══════════════════════════════════════════════════════
# 测试4：存档/读档
# ═══════════════════════════════════════════════════════

@transition fade_from_black 0.3
@perform gap wink
金苹果派: 测试4来啦！这次是存档功能~

@perform gap stand
金苹果派: 呐，你看，现在剧情里我说了这么多话对吧？
金苹果派: 如果这时候存个档，下次读档就能从这里继续！
金苹果派: 来试试看~ 按「ESC」打开菜单！

@perform gap smile
金苹果派: 看到「存档」按钮了吗？点进去，选一个空位~
金苹果派: 然后点「保存」！搞定！

@perform gap wink
金苹果派: 好了，现在试试「读档」？重新进游戏的话，点「读档」选你刚才存的那一栏~
金苹果派: 啊……不过跑测试中途不太好直接读档跳走。
金苹果派: 所以这个功能就由你在实际游戏里亲自验证啦！

金苹果派: 我帮你确认一下——存档系统确实已经在工作了！

@choice
存档系统可以用了吗？
没问题！
@jump save_ok
有问题！
@jump report_bug4

@label report_bug4
金苹果派: 诶？！存档有问题吗…
金苹果派: 好吧记下了……后面的不能测了(´;ω;｀)
@jump bad_ending

@label save_ok
金苹果派: 好耶！存档没问题！
金苹果派: 记得到时候实际游戏里按ESC存档哦！
@transition fade_to_black 0.3

# ═══════════════════════════════════════════════════════
# 测试5：选项分支 + 好感度
# ═══════════════════════════════════════════════════════

@transition fade_from_black 0.3
@perform gap wink
金苹果派: 接下来是选择题时间！
金苹果派: 选哪条路，后面的剧情就不一样了哦！

@choice
选一个吧！
今天超棒的！❤️
@jump route_praise
还…还行吧
@jump route_improve

# ── 路线A：被夸了 ──
@label route_praise
@perform gap smile
金苹果派: 诶嘿~被夸了好开心！！(〃▽〃)
@affection gap +5
金苹果派: 好感度UPUP！+5！
金苹果派: 心情超好！后面的测试也要加油！

@choice
选项分支测试通过了吗？
通过啦！
@jump praise_continue
有Bug…
@jump report_bug4

@label report_bug4
金苹果派: 呜呜…好吧记下了…
@jump bad_ending

@label praise_continue
金苹果派: 好！去测成就系统！
@jump test_achievement

# ── 路线B：被说还行 ──
@label route_improve
@perform gap stand
金苹果派: 唔…只是"还行"吗…
金苹果派: 好吧那我继续加油！(｀へ´)
@affection gap +3
金苹果派: 好感度+3…虽然不多但也是爱！

@choice
选项分支测试通过了吗？
通过啦！
@jump improve_continue
有Bug…
@jump report_bug4b

@label report_bug4b
金苹果派: 唔…好吧记下了…
@jump bad_ending

@label improve_continue
金苹果派: 好…去看成就吧。
@jump test_achievement

# ═══════════════════════════════════════════════════════
# 测试6：成就系统
# ═══════════════════════════════════════════════════════

@label test_achievement
@transition fade_to_black 0.3
@transition fade_from_black 0.3
@perform gap stand
金苹果派: 测试6——成就系统！
金苹果派: 叮！解锁一个成就给你看~

@achievement unlock gap_dev_test 开发者认证 以开发者身份完成框架测试
@perform gap wink
金苹果派: 看！成就弹窗出来了吧！是不是很酷！

@choice
成就系统OK吗？
OK！
@jump achieve_ok
有问题！
@jump report_bug5

@label report_bug5
金苹果派: 成就出问题了？记下了…
@jump bad_ending

@label achieve_ok
金苹果派: 成就系统通过！
@transition fade_to_black 0.3

# ═══════════════════════════════════════════════════════
# 测试7：事件系统
# ═══════════════════════════════════════════════════════

@transition fade_from_black 0.3
@perform gap stand
金苹果派: 测试7——事件系统！
金苹果派: 发射一个事件信号~biu！

@event gap_custom_event
@perform gap wink
金苹果派: 已发射！EventBus收到了吗？

@choice
事件系统OK吗？
OK！
@jump event_ok
有问题！
@jump report_bug6

@label report_bug6
金苹果派: 好吧事件有问题…记下了…
@jump bad_ending

@label event_ok
金苹果派: 事件系统通过！✧⁺⸜(●′▾`●)⸝⁺✧
@transition fade_to_black 0.3

# ═══════════════════════════════════════════════════════
# 测试8：左右交替快速切换
# ═══════════════════════════════════════════════════════

@transition fade_from_black 0.3
@char_side gap left
@perform gap stand
金苹果派: 最后一项！左右来回跑！
金苹果派: 看好了别眨眼——

@perform gap wink
金苹果派: 左边！wink！

@char_side gap right
@perform gap smile
金苹果派: 右边！笑！

@char_side gap left
@perform gap smile2
金苹果派: 左边！眯眯眼！

@char_side gap right
@perform gap welcome
金苹果派: 右边！欢迎光临！

@char_side gap left
@perform gap stand
金苹果派: 回到左边！完美收工！

@choice
全部测试的结果是？
完美通过！好耶！！
@jump happy_ending
有Bug要修……
@jump bad_ending

# ═══════════════════════════════════════════════════════
# ★ 好结局 ★
# ═══════════════════════════════════════════════════════

@label happy_ending
@bg bg_1
@bgm peaceful_day
@perform gap smile
金苹果派: 好耶！！全部通过啦！！🎉🎉🎉
金苹果派: ✅ 测试1（左侧基础）
金苹果派: ✅ 测试2（右侧翻转）
金苹果派: ✅ 测试3（背景BGM）
金苹果派: ✅ 测试4（存档读档）
金苹果派: ✅ 测试5（选项好感度）
金苹果派: ✅ 测试6（成就系统）
金苹果派: ✅ 测试7（事件系统）
金苹果派: ✅ 测试8（左右交替）
金苹果派: 全部搞定！我厉害吧！嘿嘿~

@perform gap wink
金苹果派: 有我在，没——问——题！✌️

@achievement unlock gap_happy_ending 完美通关 全部测试通过
@event gap_happy_ending

@transition fade_to_black 1.0
金苹果派: 下次再来找我玩呀！拜拜~👋
@chapter_end

# ═══════════════════════════════════════════════════════
# ★ 坏结局 ★
# ═══════════════════════════════════════════════════════

@label bad_ending
@transition fade_to_black 0.3
@bg bg_1
@bgm peaceful_day
@perform gap stand
金苹果派: 唔…有Bug需要修……
金苹果派: 虽然有点遗憾，但没关系的！
金苹果派: 修好了再来找我测就好啦~(｡•́︿•̀｡)

@perform gap wink
金苹果派: 开发者加油！我相信你！

@achievement unlock gap_need_fix 有待完善 有Bug需要修复
@event gap_need_fix

@transition fade_to_black 1.0
金苹果派: 下次见啦~等你好消息！
@chapter_end

"""

## 序章·破晓
const _PROLOGUE := """# 序章·破晓 - 对话脚本
# 转换自《剧情文案_序章_第一章.md》
# 格式说明：
# @chapter <章节名> - 设置当前章节
# @bg <背景ID> - 设置背景
# @bgm <音乐ID> - 设置背景音乐  
# @char <角色ID> <位置> <表情> - 显示角色
# @label <标签名> - 定义跳转标签
# @choice - 开始选项分支
# @jump <标签名> - 跳转到指定标签
# @achievement unlock <成就ID> - 解锁成就
# @event <事件名> - 触发事件
# 角色名: 对话内容 - 角色对话
# 旁白: 描述文本 - 旁白描述

@chapter prologue_dawn

@label start
@bg bg_1
@bgm peaceful_day
# === 序章开始 ===
旁白: 三月的风还带着些许凉意。我站在这所学校的校门前，仰头看着那行烫金大字。阳光透过云层洒下来，在地上投下斑驳的光影，将校门口的两座石狮子染上一层温暖的金边。
旁白: 说起来，我已经很久没有这样认真地看过一所学校了————那些黑历史不提也罢。重要的是，从今天开始，我要在新的环境里，开始新的生活了。
旁白: 我深吸一口气，闻到了春天特有的气息——泥土的芬芳、青草的清香，还有远处飘来的淡淡樱花香。说实话，心里还是有些紧张的。转学这种事，说起来轻巧，但真正站在一个陌生的地方，周围全是陌生的人，陌生的事，陌生的风景……说不忐忑是假的。
旁白: 但是——我握紧了书包带子。既然选择了重新开始，那就好好面对吧。

旁白: \"少了一份盖章的复印件……\"
旁白: 我蹲在校门口，把书包里的文件翻了一遍又一遍。春风凉飕飕的，吹得纸张哗啦作响。明明昨晚检查了三遍，怎么关键的转学证明就是找不着呢？教导处老师特意叮嘱过，今天不交齐手续就没法入学。
旁白: 额头开始冒汗。手指冰凉。心脏咚咚咚地敲打着胸腔。

雪乃: 那个……需要帮忙吗？
旁白: 一个温柔的声音从头顶传来。我猛地抬头，阳光有些刺眼，逆光中只看见一个模糊的轮廓。她蹲下身来，黑色的长发滑过肩头，校服裙子整齐地压在膝盖下。
@char snow left smile
雪乃: 我是学生会的雪乃，二年级。看你在这里翻了好久，是丢了什么东西吗？
主角: 转、转学证明……少了一份盖章的……
雪乃: 啊，那个啊。她眨眨眼，居然从自己的文件夹里抽出一张纸，教导处的老师刚才打电话给我，说看到监控里有个转学生在校门口转悠了十分钟，让我来看看。他猜你可能会漏掉这份——因为上周也有个转学生犯了一样的错误。
旁白: 她把文件递给我。纸张边缘平整，盖着鲜红的公章。
雪乃: 老师让我转交的。她站起身，拍了拍裙摆上的灰尘，顺便带你去办手续。
旁白: 我愣愣地接过文件，大脑一时没转过来。所以……她不是因为\"学生会职责\"来接我，而是因为老师发现了我的窘境？一股热意从脖子涌上脸颊。
主角: 谢、谢谢学姐……
雪乃: 不用谢。她微微一笑，眉眼弯弯，不过下次可得仔细点哦。重要的东西要放在固定的夹层里，像这样——
旁白: 她从自己的文件夹里抽出一个小巧的透明文件袋，里面整整齐齐地分类放着各种纸张。
雪乃: 看，按日期和类型分开，就不会乱了。
旁白: 她的动作很熟练，显然不是第一次做这种事。我看着她纤细的手指在文件间穿梭，突然意识到——这个人，好像把\"照顾别人\"当成了一种本能。
主角: 学姐……经常这样帮忙吗？
雪乃: 嗯？她抬起头，眼神有瞬间的恍惚，随即又恢复了温柔的笑意，算是吧。毕竟……我也曾经是转学生。
旁白: 她说完这句话，轻轻合上文件夹。阳光从她身后洒落，给她镀上了一层柔和的光晕。但不知为何，我觉得那道光芒有些……脆弱。
雪乃: 对了，你叫什么名字？
主角: 我叫——
# [主角名字输入将在游戏中处理]

雪乃: 【主角名】同学吗？好名字。她微笑着站起来，走吧，我带你去办手续。

# === 樱花大道场景 ===
@bg bg_1
旁白: 办完手续后，雪乃学姐带我参观校园。
旁白: 我们走在樱花大道上，三月的樱花还没完全盛开，但枝头已经挂满了粉白的花苞，偶尔有早开的花朵在风中轻轻摇曳。
旁白: 阳光透过枝叶的缝隙洒下来，在地上投下斑驳的光影。空气里弥漫着淡淡的花香和泥土的气息。
旁白: 雪乃学姐走在前面半步的位置，步伐不快不慢，刚好让我能跟上又不至于感到压力。

雪乃: 那边是教学楼，大部分课程都在那边上。食堂在穿过中庭的左手边，推荐周三的咖喱。
主角: 学姐记得好清楚啊。
雪乃: 因为去年我也像你一样，被学长学姐带着参观校园。她笑了笑，所以知道新来的最想知道什么。

旁白: 她的声音很轻很柔。说话的时候，她会微微侧过头来看我一眼，眼神里有种说不清的温暖——但又带着一丝若有若无的距离感。
旁白: 我说不清那是什么。就是觉得……她好像在用一种\"看着过去的自己\"的眼神看着我。

# === 食堂场景 ===
@label lunch
@bg bg_3
旁白: 中午，雪乃学姐带我去了食堂。
旁白: 食堂里已经排起了长队，各种食物的香气混合在一起——炸物、咖喱、味增汤……光是闻到就让人饿了。
旁白: 雪乃学姐轻车熟路地带我穿过人群，在最里面的窗口前停下来。

雪乃: 今天的推荐是炸猪排套餐。个人建议配一碗味增汤。
主角: 学姐经常来食堂吗？
雪乃: 嗯。她点点头，有时候学生会工作忙，来不及自己做便当的时候，就会来这里解决。
主角: 自己做便当？
雪乃: 啊……她愣了一下，耳根微微泛红，我是说……偶尔、偶尔会做！

旁白: 她慌乱地摆手的样子，和刚才那个从容的学姐判若两人。我忍不住笑了。

@char snow left smile
主角: 那有机会的话，我也想尝尝学姐的手艺。
雪乃: ……！她睁大眼睛看着我，然后迅速别过头去，声音里带着一丝笑意：
雪乃: 那、那要看你表现了。
旁白: 阳光从食堂的窗户洒进来，落在她微微泛红的耳尖上。

@event trigger prologue_lunch_ended
@char snow hide

# === 天台场景 ===
@label rooftop
@bg bg_4
旁白: 下午，我爬上了教学楼的天台。
旁白: 推开铁门的那一刻，视野豁然开朗。整个校园尽收眼底——整齐的教学楼、操场上的奔跑的身影、远处还未全开的樱花林、更远处的城市天际线。
旁白: 风很大，但很舒服。带着春天特有的温柔，吹在脸上凉丝丝的。

旁白: 我没想到天台上已经有人了。
雪乃: 啊……你果然来这里了。
旁白: 我转过头，看到雪乃学姐靠在栏杆边，手里拿着一罐热茶。

@char snow left smile
主角: 学姐怎么知道我会上来？
雪乃: 因为每个转学生都会在第一天找到这个天台。她笑了笑，把热茶递给我，这里视野最好，能看到整个校园。能看到……未来生活的地方。
旁白: 她说话的时候，视线投向远方。夕阳的光落在她的侧脸上，镀上一层柔和的金色。

旁白: 我们并肩站在栏杆边，谁也没有说话。风从耳边吹过，带来远处的喧嚣声和近处的呼吸声。
旁白: 那一刻很安静。安静得让我觉得——也许这个学校，真的可以成为我重新开始的地方。

雪乃: 【主角名】同学。
主角: 嗯？
雪乃: 欢迎来到这所学校。她转过头，对我露出一个温暖的笑容，如果有什么需要帮忙的，随时可以找我。
旁白: 夕阳正好落在她的身后。她的笑容在金色的光芒里，显得格外耀眼。

@event trigger prologue_rooftop_ended

# === 序章结束 ===
旁白: 这是我来到这所学校的第一天。
旁白: 我遇到了一个温柔的学姐。
旁白: 也看到了一个从未见过的自己。

@achievement unlock prologue_complete
@event trigger prologue_ended
旁白: ——序章·破晓·完——

@chapter_end
"""

## 第一章·春风（草稿）
const _CH1_DRAFT := """@chapter chapter1_spring_breeze

@label start
@bg bg_5  # 假设 bg_5 是教室（白天）
@bgm peaceful_day

# === 第一章开始 ===
旁白: 入学第一周，我逐渐适应了这里的生活。
旁白: 每天早上，我都会收到雪乃学姐的消息。

雪乃: 早安，【主角名】同学。今天吃早餐了吗？
旁白: 她的消息总是在我起床后不久就发来，像是每天早上准时响起的闹钟。只不过比闹钟温柔多了。
旁白: 说实话，我已经很久没有被人这样关心过了。以前的时候，每天早上叫醒我的只有闹钟的嗡嗡声。起床后，一个人对着空荡荡的房间，吃着便利店买来的面包，然后独自去上学。没有人会说\"早安\"，没有人在意我有没有吃早餐。
旁白: 但是现在——每天早上醒来，打开手机，就能看到雪乃学姐的消息。

雪乃: 记得吃早餐哦~
雪乃: 今天的天气很好，心情也会变好的。
雪乃: 新的一天加油！

旁白: 那些简简单单的话语，却让我感到一种说不出的温暖。像是冬日里的暖阳，像是雨天里的伞。

@choice
你怎么回复雪乃学姐的消息？
- 认真回复并分享日常 → @jump option_a
- 简单回复\"早安\" → @jump option_b

@label option_a
主角: 早安，雪乃学姐！今天天气确实很好，我已经吃完早餐了。
雪乃: 那就好~今天也要加油哦！
@event trigger affection_snow +3
@jump after_choice

@label option_b
主角: 早安，学姐。
雪乃: 嗯！新的一天开始了，加油吧！
@event trigger affection_snow +1
@jump after_choice

@label after_choice
旁白: 发完消息，我收拾好书包，准备去学校。

# === 午休天台场景 ===
@bg bg_4  # 天台（白天）
旁白: 今天午休的时候，我照例在天台的楼梯口吃便当。午后的阳光很好，天台上种着的绿植散发着淡淡的清香。我靠在栏杆上，看着远处的操场发呆。（后续内容略……）

@achievement unlock chapter1_spring_breeze_complete
@event trigger chapter1_completed
旁白: ——第一章·春风·完——

@chapter_end
"""

## 第一章·春风（正式版）
const _CH2 := """@chapter chapter2_spring_breeze

@label start
@bg bg_5  # 教室（白天）
@bgm peaceful_day

# === 第一章开始 ===
旁白: 入学第一周，我逐渐适应了这里的生活。
旁白: 每天早上，我都会收到雪乃学姐的消息。

雪乃: 早安，【主角名】同学。今天吃早餐了吗？
旁白: 她的消息总是在我起床后不久就发来，像是每天早上准时响起的闹钟。只不过比闹钟温柔多了。
[完整内容请查看 resources/scripts/chapter2_spring_breeze.txt]

@achievement unlock chapter2_spring_breeze_complete
@event trigger chapter2_completed
旁白: ——第二章·春风·完——

@chapter_end
"""

## 第二章·微光（完整脚本请查看对应 txt）
const _CH3 := """@chapter chapter3_glimmer

@label start
@bg bg_5  # 教室（白天）
@bgm peaceful_day

# === 第二章开始 ===
旁白: 入学第二周，生活逐渐形成了固定的节奏。
[完整内容请查看 resources/scripts/chapter3_glimmer.txt]

@achievement unlock chapter3_glimmer_complete
@event trigger chapter3_completed
旁白: ——第二章·微光·完——

@chapter_end
"""

## 测试脚本
const _TEST := """@chapter test_chapter

@label start
@bg bg_1
@bgm peaceful_day

旁白: 这是一个测试对话脚本。

@achievement unlock test_complete
@chapter_end
"""

## 集成测试脚本
const _INTEGRATION := """@chapter integration_test

@label start
@bg bg_1
@bgm peaceful_day

旁白: 这是一个集成测试脚本。

@achievement unlock integration_test_complete
@chapter_end
"""
