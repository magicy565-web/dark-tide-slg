## cave_panel.gd — 洞穴/遗迹/巢穴专属 UI 面板
## 提供探索、清剿、黑市交易、改造升级的完整交互界面。
## 版本: v1.0.0
extends CanvasLayer

const CLR_GOLD   := Color(0.9, 0.8, 0.4)
const CLR_CYAN   := Color(0.4, 0.8, 0.8)
const CLR_GREEN  := Color(0.4, 0.8, 0.4)
const CLR_RED    := Color(0.9, 0.3, 0.3)
const CLR_ORANGE := Color(0.9, 0.6, 0.2)
const CLR_GRAY   := Color(0.5, 0.5, 0.5)
const CLR_TEXT   := Color(0.85, 0.85, 0.85)
const CLR_DARK   := Color(0.15, 0.10, 0.08, 0.97)

var _tile_idx: int = -1
var _root: Control
var _main_panel: PanelContainer
var _title_label: Label
var _level_label: Label
var _status_label: Label
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
	style.border_color = Color(0.4, 0.3, 0.2, 0.9)
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

	# 标题栏
	var header = _make_header()
	outer_vbox.add_child(header)

	# 标签页栏
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 2)
	outer_vbox.add_child(_tab_bar)
	_build_tabs()

	# 内容区域
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
	hdr_style.bg_color = Color(0.2, 0.12, 0.06)
	hbox.add_theme_stylebox_override("panel", hdr_style)

	var icon_lbl = Label.new()
	icon_lbl.text = "💀"
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_lbl.add_theme_constant_override("margin_left", 10)
	hbox.add_child(icon_lbl)

	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title_vbox)

	_title_label = Label.new()
	_title_label.text = "洞穴"
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", CLR_GOLD)
	title_vbox.add_child(_title_label)

	_level_label = Label.new()
	_level_label.text = "等级: 浅层洞穴"
	_level_label.add_theme_font_size_override("font_size", 11)
	_level_label.add_theme_color_override("font_color", CLR_GRAY)
	title_vbox.add_child(_level_label)

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
		["overview", "📊 概览"],
		["explore",  "🔦 探索"],
		["combat",   "⚔ 清剿"],
		["market",   "🛒 黑市"],
		["upgrade",  "⬆ 改造"],
	]
	for tab in tabs:
		var btn = Button.new()
		btn.text = tab[1]
		btn.custom_minimum_size = Vector2(0, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tab_id = tab[0]
		btn.pressed.connect(func(): _switch_tab(tab_id))
		_tab_bar.add_child(btn)

func _switch_tab(tab_id: String) -> void:
	_current_tab = tab_id
	_refresh_content()

# ═══════════════════════════════════════════════════════════════
#                    面板显示
# ═══════════════════════════════════════════════════════════════
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
	var data = GameManager.cave_system.get_cave_data(_tile_idx)
	var level_data = GameManager.cave_system.CAVE_LEVELS.get(data["level"], GameManager.cave_system.CAVE_LEVELS[1])

	_title_label.text = tile.get("name", "洞穴 #%d" % _tile_idx)
	_level_label.text = "等级 %d — %s  |  探索次数: %d" % [data["level"], level_data["name"], data["total_explored"]]
	_refresh_content()

func _refresh_content() -> void:
	for child in _content_vbox.get_children():
		child.queue_free()

	match _current_tab:
		"overview": _build_overview()
		"explore":  _build_explore()
		"combat":   _build_combat()
		"market":   _build_market()
		"upgrade":  _build_upgrade()

# ═══════════════════════════════════════════════════════════════
#                    概览标签页
# ═══════════════════════════════════════════════════════════════
func _build_overview() -> void:
	if _tile_idx < 0:
		return
	var data = GameManager.cave_system.get_cave_data(_tile_idx)
	var tile = GameManager.tiles[_tile_idx]
	var level_data = GameManager.cave_system.CAVE_LEVELS.get(data["level"], GameManager.cave_system.CAVE_LEVELS[1])

	_content_vbox.add_child(_make_section_title("洞穴状态"))

	var info_grid = GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 12)
	info_grid.add_theme_constant_override("v_separation", 6)
	_content_vbox.add_child(info_grid)

	var cleared_text: String = "[color=lime]已清剿[/color]" if data["cleared"] else "[color=red]有怪物[/color]"
	var cooldown_text: String = "可探索" if data["explore_cooldown"] == 0 else "冷却 %d 回合" % data["explore_cooldown"]

	_add_info_row(info_grid, "状态", "[已清剿]" if data["cleared"] else "[怪物出没]", CLR_GREEN if data["cleared"] else CLR_RED)
	_add_info_row(info_grid, "探索", cooldown_text, CLR_GREEN if data["explore_cooldown"] == 0 else CLR_ORANGE)
	_add_info_row(info_grid, "驻军", "%d 人" % tile.get("garrison", 0), CLR_TEXT)
	_add_info_row(info_grid, "改造", ", ".join(data["upgrades"]) if not data["upgrades"].is_empty() else "未改造", CLR_CYAN)

	if not data["cleared"]:
		_content_vbox.add_child(_make_section_title("怪物信息"))
		var monster_id: String = data.get("monster_id", "")
		for m in GameManager.cave_system.MONSTER_TYPES:
			if m["id"] == monster_id:
				var monster_box = _make_info_box()
				monster_box.add_child(_make_label("🐉 %s" % m["name"], CLR_RED, 14))
				monster_box.add_child(_make_label("战力: %d  |  当前HP: %d" % [m["power"], data["monster_hp"]], CLR_TEXT, 12))
				_content_vbox.add_child(monster_box)
				break

	if level_data.get("black_market", false):
		_content_vbox.add_child(_make_section_title("黑市状态"))
		var bm_label = _make_label("🛒 黑市开放中，%d 件商品可购买（每 5 回合刷新）" % data["black_market_stock"].size(), CLR_GOLD, 12)
		_content_vbox.add_child(bm_label)

