class_name HuntVisuals
extends Node3D
## THE HUNT's world markers (presentation only, fed from HuntRules on the
## host): each treasure is a glowing case (gold: the grand treasure; green:
## the local hunter's own assignments; blue: rivals'), floating over its
## carrier's head while carried; tall beams mark our own assignments and
## the grand treasure so they can be found across the 150 m yard; labelled
## rings mark the extraction pads; the alarm trap pulses red.

const GRAND := Color(1.0, 0.78, 0.25)
const OWN := Color(0.35, 1.0, 0.5)
const RIVAL := Color(0.45, 0.7, 1.0)
const ALARM := Color(1.0, 0.25, 0.2)
const CACHE := Color(1.0, 0.55, 0.15)
const INTEL := Color(0.75, 0.55, 1.0)
const CARRIED_LIFT := 2.3
const BEAM_HEIGHT := 40.0

var _cases: Dictionary = {}  ## treasure id -> Node3D
var _beams: Dictionary = {}  ## treasure id -> MeshInstance3D
var _built: bool = false
var _trap: MeshInstance3D
var _rings: Array[MeshInstance3D] = []
var _wanted_marks: Array[Node3D] = []
var _zone_labels: Array[Label3D] = []
var _zone_beams: Array[MeshInstance3D] = []
var _clue_mark: Node3D
var _cache_nodes: Dictionary = {}  ## cache id -> Node3D
var _ally_mark: Label3D
var _intel_marks: Array[Node3D] = []
var _time: float = 0.0
## The ore crates' armour: the outpost's PBR metal (CC0, art/ASSETS.csv).
var _crate_metal: StandardMaterial3D


func _process(delta: float) -> void:
	_time += delta
	for node: Node3D in _cases.values():
		var case: Node3D = node.get_node("Case")
		case.rotation.y = _time * 1.2
		case.position.y = 0.55 + sin(_time * 2.4 + node.get_index()) * 0.1
	if _trap != null:
		_trap.scale = Vector3.ONE * (1.0 + sin(_time * 5.0) * 0.06)
	for r in _rings:  # extraction pads breathe so they read from afar
		var k := 1.0 + sin(_time * 2.2) * 0.05
		r.scale = Vector3(k, 1.0, k)
	for i in _pickups.size():  # the rotorcraft holding over each pad
		var hop: Node3D = _pickups[i]
		hop.position.y = _pickup_base[i] + sin(_time * 0.9 + i) * 0.35
		hop.rotation.y += delta * 0.12


## `local_id`: whose assignments count as "ours". `carrier_pos`:
## Callable(id) -> Vector3 for where a carrier is drawn (INF if unknown).
## Online (a client): cases on the ground glide to where the host says;
## further than SMOOTH_SNAP they jump (home again, a new case).
var smooth_cargo := false
const SMOOTH_SNAP := 12.0
const SMOOTH_RATE := 10.0


func sync(hunt: HuntRules, tick: int, local_id: int, carrier_pos: Callable) -> void:
	if not _built:
		_build_static(hunt)
	_sync_war(hunt, local_id)
	_sync_army(hunt, tick)
	_aim_flak(hunt, tick, local_id, get_process_delta_time())
	var seen := {}
	for t: HuntRules.Treasure in hunt.treasures:
		seen[t.id] = true
		var color := _color_of(t, local_id)
		var node: Node3D = _cases.get(t.id)
		if node == null:
			node = _make_case(color, t.kind == HuntRules.Kind.GRAND)
			add_child(node)
			_cases[t.id] = node
		# Stowed in a vehicle's hold: out of sight (no case, no beam) for everyone.
		var hidden := t.banked or t.vehicle >= 0 or (t.kind == HuntRules.Kind.GRAND and tick < t.available_tick)
		node.visible = not hidden
		var pos := t.position
		if t.carrier != 0:
			var at: Vector3 = carrier_pos.call(t.carrier)
			if at != Vector3.INF:
				pos = at
			pos += Vector3(0, CARRIED_LIFT - 0.55, 0)
		if smooth_cargo and t.carrier == 0 and node.position.distance_to(pos) < SMOOTH_SNAP:
			# Online: glide between the host's updates (a few a second) instead of jumping.
			node.position = node.position.lerp(pos, clampf(get_process_delta_time() * SMOOTH_RATE, 0.0, 1.0))
		else:
			node.position = pos
		pos = node.position
		if t.kind == HuntRules.Kind.GRAND:
			_update_lock_label(node, hunt, t)
		# Beams: our own treasures and the grand one, while on the ground or
		# carried by someone else (follow the thief).
		var wants_beam := not hidden and t.carrier != local_id and (t.kind != HuntRules.Kind.PERSONAL or t.owner == local_id)
		var beam: MeshInstance3D = _beams.get(t.id)
		if wants_beam and beam == null:
			beam = _make_beam(color)
			add_child(beam)
			_beams[t.id] = beam
		if beam != null:
			beam.visible = wants_beam
			beam.position = Vector3(pos.x, BEAM_HEIGHT * 0.5, pos.z)
	for id: int in _cases.keys():
		if not seen.has(id):
			_cases[id].queue_free()
			_cases.erase(id)
			if _beams.has(id):
				_beams[id].queue_free()
				_beams.erase(id)
	if _trap != null:
		_trap.visible = hunt.trap_rearm_tick == 0
	if str(hunt.zones) != _pads_key:
		_build_pads(hunt)
	# Last Extraction: closed pads go dark; the last one says so. In a war
	# each camp's pad is its own: yours in your colour, theirs in theirs.
	for i in _zone_labels.size():
		if not hunt.zone_sides.is_empty() and i < hunt.zone_sides.size():
			var mine := hunt.may_use_zone(i, local_id)
			var col := _side_color(hunt, int(hunt.zone_sides[i]), local_id)
			_zone_labels[i].modulate = col
			_zone_labels[i].text = tr("WAR_PAD_YOURS") if mine else tr("WAR_PAD_THEIRS")
			continue
		var open := hunt.zone_open(i, tick)
		_rings[i].visible = open
		_zone_beams[i].visible = open
		_zone_labels[i].modulate = OWN if open else Color(0.5, 0.5, 0.5)
		_zone_labels[i].text = tr("HUNT_EXTRACT_CLOSED") if not open \
				else (tr("HUNT_EXTRACT_LAST") if hunt.final_phase(tick) and i == hunt.final_zone else tr("HUNT_EXTRACT_LABEL"))
	_sync_last_known(hunt.social, tick, local_id)
	_sync_clue(hunt, tick, local_id)
	_sync_caches(hunt)
	_sync_ally(hunt, local_id, carrier_pos)
	_sync_intel(hunt, tick, local_id)


