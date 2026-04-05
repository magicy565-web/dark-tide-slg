## province_info_panel.gd
## 差异化据点信息面板 —— 战国兰斯式地域压制重构
## 不同类型的据点展现完全不同的视觉主题、颜色和功能按钮。
## 通过 T 键或点击据点触发，替代原有的 territory_info_panel。
## 作者: Manus AI  版本: v1.1.0
## v1.1.0 修复: 点击据点自动弹出面板 (P0 Bug); 连接 territory_deselected 信号
extends CanvasLayer

const FactionData = preload("res://systems/faction/faction_data.gd")
const TerritoryTypeSystem = preload("res://systems/map/territory_type_system.gd")

# ── 通用颜色常量 ──
const CLR_GOLD    := Color(0.9, 0.8, 0.4)
const CLR_GREEN   := Color(0.4, 0.8, 0.4)
const CLR_SILVER  := Color(0.7, 0.7, 0.8)
const CLR_RED     := Color(0.9, 0.3, 0.3)
const CLR_CYAN    := Color(0.4, 0.8, 0.8)
const CLR_DIM     := Color(0.5, 0.5, 0.5)
const CLR_TEXT    := Color(0.85, 0.85, 0.85)
const CLR_LABEL   := Color(0.6, 0.6, 0.6)

# ── 行动按钮标签映射 ──
const ACTION_LABELS: Dictionary = {
	"recruit":          "征兵",
	"upgrade_walls":    "加固城墙",
	"train_elite":      "精锐训练",
	"guard":            "驻守防御",
	"domestic":         "内政",
	"build_market":     "建造市场",
	"diplomacy":        "外交",
	"explore":          "探索",
	"ritual":           "举行仪式",
	"research":         "研究",
	"fortify":          "筑垒",
	"block_supply":     "封锁补给",
	"exploit":          "开采资源",
	"upgrade_facility": "升级设施",
	"excavate":         "发掘遗址",
	"attack":           "清剿",
	"upgrade_outpost":  "升级前哨",
}

# ── 状态 ──
var _visible: bool = false
var _selected_tile: int = -1
var _current_prov_type: int = TerritoryTypeSystem.ProvType.WILDERNESS

# ── UI 节点引用 ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var _panel_style: StyleBoxFlat
var type_badge: Label        # 据点类型徽章（左上角）
var header_label: Label      # 据点名称
var type_desc_label: Label   # 据点类型描述
var btn_close: Button
var content_scroll: ScrollContainer
var content_container: VBoxContainer
var quick_action_bar: HBoxContainer   # 快捷行动按钮栏
var garrison_section: VBoxContainer   # 驻守武将区域

# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_DETAIL_PANELS
	_build_ui()
	_connect_signals()
	hide_panel()

