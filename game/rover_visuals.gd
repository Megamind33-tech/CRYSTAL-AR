class_name RoverVisuals
extends Node
## The rovers' bodies in Kasei Valley (free roam and runs at the dig): at
## the driver (drawn smoothly between ticks) or where they're parked, sitting
## on the slope of the ground under them. Also tells the camera when the
## local player drives. A child of the match.

var _rovers: Array[MeshInstance3D] = []
var _models: Array[int] = []  ## the model each body was built for


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
		_models.append(0)
	for i in vehicles.size():
		if _models[i] != vehicles[i].model:  # a different model (the factory sold one)
			_models[i] = vehicles[i].model
			_rovers[i].mesh = Comic.kit_mesh(VehicleSim.MODELS[clampi(_models[i], 0, VehicleSim.MODELS.size() - 1)].kit)
	var me := world.get_player(ServerSession.LOCAL_PLAYER_ID)
	m.view.driving = me != null and me.state.vehicle >= 0
	var visuals: Dictionary = m._visuals
	for i in vehicles.size():
		var v := vehicles[i]
		var at := v.position
		if v.driver != 0 and visuals.has(v.driver):
			at = (visuals[v.driver] as Node3D).global_position
		var mi := _rovers[i]
		var up := ground_normal(at.x, at.z)
		var fwd := Vector3(-sin(v.yaw), 0.0, -cos(v.yaw))
		var right := fwd.cross(up).normalized()
		fwd = up.cross(right).normalized()
		var target := Basis(right, up, -fwd)
		mi.basis = mi.basis.orthonormalized().slerp(target, minf(delta * 10.0, 1.0)) if mi.position != Vector3.ZERO else target
		mi.position = Vector3(at.x, WorldTerrain.height(at.x, at.z), at.z)


static func ground_normal(x: float, z: float) -> Vector3:
	var gx := (WorldTerrain.height(x + 1.5, z) - WorldTerrain.height(x - 1.5, z)) / 3.0
	var gz := (WorldTerrain.height(x, z + 1.5) - WorldTerrain.height(x, z - 1.5)) / 3.0
	return Vector3(-gx, 1.0, -gz).normalized()
