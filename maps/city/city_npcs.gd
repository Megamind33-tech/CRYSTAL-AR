class_name CityNpcs
extends Node3D
## Tharsis Gate's people (presentation only, so they cost nothing on the
## server): a vendor at each terminal, idling and turning to face you when
## you come near, with a name board; and residents walking their loops at
## a walking pace, turning at each corner. Bodies are the game's character
## rigs (same animation library) in civilian colours, unarmed. Far or
## off-screen bodies animate at reduced rates (PlayerVisual's detail).

const WALK_SPEED := 1.4
## Work-suit colours, clearly fabric: miners' safety orange, haulers'
## navy, medics' white, traders' teal, engineers' mustard, guards' slate,
## farmers' olive, clerks' maroon.
const COLORS := [Color(0.95, 0.33, 0.04), Color(0.14, 0.24, 0.52), Color(0.88, 0.9, 0.92), Color(0.08, 0.46, 0.48),
		Color(0.78, 0.56, 0.06), Color(0.3, 0.34, 0.42), Color(0.34, 0.42, 0.16), Color(0.52, 0.1, 0.17)]

## Beyond this (metres) people aren't animated (they're out of sight).
const FAR := 130.0
var _vendors: Array = []  ## [PlayerVisual, PlayerSimState, home yaw]
var _walkers: Array = []  ## [PlayerVisual, PlayerSimState, path, next index]
var _time: float = 0.0
## Where the player stands (set by the match) so vendors can look at them.
var player_position := Vector3.INF


