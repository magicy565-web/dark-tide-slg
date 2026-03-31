## skill_animation_data.gd — Animation metadata for skills and combos (技能动画数据)
## Provides VFX type definitions, screen shake parameters, camera zoom configs,
## and combo chain animation data for BattleSpriteAnimator consumers.
class_name SkillAnimationData
extends RefCounted

# ─── VFX Type IDs ─────────────────────────────────────────────────────────────

enum VfxType {
	NONE,
	SLASH,
	FIRE,
	ICE,
	LIGHTNING,
	HEAL,
	DARK,
	HOLY,
	WIND,
	EARTH,
	WATER,
	POISON,
	EXPLOSION,
	BUFF_AURA,
	DEBUFF_AURA,
}

const VFX_NAMES: Dictionary = {
	VfxType.NONE: "none",
	VfxType.SLASH: "slash",
	VfxType.FIRE: "fire",
	VfxType.ICE: "ice",
	VfxType.LIGHTNING: "lightning",
	VfxType.HEAL: "heal",
	VfxType.DARK: "dark",
	VfxType.HOLY: "holy",
	VfxType.WIND: "wind",
	VfxType.EARTH: "earth",
	VfxType.WATER: "water",
	VfxType.POISON: "poison",
	VfxType.EXPLOSION: "explosion",
	VfxType.BUFF_AURA: "buff_aura",
	VfxType.DEBUFF_AURA: "debuff_aura",
}

const VFX_NAMES_CN: Dictionary = {
	VfxType.NONE: "无",
	VfxType.SLASH: "斩击",
	VfxType.FIRE: "火焰",
	VfxType.ICE: "冰霜",
	VfxType.LIGHTNING: "雷电",
	VfxType.HEAL: "治愈",
	VfxType.DARK: "暗黑",
	VfxType.HOLY: "神圣",
	VfxType.WIND: "风",
	VfxType.EARTH: "土",
	VfxType.WATER: "水",
	VfxType.POISON: "毒",
	VfxType.EXPLOSION: "爆炸",
	VfxType.BUFF_AURA: "增益光环",
	VfxType.DEBUFF_AURA: "减益光环",
}

## VFX color palette — used by BattleSpriteAnimator.play_skill(color)
const VFX_COLORS: Dictionary = {
	VfxType.NONE: Color.WHITE,
	VfxType.SLASH: Color(0.9, 0.9, 1.0),
	VfxType.FIRE: Color(1.0, 0.4, 0.1),
	VfxType.ICE: Color(0.3, 0.7, 1.0),
	VfxType.LIGHTNING: Color(1.0, 1.0, 0.3),
	VfxType.HEAL: Color(0.3, 1.0, 0.5),
	VfxType.DARK: Color(0.5, 0.1, 0.6),
	VfxType.HOLY: Color(1.0, 0.95, 0.6),
	VfxType.WIND: Color(0.6, 0.9, 0.6),
	VfxType.EARTH: Color(0.7, 0.5, 0.2),
	VfxType.WATER: Color(0.2, 0.5, 0.9),
	VfxType.POISON: Color(0.4, 0.8, 0.2),
	VfxType.EXPLOSION: Color(1.0, 0.6, 0.1),
	VfxType.BUFF_AURA: Color(0.3, 0.6, 1.0),
	VfxType.DEBUFF_AURA: Color(0.8, 0.2, 0.3),
}


# ─── Skill Tier (determines screen shake / camera zoom) ──────────────────────

enum SkillTier {
	BASIC,      # Normal attacks, minor skills
	ADVANCED,   # Mid-tier skills, formation triggers
	ELITE,      # Powerful hero skills
	ULTIMATE,   # Ultimate / awakening skills
	COMBO,      # Tactical combo triggers
}


# ─── Screen Shake Configuration ──────────────────────────────────────────────

## Per-tier screen shake: { intensity: float (pixels), duration: float (seconds) }
const SCREEN_SHAKE: Dictionary = {
	SkillTier.BASIC: {"intensity": 2.0, "duration": 0.1},
	SkillTier.ADVANCED: {"intensity": 4.0, "duration": 0.2},
	SkillTier.ELITE: {"intensity": 6.0, "duration": 0.3},
	SkillTier.ULTIMATE: {"intensity": 10.0, "duration": 0.5},
	SkillTier.COMBO: {"intensity": 8.0, "duration": 0.4},
}


