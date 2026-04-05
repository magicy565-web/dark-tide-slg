## terrain_info_panel.gd
## v1.4.0 — 地形信息面板
## 显示地块的地形详情、天气交叉效果、改造选项和筑路功能
extends Control

const FactionData = preload("res://systems/faction/faction_data.gd")

# ── 面板状态 ──
var _current_tile_idx: int = -1
var _current_tile: Dictionary = {}

# ── UI 节点引用 ──
var _panel_bg: PanelContainer
var _title_label: Label
var _close_btn: Button
var _content_scroll: ScrollContainer
var _content_vbox: VBoxContainer

# ── 子区域 ──
var _terrain_header: HBoxContainer   # 图标 + 名称 + 描述
var _stats_grid: GridContainer       # 移动/产出/视野/减员
var _weather_section: VBoxContainer  # 天气交叉效果
var _combat_section: VBoxContainer   # 战斗修正
var _upgrade_section: VBoxContainer  # 升级限制与特殊建筑
var _transform_section: VBoxContainer # 地形改造
var _road_section: VBoxContainer     # 筑路

# ── 颜色主题 ──
const COLOR_TERRAIN_TITLE   := Color(0.95, 0.85, 0.50)
const COLOR_SECTION_HEADER  := Color(0.70, 0.90, 1.00)
const COLOR_POSITIVE        := Color(0.40, 1.00, 0.40)
const COLOR_NEGATIVE        := Color(1.00, 0.40, 0.40)
const COLOR_NEUTRAL         := Color(0.85, 0.85, 0.85)
const COLOR_SPECIAL         := Color(1.00, 0.80, 0.20)


func _ready() -> void:
	_build_ui()
	hide()


func _build_ui() -> void:
	# 外层容器
	_panel_bg = PanelContainer.new()
	_panel_bg.custom_minimum_size = Vector2(420, 580)
	add_child(_panel_bg)

	var outer_vbox := VBoxContainer.new()
	_panel_bg.add_child(outer_vbox)

	# 标题栏
	var title_bar := HBoxContainer.new()
	outer_vbox.add_child(title_bar)

	_title_label = Label.new()
	_title_label.text = "地形详情"
	_title_label.add_theme_color_override("font_color", COLOR_TERRAIN_TITLE)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.pressed.connect(hide)
	title_bar.add_child(_close_btn)

	# 滚动区域
	_content_scroll = ScrollContainer.new()
	_content_scroll.custom_minimum_size = Vector2(400, 520)
	outer_vbox.add_child(_content_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.add_child(_content_vbox)

	# 子区域
	_terrain_header = HBoxContainer.new()
	_content_vbox.add_child(_terrain_header)

	_stats_grid = GridContainer.new()
	_stats_grid.columns = 2
	_content_vbox.add_child(_stats_grid)

	_weather_section = VBoxContainer.new()
	_content_vbox.add_child(_weather_section)

	_combat_section = VBoxContainer.new()
	_content_vbox.add_child(_combat_section)

	_upgrade_section = VBoxContainer.new()
	_content_vbox.add_child(_upgrade_section)

	_transform_section = VBoxContainer.new()
	_content_vbox.add_child(_transform_section)

	_road_section = VBoxContainer.new()
	_content_vbox.add_child(_road_section)


# ══════════════════════════════════════════════════════════════════════════════
# 公开接口
# ══════════════════════════════════════════════════════════════════════════════

func show_terrain_info(tile_idx: int) -> void:
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return
	_current_tile_idx = tile_idx
	_current_tile = GameManager.tiles[tile_idx]
	_refresh()
	show()


func _refresh() -> void:
	if _current_tile.is_empty():
		return

	var terrain_type: int = _current_tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})

	# 标题
	_title_label.text = "🗺 地形详情 — %s %s" % [terrain_data.get("icon", ""), terrain_data.get("name", "未知")]

	# 清空所有区域
	for section in [_terrain_header, _stats_grid, _weather_section, _combat_section, _upgrade_section, _transform_section, _road_section]:
		for child in section.get_children():
			child.queue_free()

	_build_terrain_header(terrain_data)
	_build_stats_grid(terrain_type, terrain_data)
	_build_weather_section(terrain_type)
	_build_combat_section(terrain_type, terrain_data)
	_build_upgrade_section(terrain_type)
	_build_transform_section(terrain_type)
	_build_road_section()


