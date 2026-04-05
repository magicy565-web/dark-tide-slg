## village_panel.gd — 村庄/城镇专属 UI 面板
## 提供建筑建造、贸易管理、民政行动、村庄升级的完整交互界面。
## 版本: v1.0.0
extends CanvasLayer

const CLR_GOLD   := Color(0.9, 0.8, 0.4)
const CLR_CYAN   := Color(0.4, 0.8, 0.8)
const CLR_GREEN  := Color(0.4, 0.8, 0.4)
const CLR_RED    := Color(0.9, 0.3, 0.3)
const CLR_ORANGE := Color(0.9, 0.6, 0.2)
const CLR_GRAY   := Color(0.5, 0.5, 0.5)
const CLR_TEXT   := Color(0.85, 0.85, 0.85)
const CLR_DARK   := Color(0.06, 0.12, 0.06, 0.97)

var _tile_idx: int = -1
var _root: Control
var _main_panel: PanelContainer
var _title_label: Label
var _level_label: Label
var _content_vbox: VBoxContainer
var _tab_bar: HBoxContainer
var _current_tab: String = "overview"

func _ready() -> void:
	layer = 90
	_build_ui()
	hide_panel()

func _build_ui() -> void:
	_root = Control.new()
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim = ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: hide_panel())
	_root.add_child(dim)

	_main_panel = PanelContainer.new()
	_main_panel.anchor_left = 0.55
	_main_panel.anchor_right = 0.98
	_main_panel.anchor_top = 0.05
	_main_panel.anchor_bottom = 0.95
	var style = StyleBoxFlat.new()
	style.bg_color = CLR_DARK
	style.border_color = Color(0.3, 0.6, 0.3, 0.9)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_main_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_main_panel)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	_main_panel.add_child(outer_vbox)

	outer_vbox.add_child(_make_header())

	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 2)
	outer_vbox.add_child(_tab_bar)
	_build_tabs()

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_content_vbox)

func _make_header() -> Control:
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 48)
	var hdr_style = StyleBoxFlat.new()
	hdr_style.bg_color = Color(0.06, 0.18, 0.06)
	hbox.add_theme_stylebox_override("panel", hdr_style)

	var icon = Label.new()
	icon.text = "🏘"
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_constant_override("margin_left", 10)
	hbox.add_child(icon)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "村庄"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", CLR_GREEN)
	vbox.add_child(_title_label)

	_level_label = Label.new()
	_level_label.text = "小村落  人口: 0/20"
	_level_label.add_theme_font_size_override("font_size", 11)
	_level_label.add_theme_color_override("font_color", CLR_GRAY)
	vbox.add_child(_level_label)

	var btn_close = Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.pressed.connect(hide_panel)
	hbox.add_child(btn_close)
	return hbox

func _build_tabs() -> void:
	for child in _tab_bar.get_children():
		child.queue_free()
	var tabs = [
		["overview",  "📊 概览"],
		["buildings", "🏗 建筑"],
		["trade",     "💰 贸易"],
		["domestic",  "📜 民政"],
		["upgrade",   "⬆ 升级"],
	]
	for tab in tabs:
		var btn = Button.new()
		btn.text = tab[1]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 30)
		var tab_id = tab[0]
		btn.pressed.connect(func(): _switch_tab(tab_id))
		_tab_bar.add_child(btn)

func _switch_tab(tab_id: String) -> void:
	_current_tab = tab_id
	_refresh_content()

func show_panel(tile_idx: int) -> void:
	_tile_idx = tile_idx
	_current_tab = "overview"
	_root.visible = true
	_refresh()

func hide_panel() -> void:
	_root.visible = false

func _refresh() -> void:
	if _tile_idx < 0 or _tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[_tile_idx]
	var data = GameManager.village_system.get_village_data(_tile_idx)
	var level_data = GameManager.village_system.VILLAGE_LEVELS.get(data["level"], GameManager.village_system.VILLAGE_LEVELS[1])

	_title_label.text = tile.get("name", "村庄 #%d" % _tile_idx)
	_level_label.text = "Lv%d %s  |  人口: %d/%d  |  幸福度: %.0f%%" % [
		data["level"], level_data["name"], data["population"], level_data["pop_cap"], data["happiness"]
	]
	_refresh_content()

func _refresh_content() -> void:
	for child in _content_vbox.get_children():
		child.queue_free()
	match _current_tab:
		"overview":  _build_overview()
		"buildings": _build_buildings()
		"trade":     _build_trade()
		"domestic":  _build_domestic()
		"upgrade":   _build_upgrade()

