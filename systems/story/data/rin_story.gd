## rin_story.gd - Story event data for Rin (凛) — Deep Branching System v2.0
## Human Kingdom commander. Proud, honorable, initially hostile.
## 3 divergent paths from player choices leading to 4 distinct endings.
extends RefCounted

const EVENTS: Dictionary = {
	"training": [
		{
			"id": "rin_training_01",
			"name": "Stage 1: 俘虏（骄傲的骑士）",
			"trigger": {"hero_captured": true},
			"scene": "地下牢房。凛被铁链缚住双手，悬吊于牢房中央。她的圣殿骑士甲胄已被卸去，只剩下被撕裂的白色内衬。金色双眸中燃烧着不屈的火焰。即便双臂因长时间悬吊而发麻，她依然紧握双拳。",
			"dialogues": [
				{"type": "action", "text": "指挥官推开牢房的铁门"},
				{"speaker": "凛", "text": "……又来了吗。无论你来多少次，我的回答都不会改变。凛·阿斯特蕾亚——圣殿骑士团第七代团长，誓约编号〇七三一。"},
				{"type": "narration", "text": "她的声音沙哑但依然带着威严。"},
				{"speaker": "凛", "text": "我宁愿死在这里，也不会背叛千姬殿下。"},
				{"type": "action", "text": "指挥官将截获的王国通信递到她面前——千姬已放弃营救她"},
				{"type": "narration", "text": "凛的瞳孔猛地收缩，双手在铁链中颤抖。但火焰重新燃起。"},
				{"speaker": "凛", "text": "即便如此。我的忠诚不是给予某个人的，而是给予'正义'本身的。所以——无论你对我做什么，都不会改变任何事情。"},
			],
			"system_prompt": "凛被俘。骑士的信念坚不可摧，但被王国抛弃的打击已经种下了裂痕。",
			"effects": {"training_progress": 1},
		},
		{
			"id": "rin_training_02",
			"name": "Stage 2: 审问（第一个选择）",
			"trigger": {"prev_event": "rin_training_01", "corruption_min": 2},
			"scene": "数日过去。凛的状态明显恶化，但眼中仍有火焰在摇晃。她正在用手指在床铺上反复描绘圣殿骑士团的纹章，但每次画到一半就停下来。",
			"dialogues": [
				{"type": "action", "text": "指挥官进入牢房，带着食物和水"},
				{"speaker": "凛", "text": "……来了。"},
				{"type": "narration", "text": "她的声音不再像第一天那样充满火焰，而是带着疲惫的平静。"},
				{"speaker": "凛", "text": "王国宣布我阵亡了……骑士团有了新的团长。你到底想从我这里得到什么？"},
				{"type": "narration", "text": "这是第一次，她主动问出了这个问题。骄傲的裂痕下露出了困惑。"},
			],
			"choices": [
				{
					"label": "以礼相待",
					"description": "松开她的铁链，递上干净的衣物和食物。以对待客人而非囚犯的方式。",
					"effects": {
						"affection": 1,
						"set_flag": {"rin_respect_path": true},
					},
				},
				{
					"label": "施加压力",
					"description": "利用她被王国抛弃的事实，持续给予心理压力，瓦解她的意志。",
					"effects": {
						"corruption": 2,
						"set_flag": {"rin_pressure_path": true},
					},
				},
				{
					"label": "展示实力",
					"description": "带她观看你的军队训练和战术部署，用压倒性的实力赢得敬畏。",
					"effects": {
						"prestige": 1,
						"set_flag": {"rin_strength_path": true},
					},
				},
			],
			"system_prompt": "第一个关键选择。你的态度将决定凛未来的命运走向。",
			"effects": {},
		},
		{
			"id": "rin_training_03a",
			"name": "Stage 3: 动摇（尊重之路）",
			"trigger": {
				"prev_event": "rin_training_02",
				"requires_flag": "rin_respect_path",
				"affection_or_corruption": {"affection_min": 3, "corruption_min": 5},
			},
			"scene": "凛被转移到了更好的房间。她仍然戒备，但开始接受食物和对话。",
			"dialogues": [
				{"speaker": "凛", "text": "你和我想象中的敌人不一样……但这不代表我会妥协。"},
				{"type": "narration", "text": "她开始松动，但仍保持骄傲。"},
				{"speaker": "凛", "text": "……告诉我，你到底在追求什么？征服？权力？还是其他什么？"},
			],
			"choices": [
				{
					"label": "坦诚相告你的目标",
					"description": "向她坦白你的真实目标和理想，不做任何隐瞒。",
					"effects": {
						"affection": 2,
						"set_flag": {"rin_honest": true},
					},
				},
				{
					"label": "利用她的动摇",
					"description": "利用她对你产生的好感，巧妙地操控她的情感。",
					"effects": {
						"corruption": 1,
						"set_flag": {"rin_manipulate": true},
						"clear_flag": "rin_respect_path",
					},
				},
			],
			"system_prompt": "凛对你产生了好奇。坦诚将通向纯爱，操控将走向人偶。",
			"effects": {},
		},
		{
			"id": "rin_training_03b",
			"name": "Stage 3: 动摇（压力之路）",
			"trigger": {
				"prev_event": "rin_training_02",
				"requires_flag": "rin_pressure_path",
				"affection_or_corruption": {"affection_min": 3, "corruption_min": 5},
			},
			"scene": "凛蜷缩在牢房角落，项圈安静地环绕在她的脖子上。",
			"dialogues": [
				{"type": "narration", "text": "她的意志在动摇，但眼中仍有恨意。"},
				{"speaker": "凛", "text": "……你还要继续吗。每天都来，每天都……我已经分不清你是在折磨我还是在试探我了。"},
			],
			"choices": [
				{
					"label": "给予喘息的机会",
					"description": "暂停施压，给她食物、书籍和自由活动的空间。",
					"effects": {
						"affection": 2,
						"set_flag": {"rin_mercy": true},
						"clear_flag": "rin_pressure_path",
					},
				},
				{
					"label": "继续施压",
					"description": "不给她任何喘息的余地，彻底摧毁她的意志。",
					"effects": {
						"corruption": 3,
						"set_flag": {"rin_broken": true},
					},
				},
			],
			"system_prompt": "她已接近崩溃边缘。仁慈可能带来救赎，继续将把她推入深渊。",
			"effects": {},
		},
		{
			"id": "rin_training_03c",
			"name": "Stage 3: 动摇（实力之路）",
			"trigger": {
				"prev_event": "rin_training_02",
				"requires_flag": "rin_strength_path",
				"affection_or_corruption": {"affection_min": 3, "corruption_min": 5},
			},
			"scene": "训练场。凛被允许观看完整的军事演练。",
			"dialogues": [
				{"type": "narration", "text": "她对你的实力心生敬畏。作为骑士，她无法不尊敬强者。"},
				{"speaker": "凛", "text": "你的战术部署……比王国的宫廷顾问强十倍。如果当初你是我的指挥官——"},
				{"type": "narration", "text": "她突然住口，意识到自己说了不该说的话。"},
			],
			"choices": [
				{
					"label": "提议并肩作战",
					"description": "邀请她作为平等的战友加入你的军队。",
					"effects": {
						"affection": 2,
						"set_flag": {"rin_comrade": true},
					},
				},
				{
					"label": "要求臣服",
					"description": "以强者的姿态要求她彻底臣服于你。",
					"effects": {
						"submission": 2,
						"set_flag": {"rin_subjugate": true},
					},
				},
			],
			"system_prompt": "她敬畏你的实力。并肩将通向纯爱，臣服将走向黑暗。",
			"effects": {},
		},
		{
			"id": "rin_training_04a",
			"name": "Stage 4: 转折——纯爱之路",
			"trigger": {
				"prev_event": "rin_training_03a",
				"affection_min": 5,
				"requires_flag": ["rin_honest"],
				"excludes_flag": ["rin_manipulate", "rin_broken", "rin_subjugate"],
			},
			"scene": "月光下的城墙。凛主动找到了你。",
			"dialogues": [
				{"type": "narration", "text": "她真正开始信任你。"},
				{"speaker": "凛", "text": "我想了很久……你对我说的那些话。关于你的理想，关于这个世界应该是什么样子。"},
				{"type": "narration", "text": "她转过身，金色双眸中没有了敌意，取而代之的是温暖而坚定的光。"},
				{"speaker": "凛", "text": "也许……我的剑不一定要为王国而战。如果你的正义是真实的——那我愿意为你的正义拔剑。"},
			],
			"system_prompt": "纯爱路线解锁。凛获得永久ATK+2, DEF+2。解锁主动技能「誓约之刃」。",
			"effects": {
				"affection": 2,
				"set_flag": {"rin_pure_love": true},
				"unlock_skill": "oath_blade",
			},
		},
		{
			"id": "rin_training_04a_alt",
			"name": "Stage 4: 转折——纯爱之路（战友线）",
			"trigger": {
				"prev_event": "rin_training_03c",
				"affection_min": 5,
				"requires_flag": ["rin_comrade"],
				"excludes_flag": ["rin_manipulate", "rin_broken", "rin_subjugate"],
			},
			"scene": "战场结束后的营帐。你们刚并肩打赢了一场硬仗。",
			"dialogues": [
				{"speaker": "凛", "text": "并肩作战的感觉……比我想象的要好得多。你背后有我守护，感觉真好。"},
				{"type": "narration", "text": "她真正开始信任你。不是因为被征服，而是因为在战火中看到了彼此的本质。"},
				{"speaker": "凛", "text": "从今天起，我的剑就是你的剑。不是因为命令——是因为我选择了你。"},
			],
			"system_prompt": "纯爱路线解锁（战友线）。凛获得永久ATK+2, DEF+2。解锁主动技能「誓约之刃」。",
			"effects": {
				"affection": 2,
				"set_flag": {"rin_pure_love": true},
				"unlock_skill": "oath_blade",
			},
		},
		{
			"id": "rin_training_04b",
			"name": "Stage 4: 转折——救赎之路",
			"trigger": {
				"prev_event": "rin_training_03b",
				"affection_min": 5,
				"requires_flag": ["rin_mercy"],
				"excludes_flag": ["rin_broken"],
			},
			"scene": "花园。凛在阳光下第一次露出了微笑。",
			"dialogues": [
				{"type": "narration", "text": "她感恩你的仁慈，但保持距离。"},
				{"speaker": "凛", "text": "你在最黑暗的时候给了我一线光……我不知道该怎么回报。但至少——我不再恨你了。"},
				{"type": "narration", "text": "她的微笑带着悲伤的温柔，像是在废墟中长出的花。"},
				{"speaker": "凛", "text": "让我用自己的方式守护这个地方吧。不是为了你，是为了你让我看到的可能性。"},
			],
			"system_prompt": "救赎路线解锁。凛获得永久DEF+4（防御专家）。解锁主动技能「圣盾」——全队减伤30%持续2回合。",
			"effects": {
				"affection": 1,
				"set_flag": {"rin_redemption": true},
				"unlock_skill": "holy_shield",
			},
		},
		{
			"id": "rin_training_04c",
			"name": "Stage 4: 转折——黑暗之路",
			"trigger": {
				"prev_event": "rin_training_03b",
				"corruption_min": 7,
				"requires_flag": ["rin_broken"],
			},
			"scene": "牢房。凛坐在地上，目光空洞。",
			"dialogues": [
				{"type": "narration", "text": "她的眼神变得空洞。"},
				{"speaker": "凛", "text": "……告诉我做什么。不用再问了。只要告诉我……做什么。"},
				{"type": "narration", "text": "曾经的骑士团长如今只是一个等待命令的空壳。但偶尔，在她眼底的深处，仍有一丝微光在挣扎。"},
			],
			"system_prompt": "黑暗路线解锁。凛获得ATK+4，但每回合有15%概率拒绝行动。解锁主动技能「狂化」——ATK×2持续3回合，但受到20%额外伤害。",
			"effects": {
				"corruption": 1,
				"set_flag": {"rin_dark": true},
				"unlock_skill": "berserk",
			},
		},
		{
			"id": "rin_training_04c_alt",
			"name": "Stage 4: 转折——黑暗之路（臣服线）",
			"trigger": {
				"prev_event": "rin_training_03c",
				"submission_min": 4,
				"requires_flag": ["rin_subjugate"],
			},
			"scene": "凛跪在你面前。不是骑士的单膝跪，而是完全的臣服。",
			"dialogues": [
				{"type": "narration", "text": "她的眼神变得空洞。"},
				{"speaker": "凛", "text": "主人……我不再是骑士了。我是你的……你想让我成为的任何东西。"},
			],
			"system_prompt": "黑暗路线解锁（臣服线）。凛获得ATK+4，但每回合有15%概率拒绝行动。解锁主动技能「狂化」。",
			"effects": {
				"submission": 2,
				"set_flag": {"rin_dark": true},
				"unlock_skill": "berserk",
			},
		},
		{
			"id": "rin_training_04d",
			"name": "Stage 4: 转折——人偶之路",
			"trigger": {
				"prev_event": "rin_training_03a",
				"affection_min": 4,
				"requires_flag": ["rin_manipulate"],
				"excludes_flag": ["rin_honest"],
			},
			"scene": "凛微笑着为你倒茶。她以为一切都是自愿的。",
			"dialogues": [
				{"type": "narration", "text": "她以为自己是自愿的。"},
				{"speaker": "凛", "text": "我最近在想……也许从一开始你就在帮助我。是我太固执了，不愿意承认。"},
				{"type": "narration", "text": "她的笑容温暖而真诚——但这份真诚建立在谎言之上。"},
				{"speaker": "凛", "text": "谢谢你……没有放弃我。"},
			],
			"system_prompt": "人偶路线解锁。凛的好感度上限锁定为7（除非后续'觉醒'）。ATK+3, DEF+1。",
			"effects": {
				"set_flag": {"rin_puppet": true},
				"set_affection_cap": 7,
			},
		},
		{
			"id": "rin_training_05a",
			"name": "Stage 5: 危机——纯爱之路",
			"trigger": {
				"prev_event": "rin_training_04a",
				"turn_min": 30,
				"affection_min": 7,
				"requires_flag": ["rin_pure_love"],
			},
			"scene": "紧急警报。王国的骑士团前来'营救'凛。",
			"dialogues": [
				{"type": "narration", "text": "凛的昔日战友率军进攻，声称要将她从'魔族的洗脑'中解救出来。"},
				{"speaker": "凛", "text": "他们不明白……我不是被洗脑了，我是自己选择的。"},
				{"type": "narration", "text": "她拔出刻有你名字的圣剑。"},
				{"speaker": "凛", "text": "让我去面对他们。我要亲口告诉他们——凛·阿斯特蕾亚的剑，如今守护的是什么。"},
				{"type": "action", "text": "凛在战斗中挡下了致命一击，并说服了部分旧部撤退"},
			],
			"system_prompt": "纯爱危机。凛与昔日战友对峙，并选择站在你身边。",
			"effects": {
				"affection": 3,
				"set_flag": {"rin_permanent_bond": true},
			},
		},
		{
			"id": "rin_training_05a_alt",
			"name": "Stage 5: 危机——纯爱之路（战友线）",
			"trigger": {
				"prev_event": "rin_training_04a_alt",
				"turn_min": 30,
				"affection_min": 7,
				"requires_flag": ["rin_pure_love"],
			},
			"scene": "紧急警报。王国的骑士团前来'营救'凛。",
			"dialogues": [
				{"type": "narration", "text": "凛的昔日战友率军进攻。"},
				{"speaker": "凛", "text": "我以战友的身份站在这里，不是被俘，不是被迫。"},
				{"type": "action", "text": "凛主动出阵，以压倒性的剑技击退了来犯者"},
			],
			"system_prompt": "纯爱危机（战友线）。凛证明了自己的选择。",
			"effects": {
				"affection": 3,
				"set_flag": {"rin_permanent_bond": true},
			},
		},
		{
			"id": "rin_training_05b",
			"name": "Stage 5: 危机——救赎之路",
			"trigger": {
				"prev_event": "rin_training_04b",
				"turn_min": 30,
				"affection_min": 7,
				"requires_flag": ["rin_redemption"],
			},
			"scene": "凛请求与人类王国进行和平谈判。",
			"dialogues": [
				{"speaker": "凛", "text": "我有一个请求……让我去和千姬殿下谈判。作为两个世界之间的桥梁。"},
				{"type": "narration", "text": "她的眼神坚定而平静。这不是请求——这是她找到的使命。"},
			],
			"choices": [
				{
					"label": "允许她去谈判",
					"description": "信任凛，让她作为使者前往人类王国。可能开启外交路线。",
					"effects": {
						"affection": 2,
						"set_flag": {"rin_diplomacy_route": true},
					},
				},
				{
					"label": "拒绝她的请求",
					"description": "太危险了。拒绝让她冒险。",
					"effects": {
						"affection": -2,
						"set_flag": {"rin_rejected_plea": true},
					},
				},
			],
			"system_prompt": "救赎危机。凛希望成为和平的桥梁。",
			"effects": {},
		},
		{
			"id": "rin_training_05c",
			"name": "Stage 5: 危机——黑暗之路",
			"trigger": {
				"prev_event": "rin_training_04c",
				"turn_min": 30,
				"requires_flag": ["rin_dark"],
				"affection_or_submission": {"affection_min": 7, "submission_min": 7},
			},
			"scene": "战场上。凛突然失控，转而攻击你方单位。",
			"dialogues": [
				{"type": "narration", "text": "凛在战斗中突然暴走，将剑指向了你的士兵。她的眼中闪烁着疯狂与痛苦的混合。"},
				{"speaker": "凛", "text": "不要过来——！我分不清了——谁是敌人——谁是——！"},
			],
			"choices": [
				{
					"label": "原谅并安慰她",
					"description": "放下武器，走向失控的凛，用拥抱代替责罚。",
					"effects": {
						"affection": 3,
						"set_flag": {"rin_healing_arc": true},
						"clear_flag": "rin_broken",
					},
				},
				{
					"label": "严厉惩罚",
					"description": "以军法处置。不能纵容危害自己人的行为。",
					"effects": {
						"corruption": 2,
						"set_flag": {"rin_permanent_dark": true},
					},
				},
			],
			"system_prompt": "黑暗危机。凛在战场上失控。你的选择将决定她能否被救赎。",
			"effects": {},
		},
		{
			"id": "rin_training_05c_alt",
			"name": "Stage 5: 危机——黑暗之路（臣服线）",
			"trigger": {
				"prev_event": "rin_training_04c_alt",
				"turn_min": 30,
				"requires_flag": ["rin_dark"],
				"affection_or_submission": {"affection_min": 7, "submission_min": 7},
			},
			"scene": "战场上。凛突然失控。",
			"dialogues": [
				{"type": "narration", "text": "压抑太久的意志在一瞬间爆发。凛的剑无差别地斩向周围的一切。"},
				{"speaker": "凛", "text": "放开我——！我不是……你的……！"},
			],
			"choices": [
				{
					"label": "原谅并安慰她",
					"description": "接受她的愤怒，给她一个重新开始的机会。",
					"effects": {
						"affection": 3,
						"set_flag": {"rin_healing_arc": true},
						"clear_flag": "rin_subjugate",
					},
				},
				{
					"label": "严厉惩罚",
					"description": "用更强的力量压制她。",
					"effects": {
						"submission": 3,
						"set_flag": {"rin_permanent_dark": true},
					},
				},
			],
			"system_prompt": "黑暗危机（臣服线）。",
			"effects": {},
		},
		{
			"id": "rin_training_05d",
			"name": "Stage 5: 危机——人偶之路",
			"trigger": {
				"prev_event": "rin_training_04d",
				"turn_min": 30,
				"affection_min": 6,
				"requires_flag": ["rin_puppet"],
			},
			"scene": "凛偶然发现了你最初的审讯记录和操控计划。",
			"dialogues": [
				{"type": "narration", "text": "凛发现了真相。她手中攥着那份文件，浑身颤抖。"},
				{"speaker": "凛", "text": "这些……都是你计划好的？从一开始……我以为是自己的选择……全都是——"},
				{"type": "narration", "text": "泪水夺眶而出。她的表情在愤怒和绝望之间撕裂。"},
			],
			"choices": [
				{
					"label": "坦白并道歉",
					"description": "承认一切，真诚地道歉，并请求她的原谅。开启困难救赎线。",
					"effects": {
						"affection": -3,
						"set_flag": {"rin_hard_redemption": true},
						"clear_flag": "rin_puppet",
					},
				},
				{
					"label": "否认一切",
					"description": "坚称文件是伪造的，继续欺骗。",
					"effects": {
						"corruption": 3,
						"set_flag": {"rin_total_puppet": true},
					},
				},
			],
			"system_prompt": "人偶危机。真相暴露。坦白可能失去一切但也可能开始真正的关系；否认将彻底夺去她的自我。",
			"effects": {},
		},
		{
			"id": "rin_training_06a",
			"name": "Stage 6: 结局——纯爱",
			"trigger": {
				"affection_min": 10,
				"requires_flag": ["rin_pure_love", "rin_permanent_bond"],
			},
			"scene": "黎明的城墙上。凛身着全新设计的白色骑士铠甲，胸口佩戴着刻有你名字的银质吊坠。",
			"dialogues": [
				{"speaker": "凛", "text": "从今天起，我不再是失去主君的骑士了。我是你的剑、你的盾、你的伴侣。"},
				{"type": "narration", "text": "她单膝跪下，以骑士的最高礼仪向你宣誓。"},
				{"speaker": "凛", "text": "凛·阿斯特蕾亚，在此立下新的誓约——与你并肩，直到世界的尽头。"},
				{"type": "narration", "text": "解锁「双剑合璧」阵型加成：凛+指挥官同阵=ATK×1.5"},
			],
			"system_prompt": "纯爱结局。解锁「双剑合璧」阵型加成。凛成为最忠诚的伴侣与骑士。",
			"effects": {
				"set_flag": {"rin_dual_blade_formation": true},
			},
		},
		{
			"id": "rin_training_06b",
			"name": "Stage 6: 结局——救赎",
			"trigger": {
				"affection_min": 8,
				"requires_flag": ["rin_redemption", "rin_diplomacy_route"],
			},
			"scene": "和平条约签署仪式。凛站在两个世界的代表之间。",
			"dialogues": [
				{"speaker": "凛", "text": "我曾是战争的利刃，现在我选择成为和平的桥梁。"},
				{"type": "narration", "text": "她将自己的旧圣剑插在谈判桌上。"},
				{"speaker": "凛", "text": "从今天起，这把剑不再为战争而铸——它是两个世界友谊的象征。"},
				{"type": "narration", "text": "解锁人类王国外交同盟。"},
			],
			"system_prompt": "救赎结局。解锁人类王国外交同盟路线。",
			"effects": {
				"set_flag": {"rin_human_alliance": true, "diplomacy_unlocked": true},
			},
		},
		{
			"id": "rin_training_06c",
			"name": "Stage 6: 结局——黑暗",
			"trigger": {
				"corruption_min": 8,
				"requires_flag": ["rin_dark", "rin_permanent_dark"],
				"excludes_flag": ["rin_healing_arc"],
			},
			"scene": "凛站在战场上，浑身沾满鲜血。她的眼神彻底空洞了。",
			"dialogues": [
				{"speaker": "凛", "text": "主人……他们都倒下了。还有谁需要我去杀？"},
				{"type": "narration", "text": "曾经的骑士已经成为了一件纯粹的武器。无情、高效、致命。"},
				{"type": "narration", "text": "解锁「恐怖统治」——所有敌方单位初始士气-20。"},
			],
			"system_prompt": "黑暗结局。解锁「恐怖统治」——敌方全体初始士气-20。凛成为最强战斗力但失去了自我。",
			"effects": {
				"set_flag": {"rin_terror_rule": true},
			},
		},
		{
			"id": "rin_training_06d",
			"name": "Stage 6: 结局——人偶",
			"trigger": {
				"corruption_min": 7,
				"requires_flag": ["rin_total_puppet"],
			},
			"scene": "凛微笑着为你整理衣物。完美的笑容，完美的服务，完美的——空洞。",
			"dialogues": [
				{"speaker": "凛", "text": "主人，今天也辛苦了。需要我做什么吗？"},
				{"type": "narration", "text": "她以为自己是自愿的。也许她真的是。也许这已经不重要了。"},
				{"type": "narration", "text": "解锁「完美人偶」——凛成为最强单位（全属性+3），但没有更多剧情。"},
			],
			"system_prompt": "人偶结局。凛成为战力最强的单位，但失去了所有未来的剧情可能。",
			"effects": {
				"set_flag": {"rin_perfect_puppet": true},
			},
		},
	],
	"pure_love": [],
	"exclusive_ending": [],
}
