class_name RoverVisuals
extends Node
## The rovers' bodies in Kasei Valley (free roam and runs at the dig): at
## the driver (drawn smoothly between ticks) or where they're parked, sitting
## on the slope of the ground under them. Their wheels turn with the ground
## they cover and the front pair steers into a turn; on dust they leave tyre
## tracks and kick up a little dust. Also tells the camera when the local
## player drives. A child of the match.

## Where each model's wheels go (Godot axes, the hub's height in y), and
## which of them steer (the front pair: most negative z).
const WHEELS := {
	"world/rover": [0.55, [Vector3(-1.25, 0, -1.55), Vector3(1.25, 0, -1.55), Vector3(-1.25, 0, 0), Vector3(1.25, 0, 0),
			Vector3(-1.25, 0, 1.55), Vector3(1.25, 0, 1.55)]],
	"world/buggy": [0.62, [Vector3(-1.2, 0, -1.15), Vector3(1.2, 0, -1.15), Vector3(-1.2, 0, 1.15), Vector3(1.2, 0, 1.15)]],
	"world/hauler": [0.6, [Vector3(-1.35, 0, -2.45), Vector3(1.35, 0, -2.45), Vector3(-1.35, 0, -1.1), Vector3(1.35, 0, -1.1),
			Vector3(-1.35, 0, 1.5), Vector3(1.35, 0, 1.5), Vector3(-1.35, 0, 2.7), Vector3(1.35, 0, 2.7)]],
}
const MAX_STEER := 0.5        ## radians, the front wheels at full lock
const MARK_EVERY := 0.45      ## metres between tyre marks
const MARKS := 3000           ## tyre marks kept in the world (oldest go first)
## Where the ground is paved (no tracks): these regions and the roads.
const PAVED := ["city", "helios", "terrace", "skyport", "galleria"]

var _rovers: Array[MeshInstance3D] = []
var _models: Array[int] = []  ## the model each body was built for
var _wheels: Array = []       ## per rover: [[pivot, steers, spin node], ...]
var _prev: Array = []         ## per rover: [position, yaw, distance since a mark]
var _spin: Array = []         ## per rover: wheel turn (radians)
var _dust: Array[GPUParticles3D] = []
var _marks: MultiMeshInstance3D
var _mark_i: int = 0
var _road_cells := {}


func _process(delta: float) -> void:
	var m := get_parent()
	if m.server == null:
		return
	var world: SimWorld = m.server.world
	var vehicles: Array[SimVehicle] = world.vehicles
	while _rovers.size() < vehicles.size():
		var mi := Comic.kit_instance("world/rover", Vector3.ZERO, 0.0)
		m.add_child(mi)
		_rovers.append(mi)
		_models.append(-1)
		_wheels.append([])
		_prev.append([Vector3.INF, 0.0, 0.0])
		_spin.append(0.0)
		var dust := _dust_emitter()
		m.add_child(dust)
		_dust.append(dust)
	if _marks == null:
		_marks = _make_marks()
		m.add_child(_marks)
		for road: Array in WorldLayout.roads():
			for sm: Array in WorldLayout.road_samples(road, 2.0):
				var q: Vector2 = sm[0]
				for dx in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						_road_cells[Vector2i(floori(q.x / 4.0) + dx, floori(q.y / 4.0) + dz)] = true
	for i in vehicles.size():
		if _models[i] != vehicles[i].model:  # a different model (the factory sold one)
			_models[i] = vehicles[i].model
			_build(i, VehicleSim.MODELS[clampi(_models[i], 0, VehicleSim.MODELS.size() - 1)].kit)
			_armour(i, _models[i])
	var me := world.get_player(ServerSession.LOCAL_PLAYER_ID)
	m.view.driving = me != null and me.state.vehicle >= 0
	var visuals: Dictionary = m._visuals
	for i in vehicles.size():
		var v := vehicles[i]
		var at := v.position
		if v.driver != 0 and visuals.has(v.driver):
			at = (visuals[v.driver] as Node3D).global_position
		var mi := _rovers[i]
		# Your own rides wear your paint job (the Style menu).
		var paint: Variant = CityStyle.paint_color() if v.owner == ServerSession.LOCAL_PLAYER_ID else null
		var want: Material = Comic.kit_material_paint(paint) if paint != null else Comic.kit_material()
		if mi.material_override != want:
			mi.material_override = want
		if VehicleSim.flies(v.model):
			_fly_pose(i, v, mi, at, world, delta)
			continue
		var up := ground_normal(at.x, at.z)
		var fwd := Vector3(-sin(v.yaw), 0.0, -cos(v.yaw))
		var right := fwd.cross(up).normalized()
		fwd = up.cross(right).normalized()
		var target := Basis(right, up, -fwd)
		mi.basis = mi.basis.orthonormalized().slerp(target, minf(delta * 10.0, 1.0)) if mi.position != Vector3.ZERO else target
		mi.position = Vector3(at.x, WorldTerrain.surface(at.x, at.z), at.z)
		_animate(i, v, mi, delta)
		_aim_turret(v, mi, m, delta)


