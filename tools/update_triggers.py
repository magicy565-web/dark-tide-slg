#!/usr/bin/env python3
"""
Batch update story event triggers for all 16 character data files.
Replaces simple linear prev_event chains with proper gameplay thresholds.
"""

import re
import os

DATA_DIR = os.path.join(os.path.dirname(__file__), '..', 'systems', 'story', 'data')

# ═══════════════════════════════════════════════════════════════
# TRIGGER DEFINITIONS PER CHARACTER
# ═══════════════════════════════════════════════════════════════
# Format: { hero_id: { route: [ (event_index, trigger_dict), ... ] } }
# event_index 0 = first event in route

# ── Main heroines: training route (4 stages) ──
# Stage 01: captured immediately
# Stage 02: corruption >= 2, turn+3
# Stage 03: corruption >= 4, turn+6
# Stage 04: corruption >= 7, turn+10

# ── Main heroines: pure_love route (4 stages) ──
# Stage 01: recruited immediately
# Stage 02: affection >= 3, turn+3
# Stage 03: affection >= 5, turn+6
# Stage 04: affection >= 8, turn+10

MAIN_TRAINING = [
    (0, '{"hero_captured": true}'),
    (1, '{"prev_event": "{hero}_training_01", "corruption_min": 2, "turn_min": 3}'),
    (2, '{"prev_event": "{hero}_training_02", "corruption_min": 4, "turn_min": 6}'),
    (3, '{"prev_event": "{hero}_training_03", "corruption_min": 7, "turn_min": 10}'),
]

MAIN_PURE_LOVE = [
    (0, '{"hero_recruited": true}'),
    (1, '{"prev_event": "{hero}_pure_love_01", "affection_min": 3, "turn_min": 3}'),
    (2, '{"prev_event": "{hero}_pure_love_02", "affection_min": 5, "turn_min": 6}'),
    (3, '{"prev_event": "{hero}_pure_love_03", "affection_min": 8, "turn_min": 10}'),
]

MAIN_HEROES = [
    'rin', 'yukino', 'momiji', 'hyouka', 'suirei',
    'gekka', 'hakagure', 'sou', 'shion', 'homura'
]

# ── Neutral heroines: hostile route (13 events for most, up to 15 for mei) ──
# Hostile: progressive threat + turn requirements
# Events spread across invasion phases

def gen_hostile_triggers(hero, count):
    triggers = []
    for i in range(count):
        if i == 0:
            triggers.append((i, '{}'))  # First event: no condition
        else:
            turn = 2 + i * 2  # turns 4, 6, 8, ...
            threat = min(10 + i * 5, 60)  # threat 15, 20, 25, ... cap 60
            prev_id = f"{hero}_hostile_{i:02d}"
            triggers.append((i, f'{{"prev_event": "{prev_id}", "turn_min": {turn}, "threat_min": {threat}}}'))
    return triggers


def gen_neutral_triggers(hero, count):
    """Neutral route: affection + turn gates for quest chain progression"""
    triggers = []
    for i in range(count):
        if i == 0:
            triggers.append((i, '{}'))
        else:
            turn = 3 + i * 2
            affection = min(1 + i, 8)  # gradual affection requirement
            prev_id = f"{hero}_neutral_{i:02d}"
            triggers.append((i, f'{{"prev_event": "{prev_id}", "affection_min": {affection}, "turn_min": {turn}}}'))
    return triggers


def gen_friendly_triggers(hero, count):
    """Friendly route: affection-gated with earlier progression"""
    triggers = []
    for i in range(count):
        if i == 0:
            triggers.append((i, '{"hero_recruited": true}'))
        else:
            turn = 2 + i * 2
            affection = min(2 + i, 9)
            prev_id = f"{hero}_friendly_{i:02d}"
            triggers.append((i, f'{{"prev_event": "{prev_id}", "affection_min": {affection}, "turn_min": {turn}}}'))
    return triggers


