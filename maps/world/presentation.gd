extends Node3D
## Presentation half of Kasei Valley: the Blender terrain under the comic
## ground material, Tharsis Gate (CityLayout) on its plateau, Dust Hollow
## and the Rustwood Dig (WorldLayout), the landmarks, the dig's deploy pad,
## the Mars daylight and the people (city and settlement).

const TEX := "res://art/environment/mars/%s_%s_1k.jpg"
const TERRAIN_SHADER := preload("res://presentation/comic/comic_terrain.gdshader")


func _ready() -> void:
	var terrain_scene: Node = (load("res://art/environment/world/terrain.glb") as PackedScene).instantiate()
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("sand_tex", load(TEX % ["red_sand", "diff"]))
	mat.set_shader_parameter("rock_tex", load(TEX % ["terrain_red_01", "diff"]))
	for mi: MeshInstance3D in terrain_scene.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
	add_child(terrain_scene)
	# The city plaza's paving.
	var paving := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(CityLayout.HALF * 2, CityLayout.HALF * 2 - 10)
	paving.mesh = pm
	paving.position = CityLayout.ORIGIN + Vector3(0, 0.03, -5)
	paving.material_override = Comic.env_material(load(TEX % ["concrete_slab_wall", "diff"]), 0.18, Color(0.72, 0.62, 0.58))
	add_child(paving)
	for p: Array in CityLayout.pieces():
		if not str(p[0]).is_empty():
			add_child(Comic.kit_instance(p[0], p[1], p[2], p[3]))
		if p[0] == "life/hab_open" or p[0] == "shopfront":
			_room_light(p[1])
	for t: Array in CityLayout.terminals():
		add_child(Comic.kit_instance("kiosk", t[1], t[2], 1.0))
	_city_life()
	_deep_furrow()
	for p: Array in WorldLayout.pieces():
		if str(p[0]).is_empty():
			continue  # collision only
		var base := WorldTerrain.at(p[1], p[2])
		var sink := 0.15 if FOOTINGS.has(p[0]) else 0.3  # small props bed into the dust
		var kit := Comic.kit_instance(p[0], base + Vector3(0, -sink, 0), p[3], p[4])
		if VIEW_RANGE.has(p[0]):
			kit.visibility_range_end = VIEW_RANGE[p[0]]
			kit.visibility_range_end_margin = 10.0
		add_child(kit)
		if FOOTINGS.has(p[0]):
			_footing(base, FOOTINGS[p[0]] * float(p[4]), float(p[3]))
		if p[0] == "life/hab_open" or p[0] == "shopfront":
			_room_light(WorldTerrain.at(p[1], p[2]))
	_deploy_pad(WorldLayout.dig_pad())
	_roads()
	_districts()
	_monorail()
	_estates()
	MarsLighting.add(self)
	MarsLighting.add_moons(self)
	var weather := DustStorms.new()
	weather.name = "Weather"
	add_child(weather)
	var devils := DustDevils.new()
	devils.name = "Wind"
	add_child(devils)
	var people := CityNpcs.new()
	people.name = "People"
	add_child(people)


## Green is wealth on Mars: Tharsis Gate's lawns, trees, shrubs and
## benches under its pressure dome (a geodesic frame and faint glass).
func _city_life() -> void:
	var grass := Comic.env_material(load(TEX % ["red_sand", "diff"]), 0.25, Color(0.42, 1.25, 0.3))
	grass.set_shader_parameter("saturation", 1.6)
	for l: Array in CityLayout.lawns():
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = l[1]
		mi.mesh = pm
		mi.position = (l[0] as Vector3) + Vector3(0, 0.05, 0)
		mi.material_override = grass
		add_child(mi)
	var ti := 0
	for p: Array in CityLayout.plants():
		var plant := Comic.kit_instance(p[0], p[1], p[2], 1.0)
		if p[0] == "life/tree":
			plant.name = "Tree_c%d" % ti
			ti += 1
		add_child(plant)
	add_child(Comic.kit_instance("life/city_dome", CityLayout.ORIGIN + Vector3(0, -0.4, 0), 0.0, 1.0))
	var glass := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 74.0
	sphere.height = 74.0 * 0.55  # a hemisphere's height: the frame's
	sphere.is_hemisphere = true
	sphere.radial_segments = 48
	sphere.rings = 12
	glass.mesh = sphere
	glass.position = CityLayout.ORIGIN
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.6, 0.85, 0.95, 0.07)
	gm.roughness = 0.1
	gm.metallic_specular = 1.0
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.material_override = gm
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)


