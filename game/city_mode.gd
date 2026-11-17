class_name CityMode
extends Node
## Free roam in Kasei Valley (THE HUNT's open world): the player walks the
## city, the valley, Dust Hollow and the canyon in third person, weapons
## holstered. Near a vendor's terminal the Action button (or E) opens it
## (CityScreen: contracts, market, outfitter); on the Rustwood Dig's pad it
## deploys to the extraction site. The HUD names where you are; landmarks
## are discovered once (the career logs them and pays a survey fee). The
## match calls update() every frame.

const REACH := 2.8  ## metres from a terminal to use it

var match_node: Node  ## the match (input, touch, hud, view, server)
var screen: CityScreen
var hud_layer: Control
var _last_press: int = -1
var _people: CityNpcs
var _near: String = ""  ## terminal id, "deploy" or ""
var _tab: String = ""
var talk: TalkPanel
var _raid: RaidDirector
var raid_banner: String = ""
var raid_banner_t: float = 0.0
var _hollow_sign: Label3D
const PERSON_AT := {"contracts": "broker", "market": "trader", "outfitter": "armourer"}
var _touch_was_visible: bool = false
var region: String = "city"
var driving_speed: float = -1.0  ## m/s while driving, else -1
var discovery_text: String = ""
var discovery_t: float = 0.0
var shelf: ShelfPanel
var pack_button: Button
var _guard_kind: String = ""   ## "farm" or "convoy": whose guards are out
var _drop_marks := {}          ## drop id -> Node3D (a pack on the ground)
var _convoy_sign: Label3D
var _i_was_down: bool = false
var _h_was_down: bool = false
var _shelf_vit: float = 0.0  ## health + shield last frame (a hit closes the shelf)
var _holdup_id: int = 0
## The Kasei Marshals: your wanted level and the officers out after you.
var wanted := Wanted.new()
var _police: RaidDirector
var _police_down: int = 0     ## officers you've put down this chase
var _police_spawn_t: float = 0.0
var _rover_crime: int = -1    ## the Concern rover you're in (one crime per boarding)
var _nav_chunks := {}
var _was_alive: bool = true
var room: int = WorldLayout.NO_ROOM
var _breakin: int = -1        ## the residence whose lock you're working
var _breakin_t: float = 0.0
var _breakin_tool: String = ""
var quick_button: Button
var garage: GaragePanel
var bino_button: Button
var scan_button: Button
var binocular_on: bool = false
var scan_marks: Array = []       ## [position, label, colour] from the last scan
var scan_t: float = 0.0          ## seconds the marks still show
var _scan_cool: float = 0.0
var _police_seen: bool = false   ## an officer has eyes on you right now
var _in_bay: bool = false
var driving_vehicle: SimVehicle  ## the rover you're in (fuel, condition on the HUD)
var _b_was_down: bool = false
var eat_button: Button
var drink_button: Button
var _kit_seen := {}
var estate: CityEstate   ## doors, property, visas, aircraft, the gang, trees
var bounty: CityBounty   ## the Marshals' Bounty Board
var trade: CityTrade     ## the Red Dust Trade
var events: CityEvents   ## things that turn up out in the valley
var heist: CityHeist     ## heists in stages
var social: CitySocial   ## MarsNet and the people in your life
var marsnet_button: Button
var style: CityStyle     ## looks and the season
var style_button: Button
var burner_button: Button
var draw_button: Button
var torch_button: Button
var drawn: bool = false          ## your gun out by choice (not a fight's)
var torch_on: bool = false
var _g_was_down: bool = false
var _t_was_down: bool = false
var _torch: SpotLight3D
var _jet_fx: GPUParticles3D
var _jet_sound: AudioStreamPlayer3D
var _last_fuel: float = 100.0
var _night_hint: bool = false
var _contacted := {}             ## fighter id -> they've called you out
var _pending_says := {}          ## fighter id -> a line for when their body exists  ## pack item -> the count both sides last agreed on
var _n_was_down: bool = false
var _homes_built: bool = false
var _home_checked: bool = false  ## the building you're in, if any, and its air  ## the fighter a hold-up is offered on (kept with slack)


func setup(layer: CanvasLayer) -> void:
	match_node.get_tree().node_added.connect(_draw_distance)
	for n: Node in match_node.find_children("*", "GeometryInstance3D", true, false):
		_draw_distance(n)
	hud_layer = _CityHud.new()
	hud_layer.city = self
	layer.add_child(hud_layer)
	screen = CityScreen.new()
	screen.visible = false
	layer.add_child(screen)
	screen.closed.connect(func() -> void:
		match_node.input.enabled = true
		match_node.touch.visible = _touch_was_visible)
	screen.deploy_requested.connect(deploy)
	talk = TalkPanel.new()
	layer.add_child(talk)
	talk.closed.connect(_close_talk)
	talk.open_tab.connect(func(tab: String) -> void:
		open_terminal(tab))
	shelf = ShelfPanel.new()
	layer.add_child(shelf)
	shelf.closed.connect(_close_talk)
	shelf.acted.connect(_on_shelf)
	pack_button = Button.new()
	pack_button.text = tr("CITY_PACK_BUTTON")
	pack_button.focus_mode = Control.FOCUS_NONE
	ComicUI.style_button(pack_button, ComicUI.YELLOW, 30, UiStyle.font_hud_big)
	pack_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pack_button.offset_left = -190
	pack_button.offset_right = -40
	pack_button.offset_top = 150
	pack_button.offset_bottom = 212
	pack_button.pressed.connect(open_pack)
	layer.add_child(pack_button)
	var garage_sign := Label3D.new()
	garage_sign.text = tr("GARAGE_NAME").to_upper()
	garage_sign.font = UiStyle.font_hud_big
	garage_sign.font_size = 120
	garage_sign.pixel_size = 0.012
	garage_sign.outline_size = 22
	garage_sign.outline_modulate = ComicUI.INK
	garage_sign.modulate = ComicUI.YELLOW
	garage_sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	garage_sign.position = WorldLayout.garage_spot() + Vector3(0, 9.5, 0)
	match_node.add_child(garage_sign)
	garage = GaragePanel.new()
	layer.add_child(garage)
	garage.closed.connect(_close_talk)
	garage.act.connect(_garage_act)
	social = CitySocial.new(self, layer)
	style = CityStyle.new(self)
	bino_button = _side_button(ComicUI.CYAN, 290, func() -> void: toggle_binoculars())
	bino_button.text = tr("CITY_BINOCULARS")
	scan_button = _side_button(ComicUI.MAGENTA, 356, func() -> void: scan())
	layer.add_child(bino_button)
	layer.add_child(scan_button)
	draw_button = _side_button(ComicUI.RED, 0, func() -> void: toggle_drawn())
	torch_button = _side_button(ComicUI.PAPER, 0, func() -> void: toggle_torch())
	burner_button = _side_button(ComicUI.MAGENTA, 0, func() -> void: _open_burner())
	burner_button.text = tr("TRADE_BURNER")
	burner_button.visible = false
	burner_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	burner_button.offset_left = 232
	burner_button.offset_right = 352
	burner_button.offset_top = 384
	burner_button.offset_bottom = 432
	layer.add_child(burner_button)
	marsnet_button = _side_button(ComicUI.CYAN, 0, func() -> void: social.open())
	marsnet_button.text = "SatNet"
	marsnet_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	marsnet_button.offset_left = 232
	marsnet_button.offset_right = 352
	marsnet_button.offset_top = 440
	marsnet_button.offset_bottom = 488
	layer.add_child(marsnet_button)
	style_button = _side_button(ComicUI.YELLOW, 0, func() -> void: style.open())
	style_button.text = tr("STYLE_BUTTON")
	style_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	style_button.offset_left = 232
	style_button.offset_right = 352
	style_button.offset_top = 496
	style_button.offset_bottom = 544
	layer.add_child(style_button)
	for b: Button in [draw_button, torch_button]:
		b.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		b.offset_left = 232
		b.offset_right = 352
		layer.add_child(b)
	draw_button.offset_top = 272
	draw_button.offset_bottom = 320
	torch_button.offset_top = 328
	torch_button.offset_bottom = 376
	eat_button = _side_button(ComicUI.YELLOW, 0, func() -> void: _eat_or_drink(true))
	drink_button = _side_button(ComicUI.CYAN, 0, func() -> void: _eat_or_drink(false))
	for b: Button in [eat_button, drink_button]:
		b.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		b.offset_left = 34
		b.offset_right = 234
	# Beside the minimap, one above the other.
	for b: Button in [eat_button, drink_button]:
		b.offset_left = 232
		b.offset_right = 352
	eat_button.offset_top = 160
	eat_button.offset_bottom = 208
	drink_button.offset_top = 216
	drink_button.offset_bottom = 264
	layer.add_child(eat_button)
	layer.add_child(drink_button)
	quick_button = Button.new()
	quick_button.focus_mode = Control.FOCUS_NONE
	ComicUI.style_button(quick_button, ComicUI.GREEN, 24, UiStyle.font_hud_big)
	quick_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quick_button.offset_left = -260
	quick_button.offset_right = -40
	quick_button.offset_top = 224
	quick_button.offset_bottom = 278
	quick_button.pressed.connect(quick_use)
	layer.add_child(quick_button)
	# The touch controls take every tap first: let our buttons have their own.
	match_node.touch.ui_blocks = func(pos: Vector2) -> bool:
		for b: Button in [pack_button, quick_button, bino_button, scan_button, eat_button, drink_button, draw_button, torch_button,
				burner_button, marsnet_button, style_button]:
			if b.visible and b.get_global_rect().grow(6).has_point(pos):
				return true
		return false
	_convoy_sign = Label3D.new()
	_convoy_sign.font = UiStyle.font_hud_big
	_convoy_sign.font_size = 96
	_convoy_sign.pixel_size = 0.01
	_convoy_sign.outline_size = 20
	_convoy_sign.outline_modulate = ComicUI.INK
	_convoy_sign.modulate = ComicUI.RED
	_convoy_sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_convoy_sign.text = tr("CITY_CONVOY").to_upper()
	match_node.add_child(_convoy_sign)
	_hollow_sign = Label3D.new()
	_hollow_sign.font = UiStyle.font_hud_big
	_hollow_sign.font_size = 220
	_hollow_sign.pixel_size = 0.014
	_hollow_sign.outline_size = 36
	_hollow_sign.outline_modulate = ComicUI.INK
	_hollow_sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_hollow_sign.position = WorldTerrain.at(WorldLayout.HOLLOW.x + 4, WorldLayout.HOLLOW.z + 4) + Vector3(0, 30, 0)
	match_node.add_child(_hollow_sign)


func update() -> void:
	var _t_city := Time.get_ticks_usec()
	_maybe_pick_nation()
	_update()
	Diagnostics.time_section("city", _t_city)


