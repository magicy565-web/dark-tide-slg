## troop_training_panel.gd — Troop ability training panel for Dark Tide SLG
## Players spend gold + resources + turns to unlock abilities for their troops.
## Code-only UI (no .tscn). Hotkey: U to toggle, ESC to close.
extends CanvasLayer

# ═══════════════════════════════════════════════════════════════
#                         ENUMS
# ═══════════════════════════════════════════════════════════════

enum TrainStatus { LOCKED, AVAILABLE, TRAINING, COMPLETED }

const SLOT_LABELS: Array = ["基础训练 Basic", "进阶训练 Advanced", "精通训练 Mastery"]

# ═══════════════════════════════════════════════════════════════
#                   RESOURCE COLORS
# ═══════════════════════════════════════════════════════════════

const RES_COLORS: Dictionary = {
	"gold": Color(1.0, 0.85, 0.35),
	"iron": Color(0.55, 0.6, 0.75),
	"crystal": Color(0.6, 0.4, 1.0),
	"horse": Color(0.65, 0.45, 0.25),
	"gunpowder": Color(1.0, 0.6, 0.2),
	"shadow": Color(0.45, 0.2, 0.6),
}

const RES_ICONS: Dictionary = {
	"gold": "●", "iron": "◆", "crystal": "✦",
	"horse": "♞", "gunpowder": "✸", "shadow": "◈",
}

# ═══════════════════════════════════════════════════════════════
#                   FACTION TROOP GROUPS
# ═══════════════════════════════════════════════════════════════

const FACTION_TROOP_GROUPS: Dictionary = {
	"orc": {
		"label": "兽人部落",
		"troops": ["orc_ashigaru", "orc_samurai", "orc_cavalry"],
	},
	"pirate": {
		"label": "暗夜海盗",
		"troops": ["pirate_ashigaru", "pirate_archer", "pirate_cannon"],
	},
	"dark_elf": {
		"label": "暗精灵议会",
		"troops": ["de_samurai", "de_ninja", "de_cavalry"],
	},
}

