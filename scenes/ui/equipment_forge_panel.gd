## equipment_forge_panel.gd — Equipment Forge UI panel for 暗潮 SLG
## Code-only CanvasLayer. Hotkey: J to toggle, ESC to close.
## Uses EquipmentForge autoload for all data/operations.
extends CanvasLayer

# ═══════════════════════════════════════════════════════════════
#                       CONSTANTS
# ═══════════════════════════════════════════════════════════════

const COLOR_BLUE := Color(0.3, 0.55, 1.0)
const COLOR_GREEN := Color(0.35, 0.85, 0.35)
const COLOR_GRAY := Color(0.45, 0.45, 0.5)

const TYPE_ICONS: Dictionary = {
	"weapon": "⚔", "armor": "🛡", "accessory": "💎",
}

const PASSIVE_NAMES: Dictionary = {
	"burn_on_hit": "灼烧打击", "stealth_first_turn": "首回合隐身",
	"revive_once": "不死鸟复活", "cleave_aoe": "范围劈斩",
	"fear_aura": "恐惧光环", "mind_control": "精神支配",
}

const RES_ICONS: Dictionary = {
	"gold": "●", "iron": "◆", "crystal": "✦",
	"horse": "♞", "gunpowder": "✸", "shadow": "◈",
}

const RES_COLORS: Dictionary = {
	"gold": Color(1.0, 0.85, 0.35),
	"iron": Color(0.55, 0.6, 0.75),
	"crystal": Color(0.6, 0.4, 1.0),
	"horse": Color(0.65, 0.45, 0.25),
	"gunpowder": Color(1.0, 0.6, 0.2),
	"shadow": Color(0.45, 0.2, 0.6),
}

# ═══════════════════════════════════════════════════════════════
#                         STATE
# ═══════════════════════════════════════════════════════════════

var _visible: bool = false
var _selected_recipe_id: String = ""
var _pulse_time: float = 0.0
var _pulse_bars: Array = []

# ═══════════════════════════════════════════════════════════════
#                      UI REFERENCES
# ═══════════════════════════════════════════════════════════════

var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var forge_level_label: Label
var btn_close: Button
var left_scroll: ScrollContainer
var left_container: VBoxContainer
var right_scroll: ScrollContainer
var right_container: VBoxContainer

# ═══════════════════════════════════════════════════════════════
#                       LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_INFO_PANELS
	_build_ui()
	hide_panel()

func _process(delta: float) -> void:
	if not _visible:
		return
	_pulse_time += delta
	for bar_data in _pulse_bars:
		if is_instance_valid(bar_data["bar"]):
			bar_data["bar"].modulate.a = 0.6 + 0.4 * sin(_pulse_time * 4.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_game_active():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_J:
			if _visible:
				hide_panel()
			else:
				show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()


func _is_game_active() -> bool:
	var gm = get_node_or_null("/root/GameManager")
	if gm and "game_active" in gm:
		return gm.game_active
	return true

# ═══════════════════════════════════════════════════════════════
#                    SHOW / HIDE / TOGGLE
# ═══════════════════════════════════════════════════════════════

func show_panel() -> void:
	_visible = true
	root.visible = true
	_selected_recipe_id = ""
	_refresh_all()
	ColorTheme.animate_panel_open(main_panel)

func hide_panel() -> void:
	if _visible:
		_play_sound("cancel")
	_visible = false
	root.visible = false
	_pulse_bars.clear()

func is_panel_visible() -> bool:
	return _visible

# ═══════════════════════════════════════════════════════════════
#                        BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "EquipmentForgeRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dim background
	dim_bg = ColorRect.new()
	dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_bg.color = ColorTheme.BG_OVERLAY
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	# Main centered panel (700x500)
	main_panel = PanelContainer.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_panel.custom_minimum_size = Vector2(700, 500)
	main_panel.size = Vector2(700, 500)
	main_panel.position = Vector2(-350, -250)  # centered via anchor
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ColorTheme.BG_SECONDARY
	panel_style.border_color = ColorTheme.BORDER_DEFAULT
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(12)
	main_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# ── Header row ──
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(header_row)

	header_label = Label.new()
	header_label.text = "装备锻造"
	header_label.add_theme_font_size_override("font_size", ColorTheme.FONT_TITLE)
	header_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	header_row.add_child(header_label)

	forge_level_label = Label.new()
	forge_level_label.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	forge_level_label.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	forge_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(forge_level_label)

	btn_close = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	outer_vbox.add_child(HSeparator.new())

	# ── Content: left (recipes) + right (detail) ──
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 8)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)

	_build_left_panel(content_hbox)
	content_hbox.add_child(VSeparator.new())
	_build_right_panel(content_hbox)


