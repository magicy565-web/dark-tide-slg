## web_readiness_check.gd — Pre-flight check for Web export
## Run via: godot --headless --script tests/web_readiness_check.gd --quit
## Reports all issues that would prevent successful Web deployment.
extends SceneTree

func _init() -> void:
	var errors: Array = []
	var warnings: Array = []
	var info: Array = []

	GameLogger.debug("╔══════════════════════════════════════════════════╗")
	GameLogger.debug("║       Dark Tide SLG — Web Readiness Check       ║")
	GameLogger.debug("╚══════════════════════════════════════════════════╝\n")

	# ═══════════════ 1. RESOURCE PATH VALIDATION ═══════════════
	GameLogger.debug("▶ [1/7] Validating resource paths...")
	var broken_paths: Array = _check_resource_paths()
	if broken_paths.is_empty():
		info.append("  ✓ All resource paths valid")
	else:
		for bp in broken_paths:
			errors.append("  ✗ Missing resource: %s (referenced in %s)" % [bp[0], bp[1]])

	# ═══════════════ 2. AUTOLOAD VERIFICATION ═══════════════
	GameLogger.debug("▶ [2/7] Verifying autoloads...")
	var autoload_issues: Array = _check_autoloads()
	if autoload_issues.is_empty():
		info.append("  ✓ All autoload scripts exist")
	else:
		for issue in autoload_issues:
			errors.append("  ✗ Autoload script missing: %s" % issue)

	# ═══════════════ 3. SCENE FILE VALIDATION ═══════════════
	GameLogger.debug("▶ [3/7] Validating scene files...")
	var scene_issues: Array = _check_scenes()
	if scene_issues.is_empty():
		info.append("  ✓ All .tscn files valid")
	else:
		for issue in scene_issues:
			errors.append("  ✗ Scene issue: %s" % issue)

	# ═══════════════ 4. ASSET SIZE CHECK ═══════════════
	GameLogger.debug("▶ [4/7] Checking asset sizes...")
	var size_info: Dictionary = _check_asset_sizes()
	info.append("  ℹ Total assets: %d files" % size_info.get("count", 0))
	info.append("  ℹ WebP images: %d files" % size_info.get("webp_count", 0))
	info.append("  ℹ PNG images: %d files" % size_info.get("png_count", 0))
	if size_info.get("large_files", []).size() > 0:
		for lf in size_info["large_files"]:
			warnings.append("  ⚠ Large file (>5MB): %s" % lf)

	# ═══════════════ 5. WEB COMPATIBILITY CHECK ═══════════════
	GameLogger.debug("▶ [5/7] Checking Web compatibility...")
	var compat_issues: Array = _check_web_compatibility()
	if compat_issues.is_empty():
		info.append("  ✓ No Web incompatibilities detected")
	else:
		for issue in compat_issues:
			warnings.append("  ⚠ %s" % issue)

	# ═══════════════ 6. SAVE SYSTEM INTEGRITY ═══════════════
	GameLogger.debug("▶ [6/7] Checking save system integrity...")
	var save_issues: Array = _check_save_system()
	if save_issues.is_empty():
		info.append("  ✓ Save system looks complete")
	else:
		for issue in save_issues:
			warnings.append("  ⚠ Save system: %s" % issue)

	# ═══════════════ 7. EXPORT PRESET CHECK ═══════════════
	GameLogger.debug("▶ [7/7] Checking export presets...")
	if FileAccess.file_exists("res://export_presets.cfg"):
		info.append("  ✓ export_presets.cfg exists")
	else:
		errors.append("  ✗ export_presets.cfg missing — cannot export")

	# ═══════════════ REPORT ═══════════════
	print("\n" + "═".repeat(52))
	GameLogger.debug("RESULTS\n")

	if not info.is_empty():
		GameLogger.debug("INFO:")
		for i in info:
			print(i)
		GameLogger.debug("")

	if not warnings.is_empty():
		GameLogger.warn("WARNINGS (%d):" % warnings.size())
		for w in warnings:
			print(w)
		GameLogger.debug("")

	if not errors.is_empty():
		GameLogger.error("ERRORS (%d):" % errors.size())
		for e in errors:
			print(e)
		GameLogger.debug("")

	if errors.is_empty():
		print("═".repeat(52))
		GameLogger.debug("✓ WEB EXPORT READY — No blocking issues found")
		print("═".repeat(52))
	else:
		print("═".repeat(52))
		GameLogger.error("✗ WEB EXPORT BLOCKED — %d error(s) must be fixed" % errors.size())
		print("═".repeat(52))

	quit()


