## sou_story.gd - Story event data for Sou (蒼) — Deep Branching System v2.0
## White Tower Grand Mage. Theme: knowledge vs power.
## 3 divergent paths from player choices leading to 3 distinct endings.
extends RefCounted

const EVENTS: Dictionary = {
	"training": [
		{
			"id": "sou_training_01",
			"name": "Stage 1: 俘虏（大魔导师的矜持）",
			"trigger": {"hero_captured": true},
			"scene": "封印室。蒼被固定在反魔力封印椅上，三重封魔核心抑制着她的力量。银白色长发在符文蓝光中泛着冷辉，紫水晶色双瞳微微发光。",
			"dialogues": [
				{"speaker": "蒼", "text": "哦？来了吗。从理论上说，捕获大魔导师后的最优策略是在二十四小时内审讯——你迟到了三个小时。效率堪忧。"},
				{"type": "narration", "text": "即使被封印椅束缚，她的姿态依然从容。"},
				{"speaker": "蒼", "text": "四百年的记忆防壁术——即使最高阶精神系魔法也无法突破。这不是自夸，而是经过同行评审的学术事实。"},
				{"speaker": "蒼", "text": "区区肉体的刺激，不过是研究对象表面的扰动罢了。"},
			],
			"system_prompt": "蒼被俘。学术的傲慢是她最后的防线。",
			"effects": {"training_progress": 1},
		},
		{
			"id": "sou_training_02",
			"name": "Stage 2: 知识的诱惑（第一个选择）",
			"trigger": {"prev_event": "sou_training_01", "corruption_min": 2},
			"scene": "封印室中，蒼注意到你带来的几本古籍——其中一本是她一直在寻找的失落文献。",
			"dialogues": [
				{"type": "narration", "text": "蒼的紫瞳在看到那本书的瞬间微微扩张——四百年的修养也无法完全掩盖学者对知识的渴望。"},
				{"speaker": "蒼", "text": "《赫尔墨斯第七残卷》……这本书在白塔的目录中已失踪两百年。你从哪里——"},
				{"type": "narration", "text": "她意识到自己失态了，立刻恢复了平静。"},
				{"speaker": "蒼", "text": "……从学术角度而言，我确实对那本书有一些好奇。"},
			],
			"choices": [
				{
					"label": "学术交流",
					"description": "将书交给她，并请教书中内容。以平等的学者身份与她对话。",
					"effects": {
						"affection": 2,
						"set_flag": {"sou_scholar_path": true},
					},
				},
				{
					"label": "以知识换服从",
					"description": "告诉她如果想看这本书，就必须为你效力。用她最渴望的东西来交换。",
					"effects": {
						"corruption": 2,
						"set_flag": {"sou_power_path": true},
					},
				},
				{
					"label": "展示禁忌知识",
					"description": "透露你拥有白塔禁忌文献的线索。那些被封存的、危险的、被禁止的研究。",
					"effects": {
						"corruption": 1, "prestige": 1,
						"set_flag": {"sou_forbidden_path": true},
					},
				},
			],
			"system_prompt": "第一个关键选择。知识是蒼的弱点——也可以是她的救赎。",
			"effects": {},
		},
		{
			"id": "sou_training_03a",
			"name": "Stage 3: 学术纽带（学者之路）",
			"trigger": {
				"prev_event": "sou_training_02",
				"requires_flag": "sou_scholar_path",
				"affection_or_corruption": {"affection_min": 4, "corruption_min": 5},
			},
			"scene": "蒼的封印被部分解除，她获准使用图书室。两人经常深夜讨论魔法理论。",
			"dialogues": [
				{"speaker": "蒼", "text": "你对第三纪元魔导阵列的理解有偏差。不过考虑到你不是受过系统教育的法师，这个水平……勉强可以接受。"},
				{"type": "narration", "text": "从蒼口中说出的'勉强可以接受'，已经是极高的评价了。"},
				{"speaker": "蒼", "text": "……如果你愿意的话，我可以系统性地教授你基础魔法理论。纯粹出于学术目的。不要误会。"},
			],
			"choices": [
				{
					"label": "认真学习",
					"description": "以认真的态度拜她为师，真心学习魔法理论。",
					"effects": {
						"affection": 2,
						"set_flag": {"sou_apprentice": true},
					},
				},
				{
					"label": "将她的知识武器化",
					"description": "学习的同时，暗中将她的理论应用于军事魔法开发。",
					"effects": {
						"corruption": 1,
						"set_flag": {"sou_weaponize": true},
						"clear_flag": "sou_scholar_path",
					},
				},
			],
			"system_prompt": "蒼开始教授你。真心学习将走向纯爱，武器化将偏向操控。",
			"effects": {},
		},
		{
			"id": "sou_training_03b",
			"name": "Stage 3: 力量交易（力量之路）",
			"trigger": {
				"prev_event": "sou_training_02",
				"requires_flag": "sou_power_path",
				"affection_or_corruption": {"affection_min": 3, "corruption_min": 5},
			},
			"scene": "蒼开始为你工作——研究增强部队的魔法。但她的眼中没有热情，只有计算。",
			"dialogues": [
				{"speaker": "蒼", "text": "按照约定，这是第三批增幅符文的配方。现在——把那本书给我。"},
				{"type": "narration", "text": "她的手指在接近书本时微微颤抖——四百年的渴望即将被满足。"},
				{"speaker": "蒼", "text": "别误会。这是公平交易。我提供魔法支援，你提供研究材料。仅此而已。"},
			],
			"choices": [
				{
					"label": "履行承诺",
					"description": "如约交出书籍，建立信任基础。",
					"effects": {
						"affection": 2,
						"set_flag": {"sou_trusted": true},
					},
				},
				{
					"label": "追加条件",
					"description": "告诉她你有更多的珍贵文献——但需要更多的'合作'。",
					"effects": {
						"corruption": 2,
						"set_flag": {"sou_exploited": true},
					},
				},
			],
			"system_prompt": "知识交易。守信将获得信任，得寸进尺将走向控制。",
			"effects": {},
		},
		{
			"id": "sou_training_03c",
			"name": "Stage 3: 禁忌的诱惑（禁忌之路）",
			"trigger": {
				"prev_event": "sou_training_02",
				"requires_flag": "sou_forbidden_path",
				"affection_or_corruption": {"affection_min": 3, "corruption_min": 5},
			},
			"scene": "深夜。蒼独自翻阅你提供的禁忌文献，紫瞳中闪烁着危险的光芒。",
			"dialogues": [
				{"speaker": "蒼", "text": "这些研究……白塔封存它们不是没有道理的。这些力量足以改变战争的形态。但风险——"},
				{"type": "narration", "text": "她的手指在一页特别危险的术式上停留了很久。"},
				{"speaker": "蒼", "text": "从纯学术的角度而言……不研究它们才是真正的浪费。真理不应该被恐惧所封存。"},
			],
			"choices": [
				{
					"label": "设定安全边界",
					"description": "允许她研究，但设立严格的安全协议和禁区。",
					"effects": {
						"affection": 1,
						"set_flag": {"sou_controlled_research": true},
					},
				},
				{
					"label": "全面开放",
					"description": "给她所有禁忌文献，不设任何限制。",
					"effects": {
						"corruption": 3,
						"set_flag": {"sou_unbound": true},
					},
				},
			],
			"system_prompt": "禁忌知识。有限制可避免灾难，无限制将导向不可控的力量。",
			"effects": {},
		},
		{
			"id": "sou_training_04a",
			"name": "Stage 4: 转折——学者之路",
			"trigger": {
				"prev_event": "sou_training_03a",
				"affection_min": 6,
				"requires_flag": ["sou_apprentice"],
				"excludes_flag": ["sou_weaponize"],
			},
			"scene": "深夜的图书室。蒼正在校对你的魔法论文，银白色长发在烛光中泛着柔和的光泽。",
			"dialogues": [
				{"speaker": "蒼", "text": "这篇论文的论证逻辑……出乎意料地严谨。虽然第四章的推导过程需要修改……但核心观点——"},
				{"type": "narration", "text": "她抬起头，紫瞳中少有地流露出温暖。"},
				{"speaker": "蒼", "text": "四百年来，我一直是独自研究。有一个能跟上我思路的人……是一种我没有预料到的体验。"},
				{"speaker": "蒼", "text": "不要误会。这纯粹是学术层面的评价。"},
				{"type": "narration", "text": "她别过头，但耳尖微微泛红。"},
			],
			"system_prompt": "学者路线解锁。蒼获得INT+6，解锁AoE法力消耗减免。解锁主动技能「魔导连锁」——降低全队法术消耗30%持续3回合。",
			"effects": {
				"affection": 2,
				"set_flag": {"sou_scholar": true},
				"unlock_skill": "arcane_chain",
			},
		},
		{
			"id": "sou_training_04b",
			"name": "Stage 4: 转折——力量之路",
			"trigger": {
				"prev_event": "sou_training_03b",
				"corruption_min": 6,
				"requires_flag": ["sou_exploited"],
			},
			"scene": "蒼在魔法工坊中日以继夜地工作。她的眼下出现了深深的黑眼圈——四百年来第一次。",
			"dialogues": [
				{"speaker": "蒼", "text": "第七批攻击型符文已完成。效能比上一批提升23%。"},
				{"type": "narration", "text": "她的声音冷静而高效，像一台精密的机器。"},
				{"speaker": "蒼", "text": "下一本书。我要下一本。"},
			],
			"system_prompt": "力量路线解锁。蒼获得ATK+4，每次攻击附带魔力吸取。",
			"effects": {
				"corruption": 1,
				"set_flag": {"sou_power": true},
				"unlock_skill": "mana_drain",
			},
		},
		{
			"id": "sou_training_04b_alt",
			"name": "Stage 4: 转折——力量之路（信任线）",
			"trigger": {
				"prev_event": "sou_training_03b",
				"affection_min": 5,
				"requires_flag": ["sou_trusted"],
				"excludes_flag": ["sou_exploited"],
			},
			"scene": "蒼自愿为你的军队研发增强魔法——不是因为交易，而是因为信任。",
			"dialogues": [
				{"speaker": "蒼", "text": "你遵守了约定。在人类中，这是一种……罕见的品质。"},
				{"speaker": "蒼", "text": "作为回报，我会全力支援你的军事行动。这不是交易——是我的选择。"},
			],
			"system_prompt": "力量路线解锁（信任线）。蒼获得ATK+4，攻击附带魔力吸取。",
			"effects": {
				"affection": 1,
				"set_flag": {"sou_power": true},
				"unlock_skill": "mana_drain",
			},
		},
		{
			"id": "sou_training_04c",
			"name": "Stage 4: 转折——禁忌之路",
			"trigger": {
				"prev_event": "sou_training_03c",
				"corruption_min": 6,
				"requires_flag": ["sou_unbound"],
			},
			"scene": "蒼的研究室发出不祥的光芒。她的银白色长发开始出现黑色的纹路。",
			"dialogues": [
				{"speaker": "蒼", "text": "我突破了第九层封印理论……你知道那意味着什么吗？"},
				{"type": "narration", "text": "她的紫瞳中闪烁着危险而狂热的光。"},
				{"speaker": "蒼", "text": "这种力量——足以撕裂现实的层壁。白塔的老朽们害怕它，但我不。知识不应该有禁区。"},
				{"type": "narration", "text": "但在她转过身时，你注意到她的手在颤抖。"},
			],
			"system_prompt": "禁忌路线解锁。蒼获得ATK+5, DEF-1，有10%概率释放无差别AoE。解锁主动技能「虚空裂隙」——巨额伤害但友军也受影响。",
			"effects": {
				"corruption": 2,
				"set_flag": {"sou_forbidden": true},
				"unlock_skill": "void_rift",
			},
		},
		{
			"id": "sou_training_04c_alt",
			"name": "Stage 4: 转折——禁忌之路（控制线）",
			"trigger": {
				"prev_event": "sou_training_03c",
				"affection_min": 4,
				"requires_flag": ["sou_controlled_research"],
				"excludes_flag": ["sou_unbound"],
			},
			"scene": "蒼在安全协议的框架内取得了突破性进展。",
			"dialogues": [
				{"speaker": "蒼", "text": "你设定的安全边界……起初我觉得多余。但事实证明，限制反而激发了更精准的思路。"},
				{"speaker": "蒼", "text": "我找到了一种方法——利用禁忌原理，但将风险控制在可接受范围内。"},
			],
			"system_prompt": "禁忌路线解锁（控制线）。蒼获得ATK+4，风险降低但仍有5%概率失控。",
			"effects": {
				"affection": 1,
				"set_flag": {"sou_forbidden": true},
				"unlock_skill": "controlled_rift",
			},
		},
		{
			"id": "sou_training_05a",
			"name": "Stage 5: 危机——学者之路",
			"trigger": {
				"turn_min": 30,
				"affection_min": 7,
				"requires_flag": ["sou_scholar"],
			},
			"scene": "白塔派来使者，要求蒼返回接受审判——他们认为她泄露了机密。",
			"dialogues": [
				{"speaker": "蒼", "text": "白塔的审判……如果我回去，等待我的是记忆封印术。四百年的知识，都会被抹除。"},
				{"type": "narration", "text": "她第一次露出了恐惧的表情——不是怕死，是怕失去知识。"},
				{"speaker": "蒼", "text": "但如果我不回去……白塔会视你为敌。"},
			],
			"system_prompt": "学者危机。白塔威胁抹除蒼的记忆。",
			"effects": {
				"affection": 2,
				"set_flag": {"sou_protected": true},
			},
		},
		{
			"id": "sou_training_05b",
			"name": "Stage 5: 危机——力量之路",
			"trigger": {
				"turn_min": 30,
				"corruption_min": 7,
				"requires_flag": ["sou_power"],
			},
			"scene": "蒼制造的魔法武器产生了意外的连锁反应，一座城镇受到了魔力辐射。",
			"dialogues": [
				{"speaker": "蒼", "text": "这不在我的计算范围内……理论上不应该发生这种——"},
				{"type": "narration", "text": "她看着受伤的平民，紫瞳中首次出现了内疚。"},
				{"speaker": "蒼", "text": "我的研究……造成了这些？"},
			],
			"choices": [
				{
					"label": "和她一起治疗伤者",
					"description": "放下一切，先救人。让她直面自己研究的后果。",
					"effects": {
						"affection": 3,
						"set_flag": {"sou_conscience": true},
					},
				},
				{
					"label": "掩盖事故",
					"description": "封锁消息，继续研发。不能让这点意外影响大局。",
					"effects": {
						"corruption": 2,
						"set_flag": {"sou_cold": true},
					},
				},
			],
			"system_prompt": "力量危机。魔法武器造成附带伤害。",
			"effects": {},
		},
		{
			"id": "sou_training_05c",
			"name": "Stage 5: 危机——禁忌之路",
			"trigger": {
				"turn_min": 30,
				"corruption_min": 7,
				"requires_flag": ["sou_forbidden"],
			},
			"scene": "蒼的研究室发生了失控事件。她的身体被禁忌魔力侵蚀，半边头发变成了漆黑色。",
			"dialogues": [
				{"speaker": "蒼", "text": "虚空裂隙……不稳定……我无法——"},
				{"type": "narration", "text": "她的身体在禁忌魔力的冲击下颤抖，双手泛着不祥的黑光。"},
				{"speaker": "蒼", "text": "帮我……如果我失控——如果我变成那种东西——请你——"},
			],
			"choices": [
				{
					"label": "用你的力量稳定她",
					"description": "与她共同承担禁忌魔力的代价，帮她恢复控制。",
					"effects": {
						"affection": 3,
						"set_flag": {"sou_stabilized": true},
					},
				},
				{
					"label": "让她自行承受",
					"description": "这是她自己选择的道路。让她独自面对后果。",
					"effects": {
						"corruption": 2,
						"set_flag": {"sou_consumed": true},
					},
				},
			],
			"system_prompt": "禁忌危机。禁忌魔力开始侵蚀蒼的身体。",
			"effects": {},
		},
		{
			"id": "sou_training_06a",
			"name": "Stage 6: 结局——学者",
			"trigger": {
				"affection_min": 10,
				"requires_flag": ["sou_scholar", "sou_protected"],
			},
			"scene": "两人共同的图书室。蒼完成了她四百年来最伟大的论文——以你的名字共同署名。",
			"dialogues": [
				{"speaker": "蒼", "text": "《论魔法与文明的共生关系》——共同作者：蒼·伊斯特利亚与……"},
				{"type": "narration", "text": "她停下笔，紫瞳中的光芒比任何魔法都更加温暖。"},
				{"speaker": "蒼", "text": "四百年来，我以为知识就是一切。但现在我知道了——没有你，这些知识只是冰冷的文字。"},
				{"speaker": "蒼", "text": "让我继续做你的导师——同时……也做你的伴侣。从学术角度而言，这是最优解。"},
				{"type": "narration", "text": "解锁「奥术结界」阵型加成：蒼全队法术INT×1.4"},
			],
			"system_prompt": "学者结局。解锁「奥术结界」阵型加成。蒼与你共同探索知识的边界。",
			"effects": {
				"set_flag": {"sou_arcane_formation": true},
			},
		},
		{
			"id": "sou_training_06b",
			"name": "Stage 6: 结局——力量",
			"trigger": {
				"corruption_min": 8,
				"requires_flag": ["sou_power", "sou_cold"],
			},
			"scene": "蒼的魔法工坊已经成为了一座军事要塞。",
			"dialogues": [
				{"speaker": "蒼", "text": "第四十七批增幅符文。效率已优化到理论极限。"},
				{"type": "narration", "text": "她的声音毫无感情，紫瞳中只剩下冰冷的计算。四百年的情感被压缩成了纯粹的效率。"},
				{"type": "narration", "text": "蒼成为最强魔法支援单位。ATK+4，每次攻击魔力吸取。但没有更多剧情。"},
			],
			"system_prompt": "力量结局。蒼成为军事资产。战力极高但失去了学者的灵魂。",
			"effects": {
				"set_flag": {"sou_weapon_complete": true},
			},
		},
		{
			"id": "sou_training_06c",
			"name": "Stage 6: 结局——禁忌",
			"trigger": {
				"corruption_min": 8,
				"requires_flag": ["sou_forbidden", "sou_consumed"],
			},
			"scene": "蒼站在虚空裂隙之前。她的头发一半银白一半漆黑，双瞳分别是紫色和赤红。",
			"dialogues": [
				{"speaker": "蒼", "text": "我看到了……第十一维度的真实……美丽而恐怖……"},
				{"type": "narration", "text": "她举起双手，空间在她掌心中扭曲。"},
				{"speaker": "蒼", "text": "不要靠近我。现在的我……连自己都无法完全控制。但这股力量——足以终结一切战争。"},
				{"type": "narration", "text": "蒼成为破坏力最强的单位。ATK+5，但有10%概率对友军释放AoE。代价是她的人性正在缓慢消失。"},
			],
			"system_prompt": "禁忌结局。蒼获得了超越凡人的力量，但正在失去自我。",
			"effects": {
				"set_flag": {"sou_void_walker": true},
			},
		},
		{
			"id": "sou_training_06c_alt",
			"name": "Stage 6: 结局——禁忌（稳定线）",
			"trigger": {
				"affection_min": 8,
				"requires_flag": ["sou_forbidden", "sou_stabilized"],
			},
			"scene": "蒼在你的帮助下成功控制了禁忌魔力。她的头发恢复了银白，但瞳孔中仍偶尔闪过赤红。",
			"dialogues": [
				{"speaker": "蒼", "text": "你帮我找到了平衡点。没有你的锚定，我已经被虚空吞噬了。"},
				{"type": "narration", "text": "她罕见地主动握住了你的手。"},
				{"speaker": "蒼", "text": "从理论上说，我现在拥有了禁忌的力量但保留了人性。你就是我的'安全协议'。"},
				{"type": "narration", "text": "解锁「奥术结界」阵型加成（稳定版）。"},
			],
			"system_prompt": "禁忌结局（稳定线）。蒼控制了禁忌之力。解锁「奥术结界」。",
			"effects": {
				"set_flag": {"sou_arcane_formation": true},
			},
		},
	],
	"pure_love": [],
	"exclusive_ending": [],
}