func _connect_signals() -> void:
	EventBus.territory_selected.connect(_on_territory_selected)
	if EventBus.has_signal("territory_deselected"):
		EventBus.territory_deselected.connect(_on_territory_deselected)
	if EventBus.has_signal("story_event_completed"):
		EventBus.story_event_completed.connect(_on_story_event_completed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			if _visible:
				hide_panel()
			else:
				show_for_tile(_selected_tile)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()

# ═══════════════════════════════════════════════════════════════
#                       构建 UI 节点树
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "ProvinceInfoRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# 半透明遮罩背景
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.45)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	# 主面板 — 右侧 40% 宽度，全高，从右侧滑入
	main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.60
	main_panel.anchor_right = 1.0
	main_panel.anchor_top = 0.0
	main_panel.anchor_bottom = 1.0
	main_panel.offset_left = 0
	main_panel.offset_right = 0
	main_panel.offset_top = 0
	main_panel.offset_bottom = 0

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.08, 0.07, 0.1, 0.97)
	_panel_style.border_color = Color(0.45, 0.35, 0.2, 0.9)
	_panel_style.set_border_width_all(2)
	_panel_style.border_width_left = 3
	_panel_style.set_corner_radius_all(0)
	_panel_style.corner_radius_top_left = 8
	_panel_style.corner_radius_bottom_left = 8
	_panel_style.set_content_margin_all(0)
	main_panel.add_theme_stylebox_override("panel", _panel_style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	main_panel.add_child(outer_vbox)

	# ── 顶部彩色标题区域 ──
	var header_bg := ColorRect.new()
	header_bg.color = Color(0.12, 0.08, 0.06, 1.0)
	header_bg.custom_minimum_size = Vector2(0, 90)
	outer_vbox.add_child(header_bg)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 4)
	header_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_vbox.offset_left = 14
	header_vbox.offset_right = -14
	header_vbox.offset_top = 10
	header_vbox.offset_bottom = -10
	header_bg.add_child(header_vbox)

	# 类型徽章行（图标 + 类型名 + 关闭按钮）
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 8)
	header_vbox.add_child(badge_row)

	type_badge = Label.new()
	type_badge.text = "🏰 军事要塞"
	type_badge.add_theme_font_size_override("font_size", 13)
	type_badge.add_theme_color_override("font_color", CLR_GOLD)
	type_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_row.add_child(type_badge)

	btn_close = Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(30, 30)
	btn_close.add_theme_font_size_override("font_size", 14)
	btn_close.pressed.connect(hide_panel)
	badge_row.add_child(btn_close)

	# 据点名称
	header_label = Label.new()
	header_label.text = "据点名称"
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	header_vbox.add_child(header_label)

	# 据点类型描述（一行简介）
	type_desc_label = Label.new()
	type_desc_label.text = ""
	type_desc_label.add_theme_font_size_override("font_size", 12)
	type_desc_label.add_theme_color_override("font_color", CLR_DIM)
	type_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_vbox.add_child(type_desc_label)

	# ── 分隔线 ──
	var sep := HSeparator.new()
	outer_vbox.add_child(sep)

	# ── 快捷行动按钮栏 ──
	quick_action_bar = HBoxContainer.new()
	quick_action_bar.add_theme_constant_override("separation", 6)
	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 12)
	bar_margin.add_theme_constant_override("margin_right", 12)
	bar_margin.add_theme_constant_override("margin_top", 8)
	bar_margin.add_theme_constant_override("margin_bottom", 8)
	bar_margin.add_child(quick_action_bar)
	outer_vbox.add_child(bar_margin)

	# ── 分隔线 ──
	var sep2 := HSeparator.new()
	outer_vbox.add_child(sep2)

	# ── 可滚动内容区域 ──
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(content_scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 8)
	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 12)
	content_margin.add_theme_constant_override("margin_right", 12)
	content_margin.add_theme_constant_override("margin_top", 6)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(content_container)
	content_scroll.add_child(content_margin)

# ═══════════════════════════════════════════════════════════════
#                       显示 / 隐藏
# ═══════════════════════════════════════════════════════════════

func show_panel() -> void:
	if not GameManager.game_active:
		return
	_visible = true
	root.visible = true
	_refresh()

func show_for_tile(tile_index: int) -> void:
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	_selected_tile = tile_index
	show_panel()

func hide_panel() -> void:
	_visible = false
	root.visible = false

func is_panel_visible() -> bool:
	return _visible

# ═══════════════════════════════════════════════════════════════
#                       刷新面板内容
# ═══════════════════════════════════════════════════════════════

func _refresh() -> void:
	_clear_content()
	if _selected_tile < 0 or _selected_tile >= GameManager.tiles.size():
		_add_empty_notice("未选择据点")
		return

	if _selected_tile < 0 or _selected_tile >= GameManager.tiles.size():
		return
	var tile: Dictionary = GameManager.tiles[_selected_tile]
	_current_prov_type = TerritoryTypeSystem.get_prov_type_from_tile(tile)
	var type_data: Dictionary = TerritoryTypeSystem.get_type_data(_current_prov_type)

	# ── 更新面板主题颜色 ──
	_apply_theme(type_data)

	# ── 更新标题区域 ──
	var tile_name: String = tile.get("name", "???")
	var tile_level: int = tile.get("level", 0)
	var icon: String = type_data.get("icon", "🌿")
	var type_name: String = type_data.get("name", "荒野前哨")

	type_badge.text = "%s %s" % [icon, type_name]
	type_badge.add_theme_color_override("font_color", type_data.get("header_color", CLR_GOLD))
	header_label.text = "%s  Lv%d" % [tile_name, tile_level]
	type_desc_label.text = type_data.get("description", "")

	# ── 更新快捷行动按钮 ──
	_build_quick_action_bar(tile, _current_prov_type)

	# ── 构建各内容区块 ──
	_build_section_stats(tile, _current_prov_type)
	_build_section_building(tile)
	_build_section_garrison_generals(tile)
	_build_section_garrison_armies(tile)
	_build_section_bonuses(_current_prov_type)
	_build_section_synergy(_current_prov_type, tile)
	_build_section_adjacency(tile)

