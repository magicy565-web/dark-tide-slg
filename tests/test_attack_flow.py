#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
暗潮 SLG — 攻击流程完整性测试
Attack Flow Integration Test

测试目标：
  1. CombatSystem.resolve_battle 的输入/输出结构完整性
  2. GameManager.action_attack_with_army 的调用链完整性
  3. 海盗阵营引导通知（PirateOnboarding）在战斗流程中的集成
  4. 战斗结果信号（EventBus）的发射路径
  5. QuestJournal 统计更新路径（battles_won）
  6. 掠夺收入路径（PirateMechanic.apply_plunder）
  7. 关键依赖项（autoloads）是否全部注册
"""

import os
import re
import sys
from pathlib import Path

ROOT = Path("/home/ubuntu/dark-tide-slg")
PASS = 0
FAIL = 0
RESULTS = []

def check(name: str, condition: bool, detail: str = ""):
    global PASS, FAIL
    status = "PASS" if condition else "FAIL"
    if condition:
        PASS += 1
    else:
        FAIL += 1
    msg = f"  [{status}] {name}"
    if not condition and detail:
        msg += f"\n         → {detail}"
    RESULTS.append(msg)
    print(msg)

def read(path: str) -> str:
    p = ROOT / path
    if not p.exists():
        return ""
    return p.read_text(encoding="utf-8")

def grep(path: str, pattern: str) -> bool:
    content = read(path)
    return bool(re.search(pattern, content))

def grep_all(path: str, patterns: list) -> tuple:
    content = read(path)
    missing = [p for p in patterns if not re.search(p, content)]
    return len(missing) == 0, missing

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: 文件存在性检查
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 1: 文件存在性检查")
print("="*60)

files_required = [
    "autoloads/game_manager.gd",
    "autoloads/event_bus.gd",
    "systems/combat/combat_system.gd",
    "systems/faction/pirate_mechanic.gd",
    "systems/tutorial/pirate_onboarding.gd",
    "systems/quest/pirate_quest_guide.gd",
    "systems/quest/quest_journal.gd",
    "scenes/ui/panels/pirate_panel.gd",
    "autoloads/save_manager.gd",
    "project.godot",
]
for f in files_required:
    exists = (ROOT / f).exists()
    check(f"文件存在: {f}", exists, f"文件缺失: {ROOT / f}")

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: Autoload 注册检查
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 2: Autoload 注册检查 (project.godot)")
print("="*60)

project_godot = read("project.godot")
autoloads_required = [
    ("GameManager",      r'GameManager\s*='),
    ("EventBus",         r'EventBus\s*='),
    ("QuestJournal",     r'QuestJournal\s*='),
    ("PirateMechanic",   r'PirateMechanic\s*='),
    ("PirateOnboarding", r'PirateOnboarding\s*='),
    ("SaveManager",      r'SaveManager\s*='),
    ("HeroSystem",       r'HeroSystem\s*='),
    ("ResourceManager",  r'ResourceManager\s*='),
]
for name, pattern in autoloads_required:
    check(f"Autoload 注册: {name}", bool(re.search(pattern, project_godot)),
          f"project.godot 中未找到 {name} 的 autoload 注册")

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: EventBus 信号完整性检查
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 3: EventBus 信号完整性检查")
print("="*60)

event_bus = read("autoloads/event_bus.gd")
signals_required = [
    ("combat_started",           r'signal combat_started'),
    ("combat_result",            r'signal combat_result'),
    ("combat_result_detailed",   r'signal combat_result_detailed'),
    ("tutorial_combat_done",     r'signal tutorial_combat_done'),
    ("infamy_changed",           r'signal infamy_changed'),
    ("rum_morale_changed",       r'signal rum_morale_changed'),
    ("hero_recruited",           r'signal hero_recruited'),
    ("resources_changed",        r'signal resources_changed'),
    ("message_log",              r'signal message_log'),
    ("quest_journal_updated",    r'signal quest_journal_updated'),
    ("tutorial_quest_done",      r'signal tutorial_quest_done'),
]
for name, pattern in signals_required:
    check(f"信号声明: {name}", bool(re.search(pattern, event_bus)),
          f"event_bus.gd 中未找到 signal {name}")

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: CombatSystem.resolve_battle 输入/输出结构
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 4: CombatSystem.resolve_battle 结构检查")
print("="*60)

combat_sys = read("systems/combat/combat_system.gd")

check("resolve_battle 方法存在",
      bool(re.search(r'func resolve_battle\(', combat_sys)))

check("resolve_battle 返回 winner 键",
      bool(re.search(r'"winner"', combat_sys)),
      "返回字典中缺少 winner 键")

check("resolve_battle 返回 attacker_losses 键",
      bool(re.search(r'"attacker_losses"', combat_sys)),
      "返回字典中缺少 attacker_losses 键")

check("resolve_battle 返回 defender_losses 键",
      bool(re.search(r'"defender_losses"', combat_sys)),
      "返回字典中缺少 defender_losses 键")

check("player_controlled 标志存在（防止测试阻塞）",
      bool(re.search(r'var player_controlled', combat_sys)),
      "player_controlled 标志缺失，人类玩家战斗会阻塞")

check("MAX_ROUNDS 常量定义",
      bool(re.search(r'const MAX_ROUNDS', combat_sys)))

check("_build_battle_units 方法存在",
      bool(re.search(r'func _build_battle_units', combat_sys)))

check("_check_battle_end 方法存在",
      bool(re.search(r'func _check_battle_end', combat_sys)))

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5: GameManager 攻击流程关键路径
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 5: GameManager 攻击流程关键路径")
print("="*60)

gm = read("autoloads/game_manager.gd")

check("action_attack_with_army 方法存在",
      bool(re.search(r'func action_attack_with_army', gm)))

check("_resolve_army_combat 方法存在",
      bool(re.search(r'func _resolve_army_combat', gm)))

check("攻击前 AP 检查",
      bool(re.search(r'player\["ap"\]\s*<\s*1', gm)),
      "缺少 AP < 1 检查，玩家可能无限攻击")

check("攻击前邻接检查",
      bool(re.search(r'get_army_attackable_tiles', gm)),
      "缺少邻接格子检查")

check("战斗结果信号 combat_result 发射",
      bool(re.search(r'EventBus\.combat_result\.emit', gm)),
      "缺少 combat_result 信号发射")

check("战斗结果信号 combat_result_detailed 发射",
      bool(re.search(r'EventBus\.combat_result_detailed\.emit', gm)),
      "缺少 combat_result_detailed 信号发射")

check("tutorial_combat_done 信号发射",
      bool(re.search(r'EventBus\.tutorial_combat_done\.emit', gm)),
      "缺少 tutorial_combat_done 信号，引导系统无法感知战斗")

check("_record_battle_stat 调用（QuestJournal battles_won 更新）",
      bool(re.search(r'_record_battle_stat\(', gm)),
      "缺少 _record_battle_stat 调用，battles_won 统计不会更新")

check("海盗阵营朗姆酒加成应用",
      bool(re.search(r'PirateMechanic\.apply_rum_bonus_to_units', gm)),
      "缺少 PirateMechanic.apply_rum_bonus_to_units 调用")

check("战斗胜利后 _capture_tile 调用",
      bool(re.search(r'_capture_tile\(', gm)),
      "缺少 _capture_tile 调用，胜利后无法占领格子")

check("战斗胜利后英雄经验授予",
      bool(re.search(r'_grant_hero_combat_exp', gm)),
      "缺少 _grant_hero_combat_exp 调用")

check("战斗后零兵士清理",
      bool(re.search(r'surviving_troops', gm)),
      "缺少零兵士清理逻辑，可能产生僵尸部队")

check("港口占领通知 PirateOnboarding",
      bool(re.search(r'PirateOnboarding.*notify_harbor_captured|notify_harbor_captured.*PirateOnboarding', gm)),
      "港口占领后未通知 PirateOnboarding，引导步骤无法推进")

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6: PirateOnboarding 引导系统集成
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 6: PirateOnboarding 引导系统集成")
print("="*60)

onboarding = read("systems/tutorial/pirate_onboarding.gd")

check("PirateOnboarding extends CanvasLayer（非 Node）",
      bool(re.search(r'extends CanvasLayer', onboarding)),
      "extends Node 不支持 layer 属性赋值，会导致运行时错误")

check("start_onboarding 方法存在",
      bool(re.search(r'func start_onboarding', onboarding)))

check("stop_onboarding 方法存在",
      bool(re.search(r'func stop_onboarding', onboarding)))

check("to_save_data 方法存在（存档支持）",
      bool(re.search(r'func to_save_data', onboarding)))

check("from_save_data 方法存在（读档支持）",
      bool(re.search(r'func from_save_data', onboarding)))

check("notify_market_item_bought 方法存在",
      bool(re.search(r'func notify_market_item_bought', onboarding)))

check("notify_treasure_explored 方法存在",
      bool(re.search(r'func notify_treasure_explored', onboarding)))

check("notify_merc_hired 方法存在",
      bool(re.search(r'func notify_merc_hired', onboarding)))

check("notify_harbor_captured 方法存在",
      bool(re.search(r'func notify_harbor_captured', onboarding)))

check("_on_combat_result 信号处理存在",
      bool(re.search(r'_on_combat_result', onboarding)),
      "缺少 combat_result 信号处理，战斗胜利无法推进引导")

check("_on_infamy_changed 信号处理存在",
      bool(re.search(r'_on_infamy_changed', onboarding)))

check("_on_rum_morale_changed 信号处理存在",
      bool(re.search(r'_on_rum_morale_changed', onboarding)))

_step_count = len(re.findall(r'"id":\s*"pirate_', onboarding))
check("STEPS 数组包含 11 个步骤",
      _step_count >= 11,
      f"STEPS 中找到 {_step_count} 个步骤，期望 ≥ 11")

# GameManager 中启动引导的调用
check("GameManager 在海盗阵营开始时调用 start_onboarding",
      bool(re.search(r'PirateOnboarding.*start_onboarding|start_onboarding.*PirateOnboarding', gm)),
      "GameManager 未调用 PirateOnboarding.start_onboarding()")

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7: QuestJournal 引导任务集成
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 7: QuestJournal 引导任务集成")
print("="*60)

qj = read("systems/quest/quest_journal.gd")

check("_guide_progress 状态变量存在",
      bool(re.search(r'_guide_progress', qj)),
      "缺少 _guide_progress 字典，引导任务无法追踪")

check("_check_guide_quests 方法存在",
      bool(re.search(r'func _check_guide_quests', qj)))

check("_complete_guide_quest 方法存在",
      bool(re.search(r'func _complete_guide_quest', qj)))

check("tick 中调用 _check_guide_quests",
      bool(re.search(r'_check_guide_quests\(', qj)),
      "tick 未调用 _check_guide_quests，引导任务不会自动推进")

check("prev_guide_done 触发器支持",
      bool(re.search(r'prev_guide_done', qj)),
      "缺少 prev_guide_done 触发器，引导任务链无法串联")

check("rum_morale_min 目标类型支持",
      bool(re.search(r'rum_morale_min', qj)))

check("smuggle_routes_min 目标类型支持",
      bool(re.search(r'smuggle_routes_min', qj)))

check("mercenary_hired_min 目标类型支持",
      bool(re.search(r'mercenary_hired_min', qj)))

check("increment_stat 方法存在（外部统计更新）",
      bool(re.search(r'func increment_stat', qj)))

check("get_all_quests 返回 guide 类型任务",
      bool(re.search(r'"category":\s*"guide"', qj)),
      "get_all_quests 未输出 category=guide，QuestProgressTracker 无法识别")

check("to_save_data 包含 guide_progress",
      bool(re.search(r'guide_progress', qj)),
      "存档中未包含 guide_progress，引导进度不会持久化")

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8: PirateQuestGuide 数据完整性
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 8: PirateQuestGuide 数据完整性")
print("="*60)

pqg = read("systems/quest/pirate_quest_guide.gd")

check("GUIDE_QUESTS 常量定义",
      bool(re.search(r'const GUIDE_QUESTS', pqg)))

check("10 个引导任务定义（pirate_g1~g10）",
      all(bool(re.search(rf'"pirate_g{i}"', pqg)) for i in range(1, 11)),
      f"缺少部分引导任务 ID")

check("所有任务有 objectives 字段",
      len(re.findall(r'"objectives"', pqg)) >= 10,
      "部分任务缺少 objectives 字段")

check("所有任务有 reward 字段",
      len(re.findall(r'"reward"', pqg)) >= 10,
      "部分任务缺少 reward 字段")

check("所有任务有 hint 字段",
      len(re.findall(r'"hint"', pqg)) >= 10,
      "部分任务缺少 hint 字段")

check("pirate_g2~g10 有 prev_guide_done 触发器",
      len(re.findall(r'"prev_guide_done"', pqg)) >= 9,
      "部分任务缺少 prev_guide_done 触发器，任务链无法串联")

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 9: pirate_panel.gd 集成检查
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 9: pirate_panel.gd 集成检查")
print("="*60)

pp = read("scenes/ui/panels/pirate_panel.gd")

check("_on_buy_market 通知 PirateOnboarding",
      bool(re.search(r'notify_market_item_bought', pp)),
      "_on_buy_market 未通知 PirateOnboarding")

check("_on_buy_market 更新 QuestJournal 统计",
      bool(re.search(r'increment_stat.*black_market_trades|black_market_trades.*increment_stat', pp)),
      "_on_buy_market 未调用 QuestJournal.increment_stat")

check("_on_explore_treasure 通知 PirateOnboarding",
      bool(re.search(r'notify_treasure_explored', pp)))

check("_on_explore_treasure 更新 QuestJournal 统计",
      bool(re.search(r'increment_stat.*treasure_maps|treasure_maps.*increment_stat', pp)))

check("_on_hire_merc 通知 PirateOnboarding",
      bool(re.search(r'notify_merc_hired', pp)))

check("_on_hire_merc 更新 QuestJournal 统计",
      bool(re.search(r'increment_stat.*mercenary_hired|mercenary_hired.*increment_stat', pp)))

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 10: SaveManager 集成检查
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 10: SaveManager 集成检查")
print("="*60)

sm = read("autoloads/save_manager.gd")

check("SaveManager 存档包含 pirate_onboarding",
      bool(re.search(r'pirate_onboarding', sm)),
      "SaveManager 未序列化 PirateOnboarding 状态")

check("SaveManager 读档恢复 pirate_onboarding",
      len(re.findall(r'pirate_onboarding', sm)) >= 2,
      "SaveManager 只有存档或只有读档，未完整实现双向序列化")

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 11: 攻击流程模拟（逻辑验证）
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print("  SECTION 11: 攻击流程逻辑模拟")
print("="*60)

# 模拟 CombatSystem.resolve_battle 的核心逻辑（Python 重现）
def simulate_combat(attacker_soldiers: int, attacker_atk: int, attacker_def: int,
                    defender_soldiers: int, defender_atk: int, defender_def: int,
                    max_rounds: int = 8) -> dict:
    """简化版战斗模拟，验证数值逻辑"""
    att_hp = attacker_soldiers
    def_hp = defender_soldiers
    rounds = 0
    for r in range(max_rounds):
        rounds += 1
        # 攻方攻击
        dmg_to_def = max(1, attacker_atk - defender_def // 2)
        def_hp -= dmg_to_def
        if def_hp <= 0:
            return {"winner": "attacker", "rounds": rounds,
                    "att_remaining": att_hp, "def_remaining": 0}
        # 守方攻击
        dmg_to_att = max(1, defender_atk - attacker_def // 2)
        att_hp -= dmg_to_att
        if att_hp <= 0:
            return {"winner": "defender", "rounds": rounds,
                    "att_remaining": 0, "def_remaining": def_hp}
    # 超时：守方获胜
    return {"winner": "defender", "rounds": rounds,
            "att_remaining": att_hp, "def_remaining": def_hp}

# 测试 1: 强攻方应该获胜
r1 = simulate_combat(50, 10, 8, 20, 5, 4)
check("模拟战斗: 强攻方（50兵/ATK10）应胜弱守方（20兵/ATK5）",
      r1["winner"] == "attacker",
      f"结果: {r1}")

# 测试 2: 弱攻方应该失败
r2 = simulate_combat(10, 4, 3, 50, 8, 6)
check("模拟战斗: 弱攻方（10兵/ATK4）应败强守方（50兵/ATK8）",
      r2["winner"] == "defender",
      f"结果: {r2}")

# 测试 3: 超时应守方获胜
r3 = simulate_combat(30, 5, 20, 30, 5, 20)  # 双方防御极高，伤害极低
check("模拟战斗: 超时（双方高防御）应守方获胜",
      r3["winner"] == "defender",
      f"结果: {r3}")

# 测试 4: 海盗朗姆酒加成（ATK+2）应影响战斗结果
r4_no_rum = simulate_combat(15, 6, 5, 20, 6, 5)
r4_with_rum = simulate_combat(15, 8, 5, 20, 6, 5)  # ATK+2 朗姆酒加成
check("模拟战斗: 朗姆酒加成（ATK+2）应改善战斗结果",
      r4_with_rum["rounds"] <= r4_no_rum["rounds"] or r4_with_rum["winner"] == "attacker",
      f"无加成: {r4_no_rum}, 有加成: {r4_with_rum}")

# 测试 5: AP 消耗验证（每次攻击 -1 AP）
check("AP 消耗逻辑: action_attack_with_army 消耗 1 AP",
      bool(re.search(r'player\["ap"\]\s*-=\s*1', gm)),
      "未找到 player[\"ap\"] -= 1 的 AP 消耗逻辑")

# 测试 6: 战斗后零兵清理
check("零兵士清理: 战斗后移除 soldiers=0 的部队",
      bool(re.search(r'surviving_troops.*append|append.*surviving_troops', gm)),
      "未找到零兵士清理逻辑")

# ═══════════════════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
print("\n" + "="*60)
print(f"  测试结果: {PASS} 通过 / {FAIL} 失败 / {PASS+FAIL} 总计")
print("="*60)

if FAIL > 0:
    print("\n  失败项目:")
    for r in RESULTS:
        if "[FAIL]" in r:
            print(r)

print()
sys.exit(0 if FAIL == 0 else 1)