func _update() -> void:
	var me: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID) if match_node.server != null else null
	if me == null:
		return
	if _people == null:
		_people = match_node.get_tree().get_first_node_in_group("city_npcs")
	if _people != null:
		_people.player_position = me.state.position
		_people.vehicle = {}
		if me.state.vehicle >= 0:
			var vm: Dictionary = VehicleSim.MODELS[clampi(me.state.vehicle_model, 0, VehicleSim.MODELS.size() - 1)]
			_people.vehicle = {"at": me.state.position, "speed": absf(me.state.vehicle_speed), "half": vm.half,
					"fwd": Vector3(-sin(me.state.vehicle_yaw), 0, -cos(me.state.vehicle_yaw)) * signf(me.state.vehicle_speed)}
		if not _people.run_down.is_connected(_on_run_down):
			_people.run_down.connect(_on_run_down)
	var pos := me.state.position
	_near = ""
	driving_speed = absf(me.state.vehicle_speed) if me.state.vehicle >= 0 else -1.0
	var vs: Array[SimVehicle] = match_node.server.world.vehicles
	driving_vehicle = vs[me.state.vehicle] if me.state.vehicle >= 0 and me.state.vehicle < vs.size() else null
	if me.state.vehicle >= 0:
		_near = "exit_rover"
	else:
		var vehicles: Array[SimVehicle] = match_node.server.world.vehicles
		for i in vehicles.size():
			var v := vehicles[i]
			if v.driver == 0 and VehicleSim.at_hold(v, pos):
				_near = "hold:%d" % i
				break
			if v.driver == 0 and v.position.distance_to(pos) < VehicleSim.BOARD_RANGE:
				_near = "rover"
	var _t_goods := Time.get_ticks_usec()
	_near_goods(me)
	Diagnostics.time_section("near_goods", _t_goods)
	var pad := WorldLayout.dig_pad()
	if _near.is_empty() and Vector2(pos.x - pad.x, pos.z - pad.z).length() < WorldLayout.DEPLOY_RADIUS:
		_near = "deploy"
	room = WorldLayout.room_at(pos + Vector3(0, 0.5, 0))
	var was := region
	region = "farm" if pos.y < WorldLayout.FARM_FLOOR + 40.0 else WorldLayout.region_at(pos.x, pos.z)
	if pos.y < WorldLayout.INTERIOR_Y + 100.0:
		region = "interior"
	if region == "city" and was != "city" and was != "":
		_checkpoint()
	_step_raid(me)
	var mark := WorldLayout.landmark_at(pos.x, pos.z)
	if not mark.is_empty():
		_discover(mark)
	# People are where their hours put them; a kiosk works when its person's away.
	for p: Array in people_now():
		if _near.is_empty() and pos.distance_to(p[1]) < REACH + 0.6:
			_near = p[0]
	for t: Array in CityLayout.terminals():
		if _near.is_empty() and pos.distance_to(t[1]) < REACH + 1.6:
			_near = "kiosk:" + str(t[0])
	if _near.is_empty() and pos.distance_to(WorldLayout.lift_top()) < 4.5:
		_near = "lift_down"
	if _near.is_empty() and pos.distance_to(WorldLayout.farm_origin() + Vector3(0, 0, 28)) < 4.5:
		_near = "lift_up"
	for i in WorldLayout.RIGS.size():
		if _near.is_empty() and pos.distance_to(WorldLayout.rig_spot(i)) < 7.0:
			_near = "rig_%d" % i
	if _rig >= 0 and (_near != "rig_%d" % _rig or not me.state.alive):
		_rig = -1  # walked off: the shift stops
	_animate_rigs(match_node.get_process_delta_time())
	_animate_factory(match_node.get_process_delta_time())
	var _t_traffic := Time.get_ticks_usec()
	_step_traffic(me, match_node.get_process_delta_time())
	Diagnostics.time_section("traffic", _t_traffic)
	if _rig >= 0:
		_rig_t += match_node.get_process_delta_time()
		if _rig_t >= WorldLayout.RIG_SECONDS:
			var rig: Array = WorldLayout.RIGS[_rig]
			var got := Profile.career().mine(rig[0], rig[2], int(Time.get_unix_time_from_system()), WorldLayout.RIG_COOLDOWN)
			Profile.save()
			_rig = -1
			var parts := PackedStringArray()
			for item: String in got:
				parts.append("%d× %s" % [got[item], Career.ITEMS[item].name])
			_note(tr("CITY_MINED") % ", ".join(parts), ComicUI.GREEN)
	for spot: Array in WorldLayout.loot_spots():
		if _near.is_empty() and pos.distance_to(spot[1]) < 3.5:
			_near = "loot:" + str(spot[0])
	for a: Vector3 in WorldLayout.algae_spots():
		if _near.is_empty() and pos.distance_to(a) < 3.5 and _raid == null:
			_near = "algae"
	_step_guards(me)
	_step_police(me, match_node.get_process_delta_time())
	_step_homes(me, match_node.get_process_delta_time())
	for bunk: Array in WorldLayout.bunks():
		if _near.is_empty() and pos.distance_to(bunk[0]) < REACH + 1.0:
			_near = "bunk"
	if _near.is_empty() and me.state.vehicle < 0:
		var ci := Profile.career().cache_at(pos)
		if ci >= 0:
			_near = "cache:%d" % ci
	if _near.is_empty() and pos.distance_to(TitanSettlement.air_station()) < REACH + 0.5:
		_near = "air_refill"
	var job: Dictionary = Profile.career().d.job
	if not job.is_empty() and WorldLayout.job_sites().has(job.id):
		var site: Array = WorldLayout.job_sites()[job.id]
		var there := Vector2(pos.x - (site[0] as Vector3).x, pos.z - (site[0] as Vector3).z).length() < float(site[1])
		if there and Career.JOBS[job.id].get("vehicle", false):
			if me.state.vehicle >= 0:  # a drive: done the moment you pull in
				var done := Profile.career().finish_job()
				Profile.save()
				if not done.is_empty():
					_flash_text(tr("CITY_JOB_DONE") % done.pay, ComicUI.GREEN)
		elif there and _near.is_empty():
			_near = "job_" + str(job.id)
	if _near.is_empty() and me.state.vehicle < 0 and pos.distance_to(WorldLayout.showroom_spot()) < 2.6:
		_near = "showroom"
	if estate == null:
		estate = CityEstate.new(self)
	var _t_estate := Time.get_ticks_usec()
	var estate_near := estate.update(me, _panels_open())
	Diagnostics.time_section("estate", _t_estate)
	if _near.is_empty() or (_near == "exit_rover" and estate_near.is_empty()):
		if not estate_near.is_empty():
			_near = estate_near
	if bounty == null:
		bounty = CityBounty.new(self)
	var _t_bounty := Time.get_ticks_usec()
	var bounty_near := bounty.update(me, _panels_open())
	Diagnostics.time_section("bounty", _t_bounty)
	if _near.is_empty() and not bounty_near.is_empty():
		_near = bounty_near
	if trade == null:
		trade = CityTrade.new(self)
	var _t_trade := Time.get_ticks_usec()
	var trade_near := trade.update(me, _panels_open())
	Diagnostics.time_section("trade", _t_trade)
	if _near.is_empty() and not trade_near.is_empty():
		_near = trade_near
	if events == null:
		events = CityEvents.new(self)
	var _t_event := Time.get_ticks_usec()
	var event_near := events.update(me, _panels_open())
	Diagnostics.time_section("events", _t_event)
	if _near.is_empty() and not event_near.is_empty():
		_near = event_near
	if heist == null:
		heist = CityHeist.new(self)
	var _t_heist := Time.get_ticks_usec()
	var heist_near := heist.update(me, _panels_open())
	Diagnostics.time_section("heist", _t_heist)
	if (_near.is_empty() or _near == "exit_rover") and not heist_near.is_empty():
		_near = heist_near
	var _t_social := Time.get_ticks_usec()
	var social_near := social.update(me, _panels_open())
	Diagnostics.time_section("social", _t_social)
	if _near.is_empty() and not social_near.is_empty():
		_near = social_near
	marsnet_button.visible = not _panels_open()
	style_button.visible = not _panels_open()
	style.apply()
	burner_button.visible = Profile.career().chain_step() >= 1 and not (_panels_open())
	var c := Profile.career()
	_hollow_sign.text = tr("WORLD_HOLLOW") + "\n" + (tr("WORLD_HOLLOW_SIGN_YOURS") if c.owns_hollow() else tr("WORLD_HOLLOW_SIGN_THARSIS"))
	_hollow_sign.modulate = ComicUI.GREEN if c.owns_hollow() else ComicUI.CYAN
	# A shelf is never a trap: hit, or dead, and it shuts so you can move.
	var vit := me.state.health + me.state.shield
	if shelf.visible and (not me.state.alive or vit < _shelf_vit - 0.5):
		shelf.close()
	_shelf_vit = vit
	var busy := _panels_open()
	if not busy and not match_node.input.enabled:
		_close_talk()  # nothing open: the controls are yours again
	match_node.touch.show_interact = not _near.is_empty() and not busy
	pack_button.visible = not busy
	var quick := _quick_label()
	quick_button.visible = not busy and not quick.is_empty()
	quick_button.text = quick
	_step_gadgets(me, busy)
	_sync_kit(me)
	_step_gear(me, busy)
	var food := _food()
	eat_button.visible = not busy and not food.is_empty() and me.state.alive
	eat_button.text = tr("CITY_EAT") % int(Profile.career().d.stash.get(food, 0)) if not food.is_empty() else ""
	var drink := _drink()
	drink_button.visible = not busy and not drink.is_empty() and me.state.alive
	drink_button.text = tr("CITY_DRINK") % int(Profile.career().d.stash.get(drink, 0)) if not drink.is_empty() else ""
	var h_down := Input.is_physical_key_pressed(KEY_H)
	if h_down and not _h_was_down and not busy:
		quick_use()
	_h_was_down = h_down
	hud_layer.visible = not shelf.visible
	var i_down := Input.is_physical_key_pressed(KEY_I) or Input.is_physical_key_pressed(KEY_TAB)
	if i_down and not _i_was_down and not busy:
		open_pack()
	_i_was_down = i_down
	var presses: int = match_node.input.press_count(PlayerCommand.Action.INTERACT)
	if _last_press >= 0 and presses != _last_press and not busy:
		if _near.begins_with("shop:") or _near.begins_with("hold:") or _near.begins_with("drop:") \
				or _near.begins_with("holdup:") or _near.begins_with("home:"):
			_use_goods(me)
		elif _near.begins_with("estate:"):
			estate.act(_near, me)
		elif _near == "bounty:board":
			bounty.open_board()
		elif _near.begins_with("trade:"):
			trade.act(_near, me)
		elif _near.begins_with("event:"):
			events.act(_near, me)
		elif _near.begins_with("heist:"):
			heist.act(_near, me)
		elif _near.begins_with("social:"):
			social.act(_near, me)
		elif _near == "bounty:ask":
			bounty.ask(me)
		elif _near.begins_with("kiosk:"):
			open_terminal(_near.substr(6))
		elif _near == "showroom":
			_open_motors()
		elif _near.begins_with("closed:"):
			pass  # the shutters are down
		elif _near == "deploy":
			deploy()
		elif _near == "rover" or _near == "exit_rover":
			pass  # the simulation boards and leaves rovers (VehicleSim)
		elif Career.PEOPLE.has(_near):
			_open_talk(_near)
		elif _near == "lift_down":
			_bake_farm()
			match_node.server.world.teleport(me, WorldLayout.lift_bottom())
			_note(tr("CITY_LIFT_DOWN"), ComicUI.CYAN)
		elif _near == "lift_up":
			match_node.server.world.teleport(me, WorldLayout.lift_top() + Vector3(0, 0.4, 4.5))
			if _guards != null:  # up the shaft with the goods: they don't follow
				_guards.finish()
				_guards = null
				_set_armed(false)
				_note(tr("CITY_THEFT_ESCAPED"), ComicUI.GREEN)
		elif _near.begins_with("loot:"):
			_search(_near.substr(5))
		elif _near == "algae":
			_bake_farm()
			Profile.career().steal_algae(2)
			Profile.save()
			_guards = RaidDirector.new(match_node.server)
			_guard_kind = "farm"
			_guards.start_guards(me.net_id, WorldLayout.guard_posts())
			crime("theft")
			_set_armed(true)
			_note(tr("CITY_THEFT_ALARM"), ComicUI.RED)
		elif _near.begins_with("rig_") and _rig < 0:
			var i := int(_near.substr(4))
			var wait := Profile.career().rig_wait(WorldLayout.RIGS[i][0], int(Time.get_unix_time_from_system()))
			if wait > 0:
				_note(tr("CITY_RIG_COOLING") % wait, ComicUI.YELLOW)
			else:
				_rig = i
				_rig_t = 0.0
		elif _near.begins_with("cache:"):
			var ci := int(_near.substr(6))
			if ci < Profile.career().d.caches.size():
				_open_shelf({"mode": "cache", "title": tr("SHELF_CACHE_TITLE"), "right": Profile.career().d.caches[ci].items, "cache": ci})
		elif _near == "air_refill":
			# EX-03's filling station: a full air canister for your suit.
			if me.state.o2_spares >= AIR_CANISTERS_MAX:
				_note(tr("TITAN_AIR_FULL"), ComicUI.YELLOW)
			elif Profile.career().pay(AIR_CANISTER_PRICE):
				me.state.o2_spares += 1
				Profile.save()
				match_node.audio.play_ui("pickup", -4.0)
				_note(tr("TITAN_AIR_FILLED") % [me.state.o2_spares, AIR_CANISTERS_MAX], ComicUI.CYAN)
			else:
				_note(tr("TITAN_AIR_BROKE") % AIR_CANISTER_PRICE, ComicUI.RED)
		elif _near == "bunk":
			Profile.career().rest()
			me.state.fatigue = 0.0
			Profile.save()
			_note(tr("CITY_SLEPT"), ComicUI.CYAN)
		elif _near.begins_with("job_"):
			var done := Profile.career().finish_job()
			Profile.save()
			if not done.is_empty():
				_note(tr("CITY_JOB_DONE") % done.pay, ComicUI.GREEN)
	_last_press = presses


## Traffic on the valley's roads (presentation only): rovers, buggies and
## haulers keeping right, turning back short of the road's ends, and
## stopping for you (on foot or driving) in the way.
const TRAFFIC := 12
const TRAFFIC_SPEED := 13.0
var _traffic: Array = []  ## [mesh, road points, distance along, direction, speed, blocked s, honk cooldown, wheels, wheel turn]


func _step_traffic(me: SimPlayer, dt: float) -> void:
	if _traffic.is_empty():
		var sky := SkyTraffic.new()  # the rotorcraft in the sky
		sky.name = "SkyTraffic"
		match_node.add_child(sky)
		# Traffic keeps to the long roads (a short street has no room to turn back).
		var roads := WorldLayout.roads().filter(func(r: Array) -> bool: return WorldLayout.road_samples(r, 2.0).size() > 80)
		for k in TRAFFIC:
			var pts: Array = []
			for sample: Array in WorldLayout.road_samples(roads[k % roads.size()], 2.0):
				pts.append(sample[0])
			var ground_models := range(VehicleSim.MODELS.size()).filter(func(i: int) -> bool: return not VehicleSim.flies(i))
			var kit: String = VehicleSim.MODELS[ground_models[k % ground_models.size()]].kit  # no aircraft on the roads
			var mi := Comic.kit_instance(kit, Vector3.ZERO, 0.0)
			mi.visibility_range_end = 220.0  # traffic: not drawn across the valley
			match_node.add_child(mi)
			var wheels := RoverVisuals.add_wheels(mi, kit)
			_traffic.append([mi, pts, 30.0 + float(k * 53 % maxi(pts.size() * 2 - 60, 1)), 1.0 if k % 2 == 0 else -1.0, TRAFFIC_SPEED,
					0.0, 0.0, wheels, 0.0])
	var me_pos := me.state.position
	for t: Array in _traffic:
		var pts: Array = t[1]
		var length := (pts.size() - 1) * 2.0
		var d: float = t[2]
		var dir: float = t[3]
		var here := _along(pts, d)
		var ahead := _along(pts, d + dir * 2.0)
		var fwd := Vector3(ahead.x - here.x, 0, ahead.y - here.y).normalized()
		var right := Vector3(-fwd.z, 0, fwd.x)
		var at := WorldTerrain.at(here.x, here.y) + right * 2.4
		# Someone in the road ahead: brake.
		var to := me_pos - at
		var blocked := to.length() < 12.0 and fwd.dot(to.normalized()) > 0.6
		t[4] = move_toward(t[4], 0.0 if blocked else TRAFFIC_SPEED, dt * (14.0 if blocked else 4.0))
		# The wheels roll with the road.
		t[8] = fmod(float(t[8]) - float(t[4]) * dt / 0.6, TAU)
		for w: Array in t[7]:
			(w[2] as Node3D).rotation.x = t[8]
		# Stuck behind you: the horn, and a word from the cab.
		t[5] = float(t[5]) + dt if blocked else 0.0
		t[6] = maxf(float(t[6]) - dt, 0.0)
		if float(t[5]) > 0.7 and float(t[6]) <= 0.0:
			t[6] = 5.0
			_honk(t[0])
		d += dir * float(t[4]) * dt
		if d > length - 30.0 or d < 30.0:  # turn back short of the ends
			t[3] = -dir
			d = clampf(d, 30.0, length - 30.0)
		t[2] = d
		var mi: MeshInstance3D = t[0]
		var up := RoverVisuals.ground_normal(at.x, at.z)
		var r := fwd.cross(up).normalized()
		var basis := Basis(r, up, -up.cross(r).normalized())
		mi.basis = mi.basis.orthonormalized().slerp(basis, minf(dt * 8.0, 1.0))
		mi.position = at


func _honk(car: Node3D) -> void:
	var horn := AudioStreamPlayer3D.new()
	horn.stream = load("res://audio/generated/honk.wav")
	horn.unit_size = 10.0
	car.add_child(horn)
	horn.play()
	horn.finished.connect(horn.queue_free)
	if _people != null:
		_people.say(car, CityNpcs._line("BOT_BARK_HONK"), true)


static func _along(pts: Array, d: float) -> Vector2:
	var i := clampi(int(d / 2.0), 0, pts.size() - 2)
	return (pts[i] as Vector2).lerp(pts[i + 1], clampf(d / 2.0 - i, 0.0, 1.0))


## Kasei Motors' line: robot arms (yellow, three joints) swing and weld
## with sparks over the rovers creeping down the line (rover, buggy, hauler).
var _arms: Array = []         ## [base Node3D, shoulder, elbow, phase]
var _line_cars: Array[MeshInstance3D] = []
var _factory_t: float = 0.0


