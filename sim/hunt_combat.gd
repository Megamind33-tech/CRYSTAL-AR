class_name HuntCombat
extends RefCounted
## THE HUNT's combat profile: grittier than the arena modes. A process-wide
## switch like WeaponSim.limited_ammo: the server applies it when a hunt
## starts and every other mode puts the shipped values back. Rules stay
## identical for humans and bots (they read the same data).
##   - Armour (the shield) is smaller and doesn't recharge; health recovers
##     slowly, only well after the last hit.
##   - Guns hit harder and fire slower, kick harder and spread more; moving
##     and jumping widen the spread, crouching tightens it (WeaponSim).

const PLAYER_VALUES := {
	"max_shield": 50.0,
	"shield_regen_per_second": 0.0,
	"health_regen_per_second": 2.5,
	"health_delay_ticks": 480,
	"spawn_protection_ticks": 120,
}
## Multipliers for every hitscan gun (not melee, grenades or launchers).
const GUN_SCALE := {
	"damage": 1.6,
	"ticks_between_shots": 1.35,
	"spread_degrees": 1.4,
	"recoil_kick_degrees": 1.8,
	"recoil_side_degrees": 2.0,
	"recoil_max_degrees": 1.6,
	"recoil_recovery_degrees_per_second": 0.8,
}
## Extra spread (degrees) at a run, scaled by speed; doubled in the air.
const MOVE_SPREAD := 2.2
const CROUCH_SPREAD := 0.65

static var active: bool = false
static var _player_defaults: Dictionary = {}
static var _gun_defaults: Dictionary = {}  ## weapon id -> {property: value}


static func apply(on: bool) -> void:
	if _player_defaults.is_empty():
		for k: String in PLAYER_VALUES:
			_player_defaults[k] = Balance.PLAYER.get(k)
		for w: WeaponData in Weapons.ALL:
			if _is_gun(w):
				var d := {}
				for k: String in GUN_SCALE:
					d[k] = w.get(k)
				_gun_defaults[w.id] = d
	active = on
	for k: String in PLAYER_VALUES:
		Balance.PLAYER.set(k, PLAYER_VALUES[k] if on else _player_defaults[k])
	for w: WeaponData in Weapons.ALL:
		if not _gun_defaults.has(w.id):
			continue
		var d: Dictionary = _gun_defaults[w.id]
		for k: String in GUN_SCALE:
			var v: Variant = d[k]
			if on:
				v = maxi(roundi(float(v) * GUN_SCALE[k]), 1) if v is int else float(v) * GUN_SCALE[k]
			w.set(k, v)
	WeaponSim.move_spread = MOVE_SPREAD if on else 0.0
	WeaponSim.crouch_spread = CROUCH_SPREAD if on else 1.0


static func _is_gun(w: WeaponData) -> bool:
	return w.id != &"melee" and w.id != &"frag_grenade" and w.id != &"arc_launcher" and w.pellets >= 1