func _ready() -> void:
	add_to_group("city_npcs")
	var i := 0
	for t: Array in CityLayout.terminals():
		var yaw := deg_to_rad(t[2])
		var front := Vector3(sin(yaw), 0, cos(yaw))  # the kiosk's +Z side
		var at: Vector3 = (t[1] as Vector3) - front * 1.6
		var v := _body(tr(t[3]), COLORS[i % COLORS.size()], _who(i, tr(t[3])), false)
		v.face_movement = false  # vendors turn to face you (their yaw), unarmed
		var s := _state(at, atan2(front.x, front.z) + PI)
		_vendors.append([v, s, s.yaw, CityMode.PERSON_AT[t[0]], at])
		_board(tr(t[3]).to_upper() + "\n" + tr("CITY_TERMINAL_" + str(t[0]).to_upper()), (t[1] as Vector3) + Vector3(0, 3.6, 0))
		i += 1
	# Dust Hollow: its foreman by the kiosk, workers on their rounds.
	var foreman_at := WorldLayout.foreman_spot()
	var fv := _body(tr("CITY_NPC_FOREMAN"), COLORS[0], _who(9, "Adaeze"), false)
	fv.face_movement = false
	var fs := _state(foreman_at, PI)
	_vendors.append([fv, fs, fs.yaw, "foreman", foreman_at])
	_board(tr("CITY_NPC_FOREMAN").to_upper() + "\n" + tr("WORLD_HOLLOW_SIGN"), foreman_at + Vector3(0, 3.0, 1.4))
	for spot: Array in WorldLayout.people_spots():
		var person: Dictionary = Career.PEOPLE[spot[0]]
		# Only Deep Furrow is under a roof here: the rest stand out in the open.
		var pv := _body(person.name, COLORS[(i + 3) % COLORS.size()], _who(i, person.name), _breathes(spot[1]))
		pv.face_movement = false
		var ps := _state(spot[1], spot[2])
		_vendors.append([pv, ps, ps.yaw, spot[0], spot[1]])
		_board(str(person.name).to_upper() + "\n" + str(person.role), (spot[1] as Vector3) + Vector3(0, 2.7, 0))
		i += 1
	# Behind every shop counter, its keeper (the Hollow's in a suit).
	for shop: Array in WorldLayout.shops():
		var info: Dictionary = Career.SHOPS[shop[0]]
		var kv := _body(info.keeper, COLORS[(i + 1) % COLORS.size()], _who(i, info.keeper), _breathes(shop[2]))
		kv.face_movement = false
		var ks := _state(shop[2], shop[3])
		_vendors.append([kv, ks, ks.yaw, "shop:" + str(shop[0]), shop[2]])
		_board(str(info.name).to_upper(), (shop[2] as Vector3) + Vector3(0, 2.6, 0))
		# The name over the door outside too, so you can find it.
		var front := (shop[1] as Vector3) + Basis(Vector3.UP, float(shop[3]) - PI) * Vector3(0, 0, 4.4)
		_board(str(info.name).to_upper(), front + Vector3(0, 4.3, 0))
		i += 1
	# Of an evening the bars fill up: regulars at each.
	for b in [5, 7]:
		var bar: Array = WorldLayout.shops()[b]
		for k in 3:
			var at: Vector3 = (bar[1] as Vector3) + Basis(Vector3.UP, float(bar[3]) - PI) * Vector3(-3.0 + k * 1.6, 0, 1.6 - k * 0.5)
			var bv := _body("", COLORS[(i + k) % COLORS.size()], i * 2 + k, _breathes(at))
			bv.face_movement = false
			var bs := _state(at, float(bar[3]) + 0.4 * (k - 1))
			_vendors.append([bv, bs, bs.yaw, "patron", at])
		i += 1
	var walks := CityLayout.walks()
	for path: Array in WorldLayout.hollow_walks():
		var grounded := []
		for p: Vector3 in path:
			grounded.append(WorldTerrain.at(p.x, p.z))
		walks.append(grounded)
	# Kasei Motors' workers walk the line (in suits: the hall has no air).
	for path: Array in [[Vector3(-6, 0, -16), Vector3(-6, 0, 16)], [Vector3(6, 0, 16), Vector3(6, 0, -16)],
			[Vector3(-10, 0, 18), Vector3(10, 0, 18), Vector3(10, 0, -18)]]:
		var fp := []
		for p: Vector3 in path:
			fp.append(WorldLayout.factory_at(p))
		walks.append(fp)
	# The outlands' districts: Helios' plaza, the Galleria's shoppers, the
	# Terrace's neighbours, the Skyport's crews.
	for d: Array in WorldLayout.district_walks():
		var c: Vector2 = d[0]
		for loop: Array in d[1]:
			var dp := []
			for q: Vector2 in loop:
				dp.append(WorldTerrain.at(c.x + q.x, c.y + q.y))
			walks.append(dp)
	# Deep Furrow's farmers tend the beds (underground, bare-headed).
	var fo := WorldLayout.farm_origin()
	walks.append([fo + Vector3(-5, 0, -18), fo + Vector3(-5, 0, 16)])
	walks.append([fo + Vector3(5, 0, 14), fo + Vector3(5, 0, -20)])
	var k := 0
	for path: Array in walks:
		# Walking the streets is outside: helmets on. Only the farm is indoors.
		var v := _body("", COLORS[i % COLORS.size()], i, _breathes(path[0]) and _breathes(path[path.size() - 1]))
		_light_weight.call_deferred(v)
		k += 1
		var s := _state(path[0], 0.0)
		_walkers.append([v, s, path, 1])
		i += 1
	# The Kasei Marshals walk their beat round the plaza and past the gate.
	for path: Array in CityLayout.patrols():
		var mv := _body("", COLORS[5], i, true, "marshal")
		_walkers.append([mv, _state(path[0], 0.0), path, 1])
		i += 1


## Helmet off only inside a pressurised room (not just under any roof).
static func _breathes(at: Vector3) -> bool:
	return WorldLayout.room_at(at + Vector3(0, 0.5, 0)) == WorldLayout.ROOM_AIR


var _schedule_t: float = 0.0
## For screenshots: so many hours later than the clock says.
static var hour_offset: float = 0.0


## People keep their hours (WorldLayout.person_at); shopkeepers are behind
## the counter while the shop's open; the bars' regulars come in the evening.
func _keep_hours() -> void:
	var h := fmod(GameClock.hour(Time.get_unix_time_from_system()) + hour_offset, 24.0)
	for v: Array in _vendors:
		var who: String = v[3] if v.size() > 3 else ""
		if who.is_empty():
			continue
		var body: Node3D = v[0]
		var s: PlayerSimState = v[1]
		if who.begins_with("shop:"):
			body.visible = WorldLayout.shop_open(who.substr(5), h)
		elif who == "patron":
			body.visible = GameClock.within(GameClock.BAR_HOURS, h)
		else:
			var at := WorldLayout.person_at(who, v[4], h)
			body.visible = at != Vector3.INF
			if body.visible and at.distance_to(s.position) > 0.5:
				s.position = at
				body.global_position = at