# ═══════════════════════════════════════════════════════════════
#                    探索标签页
# ═══════════════════════════════════════════════════════════════
func _build_explore() -> void:
	var data = GameManager.cave_system.get_cave_data(_tile_idx)
	_content_vbox.add_child(_make_section_title("洞穴探索"))

	var desc = _make_label("探索洞穴可触发随机事件，获得资源、遗物或遭遇怪物。\n探索后需等待 2 回合冷却。", CLR_TEXT, 12)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_vbox.add_child(desc)

	# 可能的事件预览
	_content_vbox.add_child(_make_section_title("可能遭遇（概率预览）"))
	var events_box = _make_info_box()
	for event in GameManager.cave_system.EXPLORE_EVENTS:
		var color: Color = CLR_RED if event.get("negative", false) else CLR_GREEN
		var reward_text: String = _format_rewards(event.get("reward", {}))
		events_box.add_child(_make_label("• %s — %s" % [event["name"], reward_text], color, 11))
	_content_vbox.add_child(events_box)

	# 探索按钮
	var cooldown: int = data["explore_cooldown"]
	var ap: int = GameManager.current_ap
	var can_explore: bool = cooldown == 0 and ap >= 1

	var btn_explore = _make_action_button(
		"🔦 探索洞穴（消耗 1 行动力）",
		can_explore,
		"" if can_explore else ("冷却中（%d 回合）" % cooldown if cooldown > 0 else "行动力不足")
	)
	btn_explore.pressed.connect(_on_explore_pressed)
	_content_vbox.add_child(btn_explore)

