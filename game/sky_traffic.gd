class_name SkyTraffic
extends Node3D
## Rotorcraft in Titan's sky (presentation only): Skyhoppers lift off the
## Skyport's pads, climb, fly their rounds over the districts at cruise
## height, come back and land; two more fly long loops round the valley
## without landing. Their hops are set by the clock, so every player sees
## the same flights.

const CRUISE := 85.0       ## metres above the basin's floor level (y = 0)
const SPEED := 26.0        ## m/s along the route
const CLIMB_SPEED := 7.0   ## m/s up from and down to a pad
const ON_PAD := 14.0       ## seconds parked between rounds

## [pad (x, z from the Skyport's centre) or null for a flyer that never
## lands, the places it flies over in turn].
static func routes() -> Array:
	var city := Vector2(CityLayout.ORIGIN.x, CityLayout.ORIGIN.z)
	var hollow := Vector2(WorldLayout.HOLLOW.x, WorldLayout.HOLLOW.z)
	return [
		[Vector2(-60, -40), [WorldLayout.HELIOS, WorldLayout.GALLERIA, city]],
		[Vector2(60, -40), [hollow, WorldLayout.TERRACE, city]],
		[null, [WorldLayout.HELIOS, WorldLayout.GALLERIA, WorldLayout.TERRACE, hollow, WorldLayout.SKYPORT]],
		[null, [hollow, Vector2(238, 165), WorldLayout.TERRACE, city, WorldLayout.SKYPORT]],
	]

var _flights: Array = []  ## [node, path (Array[Vector3]), length, pause at the start (s), period (s)]


func _ready() -> void:
	for r: Array in routes():
		var path: Array[Vector3] = []
		var stops: Array = r[1]
		if r[0] != null:
			var pad := WorldLayout.SKYPORT + (r[0] as Vector2)
			var ground := WorldTerrain.at(pad.x, pad.y) + Vector3(0, 0.4, 0)
			path.append(ground)
			path.append(Vector3(ground.x, CRUISE, ground.z))
			for c: Vector2 in stops:
				path.append(Vector3(c.x, CRUISE, c.y))
			path.append(Vector3(ground.x, CRUISE, ground.z))
			path.append(ground)
		else:
			for c: Vector2 in stops:
				path.append(Vector3(c.x, CRUISE + 25.0, c.y))
			path.append(path[0])
		var length := 0.0
		for i in path.size() - 1:
			length += _leg_time(path[i], path[i + 1])
		var hopper := Comic.kit_instance("world/skyhopper", path[0], 0.0, 1.0)
		hopper.visibility_range_end = 1400.0
		add_child(hopper)
		var pause := ON_PAD if r[0] != null else 0.0
		_flights.append([hopper, path, length, pause, length + pause])


## Seconds to fly a leg: up and down at the climb rate, across at speed.
static func _leg_time(a: Vector3, b: Vector3) -> float:
	var flat := Vector2(b.x - a.x, b.z - a.z).length()
	return maxf(flat / SPEED, absf(b.y - a.y) / CLIMB_SPEED) + 0.01


func _process(dt: float) -> void:
	var now := Time.get_unix_time_from_system()
	for i in _flights.size():
		var f: Array = _flights[i]
		var node: Node3D = f[0]
		var path: Array = f[1]
		var t := fposmod(now + i * 37.0, float(f[4])) - float(f[3])
		if t < 0.0:
			node.position = path[0]  # parked on its pad
			continue
		for k in path.size() - 1:
			var leg := _leg_time(path[k], path[k + 1])
			if t <= leg:
				var a: Vector3 = path[k]
				var b: Vector3 = path[k + 1]
				var s := smoothstep(0.0, 1.0, t / leg) if absf(b.y - a.y) > 1.0 else t / leg
				node.position = a.lerp(b, s)
				var dir := Vector2(b.x - a.x, b.z - a.z)
				if dir.length() > 1.0:
					var yaw := atan2(-dir.x, -dir.y)
					node.rotation.y = lerp_angle(node.rotation.y, yaw, minf(dt * 2.0, 1.0))
					node.rotation.x = -0.12  # nose down, flying forward
				else:
					node.rotation.x = 0.0
				break
			t -= leg
