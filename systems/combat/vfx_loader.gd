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