# ═══════════════════════════════════════════════════════════════
# FILE PROCESSING
# ═══════════════════════════════════════════════════════════════

def count_events_in_route(content, route_name):
    """Count how many events exist in a given route section."""
    # Find the route array
    pattern = rf'"{route_name}"\s*:\s*\['
    match = re.search(pattern, content)
    if not match:
        return 0
    # Count event IDs in this route
    start = match.end()
    # Find matching close bracket
    bracket_depth = 1
    pos = start
    event_count = 0
    while pos < len(content) and bracket_depth > 0:
        if content[pos] == '[':
            bracket_depth += 1
        elif content[pos] == ']':
            bracket_depth -= 1
        elif content[pos:pos+4] == '"id"':
            event_count += 1
        pos += 1
    return event_count


def update_trigger_in_content(content, event_id, new_trigger_str):
    """Replace the trigger dict for a specific event ID."""
    # Find the event ID in the file
    id_pattern = rf'"id":\s*"{re.escape(event_id)}"'
    id_match = re.search(id_pattern, content)
    if not id_match:
        print(f"  WARNING: Event ID '{event_id}' not found")
        return content

    # Find the trigger dict after this ID
    search_start = id_match.end()
    trigger_pattern = r'"trigger":\s*\{[^}]*\}'
    trigger_match = re.search(trigger_pattern, content[search_start:search_start+500])
    if not trigger_match:
        print(f"  WARNING: No trigger found for '{event_id}'")
        return content

    abs_start = search_start + trigger_match.start()
    abs_end = search_start + trigger_match.end()

    new_trigger = f'"trigger": {new_trigger_str}'
    content = content[:abs_start] + new_trigger + content[abs_end:]
    return content


def process_main_hero(hero):
    filepath = os.path.join(DATA_DIR, f'{hero}_story.gd')
    if not os.path.exists(filepath):
        print(f"SKIP: {filepath} not found")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    print(f"Processing {hero}...")

    # Training route
    for idx, trigger_template in MAIN_TRAINING:
        event_id = f"{hero}_training_{idx+1:02d}"
        trigger_str = trigger_template.replace('{hero}', hero)
        content = update_trigger_in_content(content, event_id, trigger_str)

    # Pure love route
    for idx, trigger_template in MAIN_PURE_LOVE:
        event_id = f"{hero}_pure_love_{idx+1:02d}"
        trigger_str = trigger_template.replace('{hero}', hero)
        content = update_trigger_in_content(content, event_id, trigger_str)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"  Updated {hero}_story.gd")


def process_neutral_hero(hero):
    filepath = os.path.join(DATA_DIR, f'{hero}_story.gd')
    if not os.path.exists(filepath):
        print(f"SKIP: {filepath} not found")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    print(f"Processing neutral: {hero}...")

    # Check which routes exist
    for route in ['hostile', 'neutral', 'friendly']:
        count = count_events_in_route(content, route)
        if count == 0:
            continue

        print(f"  Route '{route}': {count} events")

        if route == 'hostile':
            triggers = gen_hostile_triggers(hero, count)
        elif route == 'neutral':
            triggers = gen_neutral_triggers(hero, count)
        elif route == 'friendly':
            triggers = gen_friendly_triggers(hero, count)

        for idx, trigger_str in triggers:
            event_id = f"{hero}_{route}_{idx+1:02d}"
            content = update_trigger_in_content(content, event_id, trigger_str)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"  Updated {hero}_story.gd")


NEUTRAL_HEROES = ['hibiki', 'sara', 'mei', 'kaede', 'akane', 'hanabi']

if __name__ == '__main__':
    print("=== Updating trigger conditions ===\n")

    for hero in MAIN_HEROES:
        process_main_hero(hero)

    print()

    for hero in NEUTRAL_HEROES:
        process_neutral_hero(hero)

    print("\nDone!")