# ═══════════════════════════════════════════════════════════════
#              TROOP TRAINING DEFINITIONS (inline data)
# ═══════════════════════════════════════════════════════════════
# TROOP_TRAINING_DEFS section — filled below
const TROOP_TRAINING_DEFS: Dictionary = {
	"orc_ashigaru": [
		{"name": "蛮力冲击", "desc": "ATK+2", "icon": "⚔", "cost": {"gold": 80}, "turns": 1, "effects": {"atk": 2}},
		{"name": "战吼", "desc": "全队ATK+1", "icon": "📯", "cost": {"gold": 200, "iron": 2}, "turns": 2, "effects": {"team_atk": 1}},
		{"name": "狂暴", "desc": "HP<50%时ATK×1.5", "icon": "🔥", "cost": {"gold": 400, "crystal": 1}, "turns": 3, "effects": {"low_hp_atk_mult": 1.5}},
	],
	"orc_samurai": [
		{"name": "重甲", "desc": "DEF+3", "icon": "🛡", "cost": {"gold": 100}, "turns": 1, "effects": {"def": 3}},
		{"name": "反击", "desc": "30%反伤", "icon": "⚡", "cost": {"gold": 250, "iron": 3}, "turns": 2, "effects": {"counter_pct": 0.30}},
		{"name": "不屈", "desc": "一次免死", "icon": "💀", "cost": {"gold": 500, "crystal": 2}, "turns": 3, "effects": {"death_save": 1}},
	],
	"orc_cavalry": [
		{"name": "冲锋", "desc": "首击ATK+4", "icon": "🐗", "cost": {"gold": 120}, "turns": 1, "effects": {"first_strike_atk": 4}},
		{"name": "践踏", "desc": "击杀后再动", "icon": "💨", "cost": {"gold": 300, "horse": 1}, "turns": 2, "effects": {"kill_extra_action": true}},
		{"name": "铁骑", "desc": "忽略地形", "icon": "🏔", "cost": {"gold": 600, "horse": 2}, "turns": 4, "effects": {"ignore_terrain": true}},
	],
	"pirate_ashigaru": [
		{"name": "走私", "desc": "DEF+2", "icon": "📦", "cost": {"gold": 60}, "turns": 1, "effects": {"def": 2}},
		{"name": "逃脱", "desc": "40%闪避", "icon": "💨", "cost": {"gold": 180, "iron": 2}, "turns": 2, "effects": {"evasion_pct": 0.40}},
		{"name": "海上恐惧", "desc": "敌ATK-3", "icon": "☠", "cost": {"gold": 350, "gunpowder": 1}, "turns": 3, "effects": {"enemy_atk_debuff": 3}},
	],
	"pirate_archer": [
		{"name": "精准", "desc": "ATK+2", "icon": "🎯", "cost": {"gold": 80}, "turns": 1, "effects": {"atk": 2}},
		{"name": "齐射", "desc": "AoE半伤", "icon": "🏹", "cost": {"gold": 220, "gunpowder": 2}, "turns": 2, "effects": {"aoe_half": true}},
		{"name": "连弩", "desc": "50%双击", "icon": "⚡", "cost": {"gold": 450, "gunpowder": 2}, "turns": 3, "effects": {"double_shot_pct": 0.50}},
	],
	"pirate_cannon": [
		{"name": "强化炮弹", "desc": "ATK+3", "icon": "💣", "cost": {"gold": 150}, "turns": 2, "effects": {"atk": 3}},
		{"name": "攻城", "desc": "城墙×2伤", "icon": "🏰", "cost": {"gold": 350, "gunpowder": 3}, "turns": 3, "effects": {"siege_mult": 2.0}},
		{"name": "连环炮", "desc": "25%追加全伤", "icon": "💥", "cost": {"gold": 700, "gunpowder": 3}, "turns": 4, "effects": {"chain_shot_pct": 0.25}},
	],
	"de_samurai": [
		{"name": "暗影步", "desc": "SPD+2", "icon": "👤", "cost": {"gold": 90}, "turns": 1, "effects": {"spd": 2}},
		{"name": "额外行动", "desc": "20%再动", "icon": "⚡", "cost": {"gold": 250, "shadow": 2}, "turns": 2, "effects": {"extra_action_pct": 0.20}},
		{"name": "暗影支配", "desc": "控制1敌单位", "icon": "👁", "cost": {"gold": 550, "shadow": 3}, "turns": 4, "effects": {"mind_control": 1}},
	],
	"de_ninja": [
		{"name": "暗杀", "desc": "背刺ATK×2", "icon": "🗡", "cost": {"gold": 100}, "turns": 1, "effects": {"backstab_mult": 2.0}},
		{"name": "隐身", "desc": "2回合免疫", "icon": "🌑", "cost": {"gold": 280, "shadow": 2}, "turns": 2, "effects": {"stealth_turns": 2}},
		{"name": "影分身", "desc": "分身助攻", "icon": "👥", "cost": {"gold": 500, "shadow": 3}, "turns": 3, "effects": {"shadow_clone": true}},
	],
	"de_cavalry": [
		{"name": "寒霜", "desc": "减速", "icon": "❄", "cost": {"gold": 110}, "turns": 1, "effects": {"slow": true}},
		{"name": "忽略地形", "desc": "无移动惩罚", "icon": "🦎", "cost": {"gold": 300, "horse": 1, "shadow": 1}, "turns": 2, "effects": {"ignore_terrain": true}},
		{"name": "寒冰领域", "desc": "AOE冻结", "icon": "🧊", "cost": {"gold": 600, "shadow": 2}, "turns": 4, "effects": {"aoe_freeze": true}},
	],
}

# Troop display names (mirrors TroopRegistry)
const TROOP_NAMES: Dictionary = {
	"orc_ashigaru": "兽人足軽", "orc_samurai": "巨魔", "orc_cavalry": "战猪骑兵",
	"pirate_ashigaru": "海盗散兵", "pirate_archer": "火枪手", "pirate_cannon": "炮击手",
	"de_samurai": "暗精灵战士", "de_ninja": "暗影刺客", "de_cavalry": "冷蜥骑兵",
}

const TROOP_CLASS_ICONS: Dictionary = {
	"orc_ashigaru": "足", "orc_samurai": "武", "orc_cavalry": "骑",
	"pirate_ashigaru": "散", "pirate_archer": "射", "pirate_cannon": "砲",
	"de_samurai": "剣", "de_ninja": "忍", "de_cavalry": "騎",
}

const TROOP_FACTIONS: Dictionary = {
	"orc_ashigaru": "orc", "orc_samurai": "orc", "orc_cavalry": "orc",
	"pirate_ashigaru": "pirate", "pirate_archer": "pirate", "pirate_cannon": "pirate",
	"de_samurai": "dark_elf", "de_ninja": "dark_elf", "de_cavalry": "dark_elf",
}

