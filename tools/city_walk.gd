extends Node
## THE HUNT city screenshots: starts the real city match (Tharsis Gate),
## poses the player around the plaza (phone layout), opens a terminal.
##   xvfb-run ... godot ... res://tools/city_walk.tscn -- --out DIR

const MATCH := preload("res://game/match.tscn")

var out_dir := "user://city_walk"
var m: Node


func _ready() -> void:
	out_dir = Platform.get_user_arg("--out", out_dir)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	Platform.storage_available = false  # never touch the real profile
	if Platform.user_args.has("--phone-lod"):
		get_viewport().mesh_lod_threshold = 4.0  # as project.godot's .mobile override
	var dig := Platform.user_args.has("--dig-only")
	Platform.storage_available = false
	if dig:  # Adaeze, a friend, comes along
		Profile.career().d.trust = {"foreman": Career.FRIEND}
		Profile.career().d.companion = "foreman"
		Profile.career().d.oxygen = 46.0
		Profile.career().d.stash = {"oxygen_canister": 1}
	if Platform.user_args.has("--people"):
		Profile.career().d["body"] = "female"  # play as a woman
	MatchConfig.pending = MatchConfig.for_place(GameMode.HUNT if dig else GameMode.CITY, "You")
	m = MATCH.instantiate()
	add_child(m)
	await _frames(200)
	m.touch.visible = true
	m.hud._touch = true
	var me: SimPlayer = m.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	print("CITY WALK: player at %s, phase %s" % [me.state.position, m.server.phase])
	if dig:
		await _dig_run(me)
		return
	var o := CityLayout.ORIGIN
	await _pose(me, o + Vector3(0, 0.05, 30), 0.0, -0.05)
	await _shot("c1_arrival")
	if Platform.user_args.has("--perf"):
		await _perf_probe(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--police"):
		await _police_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--people"):
		await _people_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--homes"):
		await _homes_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--tools"):
		var tc := Profile.career()
		tc.d.wallet = 900
		tc.d.stash = {"medkit": 2, "armour_plate": 1, "crowbar": 1, "lockpick": 3, "mask": 1, "stim_cola": 2}
		var store: Array = WorldLayout.shops()[2]
		await _pose(me, (store[1] as Vector3) + Vector3(0, 0.05, 0), float(store[3]) - PI, -0.12)
		me.state.health = 40.0
		await _frames(10)
		await _shot("t1_quick_heal_button")
		m.input.press(PlayerCommand.Action.INTERACT)
		await _frames(20)
		m.city.shelf._sel_side = 1
		m.city.shelf._sel_item = "crowbar"
		m.city.shelf.refresh()
		await _frames(10)
		await _shot("t2_store_tools")
		m.city.shelf.close()
		m.city.quick_use()
		print("CITY WALK: healed to %.0f, medkits left %d" % [me.state.health, int(tc.d.stash.get("medkit", 0))])
		get_tree().quit(0)
		return
	if Platform.user_args.has("--garage"):
		await _garage_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--meat"):
		var mc := Profile.career()
		mc.d.wallet = 600
		mc.d.stash = {"vat_meat": 2, "fresh_meat": 1, "meal_pack": 1}
		me.state.food = 22.0
		var shop: Array = WorldLayout.shops()[2]
		await _pose(me, (shop[1] as Vector3) + Vector3(0, 0.05, 0), float(shop[3]) - PI, -0.12)
		await _frames(10)
		await _shot("m1_hungry")
		m.input.press(PlayerCommand.Action.INTERACT)
		await _frames(20)
		m.city.shelf._sel_side = 0
		m.city.shelf._sel_item = "fresh_meat"
		m.city.shelf.refresh()
		await _frames(10)
		await _shot("m2_meat_shelf")
		m.city.shelf.close()
		m.city.open_pack()
		m.city.shelf._sel_side = 0
		m.city.shelf._sel_item = "fresh_meat"
		m.city.shelf.refresh()
		await _frames(10)
		await _shot("m3_meat_card")
		m.city.shelf.close()
		m.city.quick_use()
		print("CITY WALK: ate, food now %.0f, meat left %s" % [me.state.food, mc.d.stash])
		get_tree().quit(0)
		return
	if Platform.user_args.has("--gear"):
		await _gear_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--living"):
		await _living_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--goods-only"):
		await _goods_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--life-only"):
		m.touch.visible = true
		var lc := Profile.career()
		lc.d.stash = {"water_ration": 2, "oxygen_canister": 1}
		if Platform.user_args.has("--deep"):
			await _pose(me, o + Vector3(-33, 0.05, -33), PI * 0.75, -0.1)
			await _shot("l2_hab_inside")
			await _pose(me, o + Vector3(0, 0.05, 100), 0.0, 0.12)
			await _shot("l3_dome_outside")
			await _pose(me, WorldLayout.lift_bottom() + Vector3(1, 0, -2), 0.0, -0.08)
			await _shot("l7_deep_furrow")
			while not (m.server.bot_nav != null and m.server.bot_nav.ready_for_queries):
				await _frames(5)
			await _pose(me, WorldLayout.algae_spots()[0] + Vector3(0, 0.3, 1), PI, -0.05)
			m.input.press(PlayerCommand.Action.INTERACT)
			await _frames(30)
			m.server.world.damage_enabled = false
			await _frames(60)
			m.server.world.damage_enabled = false
			await _shot("l8_theft_guards")
			print("CITY WALK: theft raid_on=%s, algae=%s" % [m.city.raid_on(), Profile.career().d.stash.get("algae_culture", 0)])
			get_tree().quit(0)
			return
		# The dome over the city, its parks.
		await _pose(me, o + Vector3(14, 0.05, 24), PI * 0.75 + PI, -0.02)
		await _shot("l1_city_park")
		# Inside a habitat.
		await _pose(me, o + Vector3(-33, 0.05, -33), PI * 0.75, -0.1)
		await _shot("l2_hab_inside")
		# Inside a shop (walk-in, counter and shelves).
		await _pose(me, o + Vector3(-20, 0.25, -32.5), 0.0, -0.12)
		await _shot("l2b_shop_inside")
		# The city from outside its dome.
		await _pose(me, o + Vector3(0, 0.05, 100), 0.0, 0.12)
		await _shot("l3_dome_outside")
		# Dust Hollow: sealed workers, its one greenhouse.
		var h := WorldLayout.HOLLOW
		await _pose(me, WorldTerrain.at(h.x - 10, h.z + 14) + Vector3(0, 0.1, 0), PI * 0.5 + 0.6, -0.08)
		await _shot("l4_hollow_greenhouse")
		# The drill rig.
		await _pose(me, WorldLayout.rig_spot(0) + Vector3(-6, 0.3, 8), -0.64, 0.1)
		m.city._rig = 0  # a shift running: the auger turns, the dust flies
		await _frames(40)
		await _shot("l5_drill_rig")
		m.city._rig = -1
		# The lift and Deep Furrow below.
		await _pose(me, WorldLayout.lift_top() + Vector3(0, 0.3, 9), 0.0, 0.0)
		await _shot("l6_lift_house")
		await _pose(me, WorldLayout.lift_bottom() + Vector3(1, 0, -2), 0.0, -0.08)
		await _shot("l7_deep_furrow")
		# Lifting cultures: the guards come down.
		while not (m.server.bot_nav != null and m.server.bot_nav.ready_for_queries):
			await _frames(5)
		await _pose(me, WorldLayout.algae_spots()[0] + Vector3(0, 0.3, 1), PI, -0.05)
		m.input.press(PlayerCommand.Action.INTERACT)
		await _frames(30)
		m.server.world.damage_enabled = false
		await _frames(60)
		m.server.world.damage_enabled = false
		await _shot("l8_theft_guards")
		# A dust storm, the moons.
		await _pose(me, WorldTerrain.at(-140, 60) + Vector3(0, 0.1, 0), PI * 0.5 + 0.9, 0.35)
		await _shot("l9_moons")
		var w: DustStorms = m.get_tree().root.find_child("Weather", true, false)
		w.tick_offset = int((Survival.STORM_FIRST + 50.0) * Sim.TICK_RATE) - m.server.world.tick
		await _frames(30)
		await _pose(me, WorldTerrain.at(-140, 60) + Vector3(0, 0.1, 0), PI * 0.5 + 1.4, -0.02)
		await _shot("l10_dust_storm")
		get_tree().quit(0)
		return
	if Platform.user_args.has("--raid-only"):
		var rc := Profile.career()
		rc.d.hollow.owner = "player"
		rc.d.hollow.raid_due = true
		rc.d.trust = {"foreman": Career.FRIEND, "armourer": Career.FRIEND}
		m.touch.visible = true
		await _pose(me, WorldTerrain.at(WorldLayout.HOLLOW.x - 30, WorldLayout.HOLLOW.z + 30) + Vector3(0, 0.3, 0), -PI * 0.25, -0.05)
		await _shot("x0_raid_due")
		while not (m.server.bot_nav != null and m.server.bot_nav.ready_for_queries):
			await _frames(5)
		await _pose(me, WorldTerrain.at(WorldLayout.HOLLOW.x + 6, WorldLayout.HOLLOW.z - 10) + Vector3(0, 0.3, 0), -PI * 0.5 - 0.3, -0.05)
		m.server.world.damage_enabled = false  # posed camera: nobody dies in the shots
		await _frames(5)
		m.server.world.damage_enabled = false
		await _shot("x1_raid_start")
		await _frames(120)
		m.server.world.damage_enabled = false
		await _shot("x2_raid_fight")
		get_tree().quit(0)
		return
	if Platform.user_args.has("--talk-only"):
		m.touch.visible = true
		var c := Profile.career()
		c.d.wallet = 1400
		c.d.trust = {"trader": 22, "foreman": 44}
		# Walk up to Mbeki at the exchange: the prompt, then the talk.
		var trader: Vector3 = CityLayout.terminals()[1][1]
		await _pose(me, trader + Vector3(2.6, 0.05, 1.2), PI * 0.5 + 0.4, -0.15)
		await _shot("t1_prompt_trader")
		m.input.press(PlayerCommand.Action.INTERACT)
		await _frames(30)
		await _shot("t2_talk_trader")
		m.city.talk.visible = false
		m.city._close_talk()
		c.buy_supplies(4)
		# Out at Dust Hollow with four crates: the foreman.
		var f := WorldLayout.foreman_spot()
		await _pose(me, f + Vector3(0.5, 0.1, 2.6), 0.2, -0.12)
		m.input.press(PlayerCommand.Action.INTERACT)
		await _frames(30)
		await _shot("t3_talk_foreman")
		c.deliver_supplies()
		c.talk("foreman")
		m.city.talk.refresh()
		await _frames(10)
		await _shot("t4_foreman_ready_to_claim")
		c.claim_hollow()
		m.city.talk.refresh()
		await _frames(10)
		await _shot("t5_hollow_claimed")
		m.city.talk.visible = false
		m.city._close_talk()
		await _pose(me, WorldTerrain.at(WorldLayout.HOLLOW.x - 40, WorldLayout.HOLLOW.z + 40) + Vector3(0, 0.1, 0), -PI * 0.25, -0.02)
		await _frames(20)
		await _shot("t6_hollow_yours")
		get_tree().quit(0)
		return
	if Platform.user_args.has("--merc-only"):
		# Close on the mercenary: from the front, and from behind.
		await _pose(me, o + Vector3(0, 0.05, 20), PI, -0.05)
		m.view.camera.fov = 40.0
		await _shot("m1_merc_front")
		await _pose(me, o + Vector3(0, 0.05, 20), 0.0, -0.1)
		await _shot("m2_merc_back")
		get_tree().quit(0)
		return
	if Platform.user_args.has("--rover-only"):
		await _pose(me, o + Vector3(4.5, 0.05, 49.5), PI * 0.5 + 2.4, -0.15)
		await _shot("r1_rover_parked")
		m.input.press(PlayerCommand.Action.INTERACT)
		await _frames(10)
		print("CITY WALK: driving = %s" % (me.state.vehicle >= 0))
		m.input.look_yaw = PI
		m.input.touch_move = Vector2(0, 1)
		await _frames(150)
		await _shot("r2_driving")
		print("CITY WALK: speed %.1f m/s at %s" % [me.state.vehicle_speed, me.state.position])
		get_tree().quit(0)
		return
	await _pose(me, o + Vector3(-15, 0.05, 6), PI * 0.5 + 0.3, -0.1)
	await _shot("c3_market_row")
	# The rover at the gate: walk up, get in, drive out into the valley.
	await _pose(me, o + Vector3(4.5, 0.05, 49.5), PI * 0.5 + 2.4, -0.15)
	await _shot("r1_rover_parked")
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(10)
	print("CITY WALK: driving = %s" % (me.state.vehicle >= 0))
	m.input.look_yaw = PI
	m.input.touch_move = Vector2(0, 1)
	await _frames(150)
	await _shot("r2_driving")
	m.input.touch_move = Vector2.ZERO
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(20)
	# Out through the gate: the valley below the plateau.
	await _pose(me, o + Vector3(0, 0.05, 52), PI + 0.5, -0.12)
	await _shot("w1_valley_from_gate")
	var hollow := WorldTerrain.at(WorldLayout.HOLLOW.x - 40, WorldLayout.HOLLOW.z + 40)
	await _pose(me, hollow + Vector3(0, 0.1, 0), -PI * 0.25, -0.1)
	await _shot("w2_dust_hollow")
	var rim := WorldTerrain.at(200, 112)
	await _pose(me, rim + Vector3(0, 0.1, 0), PI + 1.0, -0.2)
	await _shot("w3_canyon_dig")
	var wreck := WorldTerrain.at(-100, -80)
	await _pose(me, wreck + Vector3(0, 0.1, 0), 0.75, -0.05)
	await _shot("w4_wreck")
	var crater := WorldTerrain.at(150, -175)
	await _pose(me, crater + Vector3(0, 0.1, 0), 0.0, -0.15)
	await _shot("w5_crater")
	# Overview from high above the valley.
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 520, 260)
	cam.look_at(Vector3(0, 0, -20))
	cam.fov = 60.0
	cam.far = 2000.0
	cam.current = true
	m.hud.visible = false
	await _frames(20)
	await _shot("w0_overview")
	cam.current = false
	m.hud.visible = true
	await _pose(me, o + Vector3(3, 0.05, -18), 0.2, -0.1)
	m.city.open_terminal("contracts")
	await _frames(20)
	await _shot("c6_terminal_open")
	print("CITY WALK: saved to %s" % ProjectSettings.globalize_path(out_dir))
	get_tree().quit(0)


