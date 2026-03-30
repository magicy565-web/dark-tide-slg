## cg_gallery_panel.gd — CG Gallery / Recollection scene (v1.0)
## Displays unlocked CGs organized by character, with fullscreen preview.
## Accessible from main menu and in-game pause menu.
extends CanvasLayer

const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State ──
var _visible: bool = false
var _selected_hero: String = ""
var _viewing_cg: bool = false          # True when fullscreen CG preview is active
var _current_preview_index: int = -1   # Index in current hero's CG list
var _current_hero_cgs: Array = []      # CG entries for currently selected hero

# ── Hero display order ──
const HERO_ORDER: Array = [
	"rin", "yukino", "momiji", "hyouka", "suirei", "gekka",
	"hakagure", "sou", "shion", "homura", "hibiki", "sara",
	"mei", "kaede", "akane", "hanabi",
]

# ── UI refs ──
var root: Control
var bg: ColorRect
var title_label: Label
var hero_list_container: VBoxContainer  # Left panel: character list
var hero_list_scroll: ScrollContainer
var cg_grid_container: GridContainer    # Right panel: CG thumbnail grid
var cg_grid_scroll: ScrollContainer
var info_label: Label                   # Bottom: CG info text
var btn_close: Button
var right_panel: PanelContainer
var left_panel: PanelContainer

# Fullscreen preview refs
var preview_layer: Control
var preview_bg: ColorRect
var preview_image: TextureRect
var preview_title: Label
var preview_counter: Label
var btn_prev: Button
var btn_next_preview: Button
var btn_close_preview: Button

# ── Animation ──
var _tween: Tween = null


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 8  # Above most UI
	_build_ui()
	_build_preview_ui()
	hide_gallery()


func _unhandled_input(event: InputEvent) -> void:
	if not _visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _viewing_cg:
				_close_preview()
			else:
				hide_gallery()
			get_viewport().set_input_as_handled()
		elif _viewing_cg:
			if event.keycode == KEY_LEFT or event.keycode == KEY_A:
				_navigate_preview(-1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
				_navigate_preview(1)
				get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "CGGalleryRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)

	# Background
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.06, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bg)

	# ── Title bar ──
	var title_bar := HBoxContainer.new()
	title_bar.anchor_left = 0.0; title_bar.anchor_right = 1.0
	title_bar.anchor_top = 0.0; title_bar.anchor_bottom = 0.0
	title_bar.offset_left = 16; title_bar.offset_right = -16
	title_bar.offset_top = 8; title_bar.offset_bottom = 48
	root.add_child(title_bar)

	title_label = Label.new()
	title_label.text = "CG 图鉴  —  Gallery"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title_label)

	btn_close = Button.new()
	btn_close.text = "✕ 关闭"
	btn_close.custom_minimum_size = Vector2(100, 36)
	btn_close.add_theme_font_size_override("font_size", 14)
	btn_close.pressed.connect(hide_gallery)
	title_bar.add_child(btn_close)

	# ── Left panel: Hero list ──
	left_panel = PanelContainer.new()
	left_panel.anchor_left = 0.0; left_panel.anchor_right = 0.22
	left_panel.anchor_top = 0.0; left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 8; left_panel.offset_right = 0
	left_panel.offset_top = 52; left_panel.offset_bottom = -8
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.05, 0.05, 0.09, 0.9)
	left_style.border_color = ColorTheme.BORDER_DIM
	left_style.set_border_width_all(1)
	left_style.set_corner_radius_all(6)
	left_style.set_content_margin_all(6)
	left_panel.add_theme_stylebox_override("panel", left_style)
	root.add_child(left_panel)

	hero_list_scroll = ScrollContainer.new()
	hero_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(hero_list_scroll)

	hero_list_container = VBoxContainer.new()
	hero_list_container.add_theme_constant_override("separation", 2)
	hero_list_scroll.add_child(hero_list_container)

	# ── Right panel: CG grid ──
	right_panel = PanelContainer.new()
	right_panel.anchor_left = 0.22; right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0; right_panel.anchor_bottom = 1.0
	right_panel.offset_left = 4; right_panel.offset_right = -8
	right_panel.offset_top = 52; right_panel.offset_bottom = -40
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.04, 0.04, 0.07, 0.85)
	right_style.border_color = ColorTheme.BORDER_DIM
	right_style.set_border_width_all(1)
	right_style.set_corner_radius_all(6)
	right_style.set_content_margin_all(10)
	right_panel.add_theme_stylebox_override("panel", right_style)
	root.add_child(right_panel)

	cg_grid_scroll = ScrollContainer.new()
	cg_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cg_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_child(cg_grid_scroll)

	cg_grid_container = GridContainer.new()
	cg_grid_container.columns = 4
	cg_grid_container.add_theme_constant_override("h_separation", 10)
	cg_grid_container.add_theme_constant_override("v_separation", 10)
	cg_grid_scroll.add_child(cg_grid_container)

	# ── Bottom info bar ──
	info_label = Label.new()
	info_label.anchor_left = 0.22; info_label.anchor_right = 1.0
	info_label.anchor_top = 1.0; info_label.anchor_bottom = 1.0
	info_label.offset_left = 10; info_label.offset_right = -10
	info_label.offset_top = -34; info_label.offset_bottom = -8
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	info_label.text = "选择角色查看已解锁的CG"
	root.add_child(info_label)