func _animate_factory(delta: float) -> void:
	var me: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	if me == null or me.state.position.distance_to(WorldLayout.factory_at(Vector3.ZERO)) > 140.0:
		return  # nobody to see it: no work
	_factory_t += delta
	if _arms.is_empty():
		var yellow := Color(0.95, 0.7, 0.08)
		for i in WorldLayout.FACTORY_ARMS.size():
			var a: Vector2 = WorldLayout.FACTORY_ARMS[i]
			var base := Node3D.new()
			base.position = WorldLayout.factory_at(Vector3(a.x, 0.0, a.y))
			base.rotation.y = PI * 0.5 if a.x < 0.0 else -PI * 0.5  # facing the line
			match_node.add_child(base)
			base.add_child(_part(CylinderMesh.new(), Vector3(0.9, 0.7, 0.9), Vector3(0, 0.35, 0), Color(0.2, 0.2, 0.22)))
			var shoulder := Node3D.new()
			shoulder.position.y = 0.8
			base.add_child(shoulder)
			shoulder.add_child(_part(BoxMesh.new(), Vector3(0.45, 2.2, 0.45), Vector3(0, 1.1, 0), yellow))
			var elbow := Node3D.new()
			elbow.position.y = 2.2
			shoulder.add_child(elbow)
			elbow.add_child(_part(BoxMesh.new(), Vector3(0.35, 1.8, 0.35), Vector3(0, 0.9, 0), yellow))
			elbow.add_child(_part(CylinderMesh.new(), Vector3(0.25, 0.4, 0.25), Vector3(0, 1.9, 0), Color(0.15, 0.15, 0.17)))
			var sparks := GPUParticles3D.new()
			var pm := ParticleProcessMaterial.new()
			pm.direction = Vector3(0, 1, 0)
			pm.spread = 80.0
			pm.initial_velocity_min = 1.5
			pm.initial_velocity_max = 4.0
			pm.gravity = Vector3(0, -3.72, 0)
			pm.scale_min = 0.05
			pm.scale_max = 0.1
			sparks.process_material = pm
			var q := QuadMesh.new()
			q.size = Vector2(0.12, 0.12)
			var qm := StandardMaterial3D.new()
			qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			qm.albedo_color = Color(1.0, 0.85, 0.4)
			q.material = qm
			sparks.draw_pass_1 = q
			sparks.amount = 24
			sparks.lifetime = 0.5
			sparks.position.y = 2.1
			elbow.add_child(sparks)
			_arms.append([base, shoulder, elbow, float(i) * 1.3, sparks])
		for k in 3:
			var car := MeshInstance3D.new()
			car.mesh = Comic.kit_mesh_lod(VehicleSim.MODELS[k].kit)
			car.material_override = Comic.kit_material()
			RoverVisuals.add_wheels(car, VehicleSim.MODELS[k].kit)
			match_node.add_child(car)
			_line_cars.append(car)
	for arm: Array in _arms:
		var t: float = _factory_t * 1.4 + float(arm[3])
		(arm[1] as Node3D).rotation.x = -0.5 + 0.35 * sin(t)
		(arm[2] as Node3D).rotation.x = -1.1 + 0.45 * sin(t * 1.3 + 1.0)
		(arm[0] as Node3D).rotation.y += sin(t * 0.7) * delta * 0.4
		(arm[4] as GPUParticles3D).emitting = sin(t * 2.0) > 0.2  # welding in bursts
	for k in _line_cars.size():
		var z := 18.0 - fmod(_factory_t * 0.8 + k * 12.0, 36.0)  # creeping down the line
		_line_cars[k].position = WorldLayout.factory_at(Vector3(0, 0.35, z))


func _part(mesh: PrimitiveMesh, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = size.x * 0.5
		(mesh as CylinderMesh).bottom_radius = size.x * 0.5
		(mesh as CylinderMesh).height = size.y
	mi.mesh = _tinted(mesh, color)
	mi.material_override = Comic.kit_material(0.01)
	mi.position = at
	return mi


## The drill rigs at work: each auger turns slowly at idle and fast (with a
## bob, ore dust and the drill's roar) while you run a shift there.
func _animate_rigs(delta: float) -> void:
	if _augers.is_empty():
		for i in WorldLayout.RIGS.size():
			var auger := Node3D.new()
			auger.position = WorldLayout.rig_spot(i) + Vector3(0, 0.2, 0)
			var shaft := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.25
			cyl.bottom_radius = 0.25
			cyl.height = 8.6
			cyl.radial_segments = 8
			shaft.mesh = _tinted(cyl, Color(0.22, 0.2, 0.24))
			shaft.position.y = 4.4
			shaft.material_override = Comic.kit_material(0.01)
			auger.add_child(shaft)
			for k in 8:  # a helical flight up the bit
				var blade := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = Vector3(0.9, 0.08, 0.22)
				blade.mesh = b
				blade.position = Vector3(0, 0.4 + k * 0.32, 0)
				blade.rotation.y = k * PI / 4.0
				blade.rotation.z = 0.35
				var m := StandardMaterial3D.new()
				m.albedo_color = Color(0.85, 0.7, 0.2)
				m.metallic = 0.7
				blade.material_override = m
				auger.add_child(blade)
			var motor := MeshInstance3D.new()
			var mb := BoxMesh.new()
			mb.size = Vector3(1.6, 1.4, 1.6)
			motor.mesh = _tinted(mb, Color(0.62, 0.56, 0.5))
			motor.position.y = 7.6
			motor.material_override = Comic.kit_material(0.01)
			auger.add_child(motor)
			match_node.add_child(auger)
			_augers.append(auger)
		_drill_sound = AudioStreamPlayer3D.new()
		_drill_sound.stream = DustStorms.looping("res://audio/generated/drill_loop.wav")
		_drill_sound.unit_size = 8.0
		_drill_sound.max_distance = 70.0
		match_node.add_child(_drill_sound)
		_dust = GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 70.0
		pm.initial_velocity_min = 1.5
		pm.initial_velocity_max = 4.0
		pm.gravity = Vector3(0, -3.72, 0)
		pm.scale_min = 0.15
		pm.scale_max = 0.4
		pm.color = Color(0.72, 0.36, 0.2)
		_dust.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.4, 0.4)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.vertex_color_use_as_albedo = true
		qm.albedo_color = Color(0.72, 0.38, 0.22)
		q.material = qm
		_dust.draw_pass_1 = q
		_dust.amount = 48
		_dust.lifetime = 1.2
		_dust.emitting = false
		match_node.add_child(_dust)
	for i in _augers.size():
		var working := i == _rig
		var a := _augers[i]
		a.rotate_y(delta * (16.0 if working else 1.2))
		var base := WorldLayout.rig_spot(i).y + 0.2
		a.position.y = base - (0.18 * absf(sin(_rig_t * 9.0)) if working else 0.0)
	var on := _rig >= 0
	if on and not _drill_sound.playing:
		_drill_sound.global_position = WorldLayout.rig_spot(_rig) + Vector3(0, 2, 0)
		_dust.global_position = WorldLayout.rig_spot(_rig) + Vector3(0, 0.4, 0)
		_drill_sound.play()
	elif not on and _drill_sound.playing:
		_drill_sound.stop()
	_dust.emitting = on


## The farm's navmesh, baked the first time it's needed (the Hollow's is
## baked at load; baking both up front was slow on weaker phones).
func _bake_farm() -> void:
	var nav: BotNavigation = match_node.server.bot_nav
	if nav != null and not nav.has_area("farm"):
		var gameplay: Node3D = match_node.world_gameplay
		if gameplay != null:
			var ms := nav.add_area("farm", gameplay, WorldLayout.farm_nav_area())
			print("Deep Furrow navmesh baked in %d ms" % ms)


## A primitive mesh with one vertex colour, for the comic kit shader.
static func _tinted(mesh: PrimitiveMesh, c: Color) -> ArrayMesh:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	colors.fill(c.srgb_to_linear())
	arrays[Mesh.ARRAY_COLOR] = colors
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Small things (props, arms, augers, sparks, pickups, signs) are drawn to
## SMALL_RANGE at most: on phones each is a draw call or two, and from 500 m
## they're a pixel. The world's own pieces have their view distances
## (StaticBatches) and people theirs (CityNpcs), so they're left alone.
## EX-03's air: a canister for the suit, up to the most you can carry.
const AIR_CANISTER_PRICE := 20
const AIR_CANISTERS_MAX := 3


## The settlements' police, the SALTS: their officers' names start so.
const POLICE := "SALTS·"
const SMALL_RANGE := 180.0
const SMALL_SIZE := 12.0


func _draw_distance(n: Node) -> void:
	var gi := n as GeometryInstance3D
	if gi == null or gi.visibility_range_end > 0.0 or not match_node.is_ancestor_of(gi):
		return
	var p: Node = gi.get_parent()
	while p != null and p != match_node:
		if p is PlayerVisual or p.name == &"Presentation" or p.name == &"WorldPresentation":
			return
		p = p.get_parent()
	var box := gi.get_aabb()
	if gi is GPUParticles3D:
		box = (gi as GPUParticles3D).visibility_aabb
	if box.get_longest_axis_size() * maxf(absf(gi.scale.x), maxf(absf(gi.scale.y), absf(gi.scale.z))) < SMALL_SIZE:
		gi.visibility_range_end = SMALL_RANGE
		gi.visibility_range_end_margin = 10.0


## A pedestrian run down: in a lawful district, the SALTS want you.
func _on_run_down(_at: Vector3) -> void:
	if region in WorldLayout.LAWFUL:
		crime("assault")


## A crime the Marshals saw: stars, and officers on the way.
func crime(kind: String) -> void:
	var before := wanted.stars
	wanted.commit(kind, Profile.career().masked())
	if estate != null:
		estate.on_crime()
	if wanted.stars > before:
		_flash_text(tr("CITY_WANTED") % wanted.stars, ComicUI.RED)
		match_node.audio.play_ui("shield_break", -2.0)


## Fights still going on keep weapons out and damage on; none, and the
## valley is peaceful again.
## A fight on: a raid, guards after you, the Marshals, or a bounty gone hot.
func in_fight() -> bool:
	return _raid != null or _guards != null or _police != null or (bounty != null and bounty.hot) \
			or (trade != null and trade.in_fight()) or (events != null and events.in_fight()) \
			or (heist != null and heist.in_fight())


func _sync_combat() -> void:
	var fighting := in_fight()
	var world: SimWorld = match_node.server.world
	world.teams_enabled = fighting
	world.damage_enabled = fighting
	_set_armed(fighting or drawn)


## Gun out or away, anywhere (in town drawing it alarms people; firing it
## brings the Marshals).
func toggle_drawn() -> void:
	drawn = not drawn
	_sync_combat()


## Any of the city's panels open (the controls are theirs).
func _panels_open() -> bool:
	return screen.visible or talk.visible or shelf.visible or garage.visible or (social != null and social.panel.visible)


## A line on MarsNet about what just happened (and fame for it).
func news(key: String, args: Array, fame: int) -> void:
	var before := Profile.career().season_tier()
	if social != null:
		social.news(key, args, fame)
	if Profile.career().season_tier() > before:
		_flash_text(tr("STYLE_TIER_UP") % Profile.career().season_tier(), ComicUI.YELLOW)


func _open_burner() -> void:
	if trade != null:
		trade.open_burner()


func toggle_torch() -> void:
	torch_on = not torch_on


## Your gear and how the valley sees you: the torch's beam, the jetpack's
## flame and roar, people freezing when you point a gun at them.
func _step_gear(me: SimPlayer, busy: bool) -> void:
	var c := Profile.career()
	var fighting := in_fight()
	draw_button.visible = not busy and me.state.alive and me.state.vehicle < 0 and not fighting
	draw_button.text = tr("CITY_HOLSTER") if drawn else tr("CITY_DRAW")
	match_node.hud.show_crosshair = fighting or drawn
	var has_torch := int(c.d.stash.get("torch", 0)) > 0
	torch_button.visible = not busy and has_torch
	torch_button.text = tr("CITY_TORCH_OFF") if torch_on else tr("CITY_TORCH")
	var g_down := Input.is_physical_key_pressed(KEY_G)
	if g_down and not _g_was_down and draw_button.visible:
		toggle_drawn()
	_g_was_down = g_down
	var t_down := Input.is_physical_key_pressed(KEY_T)
	if t_down and not _t_was_down and torch_button.visible:
		toggle_torch()
	_t_was_down = t_down
	if not has_torch:
		torch_on = false
	var night := hour() < 6.0 or hour() > 19.5
	if night and has_torch and not torch_on and not _night_hint:
		_night_hint = true
		_note(tr("CITY_NIGHT_TORCH"), ComicUI.PAPER)
	# The torch: a beam from your helmet where you look.
	if _torch == null:
		_torch = SpotLight3D.new()
		_torch.spot_range = 40.0
		_torch.spot_angle = 30.0
		_torch.spot_attenuation = 0.6
		_torch.light_energy = 12.0
		_torch.light_color = Color(1.0, 0.95, 0.85)
		_torch.shadow_enabled = false
		match_node.add_child(_torch)
	_torch.visible = torch_on and me.state.alive
	if _torch.visible:
		var look := Basis.from_euler(Vector3(me.state.pitch, me.state.yaw, 0.0))
		_torch.global_transform = Transform3D(look, me.state.position + Vector3(0, 1.62, 0) + look * Vector3(0, 0, -0.35))
	# The jetpack: carried if it's in your pack; flame and roar while it fires.
	me.state.jetpack = int(c.d.stash.get("jetpack", 0)) > 0
	var firing := me.state.jetpack and not me.state.is_on_floor() and me.state.jet_fuel < _last_fuel - 0.001
	_last_fuel = me.state.jet_fuel
	if _jet_fx == null:
		_jet_fx = GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, -1, 0)
		pm.spread = 12.0
		pm.initial_velocity_min = 4.0
		pm.initial_velocity_max = 7.0
		pm.scale_min = 0.12
		pm.scale_max = 0.3
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.8, 0.4, 1.0))
		ramp.set_color(1, Color(1.0, 0.35, 0.1, 0.0))
		var rt := GradientTexture1D.new()
		rt.gradient = ramp
		pm.color_ramp = rt
		_jet_fx.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.35, 0.35)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.vertex_color_use_as_albedo = true
		var puff := Gradient.new()
		puff.set_color(0, Color(1, 1, 1, 1))
		puff.set_color(1, Color(1, 1, 1, 0))
		var pt := GradientTexture2D.new()
		pt.gradient = puff
		pt.fill = GradientTexture2D.FILL_RADIAL
		pt.fill_from = Vector2(0.5, 0.5)
		pt.fill_to = Vector2(0.5, 0.0)
		pt.width = 64
		pt.height = 64
		qm.albedo_texture = pt
		q.material = qm
		_jet_fx.draw_pass_1 = q
		_jet_fx.amount = 40
		_jet_fx.lifetime = 0.35
		match_node.add_child(_jet_fx)
		_jet_sound = AudioStreamPlayer3D.new()
		_jet_sound.stream = DustStorms.looping("res://audio/generated/jet_loop.wav")
		_jet_sound.unit_size = 6.0
		match_node.add_child(_jet_sound)
	_jet_fx.emitting = firing
	var back := Vector3(sin(me.state.yaw), 0, cos(me.state.yaw)) * 0.45
	_jet_fx.global_position = me.state.position + Vector3(0, 1.0, 0) + back
	_jet_sound.global_position = _jet_fx.global_position
	if firing and not _jet_sound.playing:
		_jet_sound.play()
	elif not firing and _jet_sound.playing:
		_jet_sound.stop()
	# A gun pointed at people: they freeze.
	if drawn and me.state.alive and _people != null:
		var aim := Basis.from_euler(Vector3(me.state.pitch, me.state.yaw, 0.0)) * Vector3(0, 0, -1)
		_people.aimed(me.state.position + Vector3(0, 1.5, 0), aim)
	# Lines waiting for a fighter's body to be made.
	for id: int in _pending_says.keys():
		var v: PlayerVisual = match_node._visuals.get(id)
		if v != null and _people != null:
			_people.say(v, _pending_says[id], true)
			_pending_says.erase(id)


