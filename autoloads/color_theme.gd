## color_theme.gd — Centralized UI color, typography, and style factory.
## Autoload singleton: ColorTheme
extends Node

# ═══════════════════════════════════════════════════════════════
#                      COLOR PALETTE
# ═══════════════════════════════════════════════════════════════

# Backgrounds
const BG_PRIMARY := Color(0.06, 0.06, 0.1, 0.92)
const BG_SECONDARY := Color(0.07, 0.06, 0.11, 0.95)
const BG_PANEL := Color(0.06, 0.06, 0.1, 0.88)
const BG_DARK := Color(0.04, 0.04, 0.08, 0.85)
const BG_OVERLAY := Color(0.0, 0.0, 0.0, 0.5)
const BG_COMBAT := Color(0.03, 0.04, 0.08, 0.97)
const BG_CARD := Color(0.10, 0.10, 0.14, 0.85)
const BG_RESULT := Color(0.06, 0.06, 0.1, 0.97)
const BG_VICTORY := Color(0.12, 0.1, 0.02, 0.96)
const BG_DEFEAT := Color(0.15, 0.04, 0.04, 0.96)

# Text
const TEXT_GOLD := Color(1.0, 0.85, 0.35)
const TEXT_NORMAL := Color(0.85, 0.85, 0.78)
const TEXT_DIM := Color(0.75, 0.75, 0.82)
const TEXT_MUTED := Color(0.6, 0.6, 0.65)
const TEXT_WARNING := Color(1.0, 0.4, 0.3)
const TEXT_SUCCESS := Color(0.4, 0.9, 0.4)
const TEXT_HEADING := Color(0.9, 0.85, 0.7)
const TEXT_TITLE := Color(1.0, 0.92, 0.75)
const TEXT_RED := Color(1.0, 0.3, 0.3)
const TEXT_WHITE := Color(1.0, 1.0, 1.0)

# Accent / borders
const ACCENT_GOLD := Color(0.85, 0.7, 0.3)
const ACCENT_GOLD_BRIGHT := Color(1.0, 0.9, 0.4)
const BORDER_DEFAULT := Color(0.5, 0.45, 0.3)
const BORDER_DIM := Color(0.22, 0.22, 0.28)
const BORDER_HIGHLIGHT := Color(0.8, 0.7, 0.4)
const BORDER_VICTORY := Color(0.85, 0.7, 0.3)
const BORDER_DEFEAT := Color(0.8, 0.15, 0.15)
const BORDER_CARD := Color(0.22, 0.22, 0.28)

# Resource label colors
const RES_GOLD := Color.GOLD
const RES_FOOD := Color(0.6, 0.9, 0.4)
const RES_IRON := Color(0.7, 0.7, 0.8)
const RES_SLAVE := Color(0.9, 0.6, 0.3)
const RES_PRESTIGE := Color(1.0, 0.85, 0.3)
const RES_CRYSTAL := Color(0.6, 0.4, 1.0)
const RES_ORDER := Color(0.5, 0.8, 1.0)
const RES_THREAT := Color(1.0, 0.4, 0.3)

# HP bar gradient
const HP_HIGH := Color(0.25, 0.75, 0.3)
const HP_MID := Color(0.85, 0.75, 0.15)
const HP_LOW := Color(0.9, 0.2, 0.15)

# Flash colors
const FLASH_GAIN := Color(1.0, 0.9, 0.2)
const FLASH_LOSS := Color(1.0, 0.2, 0.15)

# Combat side colors
const SIDE_ATTACKER := Color(0.95, 0.7, 0.45)
const SIDE_DEFENDER := Color(0.45, 0.7, 0.95)

# Button colors
const BTN_NORMAL_BG := Color(0.18, 0.15, 0.25, 0.9)
const BTN_HOVER_BG := Color(0.25, 0.2, 0.35, 0.95)
const BTN_PRESSED_BG := Color(0.1, 0.08, 0.15, 0.95)
const BTN_TEXT := Color(0.9, 0.85, 0.7)