# ─── 概览 ───
func _build_overview() -> void:
	var data = GameManager.village_system.get_village_data(_tile_idx)
	var tile = GameManager.tiles[_tile_idx]
	var level_data = GameManager.village_system.VILLAGE_LEVELS.get(data["level"], GameManager.village_system.VILLAGE_LEVELS[1])
	var bld_effects = GameManager.village_system.get_building_effects(_tile_idx)

	_content_vbox.add_child(_make_section_title("村庄状态"))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	_content_vbox.add_child(grid)

	_add_info_row(grid, "人口", "%d/%d" % [data["population"], level_data["pop_cap"]], CLR_TEXT)
	_add_info_row(grid, "幸福度", "%.0f%%" % data["happiness"], CLR_GREEN if data["happiness"] >= 60 else CLR_RED)
	_add_info_row(grid, "建筑", "%d/%d 槽位" % [data["buildings"].size(), level_data["building_slots"]], CLR_CYAN)
	_add_info_row(grid, "贸易", "%d 条路线" % data["active_trades"].size(), CLR_GOLD)
	_add_info_row(grid, "驻军", "%d 人" % tile.get("garrison", 0), CLR_TEXT)

	if not data["active_trades"].is_empty():
		_content_vbox.add_child(_make_section_title("活跃贸易"))
		for trade_entry in data["active_trades"]:
			var trade = GameManager.village_system._find_trade(trade_entry["id"])
			if not trade.is_empty():
				var lbl = _make_label("• %s — 剩余 %d 回合" % [trade["name"], trade_entry["turns_left"]], CLR_GOLD, 12)
				_content_vbox.add_child(lbl)

	if not data["buildings"].is_empty():
		_content_vbox.add_child(_make_section_title("建筑效果汇总"))
		var eff_box = _make_info_box()
		if bld_effects.get("gold_per_turn", 0) > 0:
			eff_box.add_child(_make_label("金币 +%d/回合" % bld_effects["gold_per_turn"], CLR_GOLD, 12))
		if bld_effects.get("food_per_turn", 0) > 0:
			eff_box.add_child(_make_label("粮食 +%d/回合" % bld_effects["food_per_turn"], CLR_GREEN, 12))
		if bld_effects.get("iron_per_turn", 0) > 0:
			eff_box.add_child(_make_label("铁矿 +%d/回合" % bld_effects["iron_per_turn"], CLR_GRAY, 12))
		if bld_effects.get("recruit_bonus", 0) > 0:
			eff_box.add_child(_make_label("征兵 +%d/回合" % bld_effects["recruit_bonus"], CLR_ORANGE, 12))
		_content_vbox.add_child(eff_box)

# ─── 建筑 ───
func _build_buildings() -> void:
	var data = GameManager.village_system.get_village_data(_tile_idx)
	var level_data = GameManager.village_system.VILLAGE_LEVELS.get(data["level"], GameManager.village_system.VILLAGE_LEVELS[1])
	var pid = GameManager.get_human_player_id()

	_content_vbox.add_child(_make_section_title("建筑管理（%d/%d 槽位）" % [data["buildings"].size(), level_data["building_slots"]]))

	for bld_id in GameManager.village_system.VILLAGE_BUILDINGS:
		var bld = GameManager.village_system.VILLAGE_BUILDINGS[bld_id]
		var current_level: int = data["buildings"].get(bld_id, 0)
		var is_max: bool = current_level >= bld["max_level"]
		var has_prereq: bool = not bld.has("requires") or data["buildings"].has(bld["requires"])
		var slot_full: bool = data["buildings"].size() >= level_data["building_slots"] and current_level == 0

		var box = _make_info_box()
		var title_color: Color = CLR_GOLD if current_level > 0 else CLR_TEXT
		box.add_child(_make_label("%s %s %s" % [bld["icon"], bld["name"], ("Lv%d" % current_level) if current_level > 0 else ""], title_color, 13))
		box.add_child(_make_label(bld["desc"], CLR_GRAY, 11))

		var cost_dict: Dictionary = {}
		for k in bld["cost"]:
			cost_dict[k] = int(bld["cost"][k] * (1.0 + current_level * 0.5))
		box.add_child(_make_label("费用: %s" % _format_cost(cost_dict), CLR_RED, 11))

		if is_max:
			box.add_child(_make_label("✅ 已达最高等级", CLR_GREEN, 11))
		elif not has_prereq:
			box.add_child(_make_label("⚠ 需要先建造 %s" % GameManager.village_system.VILLAGE_BUILDINGS[bld["requires"]]["name"], CLR_ORANGE, 11))
		elif slot_full:
			box.add_child(_make_label("⚠ 建筑槽位已满", CLR_ORANGE, 11))
		else:
			var can_build = ResourceManager.can_afford(pid, cost_dict)
			var action_text: String = "建造" if current_level == 0 else "升级至 Lv%d" % (current_level + 1)
			var btn = _make_action_button(action_text, can_build, "资源不足" if not can_build else "")
			var captured_id = bld_id
			btn.pressed.connect(func(): _on_build_pressed(captured_id))
			box.add_child(btn)

		_content_vbox.add_child(box)

