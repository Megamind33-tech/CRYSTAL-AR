class_name CityHeist
extends RefCounted
## Heists (free roam, with CityMode): planned on the board in your gang's
## back room, done in stages. The Helios Ring vault: three prep jobs (hack
## the Ring's maintenance panel for the codes, sweep the Ring with a scanner
## for the guard rota, leave a getaway vehicle at the drop point), then the
## approach (quiet: at night, masked, few guards who only fight if they see
## you; loud: more guards, all fighting; con: Helios papers, two guards),
## then the finale: through the vault door at the core's far side, crack
## the vault (the bonds), and get clear of Helios. Your crew fights with you
## and takes a share.

const HOLD_SECONDS := 6.0
const ALARM_RANGE := 7.0

var city: CityMode
var guards: RaidDirector
var alarm: bool = false
var _hold: String = ""
var _hold_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_city: CityMode) -> void:
	city = p_city
	_rng.randomize()


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _now() -> int:
	return int(Time.get_unix_time_from_system())


static func board_spot() -> Vector3:
	return CityEstate.gang_spot() + Vector3(3.5, 0, 0)


func fighters() -> Array[int]:
	var out: Array[int] = []
	if guards != null:
		out.append_array(guards.raiders)
	return out


func in_fight() -> bool:
	return guards != null and alarm


func night() -> bool:
	var h := city.hour()
	return h < 6.0 or h > 19.5


func update(me: SimPlayer, busy: bool) -> String:
	var c := Profile.career()
	var pos := me.state.position
	var dt := city.match_node.get_process_delta_time()
	var h := c.heist()
	# Holding at the panel or the vault.
	if not _hold.is_empty():
		var at := WorldLayout.ring_panel() if _hold == "codes" else _vault_safe()
		if pos.distance_to(at) > 3.0 or not me.state.alive:
			_hold = ""
		else:
			_hold_t += dt
			if _hold_t >= HOLD_SECONDS:
				_finish_hold(me)
	if not h.is_empty():
		_step_heist(me, c, h)
	if busy or me.state.vehicle >= 0:
		# The getaway drop: park any vehicle there.
		if not h.is_empty() and h.stage == "prep" and me.state.vehicle >= 0 and not "ride" in h.preps \
				and pos.distance_to(WorldLayout.getaway_spot()) < 8.0 and absf(me.state.vehicle_speed) < 1.0:
			c.heist_prep("ride")
			Profile.save()
			city._flash_text(_t("HEIST_PREP_RIDE"), ComicUI.MAGENTA)
		return ""
	if pos.distance_to(board_spot()) < 2.4:
		return "heist:board"
	if h.is_empty():
		return ""
	if h.stage == "prep" and not "codes" in h.preps and pos.distance_to(WorldLayout.ring_panel()) < 2.6:
		return "heist:codes"
	if h.stage == "finale":
		if pos.distance_to(WorldLayout.vault_door()) < 2.6 and city.estate != null and city.estate.inside.is_empty():
			return "heist:enter"
		if guards != null and int(c.d.stash.get("ring_bonds", 0)) <= 0 and pos.distance_to(_vault_safe()) < 2.2:
			return "heist:crack"
	return ""


func _vault_safe() -> Vector3:
	return (WorldLayout.INTERIORS.office as Vector3) + Vector3(5.0, 0, 3.0)


func _step_heist(me: SimPlayer, c: Career, h: Dictionary) -> void:
	if h.stage != "finale" or guards == null:
		# The getaway: out of Helios with the bonds.
		if int(c.d.stash.get("ring_bonds", 0)) > 0 and _clear_of_helios(me):
			_paid(c)
		return
	# Quiet or con: they fight only once they see you (or you start it).
	if not alarm:
		for id: int in guards.raiders:
			var p: SimPlayer = city.match_node.server.world.players.get(id)
			if p == null:
				continue
			var hurt := not p.state.alive or p.state.health < Balance.PLAYER.max_health - 0.5
			if hurt or (h.approach == "quiet" and p.state.position.distance_to(me.state.position) < ALARM_RANGE):
				_raise_alarm(me)
				break
	var state := guards.step()
	if state == 2:  # you fell: the job's blown, the bonds are lost
		_set_down(c)
		city._flash_text(_t("HEIST_FAILED"), ComicUI.RED)
		return
	if int(c.d.stash.get("ring_bonds", 0)) > 0 and _clear_of_helios(me):
		_paid(c)