# Phase banner
const PHASE_HUMAN := Color(0.95, 0.85, 0.4)
const PHASE_AI := Color(0.8, 0.5, 0.5)
const PHASE_BG := Color(0.06, 0.05, 0.1, 0.92)
const PHASE_BORDER := Color(0.65, 0.55, 0.25)

# March system
const MARCH_PATH_FRIENDLY := Color(0.3, 0.6, 1.0, 0.7)
const MARCH_PATH_ENEMY := Color(0.9, 0.2, 0.15, 0.7)
const MARCH_PATH_GOLD := Color(1.0, 0.85, 0.3, 0.7)
const MARCH_DEST_PULSE := Color(1.0, 0.9, 0.3, 0.6)
const MARCH_CHEVRON := Color(0.3, 0.7, 1.0, 0.9)
const MARCH_DUST := Color(0.6, 0.5, 0.35, 0.5)
const MARCH_SUPPLY_HIGH := Color(0.3, 0.85, 0.3)
const MARCH_SUPPLY_MID := Color(0.85, 0.75, 0.15)
const MARCH_SUPPLY_LOW := Color(0.9, 0.2, 0.15)

# ═══════════════════════════════════════════════════════════════
#                    FACTION COLORS
# ═══════════════════════════════════════════════════════════════

const FACTION_COLORS := {
	"orc": Color(0.9, 0.4, 0.2),
	"pirate": Color(0.4, 0.6, 0.9),
	"dark_elf": Color(0.6, 0.3, 0.8),
	"human": Color(0.3, 0.6, 1.0),
	"high_elf": Color(0.3, 0.9, 0.4),
	"mage": Color(0.7, 0.4, 1.0),
	"neutral": Color(0.7, 0.7, 0.5),
}

# FactionData.FactionID enum indices -> color
const FACTION_ID_COLORS := {
	0: Color(0.6, 0.2, 0.1),   # ORC
	1: Color(0.15, 0.15, 0.4), # PIRATE
	2: Color(0.35, 0.1, 0.45), # DARK_ELF
}

# ═══════════════════════════════════════════════════════════════
#                    FONT SIZES
# ═══════════════════════════════════════════════════════════════

const FONT_TITLE := 28
const FONT_HEADING := 20
const FONT_SUBHEADING := 16
const FONT_BODY := 14
const FONT_SMALL := 11
const FONT_TINY := 9

# ═══════════════════════════════════════════════════════════════
#                    ANIMATION CONSTANTS
# ═══════════════════════════════════════════════════════════════

const ANIM_PANEL_DURATION := 0.2
const ANIM_HOVER_DURATION := 0.12
const ANIM_PULSE_GROW := 0.08
const ANIM_PULSE_SHRINK := 0.15
const ANIM_FLASH_IN := 0.1
const ANIM_FLASH_OUT := 0.35
const HOVER_SCALE := Vector2(1.05, 1.05)
const PRESS_SCALE := Vector2(0.95, 0.95)

# ═══════════════════════════════════════════════════════════════
#              BUTTON TEXTURE CACHE
# ═══════════════════════════════════════════════════════════════

var btn_normal_tex: Texture2D
var btn_hover_tex: Texture2D
var btn_pressed_tex: Texture2D
var btn_danger_tex: Texture2D
var btn_confirm_tex: Texture2D
var _loaded: bool = false


func _ready() -> void:
	_load_btn_textures()


func _load_btn_textures() -> void:
	if _loaded:
		return
	# v2 buttons with fallback to v1
	btn_normal_tex = _safe_tex("res://assets/ui/buttons/btn_action_normal.png")
	if not btn_normal_tex: btn_normal_tex = _safe_tex("res://assets/ui/btn_normal.png")
	btn_hover_tex = _safe_tex("res://assets/ui/buttons/btn_action_hover.png")
	if not btn_hover_tex: btn_hover_tex = _safe_tex("res://assets/ui/btn_hover.png")
	btn_pressed_tex = _safe_tex("res://assets/ui/buttons/btn_action_pressed.png")
	if not btn_pressed_tex: btn_pressed_tex = _safe_tex("res://assets/ui/btn_pressed.png")
	# Specialized button textures
	btn_danger_tex = _safe_tex("res://assets/ui/buttons/btn_danger_normal.png")
	btn_confirm_tex = _safe_tex("res://assets/ui/buttons/btn_confirm_normal.png")
	_loaded = true