## The match's events, as the valley sees them: shots send people running
## (and in town, yours are a crime), fighters call out, take hits, lose men.
func on_event(e: Dictionary) -> void:
	var world: SimWorld = match_node.server.world if match_node.server != null else null
	if world == null:
		return
	var me := ServerSession.LOCAL_PLAYER_ID
	match e.type:
		"fire":
			if _people != null:
				_people.threat(e.origin, 40.0)
			var fighting := in_fight()
			if int(e.shooter) == me and not fighting and region in WorldLayout.LAWFUL and not (bounty != null and bounty.hot):
				crime("shots")
			elif int(e.shooter) in _hostiles() and not _contacted.has(int(e.shooter)):
				_contacted[int(e.shooter)] = true
				_bark(int(e.shooter), "BOT_BARK_CONTACT")
		"hit":
			if int(e.target) in _hostiles() and randf() < 0.4:
				_bark(int(e.target), "BOT_BARK_HIT")
		"death":
			var victim := int(e.victim)
			if victim in _hostiles():
				for id: int in _hostiles():
					var p: SimPlayer = world.players.get(id)
					if id != victim and p != null and p.state.alive:
						_bark(id, "BOT_BARK_DOWN")
						break
			elif victim == me:
				for id: int in _hostiles():
					var p: SimPlayer = world.players.get(id)
					if p != null and p.state.alive:
						_bark(id, "BOT_BARK_WIN")
						break


func _bark(id: int, key: String) -> void:
	var v: PlayerVisual = match_node._visuals.get(id)
	if v != null and _people != null:
		_people.say(v, CityNpcs._line(key))
	else:
		_pending_says[id] = CityNpcs._line(key)


## The Marshals' chase: officers come (more with more stars) from out of
## sight around you; out of their sight long enough and they lose you; put
## an officer down and it gets worse; fall and they fine you.
func _step_police(me: SimPlayer, dt: float) -> void:
	var server: ServerSession = match_node.server
	var world: SimWorld = server.world
	# Taking a Concern rover is theft too.
	if me.state.vehicle >= 0 and me.state.vehicle < world.vehicles.size() and world.vehicles[me.state.vehicle].owner < 0:
		if _rover_crime != me.state.vehicle:
			_rover_crime = me.state.vehicle
			crime("rover")
	elif me.state.vehicle < 0:
		_rover_crime = -1
	if wanted.stars == 0:
		_police_seen = false
		if _police != null:
			_police.finish()
			_police = null
			_sync_combat()
		_was_alive = me.state.alive
		return
	if _police == null:
		_police = RaidDirector.new(server)
		_police_down = 0
		_police_spawn_t = 0.0
		_police.raiders.clear()
		_sync_combat()
	var state := _police.step()
	# Fell while wanted: the Marshals take their fine and what's illegal.
	if not me.state.alive and _was_alive:
		var fine := Profile.career().busted()
		Profile.save()
		wanted.clear()
		_flash_text(tr("CITY_BUSTED") % fine, ComicUI.RED)
		_police.finish()
		_police = null
		_sync_combat()
		_was_alive = false
		return
	_was_alive = me.state.alive
	var down := 0
	for id: int in _police.raiders:
		var p: SimPlayer = world.players.get(id)
		if p != null and not p.state.alive:
			down += 1
	if down > _police_down:
		for i in down - _police_down:
			crime("officer_down")
		_police_down = down
	# Reinforcements, one at a time, out of sight around you.
	_police_spawn_t -= dt
	if state != 2 and _police.raiders_left() < wanted.officers() and _police_spawn_t <= 0.0 \
			and server.bot_nav != null and server.bot_nav.ready_for_queries:
		_police_spawn_t = 3.0
		_bake_around(me.state.position)
		var angle := randf() * TAU
		var at := me.state.position + Vector3(cos(angle), 0, sin(angle)) * 42.0
		at = WorldTerrain.at(at.x, at.z) if region != "farm" else WorldLayout.farm_origin() + Vector3(0, 0.3, 24)
		if region == "city":
			at.y = CityLayout.ORIGIN.y
		_police.start_guards(me.net_id, [at], "marshal", CityMode.POLICE + "%d", _police.raiders.size() + 1)
		_pending_says[_police.raiders.back()] = CityNpcs._line("BOT_BARK_MARSHAL")
		if _police.militia.is_empty() and estate != null:
			estate.crew_join(_police, me)  # your gang stands with you
	# Seen? An officer near with a clear line to you.
	var seen := false
	var space: PhysicsDirectSpaceState3D = match_node.get_world_3d().direct_space_state
	for id: int in _police.raiders:
		var p: SimPlayer = world.players.get(id)
		if p == null or not p.state.alive:
			continue
		var d := p.state.position.distance_to(me.state.position)
		if d < 55.0:
			var q := PhysicsRayQueryParameters3D.create(p.state.position + Vector3(0, 1.6, 0),
					me.state.position + Vector3(0, 1.2, 0), Sim.LAYER_WORLD)
			if space.intersect_ray(q).is_empty():
				seen = true
				break
	if int(Profile.career().d.stash.get("ring_bonds", 0)) > 0:
		seen = true  # the Ring's bonds are tagged: they track you till you're clear
	_police_seen = seen
	if wanted.step(dt, seen):
		_flash_text(tr("CITY_LOST_THEM"), ComicUI.GREEN)


## Bakes the navmesh around `pos` (an 120 m cell, once) so officers can
## find their way through streets and buildings there.
func _bake_around(pos: Vector3) -> void:
	var nav: BotNavigation = match_node.server.bot_nav
	var gameplay: Node3D = match_node.world_gameplay
	if nav == null or gameplay == null or region == "farm":
		return
	var cell := Vector2i(floori(pos.x / 120.0), floori(pos.z / 120.0))
	var key := "chase_%d_%d" % [cell.x, cell.y]
	if _nav_chunks.has(key):
		return
	_nav_chunks[key] = true
	var origin := Vector3(cell.x * 120.0 - 20.0, pos.y - 40.0, cell.y * 120.0 - 20.0)
	var ms := nav.add_area(key, gameplay, AABB(origin, Vector3(160.0, 80.0, 160.0)))
	print("Marshals' navmesh %s baked in %d ms" % [key, ms])


## Residences: your locker (and while you were away, did anyone get in?),
## the lockers in other people's habs and the lock you're working on one.
func _step_homes(me: SimPlayer, dt: float) -> void:
	var c := Profile.career()
	if not _homes_built:
		_homes_built = true
		for home: Array in WorldLayout.residences():
			_locker_mark(home)
	if not _home_checked and me.state.alive:
		_home_checked = true
		var rolls := [randf(), randf(), randf()]
		var taken := c.burglary(int(Time.get_unix_time_from_system()), rolls)
		Profile.save()
		if not taken.is_empty():
			var parts := PackedStringArray()
			for item: String in taken:
				parts.append("%d× %s" % [taken[item], Career.ITEMS[item].name])
			_flash_text(tr("CITY_HOME_ROBBED") % ", ".join(parts), ComicUI.RED)
	if _breakin < 0:
		return
	if _near != "home:%d" % _breakin or not me.state.alive:
		_breakin = -1  # walked off: the lock holds
		return
	_breakin_t += dt
	if _breakin_t < _breakin_seconds():
		return
	var home: Array = WorldLayout.residences()[_breakin]
	_breakin = -1
	if _breakin_tool == "lockpick":
		c.use_up("lockpick")  # a pick snaps in every lock
	var got := c.break_in(str(home[0]), [randf(), randf()], int(Time.get_unix_time_from_system()))
	Profile.save()
	if region in WorldLayout.LAWFUL:
		crime(Career.BREAK_TOOLS[_breakin_tool][1])  # the neighbours heard (a crowbar's loud)
	if got.is_empty():
		_note(tr("CITY_HOME_BARE"), ComicUI.YELLOW)
		return
	# The open locker's goods stay there for the taking (a hit that shuts
	# the shelf doesn't lose them): searchable like a dropped pack.
	var world: SimWorld = match_node.server.world
	world.drops.append({"id": 100000 + world.tick, "position": home[1], "name": home[2], "label": tr("SHELF_HOME_OF") % home[2],
			"items": got, "until": world.tick + int(Robbery.DROP_SECONDS * Sim.TICK_RATE)})
	_open_shelf({"mode": "loot", "title": tr("SHELF_HOME_OF") % home[2], "right": got})


## A locker cabinet inside a residence, and a sign on yours.
func _locker_mark(home: Array) -> void:
	var cab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 2.0, 0.6)
	var yours := str(home[2]).is_empty()
	cab.mesh = _tinted(box, Color(0.25, 0.55, 0.6) if yours else Color(0.45, 0.4, 0.38))
	cab.material_override = Comic.kit_material(0.01)
	cab.position = (home[1] as Vector3) + Vector3(0, 1.0, 0)
	cab.visibility_range_end = 40.0  # it's indoors
	match_node.add_child(cab)
	var sign := Label3D.new()
	sign.text = tr("CITY_YOUR_HOME") if yours else tr("CITY_HOME_SIGN") % home[2]
	sign.font = UiStyle.font_hud_big
	sign.font_size = 56
	sign.pixel_size = 0.01
	sign.outline_size = 12
	sign.outline_modulate = ComicUI.INK
	sign.modulate = ComicUI.GREEN if yours else ComicUI.PAPER
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.position = (home[1] as Vector3) + Vector3(0, 2.5, 0)
	sign.visibility_range_end = 30.0  # two draws each: only near the door
	match_node.add_child(sign)


func _breakin_seconds() -> float:
	return float(Career.BREAK_TOOLS.get(_breakin_tool, [Career.BREAKIN_SECONDS])[0])


## Using kit from the pack on yourself: a medkit, an armour plate, a stim.
func use_kit(item: String) -> bool:
	var me: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	if me == null or not me.state.alive or not Career.USE.has(item):
		return false
	var c := Profile.career()
	if not c.use_up(item):
		return false
	var fx: Dictionary = Career.USE[item]
	var s := me.state
	s.health = minf(s.health + float(fx.get("health", 0.0)), Balance.PLAYER.max_health)
	s.shield = minf(s.shield + float(fx.get("shield", 0.0)), Balance.PLAYER.max_shield)
	s.stamina = minf(s.stamina + float(fx.get("stamina", 0.0)), 100.0)
	s.fatigue = clampf(s.fatigue + float(fx.get("fatigue", 0.0)), 0.0, 100.0)
	s.food = minf(s.food + float(fx.get("food", 0.0)), 100.0)
	s.water = minf(s.water + float(fx.get("water", 0.0)), 100.0)
	_sync_kit(me)
	Profile.save()
	match_node.audio.play_ui("pickup" if item != "stim_cola" else "spawn", -4.0)
	_note(tr("CITY_USED") % Career.ITEMS[item].name, ComicUI.GREEN)
	return true


## The quick-use button: heal if hurt, else top up the shield.
func quick_use() -> void:
	var me: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	if me == null:
		return
	var c := Profile.career()
	if me.state.health < Balance.PLAYER.max_health - 1.0 and int(c.d.stash.get("medkit", 0)) > 0:
		use_kit("medkit")
	elif me.state.shield < Balance.PLAYER.max_shield - 1.0 and int(c.d.stash.get("armour_plate", 0)) > 0:
		use_kit("armour_plate")
	elif me.state.food < Survival.HUNGRY and not _food().is_empty():
		use_kit(_food())
	elif int(c.d.stash.get("medkit", 0)) > 0:
		use_kit("medkit")


func _drink() -> String:
	var c := Profile.career()
	for f: String in ["water_ration", "red_ale", "stim_cola"]:
		if int(c.d.stash.get(f, 0)) > 0:
			return f
	return ""


func _eat_or_drink(eat: bool) -> void:
	var item := _food() if eat else _drink()
	if not item.is_empty():
		use_kit(item)


## The pack and the suit agree on spares: oxygen canisters, water rations
## and grenades live in both (the suit swaps them in and throws them; the
## shops and lockers change the pack). Whichever side changed since they
## last agreed wins.
const KIT_LINKS := {"oxygen_canister": "o2_spares", "water_ration": "water_spares", "frag_grenade": "grenades"}


func _sync_kit(me: SimPlayer) -> void:
	if not me.state.alive:
		return
	var c := Profile.career()
	for item: String in KIT_LINKS:
		var field: String = KIT_LINKS[item]
		var pack: int = c.d.stash.get(item, 0)
		var suit: int = me.state.get(field)
		var seen: int = _kit_seen.get(item, -1)
		if seen < 0:
			me.state.set(field, pack)  # the career's count to start
		elif pack != seen:
			me.state.set(field, pack)  # bought, found, sold, stored
		elif suit != seen:
			if suit > 0:
				c.d.stash[item] = suit  # used or thrown out there
			else:
				c.d.stash.erase(item)
		_kit_seen[item] = int(c.d.stash.get(item, 0))


## The food you'd eat first: the cheapest that fills you (save the good stuff).
func _food() -> String:
	var c := Profile.career()
	for f: String in ["meal_pack", "vat_meat", "fresh_food", "fresh_meat"]:
		if int(c.d.stash.get(f, 0)) > 0:
			return f
	return ""


func _quick_label() -> String:
	var c := Profile.career()
	var parts := PackedStringArray()
	var me: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	if me != null and me.state.food < Survival.HUNGRY and not _food().is_empty():
		parts.append(tr("CITY_QUICK_EAT") % Career.ITEMS[_food()].name)
	if int(c.d.stash.get("medkit", 0)) > 0:
		parts.append(tr("CITY_QUICK_MED") % int(c.d.stash.medkit))
	if int(c.d.stash.get("armour_plate", 0)) > 0:
		parts.append(tr("CITY_QUICK_ARMOUR") % int(c.d.stash.armour_plate))
	return " · ".join(parts)