## Shelves: a gun dealer's counter, your pack, the Concern convoy's hold,
## a pack on the ground.
func _goods_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.wallet = 940
	c.d.stash = {"burst_rifle": 1, "flux_smg": 1, "frag_grenade": 3, "oxygen_canister": 2, "water_ration": 3, "rare_ore": 2, "helium3": 1, "scrap": 4,
			"refined_ingot": 1, "fresh_food": 2, "red_dust": 2, "algae_culture": 1}
	var shops := WorldLayout.shops()
	var arms: Array = shops[1]
	await _pose(me, (arms[1] as Vector3) + Vector3(0, 0.05, 0), float(arms[3]) - PI, -0.12)
	await _shot("g1_arms_counter")
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(20)
	m.city.shelf._sel_side = 1
	m.city.shelf._sel_item = "scatter_gun"
	m.city.shelf.refresh()
	await _frames(10)
	await _shot("g2_arms_shelf")
	m.city.shelf.close()
	m.city.open_pack()
	m.city.shelf._sel_side = 0
	m.city.shelf._sel_item = "burst_rifle"
	m.city.shelf.refresh()
	await _frames(10)
	await _shot("g3_pack")
	m.city.shelf.close()
	var convoy: SimVehicle = null
	for v: SimVehicle in m.server.world.vehicles:
		if v.owner < 0:
			convoy = v
	var hatch := convoy.position - Vector3(-sin(convoy.yaw), 0.0, -cos(convoy.yaw)) * (VehicleSim.HOLD_BACK + 0.3)
	await _pose(me, hatch, convoy.yaw, -0.2)
	await _shot("g4_convoy_hatch")
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(20)
	m.server.world.damage_enabled = false
	await _shot("g5_convoy_hold")
	m.city.shelf.close()
	var o := CityLayout.ORIGIN + Vector3(6, 0.05, 20)
	m.server.world.drops.append({"id": 99, "position": o + Vector3(1.0, 0, -1.4), "name": "Concern·Mirek",
			"items": {"supply_crate": 1, "cred_chip": 3, "flux_smg": 1, "oxygen_canister": 1},
			"until": m.server.world.tick + 6000})
	await _pose(me, o, 0.0, -0.3)
	await _shot("g6_pack_on_ground")
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(20)
	await _shot("g7_search_pack")
	m.city.shelf.close()
	# A hold-up: one of the convoy's escort, badly hurt, in your sights.
	if m.city._guards != null and not m.city._guards.raiders.is_empty():
		var gid: int = m.city._guards.raiders[0]
		var g: SimPlayer = m.server.world.players.get(gid)
		if g == null or not is_instance_valid(g):
			return
		var spot := o + Vector3(-8, 0, 6)
		await _pose(me, spot, 0.0, -0.05)
		m.server.world.teleport(g, spot + Vector3(0, 0, -3))
		g.state.health = 20.0
		g.state.shield = 0.0
		await _frames(2)
		print("CITY WALK: hold-up offered: %s" % m.city._near)
		await _shot("g8_holdup_prompt")
		m.input.press(PlayerCommand.Action.INTERACT)
		await _frames(20)
		print("CITY WALK: guard gone: %s, shelf open: %s, title %s" % [not m.server.world.players.has(gid),
				m.city.shelf.visible, m.city.shelf.title])
		await _shot("g9_holdup_pack")
	# Your own rover's hold: load the ore.
	m.city.shelf.close()
	var mine: SimVehicle = m.server.world.vehicles[0]
	var back := mine.position - Vector3(-sin(mine.yaw), 0.0, -cos(mine.yaw)) * (VehicleSim.HOLD_BACK + 0.3)
	await _pose(me, back, mine.yaw, -0.2)
	print("CITY WALK: at own hold: %s" % m.city._near)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(20)
	m.city.shelf._sel_side = 0
	m.city.shelf._sel_item = "rare_ore"
	m.city.shelf.refresh()
	print("CITY WALK: loaded: %s, hold %s" % [c.load_rover("rare_ore", 2), c.d.rover_cargo])
	m.city.shelf.refresh()
	await _frames(5)
	await _shot("g10_own_hold")