## Informant: a violet ring at each live report with a position, labelled
## with its kind, confidence and age.
func _sync_intel(hunt: HuntRules, tick: int, local_id: int) -> void:
	var shown := 0
	for r: Dictionary in hunt.economy.intel_of(local_id, tick):
		if r.position == Vector3.INF or r.kind == "vault_status" or not hunt.intel_useful(r, tick):
			continue
		if shown >= _intel_marks.size():
			var mark := _make_wanted_mark()
			(mark.get_child(0) as MeshInstance3D).material_override = _glow(INTEL, 0.6, 2.0)
			(mark.get_node("Label") as Label3D).modulate = INTEL
			add_child(mark)
			_intel_marks.append(mark)
		var mark: Node3D = _intel_marks[shown]
		mark.visible = true
		mark.position = r.position
		(mark.get_node("Label") as Label3D).text = tr("HUNT_INTEL_MARK") % [tr("HUNT_INTEL_KIND_" + str(r.kind).to_upper()),
				int(round(float(r.confidence) * 100.0)), (tick - int(r.tick)) / Sim.TICK_RATE]
		shown += 1
	for i in range(shown, _intel_marks.size()):
		_intel_marks[i].visible = false


## Double-Cross: allies share information; the ally is marked overhead.
func _sync_ally(hunt: HuntRules, local_id: int, carrier_pos: Callable) -> void:
	var ally: int = hunt.social.allies.get(local_id, 0)
	if ally == 0:
		if _ally_mark != null:
			_ally_mark.visible = false
		return
	if _ally_mark == null:
		_ally_mark = Label3D.new()
		_ally_mark.text = tr("HUNT_ALLY_MARK")
		_ally_mark.font_size = 120
		_ally_mark.modulate = OWN
		_ally_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_ally_mark.no_depth_test = true
		add_child(_ally_mark)
	# Your nation's squadmate is marked SQUAD; a pact's ally, ALLY.
	_ally_mark.text = tr("SQUAD_TAG") if hunt.social.is_squad(local_id) else tr("HUNT_ALLY_MARK")
	var at: Vector3 = carrier_pos.call(ally)
	_ally_mark.visible = at != Vector3.INF
	if at != Vector3.INF:
		_ally_mark.position = at + Vector3(0, 3.2, 0)  # above the name


## Resource Dispute: each cache is a stack of ore crates under an amber
## beam, labelled with its type, value and collection progress.
func _sync_caches(hunt: HuntRules) -> void:
	var seen := {}
	for c: HuntRules.Cache in hunt.caches:
		if c.empty:
			continue
		seen[c.id] = true
		var node: Node3D = _cache_nodes.get(c.id)
		if node == null:
			node = _make_cache()
			node.position = c.position
			add_child(node)
			_cache_nodes[c.id] = node
		var label: Label3D = node.get_node("Label")
		var res: Dictionary = HuntResources.TYPES[c.resource]
		label.text = tr(res.name_key) + " · %d" % res.points
		if c.collector != 0:
			label.text += "  %d%%" % (100 * c.progress / int(res.collect_ticks))
	for id: int in _cache_nodes.keys():
		if not seen.has(id):
			_cache_nodes[id].queue_free()
			_cache_nodes.erase(id)


