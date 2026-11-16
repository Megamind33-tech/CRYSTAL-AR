class_name CitySocial
extends RefCounted
## MarsNet and the people in your life (free roam, with CityMode). The feed
## carries the valley's chatter (people post every minute or two), the
## news of what you do (bounties brought in, heists, homes bought, your
## gang's rise, a manhunt) and your snaps; likes and notoriety are fame,
## and fame changes things (people know you; the trade finds you faster).
## And Rhea Okoye, met at the Galleria: she texts invites (a place, a time)
## and you turn up and stay a while, or you don't.

const AMBIENT := Vector2(70.0, 150.0)
const MEET_REACH := 3.5

var city: CityMode
var panel: MarsNetPanel
var _ambient_t: float = 40.0
var _invite_t: float = 0.0
var _with_t: float = 0.0
var _tier_seen: int = -1
var _stars_posted: int = 0
var _linger_t: float = 0.0       ## after a good time she stays a little
var _linger_at := Vector3.INF
var _rng := RandomNumberGenerator.new()


func _init(p_city: CityMode, layer: CanvasLayer) -> void:
	city = p_city
	_rng.randomize()
	panel = MarsNetPanel.new()
	layer.add_child(panel)
	panel.closed.connect(city._close_talk)
	panel.snap.connect(_snap)


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func open() -> void:
	panel.open()
	city.match_node.input.enabled = false
	city._touch_was_visible = city.match_node.touch.visible
	city.match_node.touch.release_all()
	city.match_node.touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A post about you (or the news). `fame` what it does for yours.
func news(key: String, args: Array, fame: int, who_key: String = "MARSNET_NEWS") -> void:
	var c := Profile.career()
	var text := _t(key) % args if not args.is_empty() else _t(key)
	c.post(_t(who_key), text, _rng.randi_range(20, 120) + fame * 3, _now(), fame)
	Profile.save()
	city._note(_t("MARSNET_PING") % text.left(60), ComicUI.CYAN)


func update(me: SimPlayer, busy: bool) -> String:
	var c := Profile.career()
	var dt := city.match_node.get_process_delta_time()
	CityNpcs.fame_tier = c.fame_tier()
	# The valley talks.
	_ambient_t -= dt
	if _ambient_t <= 0.0:
		_ambient_t = _rng.randf_range(AMBIENT.x, AMBIENT.y)
		var lines := _t("MARSNET_CHATTER").split("|")
		var pick := lines[_rng.randi() % lines.size()].split("::")
		if pick.size() == 2:
			c.post(pick[0], pick[1], _rng.randi_range(2, 60), _now())
	# A manhunt makes the news.
	if city.wanted.stars >= 3 and _stars_posted < 3:
		_stars_posted = 3
		news("MARSNET_MANHUNT", [], 10)
	elif city.wanted.stars == 0:
		_stars_posted = 0
	# Fame tiers.
	var tier := c.fame_tier()
	if _tier_seen >= 0 and tier > _tier_seen:
		city._flash_text(_t("MARSNET_TIER") % Career.FAME_TIERS[tier][1], ComicUI.CYAN)
	_tier_seen = tier
	_step_partner(me, c, dt)
	if busy or me.state.vehicle >= 0 or city._people == null:
		return ""
	var pat := city._people.meet_position("partner")
	if pat != Vector3.INF and pat.distance_to(me.state.position) < MEET_REACH:
		return "social:partner"
	return ""