# ═══════════════════════════════════════════════════════════════
#                    清剿标签页
# ═══════════════════════════════════════════════════════════════
func _build_combat() -> void:
	var data = GameManager.cave_system.get_cave_data(_tile_idx)
	var tile = GameManager.tiles[_tile_idx]
	_content_vbox.add_child(_make_section_title("清剿怪物"))

	if data["cleared"]:
		_content_vbox.add_child(_make_label("✅ 洞穴已清剿，怪物已被消灭。", CLR_GREEN, 13))
		return

	var monster_id: String = data.get("monster_id", "")
	var monster_info: Dictionary = {}
	for m in GameManager.cave_system.MONSTER_TYPES:
		if m["id"] == monster_id:
			monster_info = m
			break

	if not monster_info.is_empty():
		var monster_box = _make_info_box()
		monster_box.add_child(_make_label("🐉 目标: %s" % monster_info["name"], CLR_RED, 14))
		monster_box.add_child(_make_label("怪物战力: %d" % monster_info["power"], CLR_TEXT, 12))
		monster_box.add_child(_make_label("清剿奖励: %s" % _format_rewards(monster_info["reward"]), CLR_GOLD, 12))
		_content_vbox.add_child(monster_box)

	var garrison: int = tile.get("garrison", 0)
	var garrison_power: int = garrison * 2
	var can_clear: bool = garrison >= 5

	var status_box = _make_info_box()
	status_box.add_child(_make_label("我方驻军: %d 人（战力 %d）" % [garrison, garrison_power], CLR_TEXT, 12))
	var result_text: String = "预计胜利" if can_clear else "驻军不足，可能失败"
	status_box.add_child(_make_label("预估结果: %s" % result_text, CLR_GREEN if can_clear else CLR_RED, 12))
	_content_vbox.add_child(status_box)

	var btn_clear = _make_action_button(
		"⚔ 清剿怪物（需要 5+ 驻军）",
		can_clear,
		"" if can_clear else "驻军不足（当前 %d 人）" % garrison
	)
	btn_clear.pressed.connect(_on_clear_pressed)
	_content_vbox.add_child(btn_clear)

# ═══════════════════════════════════════════════════════════════
#                    黑市标签页
# ═══════════════════════════════════════════════════════════════
func _build_market() -> void:
	var data = GameManager.cave_system.get_cave_data(_tile_idx)
	var level_data = GameManager.cave_system.CAVE_LEVELS.get(data["level"], GameManager.cave_system.CAVE_LEVELS[1])

	_content_vbox.add_child(_make_section_title("地下黑市"))

	if not level_data.get("black_market", false):
		_content_vbox.add_child(_make_label("⚠ 当前洞穴等级不支持黑市（需要 Lv3+）", CLR_ORANGE, 12))
		return

	if data["black_market_stock"].is_empty():
		_content_vbox.add_child(_make_label("黑市暂时无货，等待下次刷新（每 5 回合）", CLR_GRAY, 12))
		return

	for item_id in data["black_market_stock"]:
		for bm_item in GameManager.cave_system.BLACK_MARKET_ITEMS:
			if bm_item["id"] == item_id:
				var item_box = _make_info_box()
				item_box.add_child(_make_label("🛒 %s" % bm_item["name"], CLR_GOLD, 13))
				item_box.add_child(_make_label(bm_item["desc"], CLR_TEXT, 11))
				item_box.add_child(_make_label("费用: %s" % _format_rewards(bm_item["cost"]), CLR_RED, 11))
				item_box.add_child(_make_label("获得: %s" % _format_rewards(bm_item["reward"]), CLR_GREEN, 11))

				var pid = GameManager.get_human_player_id()
				var can_buy = ResourceManager.can_afford(pid, bm_item["cost"])
				var btn_buy = _make_action_button("购买", can_buy, "" if can_buy else "资源不足")
				var captured_id = item_id
				btn_buy.pressed.connect(func(): _on_buy_market_pressed(captured_id))
				item_box.add_child(btn_buy)
				_content_vbox.add_child(item_box)
				break

