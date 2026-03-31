## multi_route_panel.gd — Multi-route battle (合战) selection UI
## Select 2-4 armies to attack one tile simultaneously. Key: G (合战 = Gassen)
extends CanvasLayer

var _visible: bool = false
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var content_vbox: VBoxContainer
var army_list_vbox: VBoxContainer
var target_label: Label
var btn_launch: Button
var status_label: Label

var _selected_army_ids: Array = []
var _target_tile: int = -1
var _selecting_target: bool = false

# Army checkbox tracking
var _army_checks: Dictionary = {}  # army_id -> CheckBox

func _ready() -> void:
	layer = 5
	_build_ui()
	_connect_signals()
	hide_panel()

func _connect_signals() -> void:
	EventBus.territory_selected.connect(_on_territory_selected)

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_G:
			if _visible: hide_panel()
			else: show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	root = Control.new()
	root.name = "MultiRoutePanelRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.45)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.2
	main_panel.anchor_right = 0.8
	main_panel.anchor_top = 0.1
	main_panel.anchor_bottom = 0.9
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.12, 0.95)
	style.border_color = Color(0.7, 0.5, 0.2, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	main_panel.add_child(outer)

	# Header
	var hdr := HBoxContainer.new()
	outer.add_child(hdr)
	header_label = Label.new()
	header_label.text = "合战 — 多路协同进攻"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(header_label)
	btn_close = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.pressed.connect(hide_panel)
	hdr.add_child(btn_close)

	outer.add_child(HSeparator.new())

	# Instructions
	var instr := RichTextLabel.new()
	instr.bbcode_enabled = true
	instr.fit_content = true
	instr.text = "[color=gray]选择 2-4 支军团，指定同一目标进攻。各路军依次战斗，防御方伤害累积。[/color]\n[color=orange]侧翼加成: +15% ATK/路 | 夹击(3路+): 防御方 DEF -25%[/color]"
	instr.add_theme_font_size_override("normal_font_size", 13)
	instr.custom_minimum_size = Vector2(0, 50)
	outer.add_child(instr)

	# Target selection
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 10)
	outer.add_child(target_row)
	var target_btn := Button.new()
	target_btn.text = "选择目标据点"
	target_btn.custom_minimum_size = Vector2(140, 34)
	target_btn.pressed.connect(_on_select_target)
	target_row.add_child(target_btn)
	target_label = Label.new()
	target_label.text = "未选择目标"
	target_label.add_theme_font_size_override("font_size", 15)
	target_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_row.add_child(target_label)

	outer.add_child(HSeparator.new())

	# Army list header
	var army_hdr := Label.new()
	army_hdr.text = "可用军团 (勾选参战军团):"
	army_hdr.add_theme_font_size_override("font_size", 15)
	army_hdr.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	outer.add_child(army_hdr)

	# Scrollable army list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	army_list_vbox = VBoxContainer.new()
	army_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	army_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(army_list_vbox)

	# Bottom: status + launch button
	outer.add_child(HSeparator.new())
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	outer.add_child(bottom)
	status_label = Label.new()
	status_label.text = "已选 0/4 路军团"
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(status_label)
	btn_launch = Button.new()
	btn_launch.text = "发动合战!"
	btn_launch.custom_minimum_size = Vector2(150, 40)
	btn_launch.disabled = true
	btn_launch.pressed.connect(_on_launch)
	bottom.add_child(btn_launch)

func show_panel() -> void:
	_visible = true
	root.visible = true
	_selected_army_ids.clear()
	_target_tile = -1
	_selecting_target = false
	_refresh()

func hide_panel() -> void:
	_visible = false
	root.visible = false
	_selecting_target = false

func is_panel_visible() -> bool:
	return _visible

