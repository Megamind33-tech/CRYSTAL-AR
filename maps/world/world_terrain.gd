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
## The lift house's yard at the Anvil's foot, the north road through it.
const LIFT_YARD := [-197.0, -169.0, 6.0, 16.0, 34.0]
const SITES := [CITY, HOLLOW, HELIOS, GALLERIA, TERRACE, SKYPORT, FACTORY_YARD, GARAGE_YARD, LIFT_YARD]
## The settlements' flats (the yards are not: a road may cross a yard's edge).
const DISTRICTS := [CITY, HOLLOW, HELIOS, GALLERIA, TERRACE, SKYPORT]
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


## The ground at (x, z): the land (natural) with the road beds cut and
## filled into it. Everything stands on this: the physics, the mesh, the
## vehicles, every placement.
static func height(x: float, z: float) -> float:
	return _road_bed(x, z, natural(x, z))


## The land before the roads: dunes, swells, the rim, mesas, craters, the
## canyon, and the flats the settlements stand on.
static func natural(x: float, z: float) -> float:
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
	# The grid's corners (cached) on the same diagonal as the physics; off
	# the grid, the height function itself.
	var half := SIZE * 0.5
	var gx := (x + half) / STEP
	var gz := (z + half) / STEP
	var i := floori(gx)
	var j := floori(gz)
	var n := cells() + 1
	if i < 0 or j < 0 or i >= n - 1 or j >= n - 1:
		return height(x, z)
	var g := grid()
	var fx := gx - i
	var fz := gz - j
	var h10 := g[j * n + i + 1]
	var h01 := g[(j + 1) * n + i]
	if fx + fz < 1.0:
		var h00 := g[j * n + i]
		return h00 + (h10 - h00) * fx + (h01 - h00) * fz
	var h11 := g[(j + 1) * n + i + 1]
	return h11 + (h01 - h11) * (1.0 - fx) + (h10 - h11) * (1.0 - fz)


# --- Road beds ---------------------------------------------------------
# Each road (WorldLayout.roads) runs on a bed: a profile along it that
# follows the land, smoothed and held to ROAD_GRADE at most (cut into rises,
# built up over dips, the two balanced), ROAD_BED_HALF either side flat
# across, then sloping back to the land. Where a road starts or ends on
# another, it meets that road's bed at the same height.

const ROAD_GRADE := 0.14
const ROAD_BED_HALF := 6.5
const ROAD_SPACING := 4.0  ## metres between profile points
const ROAD_REACH := 45.0   ## the widest an embankment or cutting spreads
const _BUCKET := 32.0
## [a, b, height at a, height at b, road] per stretch of every road's bed.
static var _segs: Array = []
## Bucket (x, z) -> indices into _segs of the stretches that reach it.
static var _buckets: Dictionary = {}
static var _bed_ready := false


static func _road_bed(x: float, z: float, h: float) -> float:
	if not _bed_ready:
		_build_beds()
	var cell := Vector2i(floori(x / _BUCKET), floori(z / _BUCKET))
	if not _buckets.has(cell):
		return h
	var p := Vector2(x, z)
	# The nearest stretch of each road here: road -> [distance, bed height].
	var near := {}
	for i: int in _buckets[cell]:
		var sg: Array = _segs[i]
		var a: Vector2 = sg[0]
		var ab: Vector2 = (sg[1] as Vector2) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		var road: int = sg[4]
		if not near.has(road) or d < float(near[road][0]):
			near[road] = [d, lerpf(sg[2], sg[3], t)]
	# Where roads meet, their beds blend (nearer counts more), so a junction
	# is one surface, not a step where one road's bed gives way to another's.
	var pull := 0.0
	var sum := 0.0
	var wsum := 0.0
	for road: int in near:
		var d: float = near[road][0]
		var bed: float = near[road][1]
		# The bank: a gentle 1 in 3 from the bed's edge back to the land.
		var bank := clampf(absf(h - bed) * 3.0, 4.0, ROAD_REACH)
		var k := smoothstep(ROAD_BED_HALF + bank, ROAD_BED_HALF, d)
		if k <= 0.0:
			continue
		var w := k * k / (d + 4.0)
		sum += bed * w
		wsum += w
		pull = maxf(pull, k)
	if wsum <= 0.0:
		return h
	return lerpf(h, sum / wsum, pull)