func _clear_of_helios(me: SimPlayer) -> bool:
	if me.state.position.y < WorldLayout.INTERIOR_Y + 100.0:
		return false
	var hc := WorldLayout.HELIOS
	return Vector2(me.state.position.x - hc.x, me.state.position.z - hc.y).length() > WorldLayout.HEIST_ESCAPE


func _paid(c: Career) -> void:
	var pay := c.heist_payout(_now())
	if guards != null:
		guards.finish()
		guards = null
	alarm = false
	Profile.save()
	city._sync_combat()
	if pay > 0:
		city._flash_text(_t("HEIST_PAID") % pay, ComicUI.GREEN)
		city.news("MARSNET_HEIST", [], 30)


func _set_down(c: Career) -> void:
	c.d.stash.erase("ring_bonds")
	if guards != null:
		guards.finish()
		guards = null
	alarm = false
	c.heist().stage = "finale"  # the preps stand: try again
	Profile.save()
	city._sync_combat()


func _raise_alarm(me: SimPlayer) -> void:
	if alarm:
		return
	alarm = true
	me.team = 0
	for id: int in guards.raiders:
		var brain: Variant = city.match_node.server.bots.get(id)
		if brain != null and "hunt" in brain:
			brain.hunt = true
	city._flash_text(_t("HEIST_ALARM"), ComicUI.RED)
	city._sync_combat()


func prompt(key: String) -> String:
	match key:
		"heist:board":
			return _t("HEIST_PROMPT_BOARD")
		"heist:codes":
			return _t("HEIST_HACKING") % roundi(_hold_t / HOLD_SECONDS * 100.0) if _hold == "codes" else _t("HEIST_PROMPT_CODES")
		"heist:enter":
			return _t("HEIST_PROMPT_ENTER")
		"heist:crack":
			return _t("HEIST_CRACKING") % roundi(_hold_t / HOLD_SECONDS * 100.0) if _hold == "crack" else _t("HEIST_PROMPT_CRACK")
	return ""


func act(key: String, me: SimPlayer) -> void:
	var c := Profile.career()
	match key:
		"heist:board":
			city.open_menu(_t("HEIST_BOARD"), _board_line(), _board_options())
		"heist:codes":
			if int(c.d.stash.get("scanner", 0)) <= 0:
				city._note(_t("HEIST_NEED_SCANNER"), ComicUI.YELLOW)
			elif _hold.is_empty():
				_hold = "codes"
				_hold_t = 0.0
		"heist:enter":
			_enter_vault(me, c)
		"heist:crack":
			if _hold.is_empty():
				_hold = "crack"
				_hold_t = 0.0
				if c.heist().approach == "con" and not alarm and _rng.randf() < 0.5:
					_raise_alarm(me)  # a con only lasts so long


func _finish_hold(me: SimPlayer) -> void:
	var c := Profile.career()
	var what := _hold
	_hold = ""
	if what == "codes":
		c.heist_prep("codes")
		Profile.save()
		city._flash_text(_t("HEIST_PREP_CODES"), ComicUI.MAGENTA)
	elif what == "crack":
		c.receive("ring_bonds", 1)
		Profile.save()
		var a: String = c.heist().approach
		city.crime("heist" if alarm or a == "loud" else ("heist_con" if a == "con" else "heist_quiet"))
		city._flash_text(_t("HEIST_GOT_BONDS"), ComicUI.GREEN)


## A scan near the Ring takes the guard rota (CityMode.scan calls this).
func on_scan(me: SimPlayer) -> void:
	var c := Profile.career()
	var h := c.heist()
	if h.is_empty() or h.stage != "prep" or "intel" in h.preps:
		return
	var hc := WorldLayout.HELIOS
	if Vector2(me.state.position.x - hc.x, me.state.position.z - hc.y).length() < 90.0:
		c.heist_prep("intel")
		Profile.save()
		city._flash_text(_t("HEIST_PREP_INTEL"), ComicUI.MAGENTA)


