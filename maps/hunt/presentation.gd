extends Node3D
## Visual half of Rustwood Yard (PLAN §3.1), dressed as a Martian ore-mining
## outpost: generated at load time from HuntLayout, so every wall, shed,
## cover and crate stands exactly where its collision is (gameplay
## unchanged). Clients only.
##
## Cost rules (mobile): the static yard is merged into ONE mesh per
## material (about 260 draw calls before, see docs/the-hunt.md); terrain
## and the industrial skyline outside the fence are one mesh each; PBR
## textures are CC0 Poly Haven 1K sets (art/ASSETS.csv) on world-space
## triplanar UVs; no SSAO, SSR, volumetric fog or extra lights.

const Kind := HuntLayout.Kind
const TEX := "res://art/environment/mars/%s_%s_1k.jpg"
## Per kind: texture set, world UV scale (repeats per metre), tint.
const SURFACES := {
	Kind.FLOOR: ["red_sand", 0.16, Color(0.8, 0.62, 0.54)],
	Kind.WALL: ["rusty_corrugated_iron", 0.32, Color(1.45, 1.25, 1.1)],
	Kind.VAULT_WALL: ["metal_plate_02", 0.28, Color(0.78, 0.8, 0.84)],
	Kind.COVER: ["concrete_slab_wall", 0.45, Color(0.9, 0.78, 0.7)],
	Kind.PROP: ["container_side", 0.38, Color(0.95, 0.5, 0.42)],
	Kind.PAD: ["metal_plate_02", 0.4, Color(0.45, 0.47, 0.52)],
}
const TERRAIN_SIZE := 560.0
const TERRAIN_CELLS := 56

var _materials: Dictionary = {}


func _ready() -> void:
	for kind in SURFACES:
		var s: Array = SURFACES[kind]
		_materials[kind] = _pbr(s[0], s[1], s[2])
	_materials[Kind.TRIM] = _emissive(Color(1.0, 0.62, 0.2), 3.0)
	# Comic ink lines on the structures that matter: walls, vault, crates.
	for kind in [Kind.WALL, Kind.VAULT_WALL, Kind.PROP]:
		(_materials[kind] as Material).next_pass = Comic.outline(0.02)
	_build_yard()
	_build_terrain()
	_build_skyline()
	_add_lighting()


## Every layout box of a kind in one mesh (one draw call per material).
func _build_yard() -> void:
	var tools := {}
	for b in HuntLayout.boxes():
		var kind: int = b[0]
		if kind == Kind.BOUND:
			continue  # invisible
		if not tools.has(kind):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[kind] = st
		var box := BoxMesh.new()
		box.size = b[2]
		(tools[kind] as SurfaceTool).append_from(box, 0, Transform3D(Basis.IDENTITY, b[1]))
	for kind in tools:
		var st: SurfaceTool = tools[kind]
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.name = "Yard_%s" % Kind.keys()[kind]
		mi.mesh = st.commit()
		mi.material_override = _materials[kind]
		if kind == Kind.TRIM or kind == Kind.PAD:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## Martian ground beyond the fence: flat under the yard, rising into dunes
## and a ridge towards the horizon. One grid mesh, no collision (the fence
## and invisible bounds keep players in).
func _build_terrain() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.008
	noise.fractal_octaves = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := TERRAIN_SIZE / TERRAIN_CELLS
	var half := TERRAIN_SIZE * 0.5
	var heights := {}
	for zi in TERRAIN_CELLS + 1:
		for xi in TERRAIN_CELLS + 1:
			var x := -half + xi * step
			var z := -half + zi * step
			var edge := maxf(absf(x), absf(z)) - (HuntLayout.HALF + 6.0)
			var rise := clampf(edge / 120.0, 0.0, 1.0)
			var h := -0.05
			if edge > 0.0:
				h = rise * rise * 38.0 + (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 14.0 * rise
			heights[Vector2i(xi, zi)] = Vector3(x, h, z)
	for zi in TERRAIN_CELLS:
		for xi in TERRAIN_CELLS:
			var a: Vector3 = heights[Vector2i(xi, zi)]
			var b: Vector3 = heights[Vector2i(xi + 1, zi)]
			var c: Vector3 = heights[Vector2i(xi, zi + 1)]
			var d: Vector3 = heights[Vector2i(xi + 1, zi + 1)]
			for v in [a, b, c, b, d, c]:
				st.add_vertex(v)
	st.generate_normals()  # no UVs: the triplanar material derives its own tangents
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	mi.material_override = _pbr("terrain_red_01", 0.05, Color(0.85, 0.62, 0.52))
	add_child(mi)


## The mining outpost beyond the fence (visual only), built from the
## Blender kit (tools/blender/build_outpost_kit.py): a habitat cluster to
## the west, storage tanks and a comms mast to the north, a hangar and pipe
## runs to the south and east. One draw (plus outline) per piece.
func _build_skyline() -> void:
	var h := HuntLayout.HALF
	var pieces := [
		["hab_dome", Vector3(-h - 22, 0, -26), 20.0], ["hab_dome", Vector3(-h - 24, 0, 6), -15.0],
		["hab_dome", Vector3(-h - 48, 0, -10), 90.0], ["pipe_run", Vector3(-h - 9, 0, -10), 90.0],
		["tank_cluster", Vector3(-30, 0, -h - 14), 0.0], ["tank_cluster", Vector3(-6, 0, -h - 16), 0.0],
		["comms_tower", Vector3(h + 20, 0, -h - 18), 0.0], ["hab_dome", Vector3(h + 22, 0, -36), 180.0],
		["hangar", Vector3(24, 0, h + 18), 0.0], ["hangar", Vector3(-22, 0, h + 20), 0.0],
		["pipe_run", Vector3(h + 6, 0, 18), 90.0], ["pipe_run", Vector3(h + 6, 0, 28), 90.0],
		["tank_cluster", Vector3(h + 16, 0, 44), 90.0], ["comms_tower", Vector3(-h - 22, 0, h + 16), 0.0],
	]
	# Industrial scale: they rise well over the 4 m fence.
	var scales := {"hab_dome": 2.0, "tank_cluster": 2.2, "comms_tower": 1.8, "hangar": 1.8, "pipe_run": 1.6}
	for p: Array in pieces:
		add_child(Comic.kit_instance(p[0], p[1], p[2], scales.get(p[0], 1.0)))


func _box(st: SurfaceTool, at: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	st.append_from(box, 0, Transform3D(Basis.IDENTITY, at))


## The Mars texture sets under the comic cel material (Comic.env_material:
## bold light bands, halftone in the shade; the albedo map carries the
## material detail).
func _pbr(set_name: String, scale: float, tint: Color) -> Material:
	return Comic.env_material(load(TEX % [set_name, "diff"]), scale, tint)


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Mars at mid-afternoon: a small pale sun in a butterscotch sky, dust in
## the air. One directional light with two shadow splits; no SSAO, SSR or
## volumetrics (phones).
func _add_lighting() -> void:
	MarsLighting.add(self)
