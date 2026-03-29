class_name VfxLoader
## Maps hero_id -> ultimate VFX texture path and display config

const VFX_BASE := "res://assets/vfx/ultimate/"

const HERO_VFX: Dictionary = {
	"rin": {texture = "01_rin_sakura_tempest.png", color = Color(1.0, 0.41, 0.71), name = "桜吹雪"},
	"yukino": {texture = "02_yukino_ice_age.png", color = Color(0.0, 0.8, 1.0), name = "氷河世紀"},
	"momiji": {texture = "03_momiji_crimson_inferno.png", color = Color(1.0, 0.3, 0.0), name = "紅蓮業火"},
	"hyouka": {texture = "04_hyouka_absolute_zero.png", color = Color(0.4, 0.7, 1.0), name = "絶対零度"},
	"suirei": {texture = "05_suirei_star_arrow_dance.png", color = Color(0.2, 0.9, 0.4), name = "星矢乱舞"},
	"gekka": {texture = "06_gekka_lunar_shadow.png", color = Color(0.7, 0.8, 1.0), name = "月影無双"},
	"hakagure": {texture = "07_hakagure_shadow_execution.png", color = Color(0.4, 0.0, 0.6), name = "影殺陣"},
	"sou": {texture = "08_sou_heaven_collapse.png", color = Color(0.0, 0.3, 0.7), name = "天崩地裂"},
	"shion": {texture = "09_shion_spacetime_rupture.png", color = Color(0.6, 0.2, 1.0), name = "時空断裂"},
	"homura": {texture = "10_homura_hell_flame_dance.png", color = Color(0.8, 0.1, 0.0), name = "煉獄炎舞"},
	"hibiki": {texture = "11_hibiki_mountain_collapse.png", color = Color(0.6, 0.4, 0.2), name = "山崩地裂"},
	"sara": {texture = "12_sara_dust_storm.png", color = Color(0.8, 0.7, 0.3), name = "砂塵嵐"},
	"mei": {texture = "13_mei_underworld_summon.png", color = Color(0.0, 0.5, 0.2), name = "冥府召喚"},
	"kaede": {texture = "14_kaede_thousand_shadows.png", color = Color(0.2, 0.6, 0.3), name = "千影分身"},
	"akane": {texture = "15_akane_purification_light.png", color = Color(1.0, 0.85, 0.3), name = "浄化の光"},
	"hanabi": {texture = "16_hanabi_fireworks_barrage.png", color = Color(1.0, 0.4, 0.4), name = "花火連弾"},
	"shion_pirate": {texture = "17_shion_pirate_tidal_cannon.png", color = Color(0.1, 0.3, 0.7), name = "潮鳴砲撃"},
	"youya": {texture = "18_youya_dark_funeral.png", color = Color(0.3, 0.0, 0.5), name = "闇夜葬送"},
}

static var _cache: Dictionary = {}

static func load_vfx(hero_id: String) -> Texture2D:
	if _cache.has(hero_id):
		return _cache[hero_id]
	var data: Dictionary = HERO_VFX.get(hero_id, {})
	if data.is_empty():
		return null
	var path: String = VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[hero_id] = tex
		return tex
	return null

static func get_vfx_data(hero_id: String) -> Dictionary:
	return HERO_VFX.get(hero_id, {})

static func get_skill_color(hero_id: String) -> Color:
	var data: Dictionary = HERO_VFX.get(hero_id, {})
	return data.get("color", Color.WHITE)

static func get_skill_name(hero_id: String) -> String:
	var data: Dictionary = HERO_VFX.get(hero_id, {})
	return data.get("name", "")

static func clear_cache() -> void:
	_cache.clear()


# ---------------------------------------------------------------------------
# Attack VFX (per troop class)
# ---------------------------------------------------------------------------

const ATK_VFX_BASE := "res://assets/vfx/attack/"

const ATTACK_VFX: Dictionary = {
	"slash":      {texture = "slash_melee.png",      size = Vector2(120, 120)},
	"arrow":      {texture = "arrow_ranged.png",     size = Vector2(100, 100)},
	"charge":     {texture = "cavalry_charge.png",   size = Vector2(140, 140)},
	"cannonball": {texture = "cannon_blast.png",     size = Vector2(130, 130)},
	"magic":      {texture = "magic_bolt.png",       size = Vector2(110, 110)},
	"shuriken":   {texture = "shuriken_shadow.png",  size = Vector2(100, 100)},
	"heal":       {texture = "heal_holy.png",        size = Vector2(120, 120)},
	"shield":     {texture = "shield_defend.png",    size = Vector2(120, 120)},
}

