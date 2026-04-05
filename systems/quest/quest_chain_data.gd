## quest_chain_data.gd — 任务链数据定义 (v1.0)
## 定义所有复杂任务链（Graph-Driven Quest Chains）。
## 每条链由节点（nodes）和有向边（next/requires）构成有向无环图（DAG）。
##
## 节点类型（type）:
##   "quest"   — 绑定到 QuestJournal 中的一个任务
##   "event"   — 绑定到 EventSystem 中的一个事件（触发弹窗）
##   "gate"    — 条件门节点，不显示给玩家，仅用于逻辑分叉
##   "reward"  — 奖励节点，完成后自动发放奖励
##
## 节点状态（由 QuestChainManager 管理）:
##   LOCKED       — 前置未完成，不可见
##   AVAILABLE    — 前置已满足，可激活
##   ACTIVE       — 正在进行
##   COMPLETED    — 已完成
##   FAILED       — 已失败（不可重试）
##   SKIPPED      — 因互斥分支被选择而跳过
##
## 分支机制:
##   "next": ["node_a", "node_b"]          — 完成后同时解锁两个节点（并行）
##   "branch_choice": true                 — 完成后玩家主动选择一个分支（互斥）
##   "mutually_exclusive": ["node_x"]      — 激活本节点时，将 node_x 标记为 SKIPPED
##   "requires": ["node_a", "node_b"]      — 需要所有前置节点均为 COMPLETED 才能解锁
##   "requires_any": ["node_a", "node_b"]  — 任意一个前置节点 COMPLETED 即可解锁
##
## 条件门（gate 节点的 condition）:
##   支持的键: turn_min, tiles_min, gold_min, threat_min, flag_set, quest_completed
##
extends RefCounted
class_name QuestChainData

# ═══════════════ 枚举 ═══════════════
enum NodeStatus {
	LOCKED,
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	FAILED,
	SKIPPED,
}