func _make_cache() -> Node3D:
	var root := Node3D.new()
	for i in 3:
		var crate := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.7, 0.5, 0.7)
		crate.mesh = m
		crate.position = Vector3(0.4 * (i - 1), 0.25 + (0.5 if i == 1 else 0.0), 0.1 * i)
		crate.material_override = _metal()
		root.add_child(crate)
	var beam := _make_beam(CACHE)
	beam.position.y = BEAM_HEIGHT * 0.5
	root.add_child(beam)
	var label := Label3D.new()
	label.name = "Label"
	label.font_size = 110
	label.modulate = CACHE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = 2.6
	root.add_child(label)
	return root


## Recovery Contract: where our stolen treasure was last reported.
func _sync_clue(hunt: HuntRules, tick: int, local_id: int) -> void:
	var clue: Dictionary = hunt.recovery_clues.get(local_id, {})
	if clue.is_empty() or hunt.stolen_from_hunter(local_id) == null:
		if _clue_mark != null:
			_clue_mark.visible = false
		return
	if _clue_mark == null:
		_clue_mark = _make_wanted_mark()
		(_clue_mark.get_child(0) as MeshInstance3D).material_override = _glow(OWN, 0.6, 2.0)
		(_clue_mark.get_node("Label") as Label3D).modulate = OWN
		add_child(_clue_mark)
	_clue_mark.visible = true
	_clue_mark.position = clue.position
	(_clue_mark.get_node("Label") as Label3D).text = tr("HUNT_CLUE_MARK") % ((tick - int(clue.tick)) / Sim.TICK_RATE)


## Most Wanted: a red ring and label where each Wanted rival was last
## reported (fuzzed, with its age): never where it is now.
func _sync_last_known(social: HuntSocial, tick: int, local_id: int) -> void:
	var shown := 0
	for id: int in social.last_known:
		if id == local_id:
			continue
		if shown >= _wanted_marks.size():
			var mark := _make_wanted_mark()
			add_child(mark)
			_wanted_marks.append(mark)
		var lk: Dictionary = social.last_known[id]
		var mark: Node3D = _wanted_marks[shown]
		mark.visible = true
		mark.position = lk.position
		var label: Label3D = mark.get_node("Label")
		label.text = tr("HUNT_WANTED_MARK") % [social.bounty.get(id, 0), (tick - int(lk.tick)) / Sim.TICK_RATE]
		shown += 1
	for i in range(shown, _wanted_marks.size()):
		_wanted_marks[i].visible = false


func _make_wanted_mark() -> Node3D:
	var root := Node3D.new()
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = HuntSocial.PING_FUZZ - 0.4
	torus.outer_radius = HuntSocial.PING_FUZZ
	ring.mesh = torus
	ring.position.y = 0.15
	ring.material_override = _glow(ALARM, 0.6, 2.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var label := Label3D.new()
	label.name = "Label"
	label.font_size = 110
	label.modulate = ALARM
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true  # readable at range, never a wall of text up close
	label.pixel_size = 0.0004
	label.no_depth_test = true
	label.position.y = 3.5
	root.add_child(label)
	return root


## Grand Vault Standoff: LOCKED / unlocking progress over the grand crate.
func _update_lock_label(node: Node3D, hunt: HuntRules, t: HuntRules.Treasure) -> void:
	var label: Label3D = node.get_node_or_null("Lock")
	if label == null:
		label = Label3D.new()
		label.name = "Lock"
		label.font_size = 110
		label.modulate = GRAND
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position.y = 2.0
		node.add_child(label)
	label.visible = t.locked and t.on_ground()
	if hunt.vault_unlocker != 0:
		label.text = tr("HUNT_LOCK_PROGRESS") % (100 * hunt.vault_progress / hunt.vault_ticks())
	else:
		label.text = tr("HUNT_LOCKED")


static func _color_of(t: HuntRules.Treasure, local_id: int) -> Color:
	match t.kind:
		HuntRules.Kind.GRAND:
			return GRAND
		HuntRules.Kind.PROOF:
			return ALARM
		HuntRules.Kind.RESOURCE:
			return CACHE
	return OWN if t.owner == local_id else RIVAL


## An extraction site as a real landing site: a pad deck (the Skyport's,
## scaled to frame the extraction circle) flush with the ground on a sunk
## concrete footing, and a Skyhopper holding over it to lift you out.
## Presentation only: the deck's top is the ground (+PAD_TOP), so feet stand
## on it as drawn; the rotorcraft hovers out of reach.
const PAD_SCALE := 0.38  ## the 29 m pad deck to about 11 m
const PAD_TOP := 0.03
const PICKUP_HEIGHT := 10.0
var _pickups: Array[Node3D] = []
var _pickup_base: Array[float] = []


func _landing_site(z: Vector3) -> void:
	var deck := Comic.kit_instance("districts/landing_pad", Vector3.ZERO, 0.0, PAD_SCALE)
	var top := 0.55 * PAD_SCALE
	deck.position = z + Vector3(0, PAD_TOP - top, 0)
	add_child(deck)
	# The footing: down to the lowest ground under the deck, so it never floats.
	var low := z.y
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	for k in 8:
		var a := k * TAU / 8.0
		var q := z + Vector3(cos(a), 0, sin(a)) * 5.4
		if space != null:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(q + Vector3(0, 6, 0), q + Vector3(0, -20, 0), Sim.LAYER_WORLD))
			if not hit.is_empty():
				low = minf(low, (hit.position as Vector3).y)
	var depth := z.y + PAD_TOP - top - low + 0.6
	var footing := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 5.2
	cyl.bottom_radius = 5.6
	cyl.height = depth
	cyl.radial_segments = 6
	footing.mesh = cyl
	footing.position = Vector3(z.x, z.y + PAD_TOP - top - depth * 0.5, z.z)
	footing.material_override = _metal()
	add_child(footing)
	var hop := Comic.kit_instance("world/skyhopper", z + Vector3(0, PICKUP_HEIGHT, 0), float(_pickups.size()) * 70.0)
	add_child(hop)
	_pickups.append(hop)
	_pickup_base.append(z.y + PICKUP_HEIGHT)


