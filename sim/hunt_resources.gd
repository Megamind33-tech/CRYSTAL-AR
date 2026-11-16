class_name HuntResources
extends RefCounted
## THE HUNT's resource types (Resource Dispute): data, not code. A cache of
## a type holds one load; collecting it takes `collect_ticks` (interrupted by
## damage or leaving) and turns it into unsecured cargo, a HuntRules
## treasure of kind RESOURCE worth `points` (and `credits`) once extracted.
## Add a type by adding a row; nothing else changes.

const TYPES := {
	"helium3": {"name_key": "HUNT_RES_HELIUM3", "points": 80, "credits": 60, "collect_ticks": 300},
	"rare_ore": {"name_key": "HUNT_RES_RARE_ORE", "points": 60, "credits": 40, "collect_ticks": 240},
	"water_ice": {"name_key": "HUNT_RES_WATER_ICE", "points": 40, "credits": 30, "collect_ticks": 180},
}
const IDS := ["helium3", "rare_ore", "water_ice"]  ## stable order for seeded picks


static func has(type_id: String) -> bool:
	return TYPES.has(type_id)


static func points(type_id: String) -> int:
	return TYPES[type_id].points


static func credits(type_id: String) -> int:
	return TYPES[type_id].credits


static func collect_ticks(type_id: String) -> int:
	return TYPES[type_id].collect_ticks