func _side_button(accent: Color, top: float, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	ComicUI.style_button(b, accent, 24, UiStyle.font_hud_big)
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -260
	b.offset_right = -40
	b.offset_top = top
	b.offset_bottom = top + 54
	b.pressed.connect(action)
	return b


## Binoculars and the scanner (tools in the pack), and the garage's bay.
func _step_gadgets(me: SimPlayer, busy: bool) -> void:
	var c := Profile.career()
	var dt := match_node.get_process_delta_time()
	var has_bino := int(c.d.stash.get("binoculars", 0)) > 0
	var has_scan := int(c.d.stash.get("scanner", 0)) > 0
	if binocular_on and (not has_bino or busy or me.state.vehicle >= 0 or not me.state.alive):
		toggle_binoculars()
	bino_button.visible = has_bino and not busy and me.state.vehicle < 0
	bino_button.text = tr("CITY_BINOCULARS_OFF") if binocular_on else tr("CITY_BINOCULARS")
	_scan_cool = maxf(_scan_cool - dt, 0.0)
	scan_t = maxf(scan_t - dt, 0.0)
	scan_button.visible = has_scan and not busy
	scan_button.disabled = _scan_cool > 0.0
	scan_button.text = tr("CITY_SCAN_WAIT") % ceili(_scan_cool) if _scan_cool > 0.0 else tr("CITY_SCAN")
	var b_down := Input.is_physical_key_pressed(KEY_B)
	if b_down and not _b_was_down and bino_button.visible:
		toggle_binoculars()
	_b_was_down = b_down
	var n_down := Input.is_physical_key_pressed(KEY_N)
	if n_down and not _n_was_down and scan_button.visible and _scan_cool <= 0.0:
		scan()
	_n_was_down = n_down
	# The garage: stop a rover in the bay and Joe comes out.
	var in_bay := driving_vehicle != null and absf(me.state.vehicle_speed) < 0.6 \
			and Vector2(me.state.position.x - WorldLayout.garage_spot().x, me.state.position.z - WorldLayout.garage_spot().z).length() < WorldLayout.BAY_RADIUS
	if in_bay and not _in_bay and not busy:
		_open_garage()
	_in_bay = in_bay


func toggle_binoculars() -> void:
	binocular_on = not binocular_on
	match_node.view.binocular_zoom = 6.0 if binocular_on else 1.0


## A scan: what's worth knowing about within SCAN_RANGE, marked for a while.
const SCAN_RANGE := 160.0
const SCAN_SHOW := 12.0
const SCAN_COOLDOWN := 20.0


func scan() -> void:
	var me: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	if me == null or _scan_cool > 0.0:
		return
	scan_marks = targets(me.state.position, SCAN_RANGE, false)
	if bounty != null:
		bounty.on_scan(me)
	if heist != null:
		heist.on_scan(me)
	scan_t = SCAN_SHOW
	_scan_cool = SCAN_COOLDOWN
	match_node.audio.play_ui("countdown", -6.0)
	_note(tr("CITY_SCANNED") % scan_marks.size(), ComicUI.MAGENTA)


## What's around `pos` within `range` worth a look: [position, label, colour].
## `all`: everyone and everything (binoculars); otherwise what's ripe
## (loaded rovers, lockers to open, packs on the ground, officers).
func targets(pos: Vector3, reach: float, all: bool) -> Array:
	var world: SimWorld = match_node.server.world
	var c := Profile.career()
	var now := int(Time.get_unix_time_from_system())
	var out := []
	for i in world.vehicles.size():
		var v := world.vehicles[i]
		if v.position.distance_to(pos) > reach or v.driver == ServerSession.LOCAL_PLAYER_ID:
			continue
		var loaded := not v.cargo.is_empty() and v.owner != ServerSession.LOCAL_PLAYER_ID
		if all or loaded:
			var who := tr("CITY_CONVOY") if v.owner < 0 else (tr("CITY_YOUR_ROVER") if v.owner == ServerSession.LOCAL_PLAYER_ID else tr("CITY_ROVER_FREE"))
			var held := 0
			for it: String in v.cargo:
				held += int(v.cargo[it])
			out.append([v.position + Vector3(0, 2.2, 0), "%s%s" % [who, (tr("CITY_MARK_LOADED") + " · %d" % held) if loaded else ""],
					ComicUI.YELLOW if loaded else ComicUI.PAPER])
	for home: Array in WorldLayout.residences():
		if str(home[2]).is_empty() or (home[1] as Vector3).distance_to(pos) > reach:
			continue
		var ripe := c.loot_wait("home:" + str(home[0]), now) <= 0
		if all or ripe:
			out.append([(home[1] as Vector3) + Vector3(0, 2.2, 0), tr("CITY_MARK_LOCKER") % home[2] + ("" if ripe else tr("CITY_MARK_BARE")),
					ComicUI.GREEN if ripe else ComicUI.PAPER])
	for dr: Dictionary in world.drops:
		if (dr.position as Vector3).distance_to(pos) <= reach:
			out.append([(dr.position as Vector3) + Vector3(0, 1.0, 0), str(dr.get("label", tr("SHELF_PACK_OF") % dr.name)), ComicUI.GREEN])
	for id: int in world.players:
		var p: SimPlayer = world.players[id]
		if id == ServerSession.LOCAL_PLAYER_ID or not p.state.alive or p.state.position.distance_to(pos) > reach:
			continue
		var cop := p.display_name.begins_with(CityMode.POLICE)
		var hostile := id in _hostiles()
		if all or cop or hostile:
			# Each compartment on its own line: on them, in their vehicle, at home.
			var extra := ""
			for comp: Array in victim_compartments(id):
				var n := 0
				for it: String in comp[1]:
					n += int(comp[1][it])
				if n > 0:
					extra += "  ·  " + tr("SCAN_LINE") % [str(comp[0]).get_slice(":", 0), n]
			out.append([p.state.position + Vector3(0, 2.3, 0), p.display_name + extra, ComicUI.CYAN if cop else ComicUI.RED])
	if not all:
		for spot: Array in WorldLayout.loot_spots():
			if (spot[1] as Vector3).distance_to(pos) <= reach and c.loot_wait(str(spot[0]), now) <= 0:
				out.append([(spot[1] as Vector3) + Vector3(0, 1.5, 0), tr(spot[3]), ComicUI.GREEN])
	return out


func _open_garage() -> void:
	garage.open(_garage_info())
	match_node.input.enabled = false
	match_node.touch.release_all()
	_touch_was_visible = match_node.touch.visible
	match_node.touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _garage_info() -> Dictionary:
	var v := driving_vehicle
	var me: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	var idx := me.state.vehicle if me != null else -1
	var chop := ""
	if v != null and v.owner != ServerSession.LOCAL_PLAYER_ID:
		chop = "concern" if v.owner < 0 else "public"
	return {"stars": wanted.stars, "seen": _police_seen, "fuel": v.fuel if v != null else 100.0,
			"condition": v.condition if v != null else 100.0, "chop": chop, "wallet": int(Profile.career().d.wallet),
			"hot": Profile.career().loot_wait("chop:rover_%d" % idx, int(Time.get_unix_time_from_system()))}


## Kasei Motors' showroom: buy a new ride (your old one's traded in).
func _open_motors() -> void:
	garage.open_menu(tr("MOTORS_NAME"), _motors_line(), _motors_options())
	match_node.input.enabled = false
	match_node.touch.release_all()
	_touch_was_visible = match_node.touch.visible
	match_node.touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _motors_line() -> String:
	var c := Profile.career()
	var now: Dictionary = VehicleSim.MODELS[int(c.d.get("ride", 0))]
	return tr("MOTORS_LINE") % [now.name, int(c.d.wallet)]


func _motors_options() -> Array:
	var c := Profile.career()
	var out := []
	for i in VehicleSim.MODELS.size():
		var m: Dictionary = VehicleSim.MODELS[i]
		if i == int(c.d.get("ride", 0)):
			out.append([tr("MOTORS_YOURS") % m.name, false, ComicUI.PAPER, "none"])
			continue
		if VehicleSim.flies(i):
			continue  # aircraft are Kasei Aero's, at the Skyport
		var cost := c.ride_price(i)
		out.append([tr("MOTORS_BUY") % [m.name, roundi(float(m.max) * 3.6), int(m.slots), cost], c.d.wallet >= cost,
				ComicUI.CYAN, "ride:%d" % i])
	return out


## A menu on the garage panel (the Immigration office, Kasei Aero, a door,
## the gang): `options` are [text, enabled, accent, id].
func open_menu(title: String, line: String, options: Array) -> void:
	garage.open_menu(title, line, options)
	match_node.input.enabled = false
	match_node.touch.release_all()
	_touch_was_visible = match_node.touch.visible
	match_node.touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _garage_act(what: String) -> void:
	var c := Profile.career()
	if what.begins_with("style:"):
		style.menu_act(what.substr(6))
		return
	if what.begins_with("heist:"):
		heist.menu_act(what.substr(6))
		return
	if what.begins_with("trade:"):
		trade.menu_act(what.substr(6))
		return
	if what.begins_with("bounty:"):
		bounty.menu_act(what.substr(7))
		return
	if what.begins_with("estate:"):
		var em: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
		if em != null:
			estate.menu_act(what.substr(7), em)
		return
	if what == "none":
		return
	if what.begins_with("ride:"):
		var model := int(what.substr(5))
		if c.buy_ride(model):
			match_node.server.world.vehicles[0].model = model  # your rover at the gate is the new one
			Profile.save()
			_flash_text(tr("MOTORS_BOUGHT") % VehicleSim.MODELS[model].name, ComicUI.GREEN)
		garage.set_menu(_motors_line(), _motors_options())
		return
	var v := driving_vehicle
	var world: SimWorld = match_node.server.world
	var me: SimPlayer = world.get_player(ServerSession.LOCAL_PLAYER_ID)
	if v == null or me == null:
		garage.visible = false
		_close_talk()
		return
	match what:
		"respray":
			if not _police_seen and c.pay(c.respray_cost(wanted.stars)):
				wanted.clear()
				_rover_crime = me.state.vehicle  # a new colour: nobody's looking for this one now
				garage.note = tr("GARAGE_RESPRAYED")
				_flash_text(tr("CITY_LOST_THEM"), ComicUI.GREEN)
		"fuel":
			if c.pay(ceili((100.0 - v.fuel) * Career.GARAGE_FUEL)):
				v.fuel = 100.0
				garage.note = tr("GARAGE_FUELLED")
		"repair":
			if c.pay(ceili((100.0 - v.condition) * Career.GARAGE_REPAIR)):
				v.condition = 100.0
				garage.note = tr("GARAGE_FIXED")
		"chop":
			var idx := me.state.vehicle
			var kind := "concern" if v.owner < 0 else "public"
			var got := c.chop("rover_%d" % idx, kind, int(Time.get_unix_time_from_system()))
			if got > 0:
				var stripped := Robbery.take_all(v.cargo, c.d.stash)  # the hold's yours before it's stripped
				world._leave_vehicle(me)
				_return_rover(idx)
				Profile.save()
				garage.visible = false
				_close_talk()
				_flash_text(tr("GARAGE_CHOPPED") % [got, stripped.size()], ComicUI.GREEN)
				return
	Profile.save()
	garage.info = _garage_info()
	garage.refresh()


## A chopped rover turns up again where it's kept (a new one), full and fixed.
func _return_rover(idx: int) -> void:
	var v: SimVehicle = match_node.server.world.vehicles[idx]
	var home: Array = WorldLayout.convoy_spot() if v.owner < 0 else (WorldLayout.rover_spots()[idx] if idx < WorldLayout.rover_spots().size() else [v.position, v.yaw])
	v.position = home[0]
	v.yaw = home[1]
	v.fuel = 100.0
	v.condition = 100.0
	v.last_speed = 0.0


## The hour of the sol now (screenshots may run it on: CityNpcs.hour_offset).
func hour() -> float:
	return fmod(GameClock.hour(Time.get_unix_time_from_system()) + CityNpcs.hour_offset, 24.0)


## Who's about and where right now: [who, position].
func people_now() -> Array:
	var h := hour()
	var out := []
	for t: Array in CityLayout.terminals():
		var yaw := deg_to_rad(t[2])
		var at: Vector3 = (t[1] as Vector3) - Vector3(sin(yaw), 0, cos(yaw)) * 1.6
		var p := WorldLayout.person_at(PERSON_AT[t[0]], at, h)
		if p != Vector3.INF:
			out.append([PERSON_AT[t[0]], p])
	var fp := WorldLayout.person_at("foreman", WorldLayout.foreman_spot(), h)
	if fp != Vector3.INF:
		out.append(["foreman", fp])
	for spot: Array in WorldLayout.people_spots():
		var sp := WorldLayout.person_at(spot[0], spot[1], h)
		if sp != Vector3.INF:
			out.append([spot[0], sp])
	return out


func raid_on() -> bool:
	return _raid != null or _guards != null


## Searching a crate, a locker, a wreck's hold.
func _search(id: String) -> void:
	for spot: Array in WorldLayout.loot_spots():
		if spot[0] != id:
			continue
		var now := int(Time.get_unix_time_from_system())
		var c := Profile.career()
		var wait := c.loot_wait(id, now)
		if wait > 0:
			_note(tr("CITY_LOOT_EMPTY") % wait, ComicUI.YELLOW)
			return
		var got := c.scavenge(id, spot[2], randf(), now, WorldLayout.LOOT_COOLDOWN)
		Profile.save()
		for item: String in got:
			_note(tr("CITY_LOOT_FOUND") % [got[item], Career.ITEMS[item].name], ComicUI.GREEN)


## The farm's guards: beaten, you got away with it; down, they take it back.
func _step_guards(me: SimPlayer) -> void:
	if _guards == null:
		return
	match _guards.step():
		1:
			_guards.finish()
			_guards = null
			_sync_combat()
			_note(tr("CITY_CONVOY_CLEAR" if _guard_kind == "convoy" else "CITY_THEFT_CLEAR"), ComicUI.GREEN)
		2:
			if _guard_kind == "convoy":
				Profile.career().caught_by_escort()
			else:
				Profile.career().caught_stealing()
			Profile.save()
			_guards.finish()
			_guards = null
			_sync_combat()
			_note(tr("CITY_CONVOY_CAUGHT" if _guard_kind == "convoy" else "CITY_THEFT_CAUGHT") % Career.SEARCH_FINE, ComicUI.RED)


func raid_status() -> Vector2i:
	return Vector2i(_raid.raiders_left(), _raid.militia_left()) if _raid != null else Vector2i.ZERO


## Concern raids: due (Career) on a Hollow you hold; it starts when you
## arrive to defend it, ends when the raiders are down (won) or you fall.
func _step_raid(me: SimPlayer) -> void:
	var c := Profile.career()
	var server: ServerSession = match_node.server
	if _raid == null:
		if region == "hollow" and c.owns_hollow() and c.d.hollow.raid_due and me.state.alive and me.state.vehicle < 0 \
				and server.bot_nav != null and server.bot_nav.ready_for_queries:
			_raid = RaidDirector.new(server)
			_raid.start(me.net_id, WorldLayout.HOLLOW, c.raiders(), c.militia())
			_set_armed(true)
			_flash("CITY_RAID_START", ComicUI.RED)
		return
	match _raid.step():
		1:
			c.raid_won()
			Profile.save()
			_end_raid()
			_flash("CITY_RAID_WON", ComicUI.GREEN)
		2:
			c.raid_lost()
			Profile.save()
			_end_raid()
			_flash("CITY_RAID_LOST", ComicUI.RED)


func _end_raid() -> void:
	_raid.finish()
	_raid = null
	_sync_combat()


## Weapons out for a raid (buttons, bodies), holstered again after.
func _set_armed(armed: bool) -> void:
	match_node.touch.hidden_ids = [] if armed else ["fire", "scope", "grenade", "crouch"]
	match_node.touch.queue_redraw()
	for v: PlayerVisual in match_node._visuals.values():
		v.holstered = not armed
	if match_node.hud != null:
		match_node.hud.show_crosshair = armed


func _flash(key: String, color: Color) -> void:
	raid_banner = tr(key)
	raid_banner_t = 4.5
	discovery_text = ""
	match_node.audio.play_ui("shield_break" if color == ComicUI.RED else "kill_confirm", -2.0)
	raid_color = color


var raid_color := Color.WHITE
var _rig: int = -1      ## the drill rig we're running a shift at
var _guards: RaidDirector  ## Deep Furrow's guards after a theft
var _augers: Array[Node3D] = []   ## each rig's turning drill
var _drill_sound: AudioStreamPlayer3D
var _dust: GPUParticles3D
var _rig_t: float = 0.0


## A landmark found for the first time: logged in the career, a survey fee
## paid (exploring is a trade too), and a banner.
func _discover(mark: Array) -> void:
	var c := Profile.career()
	var found: Array = c.d.get("discovered", [])
	if mark[0] in found:
		return
	found.append(mark[0])
	c.d["discovered"] = found
	c.d.wallet += int(mark[3])
	Profile.save()
	discovery_text = tr("WORLD_LANDMARK_" + str(mark[0]).to_upper())
	discovery_t = 4.0
	match_node.audio.play_ui("kill_confirm", -4.0)


## Goods within reach, in order: a dropped pack, a fighter you have the
## edge on, a shop's counter.
func _near_goods(me: SimPlayer) -> void:
	var world: SimWorld = match_node.server.world
	var pos := me.state.position
	_sync_drops(world)
	for v: SimVehicle in world.vehicles:
		if v.owner < 0:
			_convoy_sign.position = v.position + Vector3(0, 3.6, 0)
			_convoy_sign.visible = not v.cargo.is_empty()
	if not _near.is_empty() or me.state.vehicle >= 0:
		return
	var dr := world.drop_near(pos)
	if not dr.is_empty():
		_near = "drop:%d" % int(dr.id)
		return
	var held: SimPlayer = world.players.get(_holdup_id)
	if held != null and _holdup_id in _hostiles() and Robbery.can_hold_up(me.state, held.state, 1.4):
		_near = "holdup:%d" % _holdup_id
		return
	_holdup_id = 0
	for id: int in _hostiles():
		var p: SimPlayer = world.players.get(id)
		if p != null and Robbery.can_hold_up(me.state, p.state):
			_near = "holdup:%d" % id
			_holdup_id = id
			return
	var homes := WorldLayout.residences()
	for i in homes.size():
		if pos.distance_to(homes[i][1]) < 1.8:
			_near = "home:%d" % i
			return
	var shops := WorldLayout.shops()
	for i in shops.size():
		if pos.distance_to(shops[i][1]) < 1.8:
			_near = ("shop:%d" if WorldLayout.shop_open(shops[i][0], hour()) else "closed:%d") % i
			return


## The fighters against you now (a raid's, the guards').
func _hostiles() -> Array[int]:
	var out: Array[int] = []
	if _raid != null:
		out.append_array(_raid.raiders)
	if _guards != null:
		out.append_array(_guards.raiders)
	if bounty != null:
		out.append_array(bounty.fighters())
	if trade != null:
		out.append_array(trade.fighters())
	if events != null:
		out.append_array(events.fighters())
	if heist != null:
		out.append_array(heist.fighters())
	return out


func _drop(id: int) -> Dictionary:
	for dr: Dictionary in match_node.server.world.drops:
		if int(dr.id) == id:
			return dr
	return {}


## Opening goods: a counter, a hold, a pack on the ground, a hold-up.
func _use_goods(me: SimPlayer) -> void:
	var world: SimWorld = match_node.server.world
	if _near.begins_with("home:"):
		var i := int(_near.substr(5))
		var home: Array = WorldLayout.residences()[i]
		if str(home[2]).is_empty():
			_open_shelf({"mode": "hold", "title": tr("SHELF_LOCKER"), "right": Profile.career().d.home.locker})
		elif _breakin < 0:
			var tool := Profile.career().break_tool()
			if tool.is_empty():
				_note(tr("CITY_NEED_TOOL"), ComicUI.YELLOW)
			else:
				_breakin = i  # work the lock: stay put while the tool does its job
				_breakin_t = 0.0
				_breakin_tool = tool
		return
	if _near.begins_with("shop:"):
		var kind: String = WorldLayout.shops()[int(_near.substr(5))][0]
		_open_shelf({"mode": "shop", "shop": kind, "title": Career.SHOPS[kind].name})
	elif _near.begins_with("hold:"):
		var v: SimVehicle = world.vehicles[int(_near.substr(5))]
		var title := tr("SHELF_HOLD_OWN") if v.owner == me.net_id else tr("CITY_CONVOY") if v.owner < 0 else tr("SHELF_HOLD_OTHER") % tr("CITY_ROVER")
		if v.owner < 0 and not v.cargo.is_empty() and _guards == null and _raid == null:
			# The Concern's escort saw you at the hatch.
			var c := Profile.career()
			var looted: Dictionary = c.d.get("looted", {})
			looted["convoy"] = int(Time.get_unix_time_from_system()) + WorldLayout.CONVOY_RESTOCK
			c.d["looted"] = looted
			Profile.save()
			_guards = RaidDirector.new(match_node.server)
			_guard_kind = "convoy"
			_guards.start_guards(me.net_id, WorldLayout.convoy_guard_posts(), "concern", "Concern·Escort %d")
			_set_armed(true)
			_flash_text(tr("CITY_CONVOY_ALARM"), ComicUI.RED)
			crime("convoy")
		_open_shelf({"mode": "hold", "title": title, "right": v.cargo, "vehicle": v})
	elif _near.begins_with("drop:"):
		var dr := _drop(int(_near.substr(5)))
		if not dr.is_empty():
			_open_shelf({"mode": "loot", "title": dr.get("label", tr("SHELF_PACK_OF") % dr.name), "right": dr.items})
	elif _near.begins_with("holdup:"):
		var id := int(_near.substr(7))
		var p: SimPlayer = world.players.get(id)
		var who := p.display_name if p != null else ""
		var gave := (_raid != null and _raid.surrender(id)) or (_guards != null and _guards.surrender(id)) \
				or (bounty != null and bounty.surrender(id))
		if gave:
			_flash_text(tr("CITY_HELD_UP") % who, ComicUI.YELLOW)
			crime("holdup")
			# Search them: each of their compartments, one at a time.
			var dr: Dictionary = world.drops.back() if not world.drops.is_empty() else {}
			var comps := victim_compartments(id, dr.items if not dr.is_empty() else {})
			_open_shelf({"mode": "loot", "title": comps[0][0], "right": comps[0][1], "compartments": comps})


## Someone's compartments, separately: what's on them (their pack, or the
## pack they gave up), the hold of the vehicle they drive or own close by,
## their home's locker if they live here. [[title, Dictionary], ...].
func victim_compartments(id: int, pack: Dictionary = {}) -> Array:
	var world: SimWorld = match_node.server.world
	var p: SimPlayer = world.players.get(id)
	var who := p.display_name if p != null else "?"
	var out := [[tr("SEARCH_PACK") % who, pack if not pack.is_empty() else world.packs.get(id, {})]]
	var at := p.state.position if p != null else Vector3.INF
	for i in world.vehicles.size():
		var v: SimVehicle = world.vehicles[i]
		if (v.driver == id or v.owner == id) and v.position.distance_to(at) < 30.0:
			out.append([tr("SEARCH_HOLD") % who, v.cargo])
			break
	for home: Array in WorldLayout.residences():
		if str(home[2]) == who or who.ends_with("·" + str(home[2])):
			var locker: Dictionary = Profile.career().d.get("their_lockers", {}).get(str(home[0]), {})
			out.append([tr("SEARCH_HOME") % who, locker])
			break
	return out


func open_pack() -> void:
	var hm: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID) if match_node.server != null else null
	var can_hide: bool = hm != null and hm.state.vehicle < 0 and not region in WorldLayout.LAWFUL and region != "interior"
	_open_shelf({"mode": "pack", "title": tr("SHELF_PACK_TITLE"), "hide_here": can_hide})


