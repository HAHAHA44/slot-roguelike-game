# 内容数据表（仅供 generate_content.gd 首次铺量使用）。
#
# 这里的每一行最终都会变成一个 .tres。**生成之后请改 .tres，不要改这里**——
# 重跑生成器会覆盖手改。保留本文件是为了记录第一次铺量时的整体配平意图：
# 同一份表里能一眼看出七个阶段的分数梯度、五个领域的效果分工、12 条生肖规则的强度对比。
#
# 文案规格（fun-axes）：事件正文 ≤ 2 句，选项 ≤ 1 句；金句要画面不要信息量。
class_name ContentTables
extends RefCounted

const STAGE_IDS := ["childhood", "adolescence", "youth", "prime", "midlife", "senior", "twilight"]

# -- 12 条生肖年度规则 -------------------------------------------------------
# 每条只拧一个旋钮，玩家才读得懂「今年该换什么上盘」。
# 强度大致对齐：单条规则给全场约 +40%～+60% 的量级。
const ZODIACS := [
	{"id": "rat", "name": "鼠", "order": 0, "rule_name": "鼠·囤积",
	 "rule_desc": "便宜的小碎片今年格外顶用。",
	 "rule": {"rule_low_base_threshold": 4, "rule_low_base_bonus": 5}},
	{"id": "ox", "name": "牛", "order": 1, "rule_name": "牛·厚积",
	 "rule_desc": "闷头自增的碎片今年事半功倍。",
	 "rule": {"rule_self_percent": 60}},
	{"id": "tiger", "name": "虎", "order": 2, "rule_name": "虎·威势",
	 "rule_desc": "练成的东西今年格外唬人。",
	 "rule": {"rule_star_percent": 70}},
	{"id": "rabbit", "name": "兔", "order": 3, "rule_name": "兔·敏行",
	 "rule_desc": "挨着的碎片今年互相带得动。",
	 "rule": {"rule_neighbor_percent": 55}},
	{"id": "dragon", "name": "龙", "order": 4, "rule_name": "龙·腾达",
	 "rule_desc": "最出挑的那一格今年一飞冲天。",
	 "rule": {"rule_highest_percent": 120}},
	{"id": "snake", "name": "蛇", "order": 5, "rule_name": "蛇·蜕变",
	 "rule_desc": "同乡今年格外抱团。",
	 "rule": {"rule_zodiac_percent": 65}},
	{"id": "horse", "name": "马", "order": 6, "rule_name": "马·奔走",
	 "rule_desc": "今年手伸得更远，隔一格也够得着。",
	 "rule": {"rule_neighbor_radius_bonus": 1}},
	{"id": "goat", "name": "羊", "order": 7, "rule_name": "羊·守拙",
	 "rule_desc": "最不起眼的那一格今年翻身。",
	 "rule": {"rule_lowest_percent": 200}},
	{"id": "monkey", "name": "猴", "order": 8, "rule_name": "猴·机变",
	 "rule_desc": "连得越多，全场越涨。",
	 "rule": {"rule_chain_percent": 4}},
	{"id": "rooster", "name": "鸡", "order": 9, "rule_name": "鸡·司晨",
	 "rule_desc": "读书人的年份。",
	 "rule": {"rule_domain": "study", "rule_domain_percent": 60}},
	{"id": "dog", "name": "狗", "order": 10, "rule_name": "狗·守夜",
	 "rule_desc": "逢双的格子今年守得住。",
	 "rule": {"rule_even_slot_percent": 45}},
	{"id": "pig", "name": "猪", "order": 11, "rule_name": "猪·丰足",
	 "rule_desc": "今年家家有余粮。",
	 "rule": {"rule_all_base_bonus": 6}},
]

