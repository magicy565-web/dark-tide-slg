## offensive_panel.gd — 据点进攻行动面板
## 显示可用的进攻行动，允许玩家选择行动和目标并执行。
extends CanvasLayer

var _visible: bool = false
var _tile_idx: int = -1
var _selected_target_idx: int = -1
var _selected_action_id: String = ""

# ── UI 节点 ──
var _root: Control
var _panel: PanelContainer
var _vbox: VBoxContainer
var _header_label: Label
var _action_vbox: VBoxContainer
var _target_label: Label
var _target_grid: GridContainer
var _execute_btn: Button
var _close_btn: Button
var _status_label: Label

# 追踪行动按钮与目标按钮
var _action_buttons: Dictionary = {}   # action_id -> Button
var _target_buttons: Dictionary = {}   # target_idx -> Button

func _ready() -> void:
	layer = UILayerRegistry.LAYER_DETAIL_PANELS

	_root = Control.new()
	_root.name = "OffensivePanelRoot"
	_root.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_root.anchor_left = 0.68
	_root.anchor_top = 0.15
	_root.anchor_right = 1.0
	_root.anchor_bottom = 0.90
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.13, 0.96)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.3, 0.2, 1.0)
	style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(_vbox)

	# 标题行
	var title_hbox = HBoxContainer.new()
	_vbox.add_child(title_hbox)

	_header_label = Label.new()
	_header_label.text = "⚔ 进攻行动"
	_header_label.add_theme_font_size_override("font_size", 16)
	_header_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(_header_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.pressed.connect(hide_panel)
	title_hbox.add_child(_close_btn)

	_vbox.add_child(HSeparator.new())

	# 行动选择区
	var action_title = Label.new()
	action_title.text = "选择行动："
	action_title.add_theme_font_size_override("font_size", 13)
	action_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_vbox.add_child(action_title)

	_action_vbox = VBoxContainer.new()
	_action_vbox.add_theme_constant_override("separation", 3)
	_vbox.add_child(_action_vbox)

	_vbox.add_child(HSeparator.new())

	# 目标选择区
	_target_label = Label.new()
	_target_label.text = "选择目标："
	_target_label.add_theme_font_size_override("font_size", 13)
	_target_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_vbox.add_child(_target_label)

	_target_grid = GridContainer.new()
	_target_grid.columns = 2
	_target_grid.add_theme_constant_override("h_separation", 4)
	_target_grid.add_theme_constant_override("v_separation", 4)
	_vbox.add_child(_target_grid)

	_vbox.add_child(HSeparator.new())

	# 状态提示
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_status_label)

	# 执行按钮
	_execute_btn = Button.new()
	_execute_btn.text = "⚔ 执行进攻"
	_execute_btn.custom_minimum_size = Vector2(0, 36)
	_execute_btn.add_theme_font_size_override("font_size", 14)
	_execute_btn.pressed.connect(_on_execute_pressed)
	_vbox.add_child(_execute_btn)

	_root.visible = false

# ───────────────────────────────────────────────────────────────

func show_panel(tile_idx: int) -> void:
	_tile_idx = tile_idx
	_selected_target_idx = -1
	_selected_action_id = ""
	_root.visible = true
	_visible = true
	_refresh()

func hide_panel() -> void:
	_root.visible = false
	_visible = false

func _refresh() -> void:
	if _tile_idx < 0 or _tile_idx >= GameManager.tiles.size():
		return

	if _tile_idx < 0 or _tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[_tile_idx]
	_header_label.text = "⚔ 进攻 — %s" % tile.get("name", "据点")
	_status_label.text = ""

	_rebuild_actions()
	_rebuild_targets()
	_update_execute_button()

func _rebuild_actions() -> void:
	# 清空旧按钮
	for c in _action_vbox.get_children():
		c.queue_free()
	_action_buttons.clear()

	if not GameManager.offensive_system:
		return

	var actions = GameManager.offensive_system.get_available_actions(_tile_idx)
	for action in actions:
		var row = _build_action_row(action)
		_action_vbox.add_child(row)

func _build_action_row(action: Dictionary) -> Control:
	var btn = Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var cooldown: int = action.get("cooldown", 0)
	var range_val: int = action.get("range", 1)

	if cooldown > 0:
		btn.text = "⏳ %s  [冷却 %d 回合]" % [action["name"], cooldown]
		btn.disabled = true
		btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		btn.text = "%s  [范围 %d]" % [action["name"], range_val]
		btn.tooltip_text = action.get("desc", "")
		btn.pressed.connect(func(): _on_action_selected(action["id"]))

	_action_buttons[action["id"]] = btn
	return btn

