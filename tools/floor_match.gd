extends SceneTree
## Floors drawn vs floors walked on: for every walk-in piece with a separate
## collision mesh (`<piece>_col.glb`), casts vertical rays on a grid and, for
## each walkable collision surface, finds the drawn floor right there (the
## piece's own mesh and its `_in.glb` interior). A drawn floor above the
## collision floor is where feet sink in.
##   godot --headless -s res://tools/floor_match.gd [-- piece ...]
## Prints per piece: rays, mismatched rays (|d| > 2 cm), mean/worst d (m).

const STEP := 0.5
const TOL := 0.02

var _pieces := ["titan/hab_r14", "titan/market_hub", "titan/plant_ex03", "titan/gatehouse", "districts/galleria",
		"districts/pod_a", "districts/pod_b", "districts/pod_c", "districts/apartment", "districts/office"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_pieces = Array(args)
	for p: String in _pieces:
		_compare(p)
	quit(0)


static func faces(path: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not ResourceLoader.exists(path):
		return out
	var scene: Node = (load(path) as PackedScene).instantiate()
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != scene:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for f in mi.mesh.get_faces():
			out.append(xf * f)
	scene.free()
	return out


## Heights of the upward-facing surfaces under (x, z), highest first.
static func up_hits(tris: PackedVector3Array, x: float, z: float) -> PackedFloat32Array:
	var hs := PackedFloat32Array()
	for i in range(0, tris.size(), 3):
		var a := tris[i]
		var b := tris[i + 1]
		var c := tris[i + 2]
		if minf(a.x, minf(b.x, c.x)) > x or maxf(a.x, maxf(b.x, c.x)) < x or minf(a.z, minf(b.z, c.z)) > z or maxf(a.z, maxf(b.z, c.z)) < z:
			continue
		var n := (b - a).cross(c - a)
		if absf(n.y) < 1e-6 or absf(n.normalized().y) < 0.7:
			continue
		var v0 := Vector2(b.x - a.x, b.z - a.z)
		var v1 := Vector2(c.x - a.x, c.z - a.z)
		var v2 := Vector2(x - a.x, z - a.z)
		var den := v0.x * v1.y - v1.x * v0.y
		if absf(den) < 1e-9:
			continue
		var u := (v2.x * v1.y - v1.x * v2.y) / den
		var w := (v0.x * v2.y - v2.x * v0.y) / den
		if u < -1e-4 or w < -1e-4 or u + w > 1.0001:
			continue
		hs.append(a.y + u * (b.y - a.y) + w * (c.y - a.y))
	hs.sort()
	hs.reverse()
	return hs


func _compare(piece: String) -> void:
	var base := "res://art/environment/%s" % piece
	var col := faces(base + "_col.glb")
	if col.is_empty():
		print("FLOOR MATCH %s: no _col mesh" % piece)
		return
	var vis := faces(base + ".glb")
	vis.append_array(faces(base + "_in.glb"))
	var box := AABB(col[0], Vector3.ZERO)
	for v in col:
		box = box.expand(v)
	var rays := 0
	var off := 0
	var sum := 0.0
	var worst := 0.0
	var worst_at := Vector3.ZERO
	var buckets := {}
	var x := box.position.x + STEP * 0.5
	while x < box.end.x:
		var z := box.position.z + STEP * 0.5
		while z < box.end.z:
			var vh := up_hits(vis, x, z)
			for hc: float in up_hits(col, x, z):
				# The top drawn floor at this walkable surface (within 40 cm):
				# what the eye sees the feet on.
				var best := INF
				for hv: float in vh:
					if absf(hv - hc) < 0.4:
						best = hv - hc
						break
				if best == INF:
					continue
				rays += 1
				sum += best
				var key := snappedf(best, 0.01)
				buckets[key] = int(buckets.get(key, 0)) + 1
				if absf(best) > TOL:
					off += 1
				if absf(best) > absf(worst):
					worst = best
					worst_at = Vector3(x, hc, z)
			z += STEP
		x += STEP
	var top := buckets.keys()
	top.sort_custom(func(a: float, b: float) -> bool: return buckets[a] > buckets[b])
	var common := []
	for k: float in top.slice(0, 4):
		common.append("%+.2f x%d" % [k, buckets[k]])
	print("FLOOR MATCH %s: %d rays, %d off, mean %+.3f, worst %+.2f at %s; common %s" % [piece, rays, off,
			sum / maxf(rays, 1), worst, worst_at.snapped(Vector3.ONE * 0.1), ", ".join(common)])
