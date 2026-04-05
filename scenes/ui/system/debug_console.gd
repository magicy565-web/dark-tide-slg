## debug_console.gd — Full debug/command console for 暗潮 SLG.
## Code-only panel (no .tscn). Toggle with backtick/tilde key.
## Usage: add as child of a CanvasLayer(layer=10) or call DebugConsole.new() and add to tree.
extends Control

# ═══════════════════════════════════════════════════════════════
#                        CONSTANTS
# ═══════════════════════════════════════════════════════════════

const BG_COLOR := Color(0.05, 0.05, 0.08, 0.95)
const BG_HEADER := Color(0.08, 0.07, 0.12, 0.98)
const BG_INPUT := Color(0.04, 0.04, 0.06, 1.0)
const BG_TAB_ACTIVE := Color(0.12, 0.10, 0.18, 1.0)
const BG_TAB_INACTIVE := Color(0.06, 0.06, 0.10, 0.8)
const TEXT_GREEN := Color(0.3, 0.9, 0.35)
const TEXT_YELLOW := Color(1.0, 0.85, 0.3)
const TEXT_RED := Color(1.0, 0.3, 0.3)
const TEXT_CYAN := Color(0.4, 0.85, 1.0)
const TEXT_WHITE := Color(0.9, 0.9, 0.9)
const TEXT_DIM := Color(0.5, 0.5, 0.55)
const BORDER_COLOR := Color(0.3, 0.25, 0.15, 0.6)
const ACCENT := Color(0.85, 0.7, 0.3)

const SLIDE_DURATION := 0.25
const PANEL_HEIGHT_RATIO := 0.4
const MAX_HISTORY := 100
const MAX_LOG_LINES := 500
const MAX_EVENT_LOG := 300

enum Tab { CONSOLE, GAME_STATE, BALANCE, EVENT_LOG }

const TAB_NAMES: Array = ["控制台", "游戏状态", "平衡监视", "事件日志"]

# ═══════════════════════════════════════════════════════════════
#                     NODE REFERENCES
# ═══════════════════════════════════════════════════════════════

var canvas_layer: CanvasLayer
var panel: PanelContainer
var header_bar: HBoxContainer
var title_label: Label
var close_btn: Button
var fps_label: Label
var tab_bar: HBoxContainer
var tab_buttons: Array[Button] = []
var tab_container: Control

# Console tab
var console_output: RichTextLabel
var input_line: LineEdit
var autocomplete_popup: PanelContainer
var autocomplete_list: VBoxContainer

# Game state tab
var state_grid: GridContainer
var state_labels: Dictionary = {}

# Balance tab
var balance_scroll: ScrollContainer
var balance_vbox: VBoxContainer

# Event log tab
var event_scroll: ScrollContainer
var event_vbox: VBoxContainer
var event_filter_input: LineEdit

# ═══════════════════════════════════════════════════════════════
#                        STATE
# ═══════════════════════════════════════════════════════════════

var _visible_flag: bool = false
var _current_tab: int = Tab.CONSOLE
var _command_history: Array[String] = []
var _history_index: int = -1
var _event_log: Array[Dictionary] = []
var _signal_spy: bool = false
var _god_mode: bool = false
var _slide_tween: Tween
var _panel_target_y: float = 0.0
var _panel_hidden_y: float = 0.0
var _connected_signals: Array[String] = []

# Command definitions: { name: String, args: String, desc: String }
var _commands: Array[Dictionary] = []
var _command_names: Array[String] = []

# ═══════════════════════════════════════════════════════════════
#                     INITIALIZATION
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_register_commands()
	_build_ui()
	_connect_event_bus()
	set_process_input(true)
	set_process(true)
	visible = true  # Canvas layer controls visibility via panel position


func _register_commands() -> void:
	# Placeholder — filled in _register_commands_impl
	_register_commands_impl()
	for cmd in _commands:
		_command_names.append(cmd["name"])


func _register_commands_impl() -> void:
	_cmd("help", "", "显示所有可用命令")
	_cmd("clear", "", "清空控制台输出")
	_cmd("give gold", "<amount>", "增加金币")
	_cmd("give food", "<amount>", "增加食物")
	_cmd("give iron", "<amount>", "增加铁矿")
	_cmd("give ap", "<amount>", "增加行动点数")
	_cmd("set turn", "<number>", "设置当前回合数")
	_cmd("set threat", "<value>", "设置威胁值")
	_cmd("set order", "<value>", "设置秩序值")
	_cmd("spawn", "<troop_id> [count]", "在选中地块生成部队")
	_cmd("tp", "<tile_index>", "传送选中军队到指定地块")
	_cmd("reveal", "", "移除全部战争迷雾")
	_cmd("god", "", "切换上帝模式 (无限AP/资源)")
	_cmd("win", "", "触发胜利条件")
	_cmd("kill", "<army_id>", "销毁指定军队")
	_cmd("heal", "", "完全治愈玩家所有军队")
	_cmd("research", "<tech_id>", "立即完成研究")
	_cmd("level", "<hero_id> <level>", "设置英雄等级")
	_cmd("dump state", "", "输出完整游戏状态")
	_cmd("dump tiles", "", "输出所有地块数据")
	_cmd("dump armies", "", "输出所有军队数据")
	_cmd("eval", "<expression>", "执行GDScript表达式 (危险)")
	_cmd("speed", "<1-10>", "设置游戏速度倍率")
	_cmd("spy", "", "切换信号监听模式")


func _cmd(cmd_name: String, args: String, desc: String) -> void:
	_commands.append({"name": cmd_name, "args": args, "desc": desc})


