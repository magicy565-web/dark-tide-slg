class_name ChibiSpriteLoader
## Utility for loading hero chibi battle animation videos (.ogv) and fallback PNG sprites.
## Maps hero_id (e.g. "rin") → animation files for 6 states.
##
## Video path pattern: res://assets/characters/animations_ogv/{folder}_chibi_{state}.ogv
## PNG fallback:       res://assets/characters/chibi/{folder}/{state}.png
##
## Usage:
##   var stream = ChibiSpriteLoader.load_video("rin", "idle")
##   var tex    = ChibiSpriteLoader.load_png("rin", "idle")  # fallback
##   var has    = ChibiSpriteLoader.has_video("sou")

const VIDEO_BASE := "res://assets/characters/animations_ogv/"
const CHIBI_BASE := "res://assets/characters/chibi/"

# hero_id → folder/file prefix mapping (18 heroes)
const HERO_FOLDERS: Dictionary = {
	"rin": "01_rin",
	"yukino": "02_yukino",
	"momiji": "03_momiji",
	"hyouka": "04_hyouka",
	"suirei": "05_suirei",
	"gekka": "06_gekka",
	"hakagure": "07_hakagure",
	"sou": "08_sou",
	"shion": "09_shion",
	"homura": "10_homura",
	"shion_pirate": "11_shion_pirate",
	"youya": "12_youya",
	"hibiki": "13_hibiki",
	"mei": "15_mei",
	"kaede": "16_kaede",
	"akane": "17_akane",
	"hanabi": "18_hanabi",
}

# States that should loop vs play-once
const LOOP_STATES := ["idle"]
const PLAY_ONCE_STATES := ["attack", "cast", "hurt", "defeated", "victory"]

# Valid states
const STATES := ["idle", "attack", "cast", "hurt", "defeated", "victory"]

# Cache: "hero_id/state" → VideoStream or Texture2D
static var _cache: Dictionary = {}

## Load an OGV video stream for a hero state.
## Returns null if not found.
static func load_video(hero_id: String, state: String = "idle") -> VideoStream:
	var cache_key := "v:" + hero_id + "/" + state
	if _cache.has(cache_key):
		return _cache[cache_key]

	var folder: String = HERO_FOLDERS.get(hero_id, "")
	if folder.is_empty():
		return null

	# Try exact state name
	var path := VIDEO_BASE + folder + "_chibi_" + state + ".ogv"
	if ResourceLoader.exists(path):
		var stream := load(path) as VideoStream
		_cache[cache_key] = stream
		return stream

	# Handle defeat/defeated inconsistency
	if state == "defeated":
		var alt := VIDEO_BASE + folder + "_chibi_defeat.ogv"
		if ResourceLoader.exists(alt):
			var stream := load(alt) as VideoStream
			_cache[cache_key] = stream
			return stream
	elif state == "defeat":
		var alt := VIDEO_BASE + folder + "_chibi_defeated.ogv"
		if ResourceLoader.exists(alt):
			var stream := load(alt) as VideoStream
			_cache[cache_key] = stream
			return stream

	return null

## Load a PNG sprite as fallback (for heroes without video).
static func load_png(hero_id: String, state: String = "idle") -> Texture2D:
	var cache_key := "p:" + hero_id + "/" + state
	if _cache.has(cache_key):
		return _cache[cache_key]

	var folder: String = HERO_FOLDERS.get(hero_id, "")
	if folder.is_empty():
		return null

	var path := CHIBI_BASE + folder + "/" + state + ".png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		_cache[cache_key] = tex
		return tex

	# Handle defeat/defeated inconsistency
	if state == "defeated":
		var alt := CHIBI_BASE + folder + "/defeat.png"
		if ResourceLoader.exists(alt):
			var tex := load(alt) as Texture2D
			_cache[cache_key] = tex
			return tex
	elif state == "defeat":
		var alt := CHIBI_BASE + folder + "/defeated.png"
		if ResourceLoader.exists(alt):
			var tex := load(alt) as Texture2D
			_cache[cache_key] = tex
			return tex

	return null

## Check if a hero has OGV video animations.
static func has_video(hero_id: String) -> bool:
	var folder: String = HERO_FOLDERS.get(hero_id, "")
	if folder.is_empty():
		return false
	var path := VIDEO_BASE + folder + "_chibi_idle.ogv"
	return ResourceLoader.exists(path)

## Check if a hero has PNG chibi sprites (fallback).
static func has_png(hero_id: String) -> bool:
	var folder: String = HERO_FOLDERS.get(hero_id, "")
	if folder.is_empty():
		return false
	var path := CHIBI_BASE + folder + "/idle.png"
	return ResourceLoader.exists(path)

## Check if a hero has any chibi assets (video or PNG).
static func has_chibi(hero_id: String) -> bool:
	return has_video(hero_id) or has_png(hero_id)

## Whether a state should loop.
static func is_loop_state(state: String) -> bool:
	return state in LOOP_STATES

## Clear all caches (call on scene change to free memory).
static func clear_cache() -> void:
	_cache.clear()