# ── 应用据点类型主题 ──
func _apply_theme(type_data: Dictionary) -> void:
	var bg_color: Color = type_data.get("bg_color", Color(0.08, 0.07, 0.1, 0.97))
	var border_color: Color = type_data.get("border_color", Color(0.45, 0.35, 0.2, 0.9))
	_panel_style.bg_color = bg_color
	_panel_style.border_color = border_color
	main_panel.add_theme_stylebox_override("panel", _panel_style)

# ═══════════════════════════════════════════════════════════════
#                    快捷行动按钮栏
# ═══════════════════════════════════════════════════════════════

func _build_quick_action_bar(tile: Dictionary, prov_type: int) -> void:
	for child in quick_action_bar.get_children():
		child.queue_free()

	var quick_actions: Array = TerritoryTypeSystem.get_quick_actions(prov_type)
	var type_data: Dictionary = TerritoryTypeSystem.get_type_data(prov_type)
	var header_color: Color = type_data.get("header_color", CLR_GOLD)

	# 检查是否是玩家控制的据点
	var pid: int = GameManager.get_human_player_id()
	var owner: int = tile.get("owner", -1)
	var is_player_owned: bool = (owner == pid)

	for action_key in quick_actions:
		var btn := Button.new()
		btn.text = ACTION_LABELS.get(action_key, action_key)
		btn.custom_minimum_size = Vector2(80, 32)
		btn.add_theme_font_size_override("font_size", 13)

		# 非玩家据点禁用内政类按钮
		if not is_player_owned and action_key not in ["attack", "explore"]:
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		else:
			# 按钮颜色跟随据点主题
			var style_normal := StyleBoxFlat.new()
			style_normal.bg_color = Color(header_color.r * 0.3, header_color.g * 0.3, header_color.b * 0.3, 0.9)
			style_normal.border_color = header_color
			style_normal.set_border_width_all(1)
			style_normal.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_color_override("font_color", header_color)

		var action_copy: String = str(action_key)
		btn.pressed.connect(func(): _on_quick_action_pressed(action_copy, tile))
		quick_action_bar.add_child(btn)

	# v1.4.0: 地形详情按鈕（所有地块类型均显示）
	var terrain_btn := Button.new()
	terrain_btn.text = "🗺 地形"
	terrain_btn.tooltip_text = "查看地形详情、天气交叉效果、改造选项"
	terrain_btn.custom_minimum_size = Vector2(80, 32)
	terrain_btn.add_theme_font_size_override("font_size", 13)
	var terrain_style := StyleBoxFlat.new()
	terrain_style.bg_color = Color(0.1, 0.2, 0.3, 0.9)
	terrain_style.border_color = Color(0.4, 0.7, 1.0)
	terrain_style.set_border_width_all(1)
	terrain_style.set_corner_radius_all(4)
	terrain_btn.add_theme_stylebox_override("normal", terrain_style)
	terrain_btn.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	var tile_idx_copy: int = tile.get("index", -1)
	terrain_btn.pressed.connect(func():
		if EventBus.has_signal("open_terrain_info_panel_requested"):
			EventBus.open_terrain_info_panel_requested.emit(tile_idx_copy)
	)
	quick_action_bar.add_child(terrain_btn)

# ═══════════════════════════════════════════════════════════════
#                    内容区块构建函数
# ═══════════════════════════════════════════════════════════════

