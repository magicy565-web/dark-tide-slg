## formation_preview.gd - Pre-battle popup showing detected formations for both sides.
## Highlights formation clashes and lets the player proceed with "Battle Begin".
extends CanvasLayer
const FormationSystem = preload("res://systems/combat/formation_system.gd")

signal battle_confirmed()
signal battle_cancelled()

# ── Theme colors ──
const BG_COLOR := Color(0.08, 0.06, 0.12, 0.95)
const GOLD := Color(0.85, 0.7, 0.3)
const GOLD_DIM := Color(0.55, 0.45, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.4)
const TEXT_COLOR := Color(0.9, 0.88, 0.82)
const DISABLED_COLOR := Color(0.35, 0.32, 0.28)
const CARD_BG := Color(0.1, 0.08, 0.15)
const CARD_BORDER := Color(0.4, 0.32, 0.18)
const CLASH_RED := Color(0.85, 0.25, 0.25)
const CLASH_YELLOW := Color(0.9, 0.75, 0.15)
const GREEN := Color(0.3, 0.8, 0.35)
const PANEL_WIDTH := 700.0

# ── Formation bonus descriptions (Chinese) ──
const FORMATION_DESCS: Dictionary = {
	0: "前排DEF+3, 后排受伤-50%",          # IRON_WALL
	1: "骑兵首回合ATK×1.5, 践踏士气-20",   # CAVALRY_CHARGE
	2: "弓兵前2回合双重射击, DEF-2",        # ARROW_STORM
	3: "忍者40%绕过前排, 持续2回合",        # SHADOW_STRIKE
	4: "法力回复+2, AoE伤害×1.25",         # ARCANE_BARRAGE
	5: "每回合治疗+1, 前排免疫士气下降",    # HOLY_BASTION
	6: "兽人ATK+2, 每次死亡ATK叠加+1",     # BERSERKER_HORDE
	7: "远程ATK+4, 攻城伤害×2",            # PIRATE_BROADSIDE
	8: "全体ATK/DEF/SPD+1",               # BALANCED_FORCE
	9: "ATK×2, DEF×1.5, SPD+5, 免疫士气",  # LONE_WOLF
}

# ── State ──
var _atk_formations: Array = []
var _def_formations: Array = []
var _clashes: Dictionary = {}
var _atk_hidden: bool = false
var _def_hidden: bool = false

# ── UI refs ──
var root: PanelContainer
var main_vbox: VBoxContainer
var title_label: Label
var columns_hbox: HBoxContainer
var atk_column: VBoxContainer
var def_column: VBoxContainer
var clash_section: VBoxContainer
var confirm_btn: Button
var cancel_btn: Button

func _ready() -> void:
	layer = UILayerRegistry.LAYER_FORMATION_PREVIEW
	visible = false
	_build_ui()

# ═════════════════════════════════════════════════
#                  PUBLIC API
# ═════════════════════════════════════════════════

func show_preview(data: Dictionary) -> void:
	_atk_formations = data.get("atk_formations", [])
	_def_formations = data.get("def_formations", [])
	_clashes = data.get("clashes", {})
	_atk_hidden = data.get("atk_hidden", false)
	_def_hidden = data.get("def_hidden", false)
	visible = true
	_refresh()

func hide_preview() -> void:
	visible = false

# ═════════════════════════════════════════════════
#                   BUILD UI
# ═════════════════════════════════════════════════

func _build_ui() -> void:
	# Dim background
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	root = PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.anchor_left = 0.5; root.anchor_right = 0.5
	root.anchor_top = 0.5; root.anchor_bottom = 0.5
	root.offset_left = -PANEL_WIDTH * 0.5; root.offset_right = PANEL_WIDTH * 0.5
	root.offset_top = -250; root.offset_bottom = 250
	root.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, GOLD, 2))
	add_child(root)

	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	root.add_child(main_vbox)

	# Title
	title_label = Label.new()
	title_label.text = "⚔ 阵型预览 ⚔"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	title_label.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(title_label)

	main_vbox.add_child(_make_hsep())

	# Two columns: attacker | defender
	columns_hbox = HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 20)
	columns_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(columns_hbox)

	atk_column = _build_side_column("进攻方阵型")
	columns_hbox.add_child(atk_column)

	# Vertical separator
	var vsep := VSeparator.new()
	var vs_style := StyleBoxFlat.new()
	vs_style.bg_color = GOLD_DIM
	vs_style.set_content_margin_all(0)
	vs_style.content_margin_left = 1; vs_style.content_margin_right = 1
	vsep.add_theme_stylebox_override("separator", vs_style)
	columns_hbox.add_child(vsep)

	def_column = _build_side_column("防守方阵型")
	columns_hbox.add_child(def_column)

	# Clash section
	clash_section = VBoxContainer.new()
	clash_section.add_theme_constant_override("separation", 4)
	main_vbox.add_child(clash_section)

	main_vbox.add_child(_make_hsep())

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(btn_row)

	cancel_btn = _make_styled_button("撤退", Color(0.5, 0.2, 0.2))
	cancel_btn.custom_minimum_size.x = 120
	cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(cancel_btn)

	confirm_btn = _make_styled_button("开战!", GOLD)
	confirm_btn.custom_minimum_size.x = 160
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)

func _build_side_column(header_text: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)

	var header := Label.new()
	header.text = header_text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", GOLD)
	header.add_theme_font_size_override("font_size", 16)
	col.add_child(header)

	return col

# ═════════════════════════════════════════════════
#                   REFRESH
# ═════════════════════════════════════════════════