# ═══════════════ 任务链定义 ═══════════════
const CHAINS: Dictionary = {

	# ─────────────────────────────────────────────────────────────────
	# 链 1: 史诗叛乱（Epic Rebellion）
	# 触发条件: 主线任务3完成后，秩序低于40
	# 分支: 武力镇压 / 外交谈判，结局不同
	# ─────────────────────────────────────────────────────────────────
	"epic_rebellion": {
		"name": "史诗叛乱",
		"desc": "领地内爆发了大规模叛乱，你必须做出抉择。",
		"category": "side_chain",
		"trigger": {
			"quest_completed": "main_3",
			"order_below": 40,
		},
		"start_node": "rebellion_outbreak",
		"nodes": {
			"rebellion_outbreak": {
				"type": "event",
				"name": "叛乱爆发",
				"desc": "领地内的不满情绪终于爆发，叛军占据了数个据点。",
				"event_id": "rebellion_outbreak",
				"branch_choice": true,
				"next": ["suppress_force", "negotiate_peace"],
				"requires": [],
			},
			"suppress_force": {
				"type": "quest",
				"name": "武力镇压",
				"desc": "调集军队，彻底消灭叛军。",
				"quest_id": "chain_rebellion_suppress",
				"mutually_exclusive": ["negotiate_peace"],
				"requires": ["rebellion_outbreak"],
				"next": ["military_aftermath"],
			},
			"negotiate_peace": {
				"type": "quest",
				"name": "外交谈判",
				"desc": "派遣使者与叛军领袖谈判，以金钱换取和平。",
				"quest_id": "chain_rebellion_negotiate",
				"mutually_exclusive": ["suppress_force"],
				"requires": ["rebellion_outbreak"],
				"next": ["diplomatic_aftermath"],
			},
			"military_aftermath": {
				"type": "reward",
				"name": "铁腕统治",
				"desc": "叛乱被彻底镇压，你的威权得到巩固。",
				"reward": {
					"gold": 300,
					"prestige": 50,
					"order_delta": 15,
					"flag_set": "rebellion_suppressed",
					"message": "铁腕镇压叛乱，威望大增，但民心有所损失。",
				},
				"requires": ["suppress_force"],
				"next": ["rebellion_legacy"],
			},
			"diplomatic_aftermath": {
				"type": "reward",
				"name": "怀柔政策",
				"desc": "谈判成功，叛军解散，民心得到安抚。",
				"reward": {
					"gold": -200,
					"order_delta": 25,
					"flag_set": "rebellion_negotiated",
					"message": "外交谈判成功，民心稳定，但损失了一批财富。",
				},
				"requires": ["negotiate_peace"],
				"next": ["rebellion_legacy"],
			},
			"rebellion_legacy": {
				"type": "gate",
				"name": "叛乱的遗产",
				"desc": "叛乱已经平息，但其影响将持续存在。",
				"condition": {
					"flag_set_any": ["rebellion_suppressed", "rebellion_negotiated"],
				},
				"requires_any": ["military_aftermath", "diplomatic_aftermath"],
				"next": ["legacy_stronghold"],
			},
			"legacy_stronghold": {
				"type": "quest",
				"name": "重建要塞",
				"desc": "在叛乱的发源地建造一座要塞，以防止未来的动乱。",
				"quest_id": "chain_rebellion_stronghold",
				"requires": ["rebellion_legacy"],
				"next": [],
			},
		},
	},

	# ─────────────────────────────────────────────────────────────────
	# 链 2: 暗影精英（Shadow Elite）
	# 触发条件: 暗影精华 >= 30，且有至少2名英雄
	# 分支: 强化路线 / 腐化路线，影响英雄成长
	# ─────────────────────────────────────────────────────────────────
	"shadow_elite": {
		"name": "暗影精英",
		"desc": "积累的暗影精华开始呼唤更深层的力量……",
		"category": "character_chain",
		"trigger": {
			"shadow_essence_min": 30,
			"heroes_min": 2,
		},
		"start_node": "shadow_awakening",
		"nodes": {
			"shadow_awakening": {
				"type": "event",
				"name": "暗影觉醒",
				"desc": "暗影精华开始在你的英雄身上产生共鸣，力量的抉择即将到来。",
				"event_id": "shadow_awakening_event",
				"branch_choice": true,
				"next": ["path_enhancement", "path_corruption"],
				"requires": [],
			},
			"path_enhancement": {
				"type": "quest",
				"name": "强化之路",
				"desc": "通过严格的训练和精华提炼，强化英雄的战斗能力。",
				"quest_id": "chain_shadow_enhance",
				"mutually_exclusive": ["path_corruption"],
				"requires": ["shadow_awakening"],
				"next": ["enhancement_mastery"],
			},
			"path_corruption": {
				"type": "quest",
				"name": "腐化之路",
				"desc": "放任暗影力量侵蚀英雄，换取更强大但危险的能力。",
				"quest_id": "chain_shadow_corrupt",
				"mutually_exclusive": ["path_enhancement"],
				"requires": ["shadow_awakening"],
				"next": ["corruption_mastery"],
			},
			"enhancement_mastery": {
				"type": "quest",
				"name": "精英掌控",
				"desc": "完成最终的精华融合仪式，英雄达到新的境界。",
				"quest_id": "chain_shadow_mastery_enhance",
				"requires": ["path_enhancement"],
				"next": ["shadow_elite_complete"],
			},
			"corruption_mastery": {
				"type": "quest",
				"name": "黑暗支配",
				"desc": "英雄已完全接受暗影腐化，成为无可匹敌的黑暗战士。",
				"quest_id": "chain_shadow_mastery_corrupt",
				"requires": ["path_corruption"],
				"next": ["shadow_elite_complete"],
			},
			"shadow_elite_complete": {
				"type": "reward",
				"name": "暗影精英成就",
				"desc": "你的英雄已经蜕变，成为真正的暗影精英。",
				"reward": {
					"prestige": 100,
					"shadow_essence": -20,
					"flag_set": "shadow_elite_achieved",
					"message": "暗影精英之路已走到终点，你的英雄将永远改变。",
				},
				"requires_any": ["enhancement_mastery", "corruption_mastery"],
				"next": [],
			},
		},
	},

	# ─────────────────────────────────────────────────────────────────
	# 链 3: 海盗同盟（Pirate Alliance）
	# 触发条件: 海盗势力存活，且玩家声望 >= 50
	# 分支: 结盟 / 征服，影响海盗势力的归属
	# ─────────────────────────────────────────────────────────────────
	"pirate_alliance": {
		"name": "海盗同盟",
		"desc": "海盗势力向你伸出了橄榄枝，或许是个机会……",
		"category": "faction_chain",
		"trigger": {
			"pirate_faction_exists": true,
			"prestige_min": 50,
		},
		"start_node": "pirate_contact",
		"nodes": {
			"pirate_contact": {
				"type": "event",
				"name": "海盗接触",
				"desc": "一名海盗使者秘密来访，带来了海盗王的提议。",
				"event_id": "pirate_contact_event",
				"branch_choice": true,
				"next": ["alliance_path", "conquest_path"],
				"requires": [],
			},
			"alliance_path": {
				"type": "quest",
				"name": "结盟之路",
				"desc": "与海盗势力建立秘密同盟，共同对抗光明联盟。",
				"quest_id": "chain_pirate_alliance",
				"mutually_exclusive": ["conquest_path"],
				"requires": ["pirate_contact"],
				"next": ["alliance_pact", "alliance_tribute"],
			},
			"conquest_path": {
				"type": "quest",
				"name": "征服之路",
				"desc": "拒绝合作，武力征服海盗势力，将其纳入麾下。",
				"quest_id": "chain_pirate_conquest",
				"mutually_exclusive": ["alliance_path"],
				"requires": ["pirate_contact"],
				"next": ["conquest_complete"],
			},
			"alliance_pact": {
				"type": "quest",
				"name": "盟约签订",
				"desc": "与海盗王签订正式盟约，确保双方的利益。",
				"quest_id": "chain_pirate_pact",
				"requires": ["alliance_path"],
				"next": ["alliance_complete"],
			},
			"alliance_tribute": {
				"type": "quest",
				"name": "贡品交换",
				"desc": "向海盗势力提供一批物资，以换取他们的信任。",
				"quest_id": "chain_pirate_tribute",
				"requires": ["alliance_path"],
				"next": ["alliance_complete"],
			},
			"alliance_complete": {
				"type": "reward",
				"name": "海盗同盟建立",
				"desc": "海盗势力成为你的盟友，他们的舰队将为你服务。",
				"reward": {
					"gold": 500,
					"prestige": 80,
					"flag_set": "pirate_allied",
					"message": "海盗同盟正式建立！海盗舰队将在海战中支援你。",
				},
				"requires_any": ["alliance_pact", "alliance_tribute"],
				"next": [],
			},
			"conquest_complete": {
				"type": "reward",
				"name": "海盗势力征服",
				"desc": "海盗势力被彻底征服，其财富和船只归你所有。",
				"reward": {
					"gold": 800,
					"prestige": 60,
					"flag_set": "pirate_conquered",
					"message": "海盗势力已被征服！大量战利品落入你的手中。",
				},
				"requires": ["conquest_path"],
				"next": [],
			},
		},
	},

	# ─────────────────────────────────────────────────────────────────
	# 链 4: 古老诅咒（Ancient Curse）
	# 触发条件: 威胁值 >= 60，且已触发过"远古遗迹"事件
	# 多阶段线性链，带有定时失败机制
	# ─────────────────────────────────────────────────────────────────
	"ancient_curse": {
		"name": "古老诅咒",
		"desc": "远古遗迹中发现的文物带来了一个可怕的诅咒……",
		"category": "crisis_chain",
		"trigger": {
			"threat_min": 60,
			"event_triggered": "ancient_ruins",
		},
		"start_node": "curse_manifests",
		"nodes": {
			"curse_manifests": {
				"type": "event",
				"name": "诅咒显现",
				"desc": "远古诅咒开始在你的领地蔓延，必须在10回合内找到解法。",
				"event_id": "curse_manifests_event",
				"next": ["curse_research"],
				"requires": [],
				"time_limit": 10,
			},
			"curse_research": {
				"type": "quest",
				"name": "研究诅咒",
				"desc": "派遣学者研究诅咒的来源和破解方法。",
				"quest_id": "chain_curse_research",
				"requires": ["curse_manifests"],
				"next": ["curse_solution_gate"],
				"time_limit": 8,
			},
			"curse_solution_gate": {
				"type": "gate",
				"name": "解法分析",
				"desc": "根据研究结果，确定最终的破解方案。",
				"condition": {
					"quest_completed": "chain_curse_research",
				},
				"requires": ["curse_research"],
				"branch_choice": true,
				"next": ["ritual_solution", "artifact_solution"],
			},
			"ritual_solution": {
				"type": "quest",
				"name": "古老仪式",
				"desc": "举行一场古老的驱邪仪式来破解诅咒。",
				"quest_id": "chain_curse_ritual",
				"mutually_exclusive": ["artifact_solution"],
				"requires": ["curse_solution_gate"],
				"next": ["curse_broken"],
				"time_limit": 5,
			},
			"artifact_solution": {
				"type": "quest",
				"name": "神器封印",
				"desc": "寻找传说中的封印神器来压制诅咒。",
				"quest_id": "chain_curse_artifact",
				"mutually_exclusive": ["ritual_solution"],
				"requires": ["curse_solution_gate"],
				"next": ["curse_broken"],
				"time_limit": 5,
			},
			"curse_broken": {
				"type": "reward",
				"name": "诅咒破解",
				"desc": "古老诅咒终于被破解，你的领地重获安宁。",
				"reward": {
					"prestige": 150,
					"order_delta": 20,
					"threat_delta": -15,
					"flag_set": "ancient_curse_broken",
					"message": "古老诅咒已被彻底破解！你的威望因此大幅提升。",
				},
				"requires_any": ["ritual_solution", "artifact_solution"],
				"next": [],
			},
		},
	},

	# ─────────────────────────────────────────────────────────────────
	# 链 5: 黑暗议会（Dark Council）
	# 触发条件: 主线任务4完成，且已招募3个中立势力
	# 终局链：影响游戏结局
	# ─────────────────────────────────────────────────────────────────
	"dark_council": {
		"name": "黑暗议会",
		"desc": "是时候召集所有黑暗势力，建立统一的黑暗议会了。",
		"category": "endgame_chain",
		"trigger": {
			"quest_completed": "main_4",
			"neutral_recruited_min": 3,
		},
		"start_node": "council_summons",
		"nodes": {
			"council_summons": {
				"type": "event",
				"name": "议会召集",
				"desc": "你决定召集所有盟友，建立黑暗议会，统一指挥对光明联盟的最终战争。",
				"event_id": "dark_council_summons",
				"next": ["council_military", "council_espionage", "council_economy"],
				"requires": [],
			},
			"council_military": {
				"type": "quest",
				"name": "军事准备",
				"desc": "整合所有盟友的军事力量，为最终决战做准备。",
				"quest_id": "chain_council_military",
				"requires": ["council_summons"],
				"next": ["council_unified"],
			},
			"council_espionage": {
				"type": "quest",
				"name": "情报渗透",
				"desc": "在光明联盟内部安插间谍，获取关键情报。",
				"quest_id": "chain_council_espionage",
				"requires": ["council_summons"],
				"next": ["council_unified"],
			},
			"council_economy": {
				"type": "quest",
				"name": "经济封锁",
				"desc": "切断光明联盟的贸易路线，削弱其战争潜力。",
				"quest_id": "chain_council_economy",
				"requires": ["council_summons"],
				"next": ["council_unified"],
			},
			"council_unified": {
				"type": "gate",
				"name": "议会统一",
				"desc": "黑暗议会的三大支柱均已就位。",
				"condition": {
					"all_completed": ["council_military", "council_espionage", "council_economy"],
				},
				"requires": ["council_military", "council_espionage", "council_economy"],
				"next": ["final_declaration"],
			},
			"final_declaration": {
				"type": "quest",
				"name": "黑暗宣言",
				"desc": "向全大陆宣告黑暗议会的成立，宣战光明联盟。",
				"quest_id": "chain_council_declaration",
				"requires": ["council_unified"],
				"next": ["council_victory"],
			},
			"council_victory": {
				"type": "reward",
				"name": "黑暗议会胜利",
				"desc": "黑暗议会已经建立，最终决战即将开始。",
				"reward": {
					"gold": 1000,
					"prestige": 200,
					"flag_set": "dark_council_formed",
					"unlock_endgame": true,
					"message": "黑暗议会宣告成立！全大陆的黑暗势力将在你的旗帜下汇聚，最终决战已经开始！",
				},
			"requires": ["final_declaration"],
			"next": [],
		},
		},
	},

	# ─────────────────────────────────────────────────────────────────
	# 链 5: 暗潮崛起（Dark Tide Rising）
	# 触发条件: 第 5 回合自动触发
	# 分支: 征服之路 / 阴谋之路，双路线结局 + 终局解锁
	# ─────────────────────────────────────────────────────────────────
	"dark_tide_rising": {
		"name": "暗潮崛起",
		"desc": "黑暗势力在大陆边缘集结，你必须在征服与外交之间做出抉择，决定暗潮的崛起方式。",
		"category": "faction_chain",
		"trigger": {
			"turn_min": 5,
		},
		"start_node": "dtr_prologue",
		"nodes": {
			"dtr_prologue": {
				"type": "event",
				"name": "黑暗的呼唤",
				"desc": "一名神秘使者带来了来自深渊的信息，暗示着大规模行动的时机已到。",
				"event_id": "dtr_prologue_event",
				"requires": [],
				"next": ["dtr_gather_forces"],
			},
			"dtr_gather_forces": {
				"type": "quest",
				"name": "集结暗影军团",
				"desc": "在行动之前，必须先集结足够的军事力量。",
				"quest_id": "chain_dtr_gather",
				"requires": ["dtr_prologue"],
				"next": ["dtr_choose_path"],
			},
			"dtr_choose_path": {
				"type": "gate",
				"name": "抉择时刻",
				"desc": "你的力量已经足够强大，现在必须选择暗潮崛起的方式。",
				"branch_choice": true,
				"requires": ["dtr_gather_forces"],
				"next": ["dtr_conquest", "dtr_intrigue"],
			},
			"dtr_conquest": {
				"type": "quest",
				"name": "铁蹄征途",
				"desc": "率领军团征服邻近的人类领地，彰显暗潮的军事实力。",
				"quest_id": "chain_dtr_conquest",
				"mutually_exclusive": ["dtr_intrigue"],
				"requires": ["dtr_choose_path"],
				"next": ["dtr_endgame"],
			},
			"dtr_intrigue": {
				"type": "quest",
				"name": "暗影外交",
				"desc": "通过外交手段与各势力建立关系，在幕后操控局势。",
				"quest_id": "chain_dtr_intrigue",
				"mutually_exclusive": ["dtr_conquest"],
				"requires": ["dtr_choose_path"],
				"next": ["dtr_endgame"],
			},
			"dtr_endgame": {
				"type": "reward",
				"name": "暗潮崛起",
				"desc": "暗潮已经真正崛起，你的名字将被历史铭记。",
				"requires_any": ["dtr_conquest", "dtr_intrigue"],
				"next": [],
				"reward": {"gold": 2000, "prestige": 500, "shadow_essence": 200},
				"flags": ["dark_tide_chain_completed"],
				"unlock_endgame": true,
			},
		},
	},

	# ─────────────────────────────────────────────────────────────────
	# 链 6: 边境危机（Border Crisis）
	# 触发条件: 威胁值 >= 50
	# 特点: 有失败节点、限时压力、战后处置分支
	# ─────────────────────────────────────────────────────────────────
	"border_crisis": {
		"name": "边境危机",
		"desc": "光明联盟的军队正在边境集结，你必须在有限时间内做出应对。",
		"category": "crisis_chain",
		"trigger": {
			"threat_min": 50,
		},
		"start_node": "bc_warning",
		"nodes": {
			"bc_warning": {
				"type": "event",
				"name": "边境警报",
				"desc": "斥候带来了紧急情报：光明联盟的大军正在向边境推进。",
				"event_id": "bc_warning_event",
				"requires": [],
				"next": ["bc_prepare"],
			},
			"bc_prepare": {
				"type": "quest",
				"name": "紧急备战",
				"desc": "在敌军到来之前，必须迅速加强边境防御。",
				"quest_id": "chain_bc_prepare",
				"time_limit_turns": 5,
				"fail_node": "bc_fail",
				"requires": ["bc_warning"],
				"next": ["bc_battle"],
			},
			"bc_battle": {
				"type": "quest",
				"name": "边境决战",
				"desc": "光明联盟的军队已经到达边境，决战时刻来临。",
				"quest_id": "chain_bc_battle",
				"requires": ["bc_prepare"],
				"next": ["bc_aftermath"],
			},
			"bc_aftermath": {
				"type": "gate",
				"name": "战后处置",
				"desc": "击退了光明联盟的进攻，现在需要决定如何处置战俘和边境领地。",
				"branch_choice": true,
				"requires": ["bc_battle"],
				"next": ["bc_occupy", "bc_negotiate"],
			},
			"bc_occupy": {
				"type": "reward",
				"name": "铁腕统治",
				"desc": "你以铁腕手段处置了战俘，边境领地被纳入暗潮版图。",
				"mutually_exclusive": ["bc_negotiate"],
				"requires": ["bc_aftermath"],
				"next": [],
				"reward": {"gold": 600, "prestige": 200},
				"flags": ["border_crisis_conquest_end"],
			},
			"bc_negotiate": {
				"type": "reward",
				"name": "边境协议",
				"desc": "你与光明联盟签订了边境协议，换取了一段时间的和平。",
				"mutually_exclusive": ["bc_occupy"],
				"requires": ["bc_aftermath"],
				"next": [],
				"reward": {"gold": 400, "prestige": 100},
				"flags": ["border_crisis_peace_end"],
			},
			"bc_fail": {
				"type": "event",
				"name": "边境失守",
				"desc": "由于准备不足，边境被光明联盟突破，你付出了沉重的代价。",
				"event_id": "bc_fail_event",
				"requires": [],
				"next": [],
				"is_failure": true,
			},
		},
	},

	# ─────────────────────────────────────────────────────────────────
	# 链 7: 古老遗迹（Ancient Ruin）
	# 触发条件: 控制领地 >= 4
	# 特点: 并行子任务、parallel_join 门、多阶段解锁
	# ─────────────────────────────────────────────────────────────────
	"ancient_ruin": {
		"name": "古老遗迹的秘密",
		"desc": "在领地深处发现了一处古老的遗迹，其中蕴藏着强大的力量和危险的秘密。",
		"category": "side_chain",
		"trigger": {
			"tiles_min": 4,
		},
		"start_node": "ar_discover",
		"nodes": {
			"ar_discover": {
				"type": "event",
				"name": "发现遗迹",
				"desc": "你的探险队在领地深处发现了一处古老的遗迹。",
				"event_id": "ar_discover_event",
				"requires": [],
				"next": ["ar_explore", "ar_research"],
			},
			"ar_explore": {
				"type": "quest",
				"name": "探索遗迹",
				"desc": "派遣探险队深入遗迹，探索其中的秘密。",
				"quest_id": "chain_ar_explore",
				"parallel_group": "ar_phase2",
				"requires": ["ar_discover"],
				"next": ["ar_join_gate"],
			},
			"ar_research": {
				"type": "quest",
				"name": "研究古文字",
				"desc": "研究遗迹中发现的古代文字，破解其中的秘密。",
				"quest_id": "chain_ar_research",
				"parallel_group": "ar_phase2",
				"requires": ["ar_discover"],
				"next": ["ar_join_gate"],
			},
			"ar_join_gate": {
				"type": "gate",
				"name": "解读遗迹",
				"desc": "探索和研究都已完成，现在可以真正进入遗迹的核心区域了。",
				"gate_type": "parallel_join",
				"parallel_group": "ar_phase2",
				"requires": ["ar_explore", "ar_research"],
				"next": ["ar_core"],
			},
			"ar_core": {
				"type": "quest",
				"name": "遗迹核心",
				"desc": "进入遗迹的核心区域，面对最终的考验。",
				"quest_id": "chain_ar_core",
				"requires": ["ar_join_gate"],
				"next": ["ar_treasure"],
			},
			"ar_treasure": {
				"type": "reward",
				"name": "古老的馈赠",
				"desc": "你成功探索了整个遗迹，获得了古老文明留下的宝藏。",
				"requires": ["ar_core"],
				"next": [],
				"reward": {"gold": 1500, "shadow_essence": 300, "prestige": 300},
				"flags": ["ancient_ruin_completed"],
			},
		},
	},
}

