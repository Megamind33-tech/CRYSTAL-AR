extends Node3D
## Presentation half of Kasei Valley: the Blender terrain under the comic
## ground material, Tharsis Gate (CityLayout) on its plateau, Dust Hollow
## and the Rustwood Dig (WorldLayout), the landmarks, the dig's deploy pad,
## the Mars daylight and the people (city and settlement).

const TEX := "res://art/environment/mars/%s_%s_1k.jpg"
## Static kit pieces merged by cell (StaticBatches): the draw-call budget.
var batches: StaticBatches
const TERRAIN_SHADER := preload("res://presentation/comic/comic_terrain.gdshader")


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("sand_tex", load(TEX % ["red_sand", "diff"]))
	mat.set_shader_parameter("rock_tex", load(TEX % ["terrain_red_01", "diff"]))
	_terrain(mat)
	batches = StaticBatches.new()
	batches.name = "Batches"
	add_child(batches)
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
			batches.add_piece(p[0], p[1], p[2], p[3], 420.0)  # the city from the outlands: the dome carries it
		if p[0] == "life/hab_open" or p[0] == "shopfront":
			_room_light(p[1])
		if str(p[0]).begins_with("titan/"):
			# Titan's buildings: the furnished inside is its own piece, drawn
			# only up close (INTERIOR_RANGE), with a warm light of its own.
			var inside := Comic.kit_instance(str(p[0]) + "_in", p[1], p[2], p[3])
			inside.visibility_range_end = INTERIOR_RANGE
			inside.visibility_range_end_margin = 4.0
			add_child(inside)
			_room_light(p[1])
	for t: Array in CityLayout.terminals():
		batches.add_piece("kiosk", t[1], t[2], 1.0, 260.0)
	_city_life()
	_deep_furrow()
	for p: Array in WorldLayout.pieces():
		if str(p[0]).is_empty():
			continue  # collision only
		var base := WorldTerrain.at(p[1], p[2])
		var sink := 0.15 if FOOTINGS.has(p[0]) else 0.3  # small props bed into the dust
		var reach: float = VIEW_RANGE.get(p[0], 0.0 if LANDMARKS.has(p[0]) else 380.0)
		batches.add_piece(p[0], base + Vector3(0, -sink, 0), p[3], p[4], reach)
		if FOOTINGS.has(p[0]):
			_footing(base, FOOTINGS[p[0]] * float(p[4]), float(p[3]))
		if p[0] == "life/hab_open" or p[0] == "shopfront":
			_room_light(WorldTerrain.at(p[1], p[2]))
	_deploy_pad(WorldLayout.dig_pad())
	_roads()
	_districts()
	_monorail()
	_estates()
	batches.build()
	MarsLighting.add(self)
	MarsLighting.add_moons(self)
	var weather := DustStorms.new()
	weather.name = "Weather"
	add_child(weather)
	var devils := DustDevils.new()
	devils.name = "Wind"
	add_child(devils)
	var settlement := TitanSettlement.new()
	settlement.name = "Settlement"
	add_child(settlement)
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
		if p[0] != "life/tree":
			batches.add_piece(p[0], p[1], p[2], 1.0, 160.0)
			continue
		var plant := Comic.kit_instance(p[0], p[1], p[2], 1.0)
		plant.name = "Tree_c%d" % ti  # each its own node: felled ones are hidden
		plant.visibility_range_end = 200.0
		ti += 1
		add_child(plant)
	batches.add_piece("life/city_dome", CityLayout.ORIGIN + Vector3(0, -0.4, 0), 0.0, 1.0, 0.0)
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


## Interiors are drawn within this of their building (metres): through the
## windows from across the street, not from across the valley.
const INTERIOR_RANGE := 45.0


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
	var hall := Comic.kit_instance("life/farm_hall", o, 0.0, 1.0)
	add_child(hall)
	_farm.append(hall)
	for k in 4:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.85) if k % 2 == 0 else Color(0.85, 1.0, 0.8)
		light.light_energy = 2.2
		light.omni_range = 24.0
		light.position = o + Vector3(0, 6.0, -20.0 + k * 14.0)
		add_child(light)
		_farm.append(light)