static func load_attack_vfx(proj_type: String) -> Texture2D:
	var key := "atk:" + proj_type
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = ATTACK_VFX.get(proj_type, {})
	if data.is_empty():
		return null
	var path: String = ATK_VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[key] = tex
		return tex
	return null

static func get_attack_vfx_size(proj_type: String) -> Vector2:
	var data: Dictionary = ATTACK_VFX.get(proj_type, {})
	return data.get("size", Vector2(100, 100))


# ---------------------------------------------------------------------------
# Buff VFX
# ---------------------------------------------------------------------------

const BUFF_VFX_BASE := "res://assets/vfx/buff/"

const BUFF_VFX: Dictionary = {
	"atk_boost": {texture = "atk_boost.png", size = Vector2(100, 100), color = Color(1.0, 0.4, 0.0)},
	"def_boost": {texture = "def_boost.png", size = Vector2(100, 100), color = Color(0.3, 0.5, 1.0)},
	"spd_boost": {texture = "spd_boost.png", size = Vector2(100, 100), color = Color(0.4, 0.9, 0.2)},
	"team_buff": {texture = "team_buff.png", size = Vector2(120, 120), color = Color(1.0, 0.85, 0.3)},
}

static func load_buff_vfx(type: String) -> Texture2D:
	var key := "buff:" + type
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = BUFF_VFX.get(type, {})
	if data.is_empty():
		return null
	var path: String = BUFF_VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[key] = tex
		return tex
	return null

static func get_buff_vfx_size(type: String) -> Vector2:
	var data: Dictionary = BUFF_VFX.get(type, {})
	return data.get("size", Vector2(100, 100))

static func get_buff_vfx_color(type: String) -> Color:
	var data: Dictionary = BUFF_VFX.get(type, {})
	return data.get("color", Color.WHITE)


# ---------------------------------------------------------------------------
# Debuff VFX
# ---------------------------------------------------------------------------

const DEBUFF_VFX_BASE := "res://assets/vfx/debuff/"

const DEBUFF_VFX: Dictionary = {
	"freeze": {texture = "freeze.png", size = Vector2(110, 110), color = Color(0.0, 0.8, 1.0)},
	"poison": {texture = "poison.png", size = Vector2(100, 100), color = Color(0.5, 0.9, 0.2)},
	"burn":   {texture = "burn.png",   size = Vector2(110, 110), color = Color(1.0, 0.3, 0.0)},
}

static func load_debuff_vfx(type: String) -> Texture2D:
	var key := "debuff:" + type
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = DEBUFF_VFX.get(type, {})
	if data.is_empty():
		return null
	var path: String = DEBUFF_VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[key] = tex
		return tex
	return null

static func get_debuff_vfx_size(type: String) -> Vector2:
	var data: Dictionary = DEBUFF_VFX.get(type, {})
	return data.get("size", Vector2(110, 110))

static func get_debuff_vfx_color(type: String) -> Color:
	var data: Dictionary = DEBUFF_VFX.get(type, {})
	return data.get("color", Color.WHITE)


# ---------------------------------------------------------------------------
# Formation VFX
# ---------------------------------------------------------------------------

const FORMATION_VFX_BASE := "res://assets/vfx/formation/"

const FORMATION_VFX: Dictionary = {
	"iron_wall":        {texture = "iron_wall.png",        size = Vector2(200, 120), color = Color(0.6, 0.6, 0.7)},
	"cavalry_charge":   {texture = "cavalry_charge.png",   size = Vector2(200, 120), color = Color(0.8, 0.5, 1.0)},
	"arrow_storm":      {texture = "arrow_storm.png",      size = Vector2(200, 120), color = Color(0.35, 0.65, 0.35)},
	"shadow_strike":    {texture = "shadow_strike.png",    size = Vector2(200, 120), color = Color(0.4, 0.0, 0.6)},
	"arcane_barrage":   {texture = "arcane_barrage.png",   size = Vector2(200, 120), color = Color(0.45, 0.3, 0.7)},
	"holy_bastion":     {texture = "holy_bastion.png",     size = Vector2(200, 120), color = Color(1.0, 0.85, 0.3)},
	"berserker_horde":  {texture = "berserker_horde.png",  size = Vector2(200, 120), color = Color(0.8, 0.1, 0.0)},
	"pirate_broadside": {texture = "pirate_broadside.png", size = Vector2(200, 120), color = Color(0.1, 0.3, 0.7)},
	"balanced_force":   {texture = "balanced_force.png",   size = Vector2(200, 120), color = Color(0.7, 0.7, 0.7)},
	"lone_wolf":        {texture = "lone_wolf.png",        size = Vector2(200, 120), color = Color(0.9, 0.7, 0.2)},
}