## 区块一：据点核心数据（产出、防御、驻守位）
func _build_section_stats(tile: Dictionary, prov_type: int) -> void:
	var type_data: Dictionary = TerritoryTypeSystem.get_type_data(prov_type)
	var header_color: Color = type_data.get("header_color", CLR_GOLD)

	content_container.add_child(_make_section_header("据点数据", header_color))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# 产出行
	var prod: Dictionary = GameManager.get_tile_production(tile)
	var prod_hbox := HBoxContainer.new()
	prod_hbox.add_theme_constant_override("separation", 8)
	prod_hbox.add_child(_make_label("产出:", CLR_LABEL))
	prod_hbox.add_child(_make_label("◆%d 金" % prod.get("gold", 0), CLR_GOLD))
	prod_hbox.add_child(_make_label("◇%d 粮" % prod.get("food", 0), CLR_GREEN))
	prod_hbox.add_child(_make_label("◇%d 铁" % prod.get("iron", 0), CLR_SILVER))
	vbox.add_child(prod_hbox)

	# 防御数据
	var bonuses: Dictionary = TerritoryTypeSystem.get_bonuses(prov_type)
	var def_mult: float = bonuses.get("def_mult", 1.0)
	var wall_hp: int = tile.get("wall_hp", 0)
	var def_hbox := HBoxContainer.new()
	def_hbox.add_theme_constant_override("separation", 8)
	def_hbox.add_child(_make_label("防御:", CLR_LABEL))
	def_hbox.add_child(_make_label("×%.1f 地形" % def_mult, CLR_CYAN))
	if wall_hp > 0:
		def_hbox.add_child(_make_label("城墙 %d HP" % wall_hp, CLR_SILVER))
	vbox.add_child(def_hbox)

	# 驻守位
	var max_slots: int = TerritoryTypeSystem.get_garrison_slots(prov_type)
	var current_generals: int = 0
	if GeneralSystem != null:
		current_generals = GeneralSystem.get_tile_generals(_selected_tile).size()
	elif GameManager.HeroSystem and GameManager.HeroSystem.has_method("get_tile_generals"):
		current_generals = GameManager.HeroSystem.get_tile_generals(_selected_tile).size()
	var garrison_hbox := HBoxContainer.new()
	garrison_hbox.add_theme_constant_override("separation", 8)
	garrison_hbox.add_child(_make_label("驻守位:", CLR_LABEL))
	var slot_color: Color = CLR_GREEN if current_generals < max_slots else CLR_RED
	garrison_hbox.add_child(_make_label("%d / %d" % [current_generals, max_slots], slot_color))
	vbox.add_child(garrison_hbox)

	# 补给状态
	var pid: int = GameManager.get_human_player_id()
	var is_supplied: bool = SupplySystem.is_tile_supplied(pid, _selected_tile)
	var is_capital: bool = SupplySystem.is_capital_tile(pid, _selected_tile)
	var supply_text: String = "★ 首都" if is_capital else ("✓ 补给正常" if is_supplied else "✗ 补给断绝")
	var supply_color: Color = CLR_GREEN if (is_supplied or is_capital) else CLR_RED
	vbox.add_child(_make_hbox_pair("补给:", supply_text, CLR_LABEL, supply_color))

	# 行动扇子消耗提示
	var fan_cost: int = TerritoryTypeSystem.get_action_fan_cost(prov_type)
	if fan_cost > 1:
		vbox.add_child(_make_label("⚠ 攻占此据点需消耗 %d 个行动扇子" % fan_cost, CLR_RED, 12))

## 区块二：驻守武将列表
func _build_section_garrison_generals(tile: Dictionary) -> void:
	content_container.add_child(_make_section_header("驻守武将", CLR_SILVER))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var generals: Array = []
	if GeneralSystem != null:
		generals = GeneralSystem.get_tile_generals(_selected_tile)
	elif GameManager.HeroSystem and GameManager.HeroSystem.has_method("get_tile_generals"):
		generals = GameManager.HeroSystem.get_tile_generals(_selected_tile)

	if generals.is_empty():
		vbox.add_child(_make_label("（无驻守武将）", CLR_DIM))
	else:
		for hero_id in generals:
			var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
			if hero_data.is_empty():
				continue
			var hero_row := HBoxContainer.new()
			hero_row.add_theme_constant_override("separation", 8)

			# 兵种图标
			var troop: String = hero_data.get("troop", "ashigaru")
			var troop_icons: Dictionary = {
				"samurai": "⚔", "cavalry": "🐴", "archer": "🏹",
				"ninja": "🌙", "mage_unit": "✨", "priest": "✚",
				"ashigaru": "🛡", "cannon": "💣",
			}
			var icon_lbl := _make_label(troop_icons.get(troop, "🛡"), CLR_TEXT, 16)
			hero_row.add_child(icon_lbl)

			# 武将名称
			var name_lbl := _make_label(hero_data.get("name", hero_id), CLR_TEXT, 14)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hero_row.add_child(name_lbl)

			# 核心属性
			var stats_lbl := _make_label(
				"ATK%d DEF%d INT%d SPD%d" % [
					hero_data.get("atk", 0), hero_data.get("def", 0),
					hero_data.get("int", 0), hero_data.get("spd", 0)
				], CLR_DIM, 12)
			hero_row.add_child(stats_lbl)
			vbox.add_child(hero_row)

	# 驻守加成提示
	var bonus_desc: String = TerritoryTypeSystem.get_general_bonus_desc(_current_prov_type)
	if bonus_desc != "":
		var bonus_lbl := _make_label("★ %s" % bonus_desc, CLR_GOLD, 12)
		bonus_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(bonus_lbl)

