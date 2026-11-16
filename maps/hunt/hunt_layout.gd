class_name HuntLayout
extends RefCounted
## THE HUNT's map, "Rustwood Yard": a 150 × 150 m salvage yard on a frontier
## moon, built only from existing assets (box geometry plus the CC0
## Quaternius sci-fi kit props the other maps use). Both the gameplay scene
## (collision) and the presentation scene (meshes) are generated from this
## data, so they can never disagree; the navmesh is baked from the collision
## at runtime (BotNavigation), so bots need no hand-placed data.
##
## Layout (top view, -Z is north): a walled vault in the middle holds the
## grand treasure, its south door watched by the alarm trap; eight roofless
## salvage sheds stand on a ring around it, doors facing the vault; crates
## and low walls give cover in the open; three extraction pads sit near the
## edges (north-west, north-east, south). Floor top is y = 0.

enum Kind { FLOOR, WALL, BOUND, COVER, PROP, VAULT_WALL, PAD, TRIM }

const HALF := 75.0  ## the play area is 2 × HALF square
const WALL_HEIGHT := 4.0
const SHED_SIZE := 10.0
const VAULT_HALF := 9.0
const DOOR := 3.4  ## door gaps: wide enough for the bot agent radius
## Kit prop footprints (from SpireLayout), drawn as crates of that size.
const PROP_SIZES := SpireLayout.PROP_SIZES


static func has_collision(kind: int) -> bool:
	return kind != Kind.PAD and kind != Kind.TRIM


## Shed centres and the side their door faces (towards the vault).
static func sheds() -> Array:
	var out := []
	for i in 8:
		var a := i * TAU / 8.0
		var r := 42.0 if i % 2 == 0 else 44.0
		var c := Vector3(snappedf(sin(a) * r, 0.5), 0, snappedf(-cos(a) * r, 0.5))
		var to := -c
		var door := Vector3(signf(to.x), 0, 0) if absf(to.x) > absf(to.z) else Vector3(0, 0, signf(to.z))
		out.append([c, door])
	return out


## Each box: [kind, centre, size].
static func boxes() -> Array:
	var out := [
		[Kind.FLOOR, Vector3(0, -0.5, 0), Vector3(HALF * 2 + 6, 1, HALF * 2 + 6)],
	]
	# Perimeter: a visible fence wall and a tall invisible bound behind it.
	for s in [-1.0, 1.0]:
		out.append([Kind.WALL, Vector3(0, WALL_HEIGHT * 0.5, (HALF + 0.25) * s), Vector3(HALF * 2 + 1, WALL_HEIGHT, 0.5)])
		out.append([Kind.WALL, Vector3((HALF + 0.25) * s, WALL_HEIGHT * 0.5, 0), Vector3(0.5, WALL_HEIGHT, HALF * 2 + 1)])
		out.append([Kind.BOUND, Vector3(0, 15, (HALF + 1.5) * s), Vector3(HALF * 2 + 6, 30, 1)])
		out.append([Kind.BOUND, Vector3((HALF + 1.5) * s, 15, 0), Vector3(1, 30, HALF * 2 + 6)])
	# The vault: doors north and south.
	out.append_array(_walled(Vector3.ZERO, VAULT_HALF * 2, VAULT_HALF * 2, [Vector3(0, 0, -1), Vector3(0, 0, 1)],
			Kind.VAULT_WALL))
	# Salvage sheds.
	for s in sheds():
		out.append_array(_walled(s[0], SHED_SIZE, SHED_SIZE, [s[1]], Kind.WALL))
	# Low cover walls in the open (waist high: crouch behind them).
	for c in covers():
		out.append([Kind.COVER, c[0] + Vector3(0, 0.6, 0), c[1]])
	for p in props():
		var size: Vector3 = PROP_SIZES[p[0]]
		if absf(fmod(p[2], 180.0)) > 45.0:
			size = Vector3(size.z, size.y, size.x)
		out.append([Kind.PROP, p[1] + Vector3(0, size.y * 0.5, 0), size])
	# Extraction pads (visual) and glowing trims along the vault.
	for z in extraction_zones():
		out.append([Kind.PAD, z + Vector3(0, 0.03, 0), Vector3(7, 0.06, 7)])
	for s in [-1.0, 1.0]:
		out.append([Kind.TRIM, Vector3(0, WALL_HEIGHT + 0.05, VAULT_HALF * s), Vector3(VAULT_HALF * 2, 0.1, 0.6)])
	return out