func _build_preview_ui() -> void:
	preview_layer = Control.new()
	preview_layer.name = "CGPreview"
	preview_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_layer.visible = false
	root.add_child(preview_layer)

	preview_bg = ColorRect.new()
	preview_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_bg.color = Color(0.0, 0.0, 0.0, 0.95)
	preview_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_layer.add_child(preview_bg)

	preview_image = TextureRect.new()
	preview_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_image.offset_left = 20; preview_image.offset_right = -20
	preview_image.offset_top = 40; preview_image.offset_bottom = -50
	preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_layer.add_child(preview_image)

	# Title at top
	preview_title = Label.new()
	preview_title.anchor_left = 0.0; preview_title.anchor_right = 1.0
	preview_title.anchor_top = 0.0; preview_title.anchor_bottom = 0.0
	preview_title.offset_top = 6; preview_title.offset_bottom = 36
	preview_title.offset_left = 20; preview_title.offset_right = -20
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 18)
	preview_title.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	preview_layer.add_child(preview_title)

	# Navigation buttons at bottom
	var nav_bar := HBoxContainer.new()
	nav_bar.anchor_left = 0.0; nav_bar.anchor_right = 1.0
	nav_bar.anchor_top = 1.0; nav_bar.anchor_bottom = 1.0
	nav_bar.offset_top = -44; nav_bar.offset_bottom = -8
	nav_bar.offset_left = 20; nav_bar.offset_right = -20
	nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_bar.add_theme_constant_override("separation", 20)
	preview_layer.add_child(nav_bar)

	btn_prev = Button.new()
	btn_prev.text = "◀ 上一张"
	btn_prev.custom_minimum_size = Vector2(120, 32)
	btn_prev.add_theme_font_size_override("font_size", 13)
	btn_prev.pressed.connect(_navigate_preview.bind(-1))
	nav_bar.add_child(btn_prev)

	preview_counter = Label.new()
	preview_counter.add_theme_font_size_override("font_size", 14)
	preview_counter.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	preview_counter.custom_minimum_size = Vector2(80, 0)
	preview_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_bar.add_child(preview_counter)

	btn_next_preview = Button.new()
	btn_next_preview.text = "下一张 ▶"
	btn_next_preview.custom_minimum_size = Vector2(120, 32)
	btn_next_preview.add_theme_font_size_override("font_size", 13)
	btn_next_preview.pressed.connect(_navigate_preview.bind(1))
	nav_bar.add_child(btn_next_preview)

	btn_close_preview = Button.new()
	btn_close_preview.text = "✕ 关闭预览"
	btn_close_preview.custom_minimum_size = Vector2(120, 32)
	btn_close_preview.add_theme_font_size_override("font_size", 13)
	btn_close_preview.pressed.connect(_close_preview)
	nav_bar.add_child(btn_close_preview)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_gallery() -> void:
	# Build catalog if not already done
	CGManager.build_catalog_from_story_data()
	_visible = true
	root.visible = true
	_populate_hero_list()
	# Auto-select first hero
	if _selected_hero == "" and not HERO_ORDER.is_empty():
		_select_hero(HERO_ORDER[0])
	else:
		_populate_cg_grid()
	# Fade in
	root.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(root, "modulate:a", 1.0, 0.25)
	EventBus.cg_gallery_opened.emit()