# ─── 贸易 ───
func _build_trade() -> void:
	var data = GameManager.village_system.get_village_data(_tile_idx)
	var level_data = GameManager.village_system.VILLAGE_LEVELS.get(data["level"], GameManager.village_system.VILLAGE_LEVELS[1])
	var bld_effects = GameManager.village_system.get_building_effects(_tile_idx)
	var max_trades: int = level_data["trade_slots"] + bld_effects.get("trade_slots", 0)
	var pid = GameManager.get_human_player_id()

	_content_vbox.add_child(_make_section_title("贸易路线（%d/%d 槽位）" % [data["active_trades"].size(), max_trades]))

	for trade in GameManager.village_system.TRADE_AGREEMENTS:
		var is_active: bool = false
		for t in data["active_trades"]:
			if t["id"] == trade["id"]:
				is_active = true
				break

		var box = _make_info_box()
		box.add_child(_make_label("💰 %s" % trade["name"], CLR_GOLD if not is_active else CLR_GRAY, 13))
		box.add_child(_make_label(trade["desc"], CLR_TEXT, 11))
		box.add_child(_make_label("费用: %s  |  收益: %s/回合  |  持续: %d 回合" % [
			_format_cost(trade["cost"]), _format_cost(trade["income"]), trade["duration"]
		], CLR_CYAN, 11))

		if is_active:
			box.add_child(_make_label("✅ 协议进行中", CLR_GREEN, 11))
		elif data["active_trades"].size() >= max_trades:
			box.add_child(_make_label("⚠ 贸易槽位已满", CLR_ORANGE, 11))
		else:
			var can_trade = ResourceManager.can_afford(pid, trade["cost"])
			var btn = _make_action_button("签订协议", can_trade, "资源不足" if not can_trade else "")
			var captured_id = trade["id"]
			btn.pressed.connect(func(): _on_trade_pressed(captured_id))
			box.add_child(btn)

		_content_vbox.add_child(box)

# ─── 民政 ───
func _build_domestic() -> void:
	var data = GameManager.village_system.get_village_data(_tile_idx)
	var pid = GameManager.get_human_player_id()

	_content_vbox.add_child(_make_section_title("民政行动"))

	for action_id in GameManager.village_system.DOMESTIC_ACTIONS:
		var action = GameManager.village_system.DOMESTIC_ACTIONS[action_id]
		var cooldown: int = data["action_cooldowns"].get(action_id, 0)
		var ap: int = GameManager.current_ap
		var ap_cost: int = action["cost"].get("ap", 0)

		var box = _make_info_box()
		box.add_child(_make_label("%s %s" % [action["icon"], action["name"]], CLR_CYAN, 13))
		box.add_child(_make_label(action["desc"], CLR_TEXT, 11))

		var cost_display: Dictionary = action["cost"].duplicate()
		box.add_child(_make_label("费用: %s" % _format_cost(cost_display), CLR_RED, 11))

		var eff_parts: Array = []
		for k in action["effects"]:
			eff_parts.append("%s %+g" % [k, action["effects"][k]])
		box.add_child(_make_label("效果: %s" % ", ".join(eff_parts), CLR_GREEN, 11))

		if cooldown > 0:
			box.add_child(_make_label("⏳ 冷却中（%d 回合）" % cooldown, CLR_ORANGE, 11))
		else:
			var res_cost: Dictionary = {}
			for k in action["cost"]:
				if k != "ap":
					res_cost[k] = action["cost"][k]
			var can_act = ap >= ap_cost and (res_cost.is_empty() or ResourceManager.can_afford(pid, res_cost))
			var reason: String = ""
			if ap < ap_cost: reason = "行动力不足"
			elif not res_cost.is_empty() and not ResourceManager.can_afford(pid, res_cost): reason = "资源不足"
			var btn = _make_action_button("执行", can_act, reason)
			var captured_id = action_id
			btn.pressed.connect(func(): _on_domestic_pressed(captured_id))
			box.add_child(btn)

		_content_vbox.add_child(box)

