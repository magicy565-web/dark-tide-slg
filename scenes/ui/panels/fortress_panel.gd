## fortress_panel.gd — 要塞/城堡专属 UI 面板
## 提供城防管理、驻军命令、防御工事建造、要塞升级的完整交互界面。
## 版本: v1.0.0
extends CanvasLayer

const CLR_GOLD   := Color(0.9, 0.8, 0.4)
const CLR_CYAN   := Color(0.4, 0.8, 0.8)
const CLR_GREEN  := Color(0.4, 0.8, 0.4)
const CLR_RED    := Color(0.9, 0.3, 0.3)
const CLR_ORANGE := Color(0.9, 0.6, 0.2)
const CLR_GRAY   := Color(0.5, 0.5, 0.5)
const CLR_TEXT   := Color(0.85, 0.85, 0.85)
const CLR_DARK   := Color(0.06, 0.08, 0.14, 0.97)

var _tile_idx: int = -1
var _root: Control
var _main_panel: PanelContainer
var _title_label: Label
var _level_label: Label
var _wall_bar: ProgressBar
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
	style.border_color = Color(0.4, 0.5, 0.7, 0.9)
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
	outer_vbox.add_child(_make_wall_bar_section())

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
	hdr_style.bg_color = Color(0.08, 0.10, 0.20)
	hbox.add_theme_stylebox_override("panel", hdr_style)

	var icon = Label.new()
	icon.text = "🏰"
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_constant_override("margin_left", 10)
	hbox.add_child(icon)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "要塞"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", CLR_CYAN)
	vbox.add_child(_title_label)

	_level_label = Label.new()
	_level_label.text = "木栅寨  |  驻军: 0/20  |  声望: 0"
	_level_label.add_theme_font_size_override("font_size", 11)
	_level_label.add_theme_color_override("font_color", CLR_GRAY)
	vbox.add_child(_level_label)

	var btn_close = Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.pressed.connect(hide_panel)
	hbox.add_child(btn_close)
	return hbox

func _make_wall_bar_section() -> Control:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	var pad_style = StyleBoxFlat.new()
	pad_style.bg_color = Color(0.05, 0.06, 0.12)
	pad_style.content_margin_left = 10
	pad_style.content_margin_right = 10
	pad_style.content_margin_top = 4
	pad_style.content_margin_bottom = 4
	vbox.add_theme_stylebox_override("panel", pad_style)

	var lbl = Label.new()
	lbl.text = "城墙耐久"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", CLR_GRAY)
	vbox.add_child(lbl)

	_wall_bar = ProgressBar.new()
	_wall_bar.custom_minimum_size = Vector2(0, 14)
	_wall_bar.min_value = 0
	_wall_bar.max_value = 100
	_wall_bar.value = 100
	_wall_bar.show_percentage = true
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.3, 0.5, 0.8)
	_wall_bar.add_theme_stylebox_override("fill", bar_style)
	vbox.add_child(_wall_bar)
	return vbox