func _build_static(hunt: HuntRules) -> void:
	_built = true
	_build_pads(hunt)
	if hunt.trap != Vector3.INF:
		_trap = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.6
		disc.bottom_radius = 0.7
		disc.height = 0.08
		_trap.mesh = disc
		_trap.position = hunt.trap + Vector3(0, 0.05, 0)
		_trap.material_override = _glow(ALARM, 1.0, 3.0)
		add_child(_trap)
	RenderLayers.mark_dynamic(self)


## The pads' look, built again when they move (a war gives each camp its own).
var _pads_key := ""
var _pad_nodes: Array[Node] = []


## Every pad's posts in one mesh and their lit tips in another (2 draw
## calls for all pads instead of 24).
func _build_pads(hunt: HuntRules) -> void:
	for n in _pad_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_pad_nodes.clear()
	_rings.clear()
	_zone_labels.clear()
	_zone_beams.clear()
	_pickups.clear()
	_pickup_base.clear()
	_pads_key = str(hunt.zones)
	var before := get_child_count()
	var posts := SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tips := SurfaceTool.new()
	tips.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: Vector3 in hunt.zones:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = HuntRules.EXTRACT_RADIUS - 0.2
		torus.outer_radius = HuntRules.EXTRACT_RADIUS
		ring.mesh = torus
		ring.position = z + Vector3(0, PAD_TOP + 0.04, 0)
		_landing_site(z)
		ring.material_override = _glow(OWN, 1.0, 2.5)
		add_child(ring)
		_rings.append(ring)
		# Four beacon posts with lit tips around the pad (merged below).
		for corner in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			var at: Vector3 = z + corner * (HuntRules.EXTRACT_RADIUS + 0.3)
			posts.append_from(_box_mesh(Vector3(0.25, 2.2, 0.25)), 0, Transform3D(Basis.IDENTITY, at + Vector3(0, 1.1, 0)))
			tips.append_from(_box_mesh(Vector3(0.32, 0.3, 0.32)), 0, Transform3D(Basis.IDENTITY, at + Vector3(0, 2.3, 0)))
		var label := Label3D.new()
		label.text = tr("HUNT_EXTRACT_LABEL")
		label.font_size = 140
		label.modulate = OWN
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = z + Vector3(0, 4.5, 0)
		add_child(label)
		_zone_labels.append(label)
		var beam := _make_beam(OWN)
		beam.position = Vector3(z.x, BEAM_HEIGHT * 0.5, z.z)
		add_child(beam)
		_zone_beams.append(beam)
	if not hunt.zones.is_empty():
		var post_mi := MeshInstance3D.new()
		post_mi.mesh = posts.commit()
		post_mi.material_override = _metal()
		add_child(post_mi)
		var tip_mi := MeshInstance3D.new()
		tip_mi.mesh = tips.commit()
		tip_mi.material_override = _glow(OWN, 1.0, 3.0)
		tip_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tip_mi)
	for i in range(before, get_child_count()):
		_pad_nodes.append(get_child(i))
	RenderLayers.mark_dynamic(self)


## An ore crate: an armoured metal case (the outpost's PBR plate) split
## by a glowing core seam in the treasure's colour, with lit corner caps.
## Three small meshes; the grand crate is half again as big.
func _make_case(color: Color, grand: bool) -> Node3D:
	var root := Node3D.new()
	var case := Node3D.new()
	case.name = "Case"
	root.add_child(case)
	var k := 1.5 if grand else 1.0
	var shell := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.6, 0.6) * k
	shell.mesh = mesh
	shell.material_override = _metal()
	case.add_child(shell)
	var seam := MeshInstance3D.new()
	var seam_mesh := BoxMesh.new()
	seam_mesh.size = Vector3(0.94, 0.1, 0.64) * k
	seam.mesh = seam_mesh
	seam.material_override = _glow(color, 1.0, 2.6 if grand else 1.8)
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	case.add_child(seam)
	var caps := MeshInstance3D.new()
	var caps_mesh := BoxMesh.new()
	caps_mesh.size = Vector3(0.2, 0.66, 0.66) * k
	caps.mesh = caps_mesh
	caps.material_override = _glow(color.darkened(0.35), 1.0, 0.8)
	case.add_child(caps)
	if Settings.video("lights") == true:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 1.5 if grand else 0.8
		light.omni_range = 5.0
		light.position.y = 1.0
		root.add_child(light)
	RenderLayers.mark_dynamic(root)
	return root


