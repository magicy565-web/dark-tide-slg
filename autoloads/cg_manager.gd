## cg_manager.gd — CG Gallery & Expression Manager (v1.0)
## Tracks unlocked CGs, manages character portrait/expression paths,
## and provides the data layer for the CG gallery scene.
## Autoload singleton: CGManager
extends Node

# ── Signals ──
signal cg_unlocked(cg_id: String, hero_id: String)

# ── Unlocked CG registry (serialized by SaveManager) ──
# Set of unlocked CG IDs: { "rin_cg_01": true, "yukino_cg_02": true, ... }
var unlocked_cgs: Dictionary = {}

# ── Asset path conventions ──
# Event CG:       res://assets/cg/{hero_id}/{cg_id}.png        (1920×1080)
# Character head:  res://assets/characters/heads/{nn}_{hero_id}_head.webp  (256×256)
# Expression:      res://assets/characters/heads/{nn}_{hero_id}_head_{expr}.webp
# Full portrait:   res://assets/characters/designs/{nn}_{hero_id}_{variant}.webp

# ── Hero ID → file number prefix mapping ──
const HERO_PREFIX: Dictionary = {
	"rin": "01", "yukino": "02", "momiji": "03", "hyouka": "04",
	"suirei": "05", "gekka": "06", "hakagure": "07", "sou": "08",
	"shion": "09", "homura": "10", "shion_pirate": "11", "youya": "12",
	"hibiki": "13", "sara": "14", "mei": "15", "kaede": "16",
	"akane": "17", "hanabi": "18",
}

# ── Expression name constants ──
# Used in dialogue data: "expression": "angry"
# Maps to file suffix: {nn}_{hero_id}_head_angry.webp
const EXPRESSIONS := ["normal", "happy", "angry", "sad", "surprised", "shy", "serious"]

# ── CG catalog ──
# Defines all possible CGs per hero (populated from story data at runtime).
# hero_id -> Array of { "cg_id": String, "title": String, "path": String }
var _cg_catalog: Dictionary = {}


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	pass


func reset() -> void:
	unlocked_cgs.clear()
	_cg_catalog.clear()


# ═══════════════════════════════════════════════════════════════
#                     CG PATH RESOLUTION
# ═══════════════════════════════════════════════════════════════

## Get the filesystem path for an event CG.
## Convention: res://assets/cg/{hero_id}/{cg_id}.png
func get_cg_path(hero_id: String, cg_id: String) -> String:
	return "res://assets/cg/%s/%s.png" % [hero_id, cg_id]


## Get the filesystem path for a character head portrait (base or expression).
## expression == "" or "normal" → base head
## expression == "angry" → {nn}_{hero_id}_head_angry.webp
func get_head_path(hero_id: String, expression: String = "") -> String:
	var prefix: String = HERO_PREFIX.get(hero_id, "00")
	if expression == "" or expression == "normal":
		return "res://assets/characters/heads/%s_%s_head.webp" % [prefix, hero_id]
	return "res://assets/characters/heads/%s_%s_head_%s.webp" % [prefix, hero_id, expression]


## Try to load a head texture, falling back to base head if expression variant doesn't exist.
func load_head_texture(hero_id: String, expression: String = "") -> Texture2D:
	var path: String = get_head_path(hero_id, expression)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# Fallback: try base head (no expression suffix)
	if expression != "" and expression != "normal":
		var base_path: String = get_head_path(hero_id, "")
		if ResourceLoader.exists(base_path):
			return load(base_path) as Texture2D
	return null


## Try to load an event CG texture. Returns null if not found.
func load_cg_texture(hero_id: String, cg_id: String) -> Texture2D:
	var path: String = get_cg_path(hero_id, cg_id)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


# ═══════════════════════════════════════════════════════════════
#                     CG UNLOCK MANAGEMENT
# ═══════════════════════════════════════════════════════════════

## Unlock a CG. Called by StoryEventSystem when an event with a CG is completed.
func unlock_cg(cg_id: String, hero_id: String = "") -> void:
	if unlocked_cgs.has(cg_id):
		return
	unlocked_cgs[cg_id] = true
	cg_unlocked.emit(cg_id, hero_id)
	if EventBus.has_signal("cg_unlocked"):
		EventBus.cg_unlocked.emit(cg_id, hero_id)


## Check if a CG has been unlocked.
func is_cg_unlocked(cg_id: String) -> bool:
	return unlocked_cgs.has(cg_id)


## Get all unlocked CG IDs.
func get_unlocked_cgs() -> Array:
	return unlocked_cgs.keys()


## Get unlocked CGs filtered by hero.
func get_unlocked_cgs_for_hero(hero_id: String) -> Array:
	var result: Array = []
	for cg_id in unlocked_cgs:
		if cg_id.begins_with(hero_id + "_"):
			result.append(cg_id)
	return result


# ═══════════════════════════════════════════════════════════════
#                     CG CATALOG (for Gallery)
# ═══════════════════════════════════════════════════════════════

## Register a CG entry in the catalog (called during story data loading).
func register_cg(hero_id: String, cg_id: String, title: String = "") -> void:
	if not _cg_catalog.has(hero_id):
		_cg_catalog[hero_id] = []
	# Avoid duplicates
	for entry in _cg_catalog[hero_id]:
		if entry["cg_id"] == cg_id:
			return
	_cg_catalog[hero_id].append({
		"cg_id": cg_id,
		"title": title,
		"path": get_cg_path(hero_id, cg_id),
	})


## Get the full CG catalog for a hero.
func get_hero_cg_catalog(hero_id: String) -> Array:
	return _cg_catalog.get(hero_id, [])


## Get the full CG catalog for all heroes (for gallery display).
func get_full_catalog() -> Dictionary:
	return _cg_catalog.duplicate(true)


## Build the CG catalog by scanning all story data files.
## Call this once at game start or when gallery is opened.
func build_catalog_from_story_data() -> void:
	_cg_catalog.clear()
	for hero_id in StoryEventSystem.STORY_DATA_FILES:
		if hero_id == "epilogue":
			continue
		var data: Dictionary = StoryEventSystem._get_story_data(hero_id)
		for route_key in data:
			var events: Array = data[route_key]
			for event in events:
				# Check for CG references in event
				var cg_id: String = event.get("cg", "")
				if cg_id != "":
					register_cg(hero_id, cg_id, event.get("name", ""))
				# Check h_event for CG
				var h_event: Dictionary = event.get("h_event", {})
				var h_cg_id: String = h_event.get("cg", "")
				if h_cg_id != "":
					register_cg(hero_id, h_cg_id, h_event.get("title", ""))
				# Check individual dialogues for inline CG switches
				for d in event.get("dialogues", []):
					var d_cg: String = d.get("cg", "")
					if d_cg != "":
						register_cg(hero_id, d_cg, event.get("name", ""))


# ═══════════════════════════════════════════════════════════════
#                     SAVE / LOAD
# ═══════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	return {
		"unlocked_cgs": unlocked_cgs.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	unlocked_cgs = data.get("unlocked_cgs", {}).duplicate()
