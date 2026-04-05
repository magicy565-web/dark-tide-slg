## offensive_panel.gd — 进攻面板
## 显示可用的进攻行动，允许玩家选择目标并执行进攻。
extends CanvasLayer

var _visible: bool = false
var _tile_idx: int = -1
var _selected_target_idx: int = -1

@onready var root = Control.new()
@onready var panel = PanelContainer.new()
@onready var vbox = VBoxContainer.new()
@onready var header_label = Label.new()
@onready var actions_vbox = VBoxContainer.new()
@onready var target_label = Label.new()
@onready var target_grid = GridContainer.new()
@onready var execute_btn = Button.new()
@onready var close_btn = Button.new()

func _ready() -> void:
	layer = UILayerRegistry.LAYER_DETAIL_PANELS
	
	root.anchor_left = 0.7
	root.anchor_top = 0.2
	root.anchor_right = 1.0
	root.anchor_bottom = 0.8
	add_child(root)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.set_border_enabled_all(true)
	style.set_border_color_all(Color(0.5, 0.5, 0.6))
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	
	panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 8)
	
	header_label.text = "进攻行动"
	header_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(header_label)
	
	vbox.add_child(HSeparator.new())
	
	actions_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(actions_vbox)
	
	vbox.add_child(HSeparator.new())
	
	target_label.text = "选择目标"
	target_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(target_label)
	
	target_grid.columns = 3
	target_grid.add_theme_constant_override("h_separation", 4)
	target_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(target_grid)
	
	vbox.add_child(HSeparator.new())
	
	var btn_hbox = HBoxContainer.new()
	vbox.add_child(btn_hbox)
	
	execute_btn.text = "执行"
	execute_btn.custom_minimum_size = Vector2(80, 30)
	execute_btn.pressed.connect(_on_execute_pressed)
	btn_hbox.add_child(execute_btn)
	
	btn_hbox.add_child(Control.new())  # spacer
	
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(80, 30)
	close_btn.pressed.connect(hide_panel)
	btn_hbox.add_child(close_btn)
	
	root.visible = false
	_visible = false

func show_panel(tile_idx: int) -> void:
	_tile_idx = tile_idx
	_selected_target_idx = -1
	_visible = true
	root.visible = true
	_refresh()

func hide_panel() -> void:
	_visible = false
	root.visible = false

func _refresh() -> void:
	for c in actions_vbox.get_children(): c.queue_free()
	for c in target_grid.get_children(): c.queue_free()
	
	var tile = GameManager.tiles[_tile_idx]
	header_label.text = "进攻 - %s" % tile.get("name", "据点")
	
	# ── 显示可用行动 ──
	var actions = GameManager.offensive_system.get_available_actions(_tile_idx)
	for action in actions:
		var action_row = _make_action_row(action)
		actions_vbox.add_child(action_row)
	
	# ── 显示可攻击的目标 ──
	_refresh_targets()

func _make_action_row(action: Dictionary) -> PanelContainer:
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_content_margin_all(6)
	pc.add_theme_stylebox_override("panel", style)
	
	var hb = HBoxContainer.new()
	pc.add_child(hb)
	
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	
	var name_lbl = Label.new()
	name_lbl.text = "%s (冷却: %d)" % [action["name"], action["cooldown"]]
	name_lbl.add_theme_font_size_override("font_size", 12)
	vb.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = action["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.custom_minimum_size = Vector2(250, 0)
	desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(desc_lbl)
	
	return pc

func _refresh_targets() -> void:
	# 获取所有相邻的敌方据点
	var tile_idx = _tile_idx
	var tile = GameManager.tiles[tile_idx]
	var owner_id = tile.get("owner_id", -1)
	
	if GameManager.adjacency.has(tile_idx):
		for adj_idx in GameManager.adjacency[tile_idx]:
			var adj_tile = GameManager.tiles[adj_idx]
			if adj_tile == null:
				continue
			var adj_owner = adj_tile.get("owner_id", -1)
			if adj_owner != owner_id and adj_owner >= 0:
				var btn = Button.new()
				btn.text = adj_tile.get("name", "据点 #%d" % adj_idx)
				btn.custom_minimum_size = Vector2(80, 30)
				btn.toggle_mode = true
				btn.pressed.connect(func(): _on_target_selected(adj_idx))
				target_grid.add_child(btn)

func _on_target_selected(target_idx: int) -> void:
	_selected_target_idx = target_idx
	# 更新按钮状态
	for btn in target_grid.get_children():
		if btn is Button:
			btn.button_pressed = false
	target_grid.get_child(target_grid.get_child_count() - 1).button_pressed = true

func _on_execute_pressed() -> void:
	if _selected_target_idx < 0:
		EventBus.message_log.emit("[color=red]请选择目标![/color]")
		return
	
	# 这里应该显示行动选择对话框
	# 暂时使用第一个可用的行动
	var actions = GameManager.offensive_system.get_available_actions(_tile_idx)
	if actions.is_empty():
		EventBus.message_log.emit("[color=red]没有可用的行动![/color]")
		return
	
	var action_id = actions[0]["id"]
	var result = GameManager.offensive_system.perform_action(_tile_idx, action_id, _selected_target_idx)
	
	if result["success"]:
		_refresh()
	else:
		EventBus.message_log.emit("[color=red]%s[/color]" % result.get("reason", "行动失败"))