static func load_formation_vfx(formation_key: String) -> Texture2D:
	var key := "formation:" + formation_key
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = FORMATION_VFX.get(formation_key, {})
	if data.is_empty():
		return null
	var path: String = FORMATION_VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[key] = tex
		return tex
	return null

static func get_formation_vfx_size(formation_key: String) -> Vector2:
	var data: Dictionary = FORMATION_VFX.get(formation_key, {})
	return data.get("size", Vector2(200, 120))

static func get_formation_vfx_color(formation_key: String) -> Color:
	var data: Dictionary = FORMATION_VFX.get(formation_key, {})
	return data.get("color", Color.WHITE)


# ---------------------------------------------------------------------------
# Morale VFX
# ---------------------------------------------------------------------------

const MORALE_VFX_BASE := "res://assets/vfx/morale/"

const MORALE_VFX: Dictionary = {
	"rout":  {texture = "morale_rout.png",  size = Vector2(120, 120), color = Color(0.3, 0.0, 0.0)},
	"rally": {texture = "morale_rally.png", size = Vector2(120, 120), color = Color(1.0, 0.85, 0.3)},
	"waver": {texture = "morale_waver.png", size = Vector2(100, 100), color = Color(0.7, 0.7, 0.5)},
}

static func load_morale_vfx(type: String) -> Texture2D:
	var key := "morale:" + type
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = MORALE_VFX.get(type, {})
	if data.is_empty():
		return null
	var path: String = MORALE_VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[key] = tex
		return tex
	return null

static func get_morale_vfx_size(type: String) -> Vector2:
	var data: Dictionary = MORALE_VFX.get(type, {})
	return data.get("size", Vector2(120, 120))

static func get_morale_vfx_color(type: String) -> Color:
	var data: Dictionary = MORALE_VFX.get(type, {})
	return data.get("color", Color.WHITE)


# ---------------------------------------------------------------------------
# Heal VFX
# ---------------------------------------------------------------------------

const HEAL_VFX_BASE := "res://assets/vfx/heal/"

const HEAL_VFX: Dictionary = {
	"heal_pulse": {texture = "heal_pulse.png", size = Vector2(120, 120), color = Color(0.2, 0.9, 0.4)},
	"mass_heal":  {texture = "mass_heal.png",  size = Vector2(160, 160), color = Color(1.0, 0.85, 0.3)},
}

static func load_heal_vfx(type: String) -> Texture2D:
	var key := "heal:" + type
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = HEAL_VFX.get(type, {})
	if data.is_empty():
		return null
	var path: String = HEAL_VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[key] = tex
		return tex
	return null

static func get_heal_vfx_size(type: String) -> Vector2:
	var data: Dictionary = HEAL_VFX.get(type, {})
	return data.get("size", Vector2(120, 120))

static func get_heal_vfx_color(type: String) -> Color:
	var data: Dictionary = HEAL_VFX.get(type, {})
	return data.get("color", Color(0.2, 0.9, 0.4))


# ---------------------------------------------------------------------------
# Awakening VFX
# ---------------------------------------------------------------------------

const AWAKENING_VFX_BASE := "res://assets/vfx/awakening/"

const AWAKENING_VFX: Dictionary = {
	"burst": {texture = "awakening_burst.png", size = Vector2(150, 150), color = Color(1.0, 0.9, 0.5)},
}

static func load_awakening_vfx() -> Texture2D:
	var key := "awakening:burst"
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = AWAKENING_VFX["burst"]
	var path: String = AWAKENING_VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[key] = tex
		return tex
	return null

static func get_awakening_vfx_size() -> Vector2:
	return AWAKENING_VFX["burst"].get("size", Vector2(150, 150))