func hide_gallery() -> void:
	if _viewing_cg:
		_close_preview()
	_visible = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(root, "modulate:a", 0.0, 0.2)
	_tween.tween_callback(func(): root.visible = false)


# ═══════════════════════════════════════════════════════════════
#                    HERO LIST (Left Panel)
# ═══════════════════════════════════════════════════════════════

func _populate_hero_list() -> void:
	# Clear existing
	for child in hero_list_container.get_children():
		child.queue_free()

	for hero_id in HERO_ORDER:
		var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
		var hero_name: String = hero_data.get("name", hero_id)

		# Count unlocked CGs for this hero
		var unlocked: Array = CGManager.get_unlocked_cgs_for_hero(hero_id)
		var catalog: Array = CGManager.get_hero_cg_catalog(hero_id)
		var total: int = catalog.size()
		var count: int = unlocked.size()

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 13)

		if total > 0:
			btn.text = "%s  (%d/%d)" % [hero_name, count, total]
		else:
			btn.text = "%s" % hero_name

		# Highlight selected hero
		if hero_id == _selected_hero:
			btn.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
		elif count > 0:
			btn.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
		else:
			btn.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)

		btn.pressed.connect(_select_hero.bind(hero_id))
		hero_list_container.add_child(btn)


func _select_hero(hero_id: String) -> void:
	_selected_hero = hero_id
	_populate_hero_list()  # Refresh highlight
	_populate_cg_grid()


# ═══════════════════════════════════════════════════════════════
#                    CG GRID (Right Panel)
# ═══════════════════════════════════════════════════════════════

func _populate_cg_grid() -> void:
	# Clear existing
	for child in cg_grid_container.get_children():
		child.queue_free()

	if _selected_hero == "":
		info_label.text = "选择角色查看已解锁的CG"
		return

	var hero_data: Dictionary = FactionData.HEROES.get(_selected_hero, {})
	var hero_name: String = hero_data.get("name", _selected_hero)
	var catalog: Array = CGManager.get_hero_cg_catalog(_selected_hero)

	# Also include CGs that are unlocked but not yet in catalog (from inline dialogues)
	var all_unlocked: Array = CGManager.get_unlocked_cgs_for_hero(_selected_hero)

	if catalog.is_empty() and all_unlocked.is_empty():
		info_label.text = "%s — 尚无CG数据" % hero_name
		return

	# Build display list from catalog
	_current_hero_cgs = []
	for entry in catalog:
		var cg_id: String = entry["cg_id"]
		var is_unlocked: bool = CGManager.is_cg_unlocked(cg_id)
		_current_hero_cgs.append({
			"cg_id": cg_id,
			"title": entry.get("title", cg_id),
			"unlocked": is_unlocked,
		})

	# Add any unlocked CGs not in catalog
	for cg_id in all_unlocked:
		var found: bool = false
		for entry in _current_hero_cgs:
			if entry["cg_id"] == cg_id:
				found = true
				break
		if not found:
			_current_hero_cgs.append({
				"cg_id": cg_id,
				"title": cg_id,
				"unlocked": true,
			})

	# Create thumbnail buttons
	var unlocked_count: int = 0
	for i in range(_current_hero_cgs.size()):
		var entry: Dictionary = _current_hero_cgs[i]
		var is_unlocked: bool = entry["unlocked"]
		if is_unlocked:
			unlocked_count += 1

		var thumb_btn := Button.new()
		thumb_btn.custom_minimum_size = Vector2(180, 105)  # 16:9 ratio-ish

		if is_unlocked:
			# Try to load thumbnail texture
			var tex: Texture2D = CGManager.load_cg_texture(_selected_hero, entry["cg_id"])
			if tex != null:
				# Create a TextureRect inside the button
				var tex_rect := TextureRect.new()
				tex_rect.texture = tex
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				thumb_btn.add_child(tex_rect)
			thumb_btn.text = ""
			thumb_btn.tooltip_text = entry["title"]
			thumb_btn.pressed.connect(_open_preview.bind(i))
		else:
			# Locked: show placeholder
			thumb_btn.text = "???"
			thumb_btn.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
			thumb_btn.tooltip_text = "未解锁"
			thumb_btn.disabled = true

		cg_grid_container.add_child(thumb_btn)

	info_label.text = "%s — 已解锁 %d/%d" % [hero_name, unlocked_count, _current_hero_cgs.size()]


