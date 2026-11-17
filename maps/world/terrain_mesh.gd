class_name TerrainMesh
extends RefCounted
## Kasei Valley's visible ground, built at load from the same height grid as
## the physics (WorldTerrain.grid), so the map can be re-laid out in code
## with no baked asset to rebuild. Vertex colours, Titan's: dark organic
## dunes on the flats, pale water-ice bedrock in bands on the slopes, frost
## in the ice crater, packed gravel on the roads. Each
## TILE-metre square is its own mesh (culled off screen, with LODs). Both
## triangles of a cell split on its (i+1, j)-(i, j+1) diagonal, like the
## physics height map: what you see is what you stand on.

const DUST_A := Color(0.33, 0.26, 0.19)
const DUST_B := Color(0.44, 0.35, 0.25)
const STRATA := [Color(0.6, 0.59, 0.55), Color(0.71, 0.7, 0.66), Color(0.5, 0.49, 0.46)]
const ICE := Color(0.86, 0.9, 0.93)
const ROAD := Color(0.66, 0.6, 0.5)  ## the road's gravel (Presentation.ROAD_SURFACE)
const ROAD_HALF := 5.0


## Tiles: [name, ArrayMesh] for TILE x TILE metre squares.
static func build(tile: float) -> Array:
	var n := WorldTerrain.cells() + 1
	var step := WorldTerrain.STEP
	var half := WorldTerrain.SIZE * 0.5
	var h := WorldTerrain.grid()
	var normals := PackedVector3Array()
	normals.resize(n * n)
	var colors := PackedColorArray()
	colors.resize(n * n)
	var road := _road_distance(n, step, half)
	for j in n:
		for i in n:
			var k := j * n + i
			var gx := (h[j * n + mini(i + 1, n - 1)] - h[j * n + maxi(i - 1, 0)]) / ((mini(i + 1, n - 1) - maxi(i - 1, 0)) * step)
			var gz := (h[mini(j + 1, n - 1) * n + i] - h[maxi(j - 1, 0) * n + i]) / ((mini(j + 1, n - 1) - maxi(j - 1, 0)) * step)
			normals[k] = Vector3(-gx, 1.0, -gz).normalized()
			# The palette is sRGB; the shader takes linear colours (as glTF stored them).
			colors[k] = color_at(-half + i * step, -half + j * step, h[k], Vector2(gx, gz).length(), road[k]).srgb_to_linear()
	var per := int(tile / step)
	var out := []
	for tj in ceili(float(n - 1) / per):
		for ti in ceili(float(n - 1) / per):
			var i0 := ti * per
			var j0 := tj * per
			var i1 := mini(i0 + per, n - 1)
			var j1 := mini(j0 + per, n - 1)
			var w := i1 - i0 + 1
			var verts := PackedVector3Array()
			var nrm := PackedVector3Array()
			var col := PackedColorArray()
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var k := j * n + i
					verts.append(Vector3(-half + i * step, h[k], -half + j * step))
					nrm.append(normals[k])
					col.append(colors[k])
			var idx := PackedInt32Array()
			for j in j1 - j0:
				for i in i1 - i0:
					var a := j * w + i       # (i, j)
					var b := a + 1           # (i+1, j)
					var d := a + w           # (i, j+1)
					var c := d + 1           # (i+1, j+1)
					idx.append_array([a, b, d, b, c, d])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = nrm
			arrays[Mesh.ARRAY_COLOR] = col
			arrays[Mesh.ARRAY_INDEX] = idx
			out.append(["Terrain_%d_%d" % [ti, tj], arrays])
	return out


## The ground's colour at (x, z): height h, slope (gradient length), and the
## distance to the nearest road.
static func color_at(x: float, z: float, h: float, slope: float, road: float) -> Color:
	var nz := sin(x * 0.13) * cos(z * 0.11) * 0.5 + sin(x * 0.031 + z * 0.027) * 0.5
	var c := DUST_A.lerp(DUST_B, nz * 0.5 + 0.5)
	var band := posmod(floori(h / 3.2), 3)
	c = c.lerp(STRATA[band], smoothstep(0.12, 0.35, slope))
	for cr: Array in [WorldTerrain.CRATER]:  # (Sinlap, CRATER2, holds a lake)
		if Vector2(x - cr[0], z - cr[1]).length() < float(cr[2]) * 0.42 and slope < 0.2:
			c = c.lerp(ICE, 0.75 * (0.5 + 0.5 * sin(x * 0.4) * sin(z * 0.37)))
	if road < ROAD_HALF:
		c = c.lerp(ROAD, smoothstep(ROAD_HALF, ROAD_HALF * 0.5, road))
	return c


## Distance from every grid corner to the nearest road (only filled near
## roads: each segment touches the corners in its own box).
static func _road_distance(n: int, step: float, half: float) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(n * n)
	d.fill(INF)
	for road: Array in WorldLayout.roads():
		for s in road.size() - 1:
			var a: Vector2 = road[s]
			var b: Vector2 = road[s + 1]
			var i0 := maxi(floori((minf(a.x, b.x) - ROAD_HALF + half) / step), 0)
			var i1 := mini(ceili((maxf(a.x, b.x) + ROAD_HALF + half) / step), n - 1)
			var j0 := maxi(floori((minf(a.y, b.y) - ROAD_HALF + half) / step), 0)
			var j1 := mini(ceili((maxf(a.y, b.y) + ROAD_HALF + half) / step), n - 1)
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var p := Vector2(-half + i * step, -half + j * step)
					var q := Geometry2D.get_closest_point_to_segment(p, a, b)
					d[j * n + i] = minf(d[j * n + i], p.distance_to(q))
	return d