## 区块三：据点类型专属加成
func _build_section_bonuses(prov_type: int) -> void:
	var type_data: Dictionary = TerritoryTypeSystem.get_type_data(prov_type)
	var header_color: Color = type_data.get("header_color", CLR_GOLD)
	var bonuses: Dictionary = TerritoryTypeSystem.get_bonuses(prov_type)

	content_container.add_child(_make_section_header("据点特性", header_color))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# 根据据点类型显示专属加成
	match prov_type:
		TerritoryTypeSystem.ProvType.FORTRESS:
			vbox.add_child(_make_label("🏰 驻守武将获得 DEF+5 加成", header_color, 13))
			vbox.add_child(_make_label("⚔ 每回合自动补充 %d 兵力" % bonuses.get("recruit_bonus", 3), CLR_TEXT, 13))
		TerritoryTypeSystem.ProvType.TOWN:
			vbox.add_child(_make_label("💰 金币产出 ×%.1f 倍" % bonuses.get("gold_mult", 1.5), header_color, 13))
			vbox.add_child(_make_label("🌾 额外粮食 +%d / 回合" % bonuses.get("food_bonus", 2), CLR_TEXT, 13))
		TerritoryTypeSystem.ProvType.SANCTUARY:
			vbox.add_child(_make_label("✨ 武将技能威力 +%.0f%%" % (bonuses.get("skill_power_bonus", 0.2) * 100), header_color, 13))
			vbox.add_child(_make_label("💎 每回合产出魔晶 ×%d" % bonuses.get("crystal_per_turn", 2), CLR_TEXT, 13))
		TerritoryTypeSystem.ProvType.GATE:
			vbox.add_child(_make_label("⚔ 防御倍率 ×%.1f（最高）" % bonuses.get("def_mult", 1.6), header_color, 13))
			vbox.add_child(_make_label("🚫 可阻断敌方补给线", CLR_RED, 13))
		TerritoryTypeSystem.ProvType.RESOURCE:
			vbox.add_child(_make_label("⛏ 专项资源产出 ×%.1f 倍" % bonuses.get("resource_mult", 2.0), header_color, 13))
		TerritoryTypeSystem.ProvType.RUINS:
			vbox.add_child(_make_label("🗿 探索奖励 ×%.1f 倍" % bonuses.get("explore_reward_mult", 1.5), header_color, 13))
			vbox.add_child(_make_label("🎲 每回合 %.0f%% 概率触发事件" % (bonuses.get("event_chance", 0.25) * 100), CLR_TEXT, 13))
		TerritoryTypeSystem.ProvType.BANDIT:
			vbox.add_child(_make_label("💀 清剿奖励: 金 +%d，铁 +%d" % [bonuses.get("defeat_reward_gold", 30), bonuses.get("defeat_reward_iron", 10)], header_color, 13))
		TerritoryTypeSystem.ProvType.WILDERNESS:
			vbox.add_child(_make_label("🌿 升级费用折扣 %.0f%%" % (bonuses.get("upgrade_discount", 0.1) * 100), header_color, 13))

## 区块四：连携效果
func _build_section_synergy(prov_type: int, tile: Dictionary) -> void:
	var synergy: Dictionary = TerritoryTypeSystem.get_synergy(prov_type)
	if synergy.get("type", "none") == "none":
		return

	content_container.add_child(_make_section_header("连携效果", CLR_CYAN))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var desc: String = synergy.get("description", "")
	var desc_lbl := _make_label(desc, CLR_CYAN, 13)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# 检查是否有相邻同类型据点（激活连携）
	var adj: Array = tile.get("adjacent", [])
	var same_type_neighbors: int = 0
	for adj_idx in adj:
		if adj_idx >= 0 and adj_idx < GameManager.tiles.size():
			var adj_tile: Dictionary = GameManager.tiles[adj_idx]
			var adj_prov_type: int = TerritoryTypeSystem.get_prov_type_from_tile(adj_tile)
			var adj_owner: int = adj_tile.get("owner", -1)
			var pid: int = GameManager.get_human_player_id()
			if adj_prov_type == prov_type and adj_owner == pid:
				same_type_neighbors += 1

	if same_type_neighbors > 0:
		vbox.add_child(_make_label("✓ 已激活（%d 个相邻同类据点）" % same_type_neighbors, CLR_GREEN, 12))
	else:
		vbox.add_child(_make_label("○ 未激活（需相邻同类型己方据点）", CLR_DIM, 12))

