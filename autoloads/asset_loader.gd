## asset_loader.gd — Lazy asset loading for Web export
## Autoload singleton. Caches textures on first access to avoid loading
## 1.3GB of assets at startup. Critical for Web builds where all assets
## must be downloaded before use.
extends Node

# Cache of loaded textures: res:// path -> Texture2D
var _cache: Dictionary = {}

# Loading queue for background loading
var _load_queue: Array = []
var _loading: bool = false

# Retry tracking for stuck threaded loads (prevents infinite re-queue)
var _retry_counts: Dictionary = {}  # path -> int (frame count)
const MAX_LOAD_RETRIES: int = 60   # ~1 second at 60fps

# Stats
var _cache_hits: int = 0
var _cache_misses: int = 0

signal asset_loaded(path: String)
signal preload_batch_done(paths: Array)


func _ready() -> void:
	pass


# ═══════════════ SYNCHRONOUS API ═══════════════

func get_texture(path: String, fallback: Texture2D = null) -> Variant:
	## Load and cache a texture. Returns fallback if load fails.
	if _cache.has(path):
		_cache_hits += 1
		return _cache[path]

	_cache_misses += 1
	if not ResourceLoader.exists(path):
		if fallback:
			return fallback
		push_warning("AssetLoader: Resource not found: %s" % path)
		return null

	var tex = load(path)
	if tex is Texture2D:
		_cache[path] = tex
		return tex
	if fallback:
		return fallback
	return null


func get_texture_or_placeholder(path: String, size: Vector2i = Vector2i(64, 64)) -> Texture2D:
	## Load texture, or return a colored placeholder if missing.
	var tex: Texture2D = get_texture(path)
	if tex:
		return tex
	# Generate a placeholder
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.3, 0.5))
	var placeholder := ImageTexture.create_from_image(img)
	_cache[path] = placeholder
	return placeholder


# ═══════════════ BACKGROUND PRELOAD ═══════════════

func preload_batch(paths: Array) -> void:
	## Queue a batch of paths for background loading.
	for p in paths:
		if not _cache.has(p) and p not in _load_queue:
			_load_queue.append(p)
	if not _loading:
		_process_queue()


func _process_queue() -> void:
	_loading = true
	while not _load_queue.is_empty():
		var path: String = _load_queue.pop_front()
		if _cache.has(path):
			continue
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)
			# We'll check completion in _process
		await get_tree().process_frame
		# Check threaded loads
		if ResourceLoader.exists(path):
			var status: int = ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var res = ResourceLoader.load_threaded_get(path)
				if res is Texture2D:
					_cache[path] = res
					asset_loaded.emit(path)
				_retry_counts.erase(path)
			elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				# Track retries to prevent infinite re-queue on stuck resources
				var retries: int = _retry_counts.get(path, 0) + 1
				if retries >= MAX_LOAD_RETRIES:
					push_warning("AssetLoader: Skipping stuck resource after %d retries: %s" % [retries, path])
					_retry_counts.erase(path)
				else:
					_retry_counts[path] = retries
					_load_queue.append(path)
			else:
				# THREAD_LOAD_FAILED or other error status
				push_warning("AssetLoader: Load failed for resource: %s (status=%d)" % [path, status])
				_retry_counts.erase(path)

	_retry_counts.clear()
	_loading = false
	preload_batch_done.emit([])


# ═══════════════ CATEGORY PRELOAD ═══════════════

func preload_icons() -> void:
	## Preload all icon textures (small, needed early).
	var paths: Array = []
	var dir := DirAccess.open("res://assets/icons")
	if dir:
		_scan_dir_recursive(dir, "res://assets/icons", paths, [".png", ".webp"])
	preload_batch(paths)


func preload_character_heads() -> void:
	## Preload character head portraits (needed for UI panels).
	var paths: Array = []
	var dir := DirAccess.open("res://assets/characters/heads")
	if dir:
		_scan_dir_recursive(dir, "res://assets/characters/heads", paths, [".png", ".webp"])
	preload_batch(paths)


func _scan_dir_recursive(dir: DirAccess, base_path: String, out: Array, extensions: Array) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full_path: String = base_path + "/" + file_name
		if dir.current_is_dir():
			var sub := DirAccess.open(full_path)
			if sub:
				_scan_dir_recursive(sub, full_path, out, extensions)
		else:
			for ext in extensions:
				if file_name.ends_with(ext):
					out.append(full_path)
					break
		file_name = dir.get_next()
	dir.list_dir_end()


# ═══════════════ CACHE MANAGEMENT ═══════════════

func clear_cache() -> void:
	## Free all cached textures.
	_cache.clear()
	_cache_hits = 0
	_cache_misses = 0


func evict(path: String) -> void:
	_cache.erase(path)


func evict_category(prefix: String) -> void:
	## Evict all cached textures whose path starts with prefix.
	var to_remove: Array = []
	for key in _cache:
		if key.begins_with(prefix):
			to_remove.append(key)
	for key in to_remove:
		_cache.erase(key)


func get_cache_size() -> int:
	return _cache.size()


func get_stats() -> Dictionary:
	return {
		"cached": _cache.size(),
		"hits": _cache_hits,
		"misses": _cache_misses,
		"queue": _load_queue.size(),
		"loading": _loading,
	}