static func _build_beds() -> void:
	_bed_ready = true  # natural() never reads the beds: no recursion
	_segs.clear()
	_buckets.clear()
	var roads := WorldLayout.roads()
	for ri in roads.size():
		var road: Array = roads[ri]
		var pts: Array = []
		for sm: Array in WorldLayout.road_samples(road, ROAD_SPACING):
			pts.append(sm[0])
		var n := pts.size()
		if n < 2:
			continue
		var land := PackedFloat32Array()
		land.resize(n)
		for i in n:
			land[i] = natural(pts[i].x, pts[i].y)
		# Smoothed over about 40 m, so the bed doesn't copy every dune.
		var smooth := PackedFloat32Array()
		smooth.resize(n)
		for i in n:
			var sum := 0.0
			var cnt := 0
			for k in range(maxi(i - 5, 0), mini(i + 6, n)):
				sum += land[k]
				cnt += 1
			smooth[i] = sum / cnt
		# Ends that meet a road already laid take its bed's height; the others
		# the land's (a street ends level with its square).
		var pins := {}
		for end: int in [0, n - 1]:
			var at := _bed_at(pts[end])
			pins[end] = at if not is_nan(at) else land[end]
		# A road never changes a settlement's flat: there, its bed is the flat.
		for i in n:
			for site: Array in DISTRICTS:
				if Vector2(pts[i].x - float(site[0]), pts[i].y - float(site[1])).length() < float(site[3]):
					pins[i] = land[i]
					break
		var step := ROAD_SPACING * ROAD_GRADE
		# Cut-only (the highest grade-held line under the land) and fill-only
		# (the lowest over it), both through the pins; the bed is between.
		var cut := _held(smooth, pins, step, true)
		var fill := _held(smooth, pins, step, false)
		var bed := PackedFloat32Array()
		bed.resize(n)
		for i in n:
			bed[i] = (cut[i] + fill[i]) * 0.5
		# Rounded off (no kinks to bump over), the ends kept where they meet.
		for pass_ in 8:
			var soft := bed.duplicate()
			for i in range(1, n - 1):
				if not pins.has(i):
					soft[i] = (bed[i - 1] + bed[i] * 2.0 + bed[i + 1]) * 0.25
			bed = soft
		var start := _segs.size()
		for i in n - 1:
			_segs.append([pts[i], pts[i + 1], bed[i], bed[i + 1], ri])
		for si in range(start, _segs.size()):
			var a: Vector2 = _segs[si][0]
			var b: Vector2 = _segs[si][1]
			var r := ROAD_BED_HALF + ROAD_REACH
			for bx in range(floori((minf(a.x, b.x) - r) / _BUCKET), floori((maxf(a.x, b.x) + r) / _BUCKET) + 1):
				for bz in range(floori((minf(a.y, b.y) - r) / _BUCKET), floori((maxf(a.y, b.y) + r) / _BUCKET) + 1):
					var key := Vector2i(bx, bz)
					if not _buckets.has(key):
						_buckets[key] = PackedInt32Array()
					var list: PackedInt32Array = _buckets[key]
					list.append(si)
					_buckets[key] = list


## The bed's height where a road already laid passes within 3 m of p
## (NAN if none does).
static func _bed_at(p: Vector2) -> float:
	var best := 3.0
	var out := NAN
	for sg: Array in _segs:
		var a: Vector2 = sg[0]
		var ab: Vector2 = (sg[1] as Vector2) - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			out = lerpf(sg[2], sg[3], t)
	return out


## A line held to `step` per point: below the profile (cut) or above it
## (fill), passing through the pinned points.
static func _held(profile: PackedFloat32Array, pins: Dictionary, step: float, below: bool) -> PackedFloat32Array:
	var n := profile.size()
	var out := profile.duplicate()
	# Within reach of every pin at the grade (so the line can meet each one).
	for i in n:
		var lo := -INF
		var hi := INF
		for j: int in pins:
			lo = maxf(lo, float(pins[j]) - step * absi(i - j))
			hi = minf(hi, float(pins[j]) + step * absi(i - j))
		out[i] = clampf(out[i], lo, maxf(lo, hi))
	for i in range(1, n):
		out[i] = minf(out[i], out[i - 1] + step) if below else maxf(out[i], out[i - 1] - step)
	for i in range(n - 2, -1, -1):
		out[i] = minf(out[i], out[i + 1] + step) if below else maxf(out[i], out[i + 1] - step)
	for i: int in pins:
		out[i] = pins[i]
	return out
