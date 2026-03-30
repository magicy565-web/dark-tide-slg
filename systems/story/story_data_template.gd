## story_data_template.gd - Reference template for character story data format (v2.0)
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
#   "cg": "rin_cg_01",                # (v2.0) Optional: event CG ID (fullscreen background)
#                                      # Resolves to: res://assets/cg/{hero_id}/{cg_id}.png
#                                      # When set, replaces scene description panel with CG image
#
#   "dialogues": [                     # Sequential dialogue entries
#     {
#       "type": "narration",           # Narrative text (no speaker)
#       "text": "叙述文本...",
#       "expression": "sad",           # (v2.0) Optional: change portrait expression
#       "cg": "rin_cg_02",            # (v2.0) Optional: switch CG mid-dialogue
#     },
#     {
#       "type": "action",              # Stage direction [in brackets]
#       "text": "指挥官推开牢房的铁门，脚步声在石壁间回荡"
#     },
#     {
#       "type": "dialogue",            # Character speech (default type)
#       "speaker": "凛",               # Speaker display name
#       "speaker_id": "rin",           # (v2.0) Optional: hero_id of speaker (for portrait switching)
#       "text": "……又来了吗。",         # Spoken text
#       "action": "凛抬起头",           # Optional: action before/during speech
#       "expression": "angry",         # (v2.0) Optional: expression variant for this line
#                                      # Values: normal, happy, angry, sad, surprised, shy, serious
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
#     "cg": "rin_h_cg_01",            # (v2.0) Optional: H-event specific CG
#     "dialogues": [                   # Same format as main dialogues
#       {"type": "narration", "text": "...", "expression": "shy"},
#       {"type": "dialogue", "speaker": "凛", "speaker_id": "rin", "text": "...", "expression": "surprised"},
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

# ═══════════════ EXPRESSION VALUES (v2.0) ═══════════════
#
# Each expression maps to a file suffix: {nn}_{hero_id}_head_{expression}.png
# Supported expressions:
#   "normal"    — Default/neutral (or omit expression field)
#   "happy"     — 喜 (joy, smile, warmth)
#   "angry"     — 怒 (anger, fury, defiance)
#   "sad"       — 哀 (sadness, grief, melancholy)
#   "surprised" — 惊 (shock, surprise, alarm)
#   "shy"       — 羞 (embarrassment, blush, bashful)
#   "serious"   — 真剣 (stern, focused, determined)
#
# If an expression variant file doesn't exist, the system falls back to the base head.

# ═══════════════ CG NAMING CONVENTION (v2.0) ═══════════════
#
# Event CG:    {hero_id}_cg_{nn}     → res://assets/cg/{hero_id}/{hero_id}_cg_{nn}.png
# H-event CG:  {hero_id}_h_cg_{nn}   → res://assets/cg/{hero_id}/{hero_id}_h_cg_{nn}.png
# Resolution:   1920×1080 (fullscreen)
# Per art spec: 3 event CGs per character minimum (training/affection milestones)

# ═══════════════ EXAMPLE (abbreviated) ═══════════════

const EVENTS: Dictionary = {
	"training": [
		{
			"id": "example_training_01",
			"name": "调教 Stage 01: 抵抗",
			"trigger": {"hero_captured": true},
			"scene": "地下牢房的石壁上渗着冰冷的水珠...",
			"cg": "rin_cg_01",
			"dialogues": [
				{"type": "action", "text": "指挥官推开牢房的铁门"},
				{"speaker": "凛", "speaker_id": "rin", "text": "……又来了吗。", "action": "凛抬起头，以冰冷的目光注视着来人", "expression": "angry"},
				{"speaker": "凛", "speaker_id": "rin", "text": "无论你来多少次，我的回答都不会改变。", "expression": "serious"},
				{"type": "narration", "text": "她的眼中闪过一丝动摇。", "expression": "sad"},
			],
			"h_event": {
				"title": "骑士的试炼",
				"cg": "rin_h_cg_01",
				"dialogues": [
					{"type": "narration", "text": "场景描写..."},
					{"speaker": "凛", "speaker_id": "rin", "text": "住手……不要碰那里——！", "expression": "surprised"},
				]
			},
			"system_prompt": "凛的调教进度 [1/10]。骑士的信念依然坚不可摧。",
			"effects": {"training_progress": 1},
		},
	],
	"pure_love": [],
}