# ─── Camera Zoom Configuration ───────────────────────────────────────────────

## Per-tier camera zoom for dramatic effect.
## zoom_level: target zoom (1.0 = normal, 1.3 = closer)
## duration: total zoom in + hold + zoom out time
## hold_time: how long to stay zoomed
## Only ELITE and above trigger camera zoom.
const CAMERA_ZOOM: Dictionary = {
	SkillTier.BASIC: {"enabled": false, "zoom_level": 1.0, "duration": 0.0, "hold_time": 0.0},
	SkillTier.ADVANCED: {"enabled": false, "zoom_level": 1.0, "duration": 0.0, "hold_time": 0.0},
	SkillTier.ELITE: {"enabled": true, "zoom_level": 1.15, "duration": 0.6, "hold_time": 0.2},
	SkillTier.ULTIMATE: {"enabled": true, "zoom_level": 1.35, "duration": 1.0, "hold_time": 0.4},
	SkillTier.COMBO: {"enabled": true, "zoom_level": 1.2, "duration": 0.8, "hold_time": 0.3},
}


# ─── Per-Skill VFX Definitions ───────────────────────────────────────────────
# Maps skill_id -> animation config dictionary.
# Keys: vfx_type, tier, particle_count, flash_color_override (optional),
#        hit_count (for multi-hit), aoe (bool), aoe_radius (pixels)

