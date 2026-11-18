extends Node
## THE HUNT's AI-first playtest (docs/game-plan.md, decision 2): a campaign
## of whole dig runs back to back, AI only, with one AI standing in for the
## player: it has a nation and a Career that carries over from run to run
## (squadmates, grudges, the pacing of turns), exactly as the game uses it.
## Reports per run and for the campaign, and exits 0 only if the game held:
##   - every run played to its clock, with cargo taken and extracted;
##   - nobody stood stuck (alive, not extracting, < 2 m in 60 s);
##   - every run seated four nations and formed the stand-in's squad;
##   - nobody turned on the stand-in on the guided first run, never twice
##     within Career.TURN_GAP_RUNS, and a grudge the stand-in earned came
##     back (it turns on its squadmate once, mid-campaign, as a player might).
## It can't say whether it's fun: it measures the pacing for a person to judge.
##
##   godot --headless --fixed-fps 60 res://tools/playtest.tscn -- [--runs 8] [--minutes 6]

const MOVEMENT := preload("res://data/hunt_movement.tres")
const STANDIN := 1000  ## the first bot takes the player's place
const BETRAY_RUN := 3  ## the run the stand-in turns on its squadmate (0-based)

var career := Career.new()
var gameplay: Node
var nav: BotNavigation
var failures: Array[String] = []
var summary: Array[Dictionary] = []
var _server: ServerSession


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var runs := Platform.get_user_arg("--runs", "8").to_int()
	var minutes := Platform.get_user_arg("--minutes", "6").to_int()
	career.choose_nation(0)
	gameplay = Maps.gameplay(GameMode.CITY_MAP)
	add_child(gameplay)
	await get_tree().physics_frame
	nav = BotNavigation.new()
	add_child(nav)
	nav.build(gameplay)
	while not nav.ready_for_queries:
		await get_tree().physics_frame
	for i in runs:
		var r: Dictionary = await _one_run(i, minutes)
		summary.append(r)
		_print_run(i, r)
	_print_campaign()
	print("PLAYTEST: %s" % ("PASS" if failures.is_empty() else "FAIL\n  - " + "\n  - ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)


func _one_run(index: int, minutes: int) -> Dictionary:
	var server := ServerSession.new()
	server.map_id = GameMode.CITY_MAP
	server.use_primaries = true
	server.game_mode = GameMode.HUNT
	server.time_limit_ticks = minutes * 60 * Sim.TICK_RATE
	add_child(server)
	_server = server
	var err := server.start(-1, MOVEMENT, Loadouts.ffa(), gameplay.spawn_points_for(GameMode.HUNT), gameplay.pickup_spots(),
			null, [], gameplay.hunt_data())
	server.world.kill_y = -260.0
	var h := server.world.hunt
	h.home_nations = {STANDIN: career.nation()}
	server.bot_nav = nav
	server.max_combatants = GameMode.HUNT_BOTS + 1
	server.bot_count = GameMode.HUNT_BOTS + 1
	server.add_local_spectator()
	var r := {"ok": err == OK, "counts": {}, "kills": 0, "first_extract_s": -1.0, "standin_banked": 0, "stuck": [],
			"squadmate": "", "nations": 0, "turned_on_me": "", "i_turned": false, "ff_warnings": 0, "deaths": {},
			"may_turn": false, "grudge": false, "jumps_per_bot_min": 0.0}
	var seated := false
	var mate := 0
	var trail := {}  ## id -> [[tick, position], ...] every 5 s
	var limit := server.time_limit_ticks + Balance.MODES.countdown_ticks + 60 * Sim.TICK_RATE
	while server.phase != MatchPhase.POST_MATCH and server.world.tick < limit:
		await get_tree().physics_frame
		var w := server.world
		if not seated and not h.nations.is_empty():
			seated = true
			mate = h.social.allies.get(STANDIN, 0)
			_name_and_pace(server, mate, r)
		for e in server.drain_host_events():
			_count(e, r, w, mate)
		if seated and index == BETRAY_RUN and not r.i_turned and h.social.allied(STANDIN, mate) \
				and server.phase == MatchPhase.PLAYING and w.tick > 120 * Sim.TICK_RATE:
			h.request(w, STANDIN, "betray_alliance")  # a player turning on their squad
		if server.phase == MatchPhase.PLAYING and w.tick % (5 * Sim.TICK_RATE) == 0:
			_check_stuck(w, h, trail, r)
	var jumps := 0
	for b: Variant in server.bots.values():
		if b is BotBrain:
			jumps += b.jumps
	r.jumps_per_bot_min = jumps / maxf(1.0, server.bots.size() * w_minutes(server))
	r.ok = r.ok and server.phase == MatchPhase.POST_MATCH
	r.standin_banked = int(h.banked_count.get(STANDIN, 0))
	var n := {}
	for id: int in h.nations:
		n[h.nations[id]] = true
	r.nations = n.size()
	career.record_squad_run(r.squadmate, r.turned_on_me if r.turned_on_me != "" else ("i_turned" if r.i_turned else ""))
	career.settle("playtest-%d" % index, h.haul.get(STANDIN, []))
	server.queue_free()
	await get_tree().physics_frame
	return r


## Minutes of match clock played (bots only move once it runs).
func w_minutes(server: ServerSession) -> float:
	return server.world.tick / float(Sim.TICK_RATE * 60)


## As Match._setup_squad: the AI take their nations' names and characters;
## the stand-in's squadmate gets the career's pacing and any grudge.
func _name_and_pace(server: ServerSession, mate: int, r: Dictionary) -> void:
	var h := server.world.hunt
	var used := {}
	if mate != 0:
		r.squadmate = career.pick_squadmate(server.world.match_seed)
		used[r.squadmate] = true
	var ids: Array = h.nations.keys()
	ids.sort()
	for id: int in ids:
		if id == STANDIN:
			h.personalities[id] = "loyal"  # a player doesn't turn by the AI's rules
			h.may_turn[id] = false
			continue
		var who: String = r.squadmate if id == mate else ""
		if who.is_empty():
			var free := Nations.names(h.nation_of(id)).filter(func(x: String) -> bool: return not used.has(x))
			who = free[absi(server.world.match_seed + id) % free.size()] if not free.is_empty() else ""
		if who.is_empty():
			continue
		used[who] = true
		server.rename_bot(id, who)
		h.personalities[id] = Nations.personality(who)
	if mate != 0:
		h.may_turn[mate] = career.squadmate_may_turn(r.squadmate)
		h.grudges[mate] = career.grudge(r.squadmate)
		r.may_turn = h.may_turn[mate]
		r.grudge = h.grudges[mate]


func _count(e: Dictionary, r: Dictionary, w: SimWorld, mate: int) -> void:
	match e.type:
		"hunt":
			r.counts[e.action] = int(r.counts.get(e.action, 0)) + 1
			if e.action == "extract" and r.first_extract_s < 0.0:
				r.first_extract_s = w.tick / float(Sim.TICK_RATE)
			if e.action == "friendly_fire":
				r.ff_warnings += 1
			if e.action == "alliance_betrayed" and e.get("squad", false):
				if e.target == STANDIN:
					r.turned_on_me = "turned_on_me"
					r["turn_reason"] = str(e.get("reason", ""))
				elif e.player == STANDIN:
					r.i_turned = true
		"death":
			if not e.suicide:
				r.kills += 1
			r.deaths[e.victim] = int(r.deaths.get(e.victim, 0)) + 1


## Stuck: trying to get somewhere (an objective, roaming or a chase, not
## yet there) and under 2 m of movement in 60 s. Holding a position to fight
## (ATTACK), falling back (RETREAT) or camping the last pad isn't stuck.
func _check_stuck(w: SimWorld, h: HuntRules, trail: Dictionary, r: Dictionary) -> void:
	for id: int in w.players:
		var p: SimPlayer = w.players[id]
		var t: Array = trail.get(id, [])
		var brain: Variant = _server.bots.get(id)
		var going: bool = brain is BotBrain and (brain.goal in [BotBrain.Goal.OBJECTIVE, BotBrain.Goal.ROAM, BotBrain.Goal.CHASE]) \
				and not (brain._aim_target != Vector3.INF and p.state.position.distance_to(brain._aim_target) < 2.5)
		if not p.state.alive or not going or int(h.extract_progress.get(id, 0)) > 0 or h.cache_of(id) != null or h.vault_unlocker == id:
			trail[id] = []
			continue
		t.append([w.tick, p.state.position])
		t = t.filter(func(x: Array) -> bool: return w.tick - int(x[0]) <= 60 * Sim.TICK_RATE)
		trail[id] = t
		if t.size() >= 12 and (t[0][1] as Vector3).distance_to(p.state.position) < 2.0 and not (p.display_name in r.stuck):
			r.stuck.append(p.display_name)
			print("PLAYTEST   stuck: %s at %s, goal %s, carrying %s, aiming at %s, vault %s (grand at %s, available %s), tick %d" % [p.display_name, p.state.position,
					BotBrain.Goal.keys()[brain.goal] if brain is BotBrain else "?", h.carried_by(id) != null,
					brain._aim_target if brain is BotBrain else "?", h.vault, h.grand().position if h.grand() != null else "-",
					h.grand_available(w.tick) if h.grand() != null else false, w.tick])


func _print_run(i: int, r: Dictionary) -> void:
	var c: Dictionary = r.counts
	print("PLAYTEST run %d: %s, nations %d, squadmate %s (may turn %s%s), takes %d, extracts %d, steals %d, kills %d, first extraction %s, stand-in banked %d, turned on stand-in: %s, stand-in turned: %s, friendly-fire warnings %d, jumps/bot/min %.2f, stuck: %s" % [
			i + 1, "clock" if r.ok else "DID NOT FINISH", r.nations, r.squadmate, r.may_turn, ", grudge" if r.grudge else "",
			c.get("take", 0), c.get("extract", 0), c.get("steal", 0), r.kills,
			("%.0f s" % r.first_extract_s) if r.first_extract_s >= 0.0 else "none", r.standin_banked,
			(r.turned_on_me + " (" + str(r.get("turn_reason", "")) + ")") if r.turned_on_me != "" else "no", r.i_turned,
			r.ff_warnings, r.jumps_per_bot_min, ", ".join(r.stuck) if not r.stuck.is_empty() else "nobody"])
	if not r.ok:
		failures.append("run %d didn't play to its clock" % (i + 1))
	if int(c.get("take", 0)) == 0 or int(c.get("extract", 0)) == 0:
		failures.append("run %d: no cargo taken or extracted" % (i + 1))
	if not r.stuck.is_empty():
		failures.append("run %d: stuck %s" % [i + 1, r.stuck])
	if r.nations != 4:
		failures.append("run %d seated %d nations" % [i + 1, r.nations])
	if r.squadmate == "":
		failures.append("run %d: the stand-in had no squadmate" % (i + 1))


func _print_campaign() -> void:
	var turns: Array = []
	var reasons := {}
	var mates := {}
	var firsts: Array = []
	for i in summary.size():
		var r: Dictionary = summary[i]
		mates[r.squadmate] = true
		if r.first_extract_s >= 0.0:
			firsts.append(r.first_extract_s)
		if r.turned_on_me != "":
			turns.append(i)
			reasons[r.get("turn_reason", "")] = true
	firsts.sort()
	var jpm := 0.0
	for r: Dictionary in summary:
		jpm += r.jumps_per_bot_min
	print("PLAYTEST bot jumps per bot per minute: %.2f" % (jpm / maxf(1.0, summary.size())))
	print("PLAYTEST campaign: %d runs, %d different squadmates, turns on the stand-in in runs %s (reasons %s), median first extraction %s" % [
			summary.size(), mates.size(), turns.map(func(i: int) -> int: return i + 1), reasons.keys(),
			("%.0f s" % firsts[firsts.size() / 2]) if not firsts.is_empty() else "none"])
	if 0 in turns:
		failures.append("someone turned on the stand-in on the guided first run")
	for k in range(1, turns.size()):
		var gap: int = turns[k] - turns[k - 1]
		var grudge_run: bool = summary[turns[k]].grudge
		if gap < Career.TURN_GAP_RUNS and not grudge_run:
			failures.append("turns on the stand-in only %d runs apart (runs %d and %d)" % [gap, turns[k - 1] + 1, turns[k] + 1])
	if summary.size() > BETRAY_RUN and not summary[BETRAY_RUN].i_turned:
		failures.append("the stand-in couldn't turn on its squadmate (run %d)" % (BETRAY_RUN + 1))
