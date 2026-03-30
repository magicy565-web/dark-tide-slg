## story_data_template.gd - Reference template for character story data format
## Each character's story file (e.g., rin_story.gd) follows this structure.
## DO NOT use this file directly — it exists as documentation.
extends RefCounted
class_name StoryDataTemplate

# ═══════════════ DATA FORMAT SPECIFICATION ═══════════════
#
# Each character story file exposes a single constant: EVENTS
# EVENTS is a Dictionary keyed by route name:
#   - "training"   — 调教路线 (main heroines, captured)
#   - "pure_love"  — 纯爱路线 (main heroines, post-defeat join)
#   - "hostile"    — 敌对路线 (neutral chars, conquest)
#   - "friendly"   — 友好路线 (neutral chars, early pure love)
#   - "neutral"    — 中立路线 (neutral chars, quest chain)
#
# Each route value is an Array of event dictionaries, ordered sequentially.
#
# ═══════════════ EVENT DICTIONARY FORMAT ═══════════════
#
# {
#   "id": "rin_training_01",          # Unique event ID
#   "name": "调教 Stage 01: 抵抗",     # Display name
#
#   "trigger": {                       # Conditions to unlock (all must be true)
#     "hero_captured": true,           # Hero must be captured
#     "hero_recruited": true,          # Hero must be recruited
#     "affection_min": 3,             # Minimum affection level
#     "corruption_min": 10,           # Minimum corruption counter
#     "prev_event": "event_id",       # Previous event must be completed
#     "turn_min": 5,                  # Minimum game turn
#     "flag": {"key": value},         # Story flags that must match
#   },
#
#   "scene": "场景描写文本...",          # Scene description (narrative/setting)
#
#   "bgm": "event",                     # Optional: BGM track name (see AudioManager)
#   "cg": "rin_training_01.png",         # Optional: CG image (res://assets/cg/ or full path)
#
#   "dialogues": [                     # Sequential dialogue entries
#     {
#       "type": "narration",           # Narrative text (no speaker)
#       "text": "叙述文本...",
#       "voice": "rin_01_001.ogg",     # Optional: voice line (res://assets/audio/voice/)
#       "sfx": "event_trigger",        # Optional: SFX name (see AudioManager)
#       "cg": "rin_cg_02.png",         # Optional: inline CG change
#     },
#     {
#       "type": "action",              # Stage direction [in brackets]
#       "text": "指挥官推开牢房的铁门，脚步声在石壁间回荡",
#       "sfx": "ui_confirm",           # Optional: SFX for action
#     },
#     {
#       "type": "dialogue",            # Character speech (default type)
#       "speaker": "凛",               # Speaker name (also used for portrait lookup)
#       "text": "……又来了吗。",         # Spoken text
#       "action": "凛抬起头",           # Optional: action before/during speech
#       "voice": "rin_01_002.ogg",     # Optional: character voice line
#     },
#     {
#       "type": "choice",              # Player choice point
#       "prompt": "如何回应？",
#       "options": [
#         {"text": "选项1文本", "effects": {"affection": 2}},
#         {"text": "选项2文本", "effects": {"set_flag": {"chose_mercy": true}}},
#       ]
#     },
#   ],
#
#   "h_event": {                       # Optional H-event data
#     "title": "骑士的试炼",
#     "dialogues": [                   # Same format as main dialogues
#       {"type": "narration", "text": "..."},
#       {"type": "dialogue", "speaker": "凛", "text": "..."},
#     ]
#   },
#
#   "system_prompt": "凛的调教进度 [1/10]。...",  # System prompt text
#
#   "effects": {                       # Auto-applied on event completion
#     "affection": 1,                  # Delta to affection (can be negative)
#     "training_progress": 1,          # Delta to training counter
#     "loyalty": 5,                    # Delta to loyalty flag
#     "gold": 100,                     # Resource deltas
#     "set_flag": {"key": value},      # Set story flags
#   },
# }

# ═══════════════ EXAMPLE (abbreviated) ═══════════════
#
# ═══════════════ DIALOGUE SYSTEM FEATURES (v2.0) ═══════════════
#
# 1. CHARACTER PORTRAITS — speaker name is auto-mapped to portrait textures
#    in res://assets/characters/portraits/ via PORTRAIT_MAP in story_dialog.gd.
#    Supported names: 凛, 雪乃, 千姬, 暗精灵女王, 海盗女王, 兽人战酋, 她, 主角, etc.
#
# 2. CG DISPLAY LAYER — set "cg" on event or individual dialogue entry.
#    Full res:// paths or short names resolved against res://assets/cg/.
#
# 3. TEXT SPEED SETTINGS — player cycles through 4 presets: 慢速/普通/快速/瞬间.
#
# 4. AUTO-ADVANCE — toggle auto-play; advances after 2.5s delay post-reveal.
#
# 5. DIALOGUE HISTORY — "Log" button opens scrollable backlog of all past entries.
#
# 6. AUDIO PLAYBACK — per-entry "voice" (voice line path) and "sfx" (SFX name).
#    Event-level "bgm" sets background music track via AudioManager.
#

const EVENTS: Dictionary = {
	"training": [
		{
			"id": "example_training_01",
			"name": "调教 Stage 01: 抵抗",
			"trigger": {"hero_captured": true},
			"scene": "地下牢房的石壁上渗着冰冷的水珠...",
			"dialogues": [
				{"type": "action", "text": "指挥官推开牢房的铁门"},
				{"speaker": "凛", "text": "……又来了吗。", "action": "凛抬起头，以冰冷的目光注视着来人"},
				{"speaker": "凛", "text": "无论你来多少次，我的回答都不会改变。"},
			],
			"h_event": {
				"title": "骑士的试炼",
				"dialogues": [
					{"type": "narration", "text": "场景描写..."},
					{"speaker": "凛", "text": "住手……不要碰那里——！"},
				]
			},
			"system_prompt": "凛的调教进度 [1/10]。骑士的信念依然坚不可摧。",
			"effects": {"training_progress": 1},
		},
	],
	"pure_love": [],
}
