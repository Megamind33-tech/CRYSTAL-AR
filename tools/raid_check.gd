extends Node
## Headless check of a Concern raid on Dust Hollow: the open world with a
## held Hollow and a raid due; the player walks in (and stands still: the
## militia does the fighting). Reports the raid starting, the kills, how it
## ended and that its fighters left. Never touches the real profile.
##   godot --headless --fixed-fps 60 res://tools/raid_check.tscn

const MATCH := preload("res://game/match.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Platform.storage_available = false
	var c := Profile.career()
	c.d.hollow.owner = "player"
	c.d.hollow.raid_due = true
	c.d.trust = {"foreman": Career.FRIEND, "armourer": Career.FRIEND}  # a strong militia: 4
	MatchConfig.pending = MatchConfig.for_place(GameMode.CITY, "You")
	var m: Node = MATCH.instantiate()
	add_child(m)
	while m.server == null or m.server.phase != MatchPhase.PLAYING or m.server.bot_nav == null \
			or not m.server.bot_nav.ready_for_queries:
		await get_tree().physics_frame
	var me: SimPlayer = m.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	for i in 30:
		await get_tree().physics_frame
	m.server.world.teleport(me, WorldTerrain.at(WorldLayout.HOLLOW.x - 10, WorldLayout.HOLLOW.z - 14) + Vector3(0, 0.3, 0))
	var kills := 0
	var started := -1
	var t0: int = m.server.world.tick
	while m.server.world.tick - t0 < 60 * 240:
		await get_tree().physics_frame
		if started < 0 and m.city.raid_on():
			started = m.server.world.tick
			print("RAID CHECK: raid started: %d raiders, %d militia" % [m.city.raid_status().x, m.city.raid_status().y])
		if started >= 0 and not m.city.raid_on():
			break
		for e in m.server.world._events:
			if e.type == "death":
				kills += 1
	var bots_left: int = m.server.bots.size()
	var owns := Profile.career().owns_hollow()
	print("RAID CHECK: %s after %.0f s, %d deaths, hollow %s, bots left %d, damage %s" % [
			"ended" if started >= 0 and not m.city.raid_on() else "STILL GOING",
			(m.server.world.tick - maxi(started, t0)) / 60.0, kills, "held" if owns else "lost", bots_left,
			m.server.world.damage_enabled])
	var ok: bool = started >= 0 and not m.city.raid_on() and bots_left == 0 and not m.server.world.damage_enabled
	print("RAID CHECK: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