const TROOP_BASE_STATS: Dictionary = {
	"orc_ashigaru": {"atk": 6, "def": 3, "spd": 4, "soldiers": 8, "tier": 1},
	"orc_samurai": {"atk": 9, "def": 6, "spd": 3, "soldiers": 7, "tier": 2},
	"orc_cavalry": {"atk": 8, "def": 4, "spd": 6, "soldiers": 5, "tier": 3},
	"pirate_ashigaru": {"atk": 6, "def": 4, "spd": 4, "soldiers": 7, "tier": 1},
	"pirate_archer": {"atk": 7, "def": 3, "spd": 4, "soldiers": 6, "tier": 2},
	"pirate_cannon": {"atk": 10, "def": 2, "spd": 1, "soldiers": 4, "tier": 3},
	"de_samurai": {"atk": 7, "def": 5, "spd": 5, "soldiers": 5, "tier": 1},
	"de_ninja": {"atk": 9, "def": 2, "spd": 7, "soldiers": 5, "tier": 2},
	"de_cavalry": {"atk": 8, "def": 6, "spd": 5, "soldiers": 5, "tier": 3},
}

# ═══════════════════════════════════════════════════════════════
#                       STATE
# ═══════════════════════════════════════════════════════════════

var _visible: bool = false
var _selected_troop_id: String = ""
# {player_id: {troop_id: {0: {status, progress}, 1: ..., 2: ...}}}
var _training_state: Dictionary = {}

# ═══════════════════════════════════════════════════════════════
#                     UI REFERENCES
# ═══════════════════════════════════════════════════════════════

var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var sidebar_scroll: ScrollContainer
var sidebar_container: VBoxContainer
var center_scroll: ScrollContainer
var center_container: VBoxContainer
var right_scroll: ScrollContainer
var right_container: VBoxContainer
var _pulse_time: float = 0.0
var _pulse_bars: Array = []

# ═══════════════════════════════════════════════════════════════
#                      LIFECYCLE
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
			var pulse_alpha: float = 0.6 + 0.4 * sin(_pulse_time * 4.0)
			var bar: ProgressBar = bar_data["bar"]
			bar.modulate.a = pulse_alpha


func _unhandled_input(event: InputEvent) -> void:
	if not _is_game_active():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_U:
			if _visible:
				hide_panel()
			else:
				show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()


func _is_game_active() -> bool:
	if Engine.has_singleton("GameManager"):
		return true
	var gm = _get_node_safe("/root/GameManager")
	if gm and gm.has_method("get") and "game_active" in gm:
		return gm.game_active
	return true

# ═══════════════════════════════════════════════════════════════
#                  TRAINING STATE MANAGEMENT
# ═══════════════════════════════════════════════════════════════

func _ensure_player_state(player_id: int) -> void:
	if not _training_state.has(player_id):
		_training_state[player_id] = {}
	for troop_id in TROOP_TRAINING_DEFS.keys():
		if not _training_state[player_id].has(troop_id):
			_training_state[player_id][troop_id] = {}
			for slot in range(3):
				var status: int = TrainStatus.AVAILABLE if slot == 0 else TrainStatus.LOCKED
				_training_state[player_id][troop_id][slot] = {"status": status, "progress": 0}


func _get_slot_state(player_id: int, troop_id: String, slot: int) -> Dictionary:
	_ensure_player_state(player_id)
	return _training_state[player_id][troop_id][slot]


func start_training(player_id: int, troop_id: String, slot: int) -> bool:
	_ensure_player_state(player_id)
	var state: Dictionary = _training_state[player_id][troop_id][slot]
	if state["status"] != TrainStatus.AVAILABLE:
		return false
	var slot_def: Dictionary = TROOP_TRAINING_DEFS[troop_id][slot]
	# Deduct resources via ResourceManager if available
	var rm = _get_node_safe("/root/ResourceManager")
	if rm and rm.has_method("can_afford"):
		if not rm.can_afford(player_id, slot_def["cost"]):
			return false
		rm.spend(player_id, slot_def["cost"])
	state["status"] = TrainStatus.TRAINING
	state["progress"] = 0
	return true