# ═══════════════════════════════════════════════════════════════
#                        BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# Root canvas layer to sit above everything
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = UILayerRegistry.LAYER_DEBUG_CONSOLE
	add_child(canvas_layer)

	var screen_size := get_viewport().get_visible_rect().size
	if screen_size == Vector2.ZERO:
		screen_size = Vector2(1920, 1080)
	var panel_h := screen_size.y * PANEL_HEIGHT_RATIO
	_panel_target_y = screen_size.y - panel_h
	_panel_hidden_y = screen_size.y

	# Main panel
	panel = PanelContainer.new()
	panel.position = Vector2(0, _panel_hidden_y)
	panel.size = Vector2(screen_size.x, panel_h)
	panel.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR))
	canvas_layer.add_child(panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(root_vbox)

	# ── Header bar ──
	_build_header(root_vbox)

	# ── Tab bar ──
	_build_tab_bar(root_vbox)

	# ── Tab content container ──
	tab_container = Control.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.clip_contents = true
	root_vbox.add_child(tab_container)

	_build_console_tab()
	_build_state_tab()
	_build_balance_tab()
	_build_event_log_tab()

	_switch_tab(Tab.CONSOLE)


func _build_header(parent: VBoxContainer) -> void:
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", _make_panel_style(BG_HEADER, BORDER_COLOR, 0, 0, 4))
	header_panel.custom_minimum_size.y = 32
	parent.add_child(header_panel)

	header_bar = HBoxContainer.new()
	header_bar.add_theme_constant_override("separation", 12)
	header_panel.add_child(header_bar)

	title_label = Label.new()
	title_label.text = "指令控制台 [DEBUG]"
	title_label.add_theme_color_override("font_color", ACCENT)
	title_label.add_theme_font_size_override("font_size", 16)
	header_bar.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(spacer)

	fps_label = Label.new()
	fps_label.text = "FPS: --  MEM: --"
	fps_label.add_theme_color_override("font_color", TEXT_DIM)
	fps_label.add_theme_font_size_override("font_size", 12)
	header_bar.add_child(fps_label)

	var god_indicator := Label.new()
	god_indicator.name = "GodIndicator"
	god_indicator.text = ""
	god_indicator.add_theme_color_override("font_color", TEXT_YELLOW)
	god_indicator.add_theme_font_size_override("font_size", 12)
	header_bar.add_child(god_indicator)

	close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", TEXT_WHITE)
	close_btn.add_theme_stylebox_override("normal", _make_flat_btn_style(Color.TRANSPARENT))
	close_btn.add_theme_stylebox_override("hover", _make_flat_btn_style(Color(0.3, 0.1, 0.1, 0.5)))
	close_btn.add_theme_stylebox_override("pressed", _make_flat_btn_style(Color(0.5, 0.1, 0.1, 0.5)))
	close_btn.pressed.connect(_toggle_console)
	header_bar.add_child(close_btn)


func _build_tab_bar(parent: VBoxContainer) -> void:
	var tab_panel := PanelContainer.new()
	tab_panel.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, Color.TRANSPARENT, 0, 0, 0))
	tab_panel.custom_minimum_size.y = 28
	parent.add_child(tab_panel)

	tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	tab_panel.add_child(tab_bar)

	for i in range(TAB_NAMES.size()):
		var btn := Button.new()
		btn.text = " %s " % TAB_NAMES[i]
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", TEXT_WHITE)
		btn.add_theme_stylebox_override("normal", _make_flat_btn_style(BG_TAB_INACTIVE))
		btn.add_theme_stylebox_override("hover", _make_flat_btn_style(BG_TAB_ACTIVE))
		btn.add_theme_stylebox_override("pressed", _make_flat_btn_style(BG_TAB_ACTIVE))
		btn.pressed.connect(_switch_tab.bind(i))
		tab_bar.add_child(btn)
		tab_buttons.append(btn)


func _build_console_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "ConsoleTab"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	tab_container.add_child(vbox)

	# Output area
	console_output = RichTextLabel.new()
	console_output.bbcode_enabled = true
	console_output.scroll_following = true
	console_output.selection_enabled = true
	console_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	console_output.add_theme_color_override("default_color", TEXT_GREEN)
	console_output.add_theme_font_size_override("normal_font_size", 13)
	console_output.add_theme_stylebox_override("normal", _make_panel_style(Color(0.03, 0.03, 0.05, 1.0), Color.TRANSPARENT, 0, 0, 6))
	vbox.add_child(console_output)

	# Input row
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 4)
	vbox.add_child(input_row)

	var prompt := Label.new()
	prompt.text = ">"
	prompt.add_theme_color_override("font_color", TEXT_GREEN)
	prompt.add_theme_font_size_override("font_size", 14)
	input_row.add_child(prompt)

	input_line = LineEdit.new()
	input_line.placeholder_text = "输入命令... (Tab 自动补全, ↑↓ 历史记录)"
	input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_line.add_theme_color_override("font_color", TEXT_GREEN)
	input_line.add_theme_color_override("font_placeholder_color", TEXT_DIM)
	input_line.add_theme_font_size_override("font_size", 13)
	input_line.add_theme_stylebox_override("normal", _make_panel_style(BG_INPUT, BORDER_COLOR, 1, 2, 4))
	input_line.add_theme_stylebox_override("focus", _make_panel_style(BG_INPUT, ACCENT, 1, 2, 4))
	input_line.text_submitted.connect(_on_command_submitted)
	input_row.add_child(input_line)

	# Autocomplete popup (hidden by default)
	autocomplete_popup = PanelContainer.new()
	autocomplete_popup.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.08, 0.12, 0.98), BORDER_COLOR, 1, 4, 4))
	autocomplete_popup.visible = false
	autocomplete_popup.z_index = 5
	vbox.add_child(autocomplete_popup)

	autocomplete_list = VBoxContainer.new()
	autocomplete_list.add_theme_constant_override("separation", 1)
	autocomplete_popup.add_child(autocomplete_list)

	_print_welcome()


func _build_state_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "StateTab"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_container.add_child(scroll)

	state_grid = GridContainer.new()
	state_grid.columns = 4
	state_grid.add_theme_constant_override("h_separation", 20)
	state_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(state_grid)


func _build_balance_tab() -> void:
	balance_scroll = ScrollContainer.new()
	balance_scroll.name = "BalanceTab"
	balance_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_container.add_child(balance_scroll)

	balance_vbox = VBoxContainer.new()
	balance_vbox.add_theme_constant_override("separation", 6)
	balance_scroll.add_child(balance_vbox)


