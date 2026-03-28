class_name ChibiSpriteLoader
## Utility for loading hero chibi battle sprites (6 states: idle/attack/cast/hurt/defeated/victory).
## Maps hero_id (e.g. "rin") → chibi sprite folder → state textures.
##
## Usage:
##   var tex = ChibiSpriteLoader.load_state("rin", "idle")
##   var tex = ChibiSpriteLoader.load_state("sou", "attack")

const CHIBI_BASE := "res://assets/characters/chibi/"

# hero_id → folder name mapping (18 heroes)
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

# Valid sprite states
const STATES := ["idle", "attack", "cast", "hurt", "defeated", "victory"]

# Cache: "hero_id/state" → Texture2D
static var _cache: Dictionary = {}

## Load a chibi sprite for a hero in a specific state.
## Returns null if not found.
static func load_state(hero_id: String, state: String = "idle") -> Texture2D:
	var cache_key := hero_id + "/" + state
	if _cache.has(cache_key):
		return _cache[cache_key]

	var folder: String = HERO_FOLDERS.get(hero_id, "")
	if folder.is_empty():
		return null

	# Try exact state name first
	var path := CHIBI_BASE + folder + "/" + state + ".png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		_cache[cache_key] = tex
		return tex

	# Handle defeat/defeated inconsistency
	if state == "defeated":
		var alt_path := CHIBI_BASE + folder + "/defeat.png"
		if ResourceLoader.exists(alt_path):
			var tex := load(alt_path) as Texture2D
			_cache[cache_key] = tex
			return tex
	elif state == "defeat":
		var alt_path := CHIBI_BASE + folder + "/defeated.png"
		if ResourceLoader.exists(alt_path):
			var tex := load(alt_path) as Texture2D
			_cache[cache_key] = tex
			return tex

	return null

## Check if a hero has chibi sprites available.
static func has_chibi(hero_id: String) -> bool:
	var folder: String = HERO_FOLDERS.get(hero_id, "")
	if folder.is_empty():
		return false
	var path := CHIBI_BASE + folder + "/idle.png"
	return ResourceLoader.exists(path)

## Get all available hero IDs that have chibi sprites.
static func get_available_heroes() -> Array[String]:
	var result: Array[String] = []
	for hero_id in HERO_FOLDERS.keys():
		if has_chibi(hero_id):
			result.append(hero_id)
	return result

## Clear the texture cache (call on scene change to free memory).
static func clear_cache() -> void:
	_cache.clear()