func process_turn(player_id: int) -> void:
	_ensure_player_state(player_id)
	for troop_id in _training_state[player_id].keys():
		for slot in range(3):
			var state: Dictionary = _training_state[player_id][troop_id][slot]
			if state["status"] == TrainStatus.TRAINING:
				state["progress"] += 1
				var required_turns: int = TROOP_TRAINING_DEFS[troop_id][slot]["turns"]
				if state["progress"] >= required_turns:
					state["status"] = TrainStatus.COMPLETED
					# Unlock next slot
					if slot < 2:
						var next_state: Dictionary = _training_state[player_id][troop_id][slot + 1]
						if next_state["status"] == TrainStatus.LOCKED:
							next_state["status"] = TrainStatus.AVAILABLE


func cancel_training(player_id: int, troop_id: String, slot: int) -> bool:
	_ensure_player_state(player_id)
	var state: Dictionary = _training_state[player_id][troop_id][slot]
	if state["status"] != TrainStatus.TRAINING:
		return false
	# Refund 50%
	var slot_def: Dictionary = TROOP_TRAINING_DEFS[troop_id][slot]
	var rm = _get_node_safe("/root/ResourceManager")
	if rm and rm.has_method("apply_delta"):
		var refund: Dictionary = {}
		for res_key in slot_def["cost"].keys():
			refund[res_key] = int(slot_def["cost"][res_key] * 0.5)
		rm.apply_delta(player_id, refund)
	state["status"] = TrainStatus.AVAILABLE
	state["progress"] = 0
	return true


func is_ability_unlocked(player_id: int, troop_id: String, slot: int) -> bool:
	_ensure_player_state(player_id)
	return _training_state[player_id][troop_id][slot]["status"] == TrainStatus.COMPLETED


func get_training_queue(player_id: int) -> Array:
	_ensure_player_state(player_id)
	var queue: Array = []
	for troop_id in _training_state[player_id].keys():
		for slot in range(3):
			var state: Dictionary = _training_state[player_id][troop_id][slot]
			if state["status"] == TrainStatus.TRAINING:
				var slot_def: Dictionary = TROOP_TRAINING_DEFS[troop_id][slot]
				queue.append({
					"troop_id": troop_id, "slot": slot,
					"name": slot_def["name"],
					"progress": state["progress"],
					"required": slot_def["turns"],
				})
	return queue


func to_save_data() -> Dictionary:
	return _training_state.duplicate(true)


func from_save_data(data: Dictionary) -> void:
	_training_state = data.duplicate(true)

# ═══════════════════════════════════════════════════════════════
#                       BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "TroopTrainingRoot"
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

	# Main panel
	main_panel = PanelContainer.new()
	main_panel.anchor_right = 1.0; main_panel.anchor_bottom = 1.0
	main_panel.offset_left = 25; main_panel.offset_right = -25
	main_panel.offset_top = 25; main_panel.offset_bottom = -25
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

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header_row)

	header_label = Label.new()
	header_label.text = "兵种训练 Troop Training"
	header_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING + 2)
	header_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)

	# Training queue summary in header
	var queue_label := Label.new()
	queue_label.name = "QueueSummary"
	queue_label.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	queue_label.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	header_row.add_child(queue_label)

	btn_close = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	outer_vbox.add_child(HSeparator.new())

	# Content: 3-column layout
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 8)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)

	# LEFT SIDEBAR (~250px)
	_build_sidebar(content_hbox)
	# Vertical separator
	content_hbox.add_child(VSeparator.new())
	# CENTER detail
	_build_center(content_hbox)
	# Vertical separator
	content_hbox.add_child(VSeparator.new())
	# RIGHT ability tree
	_build_right(content_hbox)


func _build_sidebar(parent: HBoxContainer) -> void:
	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(250, 0)
	sidebar_panel.size_flags_horizontal = Control.SIZE_FILL
	var style := _make_sub_panel_style()
	sidebar_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(sidebar_panel)

	sidebar_scroll = ScrollContainer.new()
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_panel.add_child(sidebar_scroll)

	sidebar_container = VBoxContainer.new()
	sidebar_container.add_theme_constant_override("separation", 2)
	sidebar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.add_child(sidebar_container)


func _build_center(parent: HBoxContainer) -> void:
	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_stretch_ratio = 1.2
	var style := _make_sub_panel_style()
	center_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(center_panel)

	center_scroll = ScrollContainer.new()
	center_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_panel.add_child(center_scroll)

	center_container = VBoxContainer.new()
	center_container.add_theme_constant_override("separation", 8)
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_scroll.add_child(center_container)