func _safe_tex(path: String) -> Variant:
	if ResourceLoader.exists(path):
		return load(path)
	return null


# ═══════════════════════════════════════════════════════════════
#                STYLE FACTORY METHODS
# ═══════════════════════════════════════════════════════════════

func make_panel_style(bg_color: Color = BG_PANEL, border_color: Color = BORDER_DEFAULT, border_width: int = 1, corner_radius: int = 6, content_margin: int = 8) -> StyleBoxFlat:
	var sf := StyleBoxFlat.new()
	sf.bg_color = bg_color
	sf.border_color = border_color
	sf.set_border_width_all(border_width)
	sf.set_corner_radius_all(corner_radius)
	sf.set_content_margin_all(content_margin)
	return sf


func make_button_style_flat(state: String = "normal") -> StyleBoxFlat:
	var sf := StyleBoxFlat.new()
	match state:
		"normal":
			sf.bg_color = BTN_NORMAL_BG
			sf.border_color = BORDER_DEFAULT
		"hover":
			sf.bg_color = BTN_HOVER_BG
			sf.border_color = BORDER_HIGHLIGHT
		"pressed":
			sf.bg_color = BTN_PRESSED_BG
			sf.border_color = BORDER_DEFAULT
	sf.set_border_width_all(1)
	sf.set_corner_radius_all(6)
	sf.set_content_margin_all(6)
	return sf


func make_button_style_textured() -> Dictionary:
	## Returns {"normal": StyleBox, "hover": StyleBox, "pressed": StyleBox}
	var result := {}
	if btn_normal_tex:
		var sn := StyleBoxTexture.new()
		sn.texture = btn_normal_tex
		sn.texture_margin_left = 8; sn.texture_margin_right = 8
		sn.texture_margin_top = 6; sn.texture_margin_bottom = 6
		sn.content_margin_left = 10; sn.content_margin_right = 10
		sn.content_margin_top = 4; sn.content_margin_bottom = 4
		result["normal"] = sn
		if btn_hover_tex:
			var sh := sn.duplicate()
			sh.texture = btn_hover_tex
			result["hover"] = sh
		if btn_pressed_tex:
			var sp := sn.duplicate()
			sp.texture = btn_pressed_tex
			result["pressed"] = sp
	else:
		result["normal"] = make_button_style_flat("normal")
		result["hover"] = make_button_style_flat("hover")
		result["pressed"] = make_button_style_flat("pressed")
	return result


func make_button_style_danger() -> Dictionary:
	## Returns danger-styled button (red glow for war/attack actions)
	var result := {}
	if btn_danger_tex:
		var sn := StyleBoxTexture.new()
		sn.texture = btn_danger_tex
		sn.texture_margin_left = 8; sn.texture_margin_right = 8
		sn.texture_margin_top = 6; sn.texture_margin_bottom = 6
		sn.content_margin_left = 10; sn.content_margin_right = 10
		sn.content_margin_top = 4; sn.content_margin_bottom = 4
		result["normal"] = sn
		if btn_hover_tex:
			var sh := sn.duplicate()
			sh.texture = btn_hover_tex
			result["hover"] = sh
		if btn_pressed_tex:
			var sp := sn.duplicate()
			sp.texture = btn_pressed_tex
			result["pressed"] = sp
	else:
		var sf := make_button_style_flat("normal")
		sf.bg_color = Color(0.3, 0.08, 0.08, 0.9)
		sf.border_color = Color(0.8, 0.2, 0.2)
		result["normal"] = sf
		result["hover"] = make_button_style_flat("hover")
		result["pressed"] = make_button_style_flat("pressed")
	return result


