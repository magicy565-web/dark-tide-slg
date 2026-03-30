## tutorial_manager.gd - SR07-style guided first-game tutorial for 暗潮 SLG (v2.0)
## Step-by-step teaching of game mechanics, triggered by game events.
## Each step shows a tooltip/overlay pointing to the relevant UI element.
extends Node

signal tutorial_step_changed(step_id: String)
signal tutorial_completed()

# ── Tutorial steps (SR07-style: sequential, event-driven) ──
# Steps 0-8 map to increasing game complexity.
# "trigger" controls WHEN a step appears; steps that share a trigger with the
# previous step chain automatically (pressing "Next" shows the next one).
# Steps with unique triggers wait until the event fires.
const STEPS: Array = [
	# Step 0 — Welcome
	{
		"id": "welcome",
		"title": "Welcome to Dark Tide / 欢迎来到暗潮",
		"text": "You command a dark faction vying for supremacy.\n你将率领一个暗黑势力征服大陆。\n\n[color=yellow]Tip:[/color] Each faction has unique mechanics — Orcs build WAAAGH!, Pirates plunder for gold, Dark Elves sacrifice slaves for power.\n\nPress [color=cyan]Next[/color] to learn the basics, or [color=gray]Skip Tutorial[/color] to jump right in.",
		"trigger": "game_start",
		"highlight": "",
	},
	# Step 1 — Map Navigation
	{
		"id": "map_navigation",
		"title": "Map Navigation / 地图导航",
		"text": "[color=yellow]Controls:[/color]\n• [color=cyan]WASD[/color] or mouse at screen edge — scroll the map\n• [color=cyan]Mouse wheel[/color] — zoom in/out\n• [color=cyan]Minimap[/color] (bottom-right) — click to jump to any area\n\nYour territory is highlighted in your faction color. Neutral and enemy lands are shown in gray and red.",
		"trigger": "board_ready",
		"highlight": "board",
	},
	# Step 2 — Territory & Resources
	{
		"id": "territory",
		"title": "Territory & Resources / 领地与资源",
		"text": "[color=yellow]Click any tile[/color] you own to see its details.\n\nEach territory produces [color=gold]Gold[/color], [color=green]Food[/color], and [color=silver]Iron[/color] every turn. Different tile types specialize:\n• [color=gold]Mines[/color] produce extra Iron\n• [color=green]Farms[/color] produce extra Food\n• [color=cyan]Trading Posts[/color] produce extra Gold\n\nUpgrade tiles via [color=cyan]Domestic > Upgrade[/color] to boost output.",
		"trigger": "board_ready",
		"highlight": "board",
	},
	# Step 3 — Actions & AP
	{
		"id": "actions",
		"title": "Actions & AP / 行动与行动点",
		"text": "Each turn you have [color=yellow]Action Points (AP)[/color] shown at the top.\n\nThe [color=cyan]left panel[/color] shows available actions:\n• [color=red]Attack[/color] — send armies against enemies (1 AP)\n• [color=cyan]Deploy[/color] — move armies between your tiles\n• [color=green]Domestic[/color] — recruit troops, upgrade tiles, build\n• [color=magenta]Diplomacy[/color] — negotiate with factions\n• [color=yellow]End Turn[/color] — finish and collect income\n\nMore territories = more AP (1 bonus AP per 7 tiles).",
		"trigger": "first_turn",
		"highlight": "ActionPanel",
	},
	# Step 4 — Combat (triggered on first attack)
	{
		"id": "combat",
		"title": "Combat / 战斗系统",
		"text": "Battle resolves automatically based on army composition.\n\n[color=yellow]Key factors:[/color]\n• Unit [color=cyan]Speed[/color] determines attack order\n• [color=green]Terrain[/color] matters — forests favor archers, plains favor cavalry\n• [color=red]Heroes[/color] stationed with armies provide powerful bonuses\n• Battles last up to 12 rounds; morale breaks can cause routs\n\nAfter combat, you may choose to [color=gold]plunder[/color], [color=cyan]occupy[/color], or [color=gray]raze[/color] conquered tiles.",
		"trigger": "first_combat",
		"highlight": "",
	},
	# Step 5 — Heroes (triggered on first hero panel open)
	{
		"id": "heroes",
		"title": "Heroes / 英雄系统",
		"text": "Heroes are powerful characters you can recruit and deploy.\n\n[color=yellow]Hero basics:[/color]\n• Captured enemy heroes can be [color=cyan]recruited[/color], [color=red]executed[/color], or [color=gold]ransomed[/color]\n• Heroes gain [color=cyan]EXP[/color] from battles and level up\n• Each hero has unique [color=yellow]passive skills[/color] and [color=magenta]ultimate abilities[/color]\n• Station heroes in armies to boost combat power\n\nPress [color=cyan]H[/color] anytime to open the Heroes panel.",
		"trigger": "hero_panel_opened",
		"highlight": "",
	},
	# Step 6 — Diplomacy (triggered on first diplomacy panel open)
	{
		"id": "diplomacy",
		"title": "Diplomacy / 外交系统",
		"text": "Negotiate with both neutral and rival factions.\n\n[color=yellow]Options include:[/color]\n• [color=cyan]Ceasefire[/color] — temporary peace with a rival\n• [color=green]Trade[/color] — exchange resources for mutual benefit\n• [color=magenta]Vassalize[/color] — subjugate neutral factions for tribute\n• [color=gold]Alliance[/color] — coordinate attacks with allies\n\nComplete faction quests to improve relations. High [color=red]Threat[/color] makes diplomacy harder — release prisoners to lower it.",
		"trigger": "diplomacy_panel_opened",
		"highlight": "",
	},
	# Step 7 — Economy (triggered on turn 3)
	{
		"id": "economy",
		"title": "Economy & Income / 经济与收入",
		"text": "By now you should see your income flowing each turn.\n\n[color=yellow]Key economy tips:[/color]\n• [color=gold]+/- numbers[/color] next to resources show net income\n• [color=red]Negative food[/color] causes army attrition — keep food positive!\n• [color=cyan]Order[/color] affects production — low order means rebellions\n• [color=red]Threat[/color] determines how aggressively the Light faction attacks you\n• Upgrade tiles and build [color=green]Farms/Mines[/color] to grow your economy\n\nBalance expansion with economic stability.",
		"trigger": "turn_3",
		"highlight": "resource_bar",
	},
	# Step 8 — Tutorial Complete
	{
		"id": "tutorial_complete",
		"title": "Tutorial Complete! / 教程完成!",
		"text": "[color=gold]Congratulations![/color] You now know the essentials.\n\n[color=yellow]Remember:[/color]\n• Press [color=cyan]ESC[/color] for settings and help\n• Press [color=cyan]H[/color] for Heroes, [color=cyan]J[/color] for Quest Journal\n• Three victory paths: [color=red]Conquest[/color] (capture all fortresses), [color=cyan]Domination[/color] (60%+ territory), [color=magenta]Shadow Rule[/color] (threat 100 + ultimate troops)\n\nGood luck, warlord! 祝征途顺利!",
		"trigger": "_complete",
		"highlight": "",
	},
]

