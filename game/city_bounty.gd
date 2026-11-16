class_name CityBounty
extends RefCounted
## The Marshals' Bounty Board (free roam, with CityMode). Take a bounty and
## you get a dossier (their face, their name, what they did, the reward)
## and a search area on the minimap where they were last seen. Close it
## down: ask people around (they point you the right way), sweep with the
## scanner (it picks up their suit), or look through binoculars. Spot them
## and it's confirmed: their name over their head, their position on the
## map, and they (and their crew) fight. Hold them up when they're beaten
## and the Marshals take them alive (the full reward), or bring the proof
## off their body to the board (the plain reward).

const SEARCH_START := 160.0
const SEARCH_MIN := 25.0
const SPOT_RANGE := 24.0        ## close enough with a clear line: confirmed
const BINO_RANGE := 180.0
const ASK_REACH := 2.6

var city: CityMode
var director: RaidDirector
var target_id: int = 0
var confirmed: bool = false
var hot: bool = false            ## the fight's on
var down: bool = false           ## the target's dead: the proof's on the body
var circle_c := Vector2.ZERO
var circle_r: float = SEARCH_START
var portrait: SubViewport
var _portrait_frames: int = 0
var _tag: Label3D
var _asked := {}
var _rng := RandomNumberGenerator.new()


func _init(p_city: CityMode) -> void:
	city = p_city
	_rng.randomize()


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func active() -> bool:
	return not (Profile.career().d.bounty as Dictionary).is_empty()


func bounty_id() -> String:
	return str(Profile.career().d.bounty.get("id", ""))


func info() -> Dictionary:
	return Career.BOUNTIES.get(bounty_id(), {})


## The fighters of the bounty (for CityMode's hostiles: hold-ups, scans).
func fighters() -> Array[int]:
	var out: Array[int] = []
	if director != null:
		out.append_array(director.raiders)
	return out


## Each frame: spawn the target, gather clues, confirm, notice the target
## falling. Returns a key for CityMode's _near ("" for nothing).
func update(me: SimPlayer, busy: bool) -> String:
	var pos := me.state.position
	if not active():
		if director != null:
			_clear()
		return "bounty:board" if not busy and me.state.vehicle < 0 and pos.distance_to(WorldLayout.bounty_board()) < 2.6 else ""
	if director == null:
		_spawn()
	_step_portrait()
	var world: SimWorld = city.match_node.server.world
	var t: SimPlayer = world.players.get(target_id)
	if t != null and not t.state.alive and not down:
		down = true
		city._flash_text(TranslationServer.translate("BOUNTY_DOWN") % info().name, ComicUI.YELLOW)
	if t != null and t.state.alive and not confirmed:
		_watch(me, t)
	# Hurt them (or their crew) and it's on.
	if not hot and t != null and t.state.alive and (t.state.health < Balance.PLAYER.max_health - 0.5 or _crew_hurt(world)):
		_go_hot(me)
	if _tag != null and is_instance_valid(_tag):
		_tag.visible = confirmed and t != null and t.state.alive
	elif confirmed and t != null and t.state.alive:
		_make_tag()
	if busy or me.state.vehicle >= 0:
		return ""
	if pos.distance_to(WorldLayout.bounty_board()) < 2.6:
		return "bounty:board"
	if not confirmed and city._people != null:
		var w := _walker_near(pos)
		if w != null:
			return "bounty:ask"
	return ""


func _crew_hurt(world: SimWorld) -> bool:
	for id: int in director.raiders:
		var p: SimPlayer = world.players.get(id)
		if p != null and (not p.state.alive or p.state.health < Balance.PLAYER.max_health - 0.5):
			return true
	return false


## Seen them? Close with a clear line, or picked out through binoculars.
func _watch(me: SimPlayer, t: SimPlayer) -> void:
	var eye := me.state.position + Vector3(0, 1.6, 0)
	var head := t.state.position + Vector3(0, 1.5, 0)
	var d := eye.distance_to(head)
	var clear := func() -> bool:
		var space: PhysicsDirectSpaceState3D = city.match_node.get_world_3d().direct_space_state
		return space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, head, Sim.LAYER_WORLD)).is_empty()
	if d < SPOT_RANGE and clear.call():
		_confirm(me, "BOUNTY_SPOTTED")
		return
	if city.binocular_on and d < BINO_RANGE:
		var look := Basis.from_euler(Vector3(me.state.pitch, me.state.yaw, 0.0)) * Vector3(0, 0, -1)
		if look.dot((head - eye).normalized()) > 0.997 and clear.call():
			_confirm(me, "BOUNTY_SPOTTED_BINO")