func _rebuild_targets() -> void:
	# 清空旧按钮
	for c in _target_grid.get_children():
		c.queue_free()
	_target_buttons.clear()

	if _tile_idx < 0 or not GameManager.adjacency.has(_tile_idx):
		_target_label.text = "无可攻击目标"
		return

	if _tile_idx < 0 or _tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[_tile_idx]
	var owner_id: int = tile.get("owner_id", -1)
	var found: bool = false

	# 根据当前选中行动的范围决定可选目标
	var max_range: int = 1
	if _selected_action_id != "" and GameManager.offensive_system:
		var action_def = GameManager.offensive_system.OFFENSIVE_ACTIONS.get(_selected_action_id, {})
		max_range = action_def.get("range", 1)

	# BFS 找到范围内的所有敌方据点
	var reachable = _bfs_tiles(_tile_idx, max_range)

	for adj_idx in reachable:
		if adj_idx == _tile_idx:
			continue
		if adj_idx < 0 or adj_idx >= GameManager.tiles.size():
			continue
		if adj_idx < 0 or adj_idx >= GameManager.tiles.size():
			return
		var adj_tile = GameManager.tiles[adj_idx]
		if adj_tile == null:
			continue
		var adj_owner: int = adj_tile.get("owner_id", -1)
		if adj_owner != owner_id and adj_owner >= 0:
			var btn = Button.new()
			btn.toggle_mode = true
			btn.text = adj_tile.get("name", "#%d" % adj_idx)
			btn.custom_minimum_size = Vector2(100, 30)
			btn.tooltip_text = "所有者: 玩家 %d" % adj_owner
			btn.pressed.connect(func(): _on_target_selected(adj_idx))
			_target_grid.add_child(btn)
			_target_buttons[adj_idx] = btn
			found = true

	if found:
		_target_label.text = "选择目标（范围 %d）：" % max_range
	else:
		_target_label.text = "范围内无敌方据点"

func _bfs_tiles(start: int, max_range: int) -> Array:
	var visited: Dictionary = {start: 0}
	var queue: Array = [start]
	while queue.size() > 0:
		var cur: int = queue.pop_front()
		if visited[cur] >= max_range:
			continue
		if GameManager.adjacency.has(cur):
			for nb in GameManager.adjacency[cur]:
				if not visited.has(nb):
					visited[nb] = visited[cur] + 1
					queue.append(nb)
	return visited.keys()

func _on_action_selected(action_id: String) -> void:
	_selected_action_id = action_id
	# 更新行动按钮高亮
	for aid in _action_buttons:
		var btn: Button = _action_buttons[aid]
		if not btn.disabled:
			btn.button_pressed = (aid == action_id)
	# 重建目标（范围可能变化）
	_rebuild_targets()
	# 如果之前选的目标不在新范围内，清除
	if _selected_target_idx >= 0 and not _target_buttons.has(_selected_target_idx):
		_selected_target_idx = -1
	_update_execute_button()

func _on_target_selected(target_idx: int) -> void:
	_selected_target_idx = target_idx
	# 更新目标按钮高亮（修复：按 key 精确匹配，不再取最后一个子节点）
	for tidx in _target_buttons:
		var btn: Button = _target_buttons[tidx]
		btn.button_pressed = (tidx == target_idx)
	_update_execute_button()

func _update_execute_button() -> void:
	var ready: bool = (_selected_action_id != "" and _selected_target_idx >= 0)
	_execute_btn.disabled = not ready
	if ready:
		var action_name: String = ""
		if GameManager.offensive_system:
			action_name = GameManager.offensive_system.OFFENSIVE_ACTIONS.get(
				_selected_action_id, {}).get("name", _selected_action_id)
		var target_name: String = ""
		if _selected_target_idx >= 0 and _selected_target_idx < GameManager.tiles.size():
			target_name = GameManager.tiles[_selected_target_idx].get("name", "#%d" % _selected_target_idx)
		_execute_btn.text = "⚔ 执行：%s → %s" % [action_name, target_name]
	else:
		_execute_btn.text = "⚔ 执行进攻"

func _on_execute_pressed() -> void:
	if _selected_action_id == "":
		_status_label.text = "请先选择一个行动！"
		return
	if _selected_target_idx < 0:
		_status_label.text = "请先选择一个目标！"
		return
	if not GameManager.offensive_system:
		_status_label.text = "进攻系统未初始化！"
		return

	var result = GameManager.offensive_system.perform_action(
		_tile_idx, _selected_action_id, _selected_target_idx)

	if result.get("success", false):
		_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		_status_label.text = "✓ 行动成功！"
		# 重置选择
		_selected_action_id = ""
		_selected_target_idx = -1
		_refresh()
	else:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		_status_label.text = "✗ 失败：%s" % result.get("reason", "未知原因")