# -- 阶段碎片（7 × 12） ------------------------------------------------------
# 每行：[id, 名字, 描述, 领域, 稀有度, 基础分, effect]
# effect 语法："self:N" / "adj:定额/百分比/半径" / "zod:定额/百分比"，多条用 | 连。
# 基础分逐阶段抬一档：童年 2–5 → 暮年 16–30。这条梯度配合星级（最高 7×）与传承物，
# 就是「早期三位数、暮年七位数」曲线的骨架。
const STAGE_TOKENS := [
	# ---- 童年 ----
	[
		["hide_seek", "捉迷藏", "数到十，全世界都藏起来了。", "sport", "Common", 3, "adj:1/40/1"],
		["running", "追跑", "不为什么，就是要跑。", "sport", "Common", 3, "self:3"],
		["picture_book", "图画书", "翻烂的那几页最好看。", "study", "Common", 3, "self:3"],
		["abacus", "珠算", "指头比脑子快。", "study", "Uncommon", 4, "zod:0/70"],
		["crayon", "蜡笔", "墙是最大的画布。", "art", "Common", 3, "adj:1/35/1"],
		["nursery_song", "童谣", "不懂词，但会唱。", "art", "Common", 2, "zod:1/60"],
		["playmate", "玩伴", "住得近就是缘分。", "social", "Common", 3, "adj:2/30/1"],
		["neighbor_kid", "邻家孩子", "隔着栅栏递过来半块糖。", "social", "Common", 2, "adj:1/45/1"],
		["piggy_bank", "存钱罐", "摇一摇，听个响。", "wealth", "Common", 3, "self:4"],
		["new_year_money", "压岁钱", "还没捂热就被收走了。", "wealth", "Uncommon", 4, "self:5"],
		["curiosity", "好奇心", "为什么天是蓝的。", "", "Uncommon", 2, "zod:0/80"],
		["stubborn", "倔脾气", "说不去就不去。", "", "Common", 4, "self:2|adj:1/25/1"],
	],
	# ---- 少年 ----
	[
		["track_team", "田径队", "跑道上的白线晒得发烫。", "sport", "Common", 4, "self:4"],
		["yoyo_pro", "悠悠球", "手腕一抖，全班安静。", "sport", "Uncommon", 5, "adj:2/55/1"],
		["exam_ace", "考试尖子", "红榜上第一个名字。", "study", "Uncommon", 5, "self:6"],
		["library_card", "借书证", "一次只能借两本，太少了。", "study", "Common", 4, "zod:0/70"],
		["sketchbook", "速写本", "课本边角全是脸。", "art", "Common", 4, "adj:2/45/1"],
		["school_band", "校乐队", "跑调也一起跑。", "art", "Uncommon", 5, "zod:2/70"],
		["best_friend", "挚友", "什么都说，包括不该说的。", "social", "Common", 4, "adj:3/40/1"],
		["first_love", "初恋", "递纸条的手心全是汗。", "social", "Rare", 6, "zod:0/110"],
		["paper_route", "送报", "天没亮就出门。", "wealth", "Common", 4, "self:5"],
		["saving_jar", "攒钱", "为了一双鞋忍了半年。", "wealth", "Uncommon", 5, "self:7"],
		["growth_spurt", "抽条", "裤脚一年短一截。", "", "Common", 3, "self:4"],
		["rebellion", "叛逆", "偏不。", "", "Uncommon", 7, "adj:0/75/2"],
	],
	# ---- 青年 ----
	[
		["marathon", "马拉松", "最后五公里才开始。", "sport", "Common", 6, "self:7"],
		["team_captain", "队长", "输了得站出来说话。", "sport", "Uncommon", 7, "adj:3/60/1"],
		["thesis", "毕业论文", "致谢写得比正文动情。", "study", "Uncommon", 7, "self:9"],
		["scholarship", "奖学金", "信封比想象中薄。", "study", "Rare", 8, "zod:0/120"],
		["first_exhibit", "首展", "来的人一半是朋友。", "art", "Uncommon", 7, "zod:3/80"],
		["street_perform", "街头演出", "琴盒里躺着几个硬币。", "art", "Common", 6, "adj:3/50/1"],
		["roommate", "室友", "深夜聊到天亮的那个人。", "social", "Common", 6, "adj:4/45/1"],
		["lover", "恋人", "第一次觉得日子有形状。", "social", "Rare", 9, "zod:2/110"],
		["first_salary", "第一份薪水", "全花在一顿饭上。", "wealth", "Common", 6, "self:8"],
		["side_hustle", "副业", "白天一个人，晚上另一个。", "wealth", "Uncommon", 7, "self:6|adj:2/40/1"],
		["wanderlust", "远行", "买了张最便宜的票。", "", "Uncommon", 5, "zod:0/90"],
		["all_nighter", "通宵", "天亮时眼睛发涩。", "", "Common", 8, "self:5"],
	],
	# ---- 壮年 ----
	[
		["gym_regular", "健身房常客", "身体是唯一还听话的东西。", "sport", "Common", 9, "self:11"],
		["amateur_league", "业余联赛", "周末的球场比办公室真实。", "sport", "Uncommon", 10, "adj:4/65/1"],
		["certification", "资格证", "一张纸换一个头衔。", "study", "Uncommon", 10, "self:12"],
		["published_paper", "论文发表", "署名第一的那次。", "study", "Rare", 12, "zod:0/130"],
		["gallery_slot", "画廊常设", "有人愿意挂你的东西了。", "art", "Uncommon", 10, "zod:4/90"],
		["studio", "工作室", "钥匙只有一把。", "art", "Rare", 12, "adj:5/70/2"],
		["spouse", "配偶", "吵过之后还是一起吃饭。", "social", "Rare", 12, "zod:3/120"],
		["colleague_circle", "同事圈", "饭桌上都是分寸。", "social", "Common", 9, "adj:5/50/1"],
		["promotion", "升职", "名片重印了一次。", "wealth", "Uncommon", 10, "self:13"],
		["first_house", "首套房", "钥匙在手心攥出汗。", "wealth", "Rare", 13, "self:9|zod:0/80"],
		["burnout_resist", "抗压", "撑住就过去了。", "", "Common", 8, "self:9"],
		["mentor", "引路人", "他只说了一句话。", "", "Rare", 11, "adj:4/60/2"],
	],
	# ---- 中年 ----
	[
		["veteran_runner", "老将", "配速慢了，路还是那条。", "sport", "Common", 13, "self:15"],
		["coach", "教练", "喊别人跑比自己跑难。", "sport", "Uncommon", 15, "adj:6/70/1"],
		["lecture_invite", "客座讲席", "台下坐着二十年前的自己。", "study", "Uncommon", 15, "self:17"],
		["field_authority", "领域权威", "别人引用你了。", "study", "Rare", 18, "zod:0/140"],
		["solo_show", "个展", "灯打在自己的名字上。", "art", "Rare", 17, "zod:6/100"],
		["apprentice", "弟子", "他学得比你快。", "art", "Uncommon", 14, "adj:6/65/2"],
		["family_dinner", "家宴", "一年到头就这一桌。", "social", "Common", 12, "adj:7/55/1"],
		["old_friend", "旧交", "十年没见，落座就接上了。", "social", "Uncommon", 14, "zod:4/110"],
		["investment", "投资", "看对了一次。", "wealth", "Rare", 17, "self:19"],
		["second_income", "第二收入", "睡着的时候也在进钱。", "wealth", "Uncommon", 15, "self:12|adj:4/45/1"],
		["midlife_doubt", "中年之惑", "半夜醒来数天花板。", "", "Common", 10, "self:12"],
		["reputation", "声望", "名字先到，人后到。", "", "Rare", 16, "adj:6/75/2"],
	],
	# ---- 老年 ----
	[
		["morning_walk", "晨练", "公园里都是熟脸。", "sport", "Common", 16, "self:19"],
		["sport_legacy", "体坛旧事", "剪报还留着。", "sport", "Uncommon", 19, "adj:8/75/1"],
		["memoir", "回忆录", "写到一半才发现忘了很多。", "study", "Uncommon", 19, "self:22"],
		["lifetime_award", "终身成就", "奖杯比想象中沉。", "study", "Rare", 23, "zod:0/150"],
		["retrospective", "回顾展", "最早那幅挂在最前面。", "art", "Rare", 22, "zod:8/110"],
		["calligraphy", "书法", "一笔下去不能改。", "art", "Common", 16, "adj:7/60/1"],
		["grandchild", "孙辈", "他管你叫的那个称呼很好听。", "social", "Rare", 22, "zod:6/120"],
		["old_neighbors", "老街坊", "谁家的事都知道。", "social", "Common", 15, "adj:8/55/1"],
		["pension", "退休金", "每月固定的那天。", "wealth", "Uncommon", 19, "self:24"],
		["estate", "家业", "分不分是个问题。", "wealth", "Rare", 24, "self:16|zod:0/90"],
		["quiet_years", "清闲", "终于没什么非做不可。", "", "Common", 13, "self:15"],
		["elder_respect", "德高望重", "说话有人听。", "", "Rare", 21, "adj:8/80/2"],
	],
	# ---- 暮年 ----
	[
		["slow_steps", "缓步", "从门口走到院子要歇一次。", "sport", "Common", 19, "self:23"],
		["old_champion", "昔日冠军", "照片上的人在笑。", "sport", "Uncommon", 23, "adj:10/80/1"],
		["last_lecture", "最后一课", "讲完把粉笔放下。", "study", "Uncommon", 23, "self:27"],
		["collected_works", "全集", "厚厚一摞，压手。", "study", "Rare", 28, "zod:0/160"],
		["final_piece", "封笔之作", "落款时手抖了一下。", "art", "Rare", 27, "zod:10/120"],
		["teahouse_tale", "茶馆闲话", "同一个故事讲第五遍。", "art", "Common", 19, "adj:9/65/1"],
		["great_grandchild", "曾孙", "抱不动了，只能摸摸头。", "social", "Rare", 27, "zod:8/130"],
		["lifelong_companion", "老伴", "不说话也不冷场。", "social", "Rare", 30, "zod:0/140"],
		["inheritance", "遗产", "早就写好了。", "wealth", "Uncommon", 23, "self:29"],
		["lifetime_savings", "一生积蓄", "数字后面很多零，花不动了。", "wealth", "Rare", 29, "self:20|zod:0/100"],
		["serenity", "安详", "怕的东西越来越少。", "", "Common", 16, "self:18"],
		["legend", "传说", "别人讲你的时候，你不在场。", "", "Legendary", 30, "adj:12/90/2"],
	],
]