# ── State ──
var _tutorial_step: int = 0           # Current step index (0-8)
var _tutorial_complete: bool = false   # Persisted flag — once true, tutorial never shows again
var _active: bool = false
var _current_step_index: int = 0
var _completed_steps: Array = []
var _tutorial_enabled: bool = true
var _pending_triggers: Array = []      # Triggers that fired while popup was showing
var _turn_count: int = 0
var _combat_seen: bool = false         # Track if first combat trigger already fired
var _hero_panel_seen: bool = false     # Track if hero panel trigger already fired
var _diplomacy_panel_seen: bool = false # Track if diplomacy panel trigger already fired

# ── UI ──
var _popup: PanelContainer
var _title_label: Label
var _text_label: RichTextLabel
var _btn_next: Button
var _btn_skip: Button
var _overlay: ColorRect
var _step_label: Label

# ── Highlight ──
var _highlight_node: Control = null
var _highlight_tween: Tween = null


func _ready() -> void:
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	# Semi-transparent overlay
	_overlay = ColorRect.new()
	_overlay.name = "TutorialOverlay"
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.color = Color(0, 0, 0, 0.3)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Popup panel
	_popup = PanelContainer.new()
	_popup.name = "TutorialPopup"
	_popup.custom_minimum_size = Vector2(440, 200)
	_popup.anchor_left = 0.5
	_popup.anchor_top = 0.5
	_popup.anchor_right = 0.5
	_popup.anchor_bottom = 0.5
	_popup.offset_left = -220
	_popup.offset_top = -100
	_popup.offset_right = 220
	_popup.offset_bottom = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	style.border_color = Color(0.6, 0.5, 0.2)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_popup.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(400, 80)
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	vbox.add_child(_text_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_btn_skip = Button.new()
	_btn_skip.text = "跳过教程"
	_btn_skip.pressed.connect(_skip_tutorial)
	btn_row.add_child(_btn_skip)

	_btn_next = Button.new()
	_btn_next.text = "继续"
	_btn_next.pressed.connect(_advance_step)
	btn_row.add_child(_btn_next)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 13)
	_step_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5, 0.7))
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_step_label)

	_popup.visible = false

	# Add UI nodes to the scene tree so they are actually rendered
	add_child(_overlay)
	add_child(_popup)


