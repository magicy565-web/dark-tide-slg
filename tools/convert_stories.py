#!/usr/bin/env python3
"""Convert Dark Tide SLG markdown story files into GDScript data files."""
import re
import sys
import os

# Character mappings: (file_number, hero_id, main_speaker, routes)
MAIN_CHARACTERS = [
    ("01", "rin", "凛", ["training", "pure_love"]),
    ("02", "yukino", "雪乃", ["training", "pure_love"]),
    ("03", "momiji", "红叶", ["training", "pure_love"]),
    ("04", "hyouka", "冰華", ["training", "pure_love"]),
    ("05", "suirei", "翠玲", ["training", "pure_love"]),
    ("06", "gekka", "月華", ["training", "pure_love"]),
    ("07", "hakagure", "叶隐", ["training", "pure_love"]),
    ("08", "sou", "蒼", ["training", "pure_love"]),
    ("09", "shion", "紫苑", ["training", "pure_love"]),
    ("10", "homura", "焔", ["training", "pure_love"]),
]

# Map Chinese route section headers to route keys
ROUTE_HEADERS = {
    "调教路线": "training",
    "纯爱路线": "pure_love",
    "驯服": "training",
    "纯爱": "pure_love",
    "调教": "training",
    "敌对路线": "hostile",
    "敌对": "hostile",
    "中立路线": "neutral",
    "中立": "neutral",
    "友好路线": "friendly",
    "友好": "friendly",
}

# Map event prefix keywords to route keys
EVENT_PREFIX_TO_ROUTE = {
    "调教": "training",
    "纯爱": "pure_love",
    "敌对": "hostile",
    "中立": "neutral",
    "友好": "friendly",
    "事件": None,  # Use current_route
    "特殊事件": None,
}


NEUTRAL_CHARACTERS = [
    ("13", "hibiki", "響", ["hostile", "neutral"]),
    ("14", "sara", "沙罗", ["hostile", "friendly", "neutral"]),
    ("15", "mei", "冥", ["hostile", "neutral"]),
    ("16", "kaede", "枫", ["hostile", "friendly", "neutral"]),
    ("17", "akane", "朱音", ["hostile", "neutral"]),
    ("18", "hanabi", "花火", ["hostile", "neutral"]),
]


def escape_gdscript(s):
    """Escape a string for GDScript."""
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\n", "\\n")
    return s


def strip_md_formatting(text):
    """Remove markdown formatting like * for italics, ** for bold."""
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
    text = re.sub(r'\*(.+?)\*', r'\1', text)
    text = text.strip()
    return text