## Frame costs in the city plaza and at the Hollow (script and physics are
## real here; render times aren't: no GPU in this machine).
func _perf_probe(me: SimPlayer) -> void:
	if Platform.user_args.has("--phone-lod"):
		get_viewport().mesh_lod_threshold = 4.0  # project.godot's .mobile override
	for place: Array in [["plaza", CityLayout.ORIGIN + Vector3(0, 0.05, 10), 0.0],
			["hollow", WorldTerrain.at(WorldLayout.HOLLOW.x, WorldLayout.HOLLOW.z + 10) + Vector3(0, 0.1, 0), 0.0]]:
		await _pose(me, place[1], place[2], -0.05)
		Diagnostics.section_report()
		var proc := 0.0
		var phys := 0.0
		var draws := 0.0
		var prims := 0.0
		var n := 300
		for i in n:
			await get_tree().process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		print("PERF %s: process %.2f ms, physics %.2f ms, draw calls %d, primitives %dk, nodes %d" % [place[0],
				proc / n, phys / n, int(draws / n), int(prims / n / 1000.0), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		print("PERF %s sections: %s" % [place[0], Diagnostics.section_report()])
		# The heaviest meshes on screen.
		var tally := {}
		for mi: MeshInstance3D in get_tree().root.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree() or mi.mesh == null:
				continue
			var tris := 0
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var key := str(mi.mesh.resource_path.get_file()) if not mi.mesh.resource_path.is_empty() else str(mi.name)
			var parent := mi.get_parent()
			key += " @" + (str(parent.get_class()) if parent != null else "") + ":" + str(parent.name if parent != null else "")
			if mi.visibility_range_end > 0.0:
				key += " (lod %.0f-%.0f)" % [mi.visibility_range_begin, mi.visibility_range_end]
			var row: Array = tally.get(key, [0, 0])
			tally[key] = [row[0] + 1, row[1] + tris]
		var keys := tally.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return tally[a][1] > tally[b][1])
		for k: String in keys.slice(0, 14):
			print("PERF mesh %dk tris x%d  %s" % [tally[k][1] / 1000, tally[k][0], k])


## Driving controls, then a chase: the Marshals called, closing in, firing.
func _police_run(me: SimPlayer) -> void:
	var mine: SimVehicle = m.server.world.vehicles[0]
	var side := mine.position + Vector3(cos(mine.yaw), 0, -sin(mine.yaw)) * 2.0
	await _pose(me, side, mine.yaw, -0.1)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(30)
	print("CITY WALK: driving %s, touch driving %s" % [me.state.vehicle >= 0, m.touch.driving])
	await _shot("p1_driving")
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(30)
	var spot := WorldTerrain.at(-120.0, 10.0) + Vector3(0, 0.1, 0)
	await _pose(me, spot, 0.0, -0.05)
	m.city.crime("convoy")
	m.city.crime("holdup")
	for i in 40:
		await _frames(15)
		if m.city._police != null and m.city._police.raiders_left() >= 3:
			break
	print("CITY WALK: wanted %d, officers %d" % [m.city.wanted.stars, m.city._police.raiders_left() if m.city._police != null else -1])
	me.state.health = 100000.0  # posed: let them shoot without ending it
	var t0 := me.state.health
	for i in 40:
		await _frames(15)
		if me.state.health < t0 - 1.0:
			break
	print("CITY WALK: shot at: %s" % (me.state.health < t0))
	await _shot("p2_marshals")
	for id: int in m.city._police.raiders:
		var p: SimPlayer = m.server.world.players.get(id)
		if p != null and p.state.alive:
			await _pose(me, p.state.position + Vector3(0, 0, 6), 0.0, -0.05)
			break
	await _frames(20)
	await _shot("p3_marshal_close")


## The valley's people up close: women and men, helmets outside, suits.
func _people_run(me: SimPlayer) -> void:
	var o := CityLayout.ORIGIN
	await _pose(me, o + Vector3(-6, 0.05, 14), PI * 0.15, -0.08)
	await _shot("h1_plaza_people")
	var chem: Array = WorldLayout.people_spots()[0]
	await _pose(me, (chem[1] as Vector3) + Vector3(3.5, 0.05, 1.5), PI * 0.5 - 0.3, -0.1)
	await _shot("h2_dr_okafor")
	var store: Array = WorldLayout.shops()[2]
	await _pose(me, (store[1] as Vector3) + Vector3(-2.6, 0.05, 1.6), float(store[3]) - PI - 0.55, -0.12)
	await _shot("h3_shopkeeper_ama")
	var fm := WorldLayout.foreman_spot()
	await _pose(me, fm + Vector3(1.5, 0.1, -4.5), PI + 0.3, -0.08)
	await _shot("h4_foreman_adaeze")
	var h := WorldLayout.HOLLOW
	await _pose(me, WorldTerrain.at(h.x - 26, h.z - 16) + Vector3(0, 0.1, 0), 0.5, -0.1)
	await _shot("h6_hollow_hab_no_air")
	await _pose(me, WorldLayout.farm_origin() + Vector3(1.5, 0.05, -10), PI * 0.5 + 0.2, -0.08)
	await _shot("h5_farm")


## Residences: your hab's locker, then a neighbour's lock worked open.
func _homes_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.stash = {"refined_ingot": 2, "water_ration": 3, "scrap": 2, "burst_rifle": 1}
	c.d.home.locker = {"helium3": 2, "cred_chip": 6, "oxygen_canister": 3}
	var homes := WorldLayout.residences()
	var mine: Vector3 = homes[0][1]
	var hab := CityLayout.ORIGIN + Vector3(-36, 0, -36)
	var to := (mine - hab).normalized()
	await _pose(me, mine - to * 2.0 + Vector3(0, 0.05, 0), atan2(-to.x, -to.z), -0.15)
	await _shot("r1_your_hab")
	print("CITY WALK: at home: %s" % m.city._near)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(20)
	m.city.shelf._sel_side = 0
	m.city.shelf._sel_item = "refined_ingot"
	m.city.shelf.refresh()
	await _frames(5)
	await _shot("r2_locker")
	m.city.shelf.close()
	var other: Vector3 = homes[1][1]
	var hab2 := CityLayout.ORIGIN + Vector3(-38, 0, 32)
	var to2 := (other - hab2).normalized()
	await _pose(me, other - to2 * 1.2 + Vector3(0, 0.05, 0), atan2(-to2.x, -to2.z), -0.15)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(90)
	await _shot("r3_breaking_in")
	await _frames(240)
	print("CITY WALK: break-in shelf %s, wanted %d" % [m.city.shelf.visible, m.city.wanted.stars])
	await _shot("r4_neighbours_locker")


## The garage (respray with stars on, chop a public rover), the fuel and
## condition gauges, binoculars and a scan.
func _garage_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.wallet = 1200
	c.d.stash["binoculars"] = 1
	c.d.stash["scanner"] = 1
	var world: SimWorld = m.server.world
	var mine: SimVehicle = world.vehicles[0]
	await _pose(me, mine.position + Vector3(cos(mine.yaw), 0, -sin(mine.yaw)) * 2.0, mine.yaw, -0.1)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(20)
	mine.fuel = 34.0
	mine.condition = 58.0
	await _shot("j1_gauges")
	m.city.crime("convoy")
	var bay := WorldLayout.garage_spot() + Vector3(0, 0.4, 0)
	world.teleport(me, bay)
	me.state.vehicle_speed = 0.0
	for id: int in world.players:
		if world.players[id].display_name.begins_with("Marshal·"):
			world.teleport(world.players[id], bay + Vector3(300, 0, 300))  # nobody watching
	await _frames(40)
	for id: int in world.players:
		if world.players[id].display_name.begins_with("Marshal·"):
			world.teleport(world.players[id], bay + Vector3(300, 0, 300))
	await _frames(3)
	print("CITY WALK: garage open %s, stars %d, seen %s" % [m.city.garage.visible, m.city.wanted.stars, m.city._police_seen])
	await _shot("j2_garage")
	m.city._garage_act("respray")
	m.city._garage_act("fuel")
	m.city._garage_act("repair")
	await _frames(5)
	print("CITY WALK: after: stars %d, fuel %.0f, condition %.0f, wallet %d" % [m.city.wanted.stars, mine.fuel, mine.condition, c.d.wallet])
	await _shot("j3_garage_done")
	m.city.garage.visible = false
	m.city._close_talk()
	m.input.press(PlayerCommand.Action.INTERACT)  # out of my rover
	await _frames(20)
	var other: SimVehicle = world.vehicles[1]
	await _pose(me, other.position + Vector3(cos(other.yaw), 0, -sin(other.yaw)) * 2.0, other.yaw, -0.1)
	print("CITY WALK: by the other rover: near %s, vehicle %d" % [m.city._near, me.state.vehicle])
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(20)
	print("CITY WALK: boarded %d" % me.state.vehicle)
	world.teleport(me, bay)
	me.state.vehicle_speed = 0.0
	await _frames(40)
	var before := int(c.d.wallet)
	m.city._garage_act("chop")
	await _frames(10)
	print("CITY WALK: chopped: +%d, driving %s, rover back at %s" % [int(c.d.wallet) - before, me.state.vehicle >= 0, other.position])
	await _pose(me, WorldTerrain.at(-140.0, 40.0) + Vector3(0, 0.1, 0), PI * 0.5 + 0.6, 0.0)
	m.city.scan()
	await _frames(10)
	await _shot("j4_scan")
	m.city.toggle_binoculars()
	await _frames(30)
	await _shot("j5_binoculars")


## The living valley: the plaza by day (minimap, clock), roads and traffic,
## the new rides, Kasei Motors, the Red Lantern of an evening, a shop shut
## at night, the Hollow on its footings.
func _gear_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.stash = {"torch": 1, "jetpack": 1}
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	var now_h := GameClock.hour(Time.get_unix_time_from_system())
	var off := fposmod(22.0 - now_h, 24.0)
	CityNpcs.hour_offset = off
	weather.hour_offset = off
	await _frames(70)
	var o := CityLayout.ORIGIN
	await _pose(me, o + Vector3(0, 0.05, 6), 0.0, -0.12)
	m.city.toggle_torch()
	await _frames(20)
	await _shot("g1_torch_night")
	CityNpcs.hour_offset = fposmod(11.0 - now_h, 24.0)
	weather.hour_offset = CityNpcs.hour_offset
	m.city.toggle_torch()
	await _frames(40)
	# Jetpack: jump and hold.
	m.input.touch_held = PlayerCommand.Held.JUMP
	m.input.press(PlayerCommand.Action.JUMP)
	var ground_y := me.state.position.y
	var top := ground_y
	for i in 8:
		await _frames(5)
		top = maxf(top, me.state.position.y)
		if i == 3:
			await _shot("g2_jetpack")
	print("CITY WALK: jetpack climbed %.1f m, fuel %.0f" % [top - ground_y, me.state.jet_fuel])
	m.input.touch_held = 0
	await _frames(120)
	# Gun drawn at people: they freeze; a shot sends them running.
	m.city.toggle_drawn()
	await _frames(30)
	var near: Array = []
	for v: Array in m.city._people._walkers:
		if near.is_empty() or (v[1] as PlayerSimState).position.distance_to(me.state.position) < (near[1] as PlayerSimState).position.distance_to(me.state.position):
			near = v
	if not near.is_empty():
		var at: Vector3 = (near[1] as PlayerSimState).position
		var to := at - me.state.position
		await _pose(me, at - Vector3(to.x, 0, to.z).normalized() * 6.0 + Vector3(0, 0.05, 0), atan2(-to.x, -to.z), -0.05)
	await _frames(12)
	print("CITY WALK: moods ", m.city._people._mood.values().map(func(d: Dictionary) -> String: return d.mode))
	await _shot("g3_drawn_people")
	m.city.on_event({"type": "fire", "shooter": me.net_id, "origin": me.state.position, "weapon": &"pistol"})
	await _frames(40)
	print("CITY WALK: after a shot, police %s" % (m.city._police != null))
	await _shot("g4_shot_panic")
	await _frames(240)
	await _shot("g5_marshals")


func _living_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.wallet = 4000
	c.d.stash = {"vat_meat": 2, "water_ration": 2}
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	var now_h := GameClock.hour(Time.get_unix_time_from_system())
	var to_hour := func(h: float) -> void:
		var off := fposmod(h - now_h, 24.0)
		CityNpcs.hour_offset = off
		weather.hour_offset = off
	to_hour.call(11.0)
	await _frames(70)
	var o := CityLayout.ORIGIN
	await _pose(me, o + Vector3(0, 0.05, 6), 0.0, -0.05)
	await _shot("v1_plaza_day")
	var world: SimWorld = m.server.world
	world.vehicles[1].model = 1
	world.vehicles[2].model = 2
	var g: SimVehicle = world.vehicles[0]
	await _pose(me, g.position + Vector3(-5.5, 0.05, -3.0), -PI * 0.25 - 0.3, -0.12)
	await _shot("v2_new_rides")
	await _pose(me, WorldTerrain.at(-140.0, 84.0) + Vector3(0, 0.1, 0), -PI * 0.5 - 0.35, -0.04)
	await _frames(60)
	await _shot("v3_road_traffic")
	await _pose(me, WorldLayout.factory_at(Vector3(-8, 0.1, 18)), PI + 0.35, -0.02)
	await _frames(40)
	await _shot("v4_factory")
	await _pose(me, WorldLayout.showroom_spot() + Vector3(0, 0.1, 0), PI, -0.1)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(20)
	await _shot("v5_showroom")
	m.city.garage.visible = false
	m.city._close_talk()
	to_hour.call(20.5)
	await _frames(70)
	var bar: Array = WorldLayout.shops()[5]
	await _pose(me, (bar[1] as Vector3) + Vector3(0, 0.05, 0) + Basis(Vector3.UP, float(bar[3]) - PI) * Vector3(1.5, 0, 2.5),
			float(bar[3]) - PI + 0.3, -0.1)
	await _frames(20)
	await _shot("v6_bar_evening")
	to_hour.call(2.0)
	await _frames(70)
	var store: Array = WorldLayout.shops()[2]
	await _pose(me, (store[1] as Vector3) + Vector3(0, 0.05, 0), float(store[3]) - PI, -0.1)
	await _shot("v7_shop_closed_night")
	to_hour.call(9.0)
	await _frames(40)
	var h := WorldLayout.HOLLOW
	await _pose(me, WorldTerrain.at(h.x - 2, h.z + 14) + Vector3(0, 0.1, 0), PI * 0.5 + 0.8, -0.08)
	await _shot("v8_hollow")


func _pose(me: SimPlayer, at: Vector3, yaw: float, pitch: float) -> void:
	m.server.world.teleport(me, at)
	me.state.yaw = yaw
	m.input.look_yaw = yaw
	m.input.look_pitch = pitch
	await _frames(60)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("CITY WALK: %s" % name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A run at the Rustwood Dig in the canyon: arrival at the pad (rover
## waiting), down the canyon, the relic vault, an extraction pad.
func _dig_run(me: SimPlayer) -> void:
	while m.server.phase != MatchPhase.PLAYING:
		await _frames(10)
	await _frames(30)
	m.server.world.damage_enabled = false  # posed camera: keep the bots off it
	m.hunt_hud.touch = true
	print("CITY WALK: run started, player at %s" % me.state.position)
	await _shot("d1_arrival_pad")
	var pad := WorldLayout.dig_pad()
	await _pose(me, pad + Vector3(-8, 0.3, 0), PI * 0.5 + 0.35, -0.12)
	await _shot("d2_rover_at_pad")
	await _pose(me, WorldLayout.canyon(270.0) + Vector3(0, 0.3, 0), -PI * 0.5 + 0.15, -0.05)
	await _shot("d3_canyon_to_vault")
	await _pose(me, WorldLayout.canyon(288.0) + Vector3(0, 0.3, 2), -PI * 0.5, -0.15)
	await _shot("d4_vault")
	await _pose(me, WorldTerrain.at(200.0, 135.0) + Vector3(0, 0.3, 0), 0.0, -0.15)
	await _shot("d5_rim_extraction")
	get_tree().quit(0)