func _build_left_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.add_theme_stylebox_override("panel", _make_sub_panel_style())
	parent.add_child(panel)

	left_scroll = ScrollContainer.new()
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(left_scroll)

	left_container = VBoxContainer.new()
	left_container.add_theme_constant_override("separation", 3)
	left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left_container)

func _build_right_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_sub_panel_style())
	parent.add_child(panel)

	right_scroll = ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(right_scroll)

	right_container = VBoxContainer.new()
	right_container.add_theme_constant_override("separation", 6)
	right_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_container)

func _make_sub_panel_style() -> StyleBoxFlat:
	var sf := StyleBoxFlat.new()
	sf.bg_color = ColorTheme.BG_DARK
	sf.border_color = ColorTheme.BORDER_DIM
	sf.set_border_width_all(1)
	sf.set_corner_radius_all(6)
	sf.set_content_margin_all(8)
	return sf

# ═══════════════════════════════════════════════════════════════
#                      REFRESH ALL
# ═══════════════════════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_header()
	_refresh_recipe_list()
	_refresh_detail()

func _refresh_header() -> void:
	var forge = get_node_or_null("/root/EquipmentForge")
	if not forge:
		forge_level_label.text = "锻造炉 Lv.?"
		return
	var pid := _get_player_id()
	var level: int = forge.get_forge_level(pid)
	var unclaimed: int = forge.get_unclaimed_count(pid)
	var text := "锻造炉 Lv.%d" % level
	if unclaimed > 0:
		text += "  |  未领取: %d" % unclaimed
	forge_level_label.text = text

# ═══════════════════════════════════════════════════════════════
#                  LEFT: RECIPE LIST
# ═══════════════════════════════════════════════════════════════

func _refresh_recipe_list() -> void:
	_clear_children(left_container)
	var forge = get_node_or_null("/root/EquipmentForge")
	if not forge:
		var err_lbl := Label.new()
		err_lbl.text = "锻造系统未加载"
		err_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		err_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
		left_container.add_child(err_lbl)
		return

	var pid := _get_player_id()
	var all_displays: Array = forge.get_all_recipe_displays(pid)
	var crafted_items: Array = forge.get_crafted_items(pid) if forge.has_method("get_crafted_items") else []

	# Group by type
	var groups: Dictionary = {"weapon": [], "armor": [], "accessory": []}
	for display in all_displays:
		var t: String = display.get("type", "")
		if groups.has(t):
			groups[t].append(display)

	var group_labels: Dictionary = {"weapon": "武器", "armor": "防具", "accessory": "饰品"}
	for type_key in ["weapon", "armor", "accessory"]:
		var items: Array = groups[type_key]
		if items.is_empty():
			continue

		# Group header
		var group_lbl := Label.new()
		group_lbl.text = "── %s %s ──" % [TYPE_ICONS.get(type_key, "?"), group_labels[type_key]]
		group_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		group_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
		group_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		left_container.add_child(group_lbl)

		for display in items:
			var recipe_id: String = display.get("id", "")
			var recipe_name: String = display.get("name", recipe_id)
			var is_available: bool = display.get("available", false)
			var in_queue: bool = display.get("in_queue", false)
			var is_crafted: bool = recipe_id in crafted_items
			var is_legendary: bool = display.get("legendary", false)

			# Determine status color
			var status_color: Color
			var status_suffix: String = ""
			if is_crafted:
				status_color = COLOR_GREEN
				status_suffix = " ✓"
			elif in_queue:
				status_color = COLOR_BLUE
				status_suffix = " ..."
			elif is_available:
				status_color = ColorTheme.TEXT_GOLD
			else:
				status_color = COLOR_GRAY

			var btn := Button.new()
			var icon_char: String = TYPE_ICONS.get(display.get("type", ""), "?")
			var legend_mark: String = "★" if is_legendary else ""
			btn.text = " %s%s %s%s" % [legend_mark, icon_char, recipe_name, status_suffix]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
			btn.custom_minimum_size = Vector2(260, 30)

			var btn_style := StyleBoxFlat.new()
			if recipe_id == _selected_recipe_id:
				btn_style.bg_color = Color(status_color.r, status_color.g, status_color.b, 0.25)
				btn_style.border_color = status_color
				btn_style.set_border_width_all(2)
			else:
				btn_style.bg_color = ColorTheme.BTN_NORMAL_BG
				btn_style.border_color = Color(status_color.r, status_color.g, status_color.b, 0.3)
				btn_style.set_border_width_all(1)
			btn_style.set_corner_radius_all(4)
			btn_style.set_content_margin_all(4)
			btn.add_theme_stylebox_override("normal", btn_style)

			var hover_style := btn_style.duplicate()
			hover_style.bg_color = Color(status_color.r, status_color.g, status_color.b, 0.18)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_color_override("font_color", status_color)
			btn.pressed.connect(_on_recipe_selected.bind(recipe_id))
			left_container.add_child(btn)

		# Spacer between groups
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		left_container.add_child(spacer)