func _build_right(parent: HBoxContainer) -> void:
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.4
	var style := _make_sub_panel_style()
	right_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(right_panel)

	right_scroll = ScrollContainer.new()
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(right_scroll)

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
#                    SHOW / HIDE
# ═══════════════════════════════════════════════════════════════

func show_panel() -> void:
	_visible = true
	root.visible = true
	_selected_troop_id = ""
	_refresh_all()
	ColorTheme.animate_panel_open(main_panel)


func hide_panel() -> void:
	if _visible:
		_play_cancel_sound()
	_visible = false
	root.visible = false
	_pulse_bars.clear()


func is_panel_visible() -> bool:
	return _visible

# ═══════════════════════════════════════════════════════════════
#                     REFRESH ALL
# ═══════════════════════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_sidebar()
	_refresh_center()
	_refresh_right()
	_refresh_queue_summary()


func _refresh_queue_summary() -> void:
	var pid: int = _get_player_id()
	var queue: Array = get_training_queue(pid)
	var lbl = root.find_child("QueueSummary", true, false)
	if lbl:
		if queue.size() > 0:
			lbl.text = "训练中: %d" % queue.size()
		else:
			lbl.text = ""

# ═══════════════════════════════════════════════════════════════
#                   SIDEBAR (left)
# ═══════════════════════════════════════════════════════════════

func _refresh_sidebar() -> void:
	_clear_children(sidebar_container)
	var pid: int = _get_player_id()
	_ensure_player_state(pid)

	for faction_key in FACTION_TROOP_GROUPS.keys():
		var group: Dictionary = FACTION_TROOP_GROUPS[faction_key]
		var faction_color: Color = ColorTheme.FACTION_COLORS.get(faction_key, ColorTheme.TEXT_DIM)

		# Faction header
		var faction_lbl := Label.new()
		faction_lbl.text = "── %s ──" % group["label"]
		faction_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		faction_lbl.add_theme_color_override("font_color", faction_color)
		faction_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sidebar_container.add_child(faction_lbl)

		for troop_id in group["troops"]:
			var btn := Button.new()
			var icon_text: String = TROOP_CLASS_ICONS.get(troop_id, "?")
			var troop_name: String = TROOP_NAMES.get(troop_id, troop_id)
			# Show training count
			var completed_count: int = _count_completed_slots(pid, troop_id)
			var training_indicator: String = ""
			if completed_count > 0:
				training_indicator = " [%d/3]" % completed_count
			var in_training: bool = _has_training_in_progress(pid, troop_id)
			if in_training:
				training_indicator += " ..."

			btn.text = " [%s] %s%s" % [icon_text, troop_name, training_indicator]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
			btn.custom_minimum_size = Vector2(230, 32)

			# Style selected vs not
			var btn_style := StyleBoxFlat.new()
			if troop_id == _selected_troop_id:
				btn_style.bg_color = Color(faction_color.r, faction_color.g, faction_color.b, 0.25)
				btn_style.border_color = faction_color
				btn_style.set_border_width_all(2)
			else:
				btn_style.bg_color = ColorTheme.BTN_NORMAL_BG
				btn_style.border_color = Color(faction_color.r, faction_color.g, faction_color.b, 0.3)
				btn_style.set_border_width_all(1)
			btn_style.set_corner_radius_all(4)
			btn_style.set_content_margin_all(4)
			btn.add_theme_stylebox_override("normal", btn_style)

			var hover_style := btn_style.duplicate()
			hover_style.bg_color = Color(faction_color.r, faction_color.g, faction_color.b, 0.18)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
			btn.pressed.connect(_on_troop_selected.bind(troop_id))
			sidebar_container.add_child(btn)

		# Small spacer between factions
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 6)
		sidebar_container.add_child(spacer)


func _count_completed_slots(player_id: int, troop_id: String) -> int:
	var count: int = 0
	for slot in range(3):
		if _get_slot_state(player_id, troop_id, slot)["status"] == TrainStatus.COMPLETED:
			count += 1
	return count


func _has_training_in_progress(player_id: int, troop_id: String) -> bool:
	for slot in range(3):
		if _get_slot_state(player_id, troop_id, slot)["status"] == TrainStatus.TRAINING:
			return true
	return false

# ═══════════════════════════════════════════════════════════════
#                    CENTER (troop detail)
# ═══════════════════════════════════════════════════════════════

