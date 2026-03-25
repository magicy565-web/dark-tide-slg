class_name LightSpriteLoader
## Utility for loading Light faction pixel art sprites.
## Maps troop_id → sprite texture path for all light-side units.
##
## Usage:
##   var tex = LightSpriteLoader.load_sprite("human_cavalry")
##   var tex_lv = LightSpriteLoader.load_sprite("human_cavalry", 2)  # lv2 icon

const SPRITE_BASE := "res://assets/sprites/light/"
const ICON_BASE := "res://assets/icons/troops_light/"

# ── Faction-specific unit sprite names ──
const FACTION_SPRITES := [
	"human_ashigaru", "human_cavalry", "human_samurai",
	"elf_archer", "elf_mage", "elf_ashigaru",
	"mage_apprentice", "mage_battle", "mage_grand",
]

# ── Shared light unit sprite names ──
const SHARED_SPRITES := [
	"light_ashigaru", "light_samurai", "light_archer", "light_cavalry",
	"light_ninja", "light_priest", "light_mage", "light_cannon",
]

# ── troop_id → sprite filename mapping ──
# Handles both faction-specific and shared troop IDs.
const TROOP_TO_SPRITE := {
	# Human Kingdom
	"human_ashigaru": "human_ashigaru",
	"human_cavalry": "human_cavalry",
	"human_samurai": "human_samurai",
	# High Elves
	"elf_archer": "elf_archer",
	"elf_mage": "elf_mage",
	"elf_ashigaru": "elf_ashigaru",
	# Mage Tower
	"mage_apprentice": "mage_apprentice",
	"mage_battle": "mage_battle",
	"mage_grand": "mage_grand",
	# Shared light units (generic base types)
	"ashigaru": "light_ashigaru",
	"samurai": "light_samurai",
	"archer": "light_archer",
	"cavalry": "light_cavalry",
	"ninja": "light_ninja",
	"priest": "light_priest",
	"mage": "light_mage",
	"cannon": "light_cannon",
	# Also support prefixed names
	"light_ashigaru": "light_ashigaru",
	"light_samurai": "light_samurai",
	"light_archer": "light_archer",
	"light_cavalry": "light_cavalry",
	"light_ninja": "light_ninja",
	"light_priest": "light_priest",
	"light_mage": "light_mage",
	"light_cannon": "light_cannon",
}

## Load the battle sprite (pixel art, transparent background) for a troop.
## Returns null if the troop has no sprite.
static func load_sprite(troop_id: String) -> Texture2D:
	var sprite_name: String = TROOP_TO_SPRITE.get(troop_id, "")
	if sprite_name.is_empty():
		push_warning("LightSpriteLoader: no sprite mapping for '%s'" % troop_id)
		return null

	var path := SPRITE_BASE + sprite_name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	push_warning("LightSpriteLoader: sprite not found at '%s'" % path)
	return null

## Load the icon (anime art) for a troop at a specific level (1-3).
static func load_icon(troop_id: String, level: int = 1) -> Texture2D:
	var sprite_name: String = TROOP_TO_SPRITE.get(troop_id, "")
	if sprite_name.is_empty():
		return null

	var lv := clampi(level, 1, 3)
	var path := ICON_BASE + sprite_name + "_lv%d.png" % lv
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## Get all available sprite names (for debug/gallery).
static func get_all_sprite_names() -> Array[String]:
	var names: Array[String] = []
	names.append_array(FACTION_SPRITES)
	names.append_array(SHARED_SPRITES)
	return names

## Check if a troop_id belongs to the Light faction sprite set.
static func has_sprite(troop_id: String) -> bool:
	return TROOP_TO_SPRITE.has(troop_id)