const SKILL_VFX: Dictionary = {
	# ── Basic attack types ──
	"melee_attack": {
		"vfx_type": VfxType.SLASH,
		"tier": SkillTier.BASIC,
		"particle_count": 4,
		"hit_count": 1,
		"aoe": false,
	},
	"ranged_attack": {
		"vfx_type": VfxType.WIND,
		"tier": SkillTier.BASIC,
		"particle_count": 3,
		"hit_count": 1,
		"aoe": false,
	},
	"cavalry_charge": {
		"vfx_type": VfxType.EARTH,
		"tier": SkillTier.ADVANCED,
		"particle_count": 8,
		"hit_count": 1,
		"aoe": false,
	},

	# ── Mage skills ──
	"fireball": {
		"vfx_type": VfxType.FIRE,
		"tier": SkillTier.ADVANCED,
		"particle_count": 10,
		"hit_count": 1,
		"aoe": true,
		"aoe_radius": 60.0,
	},
	"ice_storm": {
		"vfx_type": VfxType.ICE,
		"tier": SkillTier.ELITE,
		"particle_count": 14,
		"hit_count": 3,
		"aoe": true,
		"aoe_radius": 80.0,
	},
	"lightning_bolt": {
		"vfx_type": VfxType.LIGHTNING,
		"tier": SkillTier.ADVANCED,
		"particle_count": 8,
		"hit_count": 1,
		"aoe": false,
	},
	"chain_lightning": {
		"vfx_type": VfxType.LIGHTNING,
		"tier": SkillTier.ELITE,
		"particle_count": 12,
		"hit_count": 4,
		"aoe": true,
		"aoe_radius": 100.0,
	},
	"meteor_storm": {
		"vfx_type": VfxType.FIRE,
		"tier": SkillTier.ULTIMATE,
		"particle_count": 20,
		"hit_count": 5,
		"aoe": true,
		"aoe_radius": 120.0,
		"flash_color_override": Color(1.0, 0.3, 0.0),
	},

	# ── Priest / Holy skills ──
	"heal": {
		"vfx_type": VfxType.HEAL,
		"tier": SkillTier.BASIC,
		"particle_count": 6,
		"hit_count": 1,
		"aoe": false,
	},
	"mass_heal": {
		"vfx_type": VfxType.HEAL,
		"tier": SkillTier.ADVANCED,
		"particle_count": 10,
		"hit_count": 1,
		"aoe": true,
		"aoe_radius": 80.0,
	},
	"divine_judgment": {
		"vfx_type": VfxType.HOLY,
		"tier": SkillTier.ULTIMATE,
		"particle_count": 18,
		"hit_count": 3,
		"aoe": true,
		"aoe_radius": 100.0,
		"flash_color_override": Color(1.0, 1.0, 0.8),
	},
	"holy_shield": {
		"vfx_type": VfxType.HOLY,
		"tier": SkillTier.ADVANCED,
		"particle_count": 8,
		"hit_count": 1,
		"aoe": false,
	},

	# ── Dark / Assassination skills ──
	"shadow_strike": {
		"vfx_type": VfxType.DARK,
		"tier": SkillTier.ADVANCED,
		"particle_count": 8,
		"hit_count": 2,
		"aoe": false,
	},
	"dark_nova": {
		"vfx_type": VfxType.DARK,
		"tier": SkillTier.ULTIMATE,
		"particle_count": 16,
		"hit_count": 4,
		"aoe": true,
		"aoe_radius": 90.0,
		"flash_color_override": Color(0.4, 0.0, 0.5),
	},
	"assassinate": {
		"vfx_type": VfxType.DARK,
		"tier": SkillTier.ELITE,
		"particle_count": 6,
		"hit_count": 1,
		"aoe": false,
	},
	"poison_blade": {
		"vfx_type": VfxType.POISON,
		"tier": SkillTier.BASIC,
		"particle_count": 5,
		"hit_count": 1,
		"aoe": false,
	},

	# ── Cannon / Artillery skills ──
	"cannon_shot": {
		"vfx_type": VfxType.EXPLOSION,
		"tier": SkillTier.ADVANCED,
		"particle_count": 10,
		"hit_count": 1,
		"aoe": true,
		"aoe_radius": 50.0,
	},
	"bombardment": {
		"vfx_type": VfxType.EXPLOSION,
		"tier": SkillTier.ELITE,
		"particle_count": 16,
		"hit_count": 3,
		"aoe": true,
		"aoe_radius": 90.0,
	},

	# ── Samurai / Warrior skills ──
	"iaijutsu": {
		"vfx_type": VfxType.SLASH,
		"tier": SkillTier.ELITE,
		"particle_count": 10,
		"hit_count": 3,
		"aoe": false,
		"flash_color_override": Color(0.9, 0.95, 1.0),
	},
	"war_cry": {
		"vfx_type": VfxType.BUFF_AURA,
		"tier": SkillTier.ADVANCED,
		"particle_count": 8,
		"hit_count": 1,
		"aoe": true,
		"aoe_radius": 70.0,
	},

	# ── Orc / Berserker skills ──
	"frenzy": {
		"vfx_type": VfxType.FIRE,
		"tier": SkillTier.ADVANCED,
		"particle_count": 8,
		"hit_count": 1,
		"aoe": false,
		"flash_color_override": Color(0.9, 0.2, 0.1),
	},
	"waaagh": {
		"vfx_type": VfxType.EARTH,
		"tier": SkillTier.ULTIMATE,
		"particle_count": 20,
		"hit_count": 1,
		"aoe": true,
		"aoe_radius": 110.0,
		"flash_color_override": Color(0.2, 0.8, 0.1),
	},
}


# ─── Combo Animation Chain Data ──────────────────────────────────────────────
# Maps combo_id (from FormationSystem) to animation chain sequences.
# Each entry: Array of hit_step dicts played in order.
# hit_step: { vfx_type, delay_before (sec), target ("all_enemies"/"single"/"all_allies"),
#              particle_count, flash_color, screen_shake_mult }