## An aircraft: where it is (in the air: no ground under it), nose up when
## climbing, banked into a turn. Parked, it sits on the ground.
func _fly_pose(i: int, v: SimVehicle, mi: MeshInstance3D, at: Vector3, world: SimWorld, delta: float) -> void:
	var ground := WorldTerrain.surface(at.x, at.z)
	if v.driver == 0:
		if v.position.y > ground + 0.05:  # left in the air: it settles on its gear
			v.position.y = ground + 0.05
		at = Vector3(at.x, ground, at.z)
	var pitch := 0.0
	var roll := 0.0
	var d: SimPlayer = world.players.get(v.driver) if v.driver != 0 else null
	if d != null:
		var speed := maxf(absf(d.state.vehicle_speed), 8.0)
		pitch = clampf(atan2(d.state.velocity.y, speed), -0.5, 0.5)
		var prev: Array = _prev[i]
		var turn := wrapf(v.yaw - float(prev[1]), -PI, PI) / maxf(delta, 0.001) if prev[0] != Vector3.INF else 0.0
		roll = clampf(turn * 0.35, -0.6, 0.6)
	var target := Basis.from_euler(Vector3(pitch, v.yaw, roll), EULER_ORDER_YXZ)
	mi.basis = mi.basis.orthonormalized().slerp(target, minf(delta * 6.0, 1.0)) if mi.position != Vector3.ZERO else target
	mi.position = at if v.driver != 0 else Vector3(at.x, ground, at.z)
	_prev[i] = [mi.position, v.yaw, 0.0]
	_dust[i].emitting = false


## A tank's turret: where its driver looks (you, driving it), else a slow
## watchful sweep.
func _aim_turret(v: SimVehicle, mi: MeshInstance3D, m: Node, delta: float) -> void:
	if v.model != VehicleSim.TANK:
		return
	var turret := mi.get_node_or_null("Armour/Turret") as Node3D
	if turret == null:
		return
	var want := turret.rotation.y + delta * 0.25
	if v.driver == ServerSession.LOCAL_PLAYER_ID:
		want = wrapf(float(m.input.look_yaw) - v.yaw, -PI, PI)
	turret.rotation.y = lerp_angle(turret.rotation.y, want, minf(delta * 4.0, 1.0))


## The body without wheels, and a pivot per wheel (the mesh under it, its
## hub at the pivot), for model `kit`.
## The army's machines (HuntArmy) dressed for war: a tank gets a turret
## and armour, a crawler its drill and plating.
func _armour(i: int, model: int) -> void:
	var mi := _rovers[i]
	var old := mi.get_node_or_null("Armour")
	if old != null:
		old.queue_free()
	if model != VehicleSim.TANK:
		return  # the crawler's body is its own model (army/crawler)
	# The tank's turret: its own piece on the hull's ring, so it can turn.
	var root := Node3D.new()
	root.name = "Armour"
	mi.add_child(root)
	var turret := Comic.kit_instance("army/tank_turret", Vector3(0, 1.36, 0.15), 0.0)
	turret.name = "Turret"
	root.add_child(turret)


func _build(i: int, kit: String) -> void:
	var mi := _rovers[i]
	mi.mesh = Comic.kit_mesh_lod(kit)
	_wheels[i] = add_wheels(mi, kit)


## Puts model `kit`'s wheels on body `mi` (any vehicle drawn anywhere: the
## valley's traffic, the showroom): [[steering pivot, steers, wheel], ...].
## Wheels aren't drawn past this (metres): the body carries the vehicle.
const WHEEL_RANGE := 45.0


static func add_wheels(mi: Node3D, kit: String) -> Array:
	var out := []
	for c in mi.get_children():
		if c.name.begins_with("Wheel"):
			c.queue_free()
	if not WHEELS.has(kit):
		return out
	var r: float = WHEELS[kit][0]
	var front := 0.0
	for p: Vector3 in WHEELS[kit][1]:
		front = minf(front, p.z)
	for p: Vector3 in WHEELS[kit][1]:
		var pivot := Node3D.new()  # steers (about Y)
		pivot.name = "Wheel"
		pivot.position = Vector3(p.x, r, p.z)
		mi.add_child(pivot)
		var wheel := Comic.kit_instance(kit + ("_wheel_l" if p.x < 0.0 else "_wheel_r"), Vector3.ZERO, 0.0)
		# Dark tyres: no outline pass (one draw, not two), and none from afar.
		wheel.material_override = Comic.kit_material_plain()
		wheel.visibility_range_end = WHEEL_RANGE
		pivot.add_child(wheel)  # spins (about X)
		out.append([pivot, absf(p.z - front) < 0.01, wheel])
	return out


