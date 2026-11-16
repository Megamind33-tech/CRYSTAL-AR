class_name CityEvents
extends RefCounted
## Things that happen out in Kasei Valley (free roam, with CityMode): every
## few minutes something turns up somewhere on the open ground, announced
## and marked on the minimap until it's taken or it's gone. A supply pod
## knocked out of orbit; a meteor fall with fragments to gather; a Concern
## hauler broken down with its cargo and two guards who won't hand it over.

const EVERY := Vector2(240.0, 420.0)    ## seconds between events
const LASTS := 300.0                     ## seconds an event stays
const REACH := 3.0
const KINDS := ["pod", "meteor", "convoy"]

var city: CityMode
var kind: String = ""
var at := Vector3.ZERO
var spots: Array = []            ## [position, taken] for fragments / the pod / the hold
var guards: RaidDirector
var _next: float = 90.0
var _left: float = 0.0
var _props: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _init(p_city: CityMode) -> void:
	city = p_city
	_rng.randomize()


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


func fighters() -> Array[int]:
	var out: Array[int] = []
	if guards != null:
		out.append_array(guards.raiders)
	return out


func in_fight() -> bool:
	return guards != null and guards.raiders_left() > 0 and _engaged


var _engaged: bool = false


func update(me: SimPlayer, busy: bool) -> String:
	var dt := city.match_node.get_process_delta_time()
	if kind.is_empty():
		_next -= dt
		if _next <= 0.0:
			_start(me)
		return ""
	_left -= dt
	if _left <= 0.0 or spots.all(func(s: Array) -> bool: return s[1]):
		_end()
		return ""
	if guards != null:
		if not _engaged and me.state.position.distance_to(at) < 45.0:
			_engaged = true
			for id: int in guards.raiders:
				var brain: Variant = city.match_node.server.bots.get(id)
				if brain != null and "hunt" in brain:
					brain.hunt = true
			guards.step()
			city._sync_combat()
		if _engaged:
			var state := guards.step()
			if state == 2:  # they got you
				_end()
				return ""
	if busy or me.state.vehicle >= 0:
		return ""
	for i in spots.size():
		if not spots[i][1] and me.state.position.distance_to(spots[i][0]) < REACH:
			return "event:%d" % i
	return ""


func _start(me: SimPlayer, which: String = "") -> void:
	kind = which if not which.is_empty() else KINDS[_rng.randi() % KINDS.size()]
	# Somewhere open, 180-420 m from you, inside the basin.
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(180.0, 420.0)
	var x := clampf(me.state.position.x + cos(a) * r, -650.0, 650.0)
	var z := clampf(me.state.position.z + sin(a) * r, -650.0, 650.0)
	at = WorldTerrain.at(x, z)
	_left = LASTS
	spots.clear()
	_engaged = false
	match kind:
		"pod":
			spots.append([at, false])
			_prop("world/freighter_wreck", at, 0.18)
		"meteor":
			for k in 4:
				var b := k * TAU / 4.0 + 0.4
				var p := WorldTerrain.at(at.x + cos(b) * 9.0, at.z + sin(b) * 9.0)
				spots.append([p, false])
				_rock(p)
		"convoy":
			var hold := at + Vector3(0, 0, 3.4)
			spots.append([hold, false])
			_prop("world/hauler", at, 1.0)
			city._bake_around(at)
			guards = RaidDirector.new(city.match_node.server)
			for k in 2:
				var g := WorldTerrain.at(at.x + (k * 2 - 1) * 5.0, at.z - 4.0)
				guards.raiders.append(guards._bot("Concern·Driver %d" % (k + 1), 1, false, g + Vector3(0, 0.3, 0), "concern"))
	city._flash_text(_t("EVENT_" + kind.to_upper()) % _direction(me), ComicUI.CYAN)


func _direction(me: SimPlayer) -> String:
	var d := Vector2(at.x - me.state.position.x, at.z - me.state.position.z)
	return "%s, %d m" % [CityBounty._compass(d), roundi(d.length())]


func _prop(piece: String, pos: Vector3, scale: float) -> void:
	var mi := Comic.kit_instance(piece, pos, _rng.randf() * 360.0, scale)
	city.match_node.add_child(mi)
	_props.append(mi)
	var smoke := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0.6, 0.2, 0)
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	pm.color = Color(0.25, 0.2, 0.2, 0.5)
	smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	qm.albedo_texture = tex
	q.material = qm
	smoke.draw_pass_1 = q
	smoke.amount = 30
	smoke.lifetime = 6.0
	smoke.visibility_aabb = AABB(Vector3(-20, -2, -20), Vector3(40, 60, 40))
	smoke.position = pos + Vector3(0, 1.5, 0)
	city.match_node.add_child(smoke)
	_props.append(smoke)


func _rock(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.8
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = CityMode._tinted(sm, Color(0.28, 0.22, 0.24))
	mi.material_override = Comic.kit_material(0.02)
	mi.position = pos + Vector3(0, 0.25, 0)
	city.match_node.add_child(mi)
	_props.append(mi)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.2)
	glow.light_energy = 1.2
	glow.omni_range = 4.0
	glow.position = pos + Vector3(0, 0.8, 0)
	city.match_node.add_child(glow)
	_props.append(glow)


func prompt(key: String) -> String:
	return _t("EVENT_PROMPT_" + kind.to_upper())


func act(key: String, _me: SimPlayer) -> void:
	var i := int(key.get_slice(":", 1))
	if i >= spots.size() or spots[i][1]:
		return
	var c := Profile.career()
	var got := {}
	match kind:
		"pod":
			got = {"supply_crate": 2, "oxygen_canister": 2, "medkit": 1, "cred_chip": 3}
		"meteor":
			got = {"rare_ore": 1, "scrap": 1}
		"convoy":
			if guards != null and guards.raiders_left() > 0:
				city._note(_t("EVENT_GUARDED"), ComicUI.YELLOW)
				return
			got = {"refined_ingot": 2, "helium3": 1, "supply_crate": 2}
			city.crime("convoy")
	spots[i][1] = true
	var parts := PackedStringArray()
	for item: String in got:
		c.receive(item, int(got[item]))
		parts.append("%d× %s" % [got[item], Career.ITEMS[item].name])
	Profile.save()
	city._note(_t("EVENT_TOOK") % ", ".join(parts), ComicUI.GREEN)


func _end() -> void:
	for n: Node3D in _props:
		if is_instance_valid(n):
			n.queue_free()
	_props.clear()
	if guards != null:
		guards.finish()
		guards = null
		city._sync_combat()
	kind = ""
	spots.clear()
	_next = _rng.randf_range(EVERY.x, EVERY.y)


## On the minimap: a star where it is (at the edge if it's off the map).
func map_places() -> Array:
	if kind.is_empty():
		return []
	return [[at, "*", ComicUI.CYAN]]