func _build_tabs() -> void:
	for child in _tab_bar.get_children():
		child.queue_free()
	var tabs = [
		["overview",  "📊 概览"],
		["garrison",  "🪖 驻军"],
		["fortify",   "🏗 工事"],
		["orders",    "📯 命令"],
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
	if _tile_idx < 0 or _tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[_tile_idx]
	var data = GameManager.fortress_system.get_fortress_data(_tile_idx)
	var level_data = GameManager.fortress_system.FORTRESS_LEVELS.get(data["level"], GameManager.fortress_system.FORTRESS_LEVELS[1])

	_title_label.text = tile.get("name", "要塞 #%d" % _tile_idx)
	_level_label.text = "Lv%d %s  |  驻军: %d/%d  |  声望: %d" % [
		data["level"], level_data["name"],
		tile.get("garrison", 0), level_data["garrison_cap"],
		data["prestige"]
	]
	_wall_bar.max_value = data["wall_hp_max"]
	_wall_bar.value = data["wall_hp"]
	_refresh_content()

func _refresh_content() -> void:
	for child in _content_vbox.get_children():
		child.queue_free()
	match _current_tab:
		"overview": _build_overview()
		"garrison": _build_garrison()
		"fortify":  _build_fortify()
		"orders":   _build_orders()
		"upgrade":  _build_upgrade()

# ─── 概览 ───
func _build_overview() -> void:
	var data = GameManager.fortress_system.get_fortress_data(_tile_idx)
	if _tile_idx < 0 or _tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[_tile_idx]
	var level_data = GameManager.fortress_system.FORTRESS_LEVELS.get(data["level"], GameManager.fortress_system.FORTRESS_LEVELS[1])
	var bld_effects = GameManager.fortress_system.get_fortification_effects(_tile_idx)

	_content_vbox.add_child(_make_section_title("要塞状态"))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	_content_vbox.add_child(grid)

	var wall_pct: float = float(data["wall_hp"]) / float(maxi(int(data["wall_hp_max"]), 1)) * 100.0
	_add_info_row(grid, "城墙", "%d/%d (%.0f%%)" % [data["wall_hp"], data["wall_hp_max"], wall_pct],
		CLR_GREEN if wall_pct > 60 else (CLR_ORANGE if wall_pct > 30 else CLR_RED))
	_add_info_row(grid, "防御加成", "+%d" % (level_data["def_bonus"] + bld_effects.get("def_bonus", 0)), CLR_CYAN)
	_add_info_row(grid, "驻军", "%d/%d" % [tile.get("garrison", 0), level_data["garrison_cap"] + bld_effects.get("garrison_cap", 0)], CLR_TEXT)
	_add_info_row(grid, "当前命令", GameManager.fortress_system.GARRISON_ORDERS.get(data["garrison_order"], {}).get("name", "无"), CLR_GOLD)
	_add_info_row(grid, "声望", "%d/10" % data["prestige"], CLR_GOLD)
	_add_info_row(grid, "历史防守", "%d 次" % data["total_battles_defended"], CLR_TEXT)

	# 建筑效果汇总
	if not data["buildings"].is_empty():
		_content_vbox.add_child(_make_section_title("工事效果汇总"))
		var eff_box = _make_info_box()
		if bld_effects.get("siege_damage_per_turn", 0) > 0:
			eff_box.add_child(_make_label("箭楼伤害 %d/回合" % bld_effects["siege_damage_per_turn"], CLR_RED, 12))
		if bld_effects.get("auto_recruit", 0) > 0:
			eff_box.add_child(_make_label("自动征兵 %d/回合" % bld_effects["auto_recruit"], CLR_GREEN, 12))
		if bld_effects.get("vision_range", 0) > 0:
			eff_box.add_child(_make_label("视野范围 +%d" % bld_effects["vision_range"], CLR_CYAN, 12))
		if bld_effects.get("assault_penalty", 0.0) > 0:
			eff_box.add_child(_make_label("护城河：攻城方 -%.0f%%" % (bld_effects["assault_penalty"] * 100), CLR_ORANGE, 12))
		_content_vbox.add_child(eff_box)

	# 修缮城墙按钮
	if data["wall_hp"] < data["wall_hp_max"]:
		_content_vbox.add_child(_make_section_title("城墙维护"))
		var repair_needed: int = data["wall_hp_max"] - data["wall_hp"]
		var repair_cost: Dictionary = {"gold": int(repair_needed * 0.5), "iron": int(repair_needed * 0.3)}
		var pid = GameManager.get_human_player_id()
		var can_repair = ResourceManager.can_afford(pid, repair_cost)
		var btn = _make_action_button(
			"🔨 修缮城墙（%s）" % _format_cost(repair_cost),
			can_repair, "资源不足" if not can_repair else ""
		)
		btn.pressed.connect(_on_repair_pressed)
		_content_vbox.add_child(btn)

# ─── 驻军 ───
func _build_garrison() -> void:
	var data = GameManager.fortress_system.get_fortress_data(_tile_idx)
	if _tile_idx < 0 or _tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[_tile_idx]
	var level_data = GameManager.fortress_system.FORTRESS_LEVELS.get(data["level"], GameManager.fortress_system.FORTRESS_LEVELS[1])
	var bld_effects = GameManager.fortress_system.get_fortification_effects(_tile_idx)
	var garrison_cap: int = level_data["garrison_cap"] + bld_effects.get("garrison_cap", 0)
	var current_garrison: int = tile.get("garrison", 0)

	_content_vbox.add_child(_make_section_title("驻军管理"))

	var stat_box = _make_info_box()
	stat_box.add_child(_make_label("当前驻军: %d / %d" % [current_garrison, garrison_cap], CLR_TEXT, 13))
	if bld_effects.get("garrison_atk", 0) > 0:
		stat_box.add_child(_make_label("驻军攻击 +%d（军械库加成）" % bld_effects["garrison_atk"], CLR_RED, 12))
	if bld_effects.get("garrison_def", 0) > 0:
		stat_box.add_child(_make_label("驻军防御 +%d（军械库加成）" % bld_effects["garrison_def"], CLR_CYAN, 12))
	if bld_effects.get("auto_recruit", 0) > 0:
		stat_box.add_child(_make_label("自动补充 +%d/回合（兵营加成）" % bld_effects["auto_recruit"], CLR_GREEN, 12))
	_content_vbox.add_child(stat_box)

	# 围城抵抗力评估
	_content_vbox.add_child(_make_section_title("围城抵抗评估"))
	var siege_turns: int = level_data["siege_turns"] + bld_effects.get("siege_supply_turns", 0)
	var siege_box = _make_info_box()
	siege_box.add_child(_make_label("预计可抵御围城: %d 回合" % siege_turns, CLR_GOLD, 13))
	siege_box.add_child(_make_label("城墙吸收伤害: %.0f%%" % (GameManager.fortress_system.SIEGE_PARAMS["wall_block_ratio"] * 100), CLR_CYAN, 12))
	siege_box.add_child(_make_label("防御加成: +%d" % (level_data["def_bonus"] + bld_effects.get("def_bonus", 0)), CLR_CYAN, 12))
	_content_vbox.add_child(siege_box)

# ─── 防御工事 ───
func _build_fortify() -> void:
	var data = GameManager.fortress_system.get_fortress_data(_tile_idx)
	var pid = GameManager.get_human_player_id()

	_content_vbox.add_child(_make_section_title("防御工事建造"))

	for bld_id in GameManager.fortress_system.FORTIFICATION_BUILDINGS:
		var bld = GameManager.fortress_system.FORTIFICATION_BUILDINGS[bld_id]
		var current_level: int = data["buildings"].get(bld_id, 0)
		var is_max: bool = current_level >= bld["max_level"]
		var has_prereq: bool = not bld.has("requires") or data["buildings"].has(bld["requires"])

		var box = _make_info_box()
		var title_color: Color = CLR_CYAN if current_level > 0 else CLR_TEXT
		box.add_child(_make_label("%s %s %s" % [bld["icon"], bld["name"], ("Lv%d" % current_level) if current_level > 0 else ""], title_color, 13))
		box.add_child(_make_label(bld["desc"], CLR_GRAY, 11))

		var cost_dict: Dictionary = {}
		for k in bld["cost"]:
			cost_dict[k] = int(bld["cost"][k] * (1.0 + current_level * 0.6))
		box.add_child(_make_label("费用: %s" % _format_cost(cost_dict), CLR_RED, 11))

		# 效果预览
		var eff_parts: Array = []
		for k in bld["effects"]:
			var base_val = bld["effects"][k]
			var scaling = bld.get("level_scaling", {}).get(k, 0)
			var next_val = base_val + scaling * current_level
			eff_parts.append("%s: %s" % [k, str(next_val)])
		box.add_child(_make_label("效果: %s" % ", ".join(eff_parts), CLR_GREEN, 11))

		if is_max:
			box.add_child(_make_label("✅ 已达最高等级", CLR_GREEN, 11))
		elif not has_prereq:
			box.add_child(_make_label("⚠ 需要先建造 %s" % GameManager.fortress_system.FORTIFICATION_BUILDINGS[bld["requires"]]["name"], CLR_ORANGE, 11))
		else:
			var can_build = ResourceManager.can_afford(pid, cost_dict)
			var action_text: String = "建造" if current_level == 0 else "升级至 Lv%d" % (current_level + 1)
			var btn = _make_action_button(action_text, can_build, "资源不足" if not can_build else "")
			var captured_id = bld_id
			btn.pressed.connect(func(): _on_fortify_pressed(captured_id))
			box.add_child(btn)

		_content_vbox.add_child(box)

# ─── 驻军命令 ───
func _build_orders() -> void:
	var data = GameManager.fortress_system.get_fortress_data(_tile_idx)
	if _tile_idx < 0 or _tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[_tile_idx]
	var pid = GameManager.get_human_player_id()

	_content_vbox.add_child(_make_section_title("驻军命令"))

	for order_id in GameManager.fortress_system.GARRISON_ORDERS:
		var order = GameManager.fortress_system.GARRISON_ORDERS[order_id]
		var is_active: bool = data["garrison_order"] == order_id
		var cooldown: int = data["order_cooldowns"].get(order_id, 0)
		var is_one_time: bool = order.has("cost")

		var box = _make_info_box()
		var title_color: Color = CLR_GOLD if is_active else CLR_TEXT
		box.add_child(_make_label("%s %s%s" % [order["icon"], order["name"], " [当前]" if is_active else ""], title_color, 13))
		box.add_child(_make_label(order["desc"], CLR_GRAY, 11))

		if is_one_time:
			# 一次性行动
			if cooldown > 0:
				box.add_child(_make_label("⏳ 冷却中（%d 回合）" % cooldown, CLR_ORANGE, 11))
			else:
				var cost = order.get("cost", {})
				var ap_cost: int = cost.get("ap", 0)
				var garrison_cost: int = cost.get("garrison", 0)
				var res_cost: Dictionary = {}
				for k in cost:
					if k not in ["ap", "garrison"]:
						res_cost[k] = cost[k]
				var can_act: bool = (
					GameManager.current_ap >= ap_cost and
					tile.get("garrison", 0) >= garrison_cost and
					(res_cost.is_empty() or ResourceManager.can_afford(pid, res_cost))
				)
				var reason: String = ""
				if GameManager.current_ap < ap_cost: reason = "行动力不足"
				elif tile.get("garrison", 0) < garrison_cost: reason = "驻军不足"
				elif not res_cost.is_empty() and not ResourceManager.can_afford(pid, res_cost): reason = "资源不足"
				var btn = _make_action_button("执行", can_act, reason)
				var captured_id = order_id
				btn.pressed.connect(func(): _on_order_pressed(captured_id))
				box.add_child(btn)
		else:
			# 持续命令
			if not is_active:
				var btn = _make_action_button("切换命令", true)
				var captured_id = order_id
				btn.pressed.connect(func(): _on_order_pressed(captured_id))
				box.add_child(btn)

		_content_vbox.add_child(box)

# ─── 升级 ───
func _build_upgrade() -> void:
	var data = GameManager.fortress_system.get_fortress_data(_tile_idx)
	var current_level: int = data["level"]
	var pid = GameManager.get_human_player_id()

	_content_vbox.add_child(_make_section_title("要塞升级"))

	if current_level >= 5:
		_content_vbox.add_child(_make_label("✅ 已达最高等级（天堑雄关）", CLR_GOLD, 13))
		return

	var next_level_data = GameManager.fortress_system.FORTRESS_LEVELS.get(current_level + 1, {})
	var upgrade_cost: Dictionary = {"gold": 100 * current_level, "iron": 50 * current_level}

	var box = _make_info_box()
	box.add_child(_make_label("升级至: Lv%d %s" % [current_level + 1, next_level_data.get("name", "")], CLR_GOLD, 14))
	box.add_child(_make_label("费用: %s" % _format_cost(upgrade_cost), CLR_RED, 12))
	box.add_child(_make_label("升级后: 城墙 %d，防御 +%d，驻军上限 %d，围城 %d 回合" % [
		next_level_data.get("wall_hp", 0), next_level_data.get("def_bonus", 0),
		next_level_data.get("garrison_cap", 0), next_level_data.get("siege_turns", 0)
	], CLR_CYAN, 12))
	box.add_child(_make_label("升级后城墙自动修复至满血", CLR_GREEN, 11))

	var can_upgrade = ResourceManager.can_afford(pid, upgrade_cost)
	var btn = _make_action_button("升级要塞", can_upgrade, "资源不足" if not can_upgrade else "")
	btn.pressed.connect(_on_upgrade_pressed)
	box.add_child(btn)
	_content_vbox.add_child(box)

# ─── 按钮回调 ───
func _on_repair_pressed() -> void:
	var result = GameManager.fortress_system.repair_walls(_tile_idx)
	if result["success"]: _refresh()
	else: EventBus.message_log.emit("[color=red]【要塞】%s[/color]" % result.get("reason", ""))

func _on_fortify_pressed(bld_id: String) -> void:
	var result = GameManager.fortress_system.build_fortification(_tile_idx, bld_id)
	if result["success"]: _refresh()
	else: EventBus.message_log.emit("[color=red]【工事】%s[/color]" % result.get("reason", ""))

func _on_order_pressed(order_id: String) -> void:
	var result = GameManager.fortress_system.issue_garrison_order(_tile_idx, order_id)
	if result["success"]: _refresh()
	else: EventBus.message_log.emit("[color=red]【命令】%s[/color]" % result.get("reason", ""))

func _on_upgrade_pressed() -> void:
	var result = GameManager.fortress_system.upgrade_fortress(_tile_idx)
	if result["success"]: _refresh()
	else: EventBus.message_log.emit("[color=red]【要塞升级】%s[/color]" % result.get("reason", ""))

# ─── 辅助 ───
func _make_section_title(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = "── %s ──" % text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", CLR_CYAN)
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
	style.bg_color = Color(0.05, 0.06, 0.12, 0.8)
	style.border_color = Color(0.2, 0.3, 0.5, 0.6)
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
	if cost.get("gold", 0) != 0:  parts.append("%+d金" % cost["gold"])
	if cost.get("iron", 0) != 0:  parts.append("%+d铁" % cost["iron"])
	if cost.get("food", 0) != 0:  parts.append("%+d粮" % cost["food"])
	if cost.get("ap", 0) != 0:    parts.append("%+d行动力" % cost["ap"])
	if cost.get("garrison", 0) != 0: parts.append("%+d驻军" % cost["garrison"])
	return ", ".join(parts) if not parts.is_empty() else "免费"