def parse_markdown(filepath):
    """Parse a markdown story file into structured route/event data."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.split("\n")
    routes = {}
    current_route = None
    current_event = None
    current_event_route = None  # Track which route the current event belongs to
    current_section = None  # "scene", "dialogue", "h_event", "system"
    events_by_route = {}

    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Detect route headers (## 一、调教路线 or ## 二、纯爱路线)
        route_match = re.match(r'^##\s+[一二三四五六七八九十]+[、．.]\s*(.+?)(?:（.*）)?$', stripped)
        if route_match:
            route_title = route_match.group(1).strip()
            # Flush pending event before switching route
            if current_event and current_event_route and current_event_route in events_by_route:
                events_by_route[current_event_route].append(current_event)
                current_event = None
            # Determine route key
            for key_word, route_key in ROUTE_HEADERS.items():
                if key_word in route_title:
                    current_route = route_key
                    if current_route not in events_by_route:
                        events_by_route[current_route] = []
                    break
            i += 1
            continue

        # Detect event headers - multiple formats:
        # Format A: ### 调教 Stage 01: 抵抗（绝望的反抗）
        # Format B: ### 敌对 事件 01: 烽烟初起
        # Format C: ### 事件01：矿山入口——地雷的欢迎
        event_match = re.match(r'^###\s+(.+?)(?:Stage|事件)\s*(\d+)\s*[:：]\s*(.+)', stripped)
        if not event_match:
            event_match = re.match(r'^###\s+(.+?)\s*(\d+)\s*[:：]\s*(.+)', stripped)
        if not event_match:
            # Format C: ### 事件01：title (no space between 事件 and number)
            event_match = re.match(r'^###\s+(事件)(\d+)\s*[:：]\s*(.+)', stripped)
        if event_match and current_route:
            prefix = event_match.group(1).strip()
            num = event_match.group(2).strip()
            title = event_match.group(3).strip()
            # Determine which route this event belongs to based on prefix
            event_route = current_route
            for key_word, route_key in EVENT_PREFIX_TO_ROUTE.items():
                if key_word in prefix:
                    if route_key is not None:
                        event_route = route_key
                    break
            if event_route not in events_by_route:
                events_by_route[event_route] = []
            # Flush previous event
            if current_event and current_event_route and current_event_route in events_by_route:
                events_by_route[current_event_route].append(current_event)
            current_event_route = event_route
            current_event = {
                "name": f"{prefix} Stage {num}: {title}".strip(),
                "num": int(num),
                "scene": "",
                "dialogues": [],
                "h_event_title": "",
                "h_event_dialogues": [],
                "system_prompt": "",
            }
            current_section = None
            i += 1
            continue

        # Detect section headers within an event
        # Format A: #### 场景描写
        # Format B: **场景描写**:  or **场景描写：**
        if stripped.startswith("#### 场景描写") or stripped.startswith("#### 場景描寫"):
            current_section = "scene"
            i += 1
            continue
        if re.match(r'^\*\*场景描写\*\*\s*[:：]?', stripped) or re.match(r'^\*\*場景描寫\*\*\s*[:：]?', stripped):
            current_section = "scene"
            i += 1
            continue
        if re.match(r'^\*\*【场景描写】\*\*', stripped) or re.match(r'^\*\*【場景描寫】\*\*', stripped):
            current_section = "scene"
            i += 1
            continue
        if stripped.startswith("#### 剧情对话") or stripped.startswith("#### 劇情對話"):
            current_section = "dialogue"
            i += 1
            continue
        if re.match(r'^\*\*剧情对话\*\*\s*[:：]?', stripped) or re.match(r'^\*\*劇情對話\*\*\s*[:：]?', stripped):
            current_section = "dialogue"
            i += 1
            continue
        if re.match(r'^\*\*【剧情对话】\*\*', stripped) or re.match(r'^\*\*【劇情對話】\*\*', stripped):
            current_section = "dialogue"
            i += 1
            continue
        if stripped.startswith("#### H事件") or stripped.startswith("#### H场景") or ("H事件" in stripped and stripped.startswith("####")):
            h_title_match = re.match(r'^####\s+H事件[：:]\s*(.+)', stripped)
            if h_title_match:
                if current_event:
                    current_event["h_event_title"] = h_title_match.group(1).strip()
            else:
                if current_event:
                    current_event["h_event_title"] = stripped.replace("####", "").replace("H事件", "").strip(": ：")
            current_section = "h_event"
            i += 1
            continue

        # System prompt - multiple formats
        # Format A: > **系统提示**: text
        # Format B: **系统提示**: \n > text
        # Format C: > ⚔ text (inside system prompt section)
        if stripped.startswith("> **系统提示") or stripped.startswith("> **系統提示"):
            prompt_text = re.sub(r'^>\s*\*\*系[统統]提示\*\*\s*[:：]?\s*', '', stripped)
            if current_event:
                current_event["system_prompt"] = strip_md_formatting(prompt_text)
            current_section = None
            i += 1
            continue
        if re.match(r'^\*\*系[统統]提示\*\*\s*[:：]?', stripped):
            current_section = "system"
            i += 1
            continue
        if re.match(r'^\*\*【系[统統]提示】\*\*', stripped):
            current_section = "system"
            i += 1
            continue
        # Trigger condition lines - skip
        if re.match(r'^\*\*触发条件\*\*\s*[:：]', stripped):
            current_section = None
            i += 1
            continue

        # Parse content based on current section
        if current_event and current_section and stripped:
            if current_section == "system":
                # System prompt content (may be > prefixed)
                text = stripped.lstrip("> ").strip()
                text = re.sub(r'^[⚔🔔💀🎭❤️♥]\s*', '', text)  # Remove emoji prefixes
                text = strip_md_formatting(text)
                if text and not text.startswith("---"):
                    if current_event["system_prompt"]:
                        current_event["system_prompt"] += " " + text
                    else:
                        current_event["system_prompt"] = text

            elif current_section == "scene":
                text = strip_md_formatting(stripped)
                if text and not text.startswith("---"):
                    if current_event["scene"]:
                        current_event["scene"] += " " + text
                    else:
                        current_event["scene"] = text

            elif current_section in ("dialogue", "h_event"):
                target = "dialogues" if current_section == "dialogue" else "h_event_dialogues"

                # Format A: **Speaker：** "text" or **Speaker:** "text"
                speaker_match = re.match(r'^\*\*(.+?)\*\*\s*[:：]\s*"(.+)"', stripped)
                if not speaker_match:
                    speaker_match = re.match(r'^\*\*(.+?)\s*[:：]\s*\*\*\s*"(.+)"', stripped)
                if not speaker_match:
                    speaker_match = re.match(r'^\*\*(.+?)\*\*\s*[:：]\s*「(.+?)」', stripped)

                # Format B: - Speaker："text" or - Speaker：「text」 (dash-prefixed)
                if not speaker_match:
                    speaker_match = re.match(r'^[-–—]\s*(.+?)\s*[:：]\s*[""「](.+?)[""」]', stripped)

                # Format C: - （action text） (dash-prefixed action in parens)
                paren_action = re.match(r'^[-–—]\s*[（(](.+?)[）)]$', stripped)

                # Format D: Speaker：「text」 or Speaker："text" (bare, no bold/dash)
                bare_speaker = None
                if not speaker_match and not paren_action:
                    bare_speaker = re.match(r'^([^\s*#>（(「"\-–—].+?)\s*[:：]\s*[「"""](.+?)[」"""]', stripped)
                    # Also match （action） without dash prefix
                    if not bare_speaker:
                        paren_action_bare = re.match(r'^[（(](.+?)[）)]$', stripped)
                        if paren_action_bare:
                            paren_action = paren_action_bare

                if speaker_match:
                    speaker = speaker_match.group(1).strip()
                    text = speaker_match.group(2).strip().strip('"「」""')
                    current_event[target].append({
                        "type": "dialogue",
                        "speaker": speaker,
                        "text": text,
                    })
                elif bare_speaker:
                    speaker = bare_speaker.group(1).strip()
                    text = bare_speaker.group(2).strip().strip('"「」""')
                    current_event[target].append({
                        "type": "dialogue",
                        "speaker": speaker,
                        "text": text,
                    })
                elif paren_action:
                    current_event[target].append({
                        "type": "action",
                        "text": strip_md_formatting(paren_action.group(1)),
                    })
                # Action in brackets: [指挥官推开门]
                elif stripped.startswith("[") and stripped.endswith("]"):
                    action_text = stripped[1:-1].strip()
                    current_event[target].append({
                        "type": "action",
                        "text": strip_md_formatting(action_text),
                    })
                # Narration (italic text): *凛抬起头...*
                elif stripped.startswith("*") and not stripped.startswith("**"):
                    narr_text = strip_md_formatting(stripped)
                    if narr_text:
                        current_event[target].append({
                            "type": "narration",
                            "text": narr_text,
                        })
                # Dash-prefixed narration without speaker
                elif stripped.startswith("-") or stripped.startswith("–") or stripped.startswith("—"):
                    text = re.sub(r'^[-–—]\s*', '', stripped)
                    text = strip_md_formatting(text)
                    if text:
                        current_event[target].append({
                            "type": "narration",
                            "text": text,
                        })
                # Plain narration or continuation
                elif not stripped.startswith("#") and not stripped.startswith("---") and not stripped.startswith(">"):
                    text = strip_md_formatting(stripped)
                    if text:
                        current_event[target].append({
                            "type": "narration",
                            "text": text,
                        })

        i += 1

    # Don't forget the last event
    if current_event and current_event_route and current_event_route in events_by_route:
        events_by_route[current_event_route].append(current_event)

    return events_by_route


def generate_gdscript(hero_id, events_by_route, route_keys):
    """Generate GDScript data file content."""
    lines = []
    lines.append(f'## {hero_id}_story.gd - Story event data for {hero_id}')
    lines.append('## Auto-generated from markdown quest scripts. Do not edit manually.')
    lines.append('extends RefCounted')
    lines.append('')
    lines.append('const EVENTS: Dictionary = {')

    for route_key in route_keys:
        events = events_by_route.get(route_key, [])
        lines.append(f'\t"{route_key}": [')

        for idx, event in enumerate(events):
            event_num = idx + 1
            event_id = f"{hero_id}_{route_key}_{event_num:02d}"

            # Trigger: first event depends on route type
            if idx == 0:
                if route_key == "training":
                    trigger = '{"hero_captured": true}'
                elif route_key in ("pure_love", "friendly"):
                    trigger = '{"hero_recruited": true}'
                elif route_key == "hostile":
                    trigger = '{}'
                elif route_key == "neutral":
                    trigger = '{}'
                else:
                    trigger = '{}'
            else:
                prev_id = f"{hero_id}_{route_key}_{event_num - 1:02d}"
                trigger = '{' + f'"prev_event": "{prev_id}"' + '}'

            # Effects vary by route type
            if route_key in ("training", "hostile"):
                effects = '{"training_progress": 1}'
            else:
                effects = '{"affection": 1}'

            lines.append('\t\t{')
            lines.append(f'\t\t\t"id": "{event_id}",')
            lines.append(f'\t\t\t"name": "{escape_gdscript(event["name"])}",')
            lines.append(f'\t\t\t"trigger": {trigger},')
            lines.append(f'\t\t\t"scene": "{escape_gdscript(event["scene"])}",')

            # Dialogues
            lines.append('\t\t\t"dialogues": [')
            for d in event["dialogues"]:
                dtype = d.get("type", "dialogue")
                if dtype == "dialogue":
                    speaker = escape_gdscript(d.get("speaker", ""))
                    text = escape_gdscript(d.get("text", ""))
                    lines.append(f'\t\t\t\t{{"speaker": "{speaker}", "text": "{text}"}},')
                elif dtype == "action":
                    text = escape_gdscript(d.get("text", ""))
                    lines.append(f'\t\t\t\t{{"type": "action", "text": "{text}"}},')
                elif dtype == "narration":
                    text = escape_gdscript(d.get("text", ""))
                    lines.append(f'\t\t\t\t{{"type": "narration", "text": "{text}"}},')
            lines.append('\t\t\t],')

            # H-event
            if event["h_event_dialogues"]:
                h_title = escape_gdscript(event.get("h_event_title", ""))
                lines.append('\t\t\t"h_event": {')
                lines.append(f'\t\t\t\t"title": "{h_title}",')
                lines.append('\t\t\t\t"dialogues": [')
                for d in event["h_event_dialogues"]:
                    dtype = d.get("type", "dialogue")
                    if dtype == "dialogue":
                        speaker = escape_gdscript(d.get("speaker", ""))
                        text = escape_gdscript(d.get("text", ""))
                        lines.append(f'\t\t\t\t\t{{"speaker": "{speaker}", "text": "{text}"}},')
                    elif dtype == "action":
                        text = escape_gdscript(d.get("text", ""))
                        lines.append(f'\t\t\t\t\t{{"type": "action", "text": "{text}"}},')
                    elif dtype == "narration":
                        text = escape_gdscript(d.get("text", ""))
                        lines.append(f'\t\t\t\t\t{{"type": "narration", "text": "{text}"}},')
                lines.append('\t\t\t\t]')
                lines.append('\t\t\t},')

            lines.append(f'\t\t\t"system_prompt": "{escape_gdscript(event["system_prompt"])}",')
            lines.append(f'\t\t\t"effects": {effects},')
            lines.append('\t\t},')

        lines.append('\t],')

    lines.append('}')
    lines.append('')
    return "\n".join(lines)


def find_md_file(docs_dir, file_num, char_names):
    """Find the markdown file for a character."""
    for name in char_names:
        pattern = f"{file_num}_{name}_路线.md"
        path = os.path.join(docs_dir, pattern)
        if os.path.exists(path):
            return path
    # Fallback: glob
    import glob
    matches = glob.glob(os.path.join(docs_dir, f"{file_num}_*_路线.md"))
    if matches:
        return matches[0]
    return None


def main():
    base_dir = "/workspace/dark-tide-slg"
    docs_dir = os.path.join(base_dir, "docs", "quest_scripts")
    output_dir = os.path.join(base_dir, "systems", "story", "data")
    os.makedirs(output_dir, exist_ok=True)

    # Character name variants for file matching
    name_variants = {
        "01": ["凛"],
        "02": ["雪乃"],
        "03": ["红叶"],
        "04": ["冰華", "冰华"],
        "05": ["翠玲"],
        "06": ["月華", "月华"],
        "07": ["叶隐", "葉隱"],
        "08": ["蒼", "苍"],
        "09": ["紫苑"],
        "10": ["焔", "焰"],
        "13": ["響", "响"],
        "14": ["沙罗"],
        "15": ["冥"],
        "16": ["枫"],
        "17": ["朱音"],
        "18": ["花火"],
    }

    all_characters = MAIN_CHARACTERS + NEUTRAL_CHARACTERS

    for file_num, hero_id, speaker, route_keys in all_characters:
        variants = name_variants.get(file_num, [speaker])
        md_path = find_md_file(docs_dir, file_num, variants)
        if not md_path:
            print(f"WARNING: No markdown file found for {hero_id} (#{file_num})")
            continue

        print(f"Processing {hero_id} from {os.path.basename(md_path)}...")
        events_by_route = parse_markdown(md_path)

        if not events_by_route:
            print(f"  WARNING: No events parsed for {hero_id}")
            continue

        for rk in events_by_route:
            print(f"  Route '{rk}': {len(events_by_route[rk])} events")

        gd_content = generate_gdscript(hero_id, events_by_route, route_keys)
        output_path = os.path.join(output_dir, f"{hero_id}_story.gd")
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(gd_content)
        line_count = gd_content.count("\n") + 1
        print(f"  Written {output_path} ({line_count} lines)")

    print("\nDone! All character story data files generated.")


if __name__ == "__main__":
    main()