## Named women of the valley (everyone else alternates, odd variants women).
const WOMEN := ["Adaeze", "Ngozi", "Ama", "Sable", "Dr. Okafor", "Oyelaran"]


## A body variant for person `i`: by name when they have one we know.
static func _who(i: int, who: String) -> int:
	for name: String in WOMEN:
		if who.begins_with(name) or who.contains(name):
			return i * 2 + 1
	return i * 2 + (0 if not who.is_empty() else i % 2)


func _board(text: String, at: Vector3) -> void:
	var board := Label3D.new()
	board.text = text
	board.font = UiStyle.font_hud_big
	board.font_size = 64
	board.outline_size = 14
	board.outline_modulate = ComicUI.INK
	board.modulate = ComicUI.YELLOW
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.position = at
	add_child(board)


func _body(display_name: String, color: Color, variant: int, indoors: bool = true, style: String = "") -> PlayerVisual:
	var v := PlayerVisual.new()
	add_child(v)
	# Colonists in work suits; outside a dome they're sealed (helmet, air).
	v.setup(display_name, false, color, variant, style if not style.is_empty() else ("civilian" if indoors else "worker"))
	v.face_movement = true
	v.hide_nameplate()
	_light_weight.call_deferred(v)
	return v


## The city's people are many: no sun shadow of their own (the player's and
## the fighters' keep theirs) and not drawn past NPC_RANGE, where they're a
## few pixels tall. Most of a frame's triangles were their bodies.
const NPC_RANGE := 75.0
func _light_weight(v: Node) -> void:
	for gi: GeometryInstance3D in v.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if gi.visibility_range_end <= 0.0 or gi.visibility_range_end > NPC_RANGE:
			gi.visibility_range_end = NPC_RANGE
			gi.visibility_range_end_margin = 4.0


func _state(at: Vector3, yaw: float) -> PlayerSimState:
	var s := PlayerSimState.new()
	s.position = at
	s.yaw = yaw
	s.alive = true
	s.move_state = PlayerSimState.Move.GROUND
	return s


## People react: gunfire nearby sends walkers running and makes the rest
## cower; a gun pointed at someone makes them freeze with their hands up;
## bump into a walker and they stop and tell you; come up to someone and
## they greet you. Each says it (a speech bubble over their head).
const RUN_SPEED := 4.6
var _mood := {}     ## PlayerVisual -> {"mode": walk/flee/cower/wait, "t", "from"}
var _said := {}     ## PlayerVisual -> time they last spoke
var _bubbles := {}  ## Label3D -> seconds left


## Shots or a blast at `at`: people within `radius` react.
func threat(at: Vector3, radius: float) -> void:
	for w: Array in _walkers:
		var v: PlayerVisual = w[0]
		var s: PlayerSimState = w[1]
		if v.visible and s.position.distance_to(at) < radius:
			_mood[v] = {"mode": "flee", "t": 7.0, "from": at}
			if randf() < 0.45:
				say(v, _line("NPC_BARK_SHOTS"))
	for e: Array in _vendors:
		var v: PlayerVisual = e[0]
		var s: PlayerSimState = e[1]
		if v.visible and s.position.distance_to(at) < radius * 0.7:
			_mood[v] = {"mode": "cower", "t": 6.0}
			if randf() < 0.5:
				say(v, _line("NPC_BARK_COWER"))


## A gun pointed from `from` along `dir`: whoever it covers freezes.
func aimed(from: Vector3, dir: Vector3) -> void:
	for list: Array in [_walkers, _vendors]:
		for e: Array in list:
			var v: PlayerVisual = e[0]
			var s: PlayerSimState = e[1]
			var to := s.position + Vector3(0, 1.2, 0) - from
			if v.visible and to.length() < 18.0 and dir.dot(to.normalized()) > 0.94:
				var m: Dictionary = _mood.get(v, {})
				if m.get("mode", "") != "flee":
					if m.get("mode", "") != "cower":
						say(v, _line("NPC_BARK_AIMED"))
					_mood[v] = {"mode": "cower", "t": 2.5}