func _refresh_detail() -> void:
	_clear_children(right_container)
	_pulse_bars.clear()

	var forge = get_node_or_null("/root/EquipmentForge")
	var pid := _get_player_id()

	# If no recipe selected, show hint + queue + upgrade section
	if _selected_recipe_id == "" or forge == null:
		var hint := Label.new()
		hint.text = "选择左侧配方查看详情" if forge != null else "锻造系统未加载"
		hint.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		hint.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_container.add_child(hint)
		if forge != null:
			_build_queue_section(forge, pid)
			_build_upgrade_section(forge, pid)
		return

	# ── Selected recipe detail ──
	var display: Dictionary = forge.get_recipe_display(_selected_recipe_id)
	if display.is_empty():
		return

	var check: Dictionary = forge.can_craft(pid, _selected_recipe_id)
	var is_legendary: bool = display.get("legendary", false)

	# Recipe name card
	var name_card := PanelContainer.new()
	var card_border := ColorTheme.ACCENT_GOLD_BRIGHT if is_legendary else ColorTheme.BORDER_DEFAULT
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = ColorTheme.BG_CARD
	card_style.border_color = card_border
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(10)
	name_card.add_theme_stylebox_override("panel", card_style)
	right_container.add_child(name_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	name_card.add_child(card_vbox)

	# Name row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	card_vbox.add_child(name_row)

	var icon_lbl := Label.new()
	icon_lbl.text = TYPE_ICONS.get(display.get("type", ""), "?")
	icon_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
	name_row.add_child(icon_lbl)

	if is_legendary:
		var star_lbl := Label.new()
		star_lbl.text = "★"
		star_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
		star_lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
		name_row.add_child(star_lbl)

	var name_lbl := Label.new()
	name_lbl.text = display.get("name", "")
	name_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
	name_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_TITLE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	var type_lbl := Label.new()
	var slot_names: Dictionary = {"weapon": "武器", "body": "防具", "accessory": "饰品"}
	type_lbl.text = slot_names.get(display.get("slot", ""), display.get("type", ""))
	type_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	type_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	name_row.add_child(type_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = display.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	desc_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(desc_lbl)

	# Stat bonuses
	var stats: Dictionary = display.get("stats", {})
	if not stats.is_empty():
		var stat_text := "属性加成: "
		var parts: Array = []
		for stat_key in stats:
			var val = stats[stat_key]
			var prefix: String = "+" if val > 0 else ""
			parts.append("%s%s%s" % [stat_key.to_upper(), prefix, str(val)])
		stat_text += " / ".join(parts)
		var stat_lbl := Label.new()
		stat_lbl.text = stat_text
		stat_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		stat_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS)
		card_vbox.add_child(stat_lbl)

	# Passive ability
	var passive_key: String = display.get("passive", "")
	if passive_key != "":
		var passive_lbl := Label.new()
		var passive_name: String = PASSIVE_NAMES.get(passive_key, passive_key)
		passive_lbl.text = "被动技能: %s" % passive_name
		passive_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		passive_lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
		card_vbox.add_child(passive_lbl)

	# Prerequisite info
	var prereq_name: String = display.get("prereq_name", "")
	if prereq_name != "":
		var prereq_lbl := Label.new()
		prereq_lbl.text = "前置配方: %s" % prereq_name
		prereq_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		prereq_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
		card_vbox.add_child(prereq_lbl)

	# Forge level requirement
	var req_level: int = display.get("forge_level_req", 1)
	var forge_lbl := Label.new()
	forge_lbl.text = "需要锻造炉等级: %d" % req_level
	forge_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	forge_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	card_vbox.add_child(forge_lbl)

	right_container.add_child(HSeparator.new())

	# ── Cost breakdown ──
	var cost_header := Label.new()
	cost_header.text = "锻造费用"
	cost_header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	cost_header.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
	right_container.add_child(cost_header)

	var cost: Dictionary = display.get("cost", {})
	var missing: Dictionary = check.get("missing_resources", {})
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 12)
	right_container.add_child(cost_row)

	for res_key in cost:
		var res_lbl := Label.new()
		var icon_char: String = RES_ICONS.get(res_key, "?")
		var amount: int = cost[res_key]
		var is_missing: bool = missing.has(res_key)
		var lbl_color: Color = ColorTheme.TEXT_WARNING if is_missing else RES_COLORS.get(res_key, ColorTheme.TEXT_NORMAL)
		var suffix: String = " (缺%d)" % missing[res_key] if is_missing else ""
		res_lbl.text = "%s %s: %d%s" % [icon_char, res_key, amount, suffix]
		res_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		res_lbl.add_theme_color_override("font_color", lbl_color)
		cost_row.add_child(res_lbl)

	var turns_lbl := Label.new()
	turns_lbl.text = "锻造回合: %d" % display.get("turns", 1)
	turns_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	turns_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	right_container.add_child(turns_lbl)

	# ── Craft button ──
	var can_do: bool = check.get("can_craft", false)
	var reason: String = check.get("reason", "")

	var craft_btn := Button.new()
	craft_btn.text = "开始锻造" if can_do else "无法锻造"
	craft_btn.custom_minimum_size = Vector2(200, 36)
	craft_btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	craft_btn.disabled = not can_do

	var cb_style := StyleBoxFlat.new()
	if can_do:
		cb_style.bg_color = Color(0.08, 0.25, 0.08, 0.9)
		cb_style.border_color = Color(0.2, 0.7, 0.3)
	else:
		cb_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
		cb_style.border_color = COLOR_GRAY
	cb_style.set_border_width_all(1)
	cb_style.set_corner_radius_all(4)
	cb_style.set_content_margin_all(6)
	craft_btn.add_theme_stylebox_override("normal", cb_style)
	craft_btn.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS if can_do else COLOR_GRAY)
	if can_do:
		craft_btn.pressed.connect(_on_start_crafting.bind(_selected_recipe_id))
	right_container.add_child(craft_btn)

	if not can_do and reason != "":
		var reason_lbl := Label.new()
		reason_lbl.text = reason
		reason_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		reason_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
		reason_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right_container.add_child(reason_lbl)

	right_container.add_child(HSeparator.new())

	# ── Queue + Upgrade sections ──
	_build_queue_section(forge, pid)
	_build_upgrade_section(forge, pid)