# -- 传承链（5 领域 × 3 环） -------------------------------------------------
# 每行：[名字, 描述, 基础分, effect]。
# 分数跳跃是刻意的（14 → 34 → 80）：走完一条链的局不到六分之一，回报必须配得上稀有度。
const LEGACY_CHAINS := {
	"sport": [
		["校队主力", "名字印在秩序册上。", 14, "self:16|adj:4/60/1"],
		["职业选手", "以此为生了。", 34, "self:38|adj:10/80/2"],
		["一代名将", "后来的人拿你当标尺。", 80, "self:90|adj:24/110/2"],
	],
	"study": [
		["学科尖子", "老师开始记你的名字。", 14, "self:20|adj:3/45/1"],
		["领域专家", "有人专程来问你。", 34, "self:46|adj:8/70/1"],
		["一代宗师", "这门学问因你分了前后。", 80, "self:108|adj:20/95/2"],
	],
	"art": [
		["小有名气", "有人认出你的手笔。", 14, "adj:5/75/1"],
		["名家", "落款本身就值钱。", 34, "adj:12/100/2"],
		["传世之作", "它会比你活得久。", 80, "adj:28/140/3"],
	],
	"social": [
		["人脉广布", "哪儿都有说得上话的人。", 14, "adj:6/70/2"],
		["一呼百应", "开口就有人接。", 34, "adj:14/95/2"],
		["众望所归", "你不在场，事也办得成。", 80, "adj:32/130/3"],
	],
	"wealth": [
		["小有积蓄", "腰不那么弯了。", 14, "self:22"],
		["一方富商", "账本要人帮着看。", 34, "self:50"],
		["富甲一方", "钱已经不是问题了。", 80, "self:115"],
	],
}