# ═══════════════ 链内嵌任务定义 ═══════════════
## 这些任务由任务链系统自动注册，不在 quest_definitions.gd 中定义。
const CHAIN_QUESTS: Dictionary = {
	# 叛乱链
	"chain_rebellion_suppress": {
		"name": "武力镇压叛军",
		"desc": "消灭所有叛军，重新占领被占据点。",
		"objectives": [
			{"type": "battles_won_min", "value": 2, "label": "赢得2场对叛军的战斗"},
			{"type": "tiles_min", "value": 10, "label": "重新占领至少10个领地"},
		],
		"reward": {"gold": 200, "order_delta": 10},
	},
	"chain_rebellion_negotiate": {
		"name": "外交谈判",
		"desc": "积累足够的金币并与叛军领袖谈判。",
		"objectives": [
			{"type": "gold_min", "value": 500, "label": "准备500金作为谈判筹码"},
		],
		"reward": {"gold": -300, "order_delta": 20},
	},
	"chain_rebellion_stronghold": {
		"name": "重建要塞",
		"desc": "在叛乱发源地建造一座要塞。",
		"objectives": [
			{"type": "building_any", "value": 1, "label": "建造1座要塞建筑"},
		],
		"reward": {"prestige": 30},
	},
	# 暗影精英链
	"chain_shadow_enhance": {
		"name": "精华提炼",
		"desc": "消耗暗影精华，强化英雄属性。",
		"objectives": [
			{"type": "shadow_essence_min", "value": 20, "label": "积累20点暗影精华"},
			{"type": "heroes_min", "value": 2, "label": "拥有2名英雄"},
		],
		"reward": {"shadow_essence": -15, "prestige": 40},
	},
	"chain_shadow_corrupt": {
		"name": "腐化仪式",
		"desc": "举行腐化仪式，让英雄接受暗影力量的侵蚀。",
		"objectives": [
			{"type": "shadow_essence_min", "value": 30, "label": "积累30点暗影精华"},
			{"type": "threat_min", "value": 40, "label": "威胁值达到40"},
		],
		"reward": {"shadow_essence": -20, "threat_delta": 10},
	},
	"chain_shadow_mastery_enhance": {
		"name": "精英融合",
		"desc": "完成最终的精华融合仪式。",
		"objectives": [
			{"type": "battles_won_min", "value": 5, "label": "赢得5场战斗（精英训练）"},
		],
		"reward": {"prestige": 60},
	},
	"chain_shadow_mastery_corrupt": {
		"name": "黑暗支配",
		"desc": "英雄完全接受暗影腐化。",
		"objectives": [
			{"type": "heroes_min", "value": 3, "label": "拥有3名英雄"},
			{"type": "threat_min", "value": 60, "label": "威胁值达到60"},
		],
		"reward": {"prestige": 80, "threat_delta": -5},
	},
	# 海盗链
	"chain_pirate_alliance": {
		"name": "建立海盗联系",
		"desc": "通过外交手段与海盗势力建立初步联系。",
		"objectives": [
			{"type": "prestige_min", "value": 60, "label": "威望达到60"},
		],
		"reward": {"prestige": 30},
	},
	"chain_pirate_pact": {
		"name": "签订盟约",
		"desc": "与海盗王完成正式盟约签订。",
		"objectives": [
			{"type": "gold_min", "value": 400, "label": "准备400金作为盟约礼金"},
		],
		"reward": {"gold": -200, "prestige": 50},
	},
	"chain_pirate_tribute": {
		"name": "贡品交换",
		"desc": "向海盗势力提供一批物资。",
		"objectives": [
			{"type": "iron_min", "value": 50, "label": "准备50铁矿作为贡品"},
			{"type": "food_min", "value": 100, "label": "准备100粮食作为贡品"},
		],
		"reward": {"iron": -30, "food": -60, "prestige": 40},
	},
	"chain_pirate_conquest": {
		"name": "征服海盗",
		"desc": "武力征服海盗势力。",
		"objectives": [
			{"type": "battles_won_min", "value": 3, "label": "击败海盗军队3次"},
			{"type": "strongholds_min", "value": 1, "label": "占领1座海盗据点"},
		],
		"reward": {"gold": 400, "prestige": 50},
	},
	# 诅咒链
	"chain_curse_research": {
		"name": "研究古老诅咒",
		"desc": "派遣学者深入研究诅咒的来源。",
		"objectives": [
			{"type": "gold_min", "value": 200, "label": "投入200金用于研究"},
			{"type": "heroes_min", "value": 1, "label": "派遣1名英雄协助研究"},
		],
		"reward": {"gold": -100, "prestige": 20},
	},
	"chain_curse_ritual": {
		"name": "古老驱邪仪式",
		"desc": "举行古老的驱邪仪式。",
		"objectives": [
			{"type": "shadow_essence_min", "value": 10, "label": "准备10点暗影精华"},
			{"type": "order_min", "value": 30, "label": "秩序值维持在30以上"},
		],
		"reward": {"shadow_essence": -10, "order_delta": 15},
	},
	"chain_curse_artifact": {
		"name": "寻找封印神器",
		"desc": "在遗迹中寻找传说中的封印神器。",
		"objectives": [
			{"type": "battles_won_min", "value": 2, "label": "探索遗迹（战斗2次）"},
			{"type": "iron_min", "value": 80, "label": "积累80铁矿用于神器修复"},
		],
		"reward": {"iron": -50, "prestige": 40},
	},
	# 黑暗议会链
	"chain_council_military": {
		"name": "整合军事力量",
		"desc": "整合所有盟友的军队，建立统一指挥体系。",
		"objectives": [
			{"type": "army_count_min", "value": 4, "label": "拥有4支军团"},
			{"type": "heroes_min", "value": 3, "label": "拥有3名英雄"},
		],
		"reward": {"prestige": 50},
	},
	"chain_council_espionage": {
		"name": "情报渗透行动",
		"desc": "在光明联盟内部安插间谍。",
		"objectives": [
			{"type": "gold_min", "value": 600, "label": "投入600金用于情报工作"},
			{"type": "tiles_min", "value": 20, "label": "控制20个领地以建立情报网"},
		],
		"reward": {"gold": -300, "prestige": 60},
	},
	"chain_council_economy": {
		"name": "经济封锁行动",
		"desc": "切断光明联盟的贸易路线。",
		"objectives": [
			{"type": "strongholds_min", "value": 2, "label": "占领2座要塞切断贸易"},
			{"type": "harbor_min", "value": 1, "label": "控制1座港口"},
		],
		"reward": {"gold": 200, "prestige": 40},
	},
	"chain_council_declaration": {
		"name": "黑暗宣言",
		"desc": "向全大陆宣告黑暗议会的成立。",
		"objectives": [
			{"type": "tiles_min", "value": 30, "label": "控制30个领地"},
			{"type": "threat_min", "value": 70, "label": "威胁值达到70"},
		],
		"reward": {"prestige": 100, "gold": 500},
	},
	# ─────────────────────────────────────────────────────────────────
	# 暗潮崛起链内嵌任务
	# ─────────────────────────────────────────────────────────────────
	"chain_dtr_gather": {
		"name": "集结暗影军团",
		"desc": "在大规模行动之前，必须先集结足够的军事力量和领地。",
		"objectives": [
			{"type": "army_count_min", "value": 30, "label": "拥有至少 30 支军队"},
			{"type": "tiles_min", "value": 3, "label": "控制至少 3 块领地"},
		],
		"reward": {"gold": 200, "prestige": 50},
	},
	"chain_dtr_conquest": {
		"name": "铁蹄征途",
		"desc": "率领军团征服邻近的人类领地，彰显暗潮的军事实力。",
		"objectives": [
			{"type": "battles_won_min", "value": 3, "label": "赢得3场战斗"},
			{"type": "tiles_min", "value": 6, "label": "控制至少 6 块领地"},
		],
		"reward": {"gold": 500, "army": 20, "prestige": 100},
	},
	"chain_dtr_intrigue": {
		"name": "暗影外交",
		"desc": "通过外交手段与各势力建立关系，在幕后操控局势。",
		"objectives": [
			{"type": "diplomacy_count", "value": 2, "label": "完成 2 次外交行动"},
			{"type": "gold_min", "value": 500, "label": "积累 500 金币"},
		],
		"reward": {"gold": 800, "prestige": 80},
	},
	# ─────────────────────────────────────────────────────────────────
	# 边境危机链内嵌任务
	# ─────────────────────────────────────────────────────────────────
	"chain_bc_prepare": {
		"name": "紧急备战",
		"desc": "在敌军到来之前，必须迅速加强边境防御。",
		"objectives": [
			{"type": "army_count_min", "value": 50, "label": "集结至少 50 支军队"},
			{"type": "building_exists", "value": "fortress", "label": "建造一座要塞"},
		],
		"reward": {"prestige": 80},
	},
	"chain_bc_battle": {
		"name": "边境决战",
		"desc": "光明联盟的军队已经到达边境，决战时刻来临。",
		"objectives": [
			{"type": "battles_won_min", "value": 1, "label": "击退光明联盟的进攻"},
		],
		"reward": {"gold": 300, "prestige": 150},
	},
	# ─────────────────────────────────────────────────────────────────
	# 古老遗迹链内嵌任务
	# ─────────────────────────────────────────────────────────────────
	"chain_ar_explore": {
		"name": "探索遗迹",
		"desc": "派遣探险队深入遗迹，探索其中的秘密。",
		"objectives": [
			{"type": "action_done", "action": "explore", "value": 3, "label": "完成 3 次探索行动"},
		],
		"reward": {"gold": 200, "shadow_essence": 50},
	},
	"chain_ar_research": {
		"name": "研究古文字",
		"desc": "研究遗迹中发现的古代文字，破解其中的秘密。",
		"objectives": [
			{"type": "research_done", "value": 1, "label": "完成 1 次研究行动"},
		],
		"reward": {"prestige": 50},
	},
	"chain_ar_core": {
		"name": "遗迹核心",
		"desc": "进入遗迹的核心区域，面对最终的考验。",
		"objectives": [
			{"type": "battles_won_min", "value": 1, "label": "击败遗迹守卫"},
		],
		"reward": {"gold": 400, "shadow_essence": 100},
	},
}