func _build_event_log_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "EventLogTab"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	tab_container.add_child(vbox)

	# Filter input
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	vbox.add_child(filter_row)

	var filter_label := Label.new()
	filter_label.text = "过滤:"
	filter_label.add_theme_color_override("font_color", TEXT_DIM)
	filter_label.add_theme_font_size_override("font_size", 12)
	filter_row.add_child(filter_label)

	event_filter_input = LineEdit.new()
	event_filter_input.placeholder_text = "输入信号名称过滤..."
	event_filter_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_filter_input.add_theme_color_override("font_color", TEXT_CYAN)
	event_filter_input.add_theme_font_size_override("font_size", 12)
	event_filter_input.add_theme_stylebox_override("normal", _make_panel_style(BG_INPUT, BORDER_COLOR, 1, 2, 3))
	event_filter_input.text_changed.connect(_on_event_filter_changed)
	filter_row.add_child(event_filter_input)

	var clear_btn := Button.new()
	clear_btn.text = "清空"
	clear_btn.add_theme_font_size_override("font_size", 12)
	clear_btn.pressed.connect(func(): _event_log.clear(); _rebuild_event_log_display())
	filter_row.add_child(clear_btn)

	event_scroll = ScrollContainer.new()
	event_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(event_scroll)

	event_vbox = VBoxContainer.new()
	event_vbox.add_theme_constant_override("separation", 2)
	event_scroll.add_child(event_vbox)


# ═══════════════════════════════════════════════════════════════
#                     EVENT BUS CONNECTION
# ═══════════════════════════════════════════════════════════════

func _connect_event_bus() -> void:
	if not _has_autoload("EventBus"):
		return
	var bus := Engine.get_singleton("EventBus") if Engine.has_singleton("EventBus") else get_node_or_null("/root/EventBus")
	if not bus:
		return
	# Connect to all signals on the EventBus for signal spy / event log
	for sig_info in bus.get_signal_list():
		var sig_name: String = sig_info["name"]
		if sig_name.begins_with("script_"):
			continue
		_connected_signals.append(sig_name)
		# Use a lambda that captures sig_name. Variadic via Callable.
		var cb := _make_signal_callback(sig_name)
		if bus.has_signal(sig_name):
			# Godot 4: connect with CONNECT_REFERENCE_COUNTED to allow cleanup
			bus.connect(sig_name, cb, CONNECT_REFERENCE_COUNTED)


func _make_signal_callback(sig_name: String) -> Callable:
	return func(a1 = null, a2 = null, a3 = null, a4 = null, a5 = null):
		var params: Array = []
		for p in [a1, a2, a3, a4, a5]:
			if p != null:
				params.append(p)
		_on_event_bus_signal(sig_name, params)


func _on_event_bus_signal(sig_name: String, params: Array) -> void:
	var entry := {
		"signal": sig_name,
		"params": params,
		"time": Time.get_ticks_msec(),
		"turn": _safe_get_turn(),
	}
	_event_log.append(entry)
	if _event_log.size() > MAX_EVENT_LOG:
		_event_log.pop_front()

	if _signal_spy and _visible_flag:
		_print_spy(sig_name, params)

	if _current_tab == Tab.EVENT_LOG and _visible_flag:
		_append_event_log_entry(entry)