func _refresh_center() -> void:
	_clear_children(center_container)

	if _selected_troop_id == "":
		var hint_lbl := Label.new()
		hint_lbl.text = "选择左侧兵种查看详情\nSelect a troop from the sidebar"
		hint_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		hint_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		center_container.add_child(hint_lbl)
		return

	var troop_id: String = _selected_troop_id
	var pid: int = _get_player_id()
	var faction_key: String = TROOP_FACTIONS.get(troop_id, "orc")
	var faction_color: Color = ColorTheme.FACTION_COLORS.get(faction_key, ColorTheme.TEXT_DIM)
	var stats: Dictionary = TROOP_BASE_STATS.get(troop_id, {})

	# Troop card
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = ColorTheme.BG_CARD
	card_style.border_color = faction_color
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	center_container.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	card.add_child(card_vbox)

	# Name + class icon + tier badge
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	card_vbox.add_child(name_row)

	var icon_lbl := Label.new()
	icon_lbl.text = "[%s]" % TROOP_CLASS_ICONS.get(troop_id, "?")
	icon_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
	icon_lbl.add_theme_color_override("font_color", faction_color)
	name_row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = TROOP_NAMES.get(troop_id, troop_id)
	name_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
	name_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_TITLE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	var tier_lbl := Label.new()
	var tier_val: int = stats.get("tier", 1)
	tier_lbl.text = "T%d" % tier_val
	tier_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	var tier_color: Color = ColorTheme.TEXT_DIM
	if tier_val == 2: tier_color = ColorTheme.ACCENT_GOLD
	elif tier_val == 3: tier_color = ColorTheme.TEXT_GOLD
	tier_lbl.add_theme_color_override("font_color", tier_color)
	name_row.add_child(tier_lbl)

	# Base stats grid
	var stats_label := Label.new()
	stats_label.text = "ATK: %d  |  DEF: %d  |  SPD: %d  |  兵数: %d" % [
		stats.get("atk", 0), stats.get("def", 0),
		stats.get("spd", 0), stats.get("soldiers", 0),
	]
	stats_label.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	stats_label.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	card_vbox.add_child(stats_label)

	center_container.add_child(HSeparator.new())

	# Already unlocked abilities
	var unlocked_header := Label.new()
	unlocked_header.text = "已解锁技能 Unlocked Abilities"
	unlocked_header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	unlocked_header.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
	center_container.add_child(unlocked_header)

	var has_unlocked: bool = false
	for slot in range(3):
		var state: Dictionary = _get_slot_state(pid, troop_id, slot)
		if state["status"] == TrainStatus.COMPLETED:
			has_unlocked = true
			var slot_def: Dictionary = TROOP_TRAINING_DEFS[troop_id][slot]
			var ability_lbl := Label.new()
			ability_lbl.text = "  %s %s — %s" % [slot_def["icon"], slot_def["name"], slot_def["desc"]]
			ability_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
			ability_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS)
			center_container.add_child(ability_lbl)

	if not has_unlocked:
		var none_lbl := Label.new()
		none_lbl.text = "  尚无已解锁技能"
		none_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		none_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		center_container.add_child(none_lbl)

	center_container.add_child(HSeparator.new())

	# Training queue status for this troop
	var queue_header := Label.new()
	queue_header.text = "训练进度 Training Queue"
	queue_header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	queue_header.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
	center_container.add_child(queue_header)

	var has_training: bool = false
	for slot in range(3):
		var state: Dictionary = _get_slot_state(pid, troop_id, slot)
		if state["status"] == TrainStatus.TRAINING:
			has_training = true
			var slot_def: Dictionary = TROOP_TRAINING_DEFS[troop_id][slot]
			var train_lbl := Label.new()
			train_lbl.text = "  %s %s — %d/%d 回合" % [
				slot_def["icon"], slot_def["name"],
				state["progress"], slot_def["turns"],
			]
			train_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
			train_lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
			center_container.add_child(train_lbl)

	if not has_training:
		var none_lbl := Label.new()
		none_lbl.text = "  无正在训练的技能"
		none_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		none_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		center_container.add_child(none_lbl)

# ═══════════════════════════════════════════════════════════════
#               RIGHT (ability upgrade tree)
# ═══════════════════════════════════════════════════════════════

