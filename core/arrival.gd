class_name Arrival
extends RefCounted
## Arriving on Titan: register, pick a nation (its flag), land in that
## nation's colony, then work with the government or freelance.
##
## Career state (Career.d): reg {done, name, body}, nation (id), arrived
## (bool: the colony landing happened), path ("" | "government" | "freelance").

const PATHS := ["government", "freelance"]

## Each nation's colony: a district of the open world.
static func colony_centre(nation: int) -> Vector2:
	match nation:
		0: return WorldLayout.HELIOS      # Aurora
		1: return WorldLayout.GALLERIA    # Meridian
		2: return WorldLayout.TERRACE     # Vesper
		3: return WorldLayout.SKYPORT     # Halden
	return Vector2(-220, 20)              # no nation: the city hub


static func colony_id(nation: int) -> String:
	return ["helios", "galleria", "terrace", "skyport"][nation] if nation >= 0 and nation < 4 else "city"


## Where to land in the colony: just off its centre, on the ground.
static func spawn(nation: int) -> Vector3:
	var c := colony_centre(nation) + Vector2(6, 6)
	return Vector3(c.x, WorldTerrain.height(c.x, c.y) + 0.3, c.y)


## The landing for the next city start, or INF when none is due.
static func pending_spawn(career: Career) -> Vector3:
	if career.nation() == Nations.NONE or bool(career.d.arrived):
		return Vector3.INF
	return spawn(career.nation())


## Choices still owed on arrival: "register", "nation", "path" or "".
static func next_step(career: Career) -> String:
	if not career.registered():
		return "register"
	if career.nation() == Nations.NONE:
		return "nation"
	if career.path() == "":
		return "path"
	return ""