## A line over `v`'s head for a few seconds (not too often from one person).
func say(v: Node3D, text: String, force: bool = false) -> void:
	if text.is_empty() or (not force and _time - float(_said.get(v, -99.0)) < 6.0):
		return
	_said[v] = _time
	for c in v.get_children():
		if c is Label3D and _bubbles.has(c):
			_bubbles.erase(c)
			c.queue_free()
	var b := Label3D.new()
	b.text = text
	b.font = UiStyle.font_hud_big
	b.font_size = 48
	b.pixel_size = 0.0011
	b.fixed_size = true  # the same size on screen near or far
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.width = 700.0
	b.outline_size = 12
	b.outline_modulate = ComicUI.INK
	b.modulate = ComicUI.PAPER
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.no_depth_test = true
	b.position = Vector3(0, 2.35 if v is PlayerVisual else 3.4, 0)
	v.add_child(b)
	_bubbles[b] = 2.8


## One of a key's lines ("a|b|c" in the strings).
static func _line(key: String) -> String:
	var lines := TranslationServer.translate(key).split("|")
	return lines[randi() % lines.size()]


## Your gang's crew (Career.d.gang.members): they walk with you, a few
## steps around you, run to catch up, and wait out of the way while a fight
## is on (the fight has them as fighters then). Presentation only.
var _crew: Array = []  ## [PlayerVisual, PlayerSimState, name]
var crew_hidden: bool = false


func set_crew(names: Array) -> void:
	var have := _crew.map(func(c: Array) -> String: return c[2])
	if have == names:
		return
	for c: Array in _crew:
		(c[0] as Node).queue_free()
	_crew.clear()
	for i in names.size():
		var start := player_position if player_position != Vector3.INF else Vector3.ZERO
		var v := _body(str(names[i]), ComicUI.MAGENTA, 40 + i, false, "worker")
		_crew.append([v, _state(start + Vector3(2 + i, 0, 2), 0.0), names[i]])


func _step_crew(delta: float) -> void:
	for i in _crew.size():
		var v: PlayerVisual = _crew[i][0]
		var s: PlayerSimState = _crew[i][1]
		v.visible = not crew_hidden and player_position != Vector3.INF
		if not v.visible:
			continue
		var a := i * 2.1 + 2.4
		var spot := player_position + Vector3(cos(a), 0, sin(a)) * (2.6 + (i % 3) * 0.9)
		var to := spot - s.position
		to.y = 0.0
		if to.length() > 40.0:  # left far behind (a drive, a lift): they catch up
			s.position = spot
			to = Vector3.ZERO
		var speed := 0.0 if to.length() < 0.6 else clampf(to.length() * 1.6, WALK_SPEED, 7.5)  # keep up with you
		var dir := to.normalized() if to.length() > 0.01 else Vector3.ZERO
		s.sprinting = speed > 4.0
		s.velocity = dir * speed
		s.position += s.velocity * delta
		if s.position.y > WorldLayout.FARM_FLOOR + 50.0 or player_position.y < WorldLayout.FARM_FLOOR + 50.0:
			s.position.y = player_position.y if absf(player_position.y - WorldTerrain.surface(s.position.x, s.position.z)) > 1.5 \
					else WorldTerrain.surface(s.position.x, s.position.z)
		if dir != Vector3.ZERO:
			s.yaw = atan2(-dir.x, -dir.z)
		v.update_from(null, s, 1.0, _time)