## A walk-in habitat's ceiling lamp (warm, short range: it lights the room).
func _room_light(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.86, 0.66)
	l.light_energy = 1.6
	l.omni_range = 7.5
	l.position = at + Vector3(0, 2.8, 0)
	add_child(l)


## Deep Furrow, the farm under the Anvil: the hall, its grow lights.
func _deep_furrow() -> void:
	var o := WorldLayout.farm_origin()
	add_child(Comic.kit_instance("life/farm_hall", o, 0.0, 1.0))
	for k in 4:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.85) if k % 2 == 0 else Color(0.85, 1.0, 0.8)
		light.light_energy = 2.2
		light.omni_range = 24.0
		light.position = o + Vector3(0, 6.0, -20.0 + k * 14.0)
		add_child(light)


## Small street furniture isn't drawn from far off (the towers always are).
const VIEW_RANGE := {"districts/lamp_neo": 180.0, "districts/planter": 140.0, "districts/holo_sign": 260.0,
		"districts/solar_tree": 260.0, "crate_stack": 180.0, "street_lamp": 180.0, "districts/pod_a": 420.0,
		"districts/pod_b": 420.0, "districts/pod_c": 420.0, "districts/landing_pad": 500.0}


## The districts' paved plazas, and the Galleria's interior lights.
func _districts() -> void:
	var paving := Comic.env_material(load(TEX % ["concrete_slab_wall", "diff"]), 0.12, Color(0.8, 0.74, 0.7))
	var dark := Comic.env_material(load(TEX % ["concrete_slab_wall", "diff"]), 0.12, Color(0.42, 0.4, 0.42))
	for d: Array in [[WorldLayout.HELIOS, 112.0, paving], [WorldLayout.TERRACE, 98.0, paving], [WorldLayout.SKYPORT, 108.0, dark]]:
		var c: Vector2 = d[0]
		var mi := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = d[1]
		disc.bottom_radius = d[1]
		disc.height = 0.1
		disc.radial_segments = 48
		disc.rings = 1
		mi.mesh = disc
		mi.position = WorldTerrain.at(c.x, c.y) + Vector3(0, 0.0, 0)
		mi.material_override = d[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	var g := WorldLayout.GALLERIA
	var fore := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(156, 64)
	fore.mesh = pm
	fore.position = WorldTerrain.at(g.x, g.y) + Vector3(0, 0.04, 0)
	fore.material_override = paving
	add_child(fore)
	for x in [-30.0, 0.0, 30.0]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.88, 0.7)
		l.light_energy = 1.4
		l.omni_range = 22.0
		l.position = WorldTerrain.at(g.x, g.y) + Vector3(x, 5.0, 0)
		add_child(l)


## Interiors (deep under the valley), the outland groves (each tree named
## "Tree_<id>" so a felled one can be hidden), the visa office's and Kasei
## Aero's kiosks.
func _estates() -> void:
	for kind: String in WorldLayout.INTERIORS:
		add_child(Comic.kit_instance("districts/" + kind, WorldLayout.INTERIORS[kind], 0.0, 1.0))
		for x in [-4.0, 4.0]:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.9, 0.75)
			l.light_energy = 1.3
			l.omni_range = 9.0
			l.position = (WorldLayout.INTERIORS[kind] as Vector3) + Vector3(x, 3.0, 0)
			add_child(l)
	for t: Array in WorldLayout.trees():
		if t[2]:
			continue  # the city's own trees are drawn with its parks
		var tree := Comic.kit_instance("life/tree", t[1], float(hash(t[0]) % 360), 1.6)
		tree.name = "Tree_" + str(t[0])
		tree.visibility_range_end = 320.0
		add_child(tree)
	add_child(Comic.kit_instance("kiosk", WorldLayout.visa_office() + Vector3(0, 0, -1.4), 0.0, 1.2))
	add_child(Comic.kit_instance("kiosk", WorldLayout.aero_counter() + Vector3(0, 0, -1.4), 0.0, 1.2))
	add_child(Comic.kit_instance("kiosk", WorldLayout.bounty_board() + Vector3(0, 0, -1.4), 0.0, 1.3))
	add_child(Comic.kit_instance("kiosk", CityEstate.gang_spot() + Vector3(0, 0, -1.4), 0.0, 1.2))
	for place: Array in [[WorldLayout.bounty_board(), "BOUNTY_BOARD_SIGN"], [WorldLayout.visa_office(), "VISA_OFFICE_SIGN"],
			[WorldLayout.aero_counter(), "AERO_SIGN"], [CityEstate.gang_spot(), "GANG_SIGN"]]:
		var sign := Label3D.new()
		sign.text = tr(place[1])
		sign.font = UiStyle.font_hud_big
		sign.font_size = 64
		sign.outline_size = 14
		sign.outline_modulate = ComicUI.INK
		sign.modulate = ComicUI.YELLOW
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.position = (place[0] as Vector3) + Vector3(0, 4.0, -1.4)
		add_child(sign)