func _refresh() -> void:
	_clear_column(atk_column)
	_clear_column(def_column)
	_clear_clash_section()

	# Populate attacker formations
	if _atk_hidden:
		_add_hidden_card(atk_column)
	else:
		_populate_formations(atk_column, _atk_formations, "atk")

	# Populate defender formations
	if _def_hidden:
		_add_hidden_card(def_column)
	else:
		_populate_formations(def_column, _def_formations, "def")

	# Clash highlights
	if not _clashes.is_empty():
		var clash_header := Label.new()
		clash_header.text = "⚡ 阵型克制 ⚡"
		clash_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clash_header.add_theme_color_override("font_color", CLASH_YELLOW)
		clash_header.add_theme_font_size_override("font_size", 15)
		clash_section.add_child(clash_header)

		for key in _clashes:
			var clash_data: Dictionary = _clashes[key]
			_build_clash_card(clash_data)

func _populate_formations(column: VBoxContainer, formations: Array, side: String) -> void:
	if formations.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "未检测到特殊阵型"
		none_lbl.add_theme_color_override("font_color", DISABLED_COLOR)
		none_lbl.add_theme_font_size_override("font_size", 13)
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(none_lbl)
		return

	for fid in formations:
		var fname: String = FormationSystem.FORMATION_NAMES.get(fid, "未知阵型")
		var fdesc: String = FORMATION_DESCS.get(fid, "")

		var card := PanelContainer.new()
		var is_clashed := _is_formation_in_clash(fid, side)
		var border_col: Color = CLASH_RED if is_clashed else CARD_BORDER
		card.add_theme_stylebox_override("panel", _make_panel_style(CARD_BG, border_col, 1 if not is_clashed else 2))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		card.add_child(vb)

		var name_lbl := Label.new()
		name_lbl.text = fname
		name_lbl.add_theme_color_override("font_color", GOLD_BRIGHT if not is_clashed else CLASH_YELLOW)
		name_lbl.add_theme_font_size_override("font_size", 14)
		vb.add_child(name_lbl)

		if fdesc != "":
			var desc_lbl := Label.new()
			desc_lbl.text = fdesc
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_lbl.add_theme_color_override("font_color", TEXT_COLOR)
			desc_lbl.add_theme_font_size_override("font_size", 11)
			vb.add_child(desc_lbl)

		if is_clashed:
			var warn := Label.new()
			warn.text = "⚠ 存在克制"
			warn.add_theme_color_override("font_color", CLASH_RED)
			warn.add_theme_font_size_override("font_size", 10)
			vb.add_child(warn)

		column.add_child(card)

func _add_hidden_card(column: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_panel_style(CARD_BG, CARD_BORDER, 1))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = "??? 情报不足 ???"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", DISABLED_COLOR)
	lbl.add_theme_font_size_override("font_size", 14)
	card.add_child(lbl)
	column.add_child(card)

func _build_clash_card(clash_data: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.06, 0.06), CLASH_RED, 1))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = clash_data.get("effect", "未知效果")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", CLASH_YELLOW)
	lbl.add_theme_font_size_override("font_size", 12)
	card.add_child(lbl)

	clash_section.add_child(card)

func _is_formation_in_clash(fid: int, _side: String) -> bool:
	# Check if this formation is involved in any clash
	for key in _clashes:
		var clash_str: String = key as String
		# Heuristic: known clash keys contain formation type names
		if fid == FormationSystem.FormationID.IRON_WALL and clash_str.find("iron_wall") != -1:
			return true
		if fid == FormationSystem.FormationID.CAVALRY_CHARGE and clash_str.find("cavalry") != -1:
			return true
		if fid == FormationSystem.FormationID.ARROW_STORM and clash_str.find("arrow") != -1:
			return true
		if fid == FormationSystem.FormationID.SHADOW_STRIKE and clash_str.find("shadow") != -1:
			return true
		if fid == FormationSystem.FormationID.ARCANE_BARRAGE and clash_str.find("arcane") != -1:
			return true
		if fid == FormationSystem.FormationID.HOLY_BASTION and clash_str.find("holy") != -1:
			return true
		if fid == FormationSystem.FormationID.BERSERKER_HORDE and clash_str.find("berserker") != -1:
			return true
	return false

# ═════════════════════════════════════════════════
#               INPUT HANDLERS
# ═════════════════════════════════════════════════

func _on_confirm() -> void:
	hide_preview()
	battle_confirmed.emit()

func _on_cancel() -> void:
	hide_preview()
	battle_cancelled.emit()

# ═════════════════════════════════════════════════
#                  CLEANUP
# ═════════════════════════════════════════════════

func _clear_column(col: VBoxContainer) -> void:
	# Keep the header (first child), remove the rest
	var children := col.get_children()
	for i in range(1, children.size()):
		children[i].queue_free()

func _clear_clash_section() -> void:
	for child in clash_section.get_children():
		child.queue_free()

# ═════════════════════════════════════════════════
#                   STYLING
# ═════════════════════════════════════════════════

func _make_panel_style(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	return s

func _make_hsep() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = GOLD_DIM
	s.set_content_margin_all(0)
	s.content_margin_top = 1; s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)
	return sep

func _make_styled_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := _make_panel_style(Color(0.12, 0.1, 0.16), accent, 1)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := _make_panel_style(Color(0.18, 0.14, 0.24), accent.lightened(0.3), 1)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := _make_panel_style(Color(0.08, 0.06, 0.12), accent, 2)
	pressed.set_content_margin_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	btn.add_theme_font_size_override("font_size", 16)
	return btn