# ── 地形标题区域 ──
func _build_terrain_header(terrain_data: Dictionary) -> void:
	var icon_label := Label.new()
	icon_label.text = terrain_data.get("icon", "🌍")
	icon_label.add_theme_font_size_override("font_size", 32)
	_terrain_header.add_child(icon_label)

	var desc_vbox := VBoxContainer.new()
	desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_terrain_header.add_child(desc_vbox)

	var name_label := Label.new()
	name_label.text = terrain_data.get("name", "未知地形")
	name_label.add_theme_color_override("font_color", COLOR_TERRAIN_TITLE)
	name_label.add_theme_font_size_override("font_size", 18)
	desc_vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = terrain_data.get("desc", "")
	desc_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_vbox.add_child(desc_label)

	# 道路状态
	if _current_tile.get("has_road", false):
		var road_label := Label.new()
		road_label.text = "🛤 已有道路（移动消耗已优化）"
		road_label.add_theme_color_override("font_color", COLOR_POSITIVE)
		desc_vbox.add_child(road_label)


# ── 基础属性网格 ──
func _build_stats_grid(terrain_type: int, terrain_data: Dictionary) -> void:
	_add_section_header(_stats_grid, "📊 基础属性", 2)

	# 获取 TerrainTileBridge 的实际数值
	var ttb: Node = _get_ttb()
	var actual_move_cost: int = terrain_data.get("move_cost", 1)
	var actual_visibility: int = terrain_data.get("visibility_range", 2)
	var prod_mods: Dictionary = {}
	if ttb:
		actual_move_cost = ttb.get_tile_move_cost(_current_tile)
		actual_visibility = ttb.get_tile_visibility(_current_tile)
		prod_mods = ttb.get_tile_production_mods(_current_tile)

	var stats: Array = [
		["⚡ 移动消耗", "%d 点" % actual_move_cost, actual_move_cost <= 1],
		["👁 视野范围", "%d 格" % actual_visibility, actual_visibility >= 2],
		["⚔ 攻击倍率", "×%.2f" % terrain_data.get("atk_mult", 1.0), terrain_data.get("atk_mult", 1.0) >= 1.0],
		["🛡 防御倍率", "×%.2f" % terrain_data.get("def_mult", 1.0), terrain_data.get("def_mult", 1.0) >= 1.0],
		["💰 金币修正", "×%.2f" % prod_mods.get("gold_mult", 1.0), prod_mods.get("gold_mult", 1.0) >= 1.0],
		["🌾 粮食修正", "×%.2f" % prod_mods.get("food_mult", 1.0), prod_mods.get("food_mult", 1.0) >= 1.0],
		["⛏ 铁矿修正", "×%.2f" % prod_mods.get("iron_mult", 1.0), prod_mods.get("iron_mult", 1.0) >= 1.0],
		["🔮 魔晶修正", "×%.2f" % prod_mods.get("magic_crystal_mult", 1.0), prod_mods.get("magic_crystal_mult", 1.0) >= 1.0],
		["🏗 建造费用", "×%.2f" % prod_mods.get("building_cost_mult", 1.0), prod_mods.get("building_cost_mult", 1.0) <= 1.0],
		["💀 每回合减员", "%.0f%%" % (terrain_data.get("attrition_pct", 0.0) * 100.0), terrain_data.get("attrition_pct", 0.0) == 0.0],
	]

	for stat in stats:
		var key_label := Label.new()
		key_label.text = stat[0]
		key_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
		_stats_grid.add_child(key_label)

		var val_label := Label.new()
		val_label.text = stat[1]
		val_label.add_theme_color_override("font_color", COLOR_POSITIVE if stat[2] else COLOR_NEGATIVE)
		_stats_grid.add_child(val_label)