# -- 道具（乘区，跨阶段累积） ------------------------------------------------
# 每行：[id, 名字, 描述, 领域, 稀有度, 价格(阶段门槛倍数), 最早阶段, 上限, 乘区字典]
const ITEMS := [
	["lucky_charm", "护身符", "红绳磨得发白。", "", "Common", 0.4, 0, 3, {"settle_percent": 6}],
	["diary", "日记本", "锁扣早就坏了。", "study", "Common", 0.5, 0, 2, {"self_percent": 10}],
	["jump_rope", "跳绳", "把手缠了胶布。", "sport", "Common", 0.5, 0, 2, {"domain_percent": 15}],
	["crayon_box", "蜡笔盒", "少了两支。", "art", "Common", 0.5, 0, 2, {"domain_percent": 15}],
	["address_book", "通讯录", "有些名字划掉了。", "social", "Common", 0.5, 0, 2, {"domain_percent": 15}],
	["coin_purse", "钱袋", "拉链有点涩。", "wealth", "Common", 0.5, 0, 2, {"domain_percent": 15}],
	["wristwatch", "手表", "走得比心跳稳。", "", "Uncommon", 0.8, 1, 2, {"settle_percent": 12}],
	["bicycle", "自行车", "链条上过一次油。", "sport", "Uncommon", 0.9, 1, 1, {"neighbor_percent": 20}],
	["dictionary", "词典", "翻旧的地方最有用。", "study", "Uncommon", 0.9, 1, 1, {"zodiac_percent": 20}],
	["camera", "相机", "取景框里的世界方一点。", "art", "Uncommon", 0.9, 1, 1, {"zodiac_percent": 18}],
	["banquet_set", "宴客器皿", "一年用不上两回。", "social", "Uncommon", 0.9, 2, 1, {"neighbor_percent": 22}],
	["ledger", "账本", "每一笔都记。", "wealth", "Uncommon", 0.9, 2, 1, {"self_percent": 18}],
	["jade_pendant", "玉佩", "捂久了会温。", "", "Rare", 1.3, 2, 2, {"settle_percent": 22}],
	["family_photo", "全家福", "有人已经不在了。", "social", "Rare", 1.4, 3, 1,
		{"settle_percent": 18, "neighbor_percent": 15}],
	["trophy_shelf", "奖杯架", "第二层空着。", "sport", "Rare", 1.4, 3, 1, {"domain_percent": 35}],
	["study_room", "书房", "门一关就是另一个世界。", "study", "Rare", 1.4, 3, 1, {"domain_percent": 35}],
	["grand_piano", "三角钢琴", "搬进来时拆了窗。", "art", "Rare", 1.6, 4, 1, {"domain_percent": 40}],
	["old_seal", "古印", "印泥的味道很旧。", "wealth", "Rare", 1.6, 4, 1, {"domain_percent": 40}],
	["ancestral_tablet", "祖宗牌位", "上香的人越来越少。", "", "Legendary", 2.2, 4, 1,
		{"settle_percent": 40}],
	["heirloom", "传家宝", "谁也说不清它值多少。", "", "Legendary", 2.4, 5, 1,
		{"settle_percent": 35, "all_base_bonus": 6}],
]

# -- 开局 Buff / Debuff（出生时一次性结算） ----------------------------------
# 每行：[id, 名字, 描述, 极性, 效果字典]
const BUFFS := [
	["wealthy_family", "家境优渥", "从没为钱发过愁。", "buff",
		{"purchasing_power_bonus": 1.5, "extra_card": "new_year_money", "extra_card_star": 2}],
	["noble_help", "名门相助", "有人愿意替你说话。", "buff",
		{"extra_card": "playmate", "extra_card_star": 2, "stat_deltas": {"int": 2}}],
	["lucky_star", "福星高照", "总能赶上好时候。", "buff", {"stat_deltas": {"luck": 3}}],
	["sturdy_body", "体格强健", "很少生病。", "buff",
		{"stat_deltas": {"end": 3}, "lifespan_delta": 5}],
	["fallen_family", "家道中落", "听说以前不是这样。", "debuff", {"stat_deltas": {"spr": -2}}],
	["ill_fortune", "时运不济", "总是差那么一点。", "debuff", {"stat_deltas": {"luck": -2}}],
	["sickly", "体弱多病", "药比饭还熟。", "debuff",
		{"stat_deltas": {"end": -2}, "lifespan_delta": -8}],
	["reclusive", "孤僻", "人多的地方待不住。", "debuff", {"stat_deltas": {"spr": -1}}],
]

# -- 权重预设 ----------------------------------------------------------------
# 良性事件高精神常见、低精神罕见；恶性反过来；致死只在低精神档非零
# （这条由 ContentDefinitionValidator 强制，写错会在加载期就被拦下）。
const W_BENIGN := {"high": 5.0, "mid": 1.0, "low": 0.2}
const W_NEUTRAL := {"high": 1.0, "mid": 1.0, "low": 1.0}
const W_MALIGN := {"high": 0.1, "mid": 1.0, "low": 5.0}
const W_LETHAL := {"low": 2.0}

