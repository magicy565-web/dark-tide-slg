## web_loader.gd — Web-specific asset loading optimizer
## Coordinates lazy loading for Web builds where ~100MB of assets must be
## downloaded. Preloads only essential assets at startup and defers heavy
## resources (effects, full designs, videos) until they are actually needed.
extends Node

## Emitted when initial essential assets are loaded and the game is playable.
signal essentials_ready
## Emitted when a deferred asset category starts/finishes loading.
signal category_loading(category: String, is_loading: bool)

# Whether we are running in a Web browser
var _is_web: bool = false

# Track which categories have been loaded
var _loaded_categories: Dictionary = {}

# Essential asset directories (small, needed immediately)
const ESSENTIAL_CATEGORIES: Dictionary = {
	"icons": "res://assets/icons",
	"heads": "res://assets/characters/heads",
	"ui": "res://assets/ui",
}

# Deferred asset directories (large, loaded on demand)
# Note: "backgrounds" and "video" directories were removed from the project;
# "effects" and "designs" directories now have proper .import files.
const DEFERRED_CATEGORIES: Dictionary = {
	"effects": "res://assets/effects",
	"designs": "res://assets/characters/designs",
	"cg": "res://assets/cg",
}

# Hardcoded fallback paths for essential assets in case DirAccess fails
# Updated to use actual existing asset paths in the project.
const ESSENTIAL_FALLBACK_PATHS: Array = [
	"res://assets/ui/icon_gold_coin.png",
	"res://assets/ui/icon_food_grain.png",
	"res://assets/ui/icon_prestige_crown.png",
	"res://assets/ui/icon_slave_chain.png",
	"res://assets/ui/icon_order.png",
	"res://assets/ui/panel_frame.png",
	"res://assets/ui/btn_normal.png",
	"res://assets/characters/heads/default.png",
]

# File extensions to scan
const TEXTURE_EXTENSIONS: Array = [".png", ".webp", ".jpg"]
const ALL_ASSET_EXTENSIONS: Array = [".png", ".webp", ".jpg", ".ogv", ".ogg", ".tres"]


func _ready() -> void:
	_is_web = OS.get_name() == "Web"

	if _is_web:
		# On Web: preload only essentials, defer the rest
		_preload_essentials()
	else:
		# On desktop: everything is local, no special handling needed
		essentials_ready.emit()


## Preload essential (small) assets, then signal readiness.
func _preload_essentials() -> void:
	# Use AssetLoader's built-in category preloaders for icons and heads
	AssetLoader.preload_icons()
	AssetLoader.preload_character_heads()

	# Also preload any UI textures
	var ui_paths: Array = []
	var dir := DirAccess.open(ESSENTIAL_CATEGORIES["ui"])
	if dir:
		_scan_dir(dir, ESSENTIAL_CATEGORIES["ui"], ui_paths, TEXTURE_EXTENSIONS)
	else:
		push_warning("WebLoader: Could not open UI directory '%s', using fallback paths" % ESSENTIAL_CATEGORIES["ui"])
		for p in ESSENTIAL_FALLBACK_PATHS:
			if p.begins_with(ESSENTIAL_CATEGORIES["ui"]) and ResourceLoader.exists(p):
				ui_paths.append(p)
	if not ui_paths.is_empty():
		AssetLoader.preload_batch(ui_paths)

	_loaded_categories["icons"] = true
	_loaded_categories["heads"] = true
	_loaded_categories["ui"] = true

	# Wait one frame for the preload batches to start processing
	await get_tree().process_frame
	essentials_ready.emit()


## Request a deferred category to be loaded. Safe to call multiple times.
## Returns immediately if already loaded.
func ensure_category(category: String) -> void:
	if _loaded_categories.get(category, false):
		return
	if not DEFERRED_CATEGORIES.has(category):
		push_warning("WebLoader: Unknown deferred category: %s" % category)
		return

	_loaded_categories[category] = true
	category_loading.emit(category, true)

	var base_path: String = DEFERRED_CATEGORIES[category]
	var paths: Array = []
	var dir := DirAccess.open(base_path)
	if dir:
		_scan_dir(dir, base_path, paths, ALL_ASSET_EXTENSIONS)
	else:
		push_warning("WebLoader: Could not open deferred directory '%s'" % base_path)

	if not paths.is_empty():
		AssetLoader.preload_batch(paths)
		# Wait for the batch to finish
		await AssetLoader.preload_batch_done

	category_loading.emit(category, false)


## Get a texture through the web-aware path, triggering a category load if needed.
func get_texture_web(path: String, fallback: Texture2D = null) -> Texture2D:
	# If already cached, return immediately
	var cached := AssetLoader.get_texture(path, fallback)
	if cached != fallback or not _is_web:
		return cached

	# On web, the asset might not be downloaded yet — try to identify category
	for cat_name in DEFERRED_CATEGORIES:
		var cat_path: String = DEFERRED_CATEGORIES[cat_name]
		if path.begins_with(cat_path):
			await ensure_category(cat_name)
			return AssetLoader.get_texture(path, fallback)

	# Unknown category, just try to load directly
	return AssetLoader.get_texture(path, fallback)


## Check if a deferred category has been loaded.
func is_category_loaded(category: String) -> bool:
	return _loaded_categories.get(category, false)


## Get loading statistics for debugging / UI display.
func get_web_stats() -> Dictionary:
	var stats := AssetLoader.get_stats()
	stats["is_web"] = _is_web
	stats["loaded_categories"] = _loaded_categories.keys()
	stats["deferred_categories"] = DEFERRED_CATEGORIES.keys()
	return stats


## Recursive directory scanner.
func _scan_dir(dir: DirAccess, base_path: String, out: Array, extensions: Array) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = base_path + "/" + file_name
		if dir.current_is_dir():
			var sub := DirAccess.open(full_path)
			if sub:
				_scan_dir(sub, full_path, out, extensions)
		else:
			for ext in extensions:
				if file_name.ends_with(ext):
					out.append(full_path)
					break
		file_name = dir.get_next()
	dir.list_dir_end()