# ── 天气交叉效果区域 ──
func _build_weather_section(terrain_type: int) -> void:
	_add_section_header(_weather_section, "🌦 当前天气交叉效果", 1)

	var ttb: Node = _get_ttb()
	if not ttb:
		var no_ttb := Label.new()
		no_ttb.text = "（地形桥接系统未加载）"
		no_ttb.add_theme_color_override("font_color", COLOR_NEGATIVE)
		_weather_section.add_child(no_ttb)
		return

	var cross_mod: Dictionary = ttb.get_terrain_weather_cross_mod(_current_tile)
	if cross_mod.is_empty():
		var none_label := Label.new()
		none_label.text = "当前天气与该地形无特殊交叉效果"
		none_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
		_weather_section.add_child(none_label)
		return

	var desc_label := Label.new()
	desc_label.text = "⚠ %s" % cross_mod.get("desc", "特殊交叉效果")
	desc_label.add_theme_color_override("font_color", COLOR_SPECIAL)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_weather_section.add_child(desc_label)

	# 显示具体数值
	var effects: Dictionary = {
		"攻击修正": cross_mod.get("atk_mult_mod", 0.0),
		"防御修正": cross_mod.get("def_mult_mod", 0.0),
		"粮食修正": cross_mod.get("food_mult_mod", 0.0),
		"金币修正": cross_mod.get("gold_mult_mod", 0.0),
		"移动消耗": float(cross_mod.get("move_cost_add", 0)),
		"额外减员": cross_mod.get("attrition_add", 0.0),
	}
	for effect_name in effects:
		var val: float = effects[effect_name]
		if val == 0.0:
			continue
		var effect_label := Label.new()
		var sign_str: String = "+" if val > 0 else ""
		effect_label.text = "  • %s: %s%.1f%%" % [effect_name, sign_str, val * 100.0]
		var is_positive: bool = (val > 0 and effect_name in ["攻击修正", "防御修正", "粮食修正", "金币修正"]) or \
								(val < 0 and effect_name in ["移动消耗", "额外减员"])
		effect_label.add_theme_color_override("font_color", COLOR_POSITIVE if is_positive else COLOR_NEGATIVE)
		_weather_section.add_child(effect_label)


# ── 战斗修正区域 ──
func _build_combat_section(terrain_type: int, terrain_data: Dictionary) -> void:
	_add_section_header(_combat_section, "⚔ 各兵种地形修正", 1)

	var unit_mods: Dictionary = terrain_data.get("unit_mods", {})
	if unit_mods.is_empty():
		var none_label := Label.new()
		none_label.text = "无特殊兵种修正"
		none_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
		_combat_section.add_child(none_label)
		return

	var unit_names: Dictionary = {
		"cavalry": "🐴 骑兵",
		"archer": "🏹 弓兵",
		"ninja": "🥷 忍者",
		"mage_unit": "🔮 法师",
		"ashigaru": "⚔ 足轻",
		"samurai": "🗡 武士",
		"cannon": "💣 炮兵",
		"priest": "✨ 祭司",
	}

	for unit_key in unit_mods:
		var mod: Dictionary = unit_mods[unit_key]
		var unit_name: String = unit_names.get(unit_key, unit_key)
		var parts: Array = []

		if mod.get("ban", false):
			var ban_label := Label.new()
			ban_label.text = "%s: 🚫 禁止进入" % unit_name
			ban_label.add_theme_color_override("font_color", COLOR_NEGATIVE)
			_combat_section.add_child(ban_label)
			continue

		if mod.get("atk", 0) != 0:
			parts.append("ATK%+d" % mod["atk"])
		if mod.get("def", 0) != 0:
			parts.append("DEF%+d" % mod["def"])
		if mod.get("spd", 0) != 0:
			parts.append("SPD%+d" % mod["spd"])

		if parts.is_empty():
			continue

		var mod_label := Label.new()
		mod_label.text = "%s: %s" % [unit_name, ", ".join(parts)]
		var has_positive: bool = parts.any(func(p): return "+" in p and not "-" in p.replace("+", ""))
		mod_label.add_theme_color_override("font_color", COLOR_POSITIVE if has_positive else COLOR_NEGATIVE)
		_combat_section.add_child(mod_label)

	# 特殊标志
	var flags: Array = terrain_data.get("special_flags", [])
	if not flags.is_empty():
		var flags_label := Label.new()
		flags_label.text = "特殊标志: " + ", ".join(flags)
		flags_label.add_theme_color_override("font_color", COLOR_SPECIAL)
		_combat_section.add_child(flags_label)


