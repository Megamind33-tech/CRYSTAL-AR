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
	if Platform.user_args.has("--squad"):  # deploy with a full squad (HuntSquad)
		Profile.career().d.team = ["gunner", "medic", "engineer"]
		Profile.career().d.wallet = 1000
	if dig:  # Adaeze, a friend, comes along
		Profile.career().d.trust = {"foreman": Career.FRIEND}
		Profile.career().d.companion = "foreman"
		Profile.career().d.oxygen = 46.0
		Profile.career().d.stash = {"oxygen_canister": 1}
	if Platform.user_args.has("--people"):
		Profile.career().d["body"] = "female"  # play as a woman
	if Platform.user_args.has("--budget") or Platform.user_args.has("--block") or Platform.user_args.has("--head") or Platform.user_args.has("--walkin") or Platform.user_args.has("--frisk") \
			or Platform.user_args.has("--districts") or Platform.user_args.has("--feet") or Platform.user_args.has("--gait-strip"):
		Profile.career().choose_nation(0)
		Profile.career().choose_path("freelance")  # no path pick over the shots
	if Platform.user_args.has("--phase1") and dig:
		Profile.career().choose_nation(0)  # a recruit of the Aurora Compact, on the first run
	MatchConfig.pending = MatchConfig.for_place(GameMode.HUNT if dig else GameMode.CITY, "You")
	m = MATCH.instantiate()
	add_child(m)
	await _frames(200)
	m.touch.visible = true
	m.hud._touch = true
	var me: SimPlayer = m.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	print("CITY WALK: player at %s, phase %s" % [me.state.position, m.server.phase])
	_set_weather(Platform.user_args.has("--day"), Platform.user_args.has("--squall"))
	if Platform.user_args.has("--floor-probe") or Platform.user_args.has("--feet"):
		await _floor_probe(me, Platform.user_args.has("--feet"))
		get_tree().quit(0)
		return
	if Platform.user_args.has("--gait-strip"):
		await _gait_strip(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--ground-probe"):
		await _ground_probe(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--frisk"):
		await _frisk_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--walkin"):
		await _walkin_test(me)
		return
	if Platform.user_args.has("--head"):
		await _pose(me, CityLayout.ORIGIN + Vector3(0, 0.05, 10), 0.0, -0.05)
		m.view.third_person = true
		await _shot("h0_ahead")
		for turn: float in [0.9, -0.9]:
			m.input.look_yaw = turn
			await _frames(25)
			await _shot("h_turn_%s" % ("left" if turn > 0 else "right"))
		get_tree().quit(0)
		return
	if Platform.user_args.has("--block"):
		await _block_tour(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--phase1"):
		await _phase1_run(me, dig)
		get_tree().quit(0)
		return
	if dig:
		await _dig_run(me)
		return
	var o := CityLayout.ORIGIN
	await _pose(me, o + Vector3(0, 0.05, 30), 0.0, -0.05)
	await _shot("c1_arrival")
	if Platform.user_args.has("--budget"):
		await _budget_probe(me)
		get_tree().quit(0)
		return
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
	if Platform.user_args.has("--roads"):
		var wx: DustStorms = m.get_tree().root.find_child("Weather", true, false)
		CityNpcs.hour_offset = fposmod(11.0 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
		wx.hour_offset = CityNpcs.hour_offset
		m.city.events._next = 1.0e9
		# Low by the road's edge, looking along it and up at it from the dip.
		for spot: Array in [[Vector2(-300, 140), Vector2(-420, 190), 0.0, "rd1"], [Vector2(-100, 300), Vector2(150, 385), -0.05, "rd2"],
				[Vector2(20, -30), Vector2(60, -60), 0.1, "rd3"]]:
			var a2: Vector2 = spot[0]
			var b2: Vector2 = spot[1]
			var mid := a2.lerp(b2, 0.3)
			var side := (b2 - a2).normalized().orthogonal() * 7.0
			var at := WorldTerrain.at(mid.x + side.x, mid.y + side.y)
			var d := b2 - (mid + side)
			await _pose(me, at + Vector3(0, 0.1, 0), atan2(-d.x, -d.y), spot[2])
			await _shot(spot[3])
		get_tree().quit(0)
		return
	if Platform.user_args.has("--style"):
		await _style_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--social"):
		await _social_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--heist"):
		await _heist_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--events"):
		await _events_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--trade"):
		await _trade_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--bounty"):
		await _bounty_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--estates"):
		await _estates_run(me)
		get_tree().quit(0)
		return
	if Platform.user_args.has("--districts"):
		await _districts_run(me)
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
		var wx: DustStorms = m.get_tree().root.find_child("Weather", true, false)
		CityNpcs.hour_offset = fposmod(12.0 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
		wx.hour_offset = CityNpcs.hour_offset
		await _pose(me, o + Vector3(4.5, 0.05, 49.5), PI * 0.5 + 2.4, -0.15)
		await _shot("r1_rover_parked")
		m.input.press(PlayerCommand.Action.INTERACT)
		await _frames(10)
		print("CITY WALK: driving = %s" % (me.state.vehicle >= 0))
		m.input.look_yaw = PI
		m.input.touch_move = Vector2(0, 1)
		await _frames(45)
		await _shot("r2_driving")
		print("CITY WALK: speed %.1f m/s at %s" % [me.state.vehicle_speed, me.state.position])
		# Off the road onto the dust, a long turn: tracks behind, the front wheels steered.
		m.input.touch_move = Vector2(0.8, 0.6)
		await _frames(40)
		await _shot("r3_turning_tracks")
		m.input.touch_move = Vector2(0, -0.3)
		await _frames(30)
		print("CITY WALK: tyre marks %d" % (m.get_children().filter(func(c: Node) -> bool: return c is RoverVisuals)[0] as RoverVisuals)._mark_i)
		await _shot("r4_tracks_behind")
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
	var wreck := WorldTerrain.at(WorldLayout.WRECK.x + 30, WorldLayout.WRECK.y + 40)
	await _pose(me, wreck + Vector3(0, 0.1, 0), 0.65, -0.05)
	await _shot("w4_wreck")
	var crater := WorldTerrain.at(150, -175)
	await _pose(me, crater + Vector3(0, 0.1, 0), 0.0, -0.15)
	await _shot("w5_crater")
	# Overview from high above the valley.
	for c: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
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
			["hollow", WorldTerrain.at(WorldLayout.HOLLOW.x, WorldLayout.HOLLOW.z + 10) + Vector3(0, 0.1, 0), 0.0],
			["helios", WorldTerrain.at(WorldLayout.HELIOS.x + 5, WorldLayout.HELIOS.y + 78) + Vector3(0, 0.1, 0), 0.0],
			["galleria_in", WorldTerrain.at(WorldLayout.GALLERIA.x - 34, WorldLayout.GALLERIA.y) + Vector3(0, 0.1, 0), -PI * 0.5],
			["outlands", WorldTerrain.at(-300, 60) + Vector3(0, 0.1, 0), 1.0]]:
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
		print("PERF %s: process %.2f ms, physics %.2f ms, draw calls %d, primitives %dk, nodes %d, video %.1f MB (textures %.1f, buffers %.1f)" % [place[0],
				proc / n, phys / n, int(draws / n), int(prims / n / 1000.0), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])
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
		if world.players[id].display_name.begins_with(CityMode.POLICE):
			world.teleport(world.players[id], bay + Vector3(300, 0, 300))  # nobody watching
	await _frames(40)
	for id: int in world.players:
		if world.players[id].display_name.begins_with(CityMode.POLICE):
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
func _style_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.wallet = 9000
	m.city.events._next = 1.0e9
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	CityNpcs.hour_offset = fposmod(11.0 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
	weather.hour_offset = CityNpcs.hour_offset
	c.add_xp(Career.XP_PER_TIER * 6)
	var o := CityLayout.ORIGIN
	await _pose(me, o + Vector3(4.5, 0.05, 44.5), PI * 0.5 + 2.4, -0.15)
	m.city.style.open()
	await _frames(10)
	await _shot("y1_style")
	m.city.style.menu_act("page:shop")
	m.city.style.menu_act("buy:suit_crimson")
	m.city.style.menu_act("buy:paint_neon")
	m.city.style.menu_act("page:season")
	m.city.style.menu_act("claim:3")
	m.city.style.menu_act("page:wardrobe")
	m.city.style.menu_act("equip:flame_green")
	await _frames(5)
	await _shot("y2_wardrobe")
	m.city.garage.visible = false
	m.city._close_talk()
	await _frames(30)  # the new suit: the body's rebuilt
	m.city.style.menu_act("emote:emote_dance")
	m.city.garage.visible = false
	m.city._close_talk()
	await _frames(60)
	m.input.look_yaw = me.state.yaw + PI
	await _frames(30)
	print("CITY WALK: wearing %s, paint %s, flame %s" % [c.equipped("suit"), c.equipped("paint"), c.equipped("flame")])
	var pv: PlayerVisual = m._visuals.get(me.net_id)
	print("CITY WALK: rig %s emote '%s' state '%s'" % [pv.rig.get_class() if pv != null else "-", pv.rig.emote if pv != null else "",
			pv.rig.get("_state_name") if pv != null else ""])
	await _shot("y3_dance_paint")
	await _frames(25)
	await _shot("y4_dance_later")


func _social_run(me: SimPlayer) -> void:
	var c := Profile.career()
	m.city.events._next = 1.0e9
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	CityNpcs.hour_offset = fposmod(17.5 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
	weather.hour_offset = CityNpcs.hour_offset
	await _pose(me, WorldLayout.partner_first() + Vector3(0, 0, 2.2), 0.0, -0.05)
	await _frames(10)
	print("CITY WALK: by Rhea, near = %s" % m.city._near)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(10)
	await _shot("s1_meet_rhea")
	c.d.partner.invite_at = 0
	m.city.social._invite_t = 0.0
	await _frames(20)
	print("CITY WALK: invite %s" % c.d.partner.invite)
	var spot := WorldLayout.hangout_spot(str(c.d.partner.invite.place))
	await _pose(me, spot + Vector3(0, 0, 2.5), 0.0, -0.05)
	var t0 := Time.get_ticks_msec()
	while not (c.d.partner.invite as Dictionary).is_empty() and Time.get_ticks_msec() - t0 < 120000:
		await _frames(10)
	print("CITY WALK: bond %d" % c.bond())
	await _shot("s2_hangout")
	c.post("KaseiNews", "Bounty hunter brings in Vesna Kroll alive. The Marshals say thanks.", 88, int(Time.get_unix_time_from_system()), 12)
	m.city.social.open()
	await _frames(5)
	await m.city.social._snap()
	await _frames(10)
	print("CITY WALK: feed %d posts, fame %d" % [(c.d.feed as Array).size(), int(c.d.fame)])
	await _shot("s3_marsnet")


func _heist_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.wallet = 20000
	c.d.stash["scanner"] = 1
	c.d.stash["armour_plate"] = 2
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	CityNpcs.hour_offset = fposmod(11.0 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
	weather.hour_offset = CityNpcs.hour_offset
	await _pose(me, CityHeist.board_spot() + Vector3(0, 0.05, 1.5), 0.0, -0.05)
	m.city.events._next = 1.0e9  # no world events in the way of this look
	print("CITY WALK: at the heist board, near = %s" % m.city._near)
	m.city.heist.menu_act("plan:ring")
	# Codes at the panel.
	await _pose(me, WorldLayout.ring_panel() + Vector3(0, 0, 1.5), 0.0, -0.05)
	print("CITY WALK: at the panel, near = %s" % m.city._near)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(5)
	await _shot("h1_hacking")
	await _frames(400)
	m.city._scan_cool = 0.0
	m.city.scan()
	c.heist_prep("ride")
	print("CITY WALK: preps %s, ready %s" % [c.heist().preps, c.heist_ready()])
	m.city.heist.menu_act("approach:loud")
	print("CITY WALK: approach %s, stage %s" % [c.heist().approach, c.heist().stage])
	await _pose(me, WorldLayout.vault_door() + Vector3(0, 0, -1.0), PI, -0.05)
	print("CITY WALK: at the vault door, near = %s" % m.city._near)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(30)
	print("CITY WALK: inside, guards %d, alarm %s" % [m.city.heist.fighters().size(), m.city.heist.alarm])
	m.input.look_yaw = PI
	await _frames(20)
	await _shot("h2_vault")
	# The guards go down (this is a look at the flow), crack it, get out, get clear.
	for id: int in m.city.heist.fighters():
		var g: SimPlayer = m.server.world.players.get(id)
		if g != null:
			g.state.health = 0.0
			g.state.alive = false
	m.server.world.teleport(me, (WorldLayout.INTERIORS.office as Vector3) + Vector3(5.0, 0.1, 2.0))
	await _frames(3)
	print("CITY WALK: at the vault, near = %s" % m.city._near)
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(400)
	print("CITY WALK: bonds %d, stars %d" % [int(c.d.stash.get("ring_bonds", 0)), m.city.wanted.stars])
	m.city.estate.inside = []
	var wallet: int = c.d.wallet
	m.server.world.teleport(me, WorldTerrain.at(WorldLayout.HELIOS.x + 360, WorldLayout.HELIOS.y) + Vector3(0, 0.3, 0))
	await _frames(20)
	print("CITY WALK: clear, paid %d, heist %s" % [int(c.d.wallet) - wallet, c.heist()])
	await _shot("h3_getaway")


func _events_run(me: SimPlayer) -> void:
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	CityNpcs.hour_offset = fposmod(11.0 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
	weather.hour_offset = CityNpcs.hour_offset
	await _pose(me, WorldTerrain.at(-60, 120) + Vector3(0, 0.1, 0), 0.0, -0.05)
	var ev: CityEvents = m.city.events
	for k: String in ["pod", "meteor", "convoy"]:
		ev._end()
		ev._start(me, k)
		await _frames(5)
		await _shot("v_%s_announced" % k)
		var spot: Vector3 = ev.spots[0][0]
		var look := spot - Vector3(spot.x + 6.0, 0, spot.z + 6.0)
		await _pose(me, spot + Vector3(6.0, 0.1, 6.0), atan2(-look.x, -look.z), -0.1)
		print("CITY WALK: %s near = %s, fight %s" % [k, m.city._near, m.city.in_fight()])
		await _shot("v_%s_there" % k)
		if k == "convoy":
			for id: int in ev.guards.raiders:
				var g: SimPlayer = m.server.world.players.get(id)
				if g != null:
					g.state.alive = false
					g.state.health = 0.0
			await _frames(5)
		m.server.world.teleport(me, spot + Vector3(1.0, 0.1, 0))
		await _frames(3)
		var stash_before: int = Profile.career().d.stash.size()
		m.input.press(PlayerCommand.Action.INTERACT)
		await _frames(5)
		print("CITY WALK: %s taken: %s, stash kinds %d -> %d" % [k, ev.spots[0][1] if not ev.spots.is_empty() else true,
				stash_before, Profile.career().d.stash.size()])


func _trade_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.wallet = 5000
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	CityNpcs.hour_offset = fposmod(11.0 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
	weather.hour_offset = CityNpcs.hour_offset
	await _pose(me, WorldLayout.ledger_drop() + Vector3(0, 0, 1.5), 0.0, -0.05)
	print("CITY WALK: at Sable's drop, near = %s" % m.city._near)
	m.city.trade.menu_act("advance")
	c.trade().order_at = 0
	await _frames(150)
	print("CITY WALK: chain %d, orders %s" % [c.chain_step(), c.trade().orders])
	await _shot("t1_order")
	var o: Dictionary = c.trade().orders[0]
	var spot := WorldLayout.client_spot(o.client)
	await _pose(me, spot + Vector3(0, 0, 2.0), 0.0, -0.05)
	print("CITY WALK: at the meet, near = %s" % m.city._near)
	await _shot("t2_meet")
	var wallet: int = c.d.wallet
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(10)
	print("CITY WALK: delivered, +$%d" % (int(c.d.wallet) - wallet))
	# Learn the cuts, mix at home, the burner.
	c.trade().sold = Career.CHAIN_SELL
	c.chain_advance(0)
	c.receive("water_ice", 4)
	c.chain_advance(0)
	c.receive("red_dust", 6)
	c.receive("stim_cola", 3)
	await _pose(me, (WorldLayout.residences()[0][1] as Vector3) + Vector3(0, 0, 1.0), 0.0, -0.05)
	m.city.trade.open_burner()
	await _frames(10)
	await _shot("t3_burner")
	m.city.trade.menu_act("mix:dust_frost")
	m.city.trade.menu_act("mix:dust_spark")
	print("CITY WALK: mixed: frost %d, spark %d" % [int(c.d.stash.get("dust_frost", 0)), int(c.d.stash.get("dust_spark", 0))])
	m.city.garage.visible = false
	m.city._close_talk()
	# A Marshal on the beat.
	var marshal: Array = m.city._people.marshals[0]
	var mp := (marshal[1] as PlayerSimState).position
	m.server.world.teleport(me, mp + Vector3(2.0, 0.1, 0))
	await _frames(30)
	print("CITY WALK: by a Marshal, searching: %s" % (not m.city.trade._searcher.is_empty()))
	await _shot("t4_stopped")
	await _frames(240)
	print("CITY WALK: still carrying dust: %s" % c.carrying_dust())
	# The turf.
	c.trade().chain = 3
	var turf := WorldLayout.turf_spot()
	await _pose(me, turf + Vector3(30, 0.1, 0), PI * 0.5, 0.0)
	await _frames(30)
	print("CITY WALK: turf fight on: %s, fighters %d" % [m.city.trade.in_fight(), m.city.trade.fighters().size()])
	await _shot("t5_turf")


func _bounty_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.stash["scanner"] = 1
	c.d.stash["binoculars"] = 1
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	CityNpcs.hour_offset = fposmod(11.0 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
	weather.hour_offset = CityNpcs.hour_offset
	await _pose(me, WorldLayout.bounty_board() + Vector3(0, 0.05, 2.0), 0.0, -0.05)
	print("CITY WALK: at the board, near = %s" % m.city._near)
	m.city.bounty.menu_act("take:kroll")
	await _frames(30)
	print("CITY WALK: target %d, search r %.0f" % [m.city.bounty.target_id, m.city.bounty.circle_r])
	await _shot("b1_dossier")
	# Ask a passer-by.
	var w: Array = m.city._people._walkers[0]
	var wp: Vector3 = (w[1] as PlayerSimState).position
	await _pose(me, wp + Vector3(1.2, 0.05, 0), PI * 0.5, -0.05)
	wp = (w[1] as PlayerSimState).position
	m.server.world.teleport(me, wp + Vector3(1.2, 0.05, 0))
	await _frames(2)
	m.city.bounty.ask(me)
	await _frames(10)
	print("CITY WALK: asked, search r %.0f" % m.city.bounty.circle_r)
	await _shot("b2_asked")
	# Out to the hideout: scan, then spot them.
	var hide := WorldLayout.bounty_hideout("kroll")
	await _pose(me, WorldTerrain.at(hide.x + 90, hide.z + 40) + Vector3(0, 0.1, 0), 0.0, 0.0)
	m.city.scan()
	await _frames(10)
	print("CITY WALK: scanned, search r %.0f" % m.city.bounty.circle_r)
	await _shot("b3_search_area")
	var t: SimPlayer = m.server.world.players.get(m.city.bounty.target_id)
	var tp := t.state.position
	var to := (tp - me.state.position)
	await _pose(me, tp - Vector3(to.x, 0, to.z).normalized() * 14.0 + Vector3(0, 0.1, 0), atan2(-to.x, -to.z), 0.0)
	await _frames(20)
	print("CITY WALK: confirmed %s, hot %s" % [m.city.bounty.confirmed, m.city.bounty.hot])
	await _shot("b4_spotted")
	# Beaten: hold them up from close in.
	t.state.health = 10.0
	t.state.shield = 0.0
	tp = t.state.position
	to = (tp - me.state.position)
	m.server.world.teleport(me, tp - Vector3(to.x, 0, to.z).normalized() * 2.0 + Vector3(0, 0.1, 0))
	me.state.yaw = atan2(-to.x, -to.z)
	m.input.look_yaw = me.state.yaw
	t.state.health = 10.0
	await _frames(3)
	print("CITY WALK: near = %s" % m.city._near)
	var wallet: int = c.d.wallet
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(10)
	print("CITY WALK: paid %d, bounty now %s" % [int(c.d.wallet) - wallet, c.d.bounty])
	await _shot("b5_taken")


func _estates_run(me: SimPlayer) -> void:
	var c := Profile.career()
	c.d.wallet = 150000
	var now := int(Time.get_unix_time_from_system())
	c.buy_visa("helios", now)
	c.buy_visa("flight", now)
	c.d.stash["cutter"] = 1
	c.form_gang("Phobos Cartel")
	c.recruit()
	c.recruit()
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	CityNpcs.hour_offset = fposmod(11.0 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
	weather.hour_offset = CityNpcs.hour_offset
	# The crew walks with you through the plaza.
	var o := CityLayout.ORIGIN
	await _pose(me, o + Vector3(0, 0.05, 4), 0.0, -0.1)
	m.input.touch_move = Vector2(0, 1)
	await _frames(40)
	m.input.touch_move = Vector2.ZERO
	await _frames(20)
	m.input.look_yaw = PI
	await _frames(10)
	await _shot("e1_crew")
	# A Helios door: rent the penthouse, go in.
	var door: Array = WorldLayout.property_doors()[0]
	await _pose(me, door[1], 0.0, 0.0)
	await _frames(5)
	print("CITY WALK: at the door, near = %s" % m.city._near)
	m.city.estate.menu_act("rent:helios_spire", me)
	m.city.estate.menu_act("enter:helios_spire", me)
	await _frames(40)
	m.input.look_yaw = PI
	m.input.look_pitch = 0.05
	await _frames(30)
	print("CITY WALK: inside %s, room %d, yours %s" % [m.city.estate.inside, m.city.room, c.has_property("helios_spire", now)])
	await _shot("e2_apartment")
	m.input.look_yaw = PI * 0.6
	await _frames(20)
	await _shot("e3_apartment_bed")
	# Kasei Aero: buy the VTOL, fly it.
	var vtol := 3
	m.city.estate.menu_act("plane:%d" % vtol, me)
	m.city.estate.inside = []
	var spot: Array = WorldLayout.aircraft_spot()
	await _pose(me, (spot[0] as Vector3) + Vector3(0, 0, 3.0), 0.0, -0.1)
	await _frames(10)
	await _shot("e4_vtol_parked")
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(10)
	print("CITY WALK: in the aircraft = %s, model %d" % [me.state.vehicle >= 0, me.state.vehicle_model])
	m.input.touch_held = PlayerCommand.Held.JUMP
	await _frames(60)
	m.input.touch_held = 0
	m.input.touch_move = Vector2(0, 1)
	await _frames(50)
	print("CITY WALK: flying at %.0f m over the ground, %.0f m/s" % [me.state.position.y - WorldTerrain.surface(me.state.position.x,
			me.state.position.z), me.state.vehicle_speed])
	await _shot("e5_flying")
	m.input.touch_move = Vector2.ZERO
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(10)
	if m.city.shelf.visible:
		m.city.shelf.close()
	# A grove: fell a tree.
	var tree: Array = WorldLayout.trees().filter(func(t: Array) -> bool: return not t[2])[0]
	var tp: Vector3 = tree[1]
	await _pose(me, tp + Vector3(2.0, 0.1, 0), PI * 0.5, -0.05)
	await _frames(5)
	print("CITY WALK: near the tree = %s" % m.city._near)
	await _shot("e6_grove")
	m.input.press(PlayerCommand.Action.INTERACT)
	await _frames(240)
	print("CITY WALK: timber %d" % int(c.d.stash.get("timber", 0)))
	await _shot("e7_felled")


func _districts_run(me: SimPlayer) -> void:
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	var now_h := GameClock.hour(Time.get_unix_time_from_system())
	var to_hour := func(hh: float) -> void:
		CityNpcs.hour_offset = fposmod(hh - now_h, 24.0)
		weather.hour_offset = CityNpcs.hour_offset
	to_hour.call(10.5)
	var look := func(from: Vector2, target: Vector2) -> float:
		var d := target - from
		return atan2(-d.x, -d.y)
	var h := WorldLayout.HELIOS
	var g := WorldLayout.GALLERIA
	var t := WorldLayout.TERRACE
	var p := WorldLayout.SKYPORT
	var shots := [
		["d1_helios", h + Vector2(110, 4), h + Vector2(-20, 0), 0.25],  # down the avenue from the road
		["d10_helios_spire", h + Vector2(-30, 8), h + Vector2(-62, -50), 0.5],
		["d13_helios_south", h + Vector2(4, 118), h + Vector2(0, -60), 0.2],
		["d11_pod", t + Vector2(-20, 6), t + Vector2(-42 * cos(0.2 + TAU / 10.0 * 4.0) * 0.0 - 30, 30), 0.12],
		["d3_galleria", g + Vector2(78, 26), g + Vector2(20, 0), 0.12],
		["d4_galleria_in", g + Vector2(-34, 0), g + Vector2(40, 0), 0.05],
		["d5_terrace", t + Vector2(-104, -8), t, 0.06],
		["d6_skyport", p + Vector2(-105, 25), p + Vector2(60, 20), 0.08],  # along the street
		["d7_monorail", Vector2(-340, 90), Vector2(-370, 20), 0.25],
		["d8_outlands", Vector2(-300, 110), Vector2(-440, 60), 0.06],
	]
	for sh: Array in shots:
		var from: Vector2 = sh[1]
		await _pose(me, WorldTerrain.at(from.x, from.y) + Vector3(0, 0.1, 0), look.call(from, sh[2]), sh[3])
		print("CITY WALK: region %s room %d" % [m.city.region, m.city.room])
		await _shot(sh[0])
	var shop: Array = WorldLayout.shops()[0]
	var front: Vector3 = (shop[1] as Vector3) + Basis(Vector3.UP, float(shop[3]) - PI) * Vector3(0, 0, 9.0)
	await _pose(me, front, float(shop[3]) - PI, 0.18)
	await _shot("d12_shopfront")
	to_hour.call(22.0)
	await _frames(30)
	await _pose(me, WorldTerrain.at(h.x + 10, h.y + 150) + Vector3(0, 0.1, 0), look.call(h + Vector2(10, 150), h + Vector2(0, -30)), 0.22)
	await _shot("d2_helios_night")
	await _pose(me, WorldTerrain.at(t.x - 104, t.y - 8) + Vector3(0, 0.1, 0), look.call(t + Vector2(-104, -8), t), 0.06)
	await _shot("d9_terrace_night")
	# From the air: the hub, then each district.
	to_hour.call(10.5)
	await _frames(30)
	var city := Vector2(CityLayout.ORIGIN.x, CityLayout.ORIGIN.z)
	await _aerial("a0_hub", city + Vector2(60, -40), Vector3(0, 640, 420))
	for a: Array in [["a1_helios", h], ["a2_galleria", g], ["a3_terrace", t], ["a4_skyport", p], ["a5_city", city],
			["a6_hollow", Vector2(WorldLayout.HOLLOW.x + 4, WorldLayout.HOLLOW.z)]]:
		await _aerial(a[0], a[1], Vector3(0, 150, 130))
	# The roads where they cut and climb: the canyon's mouth, the lift yard, the gate.
	for a: Array in [["r1_canyon_mouth", WorldLayout.CANYON_GATE + Vector2(30, 0)], ["r2_lift_road", WorldLayout.LIFT_ROAD],
			["r3_gate_roads", Vector2(-220, 120)]]:
		await _aerial(a[0], a[1], Vector3(-60, 70, 90))


## A shot from a camera `offset` from the ground at `target`, looking at it.
func _aerial(shot: String, target: Vector2, offset: Vector3) -> void:
	for c: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	add_child(cam)
	var at := WorldTerrain.at(target.x, target.y)
	cam.position = at + offset
	cam.look_at(at)
	cam.fov = 60.0
	cam.far = 2400.0
	cam.current = true
	m.hud.visible = false
	await _frames(30)
	await _shot(shot)
	cam.current = false
	cam.queue_free()
	m.hud.visible = true


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
	print("CITY WALK: %s (draw calls %d)" % [name, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


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
	if Platform.user_args.has("--squad"):
		var hr: HuntRules = m.server.world.hunt
		print("CITY WALK: squad of %d, members %s" % [hr.squad.squad_of(me.net_id).members.size() if hr.squad.squad_of(me.net_id) != null else 0, hr.squad.by_id.keys()])
		hr.request(m.server.world, me.net_id, "squad_strategy", {"strategy": "bodyguard"})
		await _frames(240)
		for id: int in hr.squad.by_id:
			print("CITY WALK: teammate %d %.1f m from you" % [id, m.server.world.players[id].state.position.distance_to(me.state.position)])
		await _shot("d1b_squad")
	var pad := WorldLayout.dig_pad()
	await _pose(me, pad + Vector3(-8, 0.3, 0), PI * 0.5 + 0.35, -0.12)
	await _shot("d2_rover_at_pad")
	await _pose(me, WorldLayout.canyon(270.0) + Vector3(0, 0.3, 0), -PI * 0.5 + 0.15, -0.05)
	await _shot("d3_canyon_to_vault")
	await _pose(me, WorldLayout.canyon(288.0) + Vector3(0, 0.3, 2), -PI * 0.5, -0.15)
	await _shot("d4_vault")
	await _pose(me, WorldTerrain.at(200.0, 135.0) + Vector3(0, 0.3, 0), 0.0, -0.15)
	await _shot("d5_rim_extraction")
	# A canyon extraction site close up (the pad deck, the waiting rotorcraft).
	var z: Vector3 = WorldLayout.dig_hunt_data().extraction_zones[2]  # on the rim, in the open
	await _pose(me, z + Vector3(0, 0.3, 18), 0.0, 0.18)
	await _shot("d6_extraction_site")
	get_tree().quit(0)


## --frisk: someone gives up to you (a raider with a pack and a loaded
## vehicle): the search screen shows each compartment on its own; then a
## scan names what each holds.
func _frisk_run(me: SimPlayer) -> void:
	var at := CityLayout.ORIGIN + Vector3(0, 0.05, 20)
	await _pose(me, at, 0.0, -0.1)
	var raider: SimPlayer = m.server.add_bot("Concern·Rook", TargetDummyDriver.new(1))
	m.server.world.teleport(raider, at + Vector3(0, 0, -3))
	m.server.world.packs[raider.net_id] = {"red_dust": 2, "rare_ore": 3, "medkit": 1}
	var rv: SimVehicle = m.server.world.add_vehicle(at + Vector3(6, 0.3, -3), 0.0)
	rv.owner = raider.net_id
	rv.cargo = {"refined_ingot": 2, "stolen_cargo": 1}
	await _frames(20)
	var comps: Array = m.city.victim_compartments(raider.net_id)
	for comp: Array in comps:
		print("FRISK compartment %s: %s" % [comp[0], comp[1]])
	m.city._open_shelf({"mode": "loot", "title": comps[0][0], "right": comps[0][1], "compartments": comps})
	await _frames(10)
	await _shot("f1_search_pack")
	m.city.shelf._compartment = 1
	m.city.shelf.title = comps[1][0]
	m.city.shelf.right = comps[1][1]
	m.city.shelf.refresh()
	await _frames(10)
	await _shot("f2_search_hold")
	m.city.shelf.close()
	for mk: Array in m.city.targets(me.state.position, 30.0, true):
		print("FRISK scan: %s" % mk[1])
	print("FRISK: %s" % ("PASS" if comps.size() >= 2 and not (comps[1][1] as Dictionary).is_empty() else "FAIL"))


## --walkin: the settlement block's acceptance test, by walking (real
## physics, the joystick held): for each building, from outside its airlock
## through both doors into the room, then back out; the doors must open for
## you; the people must reach their stops. Exits 0 only if all hold.
const WALKIN := [["titan/hab_r14", 10.0], ["titan/market_hub", 10.0], ["titan/plant_ex03", 12.0], ["titan/gatehouse", 10.0]]


func _local_y(bp: Array, at: Vector3) -> float:
	var local := Basis(Vector3.UP, deg_to_rad(float(bp[2]))).inverse() * (at - (bp[1] as Vector3))
	return -local.z


func _walk(me: SimPlayer, yaw: float, seconds: float, until: Callable) -> bool:
	m.input.look_yaw = yaw
	var frames := 0
	while frames < int(seconds * 30.0):
		m.input.touch_move = Vector2(0, 1)
		await get_tree().process_frame
		frames += 1
		if until.call():
			m.input.touch_move = Vector2.ZERO
			return true
	m.input.touch_move = Vector2.ZERO
	return false


func _walkin_test(me: SimPlayer) -> void:
	var fails: Array[String] = []
	var settlement: TitanSettlement = get_tree().root.find_child("Settlement", true, false)
	for b: Array in WALKIN:
		var bp := TitanSettlement.piece(b[0])
		var d: float = b[1]
		var gate: bool = b[0] == "titan/gatehouse"
		var outside := -d / 2.0 - (4.0 if gate else 5.5)
		var start := TitanSettlement.to_world(bp, 0.0 if not gate else 2.0, outside) + Vector3(0, 0.3, 0)
		var inward := TitanSettlement.to_yaw(bp, 0.0)
		await _pose(me, start, inward, -0.05)
		var inside_y := -d / 2.0 + 1.0 if not gate else d / 2.0 + 3.0  # past the inner door; the gatehouse: right through
		var t0 := Time.get_ticks_msec()
		var opened := {"any": false}  # (a lambda gets a copy of a plain bool)
		var got_in: bool = await _walk(me, inward, 14.0, func() -> bool:
			if settlement != null:
				for door: Array in settlement._doors:
					if float(door[6]) > 0.9:
						opened.any = true
			return _local_y(bp, me.state.position) > inside_y)
		await _shot("w_%s_in" % str(b[0]).get_file())
		var got_out: bool = await _walk(me, wrapf(inward + PI, -PI, PI), 14.0, func() -> bool:
			return _local_y(bp, me.state.position) < outside + 1.0 if not gate else _local_y(bp, me.state.position) < -d / 2.0 - 2.0)
		print("WALKIN %-18s in %s, out %s, a door opened %s, at %s (%.1f s)" % [b[0], got_in, got_out, opened.any, me.state.position,
				(Time.get_ticks_msec() - t0) / 1000.0])
		if not got_in:
			fails.append("%s: couldn't walk in" % b[0])
		if not got_out:
			fails.append("%s: couldn't walk out" % b[0])
		if not opened.any:
			fails.append("%s: no door opened" % b[0])
	# The people: every routine visits its stops.
	var npcs: CityNpcs = get_tree().get_first_node_in_group("city_npcs")
	npcs.everyone_awake = true  # the test watches them all at once
	var routines: Array = npcs._walkers.filter(func(w: Array) -> bool: return w.size() > 4)
	var visits: Array = []
	for w in routines:
		visits.append({})
	for f in 1800:
		await get_tree().process_frame
		for k in routines.size():
			visits[k][int(routines[k][3])] = true
	for k in routines.size():
		var stops := (routines[k][2] as Array).size()
		print("WALKIN person %d: %d of %d stops reached" % [k, (visits[k] as Dictionary).size(), stops])
		if (visits[k] as Dictionary).size() < mini(stops, 3):
			fails.append("person %d stuck on their routine" % k)
	print("WALKIN: %s" % ("PASS" if fails.is_empty() else "FAIL: " + "; ".join(fails)))
	get_tree().quit(0 if fails.is_empty() else 1)


## --block: the settlement block (the plaza) and each building's inside,
## for before/after shots: [name, where (relative to CityLayout.ORIGIN),
## yaw, pitch].
const BLOCK_VIEWS := [
	["b0_plaza", Vector3(0, 0.05, 22), 0.0, -0.02],
	["b1_home_door", Vector3(-24, 0.05, -28), PI * 0.5 - 0.15, -0.05],
	["b2_home_inside", Vector3(-38.2, 0.05, -31), PI * 0.5, -0.12],
	["b2b_home_bedroom", Vector3(-37.5, 0.05, -36.5), PI * 0.5 + 0.6, -0.15],
	["b3_shop_door", Vector3(18, 0.05, -18), 0.1, -0.05],
	["b4_shop_inside", Vector3(19, 0.05, -29.8), 0.0, -0.12],
	["b5_plant", Vector3(22, 0.05, -30), -PI * 0.5 + 0.3, -0.04],
	["b6_plant_inside", Vector3(38.5, 0.05, -34), -PI * 0.5 - 0.3, -0.1],
	["b7_gate", Vector3(0, 0.05, 24), PI, -0.04],
	["b8_gate_hall", Vector3(1.5, 0.05, 36), PI, -0.08],
]


## --day: the city at 13:00 (the daylight and the sky bands); --squall: the
## methane squall at its height (rain, the haze closes in). Both shift the
## Weather node (DustStorms) and the NPCs' clock, as the other tours do.
func _set_weather(day: bool, squall: bool) -> void:
	var weather: DustStorms = m.get_tree().root.find_child("Weather", true, false)
	if weather == null or not (day or squall):
		return
	if day:
		CityNpcs.hour_offset = fposmod(13.0 - GameClock.hour(Time.get_unix_time_from_system()), 24.0)
		weather.hour_offset = CityNpcs.hour_offset
	# Place the squall: at its height (--squall), or in the clear between two
	# (no rain). The Weather node's clock is seconds since its _ready.
	var at := fposmod(weather._time * Sim.TICK_DT - Survival.STORM_FIRST, Survival.STORM_EVERY)
	var target := Survival.STORM_LENGTH * 0.5 if squall else Survival.STORM_LENGTH + (Survival.STORM_EVERY - Survival.STORM_LENGTH) * 0.5
	var wait := fposmod(target - at, Survival.STORM_EVERY)
	weather.tick_offset = roundi(wait / Sim.TICK_DT)
	Survival.weather = true
	print("CITY WALK: weather day %s squall %s" % [day, squall])


func _block_tour(me: SimPlayer) -> void:
	if m.city != null and m.city._nation_pick == null:
		Profile.career().choose_nation(0)
	await _frames(10)
	for v: Array in BLOCK_VIEWS:
		await _pose(me, CityLayout.ORIGIN + (v[1] as Vector3), v[2], v[3])
		await _shot(v[0])


## --phase1: the nation pick and the tracker in the city; in a run (with
## --dig-only) the nations' colours, the squad and the guided objective.
func _phase1_run(me: SimPlayer, dig: bool) -> void:
	if not dig:
		await _frames(20)
		await _shot("p1_nation_pick")
		var pick: NationPick = m.city._nation_pick
		print("PHASE1: nation pick shown %s" % (pick != null))
		pick.chosen.emit(0)
		await _frames(30)
		await _pose(me, CityLayout.ORIGIN + Vector3(0, 0.05, 20), 0.0, -0.05)
		await _shot("p1_city_tracker")
		print("PHASE1: tracker step %d, nation %s" % [Guide.step(Profile.career()), Nations.display_name(Profile.career().nation())])
		return
	while m.server.phase != MatchPhase.PLAYING:
		await _frames(10)
	await _frames(40)
	m.server.world.damage_enabled = false
	m.hunt_hud.touch = true
	var h: HuntRules = m.server.world.hunt
	var mate: int = h.social.allies.get(me.net_id, 0)
	for id: int in h.nations:
		var p: SimPlayer = m.server.world.players[id]
		print("PHASE1: %-14s nation %-18s ally %-14s %s" % [p.display_name, Nations.display_name(h.nation_of(id)),
				m._display_name(h.social.allies.get(id, 0)) if h.social.allies.has(id) else "-", h.personalities.get(id, "")])
	print("PHASE1: squadmate %s (may turn %s), objective: %s" % [m._squadmate, h.may_turn.get(mate, "?"), m.hud._objective])
	await _shot("p1_run_start")
	# The squadmate and a rival nation's hunter, side by side in front of us.
	var spot := WorldLayout.canyon(200.0) + Vector3(0, 0.3, 0)
	await _pose(me, spot, 0.0, -0.06)
	var rival := 0
	for id: int in h.nations:
		if h.nation_of(id) != h.nation_of(me.net_id) and not h.social.allies.has(id):
			rival = id
			break
	for i in 12:
		for pair: Array in [[mate, Vector3(-2.2, 0, -7)], [rival, Vector3(2.2, 0, -7)]]:
			var bp: SimPlayer = m.server.world.players.get(pair[0])
			if bp != null:
				m.server.world.teleport(bp, spot + pair[1])
				bp.state.yaw = PI
		await _frames(2)
	await _shot("p1_squad_and_rival")
	# Behind a wall: the squadmate's name still shows.
	var mp: SimPlayer = m.server.world.players.get(mate)
	print("PHASE1: squad plate shown %s, rival plate nation %d" % [m._visuals[mate].nameplate_squad, m._visuals[rival].nameplate_nation])
	if mp != null:
		await _shot("p1_squad_far")


## --budget: the phone budget (86 draws, 100k triangles, 86 MB video
## memory) at each probe spot (--spot NAME for one), and what spends it:
## --cats hides each category in turn (world batches, terrain, people, the
## HUD...), --ui detaches each HUD element in turn, --outside lists what's
## drawn outside the world's presentation, --hold waits 40 s per spot for a
## remote debugger's video-memory list. Draw counts include the 2D HUD.
## Run it at the phone's resolution with the phone's settings:
##   xvfb-run -s "-screen 0 2400x1080x24" godot --resolution 2400x1080 \
##     res://tools/city_walk.tscn -- --budget --phone-lod \
##     --quality medium,lod=4.0,probe=false,msaa=1 --cats
func _budget_probe(me: SimPlayer) -> void:
	var spots := [["plaza", CityLayout.ORIGIN + Vector3(0, 0.05, 10), 0.0],
			["titan", CityLayout.ORIGIN + Vector3(-24, 0.05, -28), PI * 0.5 - 0.15],
			["shop", CityLayout.ORIGIN + Vector3(18, 0.05, -18), 0.1],
			["hollow", WorldTerrain.at(WorldLayout.HOLLOW.x, WorldLayout.HOLLOW.z + 10) + Vector3(0, 0.1, 0), 0.0],
			["helios", WorldTerrain.at(WorldLayout.HELIOS.x + 5, WorldLayout.HELIOS.y + 78) + Vector3(0, 0.1, 0), 0.0],
			["galleria_in", WorldTerrain.at(WorldLayout.GALLERIA.x - 34, WorldLayout.GALLERIA.y) + Vector3(0, 0.1, 0), -PI * 0.5],
			["outlands", WorldTerrain.at(-300, 60) + Vector3(0, 0.1, 0), 1.0]]
	var only := Platform.get_user_arg("--spot", "")
	await _frames(240)  # the arrival settles first (a teleport before it is undone)
	for place: Array in spots:
		if not only.is_empty() and place[0] != only:
			continue
		await _pose(me, place[1], place[2], -0.05)
		await _shot("budget_" + str(place[0]))
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true  # nothing moves while it's measured
		var all := await _measure()
		print("BUDGET %s: draws %d, triangles %dk, video %.1f MB (textures %.1f, buffers %.1f)" % [place[0], all.x, all.y / 1000,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
				Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0])
		if Platform.user_args.has("--cats"):
			for cat: String in ["Batch_", "Terrain_", "Tree_", "character", "label", "particles", "ui", "People", "WorldPresentation", "Skeleton3D", "mesh_outside_world"]:
				var nodes := []
				for gi: Node in get_tree().root.find_children("*", "", true, false):
					var hit := false
					match cat:
						"character": hit = gi is PlayerVisual
						"label": hit = gi is Label3D
						"particles": hit = gi is GPUParticles3D or gi is CPUParticles3D
						"ui": hit = gi is CanvasLayer
						"Skeleton3D": hit = gi is Skeleton3D
						"mesh_outside_world": hit = gi is GeometryInstance3D and not _under(gi, "WorldPresentation") and not _under(gi, "People")
						_: hit = str(gi.name).begins_with(cat)
					if hit and gi.get("visible"):
						nodes.append(gi)
				var before := await _measure()
				for n: Node in nodes:
					n.set("visible", false)
				var after := await _measure()
				for n: Node in nodes:
					n.set("visible", true)
				print("BUDGET %s   %-12s x%-3d draws %4d -> %4d  triangles %6.1fk -> %6.1fk" % [place[0], cat, nodes.size(), before.x, after.x, before.y / 1000.0, after.y / 1000.0])
		if Platform.user_args.has("--shadows"):
			var lights := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
			var before := await _measure()
			for l: DirectionalLight3D in lights:
				l.shadow_enabled = false
			var after := await _measure()
			for l: DirectionalLight3D in lights:
				l.shadow_enabled = true
			print("BUDGET %s   shadows off: draws %d -> %d, triangles %.1fk -> %.1fk" % [place[0], before.x, after.x, before.y / 1000.0, after.y / 1000.0])
			var nb := 0
			for b: MeshInstance3D in get_tree().root.find_children("Batch_*", "MeshInstance3D", true, false):
				if b.is_visible_in_tree():
					nb += 1
					b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a2 := await _measure()
			print("BUDGET %s   batches cast no shadow (%d): draws -> %d, triangles -> %.1fk" % [place[0], nb, a2.x, a2.y / 1000.0])
		if Platform.user_args.has("--batchcost"):
			var base := await _measure()
			for b: MeshInstance3D in get_tree().root.find_children("Batch_*", "MeshInstance3D", true, false):
				if not b.is_visible_in_tree():
					continue
				b.visible = false
				var after := await _measure()
				b.visible = true
				if base.x - after.x > 0 or base.y - after.y > 2000:
					print("BUDGET %s   %-18s draws %d tris %.1fk (mesh %.1fk) at %.0f m reach %.0f %s" % [place[0], b.name, base.x - after.x, (base.y - after.y) / 1000.0,
							(b.mesh as ArrayMesh).surface_get_array_len(0) / 3000.0, get_viewport().get_camera_3d().global_position.distance_to(b.global_position), b.visibility_range_end,
							"outlined" if b.material_override.next_pass != null else "plain"])
		if Platform.user_args.has("--world"):
			_world_tally(str(place[0]))
		if Platform.user_args.has("--outside"):
			var cam := get_viewport().get_camera_3d()
			var tally := {}
			for gi: GeometryInstance3D in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
				if not gi.is_visible_in_tree() or _under(gi, "WorldPresentation") or _under(gi, "People"):
					continue
				var d := cam.global_position.distance_to(gi.global_position)
				if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end:
					continue
				var path := str(gi.get_parent().get_parent().name if gi.get_parent().get_parent() != null else "") + "/" + str(gi.get_parent().name) + "/" + str(gi.name).get_slice("@", 0)
				var mi := gi as MeshInstance3D
				var key := "%s %s mesh=%s" % [gi.get_class(), path.left(60), str(mi.mesh.resource_name if mi != null and mi.mesh != null else "")]
				var row: Array = tally.get(key, [0, 9999.0])
				tally[key] = [row[0] + 1, minf(row[1], d)]
			for k: String in tally:
				print("BUDGET %s   outside x%d nearest %.0f m  %s" % [place[0], tally[k][0], tally[k][1], k])
		if Platform.user_args.has("--ui"):
			var items := []
			for layer: CanvasLayer in get_tree().root.find_children("*", "CanvasLayer", true, false):
				if not layer.visible:
					continue
				for c: Node in layer.get_children():
					items.append(c)
					for g: Node in c.get_children():
						if g is CanvasItem:
							items.append(g)
			for c: Node in items:
				if not c.is_inside_tree() or not (c is CanvasItem) or not (c as CanvasItem).is_visible_in_tree():
					continue
				var parent := c.get_parent()
				var idx := c.get_index()
				var before := await _measure()
				parent.remove_child(c)
				var after := await _measure()
				parent.add_child(c)
				parent.move_child(c, idx)
				if before.x - after.x >= 2:
					var desc := []
					for k: Node in c.find_children("*", "", true, false):
						if desc.size() < 5:
							desc.append(k.get_class() + ((":" + str(k.get("text")).left(10)) if k.get("text") is String else ""))
					print("BUDGET %s   ui %-28s draws %3d  %s %s %s" % [place[0], str(parent.name).left(10) + "/" + str(c.name).left(16), before.x - after.x, c.get_class(), str(c.get("text")).left(16) if c.get("text") is String else "", desc])
			var cam := get_viewport().get_camera_3d()
			for b: MeshInstance3D in get_tree().root.find_children("Batch_*", "MeshInstance3D", true, false):
				var d := cam.global_position.distance_to(b.global_position)
				if d < b.visibility_range_end + 10.0 or b.visibility_range_end == 0.0:
					print("BUDGET %s   %s d=%.0f tris %d outline %s" % [place[0], b.name, d, b.mesh.surface_get_array_index_len(0) / 3, b.material_override.next_pass != null])
		if Platform.user_args.has("--hold"):
			print("BUDGET HOLD %s %d" % [place[0], Time.get_ticks_msec()])
			await get_tree().create_timer(40.0, true).timeout
		get_tree().paused = false
	_character_report()
	_texture_report()
	_rd_report()
	_cache_report()
	_mesh_report()
	if Platform.user_args.has("--vramsplit"):
		await _vram_split()


## Texture memory as the renderer's extras are turned off one at a time.
func _vram_split() -> void:
	var tex := func() -> float:
		for i in 6:
			await get_tree().process_frame
		return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	print("SPLIT base %.1f" % await tex.call())
	var we := get_tree().root.find_children("*", "WorldEnvironment", true, false)
	var env: Environment = (we[0] as WorldEnvironment).environment if not we.is_empty() else null
	if env != null:
		env.glow_enabled = false
		print("SPLIT glow off %.1f" % await tex.call())
		env.background_mode = Environment.BG_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		print("SPLIT sky off %.1f" % await tex.call())
	for l: DirectionalLight3D in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		l.shadow_enabled = false
	print("SPLIT shadows off %.1f" % await tex.call())
	get_tree().root.scaling_3d_scale = 0.25
	print("SPLIT scale 0.25 %.1f" % await tex.call())
	for c: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		c.queue_free()
	print("SPLIT canvas freed %.1f" % await tex.call())
	for c: Node in get_tree().root.find_children("*", "WorldPresentation*", true, false):
		c.queue_free()
	print("SPLIT world presentation freed %.1f" % await tex.call())


## Every distinct mesh in the scene by approximate GPU size (vertices x
## stride + indices + LOD indices), grouped by where it comes from.
func _mesh_report() -> void:
	var seen := {}
	var groups := {}
	for n: Node in get_tree().root.find_children("*", "", true, false):
		var m: Mesh = null
		if n is MeshInstance3D:
			m = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
			m = (n as MultiMeshInstance3D).multimesh.mesh
		if m == null or seen.has(m) or not (m is ArrayMesh):
			continue
		seen[m] = true
		var am := m as ArrayMesh
		var bytes := 0
		for si in am.get_surface_count():
			var vc := am.surface_get_array_len(si)
			var ic := am.surface_get_array_index_len(si)
			var fmt := am.surface_get_format(si)
			var stride := 12 + (8 if fmt & Mesh.ARRAY_FORMAT_NORMAL else 0) + (4 if fmt & Mesh.ARRAY_FORMAT_TANGENT else 0) \
					+ (4 if fmt & Mesh.ARRAY_FORMAT_COLOR else 0) + (8 if fmt & Mesh.ARRAY_FORMAT_TEX_UV else 0) + (8 if fmt & Mesh.ARRAY_FORMAT_TEX_UV2 else 0) \
					+ (24 if fmt & Mesh.ARRAY_FORMAT_BONES else 0) + (16 if fmt & Mesh.ARRAY_FORMAT_CUSTOM0 else 0)
			bytes += vc * stride + ic * (2 if vc < 65536 else 4) * 2  # indices + about as much again in LODs
		var key := am.resource_path.get_base_dir() if not am.resource_path.is_empty() else str(n.name).rstrip("0123456789_").left(14)
		if key.is_empty():
			key = str(n.get_parent().name).left(14)
		groups[key] = groups.get(key, 0) + bytes
		if am.shadow_mesh != null and not seen.has(am.shadow_mesh):
			seen[am.shadow_mesh] = true
			groups["(shadow meshes)"] = groups.get("(shadow meshes)", 0) + am.shadow_mesh.surface_get_array_len(0) * 12
	var keys := groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return groups[a] > groups[b])
	var total := 0
	for k: String in keys:
		total += groups[k]
	print("MESHES %d, ~%.1f MB" % [seen.size(), total / 1048576.0])
	for k: String in keys.slice(0, 25):
		print("MESH %6.2f MB %s" % [groups[k] / 1048576.0, k])


## Every imported texture/font the ResourceLoader holds (loaded anywhere,
## in the scene or not), largest first.
func _cache_report() -> void:
	var rows := []
	var stack := ["res://"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for d in DirAccess.get_directories_at(dir):
			if not d.begins_with("."):
				stack.append(dir.path_join(d))
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".import"):
				continue
			var path := dir.path_join(f.trim_suffix(".import"))
			if not ResourceLoader.has_cached(path):
				continue
			var r := ResourceLoader.load(path)
			var mb := 0.0
			var info := r.get_class()
			if r is Texture2D and not (r is ViewportTexture):
				var img := (r as Texture2D).get_image()
				if img != null:
					mb = img.get_data_size() / 1048576.0
					info = "%dx%d fmt %d mips %s" % [img.get_width(), img.get_height(), img.get_format(), img.has_mipmaps()]
			elif r is TextureLayered:
				var tl := r as TextureLayered
				for i in tl.get_layers():
					mb += tl.get_layer_data(i).get_data_size() / 1048576.0
				info = "%dx%d x%d" % [tl.get_width(), tl.get_height(), tl.get_layers()]
			rows.append([mb, path, info])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var total := 0.0
	for r: Array in rows:
		total += r[0]
	print("CACHED %d, %.1f MB" % [rows.size(), total])
	for r: Array in rows:
		var f := ResourceLoader.load(r[1]) as FontFile
		if f == null:
			continue
		var fmb := 0.0
		var n := 0
		for ci in f.get_cache_count():
			for sz: Vector2i in f.get_size_cache_list(ci):
				for ti in f.get_texture_count(ci, sz):
					var im := f.get_texture_image(ci, sz, ti)
					if im != null and r[1].contains("Anton"):
						print("FONTTEX %s size %s %dx%d fmt %d" % [ci, sz, im.get_width(), im.get_height(), im.get_format()])
					if im != null:
						fmb += im.get_data_size() / 1048576.0
						n += 1
		print("FONT %6.2f MB in %d glyph textures %s" % [fmb, n, r[1]])
	for r: Array in rows.slice(0, 50):
		print("CACHED %6.2f MB %s %s" % [r[0], r[2], r[1]])


## Every live viewport (each one owns render targets).
func _rd_report() -> void:
	for vp: Node in get_tree().root.find_children("*", "SubViewport", true, false):
		var v := vp as SubViewport
		print("VIEWPORT %s %s msaa %d update %d" % [v.get_path(), v.size, v.msaa_3d, v.render_target_update_mode])
	var root := get_tree().root
	print("ROOT %s scale %.2f msaa %d ssaa %d" % [root.size, root.scaling_3d_scale, root.msaa_3d, root.screen_space_aa])


## --world: what the in-range world meshes spend, grouped by parent + name
## (draws = surfaces x material passes, as the renderer counts them).
func _world_tally(spot: String) -> void:
	var cam := get_viewport().get_camera_3d()
	var tally := {}
	for gi: GeometryInstance3D in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		if not gi.is_visible_in_tree() or not (gi is MeshInstance3D or gi is MultiMeshInstance3D):
			continue
		var d := cam.global_position.distance_to(gi.global_position)
		if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end:
			continue
		if gi.visibility_range_begin > 0.0 and d < gi.visibility_range_begin:
			continue
		var planes := cam.get_frustum()
		var wb := gi.global_transform * gi.get_aabb()
		var inside := true
		for pl: Plane in planes:
			var pt := Vector3(wb.position.x + (wb.size.x if pl.normal.x > 0.0 else 0.0), wb.position.y + (wb.size.y if pl.normal.y > 0.0 else 0.0), wb.position.z + (wb.size.z if pl.normal.z > 0.0 else 0.0))
			if pl.distance_to(pt) > 0.0:
				inside = false
				break
		if not inside:
			continue
		var surf := 1
		var passes := 1
		var tris := 0
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			var mi := gi as MeshInstance3D
			surf = mi.mesh.get_surface_count()
			passes = 0
			for s in surf:
				var mat := mi.get_active_material(s)
				var p := 0
				while mat != null:
					p += 1
					mat = mat.next_pass
				passes += maxi(p, 1) + (1 if mi.material_overlay != null else 0)
				if mi.mesh is ArrayMesh:
					tris += (mi.mesh as ArrayMesh).surface_get_array_index_len(s) / 3
		else:
			passes = 2
		var nm := str(gi.name).get_slice("@", 0)
		if nm.is_empty():
			nm = "(anon)"
		while not nm.begins_with("Batch") and nm.length() > 1 and nm[nm.length() - 1].is_valid_int():
			nm = nm.left(nm.length() - 1)
		var anc := []
		var an: Node = gi.get_parent()
		while an != null and anc.size() < 3:
			if not str(an.name).begins_with("@"):
				anc.append(str(an.name).left(18))
			an = an.get_parent()
		var mnm := ""
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh != null:
			mnm = (gi as MeshInstance3D).mesh.get_class() + ((gi as MeshInstance3D).mesh.resource_name if (gi as MeshInstance3D).mesh.resource_name != "" else "")
		var key := "%s <%s> %s" % [gi.get_class(), "/".join(anc), nm.left(30) + " " + mnm]
		var row: Array = tally.get(key, [0, 0, 0])
		tally[key] = [row[0] + 1, row[1] + passes, row[2] + tris]
	var keys := tally.keys()
	keys.sort_custom(func(a, b): return tally[a][1] > tally[b][1])
	for k: String in keys.slice(0, 70):
		print("BUDGET %s   world x%-3d draws~%-3d tris %-6d %s" % [spot, tally[k][0], tally[k][1], tally[k][2], k])


## What one character costs: draws (surfaces x passes) and triangles per
## mesh, for the first few people.
func _character_report() -> void:
	var shown := 0
	for pv: PlayerVisual in get_tree().root.find_children("*", "PlayerVisual", true, false):
		if shown >= 3:
			break
		shown += 1
		var draws := 0
		var parts := []
		for mi: MeshInstance3D in pv.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree() or mi.mesh == null:
				continue
			for si in mi.mesh.get_surface_count():
				var passes := 0
				var mat := mi.get_active_material(si)
				while mat != null:
					passes += 1
					mat = mat.next_pass
				if mi.material_overlay != null:
					passes += 1
				draws += passes
				parts.append("%s[%d] %d tris x%d" % [mi.name, si, mi.mesh.surface_get_array_index_len(si) / 3, passes])
		print("CHAR %s (%s): %d draws: %s" % [pv.name, pv.get_parent().name, draws, ", ".join(parts)])


func _under(n: Node, name: String) -> bool:
	while n != null:
		if n.name == name:
			return true
		n = n.get_parent()
	return false


func _measure() -> Vector2i:
	await _frames(4)
	var d := 0.0
	var p := 0.0
	for i in 4:
		await get_tree().process_frame
		d += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		p += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	return Vector2i(int(d / 4), int(p / 4))


## Every texture reachable from the scene (materials, shader parameters,
## UI), largest first, with its estimated video memory.
func _texture_report() -> void:
	var seen := {}
	for n: Node in get_tree().root.find_children("*", "", true, false):
		for prop: Dictionary in n.get_property_list():
			if prop.type == TYPE_OBJECT:
				_collect_textures(n.get(prop.name), seen, 0)
	var rows := []
	var total := 0.0
	for t: Variant in seen:
		if not seen[t]:
			continue
		var mb := _tex_mb(t)
		total += mb
		rows.append([mb, t])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("TEXTURES %d, %.1f MB" % [rows.size(), total])
	for r: Array in rows.slice(0, 60):
		var t: Texture2D = r[1]
		var img := t.get_image() if not (t is ViewportTexture) else null
		print("TEX %6.2f MB %dx%d %s %s" % [r[0], t.get_width(), t.get_height(), str(img.get_format()) if img != null else "?",
				t.resource_path if not t.resource_path.is_empty() else t.get_class()])


func _collect_textures(o: Variant, seen: Dictionary, depth: int) -> void:
	if depth > 4 or not (o is Resource):
		return
	if o is Texture2D:
		seen[o] = true
		return
	if seen.has(o):
		return
	seen[o] = false
	if o is ShaderMaterial:
		for u: Dictionary in (o as ShaderMaterial).shader.get_shader_uniform_list() if (o as ShaderMaterial).shader != null else []:
			_collect_textures((o as ShaderMaterial).get_shader_parameter(u.name), seen, depth + 1)
	if o is Mesh:
		for i in (o as Mesh).get_surface_count():
			_collect_textures((o as Mesh).surface_get_material(i), seen, depth + 1)
	for prop: Dictionary in (o as Object).get_property_list():
		if prop.type == TYPE_OBJECT and prop.usage & PROPERTY_USAGE_STORAGE:
			_collect_textures((o as Object).get(prop.name), seen, depth + 1)


func _tex_mb(t: Texture2D) -> float:
	if t is ViewportTexture:
		return 0.0
	var img := t.get_image()
	if img == null:
		return 0.0
	return img.get_data_size() / 1048576.0


## Drops the player at spots all over the valley (on roads, their banks and
## junctions, the districts, the yards), lets them settle, and prints how
## far their feet are from the ground as drawn (WorldTerrain.surface).
func _ground_probe(me: SimPlayer) -> void:
	var spots: Array[Vector2] = []
	for road: Array in WorldLayout.roads():
		var smp := WorldLayout.road_samples(road, 37.0)
		for sm: Array in smp:
			var q: Vector2 = sm[0]
			var n := Vector2(-(sm[1] as Vector2).y, (sm[1] as Vector2).x)
			for off in [0.0, 8.0, 14.0]:
				spots.append(q + n * off)
	for c: Vector2 in [WorldLayout.HELIOS, WorldLayout.GALLERIA + Vector2(70, 0), WorldLayout.TERRACE + Vector2(0, -50),
			WorldLayout.SKYPORT + Vector2(0, 25), Vector2(WorldLayout.HOLLOW.x, WorldLayout.HOLLOW.z), WorldLayout.FACTORY + Vector2(0, 30),
			WorldLayout.GARAGE, Vector2(WorldLayout.LIFT.x, WorldLayout.LIFT.z) + Vector2(-8, 0)]:
		spots.append(c)
	var worst := 0.0
	var bad := 0
	var stand := -1.0  # where the player stands above the ground, from the first open spot
	for q in spots:
		m.server.world.teleport(me, WorldTerrain.at(q.x, q.y) + Vector3(0, 1.5, 0))
		await _frames(20)
		var feet := me.state.position
		var d := feet.y - WorldTerrain.surface(feet.x, feet.z)
		if stand < 0.0:
			stand = d
		d -= stand
		worst = maxf(worst, absf(d))
		if absf(d) > 0.15:
			bad += 1
			print("GROUND PROBE: off by %.2f m at %s (asked %s)" % [d, feet.snapped(Vector3.ONE * 0.1), q.round()])
	print("GROUND PROBE: %d spots, %d off, worst %.2f m" % [spots.size(), bad, worst])


## Where people stand vs the floors drawn under them: at each spot, the
## player's resting height (sim) against the top drawn surface (the render
## meshes' own triangles) and the collision floor. `feet`: a close render of
## the feet at each spot as well (feet_<spot>.png).
func _floor_probe(me: SimPlayer, feet: bool) -> void:
	var spots := {}
	for p: Array in CityLayout.pieces():
		if String(p[0]).begins_with("titan/") and not spots.has(p[0]):
			spots[String(p[0]).trim_prefix("titan/")] = TitanSettlement.to_world(p, 0.5, 0.0) + Vector3(0, 1.0, 0)
	spots["galleria"] = WorldTerrain.at(WorldLayout.GALLERIA.x + 10.0, WorldLayout.GALLERIA.y + 3.0) + Vector3(0, 2.0, 0)
	spots["galleria_east"] = WorldTerrain.at(WorldLayout.GALLERIA.x + 40.0, WorldLayout.GALLERIA.y - 6.0) + Vector3(0, 2.0, 0)
	spots["plaza"] = CityLayout.ORIGIN + Vector3(0, 1.0, -12)
	spots["street"] = WorldTerrain.at(CityLayout.ORIGIN.x - 70.0, CityLayout.ORIGIN.z + 2.0) + Vector3(0, 1.0, 0)
	var only := Platform.get_user_arg("--spot", "")
	await _frames(240)  # the arrival settles first (a teleport before it is undone)
	for name: String in spots:
		if not only.is_empty() and not only.split(",").has(name):
			continue
		var at: Vector3 = spots[name]
		m.server.world.teleport(me, at)
		await _frames(150)
		var pos := me.state.position
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 2.0, Sim.LAYER_WORLD)
		var hit := get_viewport().world_3d.direct_space_state.intersect_ray(q)
		var col_y: float = (hit.position as Vector3).y if not hit.is_empty() else NAN
		var drawn := _drawn_floor(pos)
		print("FLOOR PROBE %s: stands %.3f (asked %.2f, %s), collision %.3f (%s), drawn %.3f (%s) -> feet %+.3f under the drawn floor" % [name,
				pos.y, at.y, PlayerSimState.Move.keys()[me.state.move_state], col_y, hit.get("collider", null), drawn[0], drawn[1], drawn[0] - pos.y])
		if feet:
			await _feet_shot(me, name)


## The top drawn surface under `pos` within 0.6 m above and 1 m below:
## [height, node name] (NAN when nothing is drawn there).
func _drawn_floor(pos: Vector3) -> Array:
	var best := -INF
	var who := ""
	var top := pos.y + 0.6
	var low := pos.y - 1.0
	for n: Node in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree() or _is_mover(gi):
			continue
		var xfs: Array[Transform3D] = []
		var mesh: Mesh = null
		if gi is MeshInstance3D:
			if (gi as MeshInstance3D).skin != null:
				continue
			mesh = (gi as MeshInstance3D).mesh
			xfs.append(gi.global_transform)
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			if mm.transform_format != MultiMesh.TRANSFORM_3D:
				continue
			for i in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
				xfs.append(gi.global_transform * mm.get_instance_transform(i))
		if mesh == null:
			continue
		var aabb := mesh.get_aabb()
		var faces := PackedVector3Array()
		for xf in xfs:
			var box := xf * aabb
			if pos.x < box.position.x or pos.x > box.end.x or pos.z < box.position.z or pos.z > box.end.z \
					or box.position.y > top or box.end.y < low:
				continue
			if faces.is_empty():
				faces = mesh.get_faces()
			var inv := xf.affine_inverse()
			var a := inv * Vector3(pos.x, top, pos.z)
			var b := inv * Vector3(pos.x, low, pos.z)
			for i in range(0, faces.size(), 3):
				var h: Variant = Geometry3D.segment_intersects_triangle(a, b, faces[i], faces[i + 1], faces[i + 2])
				if h != null:
					var y := (xf * (h as Vector3)).y
					if OS.has_environment("FLOOR_PROBE_ALL"):
						print("  drawn %.3f %s %s %s" % [y, gi.get_path(), mesh, xf * aabb])
					if y > best:
						best = y
						who = String(gi.name) + "/" + String(mesh.resource_name)
	return [best if best > -INF else NAN, who]


func _is_mover(n: Node) -> bool:
	while n != null:
		if n.is_in_group("movers"):
			return true
		n = n.get_parent()
	return false


## A low close look at the player's boots from the side.
func _feet_shot(me: SimPlayer, name: String) -> void:
	for c: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	add_child(cam)
	var pos := me.state.position
	# From the side with the most room (walls, tables and doors block some).
	var space := get_viewport().world_3d.direct_space_state
	var best := Vector3(1, 0, 0)
	var room := -1.0
	for i in 12:
		var dir := Vector3(cos(i * TAU / 12.0), 0.0, sin(i * TAU / 12.0))
		var from := pos + Vector3(0, 0.3, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 2.4, Sim.LAYER_WORLD))
		var d := 2.4 if hit.is_empty() else from.distance_to(hit.position)
		if d > room + 0.05:
			room = d
			best = dir
	cam.fov = 40.0
	cam.global_position = pos + best * minf(room - 0.2, 1.7) + Vector3(0, 0.3, 0)
	cam.look_at(pos + Vector3(0, 0.25, 0))
	for i in 30:
		cam.make_current()
		await get_tree().process_frame
	await _shot("feet_" + name)
	cam.queue_free()
	await _frames(2)


## The walk on film: the player walking, jogging and running across the
## plaza, seen side on (frames 0.1 s apart), and how low the boots go
## against the floor under them. Also an NPC walker for comparison.
func _gait_strip(me: SimPlayer) -> void:
	m.view.third_person = true
	m.hud.visible = false
	var cam := Camera3D.new()
	m.view.add_child(cam)  # in the world's own viewport
	cam.fov = 40.0
	var v: PlayerVisual = m._visuals.get(me.net_id)
	for g: int in [InputAdapter.Gait.WALK, InputAdapter.Gait.JOG, InputAdapter.Gait.RUN]:
		m.input.gait = g
		# Helios's avenue, heading west: long, straight, clear.
		var h := WorldLayout.HELIOS
		m.server.world.teleport(me, WorldTerrain.at(h.x + 100, h.y + 5) + Vector3(0, 0.05, 0))
		me.state.yaw = PI * 0.5
		m.input.look_yaw = PI * 0.5
		m.input.look_pitch = -0.1
		await _frames(30)
		m.input.touch_move = Vector2(0, 1)
		var start := me.state.position
		await _frames(40)  # up to speed
		print("GAIT moved %.2f m in 40 frames; touch %s" % [start.distance_to(me.state.position), m.input.touch_move])
		var low := INF
		for f in 10:
			for k in 6:
				cam.global_position = me.state.position + Vector3(0, 1.0, 6.5)
				cam.look_at(me.state.position + Vector3(0, 0.9, 0))
				cam.make_current()
				m.hud.visible = false
				await get_tree().process_frame
			low = minf(low, _lowest_foot(v, me.state.position))
			await _shot("gait_%d_%02d" % [g, f])
		var sp := Vector2(me.state.velocity.x, me.state.velocity.z).length()
		print("GAIT %d: %.2f m/s, lowest boot %.3f m from the floor under it" % [g, sp, low])
		m.input.touch_move = Vector2.ZERO
		await _frames(30)
	cam.current = false


## How far the lowest foot/toe bone is above the ground at `feet` (minus: in it).
func _lowest_foot(v: Node, feet: Vector3) -> float:
	if v == null:
		return INF
	var low := INF
	for sk: Skeleton3D in v.find_children("*", "Skeleton3D", true, false):
		for b in sk.get_bone_count():
			var n := sk.get_bone_name(b).to_lower()
			if n.contains("toe") or n.contains("foot"):
				low = minf(low, (sk.global_transform * sk.get_bone_global_pose(b)).origin.y - feet.y)
	return low