## Seen from anywhere (the skyline): everything else has a view distance.
const LANDMARKS := ["districts/spire_a", "districts/spire_b", "districts/arc_towers", "districts/ring_hab", "districts/galleria",
		"districts/control_tower", "districts/shuttle", "comms_tower", "world/freighter_wreck", "life/factory", "life/mining_rig"]
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
		var room := Comic.kit_instance("districts/" + kind, WorldLayout.INTERIORS[kind], 0.0, 1.0)
		add_child(room)
		_interiors.append(room)
		for x in [-4.0, 4.0]:
			var l := OmniLight3D.new()
			_interiors.append(l)
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
		tree.visibility_range_end = 220.0
		add_child(tree)
	add_child(Comic.kit_instance("kiosk", WorldLayout.visa_office() + Vector3(0, 0, -1.4), 0.0, 1.2))
	add_child(Comic.kit_instance("kiosk", WorldLayout.aero_counter() + Vector3(0, 0, -1.4), 0.0, 1.2))
	add_child(Comic.kit_instance("kiosk", WorldLayout.bounty_board() + Vector3(0, 0, -1.4), 0.0, 1.3))
	add_child(Comic.kit_instance("kiosk", CityEstate.gang_spot() + Vector3(0, 0, -1.4), 0.0, 1.2))
	add_child(Comic.kit_instance("kiosk", CityHeist.board_spot() + Vector3(0, 0, -1.4), 0.0, 1.2))
	add_child(Comic.kit_instance("kiosk", WorldLayout.ring_panel() + Vector3(0, 0, -1.4), 0.0, 1.0))
	for place: Array in [[WorldLayout.bounty_board(), "BOUNTY_BOARD_SIGN"], [WorldLayout.visa_office(), "VISA_OFFICE_SIGN"],
			[WorldLayout.aero_counter(), "AERO_SIGN"], [CityEstate.gang_spot(), "GANG_SIGN"],
			[CityHeist.board_spot(), "HEIST_SIGN"], [WorldLayout.getaway_spot(), "HEIST_GETAWAY_SIGN"]]:
		var sign := Label3D.new()
		sign.text = tr(place[1])
		sign.font = UiStyle.font_hud_big
		sign.font_size = 64
		sign.outline_size = 14
		sign.outline_modulate = ComicUI.INK
		sign.modulate = ComicUI.YELLOW
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.position = (place[0] as Vector3) + Vector3(0, 4.0, -1.4)
		sign.visibility_range_end = 90.0
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
			var pb := Basis(Vector3.UP, atan2(dir.x, dir.y)).scaled(Vector3(1.0, (at.y - 1.1 - ground.y) / 9.9, 1.0))
			batches.add_arrays(Comic.kit_arrays("districts/mono_pylon"), Transform3D(pb, ground), 450.0)
		if k == 0 or k % 3 != 0:
			continue  # the guideway in 6 m sections (it's smoothed: straight enough)
		var a: Vector3 = _track[k - 3][0]
		var n := Vector3(-dir.y, 0, dir.x)
		_box_strip(st, a, at, n, 0.9, 1.1, white)        # the beam
		_box_strip(st, a + Vector3(0, 1.12, 0), at + Vector3(0, 1.12, 0), n, 0.25, 0.1, cyan)  # its guide light
		if k % 48 == 0 or k >= samples.size() - 3:  # a section per ~100 m, batched by where it is
			st.generate_normals()
			batches.add_arrays(st.commit_to_arrays(), Transform3D.IDENTITY, 450.0, true, at)
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
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


## Interiors (deep under the valley) are drawn only when you're down there.
var _interiors: Array[Node3D] = []
var _farm: Array[Node3D] = []  ## Deep Furrow: drawn when you're down there


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var down := cam.global_position.y < WorldLayout.INTERIOR_Y + 100.0
		for n: Node3D in _interiors:
			if n.visible != down:
				n.visible = down
		var farm := cam.global_position.y < WorldLayout.FARM_FLOOR + 60.0 and not down
		for n: Node3D in _farm:
			if n.visible != farm:
				n.visible = farm
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
	torus.rings = 48
	torus.ring_segments = 4
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


## The valley's roads (WorldLayout.roads): packed ice gravel 9 m wide laid
## on the ground, inked at the edges like the comic's outlines, two darker
## wheel ruts down the middle.
const ROAD_HALF := 4.5
## Packed pale ice gravel: lighter than the dunes, so the roads read from afar.
const ROAD_SURFACE := Color(0.66, 0.6, 0.5)


func _roads() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tarmac := ROAD_SURFACE.srgb_to_linear()
	var ink := ComicUI.INK.srgb_to_linear()
	var rut := ROAD_SURFACE.darkened(0.22).srgb_to_linear()
	for road: Array in WorldLayout.roads():
		var pts := WorldLayout.road_samples(road, 1.5)
		for i in pts.size() - 1:
			if i > 0 and i % 64 == 0:  # a section per ~100 m, batched by where it is
				_road_section(st, pts[i][0])
				st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var a: Vector2 = pts[i][0]
			var b: Vector2 = pts[i + 1][0]
			var da: Vector2 = pts[i][1]
			var db: Vector2 = pts[i + 1][1]
			var na := Vector2(-da.y, da.x)
			var nb := Vector2(-db.y, db.x)
			_strip(st, a, b, na, nb, -ROAD_HALF, ROAD_HALF, 0.06, tarmac)
			for side in [-1.0, 1.0]:
				_strip(st, a, b, na, nb, side * ROAD_HALF - 0.35 * side, side * ROAD_HALF, 0.08, ink)  # the inked edge
				_strip(st, a, b, na, nb, side * 1.6 - 0.45, side * 1.6 + 0.45, 0.07, rut)  # a wheel rut
				_skirt(st, a, b, na, nb, side * ROAD_HALF, ink)  # no gap under the edge, from any angle
		_road_section(st, pts[pts.size() - 1][0])
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)


