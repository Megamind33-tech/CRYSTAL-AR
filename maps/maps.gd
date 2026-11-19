class_name Maps
extends RefCounted
## Map registry. A map is a gameplay scene (collision + spawn_points(); all
## the dedicated server loads) and a presentation scene (meshes, lights,
## baked lightmap; clients only), PLAN §3.1.

const DEFAULT := "station"
## Maps offered in the menu, in order.
const PLAYABLE := ["station", "spire", "foundry"]
const LIST := {
	"station": {
		"name": "MAP_STATION",
		"blurb": "MAP_STATION_BLURB",
		"thumb": "res://ui/maps/station.png",
		"gameplay": "res://maps/station/gameplay.tscn",
		"presentation": "res://maps/station/presentation.tscn",
		"exposure": 0.85,  ## MapDetail: tonemap exposure
	},
	"spire": {
		"name": "MAP_SPIRE",
		"blurb": "MAP_SPIRE_BLURB",
		"thumb": "res://ui/maps/spire.png",
		"gameplay": "res://maps/spire/gameplay.tscn",
		"presentation": "res://maps/spire/presentation.tscn",
		"exposure": 1.35,  ## MapDetail: tonemap exposure
	},
	"foundry": {
		"name": "MAP_FOUNDRY",
		"blurb": "MAP_FOUNDRY_BLURB",
		"thumb": "res://ui/maps/foundry.png",
		"gameplay": "res://maps/foundry/gameplay.tscn",
		"presentation": "res://maps/foundry/presentation.tscn",
		"exposure": 1.3,  ## MapDetail: tonemap exposure
	},
	"hunt": {
		"name": "MAP_HUNT",
		"blurb": "MAP_HUNT_BLURB",
		"thumb": "res://ui/maps/foundry.png",
		"gameplay": "res://maps/hunt/gameplay.tscn",
		"presentation": "res://maps/hunt/presentation.tscn",
		"exposure": 1.0,  ## MapDetail: tonemap exposure
	},
	"city": {
		"name": "MAP_CITY",
		"blurb": "MAP_CITY_BLURB",
		"thumb": "res://ui/maps/foundry.png",
		"gameplay": "res://maps/world/gameplay.tscn",
		"presentation": "res://maps/world/presentation.tscn",
		"exposure": 1.0,  ## MapDetail: tonemap exposure
	},
	"test_arena": {
		"name": "MAP_TEST_ARENA",
		"gameplay": "res://maps/test_arena/gameplay.tscn",
		"presentation": "res://maps/test_arena/presentation.tscn",
	},
}


## THE HUNT online: "city@<site>" is the valley map with the battleground a
## networked run is fought at (Battlegrounds), so clients load the same one.
const SITE_SEP := "@"


static func has(id: String) -> bool:
	return LIST.has(base(id)) and (site_of(id).is_empty() or site_of(id) in Battlegrounds.IDS)


## The map part of an id ("city@crater" -> "city").
static func base(id: String) -> String:
	return id.get_slice(SITE_SEP, 0)


## The battleground part ("" for none).
static func site_of(id: String) -> String:
	return id.get_slice(SITE_SEP, 1) if id.contains(SITE_SEP) else ""


static func with_site(map: String, site: String) -> String:
	return map + SITE_SEP + site


static func gameplay(id: String) -> Node3D:
	return (load(LIST[base(id)].gameplay) as PackedScene).instantiate()


static func presentation(id: String) -> Node3D:
	return (load(LIST[base(id)].presentation) as PackedScene).instantiate()


## `--map ID` from the command line if valid, else `fallback` (if valid),
## else DEFAULT.
static func from_args(fallback: String = DEFAULT) -> String:
	var id := Platform.get_user_arg("--map", fallback)
	return id if has(id) else DEFAULT