## 区块五：相邻据点
func _build_section_adjacency(tile: Dictionary) -> void:
	var adj: Array = tile.get("adjacent", [])
	if adj.is_empty():
		return

	content_container.add_child(_make_section_header("相邻据点", CLR_DIM))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var pid: int = GameManager.get_human_player_id()
	for adj_idx in adj:
		if adj_idx < 0 or adj_idx >= GameManager.tiles.size():
			continue
		if adj_idx < 0 or adj_idx >= GameManager.tiles.size():
			return
		var adj_tile: Dictionary = GameManager.tiles[adj_idx]
		var adj_name: String = adj_tile.get("name", "???")
		var adj_owner: int = adj_tile.get("owner", -1)
		var adj_prov_type: int = TerritoryTypeSystem.get_prov_type_from_tile(adj_tile)
		var adj_icon: String = TerritoryTypeSystem.get_type_icon(adj_prov_type)
		var adj_type_name: String = TerritoryTypeSystem.get_type_name(adj_prov_type)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var icon_lbl := _make_label(adj_icon, CLR_TEXT, 13)
		row.add_child(icon_lbl)

		var name_lbl := _make_label(adj_name, CLR_TEXT, 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var type_lbl := _make_label(adj_type_name, CLR_DIM, 11)
		row.add_child(type_lbl)

		# 所有权颜色标记
		var owner_color: Color
		if adj_owner == pid:
			owner_color = CLR_GREEN
		elif adj_owner == -1:
			owner_color = CLR_DIM
		else:
			owner_color = CLR_RED
		var dot_lbl := _make_label("●", owner_color, 12)
		row.add_child(dot_lbl)

		vbox.add_child(row)

# ═══════════════════════════════════════════════════════════════
#                       UI 工厂函数
# ═══════════════════════════════════════════════════════════════

func _make_section_header(text: String, color: Color = CLR_GOLD) -> Label:
	var lbl := Label.new()
	lbl.text = "── %s ──" % text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_section_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.25)
	style.border_color = Color(0.3, 0.3, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", style)
	return pc

func _make_label(text: String, color: Color = CLR_TEXT, size: int = 14) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _make_hbox_pair(label_text: String, value_text: String,
		label_color: Color = CLR_LABEL, value_color: Color = CLR_TEXT) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(_make_label(label_text, label_color))
	hbox.add_child(_make_label(value_text, value_color))
	return hbox

func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()

func _add_empty_notice(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", CLR_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(lbl)

# ═══════════════════════════════════════════════════════════════
#                       事件处理
# ═══════════════════════════════════════════════════════════════

func _on_territory_selected(tile_index: int) -> void:
	## 点击据点时：若面板已打开则刷新内容，否则自动弹出面板。
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	_selected_tile = tile_index
	if _visible:
		_refresh()
	else:
		show_panel()

func _on_territory_deselected() -> void:
	## 取消选择据点时关闭面板。
	hide_panel()

func _on_story_event_completed(_event_id: String) -> void:
	if _visible:
		_refresh()

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()

func _on_quick_action_pressed(action: String, tile: Dictionary) -> void:
	# 将快捷行动转发给原有的行动系统
	# 通过 EventBus 发出行动请求信号
	if EventBus.has_signal("action_requested"):
		EventBus.action_requested.emit(action, _selected_tile)
	else:
		# 降级处理：直接调用 GameManager 的行动方法
		match action:
			"recruit":
				if GameManager.has_method("open_recruit_panel"):
					GameManager.open_recruit_panel(_selected_tile)
			"domestic":
				if GameManager.has_method("open_domestic_panel"):
					GameManager.open_domestic_panel(_selected_tile)
			"explore":
				if GameManager.has_method("execute_explore"):
					GameManager.execute_explore(_selected_tile)
			_:
				EventBus.message_log.emit("行动: %s → 据点 #%d" % [ACTION_LABELS.get(action, action), _selected_tile])
	hide_panel()


# ═══════════════════════════════════════════════════════════════
#          区块：建筑状态（v0.9.3 新增）
# ═══════════════════════════════════════════════════════════════
## 区块：建筑状态 —— 显示当前建筑名称、等级、效果摘要及公共秩序
func _build_section_building(tile: Dictionary) -> void:
	var type_data: Dictionary = TerritoryTypeSystem.get_type_data(_current_prov_type)
	var header_color: Color = type_data.get("header_color", CLR_GOLD)
	content_container.add_child(_make_section_header("建筑 & 秩序", header_color))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# ── 建筑状态 ──
	var bld_id: String = tile.get("building_id", "")
	var bld_level: int = tile.get("building_level", 1)
	if bld_id == "":
		vbox.add_child(_make_hbox_pair("建筑:", "（空地）", CLR_LABEL, CLR_DIM))
	else:
		var bld_name: String = bld_id
		if BuildingRegistry and BuildingRegistry.has_method("get_building_name"):
			bld_name = BuildingRegistry.get_building_name(bld_id, bld_level)
		var max_level: int = 3
		if BuildingRegistry and BuildingRegistry.has_method("get_building_max_level"):
			max_level = BuildingRegistry.get_building_max_level(bld_id)
		var level_color: Color = CLR_GOLD if bld_level >= max_level else CLR_GREEN
		vbox.add_child(_make_hbox_pair("建筑:", bld_name, CLR_LABEL, level_color))
		# 建筑效果摘要
		if BuildingRegistry and BuildingRegistry.has_method("get_building_effects"):
			var effects: Dictionary = BuildingRegistry.get_building_effects(bld_id, bld_level)
			var effect_parts: Array = []
			if effects.get("gold_per_turn", 0) > 0:
				effect_parts.append("金 +%d/回" % effects["gold_per_turn"])
			if effects.get("food_bonus", 0) > 0:
				effect_parts.append("粮 +%d/回" % effects["food_bonus"])
			if effects.get("iron_bonus", 0) > 0:
				effect_parts.append("铁 +%d/回" % effects["iron_bonus"])
			if effects.get("iron_per_turn", 0) > 0:
				effect_parts.append("铁 +%d/回" % effects["iron_per_turn"])
			if effects.get("gunpowder_per_turn", 0) > 0:
				effect_parts.append("火药 +%d/回" % effects["gunpowder_per_turn"])
			if effects.get("slaves_per_turn", 0) > 0:
				effect_parts.append("奴隶 +%d/回" % effects["slaves_per_turn"])
			var se_total: int = effects.get("shadow_per_turn", 0) + effects.get("shadow_essence_per_turn", 0)
			if se_total > 0:
				effect_parts.append("暗影 +%d/回" % se_total)
			if effects.get("recruit_discount", 0) > 0:
				effect_parts.append("招募折扣 -%d%%" % effects["recruit_discount"])
			if effects.get("def_bonus", 0) > 0:
				effect_parts.append("防御 +%d" % effects["def_bonus"])
			if effect_parts.size() > 0:
				var eff_lbl := _make_label("  → " + ", ".join(effect_parts), CLR_DIM, 12)
				eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				vbox.add_child(eff_lbl)
		# 升级提示
		if bld_level < max_level:
			var next_cost: Dictionary = {}
			if BuildingRegistry and BuildingRegistry.has_method("get_building_cost"):
				next_cost = BuildingRegistry.get_building_cost(bld_id, bld_level + 1)
			var cost_parts: Array = []
			if next_cost.get("gold", 0) > 0: cost_parts.append("金%d" % next_cost["gold"])
			if next_cost.get("iron", 0) > 0: cost_parts.append("铁%d" % next_cost["iron"])
			if next_cost.get("slaves", 0) > 0: cost_parts.append("奴隶%d" % next_cost["slaves"])
			var cost_str: String = "（%s）" % ", ".join(cost_parts) if cost_parts.size() > 0 else ""
			vbox.add_child(_make_label("  ↑ 可升至 Lv%d %s" % [bld_level + 1, cost_str], CLR_CYAN, 12))
		else:
			vbox.add_child(_make_label("  ✓ 已达最高等级", CLR_GOLD, 12))

	# ── 公共秩序 ──
	var pub_order: float = tile.get("public_order", 0.8)
	var order_pct: int = int(pub_order * 100.0)
	var order_label: String = "正常运转"
	var order_color: Color = CLR_GREEN
	if pub_order >= 0.9:
		order_label = "繁荣安定"
		order_color = Color(0.3, 1.0, 0.5)
	elif pub_order >= 0.7:
		order_label = "正常运转"
		order_color = CLR_GREEN
	elif pub_order >= 0.5:
		order_label = "略有动荡"
		order_color = Color(0.9, 0.8, 0.2)
	elif pub_order >= 0.3:
		order_label = "民心不稳"
		order_color = Color(0.9, 0.5, 0.1)
	else:
		order_label = "濒临叛乱"
		order_color = CLR_RED

	var order_row := HBoxContainer.new()
	order_row.add_theme_constant_override("separation", 8)
	order_row.add_child(_make_label("公共秩序:", CLR_LABEL))
	order_row.add_child(_make_label("%d%% %s" % [order_pct, order_label], order_color))
	vbox.add_child(order_row)

	# 产出倍率提示
	if ProductionCalculator and ProductionCalculator.has_method("get_tile_order_multiplier"):
		var prod_mult: float = ProductionCalculator.get_tile_order_multiplier(pub_order)
		if prod_mult < 1.0:
			vbox.add_child(_make_label("  ⚠ 产出 ×%.2f（秩序惩罚）" % prod_mult, CLR_RED, 12))

	# ── 战略价值 ──
	var tile_idx: int = tile.get("index", -1)
	if tile_idx >= 0:
		var strat_val: int = 1
		# TerritoryEffects has static methods — call directly without has_method check
		strat_val = TerritoryEffects.get_strategic_value(tile_idx)
		if strat_val <= 0 and GameManager.has_method("get_chokepoint_strategic_value"):
			strat_val = int(GameManager.get_chokepoint_strategic_value(tile_idx))
		var star_str: String = ""
		for _si in range(mini(strat_val, 10)):
			star_str += "★"
		for _si in range(10 - mini(strat_val, 10)):
			star_str += "☆"
		var val_color: Color = CLR_DIM
		if strat_val >= 8: val_color = CLR_RED
		elif strat_val >= 6: val_color = CLR_GOLD
		elif strat_val >= 4: val_color = CLR_CYAN
		vbox.add_child(_make_hbox_pair("战略价值:", "%s (%d/10)" % [star_str, strat_val], CLR_LABEL, val_color))


# ═══════════════════════════════════════════════════════════════
#          区块：驻守军队（v0.9.3 新增）
# ═══════════════════════════════════════════════════════════════
## 区块：驻守军队 —— 显示当前在此据点的军队及其兵力
func _build_section_garrison_armies(tile: Dictionary) -> void:
	var tile_idx: int = tile.get("index", -1)
	if tile_idx < 0:
		return
	# 收集在此据点的所有军队
	var armies_here: Array = []
	for army_id in GameManager.armies:
		var army: Dictionary = GameManager.armies[army_id]
		if army.get("tile_index", -1) == tile_idx:
			armies_here.append(army)
	if armies_here.is_empty():
		return

	content_container.add_child(_make_section_header("驻守军队", CLR_SILVER))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var pid: int = GameManager.get_human_player_id()
	for army in armies_here:
		var army_row := HBoxContainer.new()
		army_row.add_theme_constant_override("separation", 8)
		# 归属颜色
		var owner_pid: int = army.get("player_id", -1)
		var is_player_army: bool = (owner_pid == pid)
		var army_color: Color = CLR_GREEN if is_player_army else CLR_RED
		# 军队状态图标
		var state_icon: String = "⚔"
		var army_id_val: int = army.get("id", -1)
		if MarchSystem and MarchSystem.has_method("is_army_garrisoned"):
			if MarchSystem.is_army_garrisoned(army_id_val):
				state_icon = "🛡"
		elif army.get("is_garrisoned", false):
			state_icon = "🛡"
		army_row.add_child(_make_label(state_icon, army_color, 14))
		# 军队名称
		var army_name: String = army.get("name", "军队 #%d" % army_id_val)
		var name_lbl := _make_label(army_name, army_color, 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		army_row.add_child(name_lbl)
		# 兵力
		var soldiers: int = 0
		if GameManager.has_method("get_army_soldier_count"):
			soldiers = GameManager.get_army_soldier_count(army_id_val)
		else:
			soldiers = army.get("soldiers", 0)
		var max_soldiers: int = army.get("max_soldiers", maxi(soldiers, 1))
		var soldier_color: Color = CLR_GREEN
		if soldiers < max_soldiers / 2:
			soldier_color = CLR_RED
		elif soldiers < max_soldiers * 3 / 4:
			soldier_color = Color(0.9, 0.8, 0.2)
		army_row.add_child(_make_label("%d/%d 兵" % [soldiers, max_soldiers], soldier_color, 12))
		# 所属派系
		var faction_id: int = GameManager.get_player_faction(owner_pid)
		var faction_name: String = FactionData.FACTION_NAMES.get(faction_id, "未知") if FactionData.FACTION_NAMES.has(faction_id) else "未知"
		army_row.add_child(_make_label("(%s)" % faction_name, CLR_DIM, 11))
		vbox.add_child(army_row)