# placeholder: callbacks
func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()


func _on_recipe_selected(recipe_id: String) -> void:
	_selected_recipe_id = recipe_id
	_play_sound("click")
	_refresh_all()

func _on_start_crafting(recipe_id: String) -> void:
	var forge = get_node_or_null("/root/EquipmentForge")
	if not forge: return
	if forge.start_crafting(_get_player_id(), recipe_id):
		_play_sound("confirm")
		_emit_debug("started crafting %s" % recipe_id)
	_refresh_all()

func _on_cancel_crafting(queue_index: int) -> void:
	var forge = get_node_or_null("/root/EquipmentForge")
	if not forge: return
	if forge.cancel_crafting(_get_player_id(), queue_index):
		_play_sound("cancel")
		_emit_debug("cancelled queue item %d" % queue_index)
	_refresh_all()

func _on_upgrade_forge() -> void:
	var forge = get_node_or_null("/root/EquipmentForge")
	if not forge: return
	if forge.upgrade_forge(_get_player_id()):
		_play_sound("confirm")
		_emit_debug("forge upgraded")
	_refresh_all()

func _on_claim_unclaimed() -> void:
	var forge = get_node_or_null("/root/EquipmentForge")
	if not forge: return
	var claimed: int = forge.claim_unclaimed_items(_get_player_id())
	if claimed > 0:
		_play_sound("confirm")
		_emit_debug("claimed %d items" % claimed)
	_refresh_all()