## Wheels turn by the distance covered (backwards in reverse), the front
## pair steers by how fast the rover is turning; tyre marks and dust on dirt.
func _animate(i: int, v: SimVehicle, mi: MeshInstance3D, delta: float) -> void:
	var prev: Array = _prev[i]
	var pos := mi.position
	if prev[0] == Vector3.INF:
		_prev[i] = [pos, v.yaw, 0.0]
		return
	var moved := pos - (prev[0] as Vector3)
	if moved.length() > 8.0:  # a teleport, not a drive
		_prev[i] = [pos, v.yaw, 0.0]
		return
	var fwd := Vector3(-sin(v.yaw), 0.0, -cos(v.yaw))
	var dist := moved.dot(fwd)
	var turn := wrapf(v.yaw - float(prev[1]), -PI, PI)
	var steer := 0.0
	if absf(dist) > 0.001:
		steer = clampf(turn / maxf(absf(dist), 0.05) * 2.2 * signf(dist), -MAX_STEER, MAX_STEER)
	var kit: String = VehicleSim.MODELS[clampi(_models[i], 0, VehicleSim.MODELS.size() - 1)].kit
	var r: float = WHEELS[kit][0] if WHEELS.has(kit) else 0.6
	_spin[i] = fmod(float(_spin[i]) - dist / r, TAU)
	for w: Array in _wheels[i]:
		var pivot: Node3D = w[0]
		if w[1]:
			pivot.rotation.y = lerp_angle(pivot.rotation.y, steer, minf(delta * 8.0, 1.0))
		(w[2] as Node3D).rotation.x = _spin[i]
	var speed := moved.length() / maxf(delta, 0.0001)
	var region := WorldLayout.region_at(pos.x, pos.z)
	var dirt := not region in PAVED and not _road_cells.has(Vector2i(floori(pos.x / 4.0), floori(pos.z / 4.0)))
	_dust[i].global_position = pos - fwd * 2.0 + Vector3(0, 0.3, 0)
	_dust[i].emitting = dirt and speed > 4.0
	var since: float = float(prev[2]) + absf(dist)
	if dirt and WHEELS.has(kit) and absf(dist) > 0.0001:
		# A print every MARK_EVERY metres along the way covered this frame
		# (at speed that's several), each where the rear tyres were then.
		var wheels: Array = WHEELS[kit][1]
		var back: Vector3 = wheels[wheels.size() - 1]
		var from: Vector3 = prev[0]
		while since >= MARK_EVERY:
			since -= MARK_EVERY
			var t := clampf(1.0 - since / absf(dist), 0.0, 1.0)
			var at := from.lerp(pos, t)
			var yaw := lerp_angle(float(prev[1]), v.yaw, t)
			var b := Basis(Vector3.UP, yaw)
			for side in [-1.0, 1.0]:
				_mark(b * Vector3(side * absf(back.x), 0.0, back.z) + at, yaw)
	elif not dirt:
		since = 0.0
	_prev[i] = [pos, v.yaw, since]


func _mark(at: Vector3, yaw: float) -> void:
	var y := WorldTerrain.surface(at.x, at.z) + 0.03
	var up := ground_normal(at.x, at.z)
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := fwd.cross(up).normalized()
	fwd = up.cross(right).normalized()
	var xf := Transform3D(Basis(right, up, -fwd), Vector3(at.x, y, at.z))
	_marks.multimesh.set_instance_transform(_mark_i, xf)
	_mark_i = (_mark_i + 1) % MARKS
	if _marks.multimesh.visible_instance_count < MARKS:
		_marks.multimesh.visible_instance_count = maxi(_marks.multimesh.visible_instance_count, _mark_i)


## Tyre marks: one flat tread print per instance (a darker band of dust).
func _make_marks() -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := PlaneMesh.new()
	q.size = Vector2(0.42, 0.62)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.09, 0.05, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Tread bars across the print.
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0.35))
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 8
	tex.height = 32
	tex.fill_to = Vector2(0, 0.25)
	tex.repeat = GradientTexture2D.REPEAT
	mat.albedo_texture = tex
	q.material = mat
	mm.mesh = q
	mm.instance_count = MARKS
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _dust_emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, -0.4, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.78, 0.5, 0.32, 0.45))
	ramp.set_color(1, Color(0.78, 0.5, 0.32, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	var puff := Gradient.new()
	puff.set_color(0, Color(1, 1, 1, 1))
	puff.set_color(1, Color(1, 1, 1, 0))
	var pt := GradientTexture2D.new()
	pt.gradient = puff
	pt.fill = GradientTexture2D.FILL_RADIAL
	pt.fill_from = Vector2(0.5, 0.5)
	pt.fill_to = Vector2(0.5, 0.0)
	qm.albedo_texture = pt
	q.material = qm
	p.draw_pass_1 = q
	p.amount = 24
	p.lifetime = 1.4
	p.emitting = false
	return p


static func ground_normal(x: float, z: float) -> Vector3:
	var gx := (WorldTerrain.height(x + 1.5, z) - WorldTerrain.height(x - 1.5, z)) / 3.0
	var gz := (WorldTerrain.height(x, z + 1.5) - WorldTerrain.height(x, z - 1.5)) / 3.0
	return Vector3(-gx, 1.0, -gz).normalized()