func _open_shelf(cfg: Dictionary) -> void:
	shelf.open(cfg)
	match_node.input.enabled = false
	match_node.touch.release_all()
	_touch_was_visible = match_node.touch.visible
	match_node.touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A change on the shelf: a new gun goes in your hands now.
func _on_shelf(kind: String, item: String) -> void:
	if kind == "hide_here":
		var hme: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
		var i := Profile.career().make_cache(hme.state.position)
		if i < 0:
			_note(tr("CITY_CACHES_FULL") % Career.MAX_CACHES, ComicUI.YELLOW)
			return
		Profile.save()
		_open_shelf({"mode": "cache", "title": tr("SHELF_CACHE_TITLE"), "right": Profile.career().d.caches[i].items, "cache": i})
		return
	if kind == "hide" or kind == "take":
		Profile.career().tidy_caches()
		Profile.save()
	if kind == "use":
		use_kit(item)
		shelf.refresh()
		return
	if kind == "body":
		match_node.rebuild_visual(ServerSession.LOCAL_PLAYER_ID)
	var me: SimPlayer = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	if me != null:  # what the shelf changed reaches the suit now (grenades, spares)
		_sync_kit(me)
	if kind != "equip" and kind != "sell" and kind != "load":
		return
	var idx := Profile.career().primary_index()
	if me != null and idx != match_node.config.primary:
		match_node.config.primary = idx
		me.loadout = Loadouts.make(idx)
		me.state.init_weapons(me.loadout)


## Packs lying on the ground: a satchel with a strap where each fell.
func _sync_drops(world: SimWorld) -> void:
	var live := {}
	for dr: Dictionary in world.drops:
		live[int(dr.id)] = true
		if not _drop_marks.has(int(dr.id)):
			var bag := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.7, 0.45, 0.5)
			bag.mesh = _tinted(box, Color(0.45, 0.32, 0.2))
			bag.material_override = Comic.kit_material(0.012)
			bag.position = (dr.position as Vector3) + Vector3(0, 0.25, 0)
			bag.rotation.y = float(int(dr.id) % 7)
			var strap := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(0.12, 0.47, 0.52)
			strap.mesh = _tinted(sb, Color(0.95, 0.75, 0.2))
			strap.material_override = Comic.kit_material(0.0)
			bag.add_child(strap)
			match_node.add_child(bag)
			_drop_marks[int(dr.id)] = bag
	for id: int in _drop_marks.keys():
		if not live.has(id):
			(_drop_marks[id] as Node).queue_free()
			_drop_marks.erase(id)


func prompt() -> String:
	if _near.is_empty() or screen.visible or talk.visible or shelf.visible:
		return ""
	var text := ""
	if _near == "rover":
		text = tr("WORLD_PROMPT_DRIVE")
	elif _near == "exit_rover":
		text = tr("WORLD_PROMPT_EXIT")
	elif _near.begins_with("home:"):
		var home: Array = WorldLayout.residences()[int(_near.substr(5))]
		if str(home[2]).is_empty():
			text = tr("CITY_PROMPT_LOCKER")
		elif _breakin == int(_near.substr(5)):
			return tr("CITY_BREAKING_IN") % roundi(_breakin_t / _breakin_seconds() * 100.0)
		else:
			text = tr("CITY_PROMPT_BREAK_IN") % home[2]
	elif _near.begins_with("trade:"):
		text = trade.prompt(_near)
	elif _near.begins_with("event:"):
		text = events.prompt(_near)
	elif _near.begins_with("social:"):
		var st := social.prompt(_near)
		if st.contains("%"):
			return st
		text = st
	elif _near.begins_with("heist:"):
		var ht := heist.prompt(_near)
		if ht.contains("%"):
			return ht
		text = ht
	elif _near == "bounty:board":
		text = tr("BOUNTY_PROMPT_BOARD")
	elif _near == "bounty:ask":
		text = tr("BOUNTY_PROMPT_ASK")
	elif _near.begins_with("estate:"):
		var et := estate.prompt(_near)
		if _near.begins_with("estate:tree:") and et.contains("%"):
			return et
		text = et
	elif _near.begins_with("kiosk:"):
		text = tr("CITY_PROMPT_KIOSK")
	elif _near == "showroom":
		text = tr("CITY_PROMPT_SHOWROOM")
	elif _near.begins_with("closed:"):
		var cshop: Array = WorldLayout.shops()[int(_near.substr(7))]
		var opens := GameClock.BAR_HOURS.x if Career.SHOPS[cshop[0]].get("hours", "") == "bar" else GameClock.OPEN_HOURS.x
		return tr("CITY_SHOP_CLOSED") % [Career.SHOPS[cshop[0]].name, GameClock.label(opens)]
	elif _near.begins_with("shop:"):
		var shop: Array = WorldLayout.shops()[int(_near.substr(5))]
		text = tr("CITY_PROMPT_SHOP") % Career.SHOPS[shop[0]].name
	elif _near.begins_with("hold:"):
		text = tr("CITY_PROMPT_HOLD")
	elif _near.begins_with("drop:"):
		var dr := _drop(int(_near.substr(5)))
		text = tr("CITY_PROMPT_SEARCH_SPOT") % dr.label if dr.has("label") else tr("CITY_PROMPT_SEARCH") % str(dr.get("name", "?"))
	elif _near.begins_with("holdup:"):
		var p: SimPlayer = match_node.server.world.players.get(int(_near.substr(7)))
		text = tr("CITY_PROMPT_HOLDUP") % (p.display_name if p != null else "?")
	elif _near == "deploy":
		var c: Dictionary = Profile.career().d.contract
		text = tr("CITY_PROMPT_DEPLOY") % (c.title if not c.is_empty() else tr("CITY_NO_CONTRACT"))
	elif _near == "bunk":
		text = tr("CITY_PROMPT_SLEEP")
	elif _near == "air_refill":
		text = tr("TITAN_AIR_PROMPT") % AIR_CANISTER_PRICE
	elif _near.begins_with("cache:"):
		text = tr("CITY_PROMPT_CACHE")
	elif _near.begins_with("loot:"):
		for spot: Array in WorldLayout.loot_spots():
			if spot[0] == _near.substr(5):
				text = tr(spot[3])
	elif _near == "algae":
		text = tr("CITY_PROMPT_ALGAE")
	elif _near == "lift_down":
		text = tr("CITY_PROMPT_LIFT_DOWN")
	elif _near == "lift_up":
		text = tr("CITY_PROMPT_LIFT_UP")
	elif _near.begins_with("rig_"):
		if _rig >= 0:
			return tr("CITY_RIG_RUNNING") % roundi(_rig_t / WorldLayout.RIG_SECONDS * 100.0)
		text = tr("CITY_PROMPT_RIG")
	elif _near.begins_with("job_"):
		text = tr("CITY_PROMPT_" + _near.to_upper())
	else:
		text = tr("TALK_TO") % Career.PEOPLE[_near].name
	return InputAdapter.prompt("interact", text)