## Through the vault door: the counting room, its guards, your crew.
func _enter_vault(me: SimPlayer, c: Career) -> void:
	var a: String = c.heist().approach
	if bool(Career.HEIST_APPROACHES[a].get("night", false)) and not night():
		city._note(_t("HEIST_WAIT_NIGHT"), ComicUI.YELLOW)
		return
	var o: Vector3 = WorldLayout.INTERIORS.office
	city.estate.inside = ["", "office", WorldLayout.vault_door()]
	city.match_node.server.world.teleport(me, WorldLayout.interior_exit("office") + Vector3(0, 0, -1.4))
	guards = RaidDirector.new(city.match_node.server)
	guards._defender = me.net_id  # step() says when you fall
	alarm = false
	var n: int = Career.HEIST_APPROACHES[a].guards
	for k in n:
		# At the back of the room, by the vault: you come in at the door.
		var at := o + Vector3(-4.5 + (k % 3) * 4.5, 0.3, -3.6 + (k / 3) * 1.6)
		guards.raiders.append(guards._bot("Xanadu·Vault Guard %d" % (k + 1), 1, false, at, "concern"))
	city.estate.crew_join(guards, me)
	if a == "loud":
		_raise_alarm(me)
	else:
		city._note(_t("HEIST_IN_QUIET") if a == "quiet" else _t("HEIST_IN_CON"), ComicUI.CYAN)


func _board_line() -> String:
	var c := Profile.career()
	var h := c.heist()
	if h.is_empty():
		return _t("HEIST_BOARD_LINE")
	var info: Dictionary = Career.HEISTS[h.id]
	var lines := PackedStringArray([str(info.name)])
	for p: String in info.preps:
		lines.append(("✔ " if p in h.preps else "· ") + _t("HEIST_PREP_" + p.to_upper() + "_TODO"))
	if h.stage == "finale":
		lines.append(_t("HEIST_GO") % _t("HEIST_APPROACH_" + str(h.approach).to_upper()))
	return "\n".join(lines)


func _board_options() -> Array:
	var c := Profile.career()
	var h := c.heist()
	var out := []
	if h.is_empty():
		var wait := c.heist_wait("ring", _now())
		out.append([_t("HEIST_PLAN") % Career.HEISTS.ring.name if wait <= 0 else _t("HEIST_LATER") % ceili(wait / 60.0),
				wait <= 0, ComicUI.MAGENTA, "heist:plan:ring"])
		return out
	if h.stage == "prep" and c.heist_ready():
		for a: String in Career.HEIST_APPROACHES:
			var block := c.approach_blocker(a, _now(), night())
			var text := _t("HEIST_APPROACH_" + a.to_upper())
			if not block.is_empty():
				text += " · " + _t("HEIST_BLOCK_" + block.to_upper())
			out.append([text, block.is_empty() or block == "night", ComicUI.CYAN, "heist:approach:" + a])
	out.append([_t("HEIST_ABANDON"), true, ComicUI.RED, "heist:abandon"])
	return out


func menu_act(what: String) -> void:
	var c := Profile.career()
	var parts := what.split(":")
	match parts[0]:
		"plan":
			if c.plan_heist(parts[1], _now()):
				city._flash_text(_t("HEIST_PLANNED"), ComicUI.MAGENTA)
		"approach":
			# Quiet waits for the night to go in (the choice can be made by day).
			if c.choose_approach(parts[1], _now(), true if parts[1] == "quiet" else night()):
				city._flash_text(_t("HEIST_CHOSEN") % _t("HEIST_APPROACH_" + parts[1].to_upper()), ComicUI.MAGENTA)
		"abandon":
			c.abandon_heist()
			if guards != null:
				guards.finish()
				guards = null
			alarm = false
			city._sync_combat()
	Profile.save()
	city.garage.set_menu(_board_line(), _board_options())


func map_places() -> Array:
	var h := Profile.career().heist()
	if h.is_empty():
		return []
	var out := []
	if h.stage == "prep":
		if not "codes" in h.preps:
			out.append([WorldLayout.ring_panel(), "H", ComicUI.MAGENTA])
		if not "ride" in h.preps:
			out.append([WorldLayout.getaway_spot(), "G", ComicUI.MAGENTA])
	else:
		out.append([WorldLayout.vault_door(), "V", ComicUI.RED])
	return out
