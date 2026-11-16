class_name WorldTerrain
extends RefCounted
## Kasei Valley's terrain height at world (x, z), metres. MUST match
## tools/blender/world_terrain.py, which Blender uses to build the visible
## mesh (maps/world/terrain.glb): the game builds the collision (a height
## map) and places everything on the ground from this copy.

const SIZE := 800.0
const STEP := 4.0
const CITY := [-220.0, 20.0, 14.0, 80.0, 150.0]
const HOLLOW := [60.0, -60.0, 2.0, 52.0, 95.0]
const MESAS := [[-60.0, -230.0, 46.0, 30.0], [255.0, -60.0, 34.0, 24.0], [-310.0, -210.0, 56.0, 34.0],
		[30.0, 250.0, 28.0, 22.0], [-90.0, 200.0, 26.0, 18.0]]
const CRATER := [150.0, -240.0, 58.0]


static func canyon_center(x: float) -> float:
	return 150.0 + 42.0 * sin(x * 0.012)


static func height(x: float, z: float) -> float:
	var h := 6.0 * sin(x * 0.011 + 0.7) * cos(z * 0.009) + 3.0 * sin(x * 0.023 - z * 0.017)
	h += 0.9 * sin(x * 0.09 + sin(z * 0.05) * 2.0) * cos(z * 0.031)
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(300.0, 392.0, edge) * 48.0
	for m: Array in MESAS:
		var d := Vector2(x - m[0], z - m[1]).length()
		h += float(m[3]) * smoothstep(float(m[2]) + 16.0, float(m[2]), d)
	var dc := Vector2(x - CRATER[0], z - CRATER[1]).length()
	var cr: float = CRATER[2]
	h += 9.0 * exp(-pow((dc - cr) / 12.0, 2.0)) - 12.0 * smoothstep(cr, cr * 0.4, dc)
	var dz := absf(z - canyon_center(x))
	var depth := 22.0 * (1.0 - smoothstep(16.0, 40.0, dz)) * smoothstep(40.0, 110.0, x) * (1.0 - smoothstep(360.0, 395.0, x))
	h -= depth
	for s: Array in [CITY, HOLLOW]:
		var d := Vector2(x - s[0], z - s[1]).length()
		h += (float(s[2]) - h) * smoothstep(float(s[4]), float(s[3]), d)
	return h


## A point on the ground.
static func at(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)