# ── 升级限制区域 ──
func _build_upgrade_section(terrain_type: int) -> void:
	_add_section_header(_upgrade_section, "🏗 建设与升级", 1)

	var ttb: Node = _get_ttb()
	if not ttb:
		return

	var upgrade_mods: Dictionary = ttb.TERRAIN_UPGRADE_MODS.get(terrain_type, {})
	if upgrade_mods.is_empty():
		return

	# 等级上限修正
	var level_bonus: int = upgrade_mods.get("max_level_bonus", 0)
	if level_bonus != 0:
		var level_label := Label.new()
		level_label.text = "等级上限: %+d 级" % level_bonus
		level_label.add_theme_color_override("font_color", COLOR_POSITIVE if level_bonus > 0 else COLOR_NEGATIVE)
		_upgrade_section.add_child(level_label)

	# 升级费用修正
	var cost_mult: float = upgrade_mods.get("upgrade_cost_mult", 1.0)
	if cost_mult != 1.0:
		var cost_label := Label.new()
		cost_label.text = "升级费用: ×%.1f" % cost_mult
		cost_label.add_theme_color_override("font_color", COLOR_POSITIVE if cost_mult < 1.0 else COLOR_NEGATIVE)
		_upgrade_section.add_child(cost_label)

	# 禁止建筑
	var forbidden: Array = upgrade_mods.get("forbidden_buildings", [])
	if not forbidden.is_empty():
		var forbidden_label := Label.new()
		forbidden_label.text = "🚫 禁止建造: " + ", ".join(forbidden)
		forbidden_label.add_theme_color_override("font_color", COLOR_NEGATIVE)
		forbidden_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_upgrade_section.add_child(forbidden_label)

	# 特殊解锁建筑
	var special: Array = upgrade_mods.get("special_unlock", [])
	if not special.is_empty():
		var special_label := Label.new()
		special_label.text = "✨ 特殊解锁: " + ", ".join(special)
		special_label.add_theme_color_override("font_color", COLOR_SPECIAL)
		special_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_upgrade_section.add_child(special_label)


# ── 地形改造区域 ──
func _build_transform_section(terrain_type: int) -> void:
	_add_section_header(_transform_section, "🔄 地形改造", 1)

	var ttb: Node = _get_ttb()
	if not ttb:
		return

	# 检查是否有进行中的改造
	if _current_tile_idx in ttb._transform_tasks:
		var task: Dictionary = ttb._transform_tasks[_current_tile_idx]
		var progress_label := Label.new()
		if task.get("is_road", false):
			progress_label.text = "🛤 筑路进行中... 剩余 %d 回合" % task["turns_remaining"]
		else:
			var target_name: String = FactionData.TERRAIN_DATA.get(task["target_terrain"], {}).get("name", "目标地形")
			progress_label.text = "⏳ 改造为 %s 进行中... 剩余 %d 回合" % [target_name, task["turns_remaining"]]
		progress_label.add_theme_color_override("font_color", COLOR_SPECIAL)
		_transform_section.add_child(progress_label)
		return

	# 显示可用的改造选项
	var has_option: bool = false
	for target_terrain in ttb.TERRAIN_TRANSFORM_RECIPES:
		var recipe: Dictionary = ttb.TERRAIN_TRANSFORM_RECIPES[target_terrain]
		if terrain_type not in recipe.get("from_terrains", []):
			continue

		has_option = true
		var option_hbox := HBoxContainer.new()
		_transform_section.add_child(option_hbox)

		var target_data: Dictionary = FactionData.TERRAIN_DATA.get(target_terrain, {})
		var option_label := Label.new()
		option_label.text = "%s → %s %s（%d回合）" % [
			recipe.get("name", "改造"),
			target_data.get("icon", ""),
			target_data.get("name", ""),
			recipe.get("turns_required", 3),
		]
		option_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
		option_hbox.add_child(option_label)

		# 费用显示
		var cost_parts: Array = []
		for res_key in recipe.get("cost", {}):
			cost_parts.append("%s:%d" % [res_key, recipe["cost"][res_key]])
		if not cost_parts.is_empty():
			var cost_label := Label.new()
			cost_label.text = "[%s]" % ", ".join(cost_parts)
			cost_label.add_theme_color_override("font_color", COLOR_SPECIAL)
			option_hbox.add_child(cost_label)

		var transform_btn := Button.new()
		transform_btn.text = "开始"
		transform_btn.pressed.connect(_on_transform_pressed.bind(target_terrain))
		option_hbox.add_child(transform_btn)

	if not has_option:
		var no_option := Label.new()
		no_option.text = "当前地形无可用改造方案"
		no_option.add_theme_color_override("font_color", COLOR_NEUTRAL)
		_transform_section.add_child(no_option)