func make_button_style_confirm() -> Dictionary:
	## Returns confirm-styled button (green glow for recruit/confirm actions)
	var result := {}
	if btn_confirm_tex:
		var sn := StyleBoxTexture.new()
		sn.texture = btn_confirm_tex
		sn.texture_margin_left = 8; sn.texture_margin_right = 8
		sn.texture_margin_top = 6; sn.texture_margin_bottom = 6
		sn.content_margin_left = 10; sn.content_margin_right = 10
		sn.content_margin_top = 4; sn.content_margin_bottom = 4
		result["normal"] = sn
		if btn_hover_tex:
			var sh := sn.duplicate()
			sh.texture = btn_hover_tex
			result["hover"] = sh
		if btn_pressed_tex:
			var sp := sn.duplicate()
			sp.texture = btn_pressed_tex
			result["pressed"] = sp
	else:
		var sf := make_button_style_flat("normal")
		sf.bg_color = Color(0.08, 0.25, 0.08, 0.9)
		sf.border_color = Color(0.2, 0.7, 0.3)
		result["normal"] = sf
		result["hover"] = make_button_style_flat("hover")
		result["pressed"] = make_button_style_flat("pressed")
	return result


func make_label(text: String, font_size: int = FONT_BODY, color: Color = TEXT_NORMAL) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func make_title_label(text: String) -> Label:
	return make_label(text, FONT_TITLE, TEXT_TITLE)


func make_heading_label(text: String) -> Label:
	return make_label(text, FONT_HEADING, TEXT_HEADING)


# ═══════════════════════════════════════════════════════════════
#                ANIMATION HELPERS
# ═══════════════════════════════════════════════════════════════

func animate_panel_open(panel: Control) -> void:
	if not is_instance_valid(panel):
		return
	panel.modulate = Color(1, 1, 1, 0)
	var orig_y: float = panel.position.y if not (panel is PanelContainer and panel.offset_top != 0) else panel.offset_top
	var use_offset: bool = panel.anchor_top != 0 or panel.anchor_bottom != 0
	if use_offset:
		panel.offset_top = orig_y + 12
		var tw := panel.create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel, "modulate:a", 1.0, ANIM_PANEL_DURATION).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "offset_top", orig_y, ANIM_PANEL_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		panel.position.y = panel.position.y + 12
		var target_y: float = panel.position.y - 12
		var tw := panel.create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel, "modulate:a", 1.0, ANIM_PANEL_DURATION).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "position:y", target_y, ANIM_PANEL_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func setup_button_hover(btn: Button) -> void:
	## Adds hover scale tween to a button. Safe to call multiple times.
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(_on_btn_hover_in.bind(btn))
	btn.mouse_exited.connect(_on_btn_hover_out.bind(btn))


func _on_btn_hover_in(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", HOVER_SCALE, ANIM_HOVER_DURATION).set_ease(Tween.EASE_OUT)


func _on_btn_hover_out(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, ANIM_HOVER_DURATION).set_ease(Tween.EASE_IN)


func pulse_button(btn: Button) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", PRESS_SCALE, ANIM_PULSE_GROW).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, ANIM_PULSE_SHRINK).set_ease(Tween.EASE_IN)


func flash_label(label: Label, is_gain: bool) -> void:
	if not is_instance_valid(label):
		return
	var flash_color := FLASH_GAIN if is_gain else FLASH_LOSS
	var tw := label.create_tween()
	tw.tween_property(label, "modulate", flash_color, ANIM_FLASH_IN)
	tw.tween_property(label, "modulate", Color.WHITE, ANIM_FLASH_OUT).set_ease(Tween.EASE_OUT)


func hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return HP_HIGH
	elif ratio > 0.3:
		return HP_MID.lerp(HP_HIGH, (ratio - 0.3) / 0.3)
	else:
		return HP_LOW.lerp(HP_MID, ratio / 0.3)


func get_faction_color(faction_name: String) -> Color:
	return FACTION_COLORS.get(faction_name.to_lower(), TEXT_DIM)