func _confirm(me: SimPlayer, key: String) -> void:
	confirmed = true
	city._flash_text(TranslationServer.translate(key) % info().name, ComicUI.RED)
	city.match_node.audio.play_ui("shield_break", -4.0)
	_make_tag()
	if info().kind != "gunman" or _rng.randf() < 0.7:
		_go_hot(me)  # most of them don't wait to be taken


func _go_hot(me: SimPlayer) -> void:
	if hot:
		return
	hot = true
	confirmed = true
	me.team = 0
	for id: int in director.raiders:
		var brain: Variant = city.match_node.server.bots.get(id)
		if brain != null and "hunt" in brain:
			brain.hunt = true
	city._sync_combat()


func _make_tag() -> void:
	var v: Node3D = city.match_node._visuals.get(target_id)
	if v == null:
		return
	_tag = Label3D.new()
	_tag.text = TranslationServer.translate("BOUNTY_TAG") % info().name
	_tag.font = UiStyle.font_hud_big
	_tag.font_size = 48
	_tag.pixel_size = 0.0022
	_tag.fixed_size = true
	_tag.outline_size = 12
	_tag.outline_modulate = ComicUI.INK
	_tag.modulate = ComicUI.RED
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.position = Vector3(0, 2.7, 0)
	v.add_child(_tag)


## Someone you can ask (a walker in reach), or null.
func _walker_near(pos: Vector3) -> Node3D:
	for w: Array in city._people._walkers:
		var v: PlayerVisual = w[0]
		var s: PlayerSimState = w[1]
		if v.visible and s.position.distance_to(pos) < ASK_REACH:
			return v
	return null


## Asking around: they point you the right way, and the area closes in.
func ask(me: SimPlayer) -> void:
	var v := _walker_near(me.state.position)
	if v == null:
		return
	var t: SimPlayer = city.match_node.server.world.players.get(target_id)
	if t == null:
		return
	if _asked.has(v):
		city._people.say(v, CityNpcs._line("BOUNTY_ASKED_AGAIN"), true)
		return
	_asked[v] = true
	var truth := Vector2(t.state.position.x, t.state.position.z)
	var from := Vector2(me.state.position.x, me.state.position.z)
	var far := from.distance_to(truth)
	if _asked.size() > 1 and _rng.randf() < 0.2:  # the first one always knows something
		city._people.say(v, CityNpcs._line("BOUNTY_NO_IDEA"), true)
		return
	var dir := _compass(truth - from)
	var line := CityNpcs._line("BOUNTY_SEEN_NEAR" if far < 120.0 else "BOUNTY_SEEN_FAR") % dir
	city._people.say(v, line, true)
	_close_in(truth, 0.6)


## A scan near them picks up their suit's beacon: the area all but closes.
func on_scan(me: SimPlayer) -> void:
	if not active() or confirmed:
		return
	var t: SimPlayer = city.match_node.server.world.players.get(target_id)
	if t == null or not t.state.alive or t.state.position.distance_to(me.state.position) > CityMode.SCAN_RANGE * 1.3:
		return
	circle_r = SEARCH_MIN
	circle_c = Vector2(t.state.position.x, t.state.position.z) + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
	city._flash_text(TranslationServer.translate("BOUNTY_SCANNED"), ComicUI.MAGENTA)


func _close_in(truth: Vector2, shrink: float) -> void:
	circle_r = maxf(circle_r * shrink, SEARCH_MIN)
	var jitter := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * circle_r * 0.45
	circle_c = truth + jitter


static func _compass(d: Vector2) -> String:
	var a := fposmod(rad_to_deg(atan2(d.x, -d.y)), 360.0)  # 0 = north (-z)
	var names := ["DIR_N", "DIR_NE", "DIR_E", "DIR_SE", "DIR_S", "DIR_SW", "DIR_W", "DIR_NW"]
	return TranslationServer.translate(names[int(round(a / 45.0)) % 8])


## A hold-up on the bounty's people: the target gives up (alive: paid now),
## their crew give up too. True if it was ours.
func surrender(id: int) -> bool:
	if director == null or not (id in director.raiders):
		return false
	var world: SimWorld = city.match_node.server.world
	if not director.surrender(id):
		return false
	if id == target_id:
		var dr: Dictionary = world.drops.back() if not world.drops.is_empty() else {}
		if not dr.is_empty():
			(dr.items as Dictionary).erase("bounty_proof")  # they go with the Marshals, not in pieces
		var pay := Profile.career().claim_bounty(true, _now())
		Profile.save()
		city._flash_text(TranslationServer.translate("BOUNTY_TAKEN_ALIVE") % [str(info().get("name", "")), pay]
				if not info().is_empty() else TranslationServer.translate("BOUNTY_PAID") % pay, ComicUI.GREEN)
		_clear()
	return true


