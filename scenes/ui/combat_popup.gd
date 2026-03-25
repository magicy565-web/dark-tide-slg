## combat_popup.gd - Battle result display for 暗潮 SLG (v0.9.1)
## Shows combat outcome with attacker/defender info, losses, and loot
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State ──
var _visible: bool = false
var _queue: Array = []  # Queue of combat results to show

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var popup_panel: PanelContainer
var title_label: Label
var result_label: RichTextLabel
var btn_dismiss: Button

var _tween: Tween = null


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 6
	_build_ui()
	_connect_signals()
	hide_popup()


func _connect_signals() -> void:
	EventBus.combat_result.connect(_on_combat_result)


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "CombatRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim_bg)

	popup_panel = PanelContainer.new()
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.offset_left = -280
	popup_panel.offset_right = 280
	popup_panel.offset_top = -180
	popup_panel.offset_bottom = 180
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.1, 0.97)
	style.border_color = Color(0.8, 0.3, 0.1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	popup_panel.add_theme_stylebox_override("panel", style)
	root.add_child(popup_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	popup_panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "战斗结果"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Result content
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	result_label = RichTextLabel.new()
	result_label.bbcode_enabled = true
	result_label.fit_content = true
	result_label.scroll_active = false
	result_label.add_theme_font_size_override("normal_font_size", 14)
	result_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.88))
	scroll.add_child(result_label)

	# Dismiss
	btn_dismiss = Button.new()
	btn_dismiss.text = "确认"
	btn_dismiss.custom_minimum_size = Vector2(140, 38)
	btn_dismiss.add_theme_font_size_override("font_size", 15)
	btn_dismiss.pressed.connect(_on_dismiss)
	vbox.add_child(btn_dismiss)
	# Center the button
	btn_dismiss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_combat_result(data: Dictionary) -> void:
	var won: bool = data.get("won", false)
	var attacker: String = data.get("attacker_name", "进攻方")
	var defender: String = data.get("defender_name", "防守方")
	var atk_losses: int = data.get("attacker_losses", 0)
	var def_losses: int = data.get("defender_losses", 0)
	var atk_power: int = data.get("attacker_power", 0)
	var def_power: int = data.get("defender_power", 0)
	var tile_name: String = data.get("tile_name", "")
	var loot_gold: int = data.get("loot_gold", 0)
	var slaves_captured: int = data.get("slaves_captured", 0)
	var hero_captured: String = data.get("hero_captured", "")

	if won:
		title_label.text = "胜利!"
		title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		title_label.text = "败北..."
		title_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

	var text: String = ""

	# Battle location
	if tile_name != "":
		text += "[center][color=gray]%s[/color][/center]\n\n" % tile_name

	# Power comparison
	text += "[color=cyan]%s[/color] (战力: %d)  vs  [color=red]%s[/color] (战力: %d)\n\n" % [attacker, atk_power, defender, def_power]

	# Separator line
	text += "[color=gray]━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n\n"

	# Losses
	text += "我方损失: [color=yellow]%d[/color] 兵\n" % atk_losses
	text += "敌方损失: [color=yellow]%d[/color] 兵\n" % def_losses

	# Loot
	if won:
		text += "\n[color=gold]战利品:[/color]\n"
		if loot_gold > 0:
			text += "  金币 +%d\n" % loot_gold
		if slaves_captured > 0:
			text += "  俘虏 +%d\n" % slaves_captured
		if hero_captured != "":
			var hero_name: String = FactionData.HEROES.get(hero_captured, {}).get("name", hero_captured)
			text += "  [color=orchid]俘获英雄: %s[/color]\n" % hero_name

	result_label.text = text
	_show_animated()


func hide_popup() -> void:
	_visible = false
	root.visible = false
	# Show next queued result
	if not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		call_deferred("show_combat_result", next)


# ═══════════════════════════════════════════════════════════════
#                       CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_combat_result(attacker_id: int, defender_desc: String, won: bool) -> void:
	# Only show popup for human player combats
	if attacker_id != GameManager.get_human_player_id():
		return
	# Build basic data from signal
	var data := {
		"won": won,
		"attacker_name": (GameManager.get_player_by_id(attacker_id) or {"name": "玩家"}).get("name", "玩家"),
		"defender_name": defender_desc,
	}
	if _visible:
		_queue.append(data)
	else:
		show_combat_result(data)


func _on_dismiss() -> void:
	_hide_animated()


# ═══════════════════════════════════════════════════════════════
#                       ANIMATION
# ═══════════════════════════════════════════════════════════════

func _show_animated() -> void:
	_visible = true
	root.visible = true
	dim_bg.modulate.a = 0.0
	popup_panel.modulate.a = 0.0
	popup_panel.scale = Vector2(0.85, 0.85)

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 1.0, 0.2)
	_tween.tween_property(popup_panel, "modulate:a", 1.0, 0.3)
	_tween.tween_property(popup_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_animated() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 0.0, 0.15)
	_tween.tween_property(popup_panel, "modulate:a", 0.0, 0.15)
	_tween.chain().tween_callback(hide_popup)