# ─── 升级 ───
func _build_upgrade() -> void:
	var data = GameManager.village_system.get_village_data(_tile_idx)
	var current_level: int = data["level"]
	var pid = GameManager.get_human_player_id()

	_content_vbox.add_child(_make_section_title("村庄升级"))

	if current_level >= 4:
		_content_vbox.add_child(_make_label("✅ 已达最高等级（繁荣城市）", CLR_GOLD, 13))
		return

	var next_level_data = GameManager.village_system.VILLAGE_LEVELS.get(current_level + 1, {})
	var upgrade_cost: Dictionary = {"gold": 80 * current_level, "iron": 20 * current_level}
	var pop_required: int = GameManager.village_system.VILLAGE_LEVELS[current_level]["pop_cap"] * 8 / 10

	var box = _make_info_box()
	box.add_child(_make_label("升级至: %s" % next_level_data.get("name", ""), CLR_GOLD, 14))
	box.add_child(_make_label("费用: %s" % _format_cost(upgrade_cost), CLR_RED, 12))
	box.add_child(_make_label("人口要求: %d（当前 %d）" % [pop_required, data["population"]],
		CLR_GREEN if data["population"] >= pop_required else CLR_RED, 12))
	box.add_child(_make_label("升级后: 建筑槽 %d，贸易槽 %d，人口上限 %d" % [
		next_level_data.get("building_slots", 0), next_level_data.get("trade_slots", 0), next_level_data.get("pop_cap", 0)
	], CLR_CYAN, 12))

	var can_upgrade = data["population"] >= pop_required and ResourceManager.can_afford(pid, upgrade_cost)
	var reason: String = ""
	if data["population"] < pop_required: reason = "人口不足"
	elif not ResourceManager.can_afford(pid, upgrade_cost): reason = "资源不足"
	var btn = _make_action_button("升级村庄", can_upgrade, reason)
	btn.pressed.connect(_on_upgrade_pressed)
	box.add_child(btn)
	_content_vbox.add_child(box)

# ─── 按钮回调 ───
func _on_build_pressed(bld_id: String) -> void:
	var result = GameManager.village_system.build(_tile_idx, bld_id)
	if result["success"]: _refresh()
	else: EventBus.message_log.emit("[color=red]【村庄建筑】%s[/color]" % result.get("reason", ""))

func _on_trade_pressed(trade_id: String) -> void:
	var result = GameManager.village_system.start_trade(_tile_idx, trade_id)
	if result["success"]: _refresh()
	else: EventBus.message_log.emit("[color=red]【村庄贸易】%s[/color]" % result.get("reason", ""))

func _on_domestic_pressed(action_id: String) -> void:
	var result = GameManager.village_system.execute_domestic_action(_tile_idx, action_id)
	if result["success"]: _refresh()
	else: EventBus.message_log.emit("[color=red]【村庄民政】%s[/color]" % result.get("reason", ""))

func _on_upgrade_pressed() -> void:
	var result = GameManager.village_system.upgrade_village(_tile_idx)
	if result["success"]: _refresh()
	else: EventBus.message_log.emit("[color=red]【村庄升级】%s[/color]" % result.get("reason", ""))

# ─── 辅助 ───
func _make_section_title(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = "── %s ──" % text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", CLR_GREEN)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _make_label(text: String, color: Color, size: int = 12) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _make_info_box() -> VBoxContainer:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.05, 0.8)
	style.border_color = Color(0.2, 0.4, 0.2, 0.6)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", style)
	return box

func _make_action_button(text: String, enabled: bool, reason: String = "") -> Button:
	var btn = Button.new()
	btn.text = text if enabled else "%s（%s）" % [text, reason]
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(0, 34)
	return btn

func _add_info_row(grid: GridContainer, key: String, value: String, color: Color) -> void:
	var k = Label.new()
	k.text = key + ":"
	k.add_theme_color_override("font_color", CLR_GRAY)
	k.add_theme_font_size_override("font_size", 12)
	grid.add_child(k)
	var v = Label.new()
	v.text = value
	v.add_theme_color_override("font_color", color)
	v.add_theme_font_size_override("font_size", 12)
	grid.add_child(v)

func _format_cost(cost: Dictionary) -> String:
	var parts: Array = []
	if cost.get("gold", 0) != 0:    parts.append("%+d金" % cost["gold"])
	if cost.get("iron", 0) != 0:    parts.append("%+d铁" % cost["iron"])
	if cost.get("food", 0) != 0:    parts.append("%+d粮" % cost["food"])
	if cost.get("slaves", 0) != 0:  parts.append("%+d奴隶" % cost["slaves"])
	if cost.get("research", 0) != 0:parts.append("%+d研究" % cost["research"])
	if cost.get("ap", 0) != 0:      parts.append("%+d行动力" % cost["ap"])
	return ", ".join(parts) if not parts.is_empty() else "免费"