## The board: take a bounty, turn in proof, or give one up.
func open_board() -> void:
	city.open_menu(TranslationServer.translate("BOUNTY_BOARD"), _board_line(), _board_options())


func _board_line() -> String:
	if not active():
		return TranslationServer.translate("BOUNTY_BOARD_LINE")
	var i := info()
	return TranslationServer.translate("BOUNTY_CURRENT") % [i.name, i.crime, int(i.reward),
			roundi(float(i.reward) * Career.BOUNTY_ALIVE)]


func _board_options() -> Array:
	var c := Profile.career()
	var out := []
	if active():
		var proof := int(c.d.stash.get("bounty_proof", 0)) > 0 and down
		out.append([TranslationServer.translate("BOUNTY_TURN_IN") % int(info().reward), proof, ComicUI.GREEN, "bounty:proof"])
		out.append([TranslationServer.translate("BOUNTY_GIVE_UP"), true, ComicUI.RED, "bounty:drop"])
		return out
	for id: String in Career.BOUNTIES:
		var b: Dictionary = Career.BOUNTIES[id]
		var wait := c.bounty_wait(id, _now())
		var text := TranslationServer.translate("BOUNTY_OFFER") % [b.name, int(b.reward), TranslationServer.translate("BOUNTY_KIND_" + str(b.kind).to_upper())]
		if wait > 0:
			text = TranslationServer.translate("BOUNTY_LATER") % [b.name, ceili(wait / 60.0)]
		out.append([text, wait <= 0, ComicUI.YELLOW, "bounty:take:" + id])
	return out


func menu_act(what: String) -> void:
	var c := Profile.career()
	var parts := what.split(":")
	match parts[0]:
		"take":
			if c.take_bounty(parts[1], _now()):
				Profile.save()
				city.garage.visible = false
				city._close_talk()
				_spawn()
				city._flash_text(TranslationServer.translate("BOUNTY_TAKEN") % info().name, ComicUI.YELLOW)
				return
		"proof":
			var pay := c.claim_bounty(false, _now())
			if pay > 0:
				city._flash_text(TranslationServer.translate("BOUNTY_PAID") % pay, ComicUI.GREEN)
				_clear()
		"drop":
			c.drop_bounty()
			_clear()
	Profile.save()
	city.garage.set_menu(_board_line(), _board_options())


## The target (and crew) at their hideout; a first search area around it.
func _spawn() -> void:
	var i := info()
	if i.is_empty():
		return
	var at := WorldLayout.bounty_hideout(bounty_id())
	city._bake_around(at)
	director = RaidDirector.new(city.match_node.server)
	target_id = director._bot("Outlaw", 1, false, at + Vector3(0, 0.3, 0), "raider")
	director.raiders.append(target_id)
	var world: SimWorld = city.match_node.server.world
	var pack: Dictionary = world.packs.get(target_id, {})
	pack["bounty_proof"] = 1
	world.packs[target_id] = pack
	var crew: int = {"gunman": 0, "guarded": 2, "crew": 3}.get(str(i.kind), 0)
	for k in int(crew):
		var a := k * TAU / maxf(float(crew), 1.0)
		var p := WorldTerrain.at(at.x + cos(a) * 4.0, at.z + sin(a) * 4.0)
		director.raiders.append(director._bot("Outlaw·Crew", 1, false, p + Vector3(0, 0.3, 0), "raider"))
	confirmed = false
	hot = false
	down = false
	_asked.clear()
	circle_r = SEARCH_START
	circle_c = Vector2(at.x, at.z) + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * SEARCH_START * 0.5
	_build_portrait()


func _clear() -> void:
	if director != null:
		director.finish()
		director = null
	target_id = 0
	confirmed = false
	hot = false
	down = false
	if _tag != null and is_instance_valid(_tag):
		_tag.queue_free()
	_tag = null
	if portrait != null:
		portrait.queue_free()
		portrait = null
	city._sync_combat()


## The dossier's mugshot: the target's own body, lit, head and shoulders,
## rendered once into a small texture.
func _build_portrait() -> void:
	if portrait != null:
		portrait.queue_free()
	portrait = SubViewport.new()
	portrait.size = Vector2i(160, 160)
	portrait.own_world_3d = true
	portrait.transparent_bg = true
	portrait.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	city.match_node.add_child(portrait)
	var v := PlayerVisual.new()
	portrait.add_child(v)
	var style := "mercenary"
	v.setup("", true, GameMode.team_color(1), target_id, style)
	v.hide_nameplate()
	var s := PlayerSimState.new()
	s.alive = true
	s.yaw = PI  # facing the camera
	v.update_from(null, s, 1.0, 0.0)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.62, 1.25)
	cam.fov = 30.0
	portrait.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 1.5, 0))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 30, 0)
	key.light_energy = 1.4
	portrait.add_child(key)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.55, 0.6)
	e.ambient_light_energy = 0.8
	env.environment = e
	portrait.add_child(env)
	_portrait_frames = 8