static func get_awakening_vfx_color() -> Color:
	return AWAKENING_VFX["burst"].get("color", Color(1.0, 0.9, 0.5))


# ---------------------------------------------------------------------------
# Combo VFX
# ---------------------------------------------------------------------------

const COMBO_VFX_BASE := "res://assets/vfx/combo/"

const COMBO_VFX: Dictionary = {
	0: {texture = "combo_sakura_snow.png",  size = Vector2(300, 200), color = Color(1.0, 0.6, 0.8),  name = "桜雪双舞"},
	1: {texture = "combo_holy_strike.png",  size = Vector2(300, 200), color = Color(1.0, 0.85, 0.3), name = "聖盾連撃"},
	2: {texture = "combo_star_moon.png",    size = Vector2(300, 200), color = Color(0.7, 0.8, 1.0),  name = "星月交輝"},
	3: {texture = "combo_red_shadow.png",   size = Vector2(300, 200), color = Color(1.0, 0.3, 0.2),  name = "紅影疾風"},
	4: {texture = "combo_sage_flame.png",   size = Vector2(300, 200), color = Color(0.6, 0.2, 1.0),  name = "賢者炎獄"},
	5: {texture = "combo_spacetime.png",    size = Vector2(300, 200), color = Color(0.6, 0.2, 1.0),  name = "時空魔導"},
	6: {texture = "combo_dual_shadow.png",  size = Vector2(300, 200), color = Color(0.2, 0.6, 0.3),  name = "双影暗殺"},
	7: {texture = "combo_holy_prayer.png",  size = Vector2(300, 200), color = Color(1.0, 0.9, 0.5),  name = "聖光祈禱"},
	8: {texture = "combo_barbarian.png",    size = Vector2(300, 200), color = Color(0.8, 0.1, 0.0),  name = "蛮族双壁"},
	9: {texture = "combo_sea_storm.png",    size = Vector2(300, 200), color = Color(0.1, 0.3, 0.7),  name = "海嵐共鳴"},
}

static func load_combo_vfx(combo_index: int) -> Texture2D:
	var key := "combo:" + str(combo_index)
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = COMBO_VFX.get(combo_index, {})
	if data.is_empty():
		return null
	var path: String = COMBO_VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[key] = tex
		return tex
	return null

static func get_combo_vfx_size(combo_index: int) -> Vector2:
	var data: Dictionary = COMBO_VFX.get(combo_index, {})
	return data.get("size", Vector2(300, 200))

static func get_combo_vfx_color(combo_index: int) -> Color:
	var data: Dictionary = COMBO_VFX.get(combo_index, {})
	return data.get("color", Color.WHITE)

static func get_combo_vfx_name(combo_index: int) -> String:
	var data: Dictionary = COMBO_VFX.get(combo_index, {})
	return data.get("name", "")


# ---------------------------------------------------------------------------
# Passive VFX
# ---------------------------------------------------------------------------

const PASSIVE_VFX_BASE := "res://assets/vfx/passive/"

const PASSIVE_VFX: Dictionary = {
	"regen":        {texture = "regen_pulse.png",   size = Vector2(80, 80),  color = Color(0.2, 0.9, 0.4)},
	"bloodlust":    {texture = "bloodlust.png",     size = Vector2(90, 90),  color = Color(0.9, 0.0, 0.0)},
	"charge":       {texture = "charge_rush.png",   size = Vector2(100, 80), color = Color(0.9, 0.7, 0.2)},
	"eagle_eye":    {texture = "eagle_eye.png",     size = Vector2(80, 80),  color = Color(0.2, 0.8, 0.9)},
	"iron_defense": {texture = "iron_defense.png",  size = Vector2(90, 90),  color = Color(0.5, 0.5, 0.6)},
}

static func load_passive_vfx(type: String) -> Texture2D:
	var key := "passive:" + type
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = PASSIVE_VFX.get(type, {})
	if data.is_empty():
		return null
	var path: String = PASSIVE_VFX_BASE + data["texture"]
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_cache[key] = tex
		return tex
	return null

static func get_passive_vfx_size(type: String) -> Vector2:
	var data: Dictionary = PASSIVE_VFX.get(type, {})
	return data.get("size", Vector2(80, 80))

static func get_passive_vfx_color(type: String) -> Color:
	var data: Dictionary = PASSIVE_VFX.get(type, {})
	return data.get("color", Color.WHITE)