const COMBO_ANIMATIONS: Dictionary = {
	"PINCER_ATTACK": {
		"tier": SkillTier.COMBO,
		"name_cn": "夹击",
		"hit_chain": [
			{"vfx_type": VfxType.SLASH, "delay_before": 0.0, "target": "single", "particle_count": 6, "flash_color": Color(0.9, 0.9, 1.0), "screen_shake_mult": 0.8},
			{"vfx_type": VfxType.WIND, "delay_before": 0.15, "target": "single", "particle_count": 5, "flash_color": Color(0.7, 0.85, 1.0), "screen_shake_mult": 1.0},
		],
	},
	"DESPERATE_STAND": {
		"tier": SkillTier.COMBO,
		"name_cn": "背水一战",
		"hit_chain": [
			{"vfx_type": VfxType.BUFF_AURA, "delay_before": 0.0, "target": "all_allies", "particle_count": 12, "flash_color": Color(1.0, 0.3, 0.3), "screen_shake_mult": 1.2},
		],
	},
	"COMMANDER_DUEL": {
		"tier": SkillTier.COMBO,
		"name_cn": "大将单挑",
		"hit_chain": [
			{"vfx_type": VfxType.SLASH, "delay_before": 0.0, "target": "single", "particle_count": 8, "flash_color": Color(1.0, 0.9, 0.3), "screen_shake_mult": 1.0},
			{"vfx_type": VfxType.SLASH, "delay_before": 0.2, "target": "single", "particle_count": 8, "flash_color": Color(1.0, 0.9, 0.3), "screen_shake_mult": 1.0},
			{"vfx_type": VfxType.SLASH, "delay_before": 0.15, "target": "single", "particle_count": 12, "flash_color": Color(1.0, 1.0, 0.5), "screen_shake_mult": 1.5},
		],
	},
	"CROSS_FIRE": {
		"tier": SkillTier.COMBO,
		"name_cn": "交叉火力",
		"hit_chain": [
			{"vfx_type": VfxType.WIND, "delay_before": 0.0, "target": "all_enemies", "particle_count": 6, "flash_color": Color(0.9, 0.9, 0.7), "screen_shake_mult": 0.6},
			{"vfx_type": VfxType.WIND, "delay_before": 0.1, "target": "all_enemies", "particle_count": 6, "flash_color": Color(0.9, 0.9, 0.7), "screen_shake_mult": 0.6},
			{"vfx_type": VfxType.EXPLOSION, "delay_before": 0.1, "target": "all_enemies", "particle_count": 10, "flash_color": Color(1.0, 0.8, 0.3), "screen_shake_mult": 1.2},
		],
	},
	"SHIELD_BROTHERS": {
		"tier": SkillTier.COMBO,
		"name_cn": "盾墙兄弟",
		"hit_chain": [
			{"vfx_type": VfxType.BUFF_AURA, "delay_before": 0.0, "target": "all_allies", "particle_count": 10, "flash_color": Color(0.5, 0.7, 1.0), "screen_shake_mult": 0.5},
			{"vfx_type": VfxType.HOLY, "delay_before": 0.2, "target": "all_allies", "particle_count": 8, "flash_color": Color(0.7, 0.85, 1.0), "screen_shake_mult": 0.3},
		],
	},
	"DARK_RITUAL": {
		"tier": SkillTier.COMBO,
		"name_cn": "暗黑仪式",
		"hit_chain": [
			{"vfx_type": VfxType.DARK, "delay_before": 0.0, "target": "all_allies", "particle_count": 8, "flash_color": Color(0.4, 0.0, 0.5), "screen_shake_mult": 0.8},
			{"vfx_type": VfxType.DARK, "delay_before": 0.25, "target": "all_allies", "particle_count": 12, "flash_color": Color(0.6, 0.1, 0.7), "screen_shake_mult": 1.0},
			{"vfx_type": VfxType.FIRE, "delay_before": 0.15, "target": "all_allies", "particle_count": 10, "flash_color": Color(0.8, 0.0, 0.2), "screen_shake_mult": 1.3},
		],
	},
	"CAVALRY_SWEEP": {
		"tier": SkillTier.COMBO,
		"name_cn": "骑兵横扫",
		"hit_chain": [
			{"vfx_type": VfxType.EARTH, "delay_before": 0.0, "target": "all_enemies", "particle_count": 10, "flash_color": Color(0.7, 0.5, 0.2), "screen_shake_mult": 1.0},
			{"vfx_type": VfxType.SLASH, "delay_before": 0.12, "target": "all_enemies", "particle_count": 8, "flash_color": Color(0.9, 0.9, 1.0), "screen_shake_mult": 1.5},
		],
	},
	"ARTILLERY_BARRAGE": {
		"tier": SkillTier.COMBO,
		"name_cn": "炮火洗礼",
		"hit_chain": [
			{"vfx_type": VfxType.EXPLOSION, "delay_before": 0.0, "target": "all_enemies", "particle_count": 8, "flash_color": Color(1.0, 0.6, 0.1), "screen_shake_mult": 0.8},
			{"vfx_type": VfxType.EXPLOSION, "delay_before": 0.15, "target": "all_enemies", "particle_count": 10, "flash_color": Color(1.0, 0.5, 0.0), "screen_shake_mult": 1.0},
			{"vfx_type": VfxType.EXPLOSION, "delay_before": 0.12, "target": "all_enemies", "particle_count": 10, "flash_color": Color(1.0, 0.4, 0.0), "screen_shake_mult": 1.2},
			{"vfx_type": VfxType.FIRE, "delay_before": 0.1, "target": "all_enemies", "particle_count": 14, "flash_color": Color(1.0, 0.3, 0.0), "screen_shake_mult": 1.5},
		],
	},
	"ASSASSIN_MARK": {
		"tier": SkillTier.COMBO,
		"name_cn": "暗杀印记",
		"hit_chain": [
			{"vfx_type": VfxType.DARK, "delay_before": 0.0, "target": "single", "particle_count": 6, "flash_color": Color(0.3, 0.0, 0.4), "screen_shake_mult": 0.5},
			{"vfx_type": VfxType.SLASH, "delay_before": 0.2, "target": "single", "particle_count": 10, "flash_color": Color(0.8, 0.1, 0.2), "screen_shake_mult": 1.5},
		],
	},
	"HEROIC_CHARGE": {
		"tier": SkillTier.COMBO,
		"name_cn": "英雄突击",
		"hit_chain": [
			{"vfx_type": VfxType.BUFF_AURA, "delay_before": 0.0, "target": "single", "particle_count": 10, "flash_color": Color(1.0, 0.8, 0.2), "screen_shake_mult": 0.8},
			{"vfx_type": VfxType.FIRE, "delay_before": 0.15, "target": "single", "particle_count": 8, "flash_color": Color(1.0, 0.5, 0.1), "screen_shake_mult": 1.0},
			{"vfx_type": VfxType.SLASH, "delay_before": 0.1, "target": "all_enemies", "particle_count": 14, "flash_color": Color(1.0, 0.9, 0.4), "screen_shake_mult": 2.0},
		],
	},
}


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — Lookup helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Get the full animation config for a skill. Returns empty dict if not found.
static func get_skill_vfx(skill_id: String) -> Dictionary:
	return SKILL_VFX.get(skill_id, {})