## Entering the city: the checkpoint may search you for contraband.
func _checkpoint() -> void:
	var found := Profile.career().checkpoint(randf())
	if found > 0:
		Profile.save()
		_flash_text(tr("CITY_SEARCHED") % [found, Career.SEARCH_FINE], ComicUI.RED)


func _note(text: String, color: Color) -> void:
	_flash_text(text, color)


func _flash_text(text: String, color: Color) -> void:
	raid_banner = text
	raid_banner_t = 4.0
	raid_color = color


func _open_talk(who: String) -> void:
	talk.open(who)
	match_node.input.enabled = false
	match_node.touch.release_all()
	_touch_was_visible = match_node.touch.visible
	match_node.touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_talk() -> void:
	match_node.input.enabled = true
	match_node.touch.visible = _touch_was_visible


func open_terminal(tab: String) -> void:
	screen._tab = tab
	screen.open()
	match_node.input.enabled = false
	match_node.touch.release_all()
	if not talk.visible and match_node.touch.visible:
		_touch_was_visible = true
	match_node.touch.visible = false  # the terminal owns the screen
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## First arrival: choose your nation before anything else (Guide step 1).
var _nation_pick: NationPick


func _maybe_pick_nation() -> void:
	_maybe_pick_path()
	if _nation_pick != null or Profile.career().nation() != Nations.NONE or match_node.server == null \
			or match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID) == null:
		return
	_nation_pick = NationPick.new()
	hud_layer.get_parent().add_child(_nation_pick)
	match_node.input.enabled = false
	match_node.touch.release_all()
	_touch_was_visible = match_node.touch.visible
	match_node.touch.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_nation_pick.chosen.connect(func(i: int) -> void:
		Profile.career().choose_nation(i)
		var me = match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
		if me != null and not bool(Profile.career().d.arrived):
			match_node.server.world.teleport(me, Arrival.spawn(i))  # off to the nation's colony
			Profile.career().d.arrived = true
		Profile.save()
		_flash_text(tr("NATION_WELCOME") % Nations.display_name(i), Nations.color(i))
		_nation_pick.queue_free()
		match_node.input.enabled = true
		match_node.touch.visible = _touch_was_visible)


## After arrival: government or freelance, asked once.
var _path_pick: PathPick


func _maybe_pick_path() -> void:
	var c := Profile.career()
	if _path_pick != null or _nation_pick != null or c.nation() == Nations.NONE or c.path() != "" \
			or match_node.server == null:
		return
	_path_pick = PathPick.new()
	hud_layer.get_parent().add_child(_path_pick)
	match_node.input.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_path_pick.chosen.connect(func(p: String) -> void:
		Profile.career().choose_path(p)
		Profile.save()
		_path_pick.queue_free()
		match_node.input.enabled = true)


## Through the gate: a deployment to Rustwood Yard (the career's contract
## and gear go with it).
func deploy() -> void:
	match_node.store_kit()
	MatchConfig.pending = MatchConfig.for_place(GameMode.HUNT, match_node.config.player_name)
	LoadingCover.change_scene(match_node.get_tree(), "res://game/match.tscn")