func _refresh_right() -> void:
	_clear_children(right_container)
	_pulse_bars.clear()

	if _selected_troop_id == "":
		var hint := Label.new()
		hint.text = "选择兵种后查看训练树\nAbility tree shown here"
		hint.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		hint.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right_container.add_child(hint)
		return

	var troop_id: String = _selected_troop_id
	var pid: int = _get_player_id()
	var faction_key: String = TROOP_FACTIONS.get(troop_id, "orc")
	var faction_color: Color = ColorTheme.FACTION_COLORS.get(faction_key, ColorTheme.TEXT_DIM)

	var tree_header := Label.new()
	tree_header.text = "训练树 Ability Tree"
	tree_header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	tree_header.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
	tree_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_container.add_child(tree_header)

	for slot in range(3):
		# Connector line (except before slot 0)
		if slot > 0:
			var connector := _make_connector_line(faction_color)
			right_container.add_child(connector)

		var slot_def: Dictionary = TROOP_TRAINING_DEFS[troop_id][slot]
		var state: Dictionary = _get_slot_state(pid, troop_id, slot)
		var status: int = state["status"]

		# Slot card
		var slot_card := PanelContainer.new()
		var sc_style := _make_slot_card_style(status, faction_color)
		slot_card.add_theme_stylebox_override("panel", sc_style)
		right_container.add_child(slot_card)

		var slot_vbox := VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 4)
		slot_card.add_child(slot_vbox)

		# Slot tier label
		var tier_row := HBoxContainer.new()
		tier_row.add_theme_constant_override("separation", 6)
		slot_vbox.add_child(tier_row)

		var slot_tier_lbl := Label.new()
		slot_tier_lbl.text = SLOT_LABELS[slot]
		slot_tier_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		slot_tier_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
		tier_row.add_child(slot_tier_lbl)

		var status_lbl := Label.new()
		status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		match status:
			TrainStatus.LOCKED:
				status_lbl.text = "🔒 未解锁"
				status_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
			TrainStatus.AVAILABLE:
				status_lbl.text = "可训练"
				status_lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
			TrainStatus.TRAINING:
				status_lbl.text = "训练中 %d/%d" % [state["progress"], slot_def["turns"]]
				status_lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD)
			TrainStatus.COMPLETED:
				status_lbl.text = "✓ 已完成"
				status_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS)
		tier_row.add_child(status_lbl)

		# Ability name + icon
		var ability_row := HBoxContainer.new()
		ability_row.add_theme_constant_override("separation", 6)
		slot_vbox.add_child(ability_row)

		var ability_icon := Label.new()
		ability_icon.text = slot_def["icon"]
		ability_icon.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
		ability_row.add_child(ability_icon)

		var ability_name := Label.new()
		ability_name.text = slot_def["name"]
		ability_name.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
		var name_color: Color = ColorTheme.TEXT_NORMAL
		if status == TrainStatus.LOCKED:
			name_color = ColorTheme.TEXT_MUTED
		elif status == TrainStatus.COMPLETED:
			name_color = ColorTheme.TEXT_SUCCESS
		ability_name.add_theme_color_override("font_color", name_color)
		ability_row.add_child(ability_name)

		# Description
		var desc_lbl := Label.new()
		desc_lbl.text = slot_def["desc"]
		desc_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		desc_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM if status == TrainStatus.LOCKED else ColorTheme.TEXT_NORMAL)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_vbox.add_child(desc_lbl)

		# Cost breakdown
		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 10)
		slot_vbox.add_child(cost_row)

		for res_key in slot_def["cost"].keys():
			var res_lbl := Label.new()
			var icon_char: String = RES_ICONS.get(res_key, "?")
			var res_color: Color = RES_COLORS.get(res_key, ColorTheme.TEXT_NORMAL)
			res_lbl.text = "%s %s: %d" % [icon_char, res_key, slot_def["cost"][res_key]]
			res_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
			res_lbl.add_theme_color_override("font_color", res_color if status != TrainStatus.LOCKED else ColorTheme.TEXT_MUTED)
			cost_row.add_child(res_lbl)

		# Turn requirement
		var turn_lbl := Label.new()
		turn_lbl.text = "⏱ %d 回合" % slot_def["turns"]
		turn_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		turn_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
		cost_row.add_child(turn_lbl)

		# Progress bar (only for TRAINING)
		if status == TrainStatus.TRAINING:
			var progress_bar := ProgressBar.new()
			progress_bar.min_value = 0
			progress_bar.max_value = slot_def["turns"]
			progress_bar.value = state["progress"]
			progress_bar.custom_minimum_size = Vector2(0, 14)
			progress_bar.show_percentage = false

			var bar_bg := StyleBoxFlat.new()
			bar_bg.bg_color = Color(0.1, 0.1, 0.15)
			bar_bg.set_corner_radius_all(3)
			progress_bar.add_theme_stylebox_override("background", bar_bg)

			var bar_fill := StyleBoxFlat.new()
			bar_fill.bg_color = ColorTheme.ACCENT_GOLD
			bar_fill.set_corner_radius_all(3)
			progress_bar.add_theme_stylebox_override("fill", bar_fill)

			slot_vbox.add_child(progress_bar)
			_pulse_bars.append({"bar": progress_bar})

		# Action buttons
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		slot_vbox.add_child(btn_row)

		if status == TrainStatus.AVAILABLE:
			var train_btn := Button.new()
			train_btn.text = "开始训练"
			train_btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
			var tb_style := StyleBoxFlat.new()
			tb_style.bg_color = Color(0.08, 0.25, 0.08, 0.9)
			tb_style.border_color = Color(0.2, 0.7, 0.3)
			tb_style.set_border_width_all(1)
			tb_style.set_corner_radius_all(4)
			tb_style.set_content_margin_all(4)
			train_btn.add_theme_stylebox_override("normal", tb_style)
			train_btn.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS)
			train_btn.pressed.connect(_on_start_training.bind(troop_id, slot))
			btn_row.add_child(train_btn)
		elif status == TrainStatus.TRAINING:
			var cancel_btn := Button.new()
			cancel_btn.text = "取消 (退50%)"
			cancel_btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
			var cb_style := StyleBoxFlat.new()
			cb_style.bg_color = Color(0.3, 0.08, 0.08, 0.9)
			cb_style.border_color = Color(0.8, 0.2, 0.2)
			cb_style.set_border_width_all(1)
			cb_style.set_corner_radius_all(4)
			cb_style.set_content_margin_all(4)
			cancel_btn.add_theme_stylebox_override("normal", cb_style)
			cancel_btn.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
			cancel_btn.pressed.connect(_on_cancel_training.bind(troop_id, slot))
			btn_row.add_child(cancel_btn)


