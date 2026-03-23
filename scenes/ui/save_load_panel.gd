## save_load_panel.gd - Save/Load UI for 暗潮 SLG (v0.9.1)
## 5 manual slots + auto-save slot
extends CanvasLayer

# ── State ──
var _visible: bool = false
var _mode: String = "save"  # "save" or "load"

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var panel: PanelContainer
var title_label: Label
var btn_close: Button
var slot_container: VBoxContainer
var _slot_nodes: Array = []

const SLOT_COUNT: int = 5


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 7
	_build_ui()
	hide_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "SaveLoadRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: hide_panel())
	root.add_child(dim_bg)

	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -220
	panel.offset_bottom = 220
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.97)
	style.border_color = Color(0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	title_label = Label.new()
	title_label.text = "存档"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	btn_close = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(32, 32)
	btn_close.add_theme_font_size_override("font_size", 14)
	btn_close.pressed.connect(hide_panel)
	header.add_child(btn_close)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Slot list
	slot_container = VBoxContainer.new()
	slot_container.add_theme_constant_override("separation", 6)
	vbox.add_child(slot_container)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_save() -> void:
	_mode = "save"
	title_label.text = "保存游戏"
	_refresh_slots()
	_visible = true
	root.visible = true


func show_load() -> void:
	_mode = "load"
	title_label.text = "读取存档"
	_refresh_slots()
	_visible = true
	root.visible = true


func hide_panel() -> void:
	_visible = false
	root.visible = false


func is_panel_visible() -> bool:
	return _visible


# ═══════════════════════════════════════════════════════════════
#                       SLOT DISPLAY
# ═══════════════════════════════════════════════════════════════

func _refresh_slots() -> void:
	for node in _slot_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_slot_nodes.clear()

	# Auto-save slot
	_add_slot_row(-1, "自动存档")

	# Manual slots
	for i in range(SLOT_COUNT):
		_add_slot_row(i, "存档 %d" % (i + 1))


func _add_slot_row(slot_index: int, label: String) -> void:
	var actual_slot: int = slot_index if slot_index >= 0 else 0  # Auto-save uses slot 0

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	slot_container.add_child(row)
	_slot_nodes.append(row)

	# Slot info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	info_vbox.add_child(name_lbl)

	var has_save: bool = SaveManager.has_save(actual_slot) if SaveManager.has_method("has_save") else false

	if has_save:
		var info: Dictionary = SaveManager.get_save_info(actual_slot) if SaveManager.has_method("get_save_info") else {}
		var turn: int = info.get("turn", 0)
		var faction: String = info.get("faction_name", "???")
		var date: String = info.get("save_date", "")

		var detail_lbl := Label.new()
		detail_lbl.text = "回合%d | %s | %s" % [turn, faction, date]
		detail_lbl.add_theme_font_size_override("font_size", 11)
		detail_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		info_vbox.add_child(detail_lbl)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "-- 空 --"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		info_vbox.add_child(empty_lbl)

	# Action button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 36)
	btn.add_theme_font_size_override("font_size", 13)

	if _mode == "save":
		btn.text = "保存"
		btn.pressed.connect(_on_save_slot.bind(actual_slot))
		# Can't save to auto-save slot manually (it's automatic)
		if slot_index < 0:
			btn.disabled = true
			btn.text = "自动"
	else:
		btn.text = "读取"
		btn.disabled = not has_save
		btn.pressed.connect(_on_load_slot.bind(actual_slot))

	row.add_child(btn)

	# Delete button (only for slots with saves, not auto-save)
	if has_save and slot_index >= 0:
		var btn_del := Button.new()
		btn_del.text = "删"
		btn_del.custom_minimum_size = Vector2(36, 36)
		btn_del.add_theme_font_size_override("font_size", 12)
		btn_del.pressed.connect(_on_delete_slot.bind(actual_slot))
		row.add_child(btn_del)


# ═══════════════════════════════════════════════════════════════
#                       CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_save_slot(slot: int) -> void:
	if SaveManager.has_method("save_game"):
		var success: bool = SaveManager.save_game(slot)
		if success:
			EventBus.message_log.emit("[color=lime]游戏已保存到存档 %d[/color]" % (slot + 1))
		else:
			EventBus.message_log.emit("[color=red]保存失败[/color]")
	_refresh_slots()


func _on_load_slot(slot: int) -> void:
	if SaveManager.has_method("load_game"):
		var success: bool = SaveManager.load_game(slot)
		if success:
			EventBus.message_log.emit("[color=lime]存档 %d 已读取[/color]" % (slot + 1))
			hide_panel()
		else:
			EventBus.message_log.emit("[color=red]读取失败[/color]")


func _on_delete_slot(slot: int) -> void:
	if SaveManager.has_method("delete_save"):
		SaveManager.delete_save(slot)
		EventBus.message_log.emit("存档 %d 已删除" % (slot + 1))
	_refresh_slots()