## Rhea: waiting at the Galleria until you meet; then invites; then, when
## the bond's strong, at home.
func _step_partner(me: SimPlayer, c: Career, dt: float) -> void:
	if city._people == null:
		return
	var now := _now()
	var where := Vector3.INF
	if not c.partner_met():
		where = WorldLayout.partner_first()
	else:
		_invite_t -= dt
		if _invite_t <= 0.0:
			_invite_t = 5.0
			var inv := c.next_invite(now, _rng.randf())
			if not inv.is_empty():
				city._flash_text(_t("PARTNER_INVITE") % [c.PARTNER.name, _t("HANGOUT_" + str(inv.place).to_upper())], ComicUI.MAGENTA)
				Profile.save()
			if c.invite_lapsed(now):
				city._note(_t("PARTNER_STOOD_UP") % c.PARTNER.name, ComicUI.RED)
				Profile.save()
		var invite: Dictionary = c.d.partner.invite
		_linger_t = maxf(_linger_t - dt, 0.0)
		if not invite.is_empty():
			where = WorldLayout.hangout_spot(invite.place)
		elif _linger_t > 0.0:
			where = _linger_at
		elif c.bond() >= Career.BOND_HOME:
			where = (WorldLayout.residences()[0][1] as Vector3) + Vector3(-1.5, 0, 0)
		else:
			where = WorldLayout.partner_first()  # at work's end, at the Galleria
	if where == Vector3.INF:
		city._people.unmeet("partner")
		_with_t = 0.0
		return
	var at := city._people.meet_position("partner")
	if at != Vector3.INF and at.distance_to(where) > 2.0:
		city._people.unmeet("partner")
	city._people.meet("partner", c.PARTNER.name, where)
	# Hanging out: stay close a while.
	if c.partner_met() and not (c.d.partner.invite as Dictionary).is_empty():
		if me.state.position.distance_to(where) < 6.0:
			_with_t += dt
			if _with_t >= Career.HANGOUT_SECONDS:
				_with_t = 0.0
				_linger_t = 30.0
				_linger_at = where
				c.hung_out(now)
				Profile.save()
				city._flash_text(_t("PARTNER_HUNG_OUT") % [c.PARTNER.name, c.bond()], ComicUI.MAGENTA)
				var pv := city._people.meet_visual("partner")
				if pv != null:
					city._people.say(pv, CityNpcs._line("PARTNER_HAPPY"), true)
				if c.bond() >= Career.BOND_FIGHTS and c.bond() - 12 < Career.BOND_FIGHTS:
					city._note(_t("PARTNER_FIGHTS") % c.PARTNER.name, ComicUI.MAGENTA)
				if c.bond() >= Career.BOND_HOME and c.bond() - 12 < Career.BOND_HOME:
					news("MARSNET_COUPLE", [c.PARTNER.name], 15)
		else:
			_with_t = maxf(_with_t - dt, 0.0)


func prompt(key: String) -> String:
	var c := Profile.career()
	if key == "social:partner":
		if not c.partner_met():
			return _t("PARTNER_PROMPT_MEET") % c.PARTNER.name
		if not (c.d.partner.invite as Dictionary).is_empty():
			return _t("PARTNER_PROMPT_TOGETHER") % [c.PARTNER.name, roundi(_with_t / Career.HANGOUT_SECONDS * 100.0)]
		return _t("PARTNER_PROMPT_TALK") % c.PARTNER.name
	return ""


func act(key: String, _me: SimPlayer) -> void:
	var c := Profile.career()
	if key != "social:partner":
		return
	var v := city._people.meet_visual("partner")
	if not c.partner_met():
		c.meet_partner(_now())
		Profile.save()
		city._flash_text(_t("PARTNER_MET") % [c.PARTNER.name, c.PARTNER.role], ComicUI.MAGENTA)
		if v != null:
			city._people.say(v, CityNpcs._line("PARTNER_HELLO"), true)
		return
	if v != null:
		city._people.say(v, CityNpcs._line("PARTNER_CHAT"), true)


## A photo of where you are, posted: the panel steps aside for the shot.
func _snap() -> void:
	panel.visible = false
	# Every overlay out of the shot (HUD, buttons, the city's panels).
	var hidden: Array[CanvasLayer] = []
	for n: Node in city.match_node.get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl.visible:
			cl.visible = false
			hidden.append(cl)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := city.match_node.get_viewport().get_texture().get_image()
	for cl: CanvasLayer in hidden:
		cl.visible = true
	img.resize(640, int(640.0 * img.get_height() / maxf(img.get_width(), 1.0)), Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute("user://snaps")
	var path := "user://snaps/%d.png" % _now()
	img.save_png(path)
	var c := Profile.career()
	var likes := 3 + c.fame_tier() * 25 + _rng.randi_range(0, 40)
	var caption := _t("MARSNET_SNAP_CAPTION").split("|")
	c.post(_t("MARSNET_YOU"), caption[_rng.randi() % caption.size()] % _t("WORLD_" + city.region.to_upper())
			if TranslationServer.translate("WORLD_" + city.region.to_upper()) != "WORLD_" + city.region.to_upper()
			else caption[0] % _t("WORLD_OPEN"), likes, _now(), 2 + likes / 20, path)
	Profile.save()
	panel.open()
	city._note(_t("MARSNET_POSTED") % likes, ComicUI.CYAN)
