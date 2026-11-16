extends Node
## THE HUNT headless verification: plays a whole match on Rustwood Yard with
## six AI hunters (the local player's place taken by a bot, as in spectator
## mode) and reports what happened: treasures taken, dropped, stolen and
## extracted, alarms, kills, the bots' goals over time and the final
## leaderboard. Exits 0 when the match ran to its end with real hunting.
##
##   godot --headless --fixed-fps 60 res://tools/hunt_check.tscn -- [--minutes N]
##
## --fixed-fps runs the simulation as fast as the machine allows.

const MOVEMENT := preload("res://data/hunt_movement.tres")

var server: ServerSession
var counts := {}
var goals := {}
var kills: int = 0
var deaths_while_carrying: int = 0
var started_ms: int = 0
var phase_log: Array = []
var results: Dictionary = {}
var sim_us: Array = []
var step_us: Array = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	started_ms = Time.get_ticks_msec()
	var minutes := Platform.get_user_arg("--minutes", str(GameMode.HUNT_MINUTES)).to_int()
	# --map city: a run at the Rustwood Dig in Kasei Valley's canyon.
	var map_id := Platform.get_user_arg("--map", "hunt")
	var gameplay := Maps.gameplay(map_id)
	add_child(gameplay)
	await get_tree().physics_frame
	server = ServerSession.new()
	server.map_id = map_id
	server.use_primaries = true
	server.game_mode = GameMode.HUNT
	server.time_limit_ticks = minutes * 60 * Sim.TICK_RATE
	add_child(server)
	var spawns: Array[Transform3D] = gameplay.spawn_points_for(GameMode.HUNT) if gameplay.has_method("spawn_points_for") \
			else gameplay.spawn_points()
	var err := server.start(-1, MOVEMENT, Loadouts.ffa(), spawns, gameplay.pickup_spots(), null, [],
			gameplay.hunt_data())
	if map_id == GameMode.CITY_MAP:
		server.world.kill_y = -260.0  # below Deep Furrow, 200 m down
	if err != OK:
		printerr("HUNT CHECK: server failed to start")
		get_tree().quit(1)
		return
	var nav := BotNavigation.new()
	add_child(nav)
	var t_nav := Time.get_ticks_msec()
	nav.build(gameplay)
	while not nav.ready_for_queries:
		await get_tree().physics_frame
	print("HUNT CHECK: navmesh baked in %d ms, %d polygons, %d links" % [Time.get_ticks_msec() - t_nav, nav.navmesh.get_polygon_count(), nav.links.size()])
	server.bot_nav = nav
	server.max_combatants = GameMode.HUNT_BOTS + 1
	server.bot_count = GameMode.HUNT_BOTS + 1  # the spectator's place goes to one more bot
	server.phase_changed.connect(func(p: int) -> void:
		phase_log.append("%s@%d" % [MatchPhase.label_key(p), server.world.tick]))
	server.add_local_spectator()
	var limit_ticks := server.time_limit_ticks + Balance.MODES.countdown_ticks + 600
	while server.phase != MatchPhase.POST_MATCH and server.world.tick < limit_ticks:
		await get_tree().physics_frame
		for e in server.drain_host_events():
			_count(e)
		if server.phase == MatchPhase.PLAYING:
			sim_us.append(server.last_sim_usec)
			step_us.append(server.last_step_usec)
		if server.world.tick % 60 == 0:
			for brain: Variant in server.bots.values():
				if brain is BotBrain:
					var g: String = BotBrain.Goal.keys()[brain.goal]
					goals[g] = goals.get(g, 0) + 1
	_report(minutes)


func _pct(values: Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var v := values.duplicate()
	v.sort()
	return v[mini(int(v.size() * q), v.size() - 1)] / 1000.0


func _count(e: Dictionary) -> void:
	match e.type:
		"hunt":
			counts[e.action] = counts.get(e.action, 0) + 1
		"death":
			if not e.suicide:
				kills += 1
		"results":
			results = e


func _report(minutes: int) -> void:
	var w := server.world
	var wall := (Time.get_ticks_msec() - started_ms) / 1000.0
	print("HUNT CHECK: %d-minute match, %d ticks (%.1f s of play) in %.1f s wall time" % [minutes, w.tick,
			w.tick / float(Sim.TICK_RATE), wall])
	print("HUNT CHECK: phases: %s" % ", ".join(phase_log))
	print("HUNT CHECK: hunters: %d (%d bots)" % [w.players.size(), server.bots.size()])
	print("HUNT CHECK: treasure events: %s" % JSON.stringify(counts))
	print("HUNT CHECK: kills: %d" % kills)
	print("HUNT CHECK: per tick: simulation p50 %.3f / p95 %.3f ms, simulation+AI p50 %.3f / p95 %.3f ms" % [
			_pct(sim_us, 0.5), _pct(sim_us, 0.95), _pct(step_us, 0.5), _pct(step_us, 0.95)])
	var bounty_claimed := 0
	for id in w.hunt.social.claimed:
		bounty_claimed += w.hunt.social.claimed[id]
	print("HUNT CHECK: bounties: %d posted, %d hunters Wanted at the end, %d points claimed" % [
			counts.get("bounty", 0), w.hunt.social.bounty.keys().filter(func(id: int) -> bool: return w.hunt.social.is_wanted(id)).size(),
			bounty_claimed])
	var total_goals := 0
	for g in goals:
		total_goals += goals[g]
	var shares := []
	for g in goals:
		shares.append("%s %d%%" % [g, roundi(100.0 * goals[g] / maxi(total_goals, 1))])
	print("HUNT CHECK: bot goals over time: %s" % ", ".join(shares))
	var board := []
	for id in w.players:
		board.append([w.scores.get(id, 0), w.players[id].display_name, w.hunt.banked_count.get(id, 0)])
	board.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("HUNT CHECK: leaderboard (points, hunter, treasures banked):")
	for row in board:
		print("    %5d  %-10s %d" % row)
	var ok: bool = server.phase == MatchPhase.POST_MATCH and counts.get("take", 0) > 0 and counts.get("extract", 0) > 0
	print("HUNT CHECK: %s" % ("PASS: the match ended on its clock with treasures taken and extracted" if ok
			else "FAIL: phase %s, takes %d, extracts %d" % [MatchPhase.label_key(server.phase), counts.get("take", 0),
			counts.get("extract", 0)]))
	get_tree().quit(0 if ok else 1)