# ═══════════════════════════════════════════════════════════════
#              QUEUE SECTION (shown in right panel)
# ═══════════════════════════════════════════════════════════════

func _build_queue_section(forge: Node, pid: int) -> void:
	var queue_header := Label.new()
	queue_header.text = "锻造队列"
	queue_header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	queue_header.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
	right_container.add_child(queue_header)

	var queue: Array = forge.get_forge_queue(pid)
	if queue.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "队列为空 (最多%d项)" % forge.MAX_QUEUE_SIZE
		empty_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		empty_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		right_container.add_child(empty_lbl)
	else:
		for i in range(queue.size()):
			var entry: Dictionary = queue[i]
			_build_queue_item(entry, i)

	# Unclaimed items button
	var unclaimed: int = forge.get_unclaimed_count(pid)
	if unclaimed > 0:
		var claim_btn := Button.new()
		claim_btn.text = "领取完成品 (%d)" % unclaimed
		claim_btn.custom_minimum_size = Vector2(180, 30)
		claim_btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.2, 0.08, 0.9)
		cs.border_color = COLOR_GREEN
		cs.set_border_width_all(1)
		cs.set_corner_radius_all(4)
		cs.set_content_margin_all(4)
		claim_btn.add_theme_stylebox_override("normal", cs)
		claim_btn.add_theme_color_override("font_color", COLOR_GREEN)
		claim_btn.pressed.connect(_on_claim_unclaimed)
		right_container.add_child(claim_btn)

func _build_queue_item(entry: Dictionary, queue_index: int) -> void:
	var is_legendary: bool = entry.get("legendary", false)
	var border_col: Color = ColorTheme.ACCENT_GOLD_BRIGHT if is_legendary else COLOR_BLUE
	var item_card := PanelContainer.new()
	var cs := _make_bordered_style(Color(border_col.r, border_col.g, border_col.b, 0.1), Color(border_col.r, border_col.g, border_col.b, 0.6))
	item_card.add_theme_stylebox_override("panel", cs)
	right_container.add_child(item_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	item_card.add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)
	var type_icon: String = TYPE_ICONS.get(entry.get("type", ""), "?")
	var name_text := "%s%s %s" % ["★" if is_legendary else "", type_icon, entry.get("name", "?")]
	var q_name := _make_label(name_text, ColorTheme.FONT_BODY, ColorTheme.TEXT_NORMAL)
	q_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(q_name)
	row.add_child(_make_label("剩余%d回合" % entry.get("remaining", 0), ColorTheme.FONT_SMALL, COLOR_BLUE))

	var progress: int = entry.get("progress", 0)
	var total: int = entry.get("total_turns", 1)
	var bar := ProgressBar.new()
	bar.min_value = 0; bar.max_value = total; bar.value = progress
	bar.custom_minimum_size = Vector2(0, 12); bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.15); bar_bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = COLOR_BLUE; bar_fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(bar)
	_pulse_bars.append({"bar": bar})

	var cancel_btn := Button.new()
	cancel_btn.text = "取消 (退50%%)"
	cancel_btn.custom_minimum_size = Vector2(120, 24)
	cancel_btn.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	var cb_s := _make_bordered_style(Color(0.25, 0.08, 0.08, 0.9), Color(0.7, 0.2, 0.2))
	cancel_btn.add_theme_stylebox_override("normal", cb_s)
	cancel_btn.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
	cancel_btn.pressed.connect(_on_cancel_crafting.bind(queue_index))
	vbox.add_child(cancel_btn)