## The monorail (WorldLayout.monorail): a white guideway on pylons every
## PYLON_EVERY metres, MONO_HEIGHT up, and a three-car train that runs the
## line end to end and waits at each end.
const PYLON_EVERY := 32.0
const TRAIN_SPEED := 22.0
const TRAIN_WAIT := 8.0
var _train: Array[Node3D] = []
var _track: Array = []          ## [position, direction] every 2 m
var _train_d: float = 0.0
var _train_dir: float = 1.0
var _train_wait: float = 0.0


func _monorail() -> void:
	# The guideway's height: the ground plus MONO_HEIGHT, smoothed so it
	# runs level over the dunes.
	var samples := WorldLayout.road_samples(WorldLayout.monorail(), 2.0)
	var ys := PackedFloat32Array()
	for sm: Array in samples:
		var q: Vector2 = sm[0]
		ys.append(WorldTerrain.height(q.x, q.y) + WorldLayout.MONO_HEIGHT)
	var smooth := PackedFloat32Array(ys)
	for k in ys.size():
		var sum := 0.0
		var n := 0
		for o in range(-12, 13):
			var i := clampi(k + o, 0, ys.size() - 1)
			sum += maxf(ys[i], WorldTerrain.height((samples[i][0] as Vector2).x, (samples[i][0] as Vector2).y) + 7.0)
			n += 1
		smooth[k] = sum / n
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color(0.9, 0.9, 0.92).srgb_to_linear()
	var cyan := Color(0.2, 0.95, 1.0).srgb_to_linear()
	cyan.a = Comic.TAG_GLOW
	var since := PYLON_EVERY
	for k in samples.size():
		var q: Vector2 = samples[k][0]
		var dir: Vector2 = samples[k][1]
		var at := Vector3(q.x, smooth[k], q.y)
		_track.append([at, Vector3(dir.x, 0, dir.y)])
		since += 2.0
		if since >= PYLON_EVERY:
			since = 0.0
			var ground := WorldTerrain.at(q.x, q.y)
			var pylon := Comic.kit_instance("districts/mono_pylon", ground, rad_to_deg(atan2(dir.x, dir.y)), 1.0)
			pylon.scale = Vector3(1.0, (at.y - 1.1 - ground.y) / 9.9, 1.0)
			add_child(pylon)
		if k == 0:
			continue
		var a: Vector3 = _track[k - 1][0]
		var n := Vector3(-dir.y, 0, dir.x)
		_box_strip(st, a, at, n, 0.9, 1.1, white)        # the beam
		_box_strip(st, a + Vector3(0, 1.12, 0), at + Vector3(0, 1.12, 0), n, 0.25, 0.1, cyan)  # its guide light
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Comic.kit_material(0.02)
	add_child(mi)
	for i in 3:
		var car := Comic.kit_instance("districts/mono_car", Vector3.ZERO, 0.0, 1.0)
		add_child(car)
		_train.append(car)


## A box section along a-b: half width `hw`, depth `h` below the top.
func _box_strip(st: SurfaceTool, a: Vector3, b: Vector3, n: Vector3, hw: float, h: float, col: Color) -> void:
	var top := [a - n * hw, a + n * hw, b + n * hw, b - n * hw]
	var bot := [a - n * hw - Vector3(0, h, 0), a + n * hw - Vector3(0, h, 0), b + n * hw - Vector3(0, h, 0),
			b - n * hw - Vector3(0, h, 0)]
	st.set_color(col)
	for f: Array in [[top[0], top[2], top[1], top[0], top[3], top[2]],
			[bot[0], bot[1], bot[2], bot[0], bot[2], bot[3]],
			[top[0], bot[0], bot[3], top[0], bot[3], top[3]],
			[top[1], top[2], bot[2], top[1], bot[2], bot[1]]]:
		for v: Vector3 in f:
			st.add_vertex(v)