func _make_connector_line(faction_color: Color) -> Control:
	var connector := ColorRect.new()
	connector.custom_minimum_size = Vector2(4, 20)
	connector.color = Color(faction_color.r, faction_color.g, faction_color.b, 0.5)
	connector.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return connector


func _make_slot_card_style(status: int, faction_color: Color) -> StyleBoxFlat:
	var sf := StyleBoxFlat.new()
	sf.set_corner_radius_all(6)
	sf.set_content_margin_all(10)
	match status:
		TrainStatus.LOCKED:
			sf.bg_color = Color(0.05, 0.05, 0.08, 0.8)
			sf.border_color = ColorTheme.BORDER_DIM
			sf.set_border_width_all(1)
		TrainStatus.AVAILABLE:
			sf.bg_color = ColorTheme.BG_CARD
			sf.border_color = Color(faction_color.r, faction_color.g, faction_color.b, 0.8)
			sf.set_border_width_all(2)
		TrainStatus.TRAINING:
			sf.bg_color = Color(0.12, 0.11, 0.06, 0.9)
			sf.border_color = ColorTheme.ACCENT_GOLD_BRIGHT
			sf.set_border_width_all(2)
		TrainStatus.COMPLETED:
			sf.bg_color = Color(0.06, 0.12, 0.06, 0.85)
			sf.border_color = ColorTheme.ACCENT_GOLD
			sf.set_border_width_all(2)
	return sf

# ═══════════════════════════════════════════════════════════════
#                      CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_troop_selected(troop_id: String) -> void:
	_selected_troop_id = troop_id
	_refresh_all()


func _on_start_training(troop_id: String, slot: int) -> void:
	var pid: int = _get_player_id()
	if start_training(pid, troop_id, slot):
		_refresh_all()


func _on_cancel_training(troop_id: String, slot: int) -> void:
	var pid: int = _get_player_id()
	if cancel_training(pid, troop_id, slot):
		_refresh_all()


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()

# ═══════════════════════════════════════════════════════════════
#                       HELPERS
# ═══════════════════════════════════════════════════════════════

func _get_player_id() -> Variant:
	var gm = _get_node_safe("/root/GameManager")
	if gm and gm.has_method("get_human_player_id"):
		return gm.get_human_player_id()
	return 0


func _get_node_safe(path: String):
	if has_node(path):
		return get_node(path)
	return null


func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()


func _play_cancel_sound() -> void:
	var am = _get_node_safe("/root/AudioManager")
	if am and am.has_method("play_ui_cancel"):
		am.play_ui_cancel()