# ═══════════════════════════════════════════════════════════════
#             UPGRADE SECTION (shown in right panel)
# ═══════════════════════════════════════════════════════════════

func _build_upgrade_section(forge: Node, pid: int) -> void:
	right_container.add_child(HSeparator.new())
	right_container.add_child(_make_label("锻造炉升级", ColorTheme.FONT_SUBHEADING, ColorTheme.TEXT_HEADING))

	var current_level: int = forge.get_forge_level(pid)
	var max_level: int = forge.MAX_FORGE_LEVEL
	right_container.add_child(_make_label("当前等级: %d / %d" % [current_level, max_level], ColorTheme.FONT_BODY, ColorTheme.TEXT_NORMAL))

	if current_level >= max_level:
		right_container.add_child(_make_label("已达到最高等级", ColorTheme.FONT_BODY, ColorTheme.TEXT_SUCCESS))
		return

	var target_level: int = current_level + 1
	var upgrade_cost: Dictionary = forge.FORGE_UPGRADE_COST.get(target_level, {})
	if not upgrade_cost.is_empty():
		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 10)
		right_container.add_child(cost_row)
		cost_row.add_child(_make_label("升级至Lv.%d:" % target_level, ColorTheme.FONT_SMALL, ColorTheme.TEXT_DIM))
		var rm = get_node_or_null("/root/ResourceManager")
		for res_key in upgrade_cost:
			var needed: int = upgrade_cost[res_key]
			var have: int = rm.get_resource(pid, res_key) if rm and rm.has_method("get_resource") else 0
			var col: Color = ColorTheme.TEXT_WARNING if have < needed else RES_COLORS.get(res_key, ColorTheme.TEXT_NORMAL)
			cost_row.add_child(_make_label("%s%d" % [RES_ICONS.get(res_key, "?"), needed], ColorTheme.FONT_SMALL, col))

	var can_upgrade: bool = false
	var rm_check = get_node_or_null("/root/ResourceManager")
	if rm_check and rm_check.has_method("can_afford") and not upgrade_cost.is_empty():
		can_upgrade = rm_check.can_afford(pid, upgrade_cost)

	var upgrade_btn := Button.new()
	upgrade_btn.text = "升级锻造炉" if can_upgrade else "资源不足"
	upgrade_btn.custom_minimum_size = Vector2(180, 32)
	upgrade_btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	upgrade_btn.disabled = not can_upgrade
	var ub_bg := Color(0.15, 0.12, 0.02, 0.9) if can_upgrade else Color(0.15, 0.15, 0.15, 0.8)
	var ub_border := ColorTheme.ACCENT_GOLD if can_upgrade else COLOR_GRAY
	upgrade_btn.add_theme_stylebox_override("normal", _make_bordered_style(ub_bg, ub_border))
	upgrade_btn.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT if can_upgrade else COLOR_GRAY)
	if can_upgrade:
		upgrade_btn.pressed.connect(_on_upgrade_forge)
	right_container.add_child(upgrade_btn)

# ═══════════════════════════════════════════════════════════════
#                        HELPERS
# ═══════════════════════════════════════════════════════════════

func _get_player_id() -> int:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_human_player_id"):
		return gm.get_human_player_id()
	return 0

func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_bordered_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sf := StyleBoxFlat.new()
	sf.bg_color = bg; sf.border_color = border
	sf.set_border_width_all(1); sf.set_corner_radius_all(4); sf.set_content_margin_all(4)
	return sf

func _play_sound(sound_type: String) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if not am:
		return
	match sound_type:
		"cancel":
			if am.has_method("play_ui_cancel"):
				am.play_ui_cancel()
		"confirm":
			if am.has_method("play_ui_confirm"):
				am.play_ui_confirm()
		"click":
			if am.has_method("play_ui_click"):
				am.play_ui_click()


func _emit_debug(msg: String) -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("debug_log"):
		eb.debug_log.emit("info", "EquipmentForgePanel: %s" % msg)
