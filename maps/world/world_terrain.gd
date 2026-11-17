class_name WorldTerrain
extends RefCounted
## Kasei Valley's terrain height at world (x, z), metres: the one source
## for the ground. The physics height map, the visible mesh (TerrainMesh)
## and every placement on the ground read it.

## The valley is a hub: Tharsis Gate on its plateau, the districts in a
## ring round it 220-330 m out (each on its own flat, joined by the roads
## in WorldLayout), the mining country east, and the basin's rim beyond.
const SIZE := 1200.0
const STEP := 5.0
const CITY := [-220.0, 20.0, 14.0, 80.0, 150.0]
const HOLLOW := [60.0, -60.0, 2.0, 52.0, 95.0]
## The districts: [x, z, height, flat radius, outer radius].
const HELIOS := [-400.0, -250.0, 18.0, 120.0, 180.0]   # north-west: towers and the ring
const GALLERIA := [-440.0, 60.0, 16.0, 80.0, 130.0]     # west: the Prism Galleria (mall)
const TERRACE := [-170.0, 330.0, 6.0, 105.0, 165.0]     # south: Nova Terrace (homes)
const SKYPORT := [-100.0, -430.0, 10.0, 115.0, 170.0]   # north: Kasei Skyport
## Levelled yards below the city's plateau: Kasei Motors' factory and Joe's
## Respray & Chop (WorldLayout.FACTORY, GARAGE).
const FACTORY_YARD := [-95.0, 28.0, 3.0, 32.0, 60.0]
const GARAGE_YARD := [-176.0, 108.0, 11.0, 16.0, 36.0]
const SITES := [CITY, HOLLOW, HELIOS, GALLERIA, TERRACE, SKYPORT, FACTORY_YARD, GARAGE_YARD]
## Mesas: [x, z, radius, height]. The Anvil (Deep Furrow's lift at its
## foot) and its neighbour north of the city; the rest frame the routes.
const ANVIL := [-180.0, -250.0, 56.0, 34.0]
const MESAS := [[-60.0, -230.0, 46.0, 30.0], [255.0, -60.0, 34.0, 24.0], ANVIL, [30.0, 250.0, 28.0, 22.0],
		[-90.0, 200.0, 26.0, 18.0], [360.0, 80.0, 42.0, 30.0], [420.0, -300.0, 40.0, 32.0], [-300.0, -440.0, 36.0, 28.0],
		[150.0, 440.0, 40.0, 32.0], [450.0, 210.0, 38.0, 30.0], [250.0, -420.0, 42.0, 30.0]]
const CRATER := [150.0, -240.0, 58.0]
const CRATER2 := [-460.0, 330.0, 75.0]


## The height at every grid corner (row j = z, column i = x), computed once:
## the physics height map and the visible mesh (TerrainMesh) both read it.
static var _grid := PackedFloat32Array()


static func cells() -> int:
	return int(SIZE / STEP)


static func grid() -> PackedFloat32Array:
	if _grid.is_empty():
		var n := cells() + 1
		var half := SIZE * 0.5
		_grid.resize(n * n)
		for j in n:
			for i in n:
				_grid[j * n + i] = height(-half + i * STEP, -half + j * STEP)
	return _grid


static func canyon_center(x: float) -> float:
	return 150.0 + 42.0 * sin(x * 0.012)


static func height(x: float, z: float) -> float:
	var h := 6.0 * sin(x * 0.011 + 0.7) * cos(z * 0.009) + 3.0 * sin(x * 0.023 - z * 0.017)
	h += 0.9 * sin(x * 0.09 + sin(z * 0.05) * 2.0) * cos(z * 0.031)
	var edge := maxf(absf(x), absf(z))
	var out := smoothstep(300.0, 420.0, edge)
	h += out * (9.0 * sin(x * 0.0071 + 1.3) * cos(z * 0.0063 - 0.4) + 4.0 * sin(x * 0.017 + z * 0.013))
	h += smoothstep(490.0, 580.0, edge) * 70.0  # the basin's rim
	for m: Array in MESAS:
		var d := Vector2(x - m[0], z - m[1]).length()
		h += float(m[3]) * smoothstep(float(m[2]) + 16.0, float(m[2]), d)
	var dc := Vector2(x - CRATER[0], z - CRATER[1]).length()
	var cr: float = CRATER[2]
	h += 9.0 * exp(-pow((dc - cr) / 12.0, 2.0)) - 12.0 * smoothstep(cr, cr * 0.4, dc)
	var dc2 := Vector2(x - CRATER2[0], z - CRATER2[1]).length()
	var cr2: float = CRATER2[2]
	h += 12.0 * exp(-pow((dc2 - cr2) / 15.0, 2.0)) - 16.0 * smoothstep(cr2, cr2 * 0.4, dc2)
	var dz := absf(z - canyon_center(x))
	var depth := 22.0 * (1.0 - smoothstep(16.0, 40.0, dz)) * smoothstep(40.0, 110.0, x) * (1.0 - smoothstep(360.0, 395.0, x))
	h -= depth
	for s: Array in SITES:
		var d := Vector2(x - s[0], z - s[1]).length()
		h += (float(s[2]) - h) * smoothstep(float(s[4]), float(s[3]), d)
	return h


## A point on the ground as you stand on it and see it: the terrain is a
## grid of STEP-metre cells, each split into two triangles on its
## (i+1, j)-(i, j+1) diagonal, like the physics height map and the mesh.
static func at(x: float, z: float) -> Vector3:
	return Vector3(x, surface(x, z), z)


static func surface(x: float, z: float) -> float:
	var half := SIZE * 0.5
	var gx := (x + half) / STEP
	var gz := (z + half) / STEP
	var i := floorf(gx)
	var j := floorf(gz)
	var fx := gx - i
	var fz := gz - j
	var x0 := -half + i * STEP
	var z0 := -half + j * STEP
	var h10 := height(x0 + STEP, z0)
	var h01 := height(x0, z0 + STEP)
	if fx + fz < 1.0:
		var h00 := height(x0, z0)
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	var h11 := height(x0 + STEP, z0 + STEP)
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)