# ═══════════════════════════════════════════════════════════════
#                  FULLSCREEN CG PREVIEW
# ═══════════════════════════════════════════════════════════════

func _open_preview(index: int) -> void:
	if index < 0 or index >= _current_hero_cgs.size():
		return
	var entry: Dictionary = _current_hero_cgs[index]
	if not entry.get("unlocked", false):
		return

	_current_preview_index = index
	_viewing_cg = true

	var tex: Texture2D = CGManager.load_cg_texture(_selected_hero, entry["cg_id"])
	preview_image.texture = tex
	preview_title.text = entry.get("title", entry["cg_id"])
	_update_preview_nav()

	preview_layer.visible = true
	preview_layer.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(preview_layer, "modulate:a", 1.0, 0.2)


func _close_preview() -> void:
	_viewing_cg = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(preview_layer, "modulate:a", 0.0, 0.15)
	_tween.tween_callback(func(): preview_layer.visible = false)


func _navigate_preview(delta: int) -> void:
	if _current_hero_cgs.is_empty():
		return

	# Find next unlocked CG in the given direction
	var new_index: int = _current_preview_index
	for _i in range(_current_hero_cgs.size()):
		new_index = (new_index + delta + _current_hero_cgs.size()) % _current_hero_cgs.size()
		if _current_hero_cgs[new_index].get("unlocked", false):
			break

	if new_index == _current_preview_index:
		return  # No other unlocked CG found

	_current_preview_index = new_index
	var entry: Dictionary = _current_hero_cgs[new_index]
	var tex: Texture2D = CGManager.load_cg_texture(_selected_hero, entry["cg_id"])

	# Crossfade
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(preview_image, "modulate:a", 0.0, 0.1)
	_tween.tween_callback(func():
		preview_image.texture = tex
		preview_title.text = entry.get("title", entry["cg_id"])
		_update_preview_nav()
	)
	_tween.tween_property(preview_image, "modulate:a", 1.0, 0.15)


func _update_preview_nav() -> void:
	# Count unlocked
	var unlocked_indices: Array = []
	for i in range(_current_hero_cgs.size()):
		if _current_hero_cgs[i].get("unlocked", false):
			unlocked_indices.append(i)
	var current_num: int = unlocked_indices.find(_current_preview_index) + 1
	preview_counter.text = "%d / %d" % [current_num, unlocked_indices.size()]
	btn_prev.disabled = unlocked_indices.size() <= 1
	btn_next_preview.disabled = unlocked_indices.size() <= 1