# ═══════════════════════════════════════════════════════════════
#                    改造标签页
# ═══════════════════════════════════════════════════════════════
func _build_upgrade() -> void:
	var data = GameManager.cave_system.get_cave_data(_tile_idx)
	_content_vbox.add_child(_make_section_title("洞穴改造"))

	for upgrade_id in GameManager.cave_system.UPGRADE_PATHS:
		var upgrade = GameManager.cave_system.UPGRADE_PATHS[upgrade_id]
		var already_done: bool = upgrade_id in data["upgrades"]
		var needs_cleared: bool = upgrade.get("requires_cleared", false) and not data["cleared"]

		var box = _make_info_box()
		box.add_child(_make_label("⬆ %s" % upgrade["name"], CLR_CYAN if not already_done else CLR_GRAY, 13))
		box.add_child(_make_label(upgrade["desc"], CLR_TEXT, 11))
		box.add_child(_make_label("费用: %s" % _format_rewards(upgrade["cost"]), CLR_RED, 11))

		if already_done:
			box.add_child(_make_label("✅ 已完成", CLR_GREEN, 11))
		else:
			var pid = GameManager.get_human_player_id()
			var can_upgrade = ResourceManager.can_afford(pid, upgrade["cost"]) and not needs_cleared
			var reason: String = ""
			if needs_cleared:
				reason = "需要先清剿怪物"
			elif not can_upgrade:
				reason = "资源不足"
			var btn = _make_action_button("改造", can_upgrade, reason)
			var captured_id = upgrade_id
			btn.pressed.connect(func(): _on_upgrade_pressed(captured_id))
			box.add_child(btn)

		_content_vbox.add_child(box)

# ═══════════════════════════════════════════════════════════════
#                    按钮回调
# ═══════════════════════════════════════════════════════════════
func _on_explore_pressed() -> void:
	var result = GameManager.cave_system.explore(_tile_idx)
	if result["success"]:
		_refresh()
	else:
		EventBus.message_log.emit("[color=red]【洞穴】%s[/color]" % result.get("reason", ""))

func _on_clear_pressed() -> void:
	var result = GameManager.cave_system.clear_monsters(_tile_idx)
	_refresh()

func _on_buy_market_pressed(item_id: String) -> void:
	var result = GameManager.cave_system.buy_black_market(_tile_idx, item_id)
	if result["success"]:
		_refresh()
	else:
		EventBus.message_log.emit("[color=red]【黑市】%s[/color]" % result.get("reason", ""))

func _on_upgrade_pressed(upgrade_id: String) -> void:
	var result = GameManager.cave_system.upgrade_cave(_tile_idx, upgrade_id)
	if result["success"]:
		_refresh()
	else:
		EventBus.message_log.emit("[color=red]【改造】%s[/color]" % result.get("reason", ""))

# ═══════════════════════════════════════════════════════════════
#                    辅助 UI 构建
# ═══════════════════════════════════════════════════════════════
func _make_section_title(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = "── %s ──" % text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", CLR_GOLD)
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
	style.bg_color = Color(0.1, 0.08, 0.06, 0.8)
	style.border_color = Color(0.3, 0.25, 0.15, 0.6)
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

func _make_action_button(text: String, enabled: bool, disabled_reason: String = "") -> Button:
	var btn = Button.new()
	btn.text = text if enabled else "%s（%s）" % [text, disabled_reason]
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(0, 34)
	if enabled:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.25, 0.18, 0.08)
		style.border_color = CLR_GOLD
		style.set_border_width_all(1)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)
	return btn

func _add_info_row(grid: GridContainer, key: String, value: String, value_color: Color) -> void:
	var key_lbl = Label.new()
	key_lbl.text = key + ":"
	key_lbl.add_theme_color_override("font_color", CLR_GRAY)
	key_lbl.add_theme_font_size_override("font_size", 12)
	grid.add_child(key_lbl)
	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_color_override("font_color", value_color)
	val_lbl.add_theme_font_size_override("font_size", 12)
	grid.add_child(val_lbl)

func _format_rewards(rewards: Dictionary) -> String:
	var parts: Array = []
	if rewards.get("gold", 0) != 0:    parts.append("%+d金" % rewards["gold"])
	if rewards.get("iron", 0) != 0:    parts.append("%+d铁" % rewards["iron"])
	if rewards.get("food", 0) != 0:    parts.append("%+d粮" % rewards["food"])
	if rewards.get("morale", 0) != 0:  parts.append("%+d民心" % rewards["morale"])
	if rewards.get("garrison", 0) > 0: parts.append("+%d驻军" % rewards["garrison"])
	if rewards.get("research", 0) > 0: parts.append("+%d研究" % rewards["research"])
	if rewards.get("espionage", 0) > 0:parts.append("+%d情报" % rewards["espionage"])
	return ", ".join(parts) if not parts.is_empty() else "无"