static func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _metal() -> StandardMaterial3D:
	if _crate_metal == null:
		_crate_metal = StandardMaterial3D.new()
		_crate_metal.albedo_color = Color(0.75, 0.72, 0.7)
		_crate_metal.albedo_texture = load("res://art/environment/mars/metal_plate_02_diff_1k.jpg")
		_crate_metal.normal_enabled = true
		_crate_metal.normal_texture = load("res://art/environment/mars/metal_plate_02_nor_gl_1k.jpg")
		_crate_metal.orm_texture = load("res://art/environment/mars/metal_plate_02_arm_1k.jpg")
		_crate_metal.uv1_triplanar = true
		_crate_metal.uv1_scale = Vector3.ONE * 1.4
	return _crate_metal


func _make_beam(color: Color) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 0.35
	cyl.height = BEAM_HEIGHT
	beam.mesh = cyl
	beam.material_override = _glow(color, 0.28, 1.5)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return beam


func _glow(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if energy > 1.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return m


# --- War (HuntWar): the control point, the camps ---

var _war_key := ""
var _flag_nodes: Array[Label3D] = []
var _convoy_node: Node3D
var _convoy_label: Label3D
var _war_nodes: Array[Node] = []
var _point_label: Label3D
var _camp_labels: Array[Label3D] = []
const POINT_GOLD := Color(1.0, 0.8, 0.25)


## A side's colour: its nation's, else ours or a rival's.
func _side_color(hunt: HuntRules, side: int, local_id: int) -> Color:
	if side >= 100:
		return Nations.color(side - 100)
	return OWN if side == hunt.war.side_of(hunt, local_id) else RIVAL


## A client (online): only the war, from the host's state (HuntWar.apply_state).
func sync_war(hunt: HuntRules, local_id: int) -> void:
	_sync_war(hunt, local_id)


func _sync_war(hunt: HuntRules, local_id: int) -> void:
	var w := hunt.war
	if not w.enabled:
		return
	# Set up again whenever the run's war is (the countdown's reset rolls it).
	var key := "%d:%d:%s" % [w.objective, w.camps.size(), str(w.camps[0].at) if not w.camps.is_empty() else ""]
	if key != _war_key:
		_war_key = key
		for n in _war_nodes:
			if is_instance_valid(n):
				n.queue_free()
		_war_nodes.clear()
		_camp_labels.clear()
		_camp_drawn.clear()
		_flak.clear()
		_point_label = null
		var before := get_child_count()
		if w.objective == HuntWar.Objective.HOLD:
			_mast(w.point, POINT_GOLD, HuntWar.HOLD_RADIUS)
			_point_label = _war_label(w.point + Vector3(0, 7.5, 0), POINT_GOLD)
		_flag_nodes.clear()
		for f: Array in w.flags:
			_mast(f[0], POINT_GOLD, HuntWar.HOLD_RADIUS)
			_flag_nodes.append(_war_label(f[0] + Vector3(0, 7.5, 0), POINT_GOLD))
		_convoy_node = null
		if w.objective == HuntWar.Objective.CONVOY:
			_convoy_node = Comic.kit_instance("world/hauler", w.convoy, 0.0, 1.2)
			add_child(_convoy_node)
			_convoy_label = _war_label(w.convoy + Vector3(0, 6, 0), POINT_GOLD)
		for c in w.camps:
			var col := _side_color(hunt, c.side, local_id)
			_mast(c.at + Vector3(0, HuntCamps.CORE_SIZE.y, 0), col, HuntWar.CAMP_RADIUS)
			var core := Comic.kit_instance("hab_dome", c.at, 0.0, 0.42)
			add_child(core)
			_camp_labels.append(_war_label(c.at + Vector3(0, 10.0, 0), col))
			_camp_drawn.append({})
		for i in range(before, get_child_count()):
			_war_nodes.append(get_child(i))
	_sync_buildings(hunt)
	_fog(hunt, local_id)
	for i in mini(_flag_nodes.size(), w.flags.size()):
		var f: Array = w.flags[i]
		var lbl: Label3D = _flag_nodes[i]
		lbl.text = tr("WAR_FLAG_LABEL") if int(f[3]) == 0 else "%s %d%%" % [tr("WAR_FLAG_LABEL"),
				100 * int(f[3]) / (HuntWar.CAPTURE_SECONDS * Sim.TICK_RATE)]
		lbl.modulate = _side_color(hunt, int(f[1]), local_id) if int(f[1]) >= 0 else POINT_GOLD
	if _convoy_node != null and is_instance_valid(_convoy_node):
		var to := w.convoy - _convoy_node.position
		if Vector2(to.x, to.z).length() > 0.01:
			_convoy_node.rotation.y = atan2(-to.x, -to.z)
		_convoy_node.position = w.convoy
		_convoy_label.position = w.convoy + Vector3(0, 6, 0)
		_convoy_label.text = tr("WAR_CONVOY_LABEL")
		_convoy_label.modulate = _side_color(hunt, w.convoy_pusher, local_id) if w.convoy_pusher >= 0 else POINT_GOLD
	if _point_label != null:
		var held := ""
		for side: int in w.hold:
			held += "  %d:%02d" % [int(w.hold[side]) / Sim.TICK_RATE / 60, int(w.hold[side]) / Sim.TICK_RATE % 60]
		_point_label.text = tr("WAR_POINT_LABEL") + held
		_point_label.modulate = _side_color(hunt, w.holder, local_id) if w.holder >= 0 else POINT_GOLD
	for i in _camp_labels.size():
		var c: HuntWar.Camp = w.camps[i]
		if w.objective != HuntWar.Objective.CAMPS:
			_camp_labels[i].text = tr("WAR_CAMP")
		else:
			_camp_labels[i].text = tr("WAR_CAMP_LABEL") % c.charges if c.charges > 0 else tr("WAR_CAMP_DOWN")


## A flag mast on a ring (no body: you walk round it, nothing to snag on).
func _mast(at: Vector3, color: Color, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.25
	torus.outer_radius = radius
	ring.mesh = torus
	ring.position = at + Vector3(0, 0.1, 0)
	ring.material_override = _glow(color, 1.0, 2.0)
	add_child(ring)
	var pole := MeshInstance3D.new()
	pole.mesh = _box_mesh(Vector3(0.18, 6.0, 0.18))
	pole.position = at + Vector3(0, 3.0, 0)
	pole.material_override = _metal()
	add_child(pole)
	var flag := MeshInstance3D.new()
	flag.mesh = _box_mesh(Vector3(1.6, 1.0, 0.06))
	flag.position = at + Vector3(0.85, 5.4, 0)
	flag.material_override = _glow(color, 0.9, 1.2)
	add_child(flag)


func _war_label(at: Vector3, color: Color) -> Label3D:
	var l := Label3D.new()
	l.font_size = 120
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = at
	add_child(l)
	return l


# --- Camp buildings (HuntCamps) ---

var _camp_drawn: Array = []  ## per camp: {socket or "walls": node}
## The kit piece and scale for each module (sized to its collision box).
const MODULE_KITS := {
	"med_bay": ["life/greenhouse", 1.0], "barracks": ["shopfront", 0.63], "comms": ["comms_tower", 1.0],
	"refinery": ["tank_cluster", 1.0],
}


func _sync_buildings(hunt: HuntRules) -> void:
	var w := hunt.war
	for ci in mini(w.builds.built.size(), _camp_drawn.size()):
		var b: HuntCamps.Built = w.builds.built[ci]
		var drawn: Dictionary = _camp_drawn[ci]
		var c: HuntWar.Camp = w.camps[ci]
		# Destroyed: gone from the field.
		if not b.walls and drawn.has("walls"):
			for n: Node in drawn["walls"]:
				if is_instance_valid(n):
					n.queue_free()
			drawn.erase("walls")
		for socket: Variant in drawn.keys():
			if socket is int and not b.modules.has(socket):
				if is_instance_valid(drawn[socket]):
					(drawn[socket] as Node).queue_free()
				drawn.erase(socket)
		if b.walls and not drawn.has("walls"):
			var ring := []
			for seg: Array in HuntCamps.wall_segments(c.at, b.gate_angle):
				var wall := Comic.kit_instance("wall_segment", seg[0], seg[1], 1.0)
				wall.scale = Vector3(1.27, 0.66, 0.6)
				add_child(wall)
				_war_nodes.append(wall)
				ring.append(wall)
			drawn["walls"] = ring
		for socket: int in b.modules:
			if drawn.has(socket):
				continue
			var m: String = b.modules[socket]
			var at := HuntCamps.socket_at(c.at, socket)
			var node: Node3D
			if m == "turret":
				node = _turret_model(at)
			elif m == "helipad":
				node = Node3D.new()
				node.position = at
				node.add_child(Comic.kit_instance("districts/landing_pad", Vector3(0, 0.05, 0), 0.0, 0.3))
				node.add_child(Comic.kit_instance("world/skyhopper", Vector3(0, 0.2, 0), 30.0, 0.8))
			elif m == "air_defense" or m == "aegis_battery":
				node = _flak_model(at, m == "aegis_battery")
			else:
				var kit: Array = MODULE_KITS[m]
				node = Comic.kit_instance(kit[0], at, rad_to_deg(atan2(c.at.x - at.x, c.at.z - at.z)), kit[1])
			add_child(node)
			_war_nodes.append(node)
			drawn[socket] = node


## A flak battery, in the comic style (outlined, cel-shaded): a sandbagged
## pit, a mount with an armoured head that turns and lifts to track the
## nearest enemy aircraft (_aim_flak), four long barrels with flash cones,
## ammo crates. The Aegis: bigger, armour skirts, a six-tube missile pod and
## a radar dish turning on its mast.
var _flak: Array = []  ## [root, head (yaw), cradle (pitch), dish or null, socket position]


func _flak_model(at: Vector3, aegis: bool) -> Node3D:
	var k := 1.35 if aegis else 1.0
	var kind := "aegis" if aegis else "flak"
	var root := Node3D.new()
	root.position = at
	root.add_child(Comic.kit_instance("army/%s_base" % kind, Vector3.ZERO, 0.0))
	var head := Node3D.new()  # turns to the target (_aim_flak)
	head.position = Vector3(0, 1.6 * k, 0)
	root.add_child(head)
	head.add_child(Comic.kit_instance("army/%s_head" % kind, Vector3.ZERO, 0.0))
	var cradle := Node3D.new()  # lifts the guns
	cradle.position = Vector3(0, 0.2 * k, -0.2 * k)
	head.add_child(cradle)
	cradle.add_child(Comic.kit_instance("army/%s_guns" % kind, Vector3.ZERO, 0.0))
	var dish_pivot: Node3D = null
	if aegis:
		dish_pivot = Node3D.new()  # the radar turns
		dish_pivot.position = Vector3(-1.6 * k, 2.3, 1.2 * k)
		root.add_child(dish_pivot)
		dish_pivot.add_child(Comic.kit_instance("army/aegis_dish", Vector3.ZERO, 0.0))
	_flak.append([root, head, cradle, dish_pivot, at])
	return root


## The flak heads track the nearest enemy aircraft; the radars turn.
func _aim_flak(hunt: HuntRules, tick: int, local_id: int, delta: float) -> void:
	for f: Array in _flak:
		if not is_instance_valid(f[0]):
			continue
		if f[3] != null:
			(f[3] as Node3D).rotation.y += delta * 1.6
		var at: Vector3 = f[4]
		var best := 90.0
		var aim := Vector3.INF
		for c in hunt.army.calls:
			if not (c.unit in HuntArmy.AIR):
				continue
			var p := hunt.army.position_of(c, tick)
			var d := p.distance_to(at)
			if d < best:
				best = d
				aim = p
		if aim == Vector3.INF:
			continue
		var to := aim - (at + Vector3(0, 1.6, 0))
		var head: Node3D = f[1]
		var cradle: Node3D = f[2]
		head.rotation.y = lerp_angle(head.rotation.y, atan2(-to.x, -to.z), minf(delta * 5.0, 1.0))
		cradle.rotation.x = lerpf(cradle.rotation.x, atan2(to.y, Vector2(to.x, to.z).length()), minf(delta * 5.0, 1.0))


## A turret in the kit's style: a base, a turning head, twin barrels.
func _turret_model(at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.add_child(Comic.kit_instance("army/turret_base", Vector3.ZERO, 0.0))
	var head := Comic.kit_instance("army/turret_head", Vector3(0, 2.12, 0), 0.0)
	head.name = "Head"
	root.add_child(head)
	return root


# --- The army's units in the air (HuntArmy calls) ---

var _unit_nodes: Dictionary = {}  ## HuntArmy.Call -> Node3D


func _sync_army(hunt: HuntRules, tick: int) -> void:
	var live := {}
	for c in hunt.army.calls:
		if c.unit in HuntArmy.ARTILLERY or c.unit == "recon_sat":
			continue  # fired from far off / in orbit: nothing to see overhead
		live[c] = true
		var node: Node3D = _unit_nodes.get(c)
		if node == null:
			node = _unit_model(c.unit)
			add_child(node)
			_unit_nodes[c] = node
		var info: Dictionary = HuntArmy.UNITS[c.unit]
		if c.unit in HuntArmy.JETS:
			# Flying in along its run during the run-up, low and fast.
			var dir := c.at - c.from
			dir.y = 0.0
			dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
			var u := clampf(1.0 - float(c.start_tick - tick) / float(info.delay), 0.0, 1.0)
			var a := c.at - dir * 260.0
			node.position = a.lerp(c.at, u) + Vector3(0, float(info.height), 0)
			node.rotation.y = atan2(-dir.x, -dir.z)
		else:
			# Circling over the target.
			var t := float(tick) / 60.0
			var r := 12.0 if c.unit == "gunship" else (3.0 if c.unit in ["medevac", "aegis_drone"] else 6.0)
			node.position = c.at + Vector3(cos(t * 0.6) * r, float(info.height) + sin(t * 1.3) * 0.6, sin(t * 0.6) * r)
			node.rotation.y = -t * 0.6
	for c in _unit_nodes.keys():
		if not live.has(c):
			(_unit_nodes[c] as Node).queue_free()
			_unit_nodes.erase(c)


## A unit in the sky: the gunship is a Skyhopper; drones and the jet are
## built in the kit's style.
## The army's own models (tools/blender/build_army_kit.py), comic-shaded and
## inked; units that share a body share its model.
const ARMY_MODELS := {"attack_drone": "attack_drone", "scout_drone": "scout_drone", "emp_drone": "emp_drone",
		"aegis_drone": "aegis_drone", "swarm": "swarm_drone", "hive": "swarm_drone", "strike_jet": "strike_jet",
		"raptor": "raptor", "bomber": "bomber", "nightwing": "nightwing"}
## Their size in the sky (the swarm's and hive's drones are small).
const ARMY_SCALE := {"hive": 0.8, "swarm": 1.0}


func _unit_model(unit: String) -> Node3D:
	if ARMY_MODELS.has(unit):
		var root := Node3D.new()
		var body := Comic.kit_instance("army/" + str(ARMY_MODELS[unit]), Vector3.ZERO, 0.0, float(ARMY_SCALE.get(unit, 1.0)))
		if not unit in HuntArmy.JETS:
			body.material_override = Comic.kit_material(0.008)  # small: a thin line, or the ink swamps it
		root.add_child(body)
		return root
	if unit == "gunship":
		return Comic.kit_instance("world/skyhopper", Vector3.ZERO, 0.0, 1.3)
	if unit == "medevac":
		var heli := Comic.kit_instance("world/skyhopper", Vector3.ZERO, 0.0, 1.0)
		var cross := MeshInstance3D.new()
		cross.mesh = _box_mesh(Vector3(1.6, 0.1, 0.5))
		cross.position = Vector3(0, 1.6, 0)
		cross.material_override = _glow(Color(1.0, 0.25, 0.25), 1.0, 2.0)
		heli.add_child(cross)
		return heli
	var root := Node3D.new()
	var parts := []
	var glow := RIVAL
	if unit in HuntArmy.JETS:
		var k := 1.5 if unit == "bomber" else (0.9 if unit == "nightwing" else 1.0)
		parts = [[Vector3(1.4, 1.0, 9.0) * k, Vector3.ZERO], [Vector3(9.0, 0.25, 2.6) * Vector3(k * (1.3 if unit == "bomber" else 1.0), 1, k), Vector3(0, 0, 0.8) * k],
				[Vector3(3.6, 0.2, 1.2) * k, Vector3(0, 0.3, 4.0) * k], [Vector3(0.2, 1.6, 1.4) * k, Vector3(0, 1.0, 3.9) * k]]
		if unit == "bomber":  # four engines under the wings
			for x: float in [-4.5, -2.5, 2.5, 4.5]:
				parts.append([Vector3(0.6, 0.6, 1.8), Vector3(x, -0.5, 0.6)])
		glow = Color(0.45, 0.3, 1.0) if unit == "nightwing" else Color(1.0, 0.5, 0.2)
	else:
		var s := 0.6 if unit in ["scout_drone", "hive"] else (1.2 if unit == "aegis_drone" else 1.0)
		if unit == "emp_drone":
			glow = Color(0.3, 0.8, 1.0)
		elif unit == "aegis_drone":
			glow = Color(0.35, 0.75, 1.0)
		parts = [[Vector3(1.0, 0.4, 1.0) * s, Vector3.ZERO]]
		for q: Vector3 in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
			parts.append([Vector3(0.9, 0.08, 0.9) * s, q * 0.9 * s + Vector3(0, 0.25, 0) * s])
	for p: Array in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(p[0])
		mi.position = p[1]
		mi.material_override = _metal()
		root.add_child(mi)
	var light := MeshInstance3D.new()
	light.mesh = _box_mesh(Vector3(0.3, 0.3, 0.3))
	light.position = Vector3(0, -0.4, 0)
	light.material_override = _glow(glow, 1.0, 2.5)
	if unit == "emp_drone" or unit == "aegis_drone":  # a ring round it: its field
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.6
		torus.outer_radius = 1.8
		ring.mesh = torus
		ring.material_override = _glow(glow, 0.8, 2.0)
		root.add_child(ring)
	root.add_child(light)
	return root


## Fog of war (a match modifier): enemy camps aren't drawn till you're near.
var _camp_nodes_by_camp: Dictionary = {}


func _fog(hunt: HuntRules, local_id: int) -> void:
	var fog := hunt.mods.has("fog")
	var me: Vector3 = hunt_local_pos
	for ci in hunt.war.camps.size():
		var c: HuntWar.Camp = hunt.war.camps[ci]
		var hidden := fog and c.side != hunt.war.side_of(hunt, local_id) and me.distance_to(c.at) > HuntMods.FOG_RANGE
		if ci < _camp_labels.size():
			_camp_labels[ci].visible = not hidden
		if ci < _camp_drawn.size():
			for v: Variant in (_camp_drawn[ci] as Dictionary).values():
				if v is Array:
					for n: Node3D in v:
						if is_instance_valid(n):
							n.visible = not hidden
				elif v is Node3D and is_instance_valid(v):
					(v as Node3D).visible = not hidden


var hunt_local_pos := Vector3.ZERO  ## where the local player is (the match sets it)