# -- 转折年事件 --------------------------------------------------------------
const EVENTS := [
	# ---- 通用良性 ----
	{"id": "ev_windfall", "name": "街角的钞票", "desc": "风把它吹到你脚边，四下无人。",
	 "kind": "benign", "weights": W_BENIGN,
	 "choices": [
		{"text": "捡起来，谁也没看见。", "karma_delta": -1, "item_reward": "coin_purse"},
		{"text": "交到派出所。", "karma_delta": 2, "spirit_delta": 1}]},
	{"id": "ev_kind_stranger", "name": "陌生人的伞", "desc": "他把伞塞给你就跑了。",
	 "kind": "benign", "weights": W_BENIGN, "karma": 1,
	 "choices": [{"text": "记住这张脸。", "spirit_delta": 2}]},
	{"id": "ev_good_news", "name": "一封好消息", "desc": "信封很薄，里面的字很短。",
	 "kind": "benign", "weights": W_BENIGN,
	 "choices": [{"text": "读了三遍。", "spirit_delta": 2, "item_reward": "lucky_charm"}]},
	{"id": "ev_old_photo", "name": "翻出旧照片", "desc": "背面有一行褪色的字。",
	 "kind": "benign", "weights": W_BENIGN,
	 "choices": [{"text": "看了很久。", "spirit_delta": 3}]},
	{"id": "ev_health_check", "name": "体检报告", "desc": "各项都还行，医生难得笑了。",
	 "kind": "benign", "weights": W_BENIGN,
	 "choices": [{"text": "松一口气。", "lifespan_delta": 2, "spirit_delta": 1}]},
	{"id": "ev_mentor_word", "name": "一句点拨", "desc": "他说完就走了，你站在原地。",
	 "kind": "benign", "weights": W_BENIGN,
	 "choices": [
		{"text": "记下来。", "stat_deltas": {"int": 1}, "spirit_delta": 1},
		{"text": "当时没懂。", "spirit_delta": 2}]},

	# ---- 通用中性 ----
	{"id": "ev_fork", "name": "岔路口", "desc": "两条路都看不到尽头。",
	 "kind": "neutral", "weights": W_NEUTRAL,
	 "choices": [
		{"text": "走稳妥那条。", "spirit_delta": 1},
		{"text": "走没走过那条。", "spirit_delta": -1, "item_reward": "wristwatch"}]},
	{"id": "ev_move_house", "name": "搬家", "desc": "东西比想象中多。",
	 "kind": "neutral", "weights": W_NEUTRAL,
	 "choices": [
		{"text": "该扔的都扔了。", "discard_cards": 1, "spirit_delta": 2},
		{"text": "一样也没舍得。", "spirit_delta": -1}]},
	{"id": "ev_long_night", "name": "睡不着的一夜", "desc": "天花板上什么也没有。",
	 "kind": "neutral", "weights": W_NEUTRAL,
	 "choices": [
		{"text": "起来做点事。", "stat_deltas": {"int": 1}, "spirit_delta": -1},
		{"text": "硬躺到天亮。", "spirit_delta": 1}]},
	{"id": "ev_reunion", "name": "同学聚会", "desc": "有人变了很多，有人一点没变。",
	 "kind": "neutral", "weights": W_NEUTRAL,
	 "choices": [
		{"text": "喝到最后。", "spirit_delta": 2, "stat_deltas": {"end": -1}},
		{"text": "提前走了。", "spirit_delta": -1}]},
	{"id": "ev_borrow", "name": "有人来借钱", "desc": "他说下个月一定还。",
	 "kind": "neutral", "weights": W_NEUTRAL,
	 "choices": [
		{"text": "借。", "karma_delta": 2, "spirit_delta": -1},
		{"text": "推了。", "karma_delta": -1, "spirit_delta": 1}]},
	{"id": "ev_new_hobby", "name": "捡起一件旧事", "desc": "很多年没碰了。",
	 "kind": "neutral", "weights": W_NEUTRAL,
	 "choices": [
		{"text": "认真练一阵。", "spirit_delta": 2, "stat_deltas": {"agi": 1}},
		{"text": "玩两天就放下。", "spirit_delta": 1}]},

	# ---- 通用恶性 ----
	{"id": "ev_illness", "name": "病了一场", "desc": "拖了很久才好，人瘦了一圈。",
	 "kind": "malign", "weights": W_MALIGN,
	 "choices": [
		{"text": "硬扛过去。", "spirit_delta": -2, "stat_deltas": {"end": -1}},
		{"text": "老实住院。", "spirit_delta": -1, "lifespan_delta": -1}]},
	{"id": "ev_betrayal", "name": "被信任的人骗了", "desc": "最难受的不是损失。",
	 "kind": "malign", "weights": W_MALIGN,
	 "choices": [
		{"text": "算了。", "spirit_delta": -2},
		{"text": "追到底。", "spirit_delta": -3, "karma_delta": -1, "discard_cards": 1}]},
	{"id": "ev_loss_money", "name": "破财", "desc": "一笔钱说没就没了。",
	 "kind": "malign", "weights": W_MALIGN,
	 "choices": [{"text": "认了。", "spirit_delta": -2, "discard_cards": 1}]},
	{"id": "ev_funeral", "name": "一场葬礼", "desc": "回来的路上谁都没说话。",
	 "kind": "malign", "weights": W_MALIGN,
	 "choices": [{"text": "站到最后。", "spirit_delta": -3, "karma_delta": 1}]},
	{"id": "ev_quarrel", "name": "大吵一架", "desc": "说出口的话收不回来。",
	 "kind": "malign", "weights": W_MALIGN,
	 "choices": [
		{"text": "先低头。", "spirit_delta": -1, "karma_delta": 1},
		{"text": "谁也不认错。", "spirit_delta": -3, "discard_cards": 1}]},
	{"id": "ev_accident", "name": "出了意外", "desc": "回想起来还是后怕。",
	 "kind": "malign", "weights": W_MALIGN,
	 "choices": [{"text": "养了半年。", "spirit_delta": -2, "stat_deltas": {"agi": -1},
		"lifespan_delta": -2}]},
	{"id": "ev_slander", "name": "背后的话", "desc": "传到你耳朵里时已经变了样。",
	 "kind": "malign", "weights": W_MALIGN,
	 "choices": [
		{"text": "不解释。", "spirit_delta": -2},
		{"text": "当面对质。", "spirit_delta": -1, "karma_delta": -1, "discard_cards": 1}]},

	# ---- 致死（只在低精神档） ----
	{"id": "ev_lethal_collapse", "name": "撑不住了", "desc": "这一次没有再站起来。",
	 "kind": "lethal", "weights": W_LETHAL,
	 "choices": [
		{"text": "还想再试一次。", "spirit_delta": -2, "lifespan_delta": -3},
		{"text": "闭上眼睛。", "lethal": true}]},
	{"id": "ev_lethal_illness", "name": "一场大病", "desc": "医生把家属叫到走廊上。",
	 "kind": "lethal", "weights": W_LETHAL,
	 "choices": [
		{"text": "赌一次手术。", "spirit_delta": -3, "lifespan_delta": -5},
		{"text": "回家躺着。", "lethal": true}]},
	{"id": "ev_lethal_road", "name": "那个雨夜", "desc": "路灯坏了很久没人修。",
	 "kind": "lethal", "weights": W_LETHAL,
	 "choices": [{"text": "……", "lethal": true}]},

	# ---- 本命年（12 年一遇，大喜大悲） ----
	{"id": "ev_birth_blessing", "name": "本命年·红绳", "desc": "长辈把它系在你手腕上，勒得有点紧。",
	 "kind": "benign", "weights": {"high": 3.0, "mid": 3.0, "low": 1.0}, "birth_year": true,
	 "choices": [
		{"text": "戴着。", "spirit_delta": 3, "item_reward": "lucky_charm"},
		{"text": "第二天就摘了。", "karma_delta": -1, "item_reward": "jade_pendant"}]},
	{"id": "ev_birth_trial", "name": "本命年·坎", "desc": "这一年什么都不顺。",
	 "kind": "malign", "weights": {"high": 1.0, "mid": 3.0, "low": 4.0}, "birth_year": true,
	 "choices": [
		{"text": "低头熬过去。", "spirit_delta": -3},
		{"text": "偏要迎上去。", "spirit_delta": -1, "discard_cards": 1, "karma_delta": 2}]},
	{"id": "ev_birth_turn", "name": "本命年·转机", "desc": "最难的那天之后，事情忽然松动了。",
	 "kind": "benign", "weights": {"high": 4.0, "mid": 2.0, "low": 1.0}, "birth_year": true,
	 "choices": [{"text": "抓住它。", "spirit_delta": 4, "item_reward": "jade_pendant"}]},

	# ---- 阶段专属 ----
	{"id": "ev_child_bike", "name": "学会骑车", "desc": "扶着后座的手松开时你没发现。",
	 "kind": "benign", "weights": W_BENIGN, "stage": "childhood",
	 "choices": [{"text": "一直骑到天黑。", "spirit_delta": 2, "card_reward": "running"}]},
	{"id": "ev_child_scold", "name": "挨了一顿骂", "desc": "你到现在也不觉得自己错了。",
	 "kind": "malign", "weights": W_MALIGN, "stage": "childhood",
	 "choices": [
		{"text": "哭了。", "spirit_delta": -2},
		{"text": "梗着脖子。", "spirit_delta": -1, "card_reward": "stubborn"}]},
	{"id": "ev_child_gift", "name": "一份礼物", "desc": "拆包装的时候手在抖。",
	 "kind": "benign", "weights": W_BENIGN, "stage": "childhood",
	 "choices": [{"text": "宝贝了很久。", "spirit_delta": 2, "card_reward": "picture_book"}]},

	{"id": "ev_teen_exam", "name": "一次大考", "desc": "分数出来那天走廊很吵。",
	 "kind": "neutral", "weights": W_NEUTRAL, "stage": "adolescence",
	 "choices": [
		{"text": "考得不错。", "card_reward": "exam_ace", "spirit_delta": 1},
		{"text": "考砸了。", "spirit_delta": -2, "stat_deltas": {"int": 1}}]},
	{"id": "ev_teen_note", "name": "一张纸条", "desc": "折成很小的一块，从后排传过来。",
	 "kind": "benign", "weights": W_BENIGN, "stage": "adolescence",
	 "choices": [
		{"text": "回了。", "card_reward": "first_love", "spirit_delta": 2},
		{"text": "假装没看见。", "spirit_delta": -1, "card_reward": "best_friend"}]},
	{"id": "ev_teen_fight", "name": "打了一架", "desc": "校服撕了个口子。",
	 "kind": "malign", "weights": W_MALIGN, "stage": "adolescence",
	 "choices": [{"text": "谁也没道歉。", "spirit_delta": -2, "stat_deltas": {"str": 1}}]},

	{"id": "ev_youth_offer", "name": "第一份 offer", "desc": "工资写在最后一行。",
	 "kind": "benign", "weights": W_BENIGN, "stage": "youth",
	 "choices": [
		{"text": "签了。", "card_reward": "first_salary", "spirit_delta": 1},
		{"text": "再等等。", "spirit_delta": -1, "card_reward": "wanderlust"}]},
	{"id": "ev_youth_breakup", "name": "分手", "desc": "东西是分两次搬走的。",
	 "kind": "malign", "weights": W_MALIGN, "stage": "youth",
	 "choices": [{"text": "很久才缓过来。", "spirit_delta": -3, "discard_cards": 1}]},
	{"id": "ev_youth_road", "name": "一个人的旅行", "desc": "在陌生的车站坐了一夜。",
	 "kind": "neutral", "weights": W_NEUTRAL, "stage": "youth",
	 "choices": [{"text": "想通了一点事。", "spirit_delta": 3, "card_reward": "wanderlust"}]},

	{"id": "ev_prime_promo", "name": "位置空出来了", "desc": "所有人都在看你。",
	 "kind": "neutral", "weights": W_NEUTRAL, "stage": "prime",
	 "choices": [
		{"text": "争。", "card_reward": "promotion", "spirit_delta": -1},
		{"text": "让。", "karma_delta": 2, "spirit_delta": 1}]},
	{"id": "ev_prime_child", "name": "孩子出生", "desc": "第一次觉得时间不够用。",
	 "kind": "benign", "weights": W_BENIGN, "stage": "prime",
	 "choices": [{"text": "抱了很久。", "spirit_delta": 3, "card_reward": "spouse", "karma_delta": 1}]},
	{"id": "ev_prime_burnout", "name": "垮了一次", "desc": "连着几个月睡不好。",
	 "kind": "malign", "weights": W_MALIGN, "stage": "prime",
	 "choices": [
		{"text": "请了长假。", "spirit_delta": 1, "discard_cards": 1},
		{"text": "硬撑。", "spirit_delta": -3, "lifespan_delta": -2}]},

	{"id": "ev_mid_parent", "name": "父母老了", "desc": "电话那头的声音慢了半拍。",
	 "kind": "malign", "weights": W_MALIGN, "stage": "midlife",
	 "choices": [
		{"text": "常回去。", "spirit_delta": -1, "karma_delta": 2},
		{"text": "只寄钱。", "spirit_delta": -2, "karma_delta": -1}]},
	{"id": "ev_mid_chance", "name": "最后一次机会", "desc": "过了这村就没这店了。",
	 "kind": "neutral", "weights": W_NEUTRAL, "stage": "midlife",
	 "choices": [
		{"text": "赌上去。", "card_reward": "investment", "spirit_delta": -2},
		{"text": "守住现在的。", "spirit_delta": 2}]},
	{"id": "ev_mid_student", "name": "有人来拜师", "desc": "他看你的眼神你很熟悉。",
	 "kind": "benign", "weights": W_BENIGN, "stage": "midlife",
	 "choices": [{"text": "收下。", "card_reward": "apprentice", "karma_delta": 1, "spirit_delta": 2}]},

	{"id": "ev_senior_retire", "name": "退休那天", "desc": "工位收拾干净只用了半小时。",
	 "kind": "neutral", "weights": W_NEUTRAL, "stage": "senior",
	 "choices": [
		{"text": "轻松。", "spirit_delta": 3, "card_reward": "quiet_years"},
		{"text": "空落落的。", "spirit_delta": -2, "card_reward": "pension"}]},
	{"id": "ev_senior_grand", "name": "抱上孙辈", "desc": "小得让人不敢用力。",
	 "kind": "benign", "weights": W_BENIGN, "stage": "senior",
	 "choices": [{"text": "笑出了皱纹。", "spirit_delta": 4, "card_reward": "grandchild"}]},
	{"id": "ev_senior_farewell", "name": "送走一位老友", "desc": "名单又短了一个。",
	 "kind": "malign", "weights": W_MALIGN, "stage": "senior",
	 "choices": [{"text": "坐了很久。", "spirit_delta": -3, "karma_delta": 1}]},

	{"id": "ev_twilight_will", "name": "写遗嘱", "desc": "笔尖悬了很久才落下。",
	 "kind": "neutral", "weights": W_NEUTRAL, "stage": "twilight",
	 "choices": [
		{"text": "都留给他们。", "karma_delta": 3, "spirit_delta": 2},
		{"text": "捐出去。", "karma_delta": 5, "spirit_delta": 1, "discard_cards": 1}]},
	{"id": "ev_twilight_visit", "name": "有人来看你", "desc": "认了半天才认出来。",
	 "kind": "benign", "weights": W_BENIGN, "stage": "twilight",
	 "choices": [{"text": "留他吃了顿饭。", "spirit_delta": 3, "karma_delta": 1}]},
	{"id": "ev_twilight_fade", "name": "记不清了", "desc": "有些名字怎么也想不起来。",
	 "kind": "malign", "weights": W_MALIGN, "stage": "twilight",
	 "choices": [{"text": "算了。", "spirit_delta": -3, "discard_cards": 1}]},
]