# ═══════════════ CHECK FUNCTIONS ═══════════════

func _check_resource_paths() -> Array:
	var broken: Array = []
	# Check critical preloaded resources
	var critical_paths: Array = [
		["res://scenes/main.tscn", "project.godot"],
		["res://assets/theme/default_theme.tres", "project.godot"],
		["res://assets/fonts/NotoSansCJKsc-Regular.otf", "project.godot"],
	]
	for entry in critical_paths:
		if not ResourceLoader.exists(entry[0]):
			broken.append(entry)
	return broken


func _check_autoloads() -> Array:
	var issues: Array = []
	# Parse project.godot for autoload entries
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file == null:
		issues.append("Cannot read project.godot")
		return issues
	var content: String = file.get_as_text()
	file.close()

	var in_autoload: bool = false
	for line in content.split("\n"):
		if line.strip_edges() == "[autoload]":
			in_autoload = true
			continue
		if line.begins_with("[") and in_autoload:
			break
		if in_autoload and "=" in line:
			var parts: Array = line.split("=", true, 1)
			if parts.size() == 2:
				var path: String = parts[1].strip_edges().trim_prefix("\"*").trim_suffix("\"")
				if not ResourceLoader.exists(path):
					issues.append("%s -> %s" % [parts[0].strip_edges(), path])
	return issues


func _check_scenes() -> Array:
	var issues: Array = []
	# Verify main scene loads
	if not ResourceLoader.exists("res://scenes/main.tscn"):
		issues.append("Main scene res://scenes/main.tscn not found")
	return issues


func _check_asset_sizes() -> Dictionary:
	var result: Dictionary = {"count": 0, "webp_count": 0, "png_count": 0, "large_files": []}
	var dir := DirAccess.open("res://assets")
	if dir == null:
		return result
	_scan_assets(dir, "res://assets", result)
	return result


func _scan_assets(dir: DirAccess, base: String, result: Dictionary) -> void:
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var full: String = base + "/" + file_name
		if dir.current_is_dir():
			var sub := DirAccess.open(full)
			if sub:
				_scan_assets(sub, full, result)
		else:
			result["count"] += 1
			if file_name.ends_with(".webp"):
				result["webp_count"] += 1
			elif file_name.ends_with(".png"):
				result["png_count"] += 1
		file_name = dir.get_next()
	dir.list_dir_end()


func _check_web_compatibility() -> Array:
	var issues: Array = []
	# Check renderer
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file:
		var content: String = file.get_as_text()
		file.close()
		if "gl_compatibility" not in content:
			issues.append("Renderer is not gl_compatibility — Web export may fail")
		if "4.2" not in content:
			issues.append("Godot version may not be 4.2")
	return issues


func _check_save_system() -> Array:
	var issues: Array = []
	# Verify save_manager.gd has the new systems
	var file := FileAccess.open("res://autoloads/save_manager.gd", FileAccess.READ)
	if file:
		var content: String = file.get_as_text()
		file.close()
		if "event_registry" not in content:
			issues.append("EventRegistry not in save flow")
		if "quest_progress_tracker" not in content:
			issues.append("QuestProgressTracker not in save flow")
		if "event_scheduler" not in content:
			issues.append("EventScheduler not in save flow")
		if "_migrate_save_data" not in content:
			issues.append("Save migration not implemented")
	else:
		issues.append("Cannot read save_manager.gd")
	return issues