func _connect_signals() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.board_ready.connect(func(): _trigger("board_ready"))
	EventBus.army_created.connect(func(_a, _b, _c): _trigger("army_created"))
	EventBus.combat_result.connect(_on_first_combat)
	# tutorial_step signal from EventBus — used by HUD to notify hero/diplomacy opens
	EventBus.tutorial_step.connect(_on_external_trigger)


func start_tutorial() -> void:
	if _tutorial_complete or not _tutorial_enabled:
		return
	_active = true
	_current_step_index = 0
	_tutorial_step = 0
	_completed_steps.clear()
	_turn_count = 0
	_combat_seen = false
	_hero_panel_seen = false
	_diplomacy_panel_seen = false
	_trigger("game_start")


## Called by HUD or other systems via EventBus.tutorial_step signal.
func _on_external_trigger(step_id: String) -> void:
	_trigger(step_id)


## First combat — only trigger once.
func _on_first_combat(_a: int, _b: String, _c: bool) -> void:
	if _combat_seen:
		return
	_combat_seen = true
	_trigger("first_combat")


## Called by HUD when player opens the hero panel for the first time.
func notify_hero_panel_opened() -> void:
	if _hero_panel_seen:
		return
	_hero_panel_seen = true
	_trigger("hero_panel_opened")


## Called by HUD when player opens the diplomacy panel for the first time.
func notify_diplomacy_panel_opened() -> void:
	if _diplomacy_panel_seen:
		return
	_diplomacy_panel_seen = true
	_trigger("diplomacy_panel_opened")


func _trigger(trigger_id: String) -> void:
	if not _active:
		return
	if _current_step_index >= STEPS.size():
		_end_tutorial()
		return

	# If the popup is currently visible, queue the trigger for later
	if _popup.visible:
		if trigger_id not in _pending_triggers:
			_pending_triggers.append(trigger_id)
		return

	var step: Dictionary = STEPS[_current_step_index]
	if step["trigger"] == trigger_id:
		_show_step(step)


func _show_step(step: Dictionary) -> void:
	_title_label.text = step["title"]
	_text_label.clear()
	_text_label.append_text(step["text"])
	_step_label.text = "步骤 %d/%d" % [_current_step_index + 1, STEPS.size()]
	_popup.visible = true
	_overlay.visible = true

	# Animate entrance
	_popup.modulate = Color(1, 1, 1, 0)
	var tween := _popup.create_tween()
	tween.tween_property(_popup, "modulate:a", 1.0, 0.3)

	_apply_highlight(step["highlight"])

	tutorial_step_changed.emit(step["id"])


func _advance_step() -> void:
	_completed_steps.append(STEPS[_current_step_index]["id"])
	_current_step_index += 1
	_tutorial_step = _current_step_index
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false

	if _current_step_index >= STEPS.size():
		_end_tutorial()
		return

	# Check if next step triggers immediately (same trigger as previous)
	var next_step: Dictionary = STEPS[_current_step_index]
	var prev_step: Dictionary = STEPS[_current_step_index - 1]
	if next_step["trigger"] == prev_step["trigger"]:
		# Same trigger, show immediately
		_show_step(next_step)
		return

	# Check if next step's trigger is "_complete" — show it immediately
	if next_step["trigger"] == "_complete":
		_show_step(next_step)
		return

	# Replay any pending triggers that queued while popup was showing
	var pending := _pending_triggers.duplicate()
	_pending_triggers.clear()
	for t in pending:
		_trigger(t)


func _skip_tutorial() -> void:
	_active = false
	_tutorial_complete = true
	_tutorial_enabled = false
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false
	_pending_triggers.clear()
	EventBus.tutorial_completed.emit()
	EventBus.message_log.emit("Tutorial skipped. Press ESC for help. / 教程已跳过。按ESC查看帮助。")


func _end_tutorial() -> void:
	_active = false
	_tutorial_complete = true
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false
	_pending_triggers.clear()
	tutorial_completed.emit()
	EventBus.tutorial_completed.emit()
	EventBus.message_log.emit("[color=gold]Tutorial complete! Good luck, warlord! / 教程完成! 祝征途顺利![/color]")