# -- 流水年金句（7 阶段 × 三档精神 × 7 条） ----------------------------------
# 每年滚一行，不阻塞、不改状态。它是《人生重开模拟器》那种叙事密度的来源，
# 而且零时间成本——和 cascade 动画并行滚在日志里。
const FLAVOR := [
	# ---- 童年 ----
	{
		"high": ["你学会了骑车。", "第一次自己系鞋带。", "把整块糖含到化。",
			"在院子里追一只猫。", "夏天的凉席印在背上。", "背下了一首诗。", "被举高高。"],
		"mid": ["换了一颗牙。", "作业本又忘在家里。", "下雨了，被接走。",
			"学校门口新开了小卖部。", "衣服上蹭了一块泥。", "看了一下午蚂蚁。", "午睡没睡着。"],
		"low": ["没人跟你玩。", "被留下来罚站。", "父亲的咳嗽重了。",
			"半夜醒来家里在吵架。", "饭桌上没人说话。", "书包带断了。", "怕黑的一年。"],
	},
	# ---- 少年 ----
	{
		"high": ["跑赢了班里最快的人。", "第一次被叫上台。", "球场上的汗和风。",
			"暗恋的人回头笑了。", "作文被当范文念。", "攒够了买那双鞋的钱。", "校服袖子卷起来。"],
		"mid": ["个子窜了一截。", "自行车链条掉了两次。", "课本包了新书皮。",
			"听同一首歌听了一个月。", "抄了半本歌词。", "月考成绩不上不下。", "剪了个后悔的头。"],
		"low": ["没人替你说话。", "成绩单不敢拿回家。", "被起了难听的外号。",
			"一个人吃了一年午饭。", "写了不敢寄的信。", "家里又提起钱的事。", "开始失眠。"],
	},
	# ---- 青年 ----
	{
		"high": ["第一次自己付房租。", "深夜的排档和朋友。", "拿到了心仪的位置。",
			"喜欢的人也喜欢你。", "存折上第一次有四位数。", "背包上多了一个吊牌。", "被夸有天分。"],
		"mid": ["搬了第三次家。", "地铁上睡过了站。", "简历改到第七版。",
			"合租的人换了。", "学会了做两个菜。", "手机屏碎了一角。", "周末在洗衣服。"],
		"low": ["面试第九次落选。", "月底最后几天数着过。", "很久没人打电话来。",
			"退租时押金没退。", "生病了自己去的医院。", "同龄人都比你快。", "梦到回不去的地方。"],
	},
	# ---- 壮年 ----
	{
		"high": ["项目做成了。", "有人开始叫你老师。", "家里添了一件像样的家具。",
			"周末睡到自然醒。", "孩子第一次叫人。", "还清了一笔账。", "被信任地交代了事。"],
		"mid": ["体检指标有一项偏高。", "通勤路上换了条线。", "同事换了一批。",
			"计划了很久的旅行推到明年。", "开始戴老花镜看手机。", "学会了闭嘴。", "又长了一岁。"],
		"low": ["会上没人接你的话。", "回家路上在车里坐了半小时。", "父母住院了。",
			"存款没有变多。", "半夜数天花板。", "很久没有真的笑过。", "开始怕手机响。"],
	},
	# ---- 中年 ----
	{
		"high": ["有人专程来请教你。", "带出来的人成了。", "旧友重逢，落座就接上了。",
			"身体还跟得上。", "做成了一件想做很久的事。", "被记住了名字。", "家里很热闹。"],
		"mid": ["白头发拔不过来了。", "参加了三场婚礼。", "换了一副眼镜。",
			"计划里的字越写越少。", "开始养生。", "同学群里安静了。", "又搬了一次家。"],
		"low": ["参加了三场葬礼。", "话到嘴边咽了回去。", "被年轻人绕过去了。",
			"孩子不太说话了。", "半夜醒来数天花板。", "看不清前面的路。", "开始怕体检。"],
	},
	# ---- 老年 ----
	{
		"high": ["公园里都是熟脸。", "孙辈来住了一个夏天。", "写字的手还稳。",
			"老友来看你了。", "一觉睡到大天亮。", "有人来听你讲从前。", "菜园子收成不错。"],
		"mid": ["药盒分了七格。", "耳朵背了一点。", "看新闻看到睡着。",
			"记性开始不好使。", "去了一趟老房子。", "台阶变高了。", "又添了一件旧毛衣。"],
		"low": ["名单又短了一个。", "很久没人来了。", "腿疼得睡不着。",
			"电话响的时候心一紧。", "认不出照片上的人。", "话没人接。", "怕过冬天。"],
	},
	# ---- 暮年 ----
	{
		"high": ["曾孙学会走路了。", "阳光晒到腿上，很暖。", "有人握着你的手。",
			"想起来的都是好事。", "睡得很沉。", "一家人齐了。", "把话都说完了。"],
		"mid": ["从门口走到院子要歇一次。", "同一个故事讲了第五遍。", "钟表的声音变大了。",
			"日子过得没有形状。", "窗外的树又落叶了。", "旧衣服都还留着。", "不太出门了。"],
		"low": ["认不清人了。", "有些名字怎么也想不起来。", "夜里很长。",
			"来看你的人越来越少。", "怕闭上眼睛。", "屋里很安静。", "疼的时候不说了。"],
	},
]