## Get the VFX color for a skill (falls back to VfxType color, then white).
static func get_skill_color(skill_id: String) -> Color:
	var cfg: Dictionary = SKILL_VFX.get(skill_id, {})
	if cfg.has("flash_color_override"):
		return cfg["flash_color_override"]
	var vtype: int = cfg.get("vfx_type", VfxType.NONE)
	return VFX_COLORS.get(vtype, Color.WHITE)


## Get screen shake config for a skill tier.
static func get_screen_shake(tier: int) -> Dictionary:
	return SCREEN_SHAKE.get(tier, SCREEN_SHAKE[SkillTier.BASIC])


## Get camera zoom config for a skill tier.
static func get_camera_zoom(tier: int) -> Dictionary:
	return CAMERA_ZOOM.get(tier, CAMERA_ZOOM[SkillTier.BASIC])


## Get combo animation chain for a combo_id. Returns empty dict if not found.
static func get_combo_animation(combo_id: String) -> Dictionary:
	return COMBO_ANIMATIONS.get(combo_id, {})


## Get the hit chain array for a combo. Returns empty array if not found.
static func get_combo_hit_chain(combo_id: String) -> Array:
	var combo: Dictionary = COMBO_ANIMATIONS.get(combo_id, {})
	return combo.get("hit_chain", [])