func _apply_highlight(target_name: String) -> void:
	_remove_highlight()
	if target_name.is_empty():
		return

	# Try finding the target by group first, then by name in the tree
	var target: Control = null
	var group_nodes := get_tree().get_nodes_in_group(target_name)
	if group_nodes.size() > 0 and group_nodes[0] is Control:
		target = group_nodes[0] as Control
	else:
		# Walk the scene tree to find by node name
		target = _find_control_by_name(get_tree().root, target_name)

	if target == null or not is_instance_valid(target):
		return

	# Create a highlight overlay Control
	_highlight_node = Control.new()
	_highlight_node.name = "TutorialHighlight"
	_highlight_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_node.z_index = 100

	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(0, 0, 0, 0)  # No fill
	hl_style.border_color = Color(1.0, 0.84, 0.0, 0.9)  # Gold border
	hl_style.border_width_top = 3
	hl_style.border_width_bottom = 3
	hl_style.border_width_left = 3
	hl_style.border_width_right = 3
	hl_style.corner_radius_top_left = 6
	hl_style.corner_radius_top_right = 6
	hl_style.corner_radius_bottom_left = 6
	hl_style.corner_radius_bottom_right = 6

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hl_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_node.add_child(panel)

	# Position over the target
	var target_rect := target.get_global_rect()
	var margin := 4.0
	_highlight_node.global_position = target_rect.position - Vector2(margin, margin)
	_highlight_node.size = target_rect.size + Vector2(margin * 2, margin * 2)
	panel.position = Vector2.ZERO
	panel.size = _highlight_node.size

	# Add to the tree above the overlay
	get_tree().root.add_child(_highlight_node)

	# Pulse animation via tween
	_highlight_node.modulate = Color(1, 1, 1, 0.9)
	_highlight_tween = _highlight_node.create_tween()
	_highlight_tween.set_loops()
	_highlight_tween.tween_property(_highlight_node, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(_highlight_node, "modulate:a", 0.9, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _remove_highlight() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = null
	if _highlight_node and is_instance_valid(_highlight_node):
		_highlight_node.queue_free()
	_highlight_node = null


func _find_control_by_name(node: Node, node_name: String) -> Control:
	if node.name == node_name and node is Control:
		return node as Control
	for child in node.get_children():
		var result := _find_control_by_name(child, node_name)
		if result != null:
			return result
	return null


func _on_turn_started(_pid: int) -> void:
	_turn_count += 1
	if _active:
		# Only trigger "first_turn" on turn 1, not every turn
		if _turn_count == 1:
			_trigger("first_turn")
		_trigger("turn_%d" % _turn_count)


func get_popup_control() -> PanelContainer:
	return _popup

func get_overlay_control() -> ColorRect:
	return _overlay

func is_active() -> bool:
	return _active

func is_complete() -> bool:
	return _tutorial_complete

## Reset tutorial state for new game (called by game_over_panel on restart).
func reset() -> void:
	_active = false
	_current_step_index = 0
	_tutorial_step = 0
	_completed_steps.clear()
	_turn_count = 0
	_combat_seen = false
	_hero_panel_seen = false
	_diplomacy_panel_seen = false
	_pending_triggers.clear()
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false
	# Note: _tutorial_complete and _tutorial_enabled are NOT reset here
	# so completed tutorials stay completed across new games.


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"active": _active,
		"current_step": _current_step_index,
		"tutorial_step": _tutorial_step,
		"tutorial_complete": _tutorial_complete,
		"completed_steps": _completed_steps.duplicate(),
		"tutorial_enabled": _tutorial_enabled,
		"turn_count": _turn_count,
		"combat_seen": _combat_seen,
		"hero_panel_seen": _hero_panel_seen,
		"diplomacy_panel_seen": _diplomacy_panel_seen,
	}

func from_save_data(data: Dictionary) -> void:
	_active = data.get("active", false)
	_current_step_index = data.get("current_step", 0)
	_tutorial_step = data.get("tutorial_step", _current_step_index)
	_tutorial_complete = data.get("tutorial_complete", false)
	_completed_steps = data.get("completed_steps", []).duplicate()
	_tutorial_enabled = data.get("tutorial_enabled", true)
	_turn_count = data.get("turn_count", 0)
	_combat_seen = data.get("combat_seen", false)
	_hero_panel_seen = data.get("hero_panel_seen", false)
	_diplomacy_panel_seen = data.get("diplomacy_panel_seen", false)
	# If tutorial was completed in a previous save, don't show again
	if _tutorial_complete:
		_active = false
		_tutorial_enabled = false