func _step_portrait() -> void:
	if portrait == null or _portrait_frames <= 0:
		return
	_portrait_frames -= 1
	if _portrait_frames == 0:
		portrait.render_target_update_mode = SubViewport.UPDATE_ONCE  # a still: no cost after


## The dossier card (CityMode's HUD draws it under the minimap).
func draw_card(ci: CanvasItem, s: float) -> void:
	if not active():
		return
	var i := info()
	var r := Rect2(Vector2(34, 446) * s, Vector2(300, 112) * s)
	ComicUI.draw_panel(ci, r, Color(ComicUI.INK, 0.86), ComicUI.RED, 3.0 * s)
	var face := Rect2(r.position + Vector2(8, 8) * s, Vector2(96, 96) * s)
	ci.draw_rect(face, Color(0.3, 0.12, 0.12, 0.9))
	if portrait != null:
		ci.draw_texture_rect(portrait.get_texture(), face, false)
	ci.draw_rect(face, ComicUI.PAPER, false, 2.0 * s)
	var x := face.end.x + 10 * s
	ComicUI.draw_text(ci, Vector2(x, r.position.y + 24 * s), TranslationServer.translate("BOUNTY_WANTED"), UiStyle.font_hud_big,
			roundi(16 * s), ComicUI.RED, 0, roundi(3 * s))
	ComicUI.draw_text(ci, Vector2(x, r.position.y + 48 * s), str(i.name), UiStyle.font_hud_bold, roundi(19 * s), ComicUI.PAPER, 0,
			roundi(3 * s))
	ComicUI.draw_text(ci, Vector2(x, r.position.y + 70 * s), TranslationServer.translate("BOUNTY_REWARD") % [int(i.reward),
			roundi(float(i.reward) * Career.BOUNTY_ALIVE)], UiStyle.font_hud_bold, roundi(15 * s), ComicUI.GREEN, 0, roundi(3 * s))
	var status := "BOUNTY_STATUS_DOWN" if down else ("BOUNTY_STATUS_SEEN" if confirmed else "BOUNTY_STATUS_SEARCH")
	ComicUI.draw_text(ci, Vector2(x, r.position.y + 94 * s), TranslationServer.translate(status) % roundi(circle_r)
			if status == "BOUNTY_STATUS_SEARCH" else TranslationServer.translate(status), UiStyle.font_hud_bold, roundi(14 * s),
			ComicUI.YELLOW, 0, roundi(3 * s))


## On the minimap: the search area, or (once seen) the target itself.
func draw_on_map(ci: CanvasItem, to_map: Callable, c: Vector2, rad: float, k: float, s: float) -> void:
	if not active():
		return
	var world: SimWorld = city.match_node.server.world
	var t: SimPlayer = world.players.get(target_id)
	var at := circle_c
	if confirmed and t != null and t.state.alive:
		at = Vector2(t.state.position.x, t.state.position.z)
	elif down and t != null:
		at = Vector2(t.state.position.x, t.state.position.z)
	var q: Vector2 = to_map.call(at)
	if q.distance_to(c) > rad - 10 * s:
		var edge := c + (q - c).normalized() * (rad - 12 * s)
		ci.draw_circle(edge, 7 * s, ComicUI.RED)
		ComicUI.draw_text(ci, edge + Vector2(0, 20 * s), TranslationServer.translate("BOUNTY_MAP"), UiStyle.font_hud_bold,
				roundi(11 * s), ComicUI.RED, 1, roundi(3 * s))
		return
	if confirmed or down:
		var d := 6.0 * s
		ci.draw_circle(q, d + 2 * s, ComicUI.INK)
		ci.draw_line(q - Vector2(d, d), q + Vector2(d, d), ComicUI.RED, 3.0 * s)
		ci.draw_line(q + Vector2(-d, d), q + Vector2(d, -d), ComicUI.RED, 3.0 * s)
	else:
		var rr := minf(circle_r * k, rad * 2.0)
		ci.draw_circle(q, rr, Color(ComicUI.RED, 0.18))
		ci.draw_arc(q, rr, 0.0, TAU, 40, Color(ComicUI.RED, 0.85), 2.0 * s)