## Build a full animation descriptor for a skill, ready for BattleSpriteAnimator.
## Returns: { color, particle_count, shake_intensity, shake_duration,
##            zoom_enabled, zoom_level, zoom_duration, zoom_hold,
##            hit_count, aoe, aoe_radius, vfx_type_name }
static func build_skill_anim_descriptor(skill_id: String) -> Dictionary:
	var cfg: Dictionary = SKILL_VFX.get(skill_id, {})
	if cfg.is_empty():
		return _default_descriptor()

	var tier: int = cfg.get("tier", SkillTier.BASIC)
	var shake: Dictionary = get_screen_shake(tier)
	var zoom: Dictionary = get_camera_zoom(tier)
	var vtype: int = cfg.get("vfx_type", VfxType.NONE)

	return {
		"skill_id": skill_id,
		"vfx_type": vtype,
		"vfx_type_name": VFX_NAMES.get(vtype, "none"),
		"color": get_skill_color(skill_id),
		"particle_count": cfg.get("particle_count", 4),
		"hit_count": cfg.get("hit_count", 1),
		"aoe": cfg.get("aoe", false),
		"aoe_radius": cfg.get("aoe_radius", 0.0),
		"shake_intensity": shake.get("intensity", 2.0),
		"shake_duration": shake.get("duration", 0.1),
		"zoom_enabled": zoom.get("enabled", false),
		"zoom_level": zoom.get("zoom_level", 1.0),
		"zoom_duration": zoom.get("duration", 0.0),
		"zoom_hold": zoom.get("hold_time", 0.0),
		"tier": tier,
	}


## Build a full animation descriptor for a combo trigger.
## Returns: { combo_id, name_cn, tier, hit_chain, shake, zoom }
static func build_combo_anim_descriptor(combo_id: String) -> Dictionary:
	var combo: Dictionary = COMBO_ANIMATIONS.get(combo_id, {})
	if combo.is_empty():
		return {"combo_id": combo_id, "hit_chain": [], "tier": SkillTier.BASIC}

	var tier: int = combo.get("tier", SkillTier.COMBO)
	var shake: Dictionary = get_screen_shake(tier)
	var zoom: Dictionary = get_camera_zoom(tier)

	return {
		"combo_id": combo_id,
		"name_cn": combo.get("name_cn", ""),
		"tier": tier,
		"hit_chain": combo.get("hit_chain", []),
		"shake_intensity": shake.get("intensity", 8.0),
		"shake_duration": shake.get("duration", 0.4),
		"zoom_enabled": zoom.get("enabled", false),
		"zoom_level": zoom.get("zoom_level", 1.0),
		"zoom_duration": zoom.get("duration", 0.0),
		"zoom_hold": zoom.get("hold_time", 0.0),
	}


## Emit EventBus signals for a skill animation request.
static func emit_skill_vfx(skill_id: String, source_pos: Vector2, target_pos: Vector2) -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	var desc: Dictionary = build_skill_anim_descriptor(skill_id)
	bus.skill_vfx_requested.emit(skill_id, desc.get("vfx_type_name", "none"), source_pos, target_pos)
	if desc.get("shake_intensity", 0.0) > 0.0:
		bus.screen_shake_requested.emit(desc["shake_intensity"], desc["shake_duration"])
	if desc.get("zoom_enabled", false):
		bus.camera_zoom_requested.emit(desc["zoom_level"], desc["zoom_duration"], target_pos)


## Emit EventBus signals for a combo animation chain.
static func emit_combo_chain(combo_id: String) -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	var chain: Array = get_combo_hit_chain(combo_id)
	bus.combo_chain_anim_requested.emit(combo_id, chain)
	var desc: Dictionary = build_combo_anim_descriptor(combo_id)
	if desc.get("shake_intensity", 0.0) > 0.0:
		bus.screen_shake_requested.emit(desc["shake_intensity"], desc["shake_duration"])
	if desc.get("zoom_enabled", false):
		bus.camera_zoom_requested.emit(desc["zoom_level"], desc["zoom_duration"], Vector2.ZERO)


# ─── Private ──────────────────────────────────────────────────────────────────

static func _default_descriptor() -> Dictionary:
	return {
		"skill_id": "",
		"vfx_type": VfxType.NONE,
		"vfx_type_name": "none",
		"color": Color.WHITE,
		"particle_count": 4,
		"hit_count": 1,
		"aoe": false,
		"aoe_radius": 0.0,
		"shake_intensity": 2.0,
		"shake_duration": 0.1,
		"zoom_enabled": false,
		"zoom_level": 1.0,
		"zoom_duration": 0.0,
		"zoom_hold": 0.0,
		"tier": SkillTier.BASIC,
	}


static func _get_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/EventBus")
