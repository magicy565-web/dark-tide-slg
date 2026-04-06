## notification_bar.gd - Top notification system for Dark Tide SLG (v0.9.1)
## Slide-in notifications for important events (hero captures, research complete, etc.)
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

const MAX_VISIBLE: int = 3
const DISPLAY_TIME: float = 4.0
const SLIDE_TIME: float = 0.3

# ── UI refs ──
var root: Control
var notification_container: VBoxContainer
var _active_notifications: Array = []


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_NOTIFICATION
	_build_ui()
	_connect_signals()


func _connect_signals() -> void:
	# Listen to important events
	EventBus.hero_captured.connect(_on_hero_captured)
	EventBus.hero_recruited.connect(_on_hero_recruited)
	EventBus.tech_effects_applied.connect(_on_tech_complete)
	EventBus.tile_captured.connect(_on_tile_captured)
	EventBus.expedition_spawned.connect(_on_expedition)
	EventBus.rebellion_occurred.connect(_on_rebellion)
	EventBus.relic_selected.connect(_on_relic)
	EventBus.ai_threat_changed.connect(_on_ai_threat)
	EventBus.unit_routed.connect(_on_unit_routed)
	EventBus.hidden_hero_discovered.connect(_on_hidden_hero_discovered)
	EventBus.story_window_triggered.connect(_on_story_window_triggered)
	EventBus.story_window_expired.connect(_on_story_window_expired)
	if EventBus.has_signal("mission_available"):
		EventBus.mission_available.connect(_on_mission_available)


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "NotifRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	notification_container = VBoxContainer.new()
	notification_container.anchor_left = 0.5
	notification_container.anchor_right = 0.5
	notification_container.offset_left = -200
	notification_container.offset_right = 200
	notification_container.offset_top = 60
	notification_container.add_theme_constant_override("separation", 4)
	notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notification_container)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_notification(text: String, color: Color = Color(0.9, 0.8, 0.5), duration: float = DISPLAY_TIME) -> void:
	# Limit active notifications
	if _active_notifications.size() >= MAX_VISIBLE:
		var oldest = _active_notifications.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.BG_PRIMARY
	style.border_color = color * 0.6
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)

	notification_container.add_child(panel)
	_active_notifications.append(panel)

	# Slide in from right
	panel.modulate.a = 0.0
	panel.position.x = 100
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, SLIDE_TIME)
	tween.tween_property(panel, "position:x", 0.0, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Auto-dismiss
	tween.chain().tween_interval(duration)
	tween.chain().tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(_remove_notification.bind(panel))


func _remove_notification(panel: PanelContainer) -> void:
	if panel in _active_notifications:
		_active_notifications.erase(panel)
	if is_instance_valid(panel):
		panel.queue_free()


# ═══════════════════════════════════════════════════════════════
#                       SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_hero_captured(hero_id: String) -> void:
	var hero_name: String = FactionData.HEROES.get(hero_id, {}).get("name", hero_id)
	show_notification("【英雄被捕】%s" % hero_name, Color(0.9, 0.6, 0.9))


func _on_hero_recruited(hero_id: String) -> void:
	var hero_name: String = FactionData.HEROES.get(hero_id, {}).get("name", hero_id)
	show_notification("【加入阵营】%s" % hero_name, Color(0.4, 1.0, 0.5))


func _on_tech_complete(_pid: int) -> void:
	show_notification("【研究完成】技术研究已完成", Color(0.4, 0.8, 1.0))


func _on_tile_captured(pid: int, tile_index: int) -> void:
	if pid != GameManager.get_human_player_id():
		return
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var tile: Dictionary = GameManager.tiles[tile_index]
	show_notification("【占领据点】%s" % tile.get("name", "???"), Color(0.4, 1.0, 0.4))


func _on_expedition(_tile_index: int) -> void:
	show_notification("【警告】远征军队来袭！", Color(1.0, 0.3, 0.2), 5.0)


func _on_rebellion(tile_index: int) -> void:
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var tile: Dictionary = GameManager.tiles[tile_index]
	show_notification("【叛乱】%s 发生暴动！" % tile.get("name", "???"), Color(1.0, 0.5, 0.2))


func _on_relic(_pid: int, relic_id: String) -> void:
	show_notification("【得到神器】%s" % relic_id, Color(1.0, 0.8, 0.2))


func _on_ai_threat(faction_key: String, _threat: int, new_tier: int) -> void:
	if new_tier >= 2:
		show_notification("【警告】%s 势力已升至第%d级威胁！" % [faction_key, new_tier], Color(1.0, 0.4, 0.3), 5.0)


func _on_unit_routed(unit_type: String, side: String) -> void:
	var side_name: String = "我方" if side == "attacker" else "敌方"
	show_notification("%s %s 士气崩溃溃逃!" % [side_name, unit_type], Color(1.0, 0.3, 0.2), 3.0)


func _on_hidden_hero_discovered(_hero_id: String, hero_name: String, message: String) -> void:
	show_notification("【发现英雄】%s！%s" % [hero_name, message], Color(0.7, 0.4, 1.0), 5.0)


func _on_story_window_triggered(_window_id: String, title: String, _narrative: String) -> void:
	show_notification("【限时事件】%s" % title, Color(0.3, 0.9, 0.4), 5.0)


func _on_story_window_expired(_window_id: String, title: String, consequence: String) -> void:
	show_notification("【事件过期】%s — %s" % [title, consequence], Color(1.0, 0.3, 0.2), 5.0)


## Sengoku Rance-style mission available notification
func _on_mission_available(hero_id: String, event_data: Dictionary) -> void:
	var hero_name: String = FactionData.HEROES.get(hero_id, {}).get("name", hero_id)
	var event_name: String = event_data.get("name", "新任务")
	# Show a prominent golden notification — Sengoku Rance style
	show_notification("★ 新任务：%s「%s」" % [hero_name, event_name], Color(1.0, 0.85, 0.2), 5.0)
