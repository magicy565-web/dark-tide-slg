## suirei_story.gd - Story event data for Suirei (翠玲) — Deep Branching System v2.0
## Elf archer from Silver Moon Council. Theme: nature vs conquest.
## 3 divergent paths from player choices leading to 3 distinct endings.
extends RefCounted

const EVENTS: Dictionary = {
	"training": [
		{
			"id": "suirei_training_01",
			"name": "Stage 1: 俘虏（高傲的精灵）",
			"trigger": {"hero_captured": true},
			"scene": "地下拘留室。翠玲被魔法锁链缚住双手。银白色的长发散乱，精灵耳朵高高竖起呈愤怒姿态。她的断弓被丢在墙角——弓弦在战斗中崩断。",
			"dialogues": [
				{"type": "action", "text": "指挥官推开石门走入拘留室"},
				{"speaker": "翠玲", "text": "呵……以你们人类的智力，我本不该期待什么体面的待遇。翠玲·希尔瓦纳，银月议庭第三席射手长。"},
				{"type": "narration", "text": "她的语气中没有丝毫恐惧，仿佛她才是审视者。"},
				{"speaker": "翠玲", "text": "我活了三百七十二年。在精灵眼中你们不过是朝生暮死的蜉蝣。你以为你和他们有什么不同？"},
			],
			"system_prompt": "翠玲被俘。精灵的高傲丝毫未减。",
			"effects": {"training_progress": 1},
		},
		{
			"id": "suirei_training_02",
			"name": "Stage 2: 精灵之道（第一个选择）",
			"trigger": {"prev_event": "suirei_training_01", "corruption_min": 2},
			"scene": "拘留室增加了一些植物——这是唯一能让翠玲保持理智的东西。她正轻声用精灵语对着一盆枯萎的藤蔓低语。",
			"dialogues": [
				{"speaker": "翠玲", "text": "这些植物……在你们人类的石牢里快死了。就像我。"},
				{"type": "narration", "text": "第一次，她的声音中没有了傲慢，只有疲惫。"},
				{"speaker": "翠玲", "text": "你们砍伐森林筑城、焚烧原野开路……你们有没有想过，那些树木也有灵魂？"},
			],
			"choices": [
				{
					"label": "尊重自然",
					"description": "向她承诺保护领地内的森林，并让她照料城堡的植物。",
					"effects": {
						"affection": 2,
						"set_flag": {"suirei_nature_path": true},
					},
				},
				{
					"label": "实用至上",
					"description": "告诉她自然资源是赢得战争的必需品。生存优先于环保。",
					"effects": {
						"corruption": 2,
						"set_flag": {"suirei_conquest_path": true},
					},
				},
				{
					"label": "寻求平衡",
					"description": "承认双方的立场都有道理，提议共同找到可持续的方案。",
					"effects": {
						"affection": 1, "prestige": 1,
						"set_flag": {"suirei_balance_path": true},
					},
				},
			],
			"system_prompt": "第一个关键选择。你对自然的态度将决定翠玲的未来。",
			"effects": {},
		},
		{
			"id": "suirei_training_03a",
			"name": "Stage 3: 共鸣（自然之路）",
			"trigger": {
				"prev_event": "suirei_training_02",
				"requires_flag": "suirei_nature_path",
				"affection_or_corruption": {"affection_min": 4, "corruption_min": 5},
			},
			"scene": "翠玲被允许在城堡花园中自由活动。她将一片荒芜的角落变成了小型精灵花园。",
			"dialogues": [
				{"speaker": "翠玲", "text": "你真的信守了承诺……这在人类中很罕见。"},
				{"type": "narration", "text": "她跪在花丛中，手指轻触一朵刚绽放的银铃花。"},
				{"speaker": "翠玲", "text": "这朵花……它在告诉我，也许不是所有人类都是破坏者。"},
			],
			"choices": [
				{
					"label": "请她教你精灵植物学",
					"description": "以学生的姿态请教，真心想理解精灵与自然的纽带。",
					"effects": {
						"affection": 2,
						"set_flag": {"suirei_student": true},
					},
				},
				{
					"label": "利用她的能力",
					"description": "让她用精灵的力量加速农作物生长，增强你的经济。",
					"effects": {
						"corruption": 1,
						"set_flag": {"suirei_exploited": true},
						"clear_flag": "suirei_nature_path",
					},
				},
			],
			"system_prompt": "翠玲开始信任你。真心学习将深化纽带，利用将偏向操控。",
			"effects": {},
		},
		{
			"id": "suirei_training_03b",
			"name": "Stage 3: 压迫（征服之路）",
			"trigger": {
				"prev_event": "suirei_training_02",
				"requires_flag": "suirei_conquest_path",
				"affection_or_corruption": {"affection_min": 3, "corruption_min": 5},
			},
			"scene": "翠玲被迫观看你的伐木队在精灵森林外围砍伐。",
			"dialogues": [
				{"type": "narration", "text": "每一棵树倒下时，翠玲的耳朵都会痛苦地颤抖。"},
				{"speaker": "翠玲", "text": "你们……你们听不到它们的哭声吗……每一棵……都是数百年……"},
			],
			"choices": [
				{
					"label": "停止砍伐",
					"description": "意识到这种做法太残忍，下令停止。",
					"effects": {
						"affection": 3,
						"set_flag": {"suirei_mercy": true},
						"clear_flag": "suirei_conquest_path",
					},
				},
				{
					"label": "要求她指出最有价值的树木",
					"description": "利用她的知识来最大化资源开采。",
					"effects": {
						"corruption": 3,
						"set_flag": {"suirei_destroyer": true},
					},
				},
			],
			"system_prompt": "翠玲目睹森林被毁。仁慈可转向救赎，继续将让她彻底绝望。",
			"effects": {},
		},
		{
			"id": "suirei_training_03c",
			"name": "Stage 3: 外交（平衡之路）",
			"trigger": {
				"prev_event": "suirei_training_02",
				"requires_flag": "suirei_balance_path",
				"affection_or_corruption": {"affection_min": 4, "corruption_min": 5},
			},
			"scene": "翠玲和你一起审查领地的资源规划地图。",
			"dialogues": [
				{"speaker": "翠玲", "text": "如果你们只砍伐这些区域，并在这里种植新树……五十年后，森林的规模甚至可以超过现在。"},
				{"type": "narration", "text": "她的精灵长耳微微竖起——这是她认真思考时的习惯。"},
				{"speaker": "翠玲", "text": "也许……精灵和人类确实可以共存。前提是你们愿意用我们的时间尺度来思考。"},
			],
			"choices": [
				{
					"label": "采纳她的方案",
					"description": "完全采用精灵的可持续发展模式，即使短期收益减少。",
					"effects": {
						"affection": 2,
						"set_flag": {"suirei_diplomat": true},
					},
				},
				{
					"label": "提议她担任大使",
					"description": "让她正式代表精灵族与你的领地谈判合作。",
					"effects": {
						"affection": 1, "prestige": 2,
						"set_flag": {"suirei_envoy": true},
					},
				},
			],
			"system_prompt": "翠玲展现了外交才能。两个选择都走向联盟，但方式不同。",
			"effects": {},
		},
		{
			"id": "suirei_training_04a",
			"name": "Stage 4: 转折——守护者之路",
			"trigger": {
				"prev_event": "suirei_training_03a",
				"affection_min": 6,
				"requires_flag": ["suirei_student"],
				"excludes_flag": ["suirei_exploited"],
			},
			"scene": "精灵花园。银铃花在月光下全部绽放，发出柔和的荧光。",
			"dialogues": [
				{"speaker": "翠玲", "text": "银铃花只在它们认可的土地上绽放。它们认可了这里……也认可了你。"},
				{"type": "narration", "text": "她将一朵银铃花别在你的衣襟上。精灵的手指在你的胸口停留了一瞬。"},
				{"speaker": "翠玲", "text": "三百七十二年来，我从未对人类做过这个举动。请珍惜。"},
			],
			"system_prompt": "守护者路线解锁。翠玲获得永久DEF+4，解锁森林地形战斗加成。解锁主动技能「月影之箭」——对所有敌人造成INT基础伤害。",
			"effects": {
				"affection": 2,
				"set_flag": {"suirei_guardian": true},
				"unlock_skill": "moonlit_arrow",
			},
		},
		{
			"id": "suirei_training_04b",
			"name": "Stage 4: 转折——征服者之路",
			"trigger": {
				"prev_event": "suirei_training_03b",
				"corruption_min": 7,
				"requires_flag": ["suirei_destroyer"],
			},
			"scene": "翠玲站在被砍伐的森林废墟中，目光空洞。",
			"dialogues": [
				{"type": "narration", "text": "她的精灵耳朵低垂着——这是精灵彻底放弃希望的姿态。"},
				{"speaker": "翠玲", "text": "树木都死了……它们的歌声……我再也听不到了……"},
				{"type": "narration", "text": "但在绝望中，她的箭术反而变得更加凶狠。失去要守护的东西后，她成了纯粹的杀戮机器。"},
			],
			"system_prompt": "征服者路线解锁。翠玲获得永久ATK+4。精灵森林资源可被开采。",
			"effects": {
				"corruption": 1,
				"set_flag": {"suirei_conqueror": true},
				"unlock_skill": "wrath_volley",
			},
		},
		{
			"id": "suirei_training_04c",
			"name": "Stage 4: 转折——大使之路",
			"trigger": {
				"prev_event": "suirei_training_03c",
				"affection_min": 5,
				"requires_flag": ["suirei_envoy"],
			},
			"scene": "外交会议室。翠玲穿着正式的精灵礼服，银月议庭的徽章别在胸口。",
			"dialogues": [
				{"speaker": "翠玲", "text": "银月议庭已同意初步接触。这是三百年来精灵首次正式与人类政权对话。"},
				{"type": "narration", "text": "她的表情兼具精灵的优雅和外交官的精明。"},
				{"speaker": "翠玲", "text": "如果这次成功了……也许我们可以改变这个世界的运作方式。"},
			],
			"system_prompt": "大使路线解锁。翠玲获得DEF+2, ATK+2，开启精灵联盟线。",
			"effects": {
				"affection": 2,
				"set_flag": {"suirei_ambassador": true},
				"unlock_skill": "verdant_shield",
			},
		},
		{
			"id": "suirei_training_04c_alt",
			"name": "Stage 4: 转折——大使之路（自然外交线）",
			"trigger": {
				"prev_event": "suirei_training_03c",
				"affection_min": 5,
				"requires_flag": ["suirei_diplomat"],
				"excludes_flag": ["suirei_envoy"],
			},
			"scene": "精灵花园扩建完成，已成为领地中最美丽的地方。",
			"dialogues": [
				{"speaker": "翠玲", "text": "你用行动证明了你的诚意。我会写信给银月议庭……推荐正式的合作。"},
			],
			"system_prompt": "大使路线解锁（自然外交线）。翠玲获得DEF+2, ATK+2。",
			"effects": {
				"affection": 2,
				"set_flag": {"suirei_ambassador": true},
				"unlock_skill": "verdant_shield",
			},
		},
		{
			"id": "suirei_training_05a",
			"name": "Stage 5: 危机——守护者之路",
			"trigger": {
				"turn_min": 30,
				"affection_min": 7,
				"requires_flag": ["suirei_guardian"],
			},
			"scene": "紧急！一支军队正在进攻精灵森林的核心区域。",
			"dialogues": [
				{"speaker": "翠玲", "text": "世界树的种子在那里……如果它被毁了，精灵族将失去最后的根基！"},
				{"type": "narration", "text": "她紧握长弓，翠绿色的瞳孔中燃烧着前所未有的决心。"},
				{"speaker": "翠玲", "text": "和我一起去守护它！这一次——我不是为精灵族而战，是为了我们共同守护的东西！"},
			],
			"system_prompt": "守护者危机。保卫精灵森林核心。",
			"effects": {
				"affection": 3,
				"set_flag": {"suirei_forest_saved": true},
			},
		},
		{
			"id": "suirei_training_05b",
			"name": "Stage 5: 危机——征服者之路",
			"trigger": {
				"turn_min": 30,
				"corruption_min": 7,
				"requires_flag": ["suirei_conqueror"],
			},
			"scene": "翠玲在战场上暴走，将箭射向了一切会动的目标。",
			"dialogues": [
				{"type": "narration", "text": "失去了与自然的联系后，她的精灵本能开始失控。"},
				{"speaker": "翠玲", "text": "全都消失吧……就像那些树一样……全都——"},
			],
			"choices": [
				{
					"label": "带她回到森林遗址",
					"description": "带她回到被砍伐的森林，种下一颗新的种子。",
					"effects": {
						"affection": 3,
						"set_flag": {"suirei_regrowth": true},
					},
				},
				{
					"label": "用更强的力量压制",
					"description": "以武力制止她的暴走。",
					"effects": {
						"corruption": 2,
						"set_flag": {"suirei_broken": true},
					},
				},
			],
			"system_prompt": "征服者危机。翠玲失控。",
			"effects": {},
		},
		{
			"id": "suirei_training_05c",
			"name": "Stage 5: 危机——大使之路",
			"trigger": {
				"turn_min": 30,
				"affection_min": 7,
				"requires_flag": ["suirei_ambassador"],
			},
			"scene": "精灵议庭内部出现了反对与人类合作的声音。翠玲面临两难。",
			"dialogues": [
				{"speaker": "翠玲", "text": "议庭中有人认为我背叛了精灵族……他们要召回我，终止所有合作。"},
				{"type": "narration", "text": "她的耳朵微微下垂——精灵表达悲伤的方式。"},
				{"speaker": "翠玲", "text": "如果你能来议庭，亲自对他们证明合作的价值……也许还有机会。"},
			],
			"system_prompt": "大使危机。精灵内部分裂。需要共同化解。",
			"effects": {
				"affection": 2,
				"set_flag": {"suirei_council_crisis": true},
			},
		},
		{
			"id": "suirei_training_06a",
			"name": "Stage 6: 结局——守护者",
			"trigger": {
				"affection_min": 10,
				"requires_flag": ["suirei_guardian", "suirei_forest_saved"],
			},
			"scene": "世界树幼苗前。翠玲将弓插在土中，让藤蔓自然缠绕。",
			"dialogues": [
				{"speaker": "翠玲", "text": "三百七十二年……我终于找到了值得并肩守护森林的人。"},
				{"type": "narration", "text": "她伸出手，修长的精灵手指与你十指相扣。银铃花在两人脚下同时绽放。"},
				{"speaker": "翠玲", "text": "精灵的一生很长。但与你共度的每一刻，都比过去三百年更加鲜活。"},
				{"type": "narration", "text": "解锁「森林结界」阵型加成：翠玲在森林地形DEF×1.3"},
			],
			"system_prompt": "守护者结局。解锁「森林结界」阵型加成。翠玲与你共同守护自然。",
			"effects": {
				"set_flag": {"suirei_forest_formation": true},
			},
		},
		{
			"id": "suirei_training_06b",
			"name": "Stage 6: 结局——征服者",
			"trigger": {
				"corruption_min": 8,
				"requires_flag": ["suirei_conqueror", "suirei_broken"],
			},
			"scene": "翠玲坐在枯死的树桩上，银白色的长发失去了光泽。",
			"dialogues": [
				{"speaker": "翠玲", "text": "……告诉我射哪里就好。我什么都不在乎了。"},
				{"type": "narration", "text": "精灵森林的资源已被完全开采。翠玲成为了一台精准的杀戮机器。"},
				{"type": "narration", "text": "解锁精灵森林资源开采。翠玲ATK+4但失去所有后续剧情。"},
			],
			"system_prompt": "征服者结局。精灵森林被开采。翠玲成为武器。",
			"effects": {
				"set_flag": {"suirei_forest_conquered": true},
			},
		},
		{
			"id": "suirei_training_06c",
			"name": "Stage 6: 结局——大使",
			"trigger": {
				"affection_min": 9,
				"requires_flag": ["suirei_ambassador", "suirei_council_crisis"],
			},
			"scene": "银月议庭大厅。翠玲站在精灵与人类代表之间。",
			"dialogues": [
				{"speaker": "翠玲", "text": "以银月议庭第三席的名义，我宣布——精灵族与魔王领正式缔结森林守护同盟。"},
				{"type": "narration", "text": "议庭中响起了精灵特有的和鸣之音——这是认可的最高形式。"},
				{"speaker": "翠玲", "text": "（小声）这是为公事。但今晚……有些私人的话想对你说。"},
				{"type": "narration", "text": "解锁精灵联盟外交路线。"},
			],
			"system_prompt": "大使结局。精灵联盟建立。翠玲成为两族之间的桥梁。",
			"effects": {
				"set_flag": {"suirei_elf_alliance": true},
			},
		},
	],
	"pure_love": [],
	"exclusive_ending": [],
}