## Four walls around `center` (w along X, d along Z), with a door gap in
## each side whose outward direction is in `doors`.
static func _walled(center: Vector3, w: float, d: float, doors: Array, kind: int) -> Array:
	var out := []
	var y := WALL_HEIGHT * 0.5
	var t := 0.5
	for side in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
		var along_x: bool = side.z != 0
		var length: float = w if along_x else d
		var mid: Vector3 = center + Vector3(side.x * (w * 0.5), y, side.z * (d * 0.5))
		var has_door := false
		for dd in doors:
			has_door = has_door or dd == side
		if not has_door:
			out.append([kind, mid, Vector3(length + t, WALL_HEIGHT, t) if along_x else Vector3(t, WALL_HEIGHT, length + t)])
			continue
		var piece: float = (length - DOOR) * 0.5
		for s in [-1.0, 1.0]:
			var off: float = (DOOR * 0.5 + piece * 0.5) * s
			var at: Vector3 = mid + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
			out.append([kind, at, Vector3(piece + t * 0.5, WALL_HEIGHT, t) if along_x else Vector3(t, WALL_HEIGHT, piece + t * 0.5)])
	return out


## Low cover walls: [floor centre, size].
static func covers() -> Array:
	var out := []
	for i in 12:
		var a := i * TAU / 12.0 + 0.26
		var c := Vector3(snappedf(sin(a) * 24.0, 0.5), 0, snappedf(-cos(a) * 24.0, 0.5))
		var tangent := absf(cos(a)) > absf(sin(a))
		out.append([c, Vector3(4, 1.2, 0.5) if tangent else Vector3(0.5, 1.2, 4)])
	for i in 8:
		var a := i * TAU / 8.0 + TAU / 16.0
		var c := Vector3(snappedf(sin(a) * 58.0, 0.5), 0, snappedf(-cos(a) * 58.0, 0.5))
		out.append([c, Vector3(5, 1.2, 0.5) if i % 2 == 0 else Vector3(0.5, 1.2, 5)])
	return out


## Cover props: [model, position on the floor, yaw degrees].
static func props() -> Array:
	var models := ["essentials/Prop_Crate_Large", "essentials/Prop_Crate", "essentials/Prop_Crate_Tarp_Large",
			"megakit/Prop_Barrel_Large", "megakit/Prop_Crate4"]
	var out := []
	for i in 16:
		var a := i * TAU / 16.0 + 0.13
		var r := 33.0 if i % 2 == 0 else 52.0
		var p := Vector3(snappedf(sin(a) * r, 0.5), 0, snappedf(-cos(a) * r, 0.5))
		out.append([models[i % models.size()], p, 90.0 if i % 3 == 0 else 0.0])
	# The vault's inner cover, either side of the plinth.
	out.append(["essentials/Prop_Crate_Large", Vector3(-5.5, 0, -2), 90.0])
	out.append(["essentials/Prop_Crate_Large", Vector3(5.5, 0, 2), 90.0])
	return out


## Where personal assignments can be placed: inside every shed and at
## open-ground caches.
static func treasure_spots() -> Array:
	var out: Array[Vector3] = []
	for s in sheds():
		out.append(s[0] - s[1] * 2.0)  # the back half of the shed, away from the door
	for i in 8:
		var a := i * TAU / 8.0 + TAU / 16.0
		out.append(Vector3(snappedf(sin(a) * 64.0, 0.5), 0, snappedf(-cos(a) * 64.0, 0.5)))
	return out


static func vault() -> Vector3:
	return Vector3.ZERO


## The alarm trap: just inside the vault's south door.
static func trap() -> Vector3:
	return Vector3(0, 0, VAULT_HALF - 2.5)


static func extraction_zones() -> Array:
	return [Vector3(-62, 0, -62), Vector3(62, 0, -62), Vector3(0, 0, 66)]


static func spawn_points() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i in 12:
		var a := i * TAU / 12.0 + TAU / 24.0
		var p := Vector3(snappedf(sin(a) * 68.0, 0.5), 0.05, snappedf(-cos(a) * 68.0, 0.5))
		var near_zone := false
		for z in extraction_zones():
			near_zone = near_zone or Vector2(p.x - z.x, p.z - z.z).length() < 12.0
		if near_zone:
			p = p * 0.86
			p.y = 0.05
		# Face the vault.
		out.append(Transform3D(Basis(Vector3.UP, atan2(p.x, p.z)), p))
	return out


## Weapon pickups (PLAN §2.3): power weapons near the vault, pistol ammo
## caches out in the yard, grenades on the ring.
static func pickup_spots() -> Array:
	var out := [
		{"weapon": &"rail_sniper", "position": Vector3(0, 0, -30), "respawn_ticks": 7200},
		{"weapon": &"arc_launcher", "position": Vector3(0, 0, 30), "respawn_ticks": 5400},
	]
	for s in [-1.0, 1.0]:
		out.append({"weapon": &"grenade", "position": Vector3(18 * s, 0, 0), "respawn_ticks": 1800})
		out.append({"weapon": &"mag_pistol", "position": Vector3(48 * s, 0, 48 * s), "respawn_ticks": 2400})
		out.append({"weapon": &"pulse_rifle", "position": Vector3(48 * s, 0, -48 * s), "respawn_ticks": 2400})
	return out


static func hunt_data() -> Dictionary:
	return {
		"treasure_spots": treasure_spots(),
		"extraction_zones": extraction_zones(),
		"vault": vault(),
		"trap": trap(),
	}