# ═══════════════════════════════════════════════════════════════
#                   INPUT & TOGGLE
# ═══════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_QUOTELEFT:
			_toggle_console()
			get_viewport().set_input_as_handled()
			return

	# Only handle further keys when console is open
	if not _visible_flag:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_navigate_history(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_navigate_history(1)
				get_viewport().set_input_as_handled()
			KEY_TAB:
				_try_autocomplete()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if autocomplete_popup.visible:
					autocomplete_popup.visible = false
				else:
					_toggle_console()
				get_viewport().set_input_as_handled()


func _toggle_console() -> void:
	_visible_flag = not _visible_flag
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _visible_flag:
		_slide_tween.tween_property(panel, "position:y", _panel_target_y, SLIDE_DURATION)
		_slide_tween.tween_callback(func(): input_line.grab_focus())
	else:
		_slide_tween.tween_property(panel, "position:y", _panel_hidden_y, SLIDE_DURATION)


# ═══════════════════════════════════════════════════════════════
#                     PROCESS / UPDATE
# ═══════════════════════════════════════════════════════════════

var _update_timer: float = 0.0

func _process(delta: float) -> void:
	if not _visible_flag:
		return
	_update_timer += delta
	# Update perf overlay every 0.25s
	if _update_timer >= 0.25:
		_update_timer = 0.0
		_update_fps_label()

	# Refresh active tab data every 0.5s
	if Engine.get_process_frames() % 30 == 0:
		match _current_tab:
			Tab.GAME_STATE:
				_refresh_game_state()
			Tab.BALANCE:
				_refresh_balance()


func _update_fps_label() -> void:
	var fps := Engine.get_frames_per_second()
	var mem_mb := OS.get_static_memory_usage() / (1024.0 * 1024.0)
	fps_label.text = "FPS: %d  MEM: %.1f MB" % [fps, mem_mb]
	# Update god mode indicator
	var god_lbl: Label = header_bar.get_node_or_null("GodIndicator")
	if god_lbl:
		god_lbl.text = "[GOD MODE]" if _god_mode else ""


# ═══════════════════════════════════════════════════════════════
#                     TAB SWITCHING
# ═══════════════════════════════════════════════════════════════

func _switch_tab(tab_idx: int) -> void:
	_current_tab = tab_idx
	# Update button styles
	for i in range(tab_buttons.size()):
		var active := (i == tab_idx)
		tab_buttons[i].add_theme_stylebox_override(
			"normal",
			_make_flat_btn_style(BG_TAB_ACTIVE if active else BG_TAB_INACTIVE)
		)
		tab_buttons[i].add_theme_color_override(
			"font_color",
			ACCENT if active else TEXT_WHITE
		)

	# Show/hide tab content
	for child in tab_container.get_children():
		child.visible = false
	var tab_names_map := ["ConsoleTab", "StateTab", "BalanceTab", "EventLogTab"]
	var target := tab_container.get_node_or_null(tab_names_map[tab_idx])
	if target:
		target.visible = true

	# Trigger initial refresh
	match tab_idx:
		Tab.GAME_STATE:
			_refresh_game_state()
		Tab.BALANCE:
			_refresh_balance()
		Tab.EVENT_LOG:
			_rebuild_event_log_display()
		Tab.CONSOLE:
			input_line.grab_focus()


# ═══════════════════════════════════════════════════════════════
#                  COMMAND PROCESSING
# ═══════════════════════════════════════════════════════════════

func _on_command_submitted(text: String) -> void:
	var cmd := text.strip_edges()
	input_line.clear()
	autocomplete_popup.visible = false
	if cmd.is_empty():
		return

	# Add to history
	if _command_history.is_empty() or _command_history.back() != cmd:
		_command_history.append(cmd)
		if _command_history.size() > MAX_HISTORY:
			_command_history.pop_front()
	_history_index = -1

	_print_input(cmd)
	_execute_command(cmd)


func _execute_command(raw: String) -> void:
	var parts := raw.split(" ", false)
	if parts.is_empty():
		return
	var keyword: String = parts[0].to_lower()
	var args: Array = parts.slice(1)

	# Two-word commands
	var two_word := ""
	if args.size() > 0:
		two_word = "%s %s" % [keyword, args[0].to_lower()]

	# Match two-word commands first
	match two_word:
		"give gold":
			_cmd_give_resource("gold", args.slice(1))
			return
		"give food":
			_cmd_give_resource("food", args.slice(1))
			return
		"give iron":
			_cmd_give_resource("iron", args.slice(1))
			return
		"give ap":
			_cmd_give_ap(args.slice(1))
			return
		"set turn":
			_cmd_set_turn(args.slice(1))
			return
		"set threat":
			_cmd_set_threat(args.slice(1))
			return
		"set order":
			_cmd_set_order(args.slice(1))
			return
		"dump state":
			_cmd_dump_state()
			return
		"dump tiles":
			_cmd_dump_tiles()
			return
		"dump armies":
			_cmd_dump_armies()
			return

	# Single-word commands
	match keyword:
		"help":
			_cmd_help()
		"clear":
			console_output.clear()
		"spawn":
			_cmd_spawn(args)
		"tp":
			_cmd_teleport(args)
		"reveal":
			_cmd_reveal()
		"god":
			_cmd_god()
		"win":
			_cmd_win()
		"kill":
			_cmd_kill(args)
		"heal":
			_cmd_heal()
		"research":
			_cmd_research(args)
		"level":
			_cmd_level(args)
		"eval":
			_cmd_eval(raw.substr(raw.find(" ") + 1) if raw.find(" ") != -1 else "")
		"speed":
			_cmd_speed(args)
		"spy":
			_cmd_spy()
		_:
			_print_error("未知命令: '%s'  输入 'help' 查看可用命令" % keyword)


# ═══════════════════════════════════════════════════════════════
#               COMMAND IMPLEMENTATIONS
# ═══════════════════════════════════════════════════════════════

func _cmd_help() -> void:
	_print_info("╔══════════════ 可用命令 ══════════════╗")
	for cmd in _commands:
		var line := "  %-20s %s" % [cmd["name"] + " " + cmd["args"], cmd["desc"]]
		_print_system(line)
	_print_info("╚══════════════════════════════════════╝")


func _cmd_give_resource(res_key: String, args: Array) -> void:
	var amount: Variant = _parse_int(args, 0, 100)
	if amount == null:
		return
	var pid := _human_pid()
	if pid < 0:
		_print_error("无法获取玩家ID")
		return
	var rm := _get_autoload("ResourceManager")
	if rm and rm.has_method("apply_delta"):
		rm.apply_delta(pid, {res_key: amount})
		_print_ok("给予 %s +%d (玩家 %d)" % [res_key, amount, pid])
		_emit_resources_changed(pid)
	else:
		_print_error("ResourceManager 不可用")


func _cmd_give_ap(args: Array) -> void:
	var amount: Variant = _parse_int(args, 0, 5)
	if amount == null:
		return
	var gm := _get_autoload("GameManager")
	if not gm:
		_print_error("GameManager 不可用")
		return
	var pid := _human_pid()
	var player: Dictionary = gm.get_player_by_id(pid) if gm.has_method("get_player_by_id") else {}
	if player.is_empty():
		_print_error("无法获取玩家数据")
		return
	player["ap"] = player.get("ap", 0) + amount
	_print_ok("AP +%d → %d" % [amount, player["ap"]])
	var bus := _get_autoload("EventBus")
	if bus:
		bus.ap_changed.emit(pid, player["ap"])


func _cmd_set_turn(args: Array) -> void:
	var val: Variant = _parse_int(args, 0, 1)
	if val == null:
		return
	var gm := _get_autoload("GameManager")
	if gm and "turn_number" in gm:
		gm.turn_number = val
		_print_ok("回合数设置为 %d" % val)
	else:
		_print_error("GameManager.turn_number 不可用")


func _cmd_set_threat(args: Array) -> void:
	var val: Variant = _parse_int(args, 0, 0)
	if val == null:
		return
	var tm := _get_autoload("ThreatManager")
	if tm and tm.has_method("change_threat"):
		var current: int = tm.get_threat() if tm.has_method("get_threat") else 0
		tm.change_threat(val - current)
		_print_ok("威胁值设置为 %d" % val)
	else:
		_print_error("ThreatManager 不可用")


func _cmd_set_order(args: Array) -> void:
	var val: Variant = _parse_int(args, 0, 50)
	if val == null:
		return
	var om := _get_autoload("OrderManager")
	if om and om.has_method("change_order"):
		var current: int = om.get_order() if om.has_method("get_order") else 50
		om.change_order(val - current)
		_print_ok("秩序值设置为 %d" % val)
	else:
		_print_error("OrderManager 不可用")


func _cmd_spawn(args: Array) -> void:
	if args.is_empty():
		_print_error("用法: spawn <troop_id> [count]")
		return
	var troop_id: String = args[0]
	var count: int = int(args[1]) if args.size() > 1 else 1
	_print_warn("spawn: 此命令需要选中地块且依赖具体部队系统实现")
	_print_system("  troop_id=%s  count=%d" % [troop_id, count])
	# Emit a signal for systems to hook into
	var bus := _get_autoload("EventBus")
	if bus and bus.has_signal("message_log"):
		bus.message_log.emit("[DEBUG] Spawn requested: %s x%d" % [troop_id, count])


func _cmd_teleport(args: Array) -> void:
	var tile_idx: Variant = _parse_int(args, 0, 0)
	if tile_idx == null:
		_print_error("用法: tp <tile_index>")
		return
	_print_warn("tp: 传送军队到地块 %d (需要选中军队)" % tile_idx)
	var gm := _get_autoload("GameManager")
	if gm and "tiles" in gm:
		if tile_idx < 0 or tile_idx >= gm.tiles.size():
			_print_error("无效地块索引: %d (共 %d 地块)" % [tile_idx, gm.tiles.size()])
			return
	_print_system("  目标地块: %d" % tile_idx)


func _cmd_reveal() -> void:
	var gm := _get_autoload("GameManager")
	if gm and "tiles" in gm:
		for tile in gm.tiles:
			if tile is Dictionary:
				tile["fog"] = false
				tile["visible"] = true
				tile["explored"] = true
		_print_ok("战争迷雾已全部移除 (%d 地块)" % gm.tiles.size())
		var bus := _get_autoload("EventBus")
		if bus:
			bus.fog_updated.emit(_human_pid())
	else:
		_print_error("GameManager.tiles 不可用")


func _cmd_god() -> void:
	_god_mode = not _god_mode
	if _god_mode:
		_print_ok("[GOD MODE ON] 无限AP和资源")
		# Grant massive resources
		var pid := _human_pid()
		var rm := _get_autoload("ResourceManager")
		if rm and rm.has_method("apply_delta"):
			rm.apply_delta(pid, {"gold": 99999, "food": 99999, "iron": 99999})
			_emit_resources_changed(pid)
		var gm := _get_autoload("GameManager")
		if gm:
			var player: Variant = gm.get_player_by_id(pid) if gm.has_method("get_player_by_id") else {}
			if not player.is_empty():
				player["ap"] = 99
	else:
		_print_warn("[GOD MODE OFF]")


func _cmd_win() -> void:
	var bus := _get_autoload("EventBus")
	if bus:
		bus.game_over.emit(_human_pid())
		_print_ok("胜利条件已触发")
	else:
		_print_error("EventBus 不可用")


func _cmd_kill(args: Array) -> void:
	var army_id: Variant = _parse_int(args, 0, -1)
	if army_id == null or army_id < 0:
		_print_error("用法: kill <army_id>")
		return
	var gm := _get_autoload("GameManager")
	if gm and "armies" in gm and gm.armies.has(army_id):
		gm.armies.erase(army_id)
		_print_ok("军队 %d 已销毁" % army_id)
		var bus := _get_autoload("EventBus")
		if bus:
			bus.army_disbanded.emit(-1, army_id)
	else:
		_print_error("找不到军队 ID %d" % army_id)


func _cmd_heal() -> void:
	var gm := _get_autoload("GameManager")
	var pid := _human_pid()
	if gm and gm.has_method("get_player_armies"):
		var player_armies: Array = gm.get_player_armies(pid)
		var count := 0
		for army in player_armies:
			if army is Dictionary:
				if army.has("troops"):
					for troop in army["troops"]:
						if troop is Dictionary and troop.has("hp_current") and troop.has("hp_max"):
							troop["hp_current"] = troop["hp_max"]
				if army.has("morale"):
					army["morale"] = 100
				count += 1
		_print_ok("已治愈 %d 支军队" % count)
	else:
		_print_error("GameManager.get_player_armies() 不可用")


func _cmd_research(args: Array) -> void:
	if args.is_empty():
		_print_error("用法: research <tech_id>")
		return
	var tech_id: String = args[0]
	_print_warn("research: 立即完成研究 '%s'" % tech_id)
	var bus := _get_autoload("EventBus")
	if bus and bus.has_signal("tech_effects_applied"):
		bus.tech_effects_applied.emit(_human_pid())
		_print_ok("tech_effects_applied 信号已发射")


func _cmd_level(args: Array) -> void:
	if args.size() < 2:
		_print_error("用法: level <hero_id> <level>")
		return
	var hero_id: String = args[0]
	var lvl: int = int(args[1])
	var hs := _get_autoload("HeroSystem")
	if hs and hs.has_method("set_hero_level"):
		hs.set_hero_level(hero_id, lvl)
		_print_ok("英雄 '%s' 等级设置为 %d" % [hero_id, lvl])
	else:
		_print_warn("HeroSystem.set_hero_level() 不可用, 尝试直接设置")
		var bus := _get_autoload("EventBus")
		if bus:
			bus.hero_leveled_up.emit(hero_id, lvl)
			_print_ok("hero_leveled_up 信号已发射: %s → Lv%d" % [hero_id, lvl])


func _cmd_eval(expr_str: String) -> void:
	if expr_str.strip_edges().is_empty():
		_print_error("用法: eval <expression>")
		return
	_print_warn("[EVAL] %s" % expr_str)
	var expression := Expression.new()
	var err := expression.parse(expr_str)
	if err != OK:
		_print_error("解析错误: %s" % expression.get_error_text())
		return
	var result = expression.execute([], self)
	if expression.has_execute_failed():
		_print_error("执行错误: %s" % expression.get_error_text())
	else:
		_print_ok("结果: %s" % str(result))


func _cmd_speed(args: Array) -> void:
	var val: Variant = _parse_int(args, 0, 1)
	if val == null:
		return
	val = clampi(val, 1, 10)
	Engine.time_scale = float(val)
	_print_ok("游戏速度设置为 %dx" % val)


func _cmd_spy() -> void:
	_signal_spy = not _signal_spy
	if _signal_spy:
		_print_ok("[信号监听 ON] 所有EventBus信号将实时显示")
	else:
		_print_warn("[信号监听 OFF]")


func _cmd_dump_state() -> void:
	_print_info("══════ GAME STATE DUMP ══════")
	var gm := _get_autoload("GameManager")
	if not gm:
		_print_error("GameManager 不可用")
		return
	_print_system("  turn_number: %d" % gm.turn_number)
	_print_system("  players: %d" % gm.players.size())
	for i in range(gm.players.size()):
		var p: Dictionary = gm.players[i]
		_print_system("  [%d] %s — AP:%s 地块:%s" % [
			i,
			p.get("name", "?"),
			str(p.get("ap", "?")),
			str(p.get("owned_tiles", []).size()) if p.has("owned_tiles") else "?",
		])
	_print_system("  tiles: %d" % gm.tiles.size())
	_print_system("  armies: %d" % gm.armies.size())
	var rm := _get_autoload("ResourceManager")
	if rm and rm.has_method("get_resource"):
		var pid := _human_pid()
		_print_system("  [Player %d] gold=%d food=%d iron=%d" % [
			pid,
			rm.get_resource(pid, "gold"),
			rm.get_resource(pid, "food"),
			rm.get_resource(pid, "iron"),
		])
	var tm := _get_autoload("ThreatManager")
	if tm and tm.has_method("get_threat"):
		_print_system("  threat: %d (tier %s)" % [tm.get_threat(), tm.get_tier() if tm.has_method("get_tier") else "?"])
	var om := _get_autoload("OrderManager")
	if om and om.has_method("get_order"):
		_print_system("  order: %d" % om.get_order())
	_print_info("══════════════════════════════")


func _cmd_dump_tiles() -> void:
	var gm := _get_autoload("GameManager")
	if not gm or not "tiles" in gm:
		_print_error("GameManager.tiles 不可用")
		return
	_print_info("══════ TILES (%d) ══════" % gm.tiles.size())
	for i in range(mini(gm.tiles.size(), 50)):
		var t: Dictionary = gm.tiles[i] if gm.tiles[i] is Dictionary else {}
		_print_system("  [%d] owner=%s type=%s name=%s" % [
			i,
			str(t.get("owner", "?")),
			str(t.get("type", "?")),
			str(t.get("name", "?")),
		])
	if gm.tiles.size() > 50:
		_print_warn("  ... 仅显示前50个 (共%d)" % gm.tiles.size())


func _cmd_dump_armies() -> void:
	var gm := _get_autoload("GameManager")
	if not gm or not "armies" in gm:
		_print_error("GameManager.armies 不可用")
		return
	_print_info("══════ ARMIES (%d) ══════" % gm.armies.size())
	for army_id in gm.armies:
		var a: Dictionary = gm.armies[army_id] if gm.armies[army_id] is Dictionary else {}
		_print_system("  [%d] owner=%s tile=%s troops=%s" % [
			army_id,
			str(a.get("owner_id", "?")),
			str(a.get("tile_index", "?")),
			str(a.get("troops", []).size()) if a.has("troops") else "?",
		])


# ═══════════════════════════════════════════════════════════════
#                GAME STATE TAB REFRESH
# ═══════════════════════════════════════════════════════════════

func _refresh_game_state() -> void:
	# Clear existing labels
	for child in state_grid.get_children():
		child.queue_free()
	state_labels.clear()

	var gm := _get_autoload("GameManager")
	var rm := _get_autoload("ResourceManager")
	var tm := _get_autoload("ThreatManager")
	var om := _get_autoload("OrderManager")
	var pid := _human_pid()

	_add_state_heading("核心状态")
	_add_state_row("回合", str(gm.turn_number) if gm else "?")
	_add_state_row("玩家数", str(gm.players.size()) if gm else "?")
	_add_state_row("地块总数", str(gm.tiles.size()) if gm else "?")
	_add_state_row("军队总数", str(gm.armies.size()) if gm else "?")

	if gm and gm.has_method("get_player_by_id"):
		var player: Variant = gm.get_player_by_id(pid)
		if not player.is_empty():
			_add_state_heading("玩家信息")
			_add_state_row("名称", str(player.get("name", "?")))
			_add_state_row("AP", str(player.get("ap", "?")))
			var owned: Array = player.get("owned_tiles", [])
			_add_state_row("控制地块", str(owned.size()))
			_add_state_row("军队数", str(player.get("army_count", "?")))

	if rm and rm.has_method("get_resource"):
		_add_state_heading("资源")
		_add_state_row("金币", str(rm.get_resource(pid, "gold")), ColorTheme.RES_GOLD if _has_autoload("ColorTheme") else TEXT_YELLOW)
		_add_state_row("食物", str(rm.get_resource(pid, "food")), ColorTheme.RES_FOOD if _has_autoload("ColorTheme") else TEXT_GREEN)
		_add_state_row("铁矿", str(rm.get_resource(pid, "iron")), ColorTheme.RES_IRON if _has_autoload("ColorTheme") else TEXT_WHITE)

	if tm and tm.has_method("get_threat"):
		_add_state_heading("威胁与秩序")
		_add_state_row("威胁值", str(tm.get_threat()), TEXT_RED)
		_add_state_row("威胁等级", str(tm.get_tier()) if tm.has_method("get_tier") else "?", TEXT_RED)

	if om and om.has_method("get_order"):
		_add_state_row("秩序值", str(om.get_order()), TEXT_CYAN)

	# Hero info
	var hs := _get_autoload("HeroSystem")
	if hs and "recruited_heroes" in hs:
		_add_state_heading("英雄")
		for hid in hs.recruited_heroes:
			var hlvl: String = ""
			if hs.has_method("get_hero_level"):
				hlvl = " Lv%d" % hs.get_hero_level(hid)
			_add_state_row(str(hid), "已招募%s" % hlvl, TEXT_CYAN)


func _add_state_heading(title: String) -> void:
	var lbl := Label.new()
	lbl.text = "── %s ──" % title
	lbl.add_theme_color_override("font_color", ACCENT)
	lbl.add_theme_font_size_override("font_size", 14)
	state_grid.add_child(lbl)
	# Fill remaining columns
	for _i in range(state_grid.columns - 1):
		var spacer := Control.new()
		state_grid.add_child(spacer)


func _add_state_row(key: String, value: String, color: Color = TEXT_GREEN) -> void:
	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_color_override("font_color", TEXT_DIM)
	key_lbl.add_theme_font_size_override("font_size", 13)
	state_grid.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_color_override("font_color", color)
	val_lbl.add_theme_font_size_override("font_size", 13)
	state_grid.add_child(val_lbl)

	# Fill remaining columns
	for _i in range(state_grid.columns - 2):
		var spacer := Control.new()
		state_grid.add_child(spacer)


# ═══════════════════════════════════════════════════════════════
#              BALANCE MONITOR TAB REFRESH
# ═══════════════════════════════════════════════════════════════

func _refresh_balance() -> void:
	for child in balance_vbox.get_children():
		child.queue_free()

	var gm := _get_autoload("GameManager")
	var rm := _get_autoload("ResourceManager")
	if not gm or not rm:
		_add_balance_label("GameManager 或 ResourceManager 不可用", TEXT_RED)
		return

	_add_balance_label("── 势力实力对比 ──", ACCENT)

	# Gather faction power data
	var max_power: float = 1.0
	var faction_data: Array = []
	for i in range(gm.players.size()):
		var p: Dictionary = gm.players[i]
		var gold: int = rm.get_resource(i, "gold") if rm.has_method("get_resource") else 0
		var army_ct: int = p.get("army_count", 0)
		var tiles_ct: int = p.get("owned_tiles", []).size() if p.has("owned_tiles") else 0
		var power: float = army_ct * 100.0 + tiles_ct * 50.0 + gold * 0.5
		max_power = maxf(max_power, power)
		faction_data.append({
			"name": p.get("name", "Player %d" % i),
			"power": power,
			"gold": gold,
			"armies": army_ct,
			"tiles": tiles_ct,
		})

	for fd in faction_data:
		_add_balance_bar(fd["name"], fd["power"], max_power)
		_add_balance_label("    金:%d  军:%d  地:%d" % [fd["gold"], fd["armies"], fd["tiles"]], TEXT_DIM)

	# Income/expense estimation
	_add_balance_label("── 经济概况 ──", ACCENT)
	for i in range(gm.players.size()):
		var p: Dictionary = gm.players[i]
		var income_est: int = 0
		if p.has("owned_tiles"):
			income_est = p["owned_tiles"].size() * 8  # rough estimate
		_add_balance_label("  %s: 预估收入 ~%d 金/回合" % [p.get("name", "?"), income_est], TEXT_GREEN)

	# Balance warnings
	var bm := _get_autoload("BalanceManager")
	if bm:
		_add_balance_label("── 平衡警告 ──", TEXT_YELLOW)
		if bm.has_method("get_warnings"):
			var warnings: Array = bm.get_warnings()
			for w in warnings:
				_add_balance_label("  ⚠ %s" % str(w), TEXT_YELLOW)
		elif bm.has_method("get_diff"):
			var diff: Dictionary = bm.get_diff()
			_add_balance_label("  难度: %s" % str(diff.get("label", "?")), TEXT_CYAN)


func _add_balance_label(text: String, color: Color = TEXT_GREEN) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	balance_vbox.add_child(lbl)


func _add_balance_bar(label: String, value: float, max_val: float) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	balance_vbox.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size.x = 120
	name_lbl.add_theme_color_override("font_color", TEXT_WHITE)
	name_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(name_lbl)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(300, 16)
	bar_bg.color = Color(0.1, 0.1, 0.14, 1.0)
	hbox.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	var ratio := clampf(value / max_val, 0.0, 1.0)
	bar_fill.custom_minimum_size = Vector2(300.0 * ratio, 16)
	bar_fill.color = _power_bar_color(ratio)
	bar_bg.add_child(bar_fill)

	var val_lbl := Label.new()
	val_lbl.text = str(int(value) if (value is int or value is float) else 0)
	val_lbl.add_theme_color_override("font_color", TEXT_DIM)
	val_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(val_lbl)


func _power_bar_color(ratio: float) -> Color:
	if ratio > 0.7:
		return Color(0.9, 0.3, 0.2, 0.85)
	elif ratio > 0.4:
		return Color(0.85, 0.75, 0.2, 0.85)
	return Color(0.3, 0.75, 0.4, 0.85)


# ═══════════════════════════════════════════════════════════════
#               EVENT LOG TAB
# ═══════════════════════════════════════════════════════════════

func _rebuild_event_log_display() -> void:
	for child in event_vbox.get_children():
		child.queue_free()
	var filter_text: String = event_filter_input.text.strip_edges().to_lower() if event_filter_input else ""
	for entry in _event_log:
		if not filter_text.is_empty() and entry["signal"].to_lower().find(filter_text) == -1:
			continue
		_append_event_log_entry(entry)


func _append_event_log_entry(entry: Dictionary) -> void:
	var filter_text: String = event_filter_input.text.strip_edges().to_lower() if event_filter_input else ""
	if not filter_text.is_empty() and entry["signal"].to_lower().find(filter_text) == -1:
		return

	var btn := Button.new()
	btn.text = "[T%d %dms] %s(%s)" % [
		entry.get("turn", 0),
		entry.get("time", 0),
		entry["signal"],
		_format_params(entry.get("params", [])),
	]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", TEXT_CYAN)
	btn.add_theme_stylebox_override("normal", _make_flat_btn_style(Color.TRANSPARENT))
	btn.add_theme_stylebox_override("hover", _make_flat_btn_style(Color(0.15, 0.15, 0.25, 0.5)))
	btn.pressed.connect(func(): _inspect_event(entry))
	event_vbox.add_child(btn)

	# Auto-scroll
	if event_vbox.get_child_count() > MAX_EVENT_LOG:
		event_vbox.get_child(0).queue_free()


func _inspect_event(entry: Dictionary) -> void:
	_switch_tab(Tab.CONSOLE)
	_print_info("══════ 事件详情 ══════")
	_print_system("  信号: %s" % entry["signal"])
	_print_system("  回合: %d" % entry.get("turn", 0))
	_print_system("  时间: %d ms" % entry.get("time", 0))
	var params: Array = entry.get("params", [])
	if params.is_empty():
		_print_system("  参数: (无)")
	else:
		for i in range(params.size()):
			_print_system("  参数[%d]: %s" % [i, str(params[i])])
	_print_info("══════════════════════")


func _on_event_filter_changed(_new_text: String) -> void:
	_rebuild_event_log_display()


# ═══════════════════════════════════════════════════════════════
#            AUTOCOMPLETE & HISTORY
# ═══════════════════════════════════════════════════════════════

func _navigate_history(direction: int) -> void:
	if _command_history.is_empty():
		return
	if direction < 0:
		# Up — go back in history
		if _history_index == -1:
			_history_index = _command_history.size() - 1
		else:
			_history_index = maxi(_history_index - 1, 0)
	else:
		# Down — go forward in history
		if _history_index == -1:
			return
		_history_index += 1
		if _history_index >= _command_history.size():
			_history_index = -1
			input_line.text = ""
			input_line.caret_column = 0
			return
	input_line.text = _command_history[_history_index]
	input_line.caret_column = input_line.text.length()


func _try_autocomplete() -> void:
	var text := input_line.text.strip_edges().to_lower()
	if text.is_empty():
		autocomplete_popup.visible = false
		return

	var matches: Array[String] = []
	for cmd_name in _command_names:
		if cmd_name.begins_with(text) or cmd_name.find(text) != -1:
			matches.append(cmd_name)

	if matches.is_empty():
		autocomplete_popup.visible = false
		return

	if matches.size() == 1:
		# Single match — auto-fill
		input_line.text = matches[0] + " "
		input_line.caret_column = input_line.text.length()
		autocomplete_popup.visible = false
		return

	# Show popup with matches
	for child in autocomplete_list.get_children():
		child.queue_free()

	for m in matches.slice(0, 8):
		var btn := Button.new()
		btn.text = m
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", TEXT_GREEN)
		btn.add_theme_stylebox_override("normal", _make_flat_btn_style(Color.TRANSPARENT))
		btn.add_theme_stylebox_override("hover", _make_flat_btn_style(Color(0.1, 0.15, 0.1, 0.5)))
		btn.pressed.connect(func():
			input_line.text = m + " "
			input_line.caret_column = input_line.text.length()
			autocomplete_popup.visible = false
			input_line.grab_focus()
		)
		autocomplete_list.add_child(btn)

	autocomplete_popup.visible = true


# ═══════════════════════════════════════════════════════════════
#              CONSOLE OUTPUT HELPERS
# ═══════════════════════════════════════════════════════════════

func _print_welcome() -> void:
	console_output.append_text("[color=#%s]╔════════════════════════════════════════╗[/color]\n" % ACCENT.to_html(false))
	console_output.append_text("[color=#%s]║   暗潮 SLG — 调试控制台 v1.0          ║[/color]\n" % ACCENT.to_html(false))
	console_output.append_text("[color=#%s]║   输入 'help' 查看可用命令             ║[/color]\n" % ACCENT.to_html(false))
	console_output.append_text("[color=#%s]╚════════════════════════════════════════╝[/color]\n" % ACCENT.to_html(false))


func _print_input(text: String) -> void:
	console_output.append_text("[color=#%s]> %s[/color]\n" % [TEXT_WHITE.to_html(false), text])
	_trim_output()


func _print_ok(text: String) -> void:
	console_output.append_text("[color=#%s]  %s[/color]\n" % [TEXT_GREEN.to_html(false), text])
	_trim_output()


func _print_error(text: String) -> void:
	console_output.append_text("[color=#%s]  [ERROR] %s[/color]\n" % [TEXT_RED.to_html(false), text])
	_trim_output()


func _print_warn(text: String) -> void:
	console_output.append_text("[color=#%s]  [WARN] %s[/color]\n" % [TEXT_YELLOW.to_html(false), text])
	_trim_output()


func _print_info(text: String) -> void:
	console_output.append_text("[color=#%s]%s[/color]\n" % [TEXT_CYAN.to_html(false), text])
	_trim_output()


func _print_system(text: String) -> void:
	console_output.append_text("[color=#%s]%s[/color]\n" % [TEXT_DIM.to_html(false), text])
	_trim_output()


func _print_spy(sig_name: String, params: Array) -> void:
	console_output.append_text("[color=#%s]  [SPY] %s(%s)[/color]\n" % [
		Color(0.6, 0.4, 1.0).to_html(false),
		sig_name,
		_format_params(params),
	])
	_trim_output()


func _trim_output() -> void:
	# RichTextLabel doesn't have a direct line count API for BBCode,
	# so we rely on max visible lines and scroll_following behavior.
	pass


# ═══════════════════════════════════════════════════════════════
#                   STYLE HELPERS
# ═══════════════════════════════════════════════════════════════

func _make_panel_style(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 0, margin: int = 4) -> StyleBoxFlat:
	var sf := StyleBoxFlat.new()
	sf.bg_color = bg
	sf.border_color = border
	sf.set_border_width_all(border_w)
	sf.set_corner_radius_all(radius)
	sf.set_content_margin_all(margin)
	return sf


func _make_flat_btn_style(bg: Color) -> StyleBoxFlat:
	var sf := StyleBoxFlat.new()
	sf.bg_color = bg
	sf.set_border_width_all(0)
	sf.set_corner_radius_all(2)
	sf.set_content_margin_all(4)
	return sf


# ═══════════════════════════════════════════════════════════════
#                   UTILITY HELPERS
# ═══════════════════════════════════════════════════════════════

func _has_autoload(name: String) -> bool:
	return get_node_or_null("/root/%s" % name) != null


func _get_autoload(name: String) -> Node:
	return get_node_or_null("/root/%s" % name)


func _human_pid() -> int:
	var gm := _get_autoload("GameManager")
	if gm and gm.has_method("get_human_player_id"):
		return gm.get_human_player_id()
	return 0


func _safe_get_turn() -> Variant:
	var gm := _get_autoload("GameManager")
	if gm and "turn_number" in gm:
		return gm.turn_number
	return 0


func _emit_resources_changed(pid: int) -> void:
	var bus := _get_autoload("EventBus")
	if bus:
		bus.resources_changed.emit(pid)


func _parse_int(args: Array, index: int, default: int) -> Variant:
	if index >= args.size():
		return default
	if not args[index].is_valid_int():
		_print_error("无效数字: '%s'" % args[index])
		return null
	return int(args[index])


func _format_params(params: Array) -> String:
	if params.is_empty():
		return ""
	var parts: Array[String] = []
	for p in params:
		var s := str(p)
		if s.length() > 40:
			s = s.left(37) + "..."
		parts.append(s)
	return ", ".join(parts)