# ── 筑路区域 ──
func _build_road_section() -> void:
	_add_section_header(_road_section, "🛤 道路建设", 1)

	if _current_tile.get("has_road", false):
		var has_road_label := Label.new()
		has_road_label.text = "✅ 该地块已有道路"
		has_road_label.add_theme_color_override("font_color", COLOR_POSITIVE)
		_road_section.add_child(has_road_label)
		return

	var ttb: Node = _get_ttb()
	if ttb and _current_tile_idx in ttb._transform_tasks and ttb._transform_tasks[_current_tile_idx].get("is_road", false):
		var task: Dictionary = ttb._transform_tasks[_current_tile_idx]
		var progress_label := Label.new()
		progress_label.text = "⏳ 筑路进行中... 剩余 %d 回合" % task["turns_remaining"]
		progress_label.add_theme_color_override("font_color", COLOR_SPECIAL)
		_road_section.add_child(progress_label)
		return

	var terrain_type: int = _current_tile.get("terrain", FactionData.TerrainType.PLAINS)
	var override_cost: int = 1
	if ttb:
		override_cost = ttb.ROAD_MOVE_COST_OVERRIDE.get(terrain_type, 1)
	var base_cost: int = FactionData.TERRAIN_DATA.get(terrain_type, {}).get("move_cost", 1)

	var road_info := Label.new()
	road_info.text = "筑路后移动消耗: %d → %d 点\n费用: 金币×30, 铁矿×10, 行动点×1, 需要2回合" % [base_cost, override_cost]
	road_info.add_theme_color_override("font_color", COLOR_NEUTRAL)
	road_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_road_section.add_child(road_info)

	var road_btn := Button.new()
	road_btn.text = "🛤 开始筑路"
	road_btn.pressed.connect(_on_road_pressed)
	_road_section.add_child(road_btn)


# ══════════════════════════════════════════════════════════════════════════════
# 按钮回调
# ══════════════════════════════════════════════════════════════════════════════

func _on_transform_pressed(target_terrain: int) -> void:
	var ttb: Node = _get_ttb()
	if not ttb:
		return
	var result: Dictionary = ttb.start_terrain_transform(_current_tile_idx, target_terrain)
	if result["success"]:
		_refresh()
	else:
		EventBus.message_log.emit("[color=red]【地形改造失败】%s[/color]" % result.get("reason", "未知原因"))


func _on_road_pressed() -> void:
	var ttb: Node = _get_ttb()
	if not ttb:
		return
	var result: Dictionary = ttb.start_road_construction(_current_tile_idx)
	if result["success"]:
		_refresh()
	else:
		EventBus.message_log.emit("[color=red]【筑路失败】%s[/color]" % result.get("reason", "未知原因"))


# ══════════════════════════════════════════════════════════════════════════════
# 辅助函数
# ══════════════════════════════════════════════════════════════════════════════

func _add_section_header(parent: Control, title: String, span: int = 1) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)

	var header := Label.new()
	header.text = title
	header.add_theme_color_override("font_color", COLOR_SECTION_HEADER)
	header.add_theme_font_size_override("font_size", 14)
	parent.add_child(header)


func _get_ttb() -> Node:
	# 优先从 GameManager 下查找（它是 autoload，挂在 root 下）
	if Engine.get_main_loop() is SceneTree:
		var root: Node = (Engine.get_main_loop() as SceneTree).root
		# 尝试直接路径：/root/GameManager/TerrainTileBridge
		if root.has_node("GameManager/TerrainTileBridge"):
			return root.get_node("GameManager/TerrainTileBridge")
		# 备用：直接在 root 下查找
		if root.has_node("TerrainTileBridge"):
			return root.get_node("TerrainTileBridge")
		# 备用：递归查找
		var found: Node = root.find_child("TerrainTileBridge", true, false)
		if found:
			return found
	return null