func _process(delta: float) -> void:
	_time += delta
	_step_crew(delta)
	for b: Label3D in _bubbles.keys():
		_bubbles[b] = float(_bubbles[b]) - delta
		if float(_bubbles[b]) <= 0.0 or not is_instance_valid(b):
			_bubbles.erase(b)
			if is_instance_valid(b):
				b.queue_free()
	for w: Array in _walkers:
		var v: PlayerVisual = w[0]
		var s: PlayerSimState = w[1]
		# Far from you, people wait where they are (no animation to run).
		if player_position != Vector3.INF and s.position.distance_squared_to(player_position) > FAR * FAR:
			if v.visible:
				v.visible = false
				v.process_mode = Node.PROCESS_MODE_DISABLED
			continue
		if not v.visible:
			v.visible = true
			v.process_mode = Node.PROCESS_MODE_INHERIT
		var m: Dictionary = _mood.get(v, {})
		var mode: String = m.get("mode", "walk")
		if mode != "walk":
			m.t = float(m.t) - delta
			if float(m.t) <= 0.0:
				_mood.erase(v)
				s.stance = PlayerSimState.Stance.STAND
				s.sprinting = false
				mode = "walk"
		# Someone walking into you: they stop, step aside, say so.
		if mode == "walk" and player_position != Vector3.INF and s.position.distance_to(player_position) < 1.4:
			var ahead := Vector3(-sin(s.yaw), 0, -cos(s.yaw))
			if ahead.dot((player_position - s.position).normalized()) > 0.3:
				_mood[v] = {"mode": "wait", "t": 1.2}
				s.position += Vector3(ahead.z, 0, -ahead.x) * 0.6
				say(v, _line("NPC_BARK_BUMP"))
				mode = "wait"
		var dir := Vector3.ZERO
		var speed := 0.0
		match mode:
			"walk":
				var target: Vector3 = w[2][w[3]]
				var to := target - s.position
				to.y = 0.0
				if to.length() < 0.3:
					w[3] = (int(w[3]) + 1) % (w[2] as Array).size()
					continue
				dir = to.normalized()
				speed = WALK_SPEED
			"flee":
				var away := s.position - (m.from as Vector3)
				away.y = 0.0
				dir = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
				speed = RUN_SPEED
				s.sprinting = true
			"cower":
				s.stance = PlayerSimState.Stance.CROUCH
				if player_position != Vector3.INF:
					var face := player_position - s.position
					dir = Vector3.ZERO
					s.yaw = atan2(-face.x, -face.z)
		s.velocity = dir * speed
		s.position += s.velocity * delta
		if s.position.y > WorldLayout.FARM_FLOOR + 50.0:
			s.position.y = WorldTerrain.surface(s.position.x, s.position.z)  # walk the ground (as drawn)
		if dir != Vector3.ZERO:
			s.yaw = atan2(-dir.x, -dir.z)
		v.update_from(null, s, 1.0, _time)
	_schedule_t -= delta
	if _schedule_t <= 0.0:
		_schedule_t = 1.0
		_keep_hours()
	for v: Array in _vendors:
		if not (v[0] as Node3D).visible:
			continue
		var s: PlayerSimState = v[1]
		if player_position != Vector3.INF and s.position.distance_squared_to(player_position) > FAR * FAR:
			continue
		var yaw: float = v[2]
		var pv: PlayerVisual = v[0]
		var vm: Dictionary = _mood.get(pv, {})
		if not vm.is_empty():
			vm.t = float(vm.t) - delta
			s.stance = PlayerSimState.Stance.CROUCH if float(vm.t) > 0.0 else PlayerSimState.Stance.STAND
			if float(vm.t) <= 0.0:
				_mood.erase(pv)
		if player_position != Vector3.INF and s.position.distance_to(player_position) < 7.0:
			var to := player_position - s.position
			yaw = atan2(-to.x, -to.z)
			# Come up to them and they say hello (once in a while).
			if s.position.distance_to(player_position) < 4.0 and _time - float(_said.get(pv, -99.0)) > 40.0:
				var who: String = v[3] if v.size() > 3 else ""
				var line := _line("NPC_BARK_GREET")
				if who.begins_with("shop:"):
					line = TranslationServer.translate("NPC_BARK_SHOP") % Career.SHOPS[who.substr(5)].name
				elif who == "patron":
					line = _line("NPC_BARK_BAR")
				say(pv, line, true)
		s.yaw = lerp_angle(s.yaw, yaw, minf(delta * 4.0, 1.0))
		s.velocity = Vector3.ZERO
		(v[0] as PlayerVisual).update_from(null, s, 1.0, _time)