## The city HUD: where you are, your wallet, the prompt (ComicUI).
class _CityHud extends Control:
	var city: CityMode

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	## Shapes go into one triangle array (ShapeBatch) and text is queued and
	## drawn after them grouped by font (ComicUI's text batch): the HUD was
	## ~70 draw calls, a call per circle, line and string.
	var _sb: ShapeBatch  ## the HUD's shapes: one draw call

	func _draw() -> void:
		if _sb == null:
			_sb = ShapeBatch.new(self)
		_sb.begin()
		ComicUI.begin_text_batch(self, _sb)
		_draw_hud()
		ComicUI.flush_text_batch(self)
		_sb.flush()

	func _draw_hud() -> void:
		if city == null or city.screen.visible:
			return
		city.discovery_t = maxf(city.discovery_t - get_process_delta_time(), 0.0)
		var s: float = Settings.get_value("accessibility", "hud_scale")
		var names := {"city": ["CITY_NAME", "CITY_SUB", "CITY_HOLSTERED"],
				"farm": ["WORLD_FARM", "WORLD_FARM_SUB", "WORLD_FARM_RULE"],
				"hollow": ["WORLD_HOLLOW", "WORLD_HOLLOW_SUB", "WORLD_HOLLOW_RULE"],
				"dig": ["WORLD_DIG", "WORLD_DIG_SUB", "WORLD_DIG_RULE"],
				"helios": ["WORLD_HELIOS", "WORLD_HELIOS_SUB", "WORLD_LAWFUL_RULE"],
				"galleria": ["WORLD_GALLERIA", "WORLD_GALLERIA_SUB", "WORLD_GALLERIA_RULE"],
				"terrace": ["WORLD_TERRACE", "WORLD_TERRACE_SUB", "WORLD_LAWFUL_RULE"],
				"skyport": ["WORLD_SKYPORT", "WORLD_SKYPORT_SUB", "WORLD_LAWFUL_RULE"],
				"interior": ["WORLD_INTERIOR", "WORLD_INTERIOR_SUB", "WORLD_INTERIOR_RULE"],
				"open": ["WORLD_OPEN", "WORLD_OPEN_SUB", "WORLD_OPEN_RULE"]}
		var n: Array = names.get(city.region, names.open)
		var accent: Color = {"city": ComicUI.YELLOW, "hollow": ComicUI.CYAN, "dig": ComicUI.MAGENTA, "helios": ComicUI.CYAN,
				"galleria": ComicUI.MAGENTA, "terrace": ComicUI.GREEN, "skyport": ComicUI.YELLOW}.get(city.region, ComicUI.PAPER)
		var title := tr(n[0])
		if city.region == "interior" and city.estate != null and not city.estate.inside.is_empty():
			title = str(Career.PROPERTIES[city.estate.inside[0]].name).to_upper() if Career.PROPERTIES.has(city.estate.inside[0]) \
					else tr("HEIST_VAULT_ROOM")
		var tw := UiStyle.font_hud_big.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(22 * s)).x
		var tag := Rect2(Vector2(34, 22) * s, Vector2(tw + 44 * s, 30 * s))
		ComicUI.draw_panel(self, tag, accent, ComicUI.INK, 3.0 * s)
		ComicUI.draw_text(self, tag.position + Vector2(18, 24) * s, title, UiStyle.font_hud_big, roundi(22 * s), ComicUI.INK, 0, 0)
		ComicUI.draw_text(self, Vector2(34, 82) * s, tr(n[1]), UiStyle.font_hud_bold, roundi(22 * s), ComicUI.PAPER, 0, roundi(4 * s))
		var rule := tr(n[2])
		var cc := Profile.career()
		if city.drawn and city.region in WorldLayout.LAWFUL:
			rule = tr("CITY_DRAWN_RULE")
		if city.region == "hollow" and cc.owns_hollow():
			rule = tr("WORLD_HOLLOW_YOURS") % [int(cc.d.hollow.supplies), int(cc.d.hollow.ingots)]
		ComicUI.draw_text(self, Vector2(34, 108) * s, rule, UiStyle.font_hud_bold, roundi(20 * s),
				Color(accent, 0.95), 0, roundi(4 * s))
		if city.room != WorldLayout.NO_ROOM:  # a roof isn't air: say which this is
			var air := city.room == WorldLayout.ROOM_AIR
			ComicUI.draw_text(self, Vector2(34, 134) * s, tr("WORLD_ROOM_AIR" if air else "WORLD_ROOM_NO_AIR"),
					UiStyle.font_hud_bold, roundi(20 * s), ComicUI.GREEN if air else ComicUI.RED, 0, roundi(4 * s))
		var c := Profile.career()
		ComicUI.draw_text(self, Vector2(size.x - 34 * s, 70 * s), "$%d" % c.d.wallet, UiStyle.font_hud_big, roundi(44 * s),
				ComicUI.GREEN, 2, roundi(7 * s))
		_draw_wanted(s)
		_draw_minimap(s)
		if city.bounty != null:
			city.bounty.draw_card(self, s)
		var k: Dictionary = c.d.contract
		# The objective tracker (Guide): one thing to do, and how far it is.
		var obj := Guide.city_objective(c)
		var from := Vector3.INF
		if city.match_node.server != null:
			var tp: SimPlayer = city.match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
			if tp != null:
				from = tp.state.position
		var line: String = (tr("GUIDE_STEP") % obj.step + "  " if int(obj.step) > 0 else "") + str(obj.text)
		if from != Vector3.INF:
			line += Guide.distance_text(from, obj.target)
		ComicUI.draw_text(self, Vector2(size.x - 34 * s, 102 * s), line, UiStyle.font_hud_bold, roundi(24 * s),
				ComicUI.YELLOW if int(obj.step) > 0 else ComicUI.PAPER, 2, roundi(4 * s))
		_tracker_target = obj.target
		ComicUI.draw_text(self, Vector2(size.x - 34 * s, 128 * s), tr("WORLD_DISCOVERED") % [c.d.get("discovered", []).size(),
				WorldLayout.LANDMARKS.size()], UiStyle.font_hud_bold, roundi(20 * s), Color(ComicUI.PAPER, 0.8), 2, roundi(4 * s))
		_draw_raid(s)
		if DustStorms.storm > 0.05 and city.region != "farm":
			ComicUI.draw_text(self, Vector2(size.x * 0.5, 190 * s), tr("WORLD_STORM"), UiStyle.font_hud_big, roundi(28 * s),
					Color(ComicUI.YELLOW, minf(DustStorms.storm * 2.0, 1.0)), 1, roundi(6 * s))
		if city.match_node.server != null:
			var sme: SimPlayer = city.match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
			if sme != null:
				SurvivalHud.draw(self, sme.state, Vector2(34 * s, size.y - (118.0 if city.raid_on() else 44.0) * s), s)
		if city.discovery_t > 0.0:
			var a := clampf(city.discovery_t / 0.5, 0.0, 1.0)
			var banner := tr("WORLD_DISCOVERY") % city.discovery_text
			var bw := UiStyle.font_hud_big.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(40 * s)).x
			var br := Rect2(Vector2((size.x - bw) * 0.5 - 30 * s, size.y * 0.24), Vector2(bw + 60 * s, 64 * s))
			ComicUI.draw_panel(self, br, Color(ComicUI.YELLOW, a), ComicUI.INK, 5.0 * s)
			ComicUI.draw_text(self, br.position + Vector2(30 * s, 48 * s), banner, UiStyle.font_hud_big, roundi(40 * s),
					Color(ComicUI.INK, a), 0, 0)
		if city.driving_speed >= 0.0:
			var kmh := "%d" % roundi(city.driving_speed * 3.6)
			var sr := Rect2(Vector2(size.x * 0.5 - 90 * s, size.y - 110 * s), Vector2(180 * s, 70 * s))
			ComicUI.draw_panel(self, sr, Color(ComicUI.INK, 0.85), ComicUI.CYAN, 3.0 * s)
			ComicUI.draw_text(self, sr.position + Vector2(90 * s, 50 * s), kmh, UiStyle.font_hud_big, roundi(44 * s),
					ComicUI.PAPER, 2, 0)
			ComicUI.draw_text(self, sr.position + Vector2(98 * s, 50 * s), "KM/H", UiStyle.font_hud_bold, roundi(22 * s),
					ComicUI.CYAN, 0, 0)
			var dv: SimVehicle = city.driving_vehicle
			if dv != null:
				_gauge(Vector2(sr.end.x + 18 * s, sr.position.y + 8 * s), s, tr("CITY_FUEL"), dv.fuel, ComicUI.YELLOW)
				_gauge(Vector2(sr.end.x + 18 * s, sr.position.y + 40 * s), s, tr("CITY_CONDITION"), dv.condition, ComicUI.GREEN)
		_draw_marks(s)
		var text := city.prompt()
		if not text.is_empty():
			var f := UiStyle.font_hud_bold
			var px := roundi(28 * s)
			var pw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var icon := 0.0
			if InputAdapter.touch_ui():
				icon = 40.0 * s  # the Action button's hand, so the prompt says which button
			var r := Rect2(Vector2((size.x - pw - icon) * 0.5 - 22 * s, size.y * 0.62), Vector2(pw + icon + 44 * s, 48 * s))
			ComicUI.draw_panel(self, r, Color(ComicUI.INK, 0.88), ComicUI.YELLOW, 3.0 * s)
			if icon > 0.0:
				draw_texture_rect(TouchControls.ICONS.interact, Rect2(r.position + Vector2(18 * s, 7 * s), Vector2(34, 34) * s),
						false, ComicUI.GREEN)
			draw_string(f, r.position + Vector2(24 * s + icon, 34 * s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ComicUI.PAPER)

	## Raid alert (due), the fight's status and your vitals, the outcome.
	## The minimap (top left, turning with you): roads, the dome, places
	## by letter, rovers, the Marshals, the job's waypoint at its edge.
	const MAP_RANGE := 130.0

	var _tracker_target := Vector3.INF  ## the tracker's place, marked on the minimap

	func _draw_minimap(s: float) -> void:
		if city.match_node.server == null:
			return
		var world: SimWorld = city.match_node.server.world
		var me: SimPlayer = world.get_player(ServerSession.LOCAL_PLAYER_ID)
		if me == null:
			return
		var rad := 92.0 * s
		var c := Vector2(34 * s + rad, 150 * s + rad)
		var yaw := me.state.vehicle_yaw if me.state.vehicle >= 0 else me.state.yaw
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var right := Vector2(cos(yaw), -sin(yaw))
		var k := rad / MAP_RANGE
		var mp := Vector2(me.state.position.x, me.state.position.z)
		var to_map := func(p: Vector2) -> Vector2:
			var d := p - mp
			return c + Vector2(d.dot(right), -d.dot(fwd)) * k
		_sb.circle(c + Vector2(4, 5) * s, rad, Color(0, 0, 0, 0.4))
		_sb.circle(c, rad, Color(0.16, 0.08, 0.06, 0.88))
		for road: Array in WorldLayout.roads():
			var prev := Vector2.INF
			for pt: Vector2 in road:
				var q: Vector2 = to_map.call(pt)
				if prev != Vector2.INF:
					var a := prev
					var b := q
					if a.distance_to(c) < rad * 1.6 or b.distance_to(c) < rad * 1.6:
						_sb.line(a, b, Color(0.55, 0.5, 0.46), 5.0 * s)
				prev = q
		var mono := PackedVector2Array()
		for pt: Vector2 in WorldLayout.monorail():
			mono.append(to_map.call(pt))
		for i in mono.size() - 1:
			if mono[i].distance_to(c) < rad * 1.6 or mono[i + 1].distance_to(c) < rad * 1.6:
				_sb.line(mono[i], mono[i + 1], Color(0.3, 0.9, 1.0, 0.6), 2.0 * s)
		var dome: Vector2 = to_map.call(Vector2(CityLayout.ORIGIN.x, CityLayout.ORIGIN.z))
		if dome.distance_to(c) < rad + WorldLayout.DOME_RADIUS * k:
			_sb.arc(dome, WorldLayout.DOME_RADIUS * k, 0.0, TAU, 48, Color(0.4, 0.8, 0.9, 0.7), 2.0 * s)
		var places := []
		var letters := {"exchange": "$", "arms": "G", "guns": "G", "store": "S", "salvage": "P", "bar": "B", "saloon": "B", "post": "T"}
		for shop: Array in WorldLayout.shops():
			places.append([shop[1], letters.get(shop[0], "S"), ComicUI.YELLOW])
		places.append([WorldLayout.garage_spot(), "R", ComicUI.MAGENTA])
		places.append([WorldLayout.showroom_spot(), "M", ComicUI.CYAN])
		places.append([WorldLayout.residences()[0][1], "H", ComicUI.GREEN])
		places.append([WorldLayout.lift_top(), "L", ComicUI.PAPER])
		for p: Array in city.people_now():
			if p[0] == "jobs":
				places.append([p[1], "J", ComicUI.YELLOW])
		if city.trade != null:
			places.append_array(city.trade.map_places())
		if city.heist != null:
			places.append_array(city.heist.map_places())
		if city.events != null:
			for ev: Array in city.events.map_places():
				var eq: Vector2 = to_map.call(Vector2((ev[0] as Vector3).x, (ev[0] as Vector3).z))
				if eq.distance_to(c) > rad - 10 * s:  # off the map: at its edge, pointing the way
					var edge := c + (eq - c).normalized() * (rad - 12 * s)
					_sb.circle(edge, 7 * s, ComicUI.CYAN)
					ComicUI.draw_text(self, edge + Vector2(0, 20 * s), tr("EVENT_MAP"), UiStyle.font_hud_bold, roundi(11 * s),
							ComicUI.CYAN, 1, roundi(3 * s))
				else:
					places.append(ev)
		for p: Array in places:
			var q: Vector2 = to_map.call(Vector2((p[0] as Vector3).x, (p[0] as Vector3).z))
			if q.distance_to(c) < rad - 6 * s:
				_sb.circle(q, 8 * s, Color(ComicUI.INK, 0.9))
				ComicUI.draw_text(self, q + Vector2(0, 5 * s), p[1], UiStyle.font_hud_big, roundi(14 * s), p[2], 1, 0)
		for v: SimVehicle in world.vehicles:
			var q: Vector2 = to_map.call(Vector2(v.position.x, v.position.z))
			if q.distance_to(c) < rad - 3 * s and v.driver != me.net_id:
				_sb.rect(Rect2(q - Vector2(3, 3) * s, Vector2(6, 6) * s), ComicUI.GREEN if v.owner == me.net_id else ComicUI.PAPER)
		var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25
		for id: int in world.players:
			var p: SimPlayer = world.players[id]
			if id == me.net_id or not p.state.alive:
				continue
			var cop := p.display_name.begins_with(CityMode.POLICE)
			if not cop and not (id in city._hostiles()):
				continue
			if city.bounty != null and id in city.bounty.fighters() and not city.bounty.hot:
				continue  # the outlaw's hiding: you find them
			var q: Vector2 = to_map.call(Vector2(p.state.position.x, p.state.position.z))
			if q.distance_to(c) < rad - 3 * s:
				_sb.circle(q, 4 * s, (ComicUI.CYAN if blink else ComicUI.RED) if cop else ComicUI.RED)
		if city.bounty != null:
			city.bounty.draw_on_map(self, to_map, c, rad, k, s)
		var job: Dictionary = Profile.career().d.job
		if not job.is_empty() and WorldLayout.job_sites().has(job.id):
			var site: Vector3 = WorldLayout.job_sites()[job.id][0]
			var q: Vector2 = to_map.call(Vector2(site.x, site.z))
			if q.distance_to(c) > rad - 8 * s:
				q = c + (q - c).normalized() * (rad - 8 * s)  # off the map: at its edge, pointing the way
			var d := 7.0 * s
			_sb.colored_polygon(PackedVector2Array([q + Vector2(0, -d), q + Vector2(d, 0), q + Vector2(0, d), q + Vector2(-d, 0)]), ComicUI.YELLOW)
		# Your hidden stashes: small cyan squares (only you know them).
		for cache: Dictionary in Profile.career().d.caches:
			var cq: Vector2 = to_map.call(Vector2(float(cache.at[0]), float(cache.at[2])))
			if cq.distance_to(c) < rad - 6 * s:
				_sb.rect(Rect2(cq - Vector2(4, 4) * s, Vector2(8, 8) * s), ComicUI.CYAN)
		# The tracker's place: a magenta diamond, at the edge when it's off the map.
		if _tracker_target != Vector3.INF:
			var tq: Vector2 = to_map.call(Vector2(_tracker_target.x, _tracker_target.z))
			if tq.distance_to(c) > rad - 8 * s:
				tq = c + (tq - c).normalized() * (rad - 8 * s)
			var td := 8.0 * s
			_sb.colored_polygon(PackedVector2Array([tq + Vector2(0, -td), tq + Vector2(td, 0), tq + Vector2(0, td), tq + Vector2(-td, 0)]), ComicUI.INK)
			td = 6.0 * s
			_sb.colored_polygon(PackedVector2Array([tq + Vector2(0, -td), tq + Vector2(td, 0), tq + Vector2(0, td), tq + Vector2(-td, 0)]), ComicUI.MAGENTA)
		# The districts: on the map, or named at its edge pointing the way.
		for dist: Array in [[WorldLayout.HELIOS, "MAP_HELIOS"], [WorldLayout.GALLERIA, "MAP_GALLERIA"],
				[WorldLayout.TERRACE, "MAP_TERRACE"], [WorldLayout.SKYPORT, "MAP_SKYPORT"],
				[Vector2(CityLayout.ORIGIN.x, CityLayout.ORIGIN.z), "MAP_CITY"]]:
			var q: Vector2 = to_map.call(dist[0])
			if q.distance_to(c) < rad - 10 * s:
				continue
			q = c + (q - c).normalized() * (rad - 14 * s)
			var label := tr(dist[1])
			ComicUI.draw_text(self, q + Vector2(0, 5 * s), label, UiStyle.font_hud_bold, roundi(12 * s), ComicUI.CYAN, 1,
					roundi(3 * s))
		# You: an arrow pointing up (the map turns with you).
		var a := 9.0 * s
		var arrow := PackedVector2Array([c + Vector2(0, -a * 1.3), c + Vector2(a * 0.8, a), c + Vector2(0, a * 0.45), c + Vector2(-a * 0.8, a)])
		_sb.colored_polygon(arrow, ComicUI.PAPER)
		arrow.append(arrow[0])
		_sb.polyline(arrow, ComicUI.INK, 2.0 * s)
		_sb.arc(c, rad, 0.0, TAU, 64, ComicUI.INK, 5.0 * s)
		_sb.arc(c, rad - 2.5 * s, 0.0, TAU, 64, ComicUI.YELLOW, 2.0 * s)
		ComicUI.draw_text(self, c + Vector2(0, -rad + 16 * s), "N" if absf(wrapf(yaw, -PI, PI)) < 0.4 else "", UiStyle.font_hud_big,
				roundi(14 * s), ComicUI.PAPER, 1, 0)
		ComicUI.draw_text(self, c + Vector2(0, rad + 22 * s), GameClock.label(city.hour()), UiStyle.font_hud_big, roundi(20 * s),
				ComicUI.PAPER, 1, roundi(4 * s))

	func _gauge(at: Vector2, s: float, label: String, pct: float, col: Color) -> void:
		var w := 150.0 * s
		var r := Rect2(at + Vector2(0, 8 * s), Vector2(w, 12 * s))
		_sb.rect(r, Color(ComicUI.INK, 0.8))
		var c := ComicUI.RED if pct < 20.0 else col
		_sb.rect(Rect2(r.position, Vector2(w * clampf(pct / 100.0, 0.0, 1.0), r.size.y)), c)
		_sb.rect(r, ComicUI.INK, false, 2.0 * s)
		ComicUI.draw_text(self, at + Vector2(w + 8 * s, 20 * s), "%s %d%%" % [label, roundi(pct)], UiStyle.font_hud_bold,
				roundi(18 * s), c, 0, roundi(3 * s))

	## Scan marks (and, through binoculars, labels on whatever you look at).
	func _draw_marks(s: float) -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var marks: Array = city.scan_marks if city.scan_t > 0.0 else []
		if city.binocular_on:
			var me: SimPlayer = city.match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
			if me != null:
				marks = marks + city.targets(me.state.position, 300.0, true)
			# The binocular view: a dark ring round two lenses.
			var c := size * 0.5
			var rad := size.y * 0.42
			for sx in [-1.0, 1.0]:
				_sb.arc(c + Vector2(sx * rad * 0.55, 0), rad, 0.0, TAU, 64, Color(0, 0, 0, 0.85), 14.0 * s)
		var job: Dictionary = Profile.career().d.job
		if not job.is_empty() and WorldLayout.job_sites().has(job.id):  # the waypoint: always shown
			marks = marks + [[(WorldLayout.job_sites()[job.id][0] as Vector3) + Vector3(0, 3, 0),
					tr("CITY_JOB_MARK") % Career.JOBS[job.id].title, ComicUI.YELLOW, true]]
		var centre := size * 0.5
		for m: Array in marks:
			var at: Vector3 = m[0]
			var col: Color = m[2]
			var dist := cam.global_position.distance_to(at)
			if cam.is_position_behind(at):
				continue
			var p := cam.unproject_position(at)
			var on := Rect2(Vector2.ZERO, size).grow(-30 * s).has_point(p)
			if not on:
				p = Vector2(clampf(p.x, 40 * s, size.x - 40 * s), clampf(p.y, 60 * s, size.y - 60 * s))
			if city.binocular_on and not city.scan_t > 0.0 and p.distance_to(centre) > size.y * 0.3 and m.size() < 4:
				continue  # binoculars name what you're looking at
			var d := 10.0 * s
			var dia := PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)])
			_sb.colored_polygon(dia, col)
			dia.append(dia[0])
			_sb.polyline(dia, ComicUI.INK, 2.5 * s)
			ComicUI.draw_text(self, p + Vector2(0, -16 * s), "%s · %dm" % [m[1], roundi(dist)], UiStyle.font_hud_bold,
					roundi(18 * s), col, 1, roundi(4 * s))

	## The wanted level: stars at the top, blinking while they search for you.
	func _draw_wanted(s: float) -> void:
		var w: Wanted = city.wanted
		if w.stars == 0:
			return
		var blink := w.unseen > 0.0 and fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.3
		var r := 19.0 * s
		var x0 := size.x * 0.5 - (Wanted.MAX - 1) * r * 1.2
		for i in Wanted.MAX:
			var c := Vector2(x0 + i * r * 2.4, 46 * s)
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
			var on := i < w.stars
			var shadow := pts.duplicate()
			for j in shadow.size():
				shadow[j] += Vector2(3, 4) * s
			_sb.colored_polygon(shadow, Color(0, 0, 0, 0.45))
			_sb.colored_polygon(pts, (ComicUI.PAPER if blink else ComicUI.YELLOW) if on else Color(ComicUI.INK, 0.5))
			pts.append(pts[0])
			_sb.polyline(pts, ComicUI.INK, 3.0 * s)
		if w.unseen > 0.0:
			ComicUI.draw_text(self, Vector2(size.x * 0.5, 92 * s), tr("CITY_WANTED_SEARCHING") % ceili(w.escape_time() - w.unseen),
					UiStyle.font_hud_bold, roundi(20 * s), ComicUI.PAPER, 1, roundi(4 * s))

	func _draw_raid(s: float) -> void:
		var c := Profile.career()
		if city.match_node.server == null:
			return
		var me: SimPlayer = city.match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
		if city.raid_on() and city._raid != null:
			var st := city.raid_status()
			var text := tr("CITY_RAID_STATUS") % [st.x, st.y]
			var tw := UiStyle.font_hud_big.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(30 * s)).x
			var r := Rect2(Vector2((size.x - tw) * 0.5 - 24 * s, 18 * s), Vector2(tw + 48 * s, 48 * s))
			ComicUI.draw_panel(self, r, ComicUI.RED, ComicUI.INK, 4.0 * s)
			ComicUI.draw_text(self, r.position + Vector2(24 * s, 37 * s), text, UiStyle.font_hud_big, roundi(30 * s), ComicUI.PAPER, 0, roundi(4 * s))
			if me != null:
				var hp := clampf(me.state.health / Balance.PLAYER.max_health, 0.0, 1.0)
				var ar := clampf(me.state.shield / maxf(Balance.PLAYER.max_shield, me.state.shield), 0.0, 1.0)
				var base := Vector2(34 * s, size.y - 40 * s)
				for bar: Array in [[ar, ComicUI.CYAN, -30.0, ceili(me.state.shield)], [hp, ComicUI.RED, 0.0, ceili(me.state.health)]]:
					var br := Rect2(base + Vector2(0, float(bar[2]) * s), Vector2(240 * s, 20 * s))
					ComicUI.draw_panel(self, br, Color(ComicUI.INK, 0.8), ComicUI.INK, 3.0 * s, 10 * s)
					var fill := Rect2(br.position + Vector2(4, 4) * s, Vector2((br.size.x - 8 * s) * float(bar[0]), br.size.y - 8 * s))
					if fill.size.x > 0.0:
						_sb.colored_polygon(ComicUI.quad(fill, 8 * s), bar[1])
					ComicUI.draw_text(self, Vector2(br.end.x + 22 * s, br.end.y), str(bar[3]), UiStyle.font_hud_big, roundi(22 * s),
							ComicUI.PAPER, 0, roundi(4 * s))
		elif c.owns_hollow() and c.d.hollow.raid_due:
			var text := tr("CITY_RAID_DUE")
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 160.0)
			ComicUI.draw_text(self, Vector2(size.x * 0.5, 150 * s), text, UiStyle.font_hud_big, roundi(28 * s),
					Color(ComicUI.RED, pulse), 1, roundi(6 * s))
		if city.raid_banner_t > 0.0:
			city.raid_banner_t = maxf(city.raid_banner_t - get_process_delta_time(), 0.0)
			var a := clampf(city.raid_banner_t / 0.5, 0.0, 1.0)
			var bw := UiStyle.font_hud_big.get_string_size(city.raid_banner, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(46 * s)).x
			var br := Rect2(Vector2((size.x - bw) * 0.5 - 30 * s, size.y * 0.26), Vector2(bw + 60 * s, 70 * s))
			ComicUI.draw_panel(self, br, Color(city.raid_color, a), ComicUI.INK, 5.0 * s)
			ComicUI.draw_text(self, br.position + Vector2(30 * s, 54 * s), city.raid_banner, UiStyle.font_hud_big, roundi(46 * s),
					Color(ComicUI.INK, a), 0, 0)