func _refresh() -> void:
	# Rebuild army list
	for child in army_list_vbox.get_children():
		child.queue_free()
	_army_checks.clear()

	var pid: int = GameManager.get_human_player_id()
	var armies: Dictionary = GameManager.armies
	var count: int = 0

	for aid in armies:
		var army: Dictionary = armies[aid]
		if army.get("player_id", -1) != pid:
			continue
		var soldiers: int = 0
		for troop in army.get("troops", []):
			soldiers += troop.get("soldiers", 0)
		if soldiers <= 0:
			continue

		count += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		army_list_vbox.add_child(row)

		var cb := CheckBox.new()
		cb.text = ""
		cb.toggled.connect(_on_army_toggled.bind(aid))
		if _selected_army_ids.has(aid):
			cb.button_pressed = true
		row.add_child(cb)
		_army_checks[aid] = cb

		var name_lbl := Label.new()
		name_lbl.text = "%s" % army.get("name", "军团%d" % aid)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		name_lbl.custom_minimum_size = Vector2(180, 0)
		row.add_child(name_lbl)

		var tile_name: String = "—"
		var ti: int = army.get("tile_index", -1)
		if ti >= 0 and ti < GameManager.tiles.size():
			tile_name = GameManager.tiles[ti].get("name", "据点%d" % ti)
		var pos_lbl := Label.new()
		pos_lbl.text = "驻扎: %s" % tile_name
		pos_lbl.add_theme_font_size_override("font_size", 13)
		pos_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		pos_lbl.custom_minimum_size = Vector2(160, 0)
		row.add_child(pos_lbl)

		var sol_lbl := Label.new()
		sol_lbl.text = "兵力: %d" % soldiers
		sol_lbl.add_theme_font_size_override("font_size", 13)
		sol_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.3))
		row.add_child(sol_lbl)

	if count == 0:
		var lbl := Label.new()
		lbl.text = "没有可用军团。请先创建军团。"
		lbl.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
		army_list_vbox.add_child(lbl)

	# Update target label
	if _target_tile >= 0 and _target_tile < GameManager.tiles.size():
		var t = GameManager.tiles[_target_tile]
		target_label.text = "%s (Lv%d, 驻军%d)" % [t.get("name", "据点"), t.get("level", 1), t.get("garrison", 0)]
		target_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
	else:
		target_label.text = "未选择目标"
		target_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	_update_status()

func _on_army_toggled(pressed: bool, army_id: int) -> void:
	if pressed:
		if _selected_army_ids.size() < 4 and not _selected_army_ids.has(army_id):
			_selected_army_ids.append(army_id)
		elif _selected_army_ids.size() >= 4:
			# Uncheck — too many
			if _army_checks.has(army_id):
				_army_checks[army_id].button_pressed = false
			return
	else:
		_selected_army_ids.erase(army_id)
	_update_status()

func _update_status() -> void:
	var n: int = _selected_army_ids.size()
	var bonus_text: String = ""
	if n >= 2:
		var flank_pct: int = (n - 1) * 15
		bonus_text = " | 侧翼ATK+%d%%" % flank_pct
	if n >= 3:
		bonus_text += " | 夹击DEF-25%"

	status_label.text = "已选 %d/4 路军团%s" % [n, bonus_text]
	if n >= 2:
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

	btn_launch.disabled = (n < 2 or _target_tile < 0)

func _on_select_target() -> void:
	_selecting_target = true
	EventBus.message_log.emit("[color=cyan]请在地图上点击要进攻的目标据点...[/color]")

func _on_territory_selected(tile_index: int) -> void:
	if not _visible or not _selecting_target:
		return
	_selecting_target = false
	var pid: int = GameManager.get_human_player_id()
	if tile_index >= 0 and tile_index < GameManager.tiles.size():
		var t = GameManager.tiles[tile_index]
		if t.get("owner_id", -1) == pid:
			EventBus.message_log.emit("[color=red]不能选择自己的据点作为合战目标![/color]")
			return
		_target_tile = tile_index
		_refresh()

func _on_launch() -> void:
	if _selected_army_ids.size() < 2 or _target_tile < 0:
		return
	hide_panel()
	# Call the multi-route attack API
	var result = await GameManager.action_multi_route_attack(_selected_army_ids.duplicate(), _target_tile)
	if not result:
		EventBus.message_log.emit("[color=red]合战执行失败[/color]")

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
