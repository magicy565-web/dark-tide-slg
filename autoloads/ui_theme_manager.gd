## ui_theme_manager.gd — Shared HD UI frame provider for all panels.
## Autoload singleton: UITheme
extends Node

# HD frame textures (loaded once, shared across all UI scripts)
var frame_top_bar: Texture2D
var frame_info_panel: Texture2D
var frame_content: Texture2D
var frame_parchment: Texture2D
var frame_action_bar: Texture2D
var frame_item_slot_normal: Texture2D
var frame_item_slot_selected: Texture2D

var _loaded: bool = false


func _ready() -> void:
	_load_frames()


func _load_frames() -> void:
	if _loaded:
		return
	frame_top_bar = _safe_tex("res://assets/ui/frames/top_bar_frame.png")
	frame_info_panel = _safe_tex("res://assets/ui/frames/info_panel_frame.png")
	frame_content = _safe_tex("res://assets/ui/frames/content_panel_frame.png")
	frame_parchment = _safe_tex("res://assets/ui/frames/parchment_bg.png")
	frame_action_bar = _safe_tex("res://assets/ui/frames/inventory_bar_frame.png")
	frame_item_slot_normal = _safe_tex("res://assets/ui/frames/item_slot_normal.png")
	frame_item_slot_selected = _safe_tex("res://assets/ui/frames/item_slot_selected.png")
	_loaded = true


func _safe_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


# ── Style factory methods ──

func make_frame_style(tex: Texture2D, tex_margin: Array, content_margin: Array, fallback_color: Color) -> StyleBox:
	## Build a StyleBoxTexture from an HD frame, or fall back to StyleBoxFlat.
	if tex:
		var stex := StyleBoxTexture.new()
		stex.texture = tex
		stex.texture_margin_left = tex_margin[0]
		stex.texture_margin_top = tex_margin[1]
		stex.texture_margin_right = tex_margin[2]
		stex.texture_margin_bottom = tex_margin[3]
		stex.content_margin_left = content_margin[0]
		stex.content_margin_top = content_margin[1]
		stex.content_margin_right = content_margin[2]
		stex.content_margin_bottom = content_margin[3]
		return stex
	var sf := StyleBoxFlat.new()
	sf.bg_color = fallback_color
	sf.set_corner_radius_all(6)
	sf.set_content_margin_all(8)
	return sf


func make_top_bar_style() -> StyleBox:
	return make_frame_style(frame_top_bar,
		[60, 30, 60, 20], [70, 14, 70, 8],
		Color(0.06, 0.06, 0.1, 0.92))


func make_info_panel_style() -> StyleBox:
	return make_frame_style(frame_info_panel,
		[30, 50, 30, 20], [20, 45, 20, 12],
		Color(0.06, 0.08, 0.12, 0.9))


func make_content_style() -> StyleBox:
	return make_frame_style(frame_content,
		[25, 20, 25, 30], [14, 12, 14, 16],
		Color(0.06, 0.06, 0.1, 0.88))


func make_action_bar_style() -> StyleBox:
	return make_frame_style(frame_action_bar,
		[30, 40, 30, 20], [16, 30, 16, 10],
		Color(0.06, 0.06, 0.1, 0.88))


func make_parchment_style() -> StyleBox:
	return make_frame_style(frame_parchment,
		[8, 8, 8, 8], [10, 10, 10, 10],
		Color(0.04, 0.04, 0.08, 0.85))


func make_dark_panel_style(alpha: float = 0.9) -> StyleBox:
	## Generic dark panel with golden border — used by detail panels, popups, etc.
	return make_frame_style(frame_content,
		[25, 20, 25, 30], [14, 12, 14, 16],
		Color(0.06, 0.06, 0.1, alpha))