func _process(delta: float) -> void:
	if _track.is_empty() or _train.is_empty():
		return
	var length := (_track.size() - 1) * 2.0
	if _train_wait > 0.0:
		_train_wait -= delta
	else:
		_train_d += _train_dir * TRAIN_SPEED * delta
		if _train_d >= length - 40.0 or _train_d <= 0.0:
			_train_d = clampf(_train_d, 0.0, length - 40.0)
			_train_dir = -_train_dir
			_train_wait = TRAIN_WAIT
	for i in _train.size():
		var d := _train_d + i * 13.4
		var k := clampi(int(d / 2.0), 0, _track.size() - 2)
		var t := clampf(d / 2.0 - k, 0.0, 1.0)
		var p: Vector3 = (_track[k][0] as Vector3).lerp(_track[k + 1][0], t)
		var dir: Vector3 = _track[k][1]
		_train[i].transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.z)), p + Vector3(0, 0.35, 0))


## The dig's deploy pad: a glowing ring and a beam visible across the valley.
func _deploy_pad(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = WorldLayout.DEPLOY_RADIUS - 0.4
	torus.outer_radius = WorldLayout.DEPLOY_RADIUS
	ring.mesh = torus
	ring.position = at + Vector3(0, 0.08, 0)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.18, 0.47)
	ring.material_override = glow
	add_child(ring)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.8
	cyl.bottom_radius = 0.8
	cyl.height = 80.0
	beam.mesh = cyl
	beam.position = at + Vector3(0, 40, 0)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(1.0, 0.18, 0.47, 0.35)
	beam.material_override = bm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)


## The valley's roads (WorldLayout.roads): a paved strip 9 m wide laid on
## the ground, white edge lines and a dashed yellow centre line; one mesh.
const ROAD_HALF := 4.5


func _roads() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tarmac := Color(0.2, 0.17, 0.16).srgb_to_linear()
	var white := Color(0.85, 0.82, 0.76).srgb_to_linear()
	var yellow := Color(0.95, 0.72, 0.12).srgb_to_linear()
	for road: Array in WorldLayout.roads():
		var pts := WorldLayout.road_samples(road, 3.0)
		for i in pts.size() - 1:
			var a: Vector2 = pts[i][0]
			var b: Vector2 = pts[i + 1][0]
			var da: Vector2 = pts[i][1]
			var db: Vector2 = pts[i + 1][1]
			var na := Vector2(-da.y, da.x)
			var nb := Vector2(-db.y, db.x)
			_strip(st, a, b, na, nb, -ROAD_HALF, ROAD_HALF, 0.12, tarmac)
			for side in [-1.0, 1.0]:  # edge lines
				_strip(st, a, b, na, nb, side * (ROAD_HALF - 0.6) - 0.12, side * (ROAD_HALF - 0.6) + 0.12, 0.14, white)
			if i % 2 == 0:  # the dashed centre line
				_strip(st, a, b, na, nb, -0.12, 0.12, 0.14, yellow)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Comic.kit_material(0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A quad from a to b, between offsets `l` and `r` across, `lift` above the ground.
func _strip(st: SurfaceTool, a: Vector2, b: Vector2, na: Vector2, nb: Vector2, l: float, r: float, lift: float, col: Color) -> void:
	var p := [a + na * l, a + na * r, b + nb * r, b + nb * l]
	var v: Array[Vector3] = []
	for q: Vector2 in p:
		v.append(WorldTerrain.at(q.x, q.y) + Vector3(0, lift, 0))
	st.set_color(col)
	for idx in [0, 2, 1, 0, 3, 2]:
		st.add_vertex(v[idx])


## Buildings on the valley's slopes stand on a concrete footing sunk into
## the ground, so there's no gap to see under them: footprint (x, z) by piece.
const FOOTINGS := {"hangar": Vector2(14.4, 10.6), "life/hab_open": Vector2(12.4, 12.4), "shopfront": Vector2(12.6, 8.6),
		"tank_cluster": Vector2(8.6, 5.6), "life/greenhouse": Vector2(6.4, 4.0), "life/lift_head": Vector2(5.6, 5.6),
		"life/mining_rig": Vector2(6.4, 6.4), "pipe_run": Vector2(10.0, 2.0)}


func _footing(at: Vector3, size: Vector2, yaw_deg: float) -> void:
	# Deep enough for the lowest corner of the ground under it.
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	var low := at.y
	for cx in [-0.5, 0.5]:
		for cz in [-0.5, 0.5]:
			var corner := at + b * Vector3(size.x * cx, 0, size.y * cz)
			low = minf(low, WorldTerrain.height(corner.x, corner.z))
	var depth := at.y - low + 1.5
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, depth, size.y)
	mi.mesh = CityMode._tinted(box, Color(0.36, 0.32, 0.3))
	mi.material_override = Comic.kit_material(0.012)
	mi.transform = Transform3D(b, at + Vector3(0, -depth * 0.5 + 0.06, 0))
	add_child(mi)