## A stretch of road into the batches: no outline (it's flat), drawn to 300 m.
func _road_section(st: SurfaceTool, near: Vector2) -> void:
	st.generate_normals()
	var arrays := st.commit_to_arrays()
	if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] != null and (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		batches.add_arrays(arrays, Transform3D.IDENTITY, 300.0, false, WorldTerrain.at(near.x, near.y))


## The road's side from its edge (offset `o` across) down into the ground.
func _skirt(st: SurfaceTool, a: Vector2, b: Vector2, na: Vector2, nb: Vector2, o: float, col: Color) -> void:
	var pa := a + na * o
	var pb := b + nb * o
	var ta := WorldTerrain.at(pa.x, pa.y) + Vector3(0, 0.06, 0)
	var tb := WorldTerrain.at(pb.x, pb.y) + Vector3(0, 0.06, 0)
	var v: Array[Vector3] = [ta, tb, tb - Vector3(0, 0.7, 0), ta - Vector3(0, 0.7, 0)]
	st.set_color(col)
	for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:  # both faces
		st.add_vertex(v[idx])


## A quad from a to b, between offsets `l` and `r` across, `lift` above the
## ground, laid exactly on it: cut along the ground's grid (its cells and
## their diagonals, as WorldTerrain.surface and the physics split them), so
## each piece lies in one flat triangle of the ground you walk on. (A quad
## laid corner to corner cuts across the ground's creases: feet sink into
## the tarmac on one side of a crease, the ground shows through on the other.)
func _strip(st: SurfaceTool, a: Vector2, b: Vector2, na: Vector2, nb: Vector2, l: float, r: float, lift: float, col: Color) -> void:
	var quad := PackedVector2Array([a + na * l, a + na * r, b + nb * r, b + nb * l])
	var lo := Vector2(INF, INF)
	var hi := -lo
	for q: Vector2 in quad:
		lo = lo.min(q)
		hi = hi.max(q)
	var step := WorldTerrain.STEP
	var half := WorldTerrain.SIZE * 0.5
	st.set_color(col)
	for j in range(floori((lo.y + half) / step), floori((hi.y + half) / step) + 1):
		for i in range(floori((lo.x + half) / step), floori((hi.x + half) / step) + 1):
			var x0 := -half + i * step
			var z0 := -half + j * step
			var c00 := Vector2(x0, z0)
			var c10 := Vector2(x0 + step, z0)
			var c01 := Vector2(x0, z0 + step)
			var c11 := Vector2(x0 + step, z0 + step)
			for tri: PackedVector2Array in [PackedVector2Array([c00, c10, c01]), PackedVector2Array([c10, c11, c01])]:
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(quad, tri):
					var v: Array[Vector3] = []
					for q: Vector2 in piece:
						v.append(WorldTerrain.at(q.x, q.y) + Vector3(0, lift, 0))
					for k in range(1, v.size() - 1):
						# Face up (+Y), whichever way round the piece came.
						var up := (v[k] - v[0]).cross(v[k + 1] - v[0]).y < 0.0
						st.add_vertex(v[0])
						st.add_vertex(v[k] if up else v[k + 1])
						st.add_vertex(v[k + 1] if up else v[k])


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
	var box := BoxMesh.new()
	box.size = Vector3(size.x, depth, size.y)
	batches.add_mesh(CityMode._tinted(box, Color(0.36, 0.32, 0.3)), Transform3D(b, at + Vector3(0, -depth * 0.5 + 0.06, 0)), 380.0)


## The ground (TerrainMesh) in TERRAIN_TILE squares, each with its own
## detail levels.
const TERRAIN_TILE := 320.0
## Coarser detail levels sooner: smooth dunes lose little, and the ground was
## a third of a frame's triangles.
const TERRAIN_LOD_BIAS := 0.35


func _terrain(mat: Material) -> void:
	for t: Array in TerrainMesh.build(TERRAIN_TILE):
		var out := MeshInstance3D.new()
		out.name = t[0]
		out.mesh = Comic.compact_mesh(t[1], true)
		out.lod_bias = TERRAIN_LOD_BIAS
		out.material_override = mat
		add_child(out)
