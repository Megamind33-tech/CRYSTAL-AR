extends Node3D
## One match on screen (PLAN §2.4, §3.3): offline, listen host or client.
## Offline and host run a ServerSession in this process (offline without
## networking) and render its world directly, interpolated between ticks. A
## client runs a ClientSession: the local player is predicted, everyone else
## is interpolated from snapshots. Input, HUD and effects are shared.

const MOVEMENT := preload("res://data/movement_config.tres")
## THE HUNT (the dig and the settlements): grounded, human movement (no
## double jump or slide, little air control), speeds matched to the walk,
## jog and run clips so feet don't slide.
const HUNT_MOVEMENT := preload("res://data/hunt_movement.tres")
const HUD_SCENE := preload("res://ui/hud/hud.tscn")
const MAIN_MENU := "res://ui/main_menu/main_menu.tscn"
const LOBBY := "res://ui/lobby/lobby.tscn"
## A client suspended this long reconnects instead of waiting for the old
## connection (the server times it out after 10 s).
const RECONNECT_AFTER_MS := 5000
const DEATH_CAM_SECONDS := 3.0
## Touch auto-melee reach (the melee weapon reaches 2.2 m from the eye).
const TOUCH_MELEE_RANGE := 2.0
## Clients from a lobby wait this long for the host's match to listen.
const LOBBY_HANDOVER_SECONDS := 1.5
## Joining the match from the lobby is retried this often (the host's socket
## may still be switching from the lobby to the match).
const HANDOVER_ATTEMPTS := 5

var config: MatchConfig
var server: ServerSession  ## offline and host
var client: ClientSession  ## client
var world_gameplay: Node3D  ## the map's gameplay (collision) node
var _stats_at: float = 0.0  ## _time of the next FPS/latency refresh
var _touch_melee_at: float = 0.0  ## no touch auto-melee press before this _time
var input := InputAdapter.new()
var view := FirstPersonView.new()
var effects := Effects.new()
var pickups := PickupVisuals.new()
var flag_visuals := FlagVisuals.new()
var hunt_visuals := HuntVisuals.new()  ## THE HUNT: treasures, beams, extraction pads
var hunt_menu: HuntMenu  ## THE HUNT: the phone (jobs, crew, deals, intel)
var hunt_hud: HuntHud  ## THE HUNT: radar, cash, wanted stars, mission text, banners
var city: CityMode  ## THE HUNT: Tharsis Gate (terminals, gate)
## Kasei Valley: where the local player is put once play starts (the dig
## pad for a run, where a run ended for free roam); INF when done.
var _arrival := Vector3.INF
var _arrival_frames: int = 0
var pad_visuals := JumpPadVisuals.new()
var blobs := BlobShadows.new()
var _flag_bases: Array = []  ## CTF: the map's flag bases
var _aim_assist := AimAssist.new()
var audio := GameAudio.new()
var hud: Hud
var touch := TouchControls.new()

var _visuals: Dictionary = {}  ## net id -> PlayerVisual
var _visual_tier := MeshyRig.current_tier()  ## the character tier _visuals were built at
var _prev: Dictionary = {}  ## host: net id -> PlayerSimState at the previous tick
var _started: bool = false
var _paused: bool = false
var _leaving: bool = false
var _pause_panel: Control
var _banner: Label
var _info: Label
var _time: float = 0.0
var _loadout: Array[WeaponData] = []
var _spawns: Array[Transform3D] = []
var _host_silent: bool = false  ## no packets from the host for 3 s (logged once per stretch)
var _paused_at_ms: int = 0  ## when the app was last suspended (0: not suspended)
var _reconnect_until_ms: int = 0  ## reconnecting while non-zero
var _online_code: String = ""  ## hosting online: the invite code (decision 0005)
var _to_lobby: bool = false  ## going back to the lobby: the online game stays open
var _join_attempt: int = 0
var _confirm_panel: Control
var _settings_menu: SettingsMenu
var _autopilot: WanderInput
var _kill_feed: KillFeed
var _scoreboard: MatchPanel
var _results: MatchPanel
var _death_label: Label
var _loadout_bar: HBoxContainer  ## primary choice while respawning (PLAN §2.6)
## The scoreboard on the pause menu, right of its buttons.
var _pause_scores: MatchPanel
## Spectator mode: the player we watch (0 until one is picked).
var _spec_target: int = 0
var _spec_dead_since: Dictionary = {}  ## networked spectator: id -> server tick its death was seen
var _results_until: float = 0.0
## Death cam (PLAN §2.6): {pos, killer, until} while active.
var _death_cam: Dictionary = {}
var _arms_ready: bool = false  ## first-person arms built (see _ensure_arms)
var _arms_color := Color.WHITE
var _life_dealt: float = 0.0
var _life_taken: float = 0.0
var _remote_cache: Dictionary = {}  ## client: latest remote render states
## Our own tally of the current match, for partial results if the match
## never sends RESULTS (we quit or the host vanished, PLAN §3.13).
var _last_slot: int = -1
var _last_reload: int = 0
var _last_shield: float = 100.0
var _shield_rising: bool = false
var _tally := MatchStats.new()
var _tally_match: int = 0
var _results_applied: bool = false
var _perf_ms := FrameStats.new(7200)  ## frame times of the current minute
var _perf_gpu := FrameStats.new(7200)  ## GPU time per frame (ms)
var _perf_cpu := FrameStats.new(7200)  ## main thread: process + physics time (ms)
var _perf_render_cpu := FrameStats.new(7200)  ## rendering CPU time (ms)
var _perf_minute_start_ms: int = 0
var _perf_frames: int = 0
var _tick_ms := FrameStats.new(3600)  ## host: server tick times of the current minute
var _sim_ms := FrameStats.new(3600)  ## host: of which simulation
var _banner_phase: int = -1
var _go_until: float = 0.0
var _adaptive := AdaptiveQuality.new()
var _perf_hitches: int = 0  ## frames over HITCH_MS this minute (cold-start stutter, PLAN §5)
var _warming: bool = false
var _perf_peaks := Vector3i.ZERO  ## this minute's most draw calls, primitives, live particles


func _ready() -> void:
	Settings.set_menu_mode(false)
	config = MatchConfig.pending if MatchConfig.pending != null else MatchConfig.new()
	MatchConfig.pending = null
	if not Maps.has(config.map):
		config.map = Maps.DEFAULT
	var load_start := Time.get_ticks_msec()
	Log.i("match", "starting: %s" % Log.describe(config, ["team_plan", "reconnect_token"]))
	var gameplay := Maps.gameplay(config.map)
	add_child(gameplay)
	world_gameplay = gameplay
	# THE HUNT: where the air is (host and clients predict the suit alike).
	Survival.air_zones.clear()
	Survival.air_boxes.clear()
	if config.map == GameMode.CITY_MAP:
		Survival.air_zones.append(Vector3(CityLayout.ORIGIN.x, CityLayout.ORIGIN.z, 72.0))  # the city's dome
		Survival.air_boxes.append(WorldLayout.farm_air())  # Deep Furrow
	pickups.spots = gameplay.pickup_spots()
	_flag_bases = gameplay.flag_bases() if gameplay.has_method("flag_bases") else []
	if gameplay.has_method("jump_pads"):
		pad_visuals.build(gameplay.jump_pads())
	var presentation := Maps.presentation(config.map)
	add_child(presentation)
	var weather: Node = presentation.find_child("Weather", false, false)
	if weather != null:  # the storms follow the world's clock
		weather.day_cycle = config.game_mode == GameMode.CITY  # sols pass in free roam
		weather.tick_source = func() -> int:
			return server.world.tick if server != null else (int(client.clock.server_time()) if client != null else 0)
	_apply_shadows(presentation)
	Settings.apply_environment(presentation)
	var map_tier := [MeshyRig.current_tier()]  ## boxed: the lambda below updates it
	MapDetail.apply(presentation, config.map, map_tier[0])
	Events.settings_changed.connect(func(section: String, _key: String, _value: Variant) -> void:
		if section == "video":
			_apply_shadows(presentation)
			Settings.apply_environment(presentation)
			# Only on a tier change: it walks the map and copies its materials,
			# too slow for every slider step or adaptive step-down.
			if MeshyRig.current_tier() != map_tier[0]:
				map_tier[0] = MeshyRig.current_tier()
				MapDetail.apply(presentation, config.map, map_tier[0])
			_rebuild_visuals_for_tier())
	add_child(input)
	add_child(view)
	add_child(effects)
	add_child(pickups)
	add_child(flag_visuals)
	add_child(hunt_visuals)
	add_child(pad_visuals)
	add_child(blobs)
	add_child(audio)
	audio.launched.connect(pad_visuals.launched)
	audio.listener = view.camera
	_build_ui()
	Log.i("match", "map %s loaded in %d ms (detail %s)" % [config.map, Time.get_ticks_msec() - load_start,
			MeshyRig.current_tier()])
	audio.caption.connect(hud.show_caption)
	if not Platform.user_args.has("--no-warmup"):  # dev: cold-start comparison
		_warm_up()
	else:
		LoadingCover.take(self, config).queue_free()
		MatchPreload.release()
	get_tree().root.get_window().focus_exited.connect(_on_focus_lost)
	Diagnostics.net_info = _net_info
	if Platform.user_args.has("--aa-bench"):  # dev: MSAA vs FXAA on the device (AaBench)
		add_child(AaBench.new())
	if Platform.user_args.has("--adpf"):  # ADPF spike (docs/decisions/0004-thermals-adpf.md)
		Platform.start_performance_hints(1000.0 / maxf(float(Settings.get_value("video", "fps_cap")), 1.0))
	# Static world bodies become queryable after the first physics step.
	await get_tree().physics_frame
	var loadout := Loadouts.ffa()
	var spawns: Array[Transform3D] = gameplay.spawn_points_for(config.game_mode) if gameplay.has_method("spawn_points_for") \
			else gameplay.spawn_points()
	_loadout = loadout
	_spawns = spawns
	if config.mode == MatchConfig.Mode.JOIN:
		if config.spectate:
			input.enabled = false
			touch.visible = false
		if config.online:
			_info.text = tr("NET_ONLINE_JOINING") % config.online_code
		if not await _start_client(config.reconnect_token):
			return
		if not config.online:
			_info.text = tr("NET_CONNECTING") % config.address
	else:
		server = ServerSession.new()
		server.name = "Server"
		server.map_id = config.map
		if Platform.get_user_arg("--time-limit").is_valid_int():  # dev: short matches
			server.time_limit_ticks = Platform.get_user_arg("--time-limit").to_int() * Sim.TICK_RATE
		elif config.minutes > 0:
			server.time_limit_ticks = config.minutes * 60 * Sim.TICK_RATE
		elif config.game_mode == GameMode.CITY:
			server.time_limit_ticks = 1 << 30  # the city has no clock
		server.use_primaries = true
		server.game_mode = config.game_mode
		server.friendly_fire = config.friendly_fire
		server.bot_difficulty = config.bot_difficulty
		add_child(server)
		var port := config.port if config.mode == MatchConfig.Mode.HOST and not config.online else -1
		var online_peer: MultiplayerPeer = null
		if config.online:
			_info.text = tr("NET_ONLINE_SIGNING_IN")
			var info := {"name": tr("NET_GAME_OF") % config.player_name, "map": config.map,
					"mode": GameMode.IDS[config.game_mode], "max": config.max_combatants(), "state": "playing"}
			# From a lobby the game (and its code) already exists; its peer
			# was closed and the match listens on a new one.
			var hosted: Dictionary = Online.serve() if config.from_lobby \
					else await Online.host(config.player_name, config.max_combatants(), info)
			if hosted.has("error"):
				Log.e("match", "online hosting failed: %s" % hosted.error)
				_fail(tr("NET_ONLINE_ERROR") % hosted.error)
				return
			online_peer = hosted.peer
			_online_code = Online.hosting_code
			Online.update_info(info)
		var err := server.start(port, _movement(), loadout, spawns, gameplay.pickup_spots(), online_peer,
				gameplay.flag_bases(), gameplay.hunt_data() if gameplay.has_method("hunt_data") else {})
		if err != OK:
			_fail(tr("NET_HOST_ERROR") % [config.port, error_string(err)])
			return
		# THE HUNT's open world (free roam or a run at the dig): its rovers,
		# and the canyon is deep.
		if config.map == GameMode.CITY_MAP:
			server.world.kill_y = -600.0  # below Deep Furrow (200 m down) and the interiors (450 m)
			for spot: Array in WorldLayout.rover_spots():
				server.world.add_vehicle(spot[0], spot[1])
			for d: Array in CityLayout.gate_doors():
				SecuredGate.add(server.world, d[0], d[1], d[2], d[3])
			if config.game_mode == GameMode.CITY:
				# The first rover at the gate is yours: its hold is the career's.
				server.world.vehicles[0].owner = ServerSession.LOCAL_PLAYER_ID
				server.world.vehicles[0].cargo = Profile.career().d.rover_cargo
				server.world.vehicles[0].model = int(Profile.career().d.get("ride", 0))  # bought at Kasei Motors
				var convoy := server.world.add_vehicle(WorldLayout.convoy_spot()[0], WorldLayout.convoy_spot()[1])
				convoy.owner = -1  # the Concern's
				if Profile.career().loot_wait("convoy", int(Time.get_unix_time_from_system())) <= 0:
					convoy.cargo = WorldLayout.CONVOY_CARGO.duplicate()
			if config.game_mode == GameMode.HUNT:
				var pad := WorldLayout.dig_pad()
				server.world.add_vehicle(pad + Vector3(6, 0.3, 0), PI * 0.5)
			elif MatchConfig.spawn_at != Vector3.INF:
				server.world.add_vehicle(MatchConfig.spawn_at + Vector3(5, 0.3, 0), PI)
			add_child(RoverVisuals.new())
		# THE HUNT: the career's gear goes on before the first spawn, and
		# your nation seats the run (docs/game-plan.md).
		if server.world.hunt != null:
			server.world.hunt.gear[ServerSession.LOCAL_PLAYER_ID] = Profile.career().loadout()
			if Profile.career().nation() != Nations.NONE:
				server.world.hunt.home_nations = {ServerSession.LOCAL_PLAYER_ID: Profile.career().nation()}
		var nav := BotNavigation.new()
		nav.name = "BotNavigation"
		add_child(nav)
		if "nav_mode" in gameplay:
			gameplay.nav_mode = config.game_mode  # bake where this mode's bots work
		nav.build(gameplay)  # async: bots wait until it's ready
		server.bot_nav = nav
		server.max_combatants = config.max_combatants()
		# The host's bots stay as players join; a spectator's place goes to one more.
		server.bot_count = config.bots + (1 if config.spectate else 0)
		server.lobby_after_match = config.from_lobby
		server.team_plan = config.team_plan
		server.team_names = config.team_names
		server.team_colors = config.team_colors
		GameMode.team_names = config.team_names
		GameMode.team_colors = config.team_colors
		server.match_over.connect(_back_to_lobby)
		if config.spectate:
			server.add_local_spectator()
			input.enabled = false
			touch.visible = false
		else:
			# THE HUNT: the suit's oxygen, spares and fatigue come from the career.
			if config.game_mode == GameMode.HUNT or config.game_mode == GameMode.CITY:
				server.world.survival_start[ServerSession.LOCAL_PLAYER_ID] = Profile.career().kit()
			var me := server.add_local_player(config.player_name, config.character, config.color, config.primary,
					MatchConfig.profile_uuid())
			if config.map == GameMode.CITY_MAP:
				if config.game_mode == GameMode.HUNT:
					_arrival = WorldLayout.dig_pad() + Vector3(-5, 0.3, 0)  # beside the pad, the rover to the east
				elif MatchConfig.spawn_at != Vector3.INF:
					_arrival = MatchConfig.spawn_at
				MatchConfig.spawn_at = Vector3.INF
			input.look_yaw = me.state.yaw
		if config.online:
			_info.text = tr("NET_ONLINE_HOSTING") % _online_code
			Platform.perf_log("ONLINE hosting with invite code %s" % _online_code)
		elif config.mode == MatchConfig.Mode.HOST:
			_info.text = tr("NET_HOSTING") % [", ".join(Discovery.lan_addresses()), config.port]
			var advertiser := Discovery.Advertiser.new()
			advertiser.beacon_source = server.beacon.bind(tr("NET_GAME_OF") % config.player_name, false, config.port)
			add_child(advertiser)
		_snapshot_prev()
	if config.mode != MatchConfig.Mode.OFFLINE:
		Platform.set_low_latency_network(true)
	if not Platform.is_mobile() and not spectating():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_started = true
	Log.i("match", "running as %s %d ms after the scene started" % [["offline", "host", "client"][config.mode],
			Time.get_ticks_msec() - load_start])


func _exit_tree() -> void:
	Platform.set_low_latency_network(false)
	if not _online_code.is_empty() and not _to_lobby:
		Online.stop_hosting()
	if Diagnostics.net_info == _net_info:
		Diagnostics.net_info = Callable()


## Creates the ClientSession and starts joining. `token` != 0 reconnects as
## the same player (PLAN §3.4).
func _start_client(token: int) -> bool:
	if client != null:
		client.leave()
		client.queue_free()
		effects.reset_seen()  # event ids restart with the new session
	client = ClientSession.new()
	client.name = "Client"
	client.player_name = config.player_name
	client.character = config.character
	client.color = config.color
	client.primary = config.primary
	client.spectate = config.spectate
	client.uuid = MatchConfig.profile_uuid()
	client.reconnect_token = token
	client.input_source = _local_command
	add_child(client)
	client.joined.connect(func() -> void:
		# Clients load the map before joining (prediction needs its collision).
		if client.map_id != config.map:
			Log.i("match", "the host runs map %s, we loaded %s%s" % [client.map_id, config.map,
					": reloading with it" if Maps.has(client.map_id) and not config.map_retried else ""])
			client.leave()
			if Maps.has(client.map_id) and not config.map_retried:
				# Load the host's map and join again (manual address joins
				# don't know it beforehand).
				config.map = client.map_id
				config.map_retried = true
				MatchConfig.pending = config
				get_tree().reload_current_scene.call_deferred()
			else:
				_fail(tr("NET_MAP_MISMATCH") % client.map_id))
	client.lobby_called.connect(_back_to_lobby)
	client.failed.connect(_on_client_lost)
	client.left.connect(_on_client_lost)
	if config.from_lobby and token == 0:
		# The host leaves the lobby and opens the match at the same moment.
		await get_tree().create_timer(LOBBY_HANDOVER_SECONDS).timeout
	var online_peer: MultiplayerPeer = null
	if config.online:
		var joined: Dictionary = await Online.connect_to(config.player_name, config.online_host) \
				if not config.online_host.is_empty() else await Online.join(config.player_name, config.online_code)
		if joined.has("error"):
			Log.w("match", "online join failed: %s" % joined.error)
			match joined.error:
				"not_found": _fail(tr("NET_ONLINE_NOT_FOUND") % config.online_code)
				"version": _fail("NET_ONLINE_VERSION")
				_: _fail(tr("NET_ONLINE_ERROR") % joined.error)
			return false
		online_peer = joined.peer
		config.online_host = joined.host_id  # the lobby reconnects to it after the match
	var err := client.join(config.address, config.port, _movement(), _loadout, _spawns, online_peer)
	if config.from_lobby and token == 0:
		# An online connection can hang instead of failing: retry it too.
		var attempt := _join_attempt
		var joining := client
		get_tree().create_timer(15.0).timeout.connect(func() -> void:
			if client == joining and client.local_id == 0 and attempt == _join_attempt and not _leaving:
				_on_client_lost("connection failed"))
	if err != OK:
		_fail(tr("NET_CONNECT_ERROR") % error_string(err))
		return false
	return true


func _on_client_lost(reason: String) -> void:
	Log.w("match", "connection lost: %s (started %s, leaving %s, reconnecting %s)" % [reason, _started, _leaving,
			_reconnect_until_ms != 0])
	if _reconnect_until_ms != 0:
		return  # the reconnect loop retries
	# Dropped mid-match (our network blipped, or the server timed us out):
	# rejoin with our token while the server keeps our place.
	if reason == "disconnected" and _started and not _leaving and client.reconnect_token != 0:
		Log.i("match", "rejoining with our token for up to %d s" % (ServerSession.RECONNECT_WINDOW_MS / 1000))
		_reconnect_until_ms = Time.get_ticks_msec() + ServerSession.RECONNECT_WINDOW_MS
		_reconnect_step.call_deferred()
		return
	if reason == "connection failed" and config.from_lobby and client.local_id == 0 \
			and _join_attempt + 1 < HANDOVER_ATTEMPTS and not _leaving:
		_join_attempt += 1
		Platform.perf_log("MATCH join attempt %d failed, retrying" % _join_attempt)
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if not _leaving:
				_start_client(0))
		return
	match reason:
		"disconnected":
			_fail("NET_DISCONNECTED")
		"connection failed":
			_fail("NET_ONLINE_UNREACHABLE" if config.online else "NET_UNREACHABLE")
		"server_shutdown":
			_fail("NET_SERVER_SHUTDOWN")
		_:
			_fail(reason)


## After the app was suspended: rejoin with our token until the window closes.
func _reconnect_step() -> void:
	if Time.get_ticks_msec() > _reconnect_until_ms:
		_reconnect_until_ms = 0
		Log.w("match", "rejoining failed: the reconnect window closed")
		_fail("NET_RECONNECT_FAILED")
		return
	var token := client.reconnect_token
	Log.i("match", "rejoin attempt (%.0f s left)" % ((_reconnect_until_ms - Time.get_ticks_msec()) / 1000.0))
	_start_client(token)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if _reconnect_until_ms != 0 and not _leaving and not client.is_live():
			_reconnect_step())


## Shader warm-up behind a loading cover (Warmup).
func _warm_up() -> void:
	var cover := LoadingCover.take(self, config)
	# A kill-feed row too: its fonts' first glyphs cost up to ~0.6 s on the
	# Mi 11X (m4.md), which used to land on the first kill.
	var glyphs := "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789_-.,+"
	_kill_feed.add_death({"killer": -1, "victim": -2, "weapon": &"rail_sniper", "suicide": false,
			"headshot": true, "assists": [-3]}, func(_id: int) -> String: return glyphs, -1)
	var warm := Warmup.new()
	add_child(warm)
	_warming = true
	warm.progress.connect(cover.set_progress)
	warm.slow.connect(cover.show_slow_note)
	warm.finished.connect(func() -> void:
		_warming = false
		_kill_feed.clear()
		Diagnostics.hitch_log = true  # frames over 50 ms, with their section times (capped per session)
		MatchPreload.release()
		cover.queue_free())
	var started := Time.get_ticks_msec()
	warm.finished.connect(func() -> void: Platform.perf_log("Warmup: %d ms" % (Time.get_ticks_msec() - started)))
	warm.start(view.camera, effects)


## The sun's realtime shadows and the map's reflection probe (PLAN §3.10
## scalable settings).
func _apply_shadows(root: Node) -> void:
	var on: bool = Settings.video("shadows")
	for light in root.find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).shadow_enabled = on
	for probe in root.find_children("*", "ReflectionProbe", true, false):
		(probe as ReflectionProbe).visible = Settings.video("probe") != false
	RenderLayers.light_dynamic_with_baked_lights(root, Settings.video("lights") == true)


## First-person arms in the player's character and colour, once the local
## id (for the "auto" colour) is known.
## First-person arms in our colour (our team's in TDM); rebuilt if it changes.
func _ensure_arms() -> void:
	var character := config.character
	var pick := config.color
	if spectating() and server != null:  # the watched player's arms
		var p: SimPlayer = server.world.players.get(_spec_target)
		character = p.character if p != null else 0
		pick = p.color if p != null else 0
	elif spectating():
		character = 0
		pick = 0
		for p in client.roster:
			if p.id == _spec_target:
				character = p.character
				pick = p.color
	var team := _team_of(local_id())
	var color: Color = GameMode.team_color(team) if team < 2 else PlayerVisual.color_for(local_id(), pick)
	if _arms_ready and color == _arms_color:
		return
	_arms_ready = true
	_arms_color = color
	view.set_character(CharacterRig.selectable_style(character), color)


func _game_mode() -> int:
	return server.game_mode if server != null else client.game_mode


## TDM team of player `id`; GameMode.NO_TEAM in FFA.
## A teammate of the local player (TDM).
func _is_ally(id: int) -> bool:
	var team := _team_of(id)
	return team != GameMode.NO_TEAM and team == _team_of(local_id())


func _team_of(id: int) -> int:
	if not GameMode.is_team_mode(_game_mode()):
		return GameMode.NO_TEAM
	if server != null:
		var p: SimPlayer = server.world.players.get(id)
		return p.team if p != null else GameMode.NO_TEAM
	return client.team_of(id)


func _team_scores() -> PackedInt32Array:
	return server.world.team_scores if server != null else client.team_scores


## Whose eyes the match is seen through: our player, or the watched one
## while spectating (so hit markers, damage and the death cam follow them).
func local_id() -> int:
	if spectating():
		return _spec_target
	return client.local_id if client != null else ServerSession.LOCAL_PLAYER_ID


func spectating() -> bool:
	return (server != null and server.local_spectating) or (client != null and client.spectate)


# --- Simulation (host / offline) ---

## Runs before the ServerSession steps (parents process first): records the
## previous tick for interpolation and hands it the local player's command.
func _physics_process(_delta: float) -> void:
	if not _started or server == null:
		return
	_snapshot_prev()
	if server.last_step_usec > 0:
		_tick_ms.add(server.last_step_usec / 1000.0)  # the previous tick
		_sim_ms.add(server.last_sim_usec / 1000.0)
	server.local_command = _local_command(server.world.tick)


## The local player's command: from input, or from a bot while the overlay's
## autopilot is on (soak tests).
func _local_command(tick: int) -> PlayerCommand:
	if not Diagnostics.autopilot:
		return input.build_command(tick)
	if _autopilot == null:
		_autopilot = WanderInput.new(randi())
	var cmd := _autopilot.command_for(tick)
	input.look_yaw = cmd.yaw_radians()
	return cmd


func _snapshot_prev() -> void:
	for id in server.world.players:
		_prev[id] = server.world.get_player(id).state.copy()


# --- Rendering ---

func _process(delta: float) -> void:
	if not _started:
		return
	_time += delta
	_log_perf(delta)
	var me_driving := _local_player()
	touch.driving = me_driving != null and me_driving.state.vehicle >= 0  # car controls in a rover
	var t0 := Time.get_ticks_usec()
	var events: Array[Dictionary] = server.drain_host_events() if server != null else client.drain_events()
	for e in events:
		var te := Time.get_ticks_usec()
		_handle_event(e)
		Diagnostics.time_section("ev_" + str(e.type), te)
	Diagnostics.time_section("events", t0)
	t0 = Time.get_ticks_usec()
	if server != null:
		_render_host(delta)
	else:
		_watch_connection()
		if client.is_predicting():
			_render_client(delta)
		elif client.spectate and client.latest_snapshot != null:
			_render_client_spectator(delta)
	_update_blobs()
	Diagnostics.time_section("visuals", t0)
	t0 = Time.get_ticks_usec()
	if _arrival != Vector3.INF and server != null and server.phase == MatchPhase.PLAYING:
		_arrival_frames += 1  # after the opening (re)spawn, which comes just after play starts
		var me := _local_player()
		if me != null and me.state.alive and _arrival_frames > 10:
			server.world.teleport(me, _arrival)
			_arrival = Vector3.INF
			_bring_companion()
			_bring_squad()
	_setup_squad()
	_update_aim_assist(delta)
	if city != null:
		city.update()
	elif _game_mode() == GameMode.HUNT and _results_applied and _time >= _results_until - 0.5 and server != null:
		_back_to_city()
	_touch_melee()
	_update_stats()
	_update_banner()
	_update_match_ui(delta)
	Diagnostics.time_section("ui", t0)


## Contact shadows under everyone shown, and under us, when realtime shadows
## are off (BlobShadows).
func _update_blobs() -> void:
	if not blobs.visible:
		return
	var feet := PackedVector3Array([view.feet_position])
	for v: PlayerVisual in _visuals.values():
		if v.visible:
			feet.append(v.global_position)
	blobs.show_at(feet)


## Touch aim assist (PLAN §3.11): slowdown, magnetism and optional
## auto-fire on visible enemies, as rendered.
func _update_aim_assist(delta: float) -> void:
	var me := _local_player()
	if not touch.visible or not Settings.get_value("input", "aim_assist") or me == null or not me.state.alive:
		touch.assist_scale = 1.0
		input.assist_fire = false
		return
	var my_team := _team_of(local_id())
	var targets := {}
	for id: int in _visuals:
		var v: PlayerVisual = _visuals[id]
		if id != local_id() and v.visible and (my_team == GameMode.NO_TEAM or _team_of(id) != my_team):
			targets[id] = v.global_position + Vector3(0.0, 1.2, 0.0)
	var firing := (input.touch_held & PlayerCommand.Held.FIRE) != 0
	var pull := _aim_assist.update(delta, view.camera.global_transform, me.current_weapon(), firing,
			Settings.get_value("input", "auto_fire"), targets, view.camera.get_world_3d().direct_space_state)
	input.add_look(pull.x, pull.y)
	touch.assist_scale = _aim_assist.slowdown
	input.assist_fire = _aim_assist.wants_fire


## Host-loss detection on the client (PLAN §3.5.1): 3 s without packets shows
## a warning, 10 s goes back to the menu. Not while reconnecting.
func _watch_connection() -> void:
	if _reconnect_until_ms != 0:
		if client.is_live():
			_reconnect_until_ms = 0
			_info.text = ""
		else:
			_info.text = tr("NET_RECONNECTING") % ceili((_reconnect_until_ms - Time.get_ticks_msec()) / 1000.0)
		return
	if client.local_id == 0:
		return  # still connecting: ENet reports failure
	var silent := client.seconds_silent()
	if (silent >= 3.0) != _host_silent:
		_host_silent = silent >= 3.0
		if _host_silent:
			Log.w("match", "no packets from the host for 3 s%s" % (" (host paused)" if client.host_paused else ""))
		else:
			Log.i("match", "the host is responding again")
	if silent >= 10.0:
		_fail("NET_HOST_LOST")
	elif silent >= 3.0:
		_info.text = tr("NET_HOST_PAUSED") if client.host_paused else tr("NET_HOST_NOT_RESPONDING")
	elif client.is_live() and not spectating():
		_info.text = ""


func _render_host(delta: float) -> void:
	if spectating():
		_render_spectator(delta)
		return
	var world := server.world
	var alpha := Engine.get_physics_interpolation_fraction()
	var me := world.get_player(ServerSession.LOCAL_PLAYER_ID)
	var s := me.state
	var prev: PlayerSimState = _prev.get(me.net_id)
	var from := prev if prev != null and prev.discontinuity_gen == s.discontinuity_gen else s
	_ensure_arms()
	_update_scope(s)
	if s.alive:
		input.confirm_slot(s.weapon_slot)
	var kick := from.recoil.lerp(s.recoil, alpha)
	view.update_view(from.position.lerp(s.position, alpha), me.config.eye_for(s.stance), input.look_yaw + kick.x,
			input.look_pitch + kick.y, s, me.current_weapon(), delta)
	var seen := {}
	if view.third_person:
		seen[me.net_id] = true
		_own_visual(me.display_name, me.is_bot, me.character, me.color).update_from(prev, s, alpha, _time)
	for id in world.players:
		if id == me.net_id:
			continue
		var p: SimPlayer = world.players[id]
		seen[id] = true
		_visual_for(id, p.display_name, p.is_bot, p.character, p.color).update_from(_prev.get(id), p.state, alpha, _time)
		audio.update_player(id, p.state, false, _is_ally(id))
	audio.update_player(me.net_id, s, true)
	_prune_visuals(seen)
	effects.sync_projectiles(world.projectiles, alpha)
	var spot_ticks := PackedInt32Array()
	for i in world.pickup_spots.size():
		spot_ticks.append(world.spot_ticks_left(i))
	pickups.sync(world.items, spot_ticks)
	if _game_mode() == GameMode.CTF:
		flag_visuals.sync(world.flags, _flag_bases, _flag_carrier_at)
	if world.hunt != null:
		hunt_visuals.sync(world.hunt, world.tick, me.net_id, _flag_carrier_at)
	_update_pickup_prompt(s, world.items)
	if world.hunt != null:
		_update_hunt_prompt(world.hunt, s, world.tick)
	hud.update_state(s, me.current_weapon(), world.scores.get(me.net_id, 0), s.respawn_tick - world.tick)


## Spectator mode: the watched player's own view (camera, weapon, HUD), with
## everyone else drawn as usual.
func _render_spectator(delta: float) -> void:
	var world := server.world
	if not world.players.has(_spec_target):
		_cycle_spectator(1)
		if not world.players.has(_spec_target):
			return  # no one to watch yet
	var alpha := Engine.get_physics_interpolation_fraction()
	var p: SimPlayer = world.players[_spec_target]
	var s := p.state
	var prev: PlayerSimState = _prev.get(p.net_id)
	var from := prev if prev != null and prev.discontinuity_gen == s.discontinuity_gen else s
	_ensure_arms()
	view.set_scope(null)
	hud.set_scope(0.0, false)
	view.update_view(from.position.lerp(s.position, alpha), p.config.eye_for(s.stance),
			lerp_angle(from.yaw, s.yaw, alpha), lerpf(from.pitch, s.pitch, alpha), s, p.current_weapon(), delta)
	var seen := {}
	for id in world.players:
		if id == p.net_id:
			continue
		var other: SimPlayer = world.players[id]
		seen[id] = true
		_visual_for(id, other.display_name, other.is_bot, other.character, other.color).update_from(_prev.get(id), other.state, alpha, _time)
		audio.update_player(id, other.state, false, _is_ally(id))
	audio.update_player(p.net_id, s, true)
	_prune_visuals(seen)
	effects.sync_projectiles(world.projectiles, alpha)
	var spot_ticks := PackedInt32Array()
	for i in world.pickup_spots.size():
		spot_ticks.append(world.spot_ticks_left(i))
	pickups.sync(world.items, spot_ticks)
	var names := PackedStringArray()
	for i in s.weapons.size():
		var w := s.weapon(i)
		names.append(KillFeed.weapon_tag(w.id) if KillFeed.WEAPON_TAGS.has(w.id) else tr(w.display_name))
	hud.set_slots(names, s.weapon_slot)
	hud.update_state(s, p.current_weapon(), world.scores.get(p.net_id, 0), s.respawn_tick - world.tick)
	_info.text = tr("SPECTATE_WATCHING") % _display_name(p.net_id) + "\n" + tr(
			"SPECTATE_HINT_TOUCH" if DisplayServer.is_touchscreen_available() else "SPECTATE_HINT")


## A networked spectator (PLAN §2.7): the watched player as the server sent
## them (interpolated like every remote player), seen from their eyes.
func _render_client_spectator(delta: float) -> void:
	var states := client.remote_states()
	_remote_cache = states
	if not states.has(_spec_target):
		_cycle_spectator(1)
		if not states.has(_spec_target):
			return  # no one to watch yet
	var s: PlayerSimState = states[_spec_target].copy()
	var weapon: WeaponData = Weapons.at(s.weapons[0]) if Weapons.at(s.weapons[0]) != null else _loadout[0]
	# Snapshots carry the held weapon but not its ammo: show a full magazine.
	s.mag = PackedInt32Array([weapon.mag_size])
	s.reserve = PackedInt32Array([0])
	s.reload = PackedInt32Array([0])
	_ensure_arms()
	view.set_scope(null)
	hud.set_scope(0.0, false)
	view.update_view(s.position, _movement().eye_for(s.stance), s.yaw, s.pitch, s, weapon, delta)
	var names := {}
	for p in client.roster:
		names[p.id] = p
	var seen := {}
	for id in states:
		if id == _spec_target:
			continue
		var info: Dictionary = names.get(id, {"name": "?", "bot": false, "character": 0, "color": 0})
		seen[id] = true
		_visual_for(id, info.name, info.bot, info.character, info.color).update_from(null, states[id], 1.0, _time)
		audio.update_player(id, states[id], false, _is_ally(id))
	audio.update_player(_spec_target, s, true)
	_prune_visuals(seen)
	var ahead := (client.clock.server_time() - client.latest_snapshot.id) * Sim.TICK_DT
	var rockets := []
	for proj in client.projectiles:
		rockets.append({"id": proj.id, "weapon": proj.weapon, "position": proj.position + proj.velocity * ahead,
				"velocity": proj.velocity})
	effects.sync_projectiles(rockets, 1.0)
	pickups.sync(client.items, client.spot_ticks)
	hud.set_slots(PackedStringArray([KillFeed.weapon_tag(weapon.id) if KillFeed.WEAPON_TAGS.has(weapon.id) \
			else tr(weapon.display_name)]), 0)
	# The respawn timer isn't sent: count from when the death was seen.
	var now := client.clock.server_time()
	var respawn := 0
	if s.alive:
		_spec_dead_since.erase(_spec_target)
	else:
		var since: float = _spec_dead_since.get_or_add(_spec_target, now)
		respawn = ceili(GameMode.respawn_ticks(_game_mode()) - (now - since))
	hud.update_state(s, weapon, client.score_of(_spec_target), respawn)
	_info.text = tr("SPECTATE_WATCHING") % _display_name(_spec_target) + "\n" + tr(
			"SPECTATE_HINT_TOUCH" if DisplayServer.is_touchscreen_available() else "SPECTATE_HINT")


## Spectator mode: watch the next (`step` 1) or previous (-1) combatant.
func _cycle_spectator(step: int) -> void:
	var ids: Array = server.world.players.keys() if server != null else \
			(client.latest_snapshot.entities.keys() if client.latest_snapshot != null else [])
	if ids.is_empty():
		return
	ids.sort()
	var i := ids.find(_spec_target)
	_spec_target = ids[posmod(i + step, ids.size()) if i >= 0 else 0]
	_death_cam = {}
	_arms_ready = false


## The interact prompt for the nearest item that needs one.
func _update_pickup_prompt(s: PlayerSimState, items: Array) -> void:
	var prompt := ""
	var best := Balance.PLAYER.pickup_radius + 0.3
	for it in items:
		var weapon: int = it.weapon
		var pos: Vector3 = it.position
		var d := Vector2(pos.x - s.position.x, pos.z - s.position.z).length()
		if s.alive and d < best and absf(pos.y - s.position.y) < SimWorld.PICKUP_HEIGHT \
				and SimWorld.needs_interact(s, weapon):
			best = d
			prompt = InputAdapter.prompt("interact", tr("HUD_PICKUP_SWAP") % tr(Weapons.at(weapon).display_name).to_upper())
	hud.set_prompt(prompt)
	touch.show_interact = not prompt.is_empty()


## THE HUNT: one context action (the touch Action button, or interact):
## collect a cache, unlock the vault. Never offered while carrying, so a
## tap can't drop the cargo by accident.
func _update_hunt_prompt(h: HuntRules, s: PlayerSimState, tick: int) -> void:
	var me := local_id()
	# The rover first (the press goes to it, never drops what we carry).
	if s.alive and server != null:
		var rover := ""
		if s.vehicle >= 0:
			rover = tr("WORLD_PROMPT_EXIT")
		else:
			for v: SimVehicle in server.world.vehicles:
				if v.driver == 0 and v.position.distance_to(s.position) < VehicleSim.BOARD_RANGE:
					rover = tr("WORLD_PROMPT_DRIVE")
		if not rover.is_empty():
			hud.set_prompt(InputAdapter.prompt("interact", rover))
			touch.show_interact = true
			return
	if not s.alive or h.carried_by(me) != null or h.cache_of(me) != null or h.vault_unlocker == me:
		return
	var text := ""
	for c: HuntRules.Cache in h.active_caches():
		if c.collector == 0 and HuntRules._flat(s.position, c.position) <= HuntRules.CACHE_RADIUS:
			text = tr("HUNT_ACTION_COLLECT") % tr(HuntResources.TYPES[c.resource].name_key)
	var g := h.grand()
	if text.is_empty() and g != null and g.locked and g.on_ground() and tick >= g.available_tick \
			and h.vault_unlocker == 0 and HuntRules._flat(s.position, g.position) <= HuntRules.VAULT_UNLOCK_RADIUS:
		text = tr("HUNT_ACTION_UNLOCK")
	if not text.is_empty():
		hud.set_prompt(InputAdapter.prompt("interact", text))
		touch.show_interact = true


## Touch has no melee button: holding fire on an enemy within arm's reach,
## in front of us, melees instead.
func _touch_melee() -> void:
	var me := _local_player()
	if not touch.visible or me == null or not me.state.alive or me.state.melee_cooldown > 0 \
			or (input.touch_held & PlayerCommand.Held.FIRE) == 0 or _time < _touch_melee_at:
		return
	var eye := view.camera.global_position
	var ahead := -view.camera.global_basis.z
	var my_team := _team_of(local_id())
	for id: int in _visuals:
		var v: PlayerVisual = _visuals[id]
		if not v.visible or (my_team != GameMode.NO_TEAM and _team_of(id) == my_team):
			continue
		var to := v.global_position + Vector3(0.0, 1.0, 0.0) - eye
		if to.length() <= TOUCH_MELEE_RANGE and ahead.dot(to.normalized()) > 0.6:
			input.press(PlayerCommand.Action.MELEE)
			_touch_melee_at = _time + 0.3
			return


## The HUD's FPS and latency readout, refreshed twice a second.
func _update_stats() -> void:
	if _time < _stats_at:
		return
	_stats_at = _time + 0.5
	var rtt := roundi(client.clock.rtt_ms) if client != null else -1
	hud.set_stats(roundi(Engine.get_frames_per_second()), rtt)


## Scope (PLAN §2.3): the sim tightens the spread while aim is held; the view
## zooms, the HUD shows the scope and look slows down to match the zoom.
func _update_scope(s: PlayerSimState) -> void:
	if not s.alive:
		touch.scope_on = false
	var scoped := input.aim_held() and WeaponSim.can_scope(s)
	view.set_scope(s.weapon() if scoped else null)
	hud.set_scope(view.scope_amount, view.scope_overlay_visible())
	var weapon := s.weapon()
	var zoom := lerpf(1.0, weapon.scope_zoom, view.scope_amount) if weapon != null else 1.0
	input.look_scale = 1.0 / maxf(zoom, 1.0)


func _render_client(delta: float) -> void:
	var me := client.pred
	var s := me.state
	var prev := client.prev_state
	var from := prev if prev != null and prev.discontinuity_gen == s.discontinuity_gen else s
	var feet := from.position.lerp(s.position, client.alpha()) + client.correction_offset
	_ensure_arms()
	_update_scope(s)
	if s.alive:
		input.confirm_slot(s.weapon_slot)
	var kick := from.recoil.lerp(s.recoil, client.alpha())
	view.update_view(feet, me.config.eye_for(s.stance), input.look_yaw + kick.x, input.look_pitch + kick.y, s,
			me.current_weapon(), delta)
	var names := {}
	for p in client.roster:
		names[p.id] = p
	var seen := {}
	var states := client.remote_states()
	_remote_cache = states
	if view.third_person:
		seen[client.local_id] = true
		var mine: Dictionary = names.get(client.local_id, {"name": "", "bot": false, "character": 0, "color": 0})
		_own_visual(mine.name, false, mine.character, mine.color, client.local_id).update_from(prev, s, client.alpha(), _time)
	for id in states:
		var info: Dictionary = names.get(id, {"name": "?", "bot": false, "character": 0, "color": 0})
		seen[id] = true
		_visual_for(id, info.name, info.bot, info.character, info.color).update_from(null, states[id], 1.0, _time)
		audio.update_player(id, states[id], false, _is_ally(id))
	audio.update_player(client.local_id, s, true)
	_prune_visuals(seen)
	# Snapshot projectiles, moved along their velocity to the current server time.
	var ahead := (client.clock.server_time() - client.latest_snapshot.id) * Sim.TICK_DT
	var rockets := []
	for proj in client.projectiles:
		rockets.append({"id": proj.id, "weapon": proj.weapon, "position": proj.position + proj.velocity * ahead,
				"velocity": proj.velocity})
	effects.sync_projectiles(rockets, 1.0)
	pickups.sync(client.items, client.spot_ticks)
	if _game_mode() == GameMode.CTF:
		flag_visuals.sync(client.flags, _flag_bases, _flag_carrier_at)
	_update_pickup_prompt(s, client.items)
	var server_state := client.server_state if client.server_state != null else s
	# Health, shield and death come from the server; movement and ammo are predicted.
	var shown := s.copy()
	shown.shield = server_state.shield
	shown.health = server_state.health
	shown.alive = server_state.alive
	shown.spawn_protection_ticks = server_state.spawn_protection_ticks
	hud.update_state(shown, me.current_weapon(), client.score_of(client.local_id),
			ceili(server_state.respawn_tick - client.clock.server_time()))


## One line per minute in the log (`adb logcat -s godot`) for sustained
## tests against PLAN §3.10: frame-time percentiles, minute average fps,
## host tick time, network health and thermal status.
const HITCH_MS := 50.0


func _log_perf(delta: float) -> void:
	if _warming:
		return
	Platform.report_frame_work((Performance.get_monitor(Performance.TIME_PROCESS) \
			+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0 + RenderingServer.get_frame_setup_time_cpu())
	# Not during an AA benchmark: a step-down would change what it measures.
	if Settings.get_value("video", "adaptive_quality") and not _paused and not AaBench.running:
		var step := _adaptive.add_frame(delta, int(Settings.get_value("video", "fps_cap")))
		if not step.is_empty():
			Platform.perf_log("QUALITY step-down %s" % step)
	var now := Time.get_ticks_msec()
	if _perf_minute_start_ms == 0:
		_perf_minute_start_ms = now
	_perf_ms.add(delta * 1000.0)
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	_perf_gpu.add(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	_perf_cpu.add((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
	_perf_render_cpu.add(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
	_perf_frames += 1
	if delta * 1000.0 > HITCH_MS:
		_perf_hitches += 1
	_perf_peaks = _perf_peaks.max(Vector3i(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)), effects.live_particles))
	if now - _perf_minute_start_ms < 60000:
		return
	var seconds := (now - _perf_minute_start_ms) / 1000.0
	var line := "PERF mode=%s fps_avg=%.1f p50=%.1f p95=%.1f p99=%.1f hitches=%d" % [
		["offline", "host", "client"][config.mode], _perf_frames / seconds,
		_perf_ms.percentile(50.0), _perf_ms.percentile(95.0), _perf_ms.percentile(99.0), _perf_hitches]
	_perf_hitches = 0
	line += " spec_total=%d" % Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)
	line += " " + Diagnostics.section_report()
	line += " gpu_p50=%.1f gpu_p95=%.1f main_p50=%.1f main_p95=%.1f render_cpu_p50=%.1f render_cpu_p95=%.1f" % [
			_perf_gpu.percentile(50.0), _perf_gpu.percentile(95.0), _perf_cpu.percentile(50.0), _perf_cpu.percentile(95.0),
			_perf_render_cpu.percentile(50.0), _perf_render_cpu.percentile(95.0)]
	if server != null:
		line += " tick_p50=%.2f tick_p99=%.2f sim_p99=%.2f players=%d clients=%d" % [_tick_ms.percentile(50.0),
				_tick_ms.percentile(99.0), _sim_ms.percentile(99.0), server.world.players.size(), server.clients.size()]
		_tick_ms = FrameStats.new(3600)
		_sim_ms = FrameStats.new(3600)
	if client != null:
		line += " rtt=%.0f corrections=%d visible=%d snaps=%d" % [client.clock.rtt_ms, client.corrections,
				client.visible_corrections, client.snaps]
	line += " draws_max=%d prims_max=%d particles_max=%d tex_mib=%.0f" % [_perf_peaks.x, _perf_peaks.y, _perf_peaks.z,
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0]
	line += " thermal=%d headroom=%.2f scale=%.2f autopilot=%s" % [Platform.thermal_status(), Platform.thermal_headroom(),
			get_tree().root.scaling_3d_scale, Diagnostics.autopilot]
	_perf_peaks = Vector3i.ZERO
	Platform.perf_log(line)
	_perf_ms = FrameStats.new(7200)
	_perf_gpu = FrameStats.new(7200)
	_perf_cpu = FrameStats.new(7200)
	_perf_render_cpu = FrameStats.new(7200)
	_perf_frames = 0
	_perf_minute_start_ms = now


# --- Profile: results and partial tallies ---

func _track_tally(e: Dictionary) -> void:
	var match_id: int = server.match_id if server != null else client.match_id
	if match_id != _tally_match:
		_tally = MatchStats.new()
		_tally_match = match_id
		_results_applied = false
	for p in _roster():
		if not _tally.lines.has(p.id):
			_tally.add_player(p.id, p.name, p.bot, 0)
	_tally.on_event(e)


## Leaving (or losing the host) before RESULTS: save what we saw ourselves
## as an incomplete match; unconfirmed when the host vanished.
func _save_partial(confirmed: bool) -> void:
	var phase := server.phase if server != null else client.phase
	if spectating() or _results_applied or not (phase == MatchPhase.PLAYING or phase == MatchPhase.SUDDEN_DEATH):
		return
	var me := local_id()
	var l: MatchStats.Line = _tally.lines.get(me)
	if l == null:
		return
	var row := {"id": me, "bot": false, "name": l.name, "score": 0,
			"ticks_played": roundi(_time * Sim.TICK_RATE), "weapon_kills": l.weapon_kills}
	for k in Protocol.RESULT_COUNTERS:
		row[k] = l.get(k)
	var partial := {"result_id": "partial-%08x-%d" % [_tally_match, me], "winner": 0, "humans": 2, "players": [row]}
	Profile.apply_results(partial, me, false, confirmed)
	_results_applied = true


# --- Match UI: kill feed, death cam, scoreboard, results, timer ---

func _roster() -> Array:
	return server.roster() if server != null else client.roster


func _display_name(id: int) -> String:
	for p in _roster():
		if p.id == id:
			return ("[BOT] " if p.bot else "") + p.name
	return "?"


## Where another player is rendered right now (Vector3.INF if unknown).
func _position_of(id: int) -> Vector3:
	if server != null:
		var p: SimPlayer = server.world.players.get(id)
		return p.state.position if p != null else Vector3.INF
	var st: PlayerSimState = _remote_cache.get(id)
	return st.position if st != null else Vector3.INF


func _vitals_of(id: int) -> Vector2:
	if server != null:
		var p: SimPlayer = server.world.players.get(id)
		return Vector2(p.state.shield, p.state.health) if p != null else Vector2.ZERO
	var st: PlayerSimState = _remote_cache.get(id)
	return Vector2(st.shield, st.health) if st != null else Vector2.ZERO


## Where a flag carrier is drawn: us at our view, others as rendered.
func _flag_carrier_at(id: int) -> Vector3:
	# Driving: the case rides in the vehicle's bed (behind the cab), not over
	# the driver's head (the driver's out of sight inside).
	var world: SimWorld = server.world if server != null else null
	var p: SimPlayer = world.players.get(id) if world != null else null
	if p != null and p.state.vehicle >= 0 and p.state.vehicle < world.vehicles.size():
		var v: SimVehicle = world.vehicles[p.state.vehicle]
		var back := Vector3(sin(v.yaw), 0.0, cos(v.yaw))
		var bed := WorldTerrain.surface(p.state.position.x, p.state.position.z) if config.map == GameMode.CITY_MAP else p.state.position.y
		return Vector3(p.state.position.x, bed, p.state.position.z) + back * 1.3 + Vector3(0, 1.75 - HuntVisuals.CARRIED_LIFT + 0.55, 0)
	if id == local_id():
		var me := _local_player()
		return me.state.position if me != null else Vector3.INF
	var v: PlayerVisual = _visuals.get(id)
	return v.global_position if v != null else _position_of(id)


## The mode's objective line (PLAN §2.4): CTF flag status, co-op wave.
func _update_objective() -> void:
	var mode := _game_mode()
	if mode == GameMode.CTF:
		var flags: Array = server.world.flags if server != null else client.flags
		var my_team := _team_of(local_id())
		if flags.size() < 2 or my_team > 1:
			hud.set_objective("")
			return
		var own: Variant = flags[my_team]
		var enemy: Variant = flags[1 - my_team]
		if enemy.carrier == local_id():
			hud.set_objective(tr("CTF_CARRYING"), GameMode.team_color(1 - my_team))
		elif own.carrier != 0:
			hud.set_objective(tr("CTF_OUR_FLAG_TAKEN") % _display_name(own.carrier), UiStyle.WARN)
		elif _flag_dropped(own):
			hud.set_objective(tr("CTF_OUR_FLAG_DROPPED") % ceili(_flag_return_ticks(own) / float(Sim.TICK_RATE)), UiStyle.WARN)
		elif enemy.carrier != 0:
			hud.set_objective(tr("CTF_WE_HAVE_FLAG") % _display_name(enemy.carrier), GameMode.team_color(my_team))
		else:
			hud.set_objective(tr("CTF_GOAL"), UiStyle.TEXT_DIM)
	elif mode == GameMode.WAVES:
		var w: Dictionary = {}
		if server != null and server.waves != null:
			w = {"wave": server.waves.wave, "fighting": server.waves.fighting, "left": server.waves.enemies_left(),
					"next": server.waves.ticks_to_next()}
		elif client != null:
			w = client.wave
		if w.is_empty():
			hud.set_objective("")
		elif w.fighting:
			hud.set_objective(tr("WAVES_FIGHTING") % [w.wave, Balance.MODES.wave_count, w.left], UiStyle.WARN)
		else:
			hud.set_objective(tr("WAVES_NEXT") % [w.wave + 1, ceili(w.next / float(Sim.TICK_RATE))], UiStyle.ACCENT)
	elif mode == GameMode.HUNT and server != null and server.world.hunt != null:
		_update_hunt_objective(server.world.hunt, server.world.tick)
	else:
		hud.set_objective("")


## THE HUNT's contracts menu: each row is a HuntRules.request(), the same
## entry point bots use.
func _build_hunt_menu(layer: CanvasLayer) -> void:
	view.third_person = true
	hunt_hud = HuntHud.new()
	hunt_hud.hud = hud
	hud.hunt_style = true
	hud.attacker_position = _position_of
	layer.add_child(hunt_hud)
	layer.move_child(hunt_hud, hud.get_index() + 1)
	if config.map == GameMode.CITY_MAP:
		hunt_hud.use_world_map(Vector2(210, 160), 200.0)
	hunt_hud.state = func() -> Dictionary:
		if server == null or server.world == null or server.world.hunt == null:
			return {}
		return {"hunt": server.world.hunt, "world": server.world, "me": local_id(), "yaw": input.look_yaw}
	# The feed sits under the cash / weapon stack.
	_kill_feed.offset_top = 300.0
	hunt_menu = HuntMenu.new()
	layer.add_child(hunt_menu)
	hunt_menu.state = func() -> Dictionary:
		if server == null or server.world == null or server.world.hunt == null:
			return {}
		return {"hunt": server.world.hunt, "world": server.world, "me": local_id()}
	# The phone button sits on the left edge, above the thumb's stick area.
	hunt_menu.button_anchor = func() -> Vector2:
		return Vector2(26.0, hunt_hud.size.y * 0.42)
	# Pause: top right, left of the minimap, in the kit's style.
	var pause: Button = hud.get_node("%PauseButton")
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -292.0
	pause.offset_right = -228.0
	pause.offset_top = 24.0
	pause.offset_bottom = 76.0
	ComicUI.style_button(pause, ComicUI.YELLOW, 24)
	touch.ui_blocks = hunt_menu.blocks
	hunt_menu.request = func(action: String, args: Dictionary = {}) -> bool:
		var st: Dictionary = hunt_menu.state.call()
		return not st.is_empty() and (st.hunt as HuntRules).request(st.world, st.me, action, args)
	var econ := func() -> HuntEconomy:
		var st: Dictionary = hunt_menu.state.call()
		return (st.hunt as HuntRules).economy if not st.is_empty() else null
	hunt_menu.add_row(func() -> String: return tr("HUNT_MENU_HIRE") % HuntEconomy.MERC_COST,
			func() -> void: hunt_menu.request.call("hire_mercenary"),
			func() -> bool:
				var e: HuntEconomy = econ.call()
				return e != null and not e.contracts.has(local_id()) and e.credits.get(local_id(), 0) >= HuntEconomy.MERC_COST, "crew")
	for order: String in HuntEconomy.ORDER_IDS:
		hunt_menu.add_row(func() -> String: return tr("HUNT_MENU_ORDER_" + order.to_upper()),
				func() -> void: hunt_menu.request.call("merc_order", {"order": order}),
				func() -> bool:
					var e: HuntEconomy = econ.call()
					return e != null and e.contracts.has(local_id()) and HuntEconomy.ORDER_IDS[e.contracts[local_id()].order] != order, "crew")
	hunt_menu.add_row(func() -> String: return tr("HUNT_MENU_DISMISS"),
			func() -> void: hunt_menu.request.call("dismiss_merc"),
			func() -> bool:
				var e: HuntEconomy = econ.call()
				return e != null and e.contracts.has(local_id()), "crew")
	# Your squad (HuntSquad): a plan in one tap, orders to everyone or to one
	# role, the rules of engagement, together or spread out.
	var my_squad := func() -> HuntSquad.Squad:
		var st: Dictionary = hunt_menu.state.call()
		return (st.hunt as HuntRules).squad.squad_of(local_id()) if not st.is_empty() else null
	for plan: String in HuntSquad.STRATEGY_IDS:
		hunt_menu.add_row(func() -> String: return tr("SQUAD_PLAN") % tr("SQUAD_STRATEGY_" + plan.to_upper()),
				func() -> void: hunt_menu.request.call("squad_strategy", {"strategy": plan}),
				func() -> bool:
					var sq: HuntSquad.Squad = my_squad.call()
					return sq != null and sq.strategy != plan, "squad")
	for order: String in HuntSquad.ORDER_IDS:
		hunt_menu.add_row(func() -> String: return tr("SQUAD_ALL") % tr("SQUAD_ORDER_" + order.to_upper()),
				func() -> void: hunt_menu.request.call("squad_order", {"order": order, "target": _nearest_hunter()}),
				func() -> bool: return my_squad.call() != null, "squad")
	for role: String in HuntSquad.ROLE_IDS:
		for order: String in ["follow", "hold", "fetch", "attack"]:
			hunt_menu.add_row(func() -> String: return tr("SQUAD_ONE") % [tr("SQUAD_ROLE_" + role.to_upper()),
						tr("SQUAD_ORDER_" + order.to_upper())],
					func() -> void: hunt_menu.request.call("squad_order", {"order": order, "role": role, "target": _nearest_hunter()}),
					func() -> bool:
						var sq: HuntSquad.Squad = my_squad.call()
						if sq == null:
							return false
						for m in sq.members:
							if m.role == role:
								return true
						return false, "squad")
	for rule: String in HuntSquad.RULE_IDS:
		hunt_menu.add_row(func() -> String: return tr("SQUAD_RULE") % tr("SQUAD_RULE_" + rule.to_upper()),
				func() -> void: hunt_menu.request.call("squad_rule", {"rule": rule}),
				func() -> bool:
					var sq: HuntSquad.Squad = my_squad.call()
					return sq != null and HuntSquad.RULE_IDS[sq.rule] != rule, "squad")
	for spread: String in HuntSquad.SPREAD_IDS:
		hunt_menu.add_row(func() -> String: return tr("SQUAD_SPREAD_" + spread.to_upper()),
				func() -> void: hunt_menu.request.call("squad_spread", {"spread": spread}),
				func() -> bool:
					var sq: HuntSquad.Squad = my_squad.call()
					return sq != null and HuntSquad.SPREAD_IDS[sq.spread] != spread, "squad")
	# Alliances: propose to the nearest hunter, answer a proposal.
	hunt_menu.add_row(func() -> String:
				var to := _nearest_hunter()
				return tr("HUNT_MENU_PROPOSE") % _display_name(to) if to != 0 else tr("HUNT_MENU_PROPOSE_NONE"),
			func() -> void: hunt_menu.request.call("propose_alliance", {"target": _nearest_hunter()}),
			func() -> bool:
				var st: Dictionary = hunt_menu.state.call()
				return not st.is_empty() and _nearest_hunter() != 0 and not (st.hunt as HuntRules).social.allies.has(local_id()), "deals")
	for accept: bool in [true, false]:
		hunt_menu.add_row(func() -> String:
					var st: Dictionary = hunt_menu.state.call()
					var offer: Dictionary = (st.hunt as HuntRules).social.proposals.get(local_id(), {}) if not st.is_empty() else {}
					var from := _display_name(int(offer.from)) if not offer.is_empty() else "—"
					return tr("HUNT_MENU_ACCEPT" if accept else "HUNT_MENU_REJECT") % from,
				func() -> void: hunt_menu.request.call("respond_alliance", {"accept": accept}),
				func() -> bool:
					var st: Dictionary = hunt_menu.state.call()
					return not st.is_empty() and (st.hunt as HuntRules).social.proposals.has(local_id()), "deals")
	# Double-Cross: end the alliance with notice, or betray it.
	for betray: bool in [false, true]:
		hunt_menu.add_row(func() -> String:
					var st: Dictionary = hunt_menu.state.call()
					var partner: int = (st.hunt as HuntRules).social.allies.get(local_id(), 0) if not st.is_empty() else 0
					return tr("HUNT_MENU_BETRAY" if betray else "HUNT_MENU_LEAVE") % (_display_name(partner) if partner != 0 else "—"),
				func() -> void: hunt_menu.request.call("betray_alliance" if betray else "leave_alliance"),
				func() -> bool:
					var st: Dictionary = hunt_menu.state.call()
					return not st.is_empty() and (st.hunt as HuntRules).social.allies.has(local_id()) \
							and not (st.hunt as HuntRules).social.dissolving.has(local_id()), "deals")
	# Informant: buy intelligence.
	for kind: String in HuntEconomy.INTEL_IDS:
		hunt_menu.add_row(func() -> String: return tr("HUNT_MENU_INTEL_" + kind.to_upper()) % HuntEconomy.INTEL[kind].cost,
				func() -> void: hunt_menu.request.call("buy_intel", {"kind": kind}),
				func() -> bool:
					var e: HuntEconomy = econ.call()
					return e != null and e.credits.get(local_id(), 0) >= int(HuntEconomy.INTEL[kind].cost), "intel")
	hunt_menu.add_row(func() -> String: return tr("HUNT_MENU_BOUNTY"),
			func() -> void: hunt_menu.request.call("accept_bounty", {"target": _nearest_wanted()}),
			func() -> bool: return _nearest_wanted() != 0, "jobs")


## Informant: our newest report of `kind`, in words (with its confidence).
func _intel_text(kind: String) -> String:
	var h := server.world.hunt
	for r: Dictionary in h.economy.intel_of(local_id(), server.world.tick):
		if r.kind != kind:
			continue
		var conf := int(round(float(r.confidence) * 100.0))
		match kind:
			"cache_clue":
				return tr("HUNT_INTEL_CACHE") % [tr(HuntResources.TYPES[r.resource].name_key), conf]
			"vault_status":
				if r.carrier != 0:
					return tr("HUNT_INTEL_VAULT_CARRIED") % _display_name(int(r.carrier))
				if int(r.back_in) > 0:
					return tr("HUNT_INTEL_VAULT_BACK") % ceili(int(r.back_in) / float(Sim.TICK_RATE))
				if int(r.unlocking) != 0:
					return tr("HUNT_INTEL_VAULT_UNLOCKING") % _display_name(int(r.unlocking))
				return tr("HUNT_INTEL_VAULT_LOCKED")
			"rival_position":
				return tr("HUNT_INTEL_RIVAL") % [_display_name(int(r.subject)),
						tr("HUNT_INTEL_CARRYING") if r.carrying else "", conf]
	return tr("HUNT_INTEL_NONE")


## The nearest other hunter we can see (not a mercenary), for proposals.
func _nearest_hunter() -> int:
	if server == null or server.world.hunt == null:
		return 0
	var h := server.world.hunt
	var me := local_id()
	var at := _position_of(me)
	var best := 0
	var best_d := 30.0
	for id: int in server.world.players:
		var p: SimPlayer = server.world.players[id]
		if id == me or not p.state.alive or h.economy.is_merc(id):
			continue
		var d := at.distance_to(p.state.position)
		if d < best_d:
			best_d = d
			best = id
	return best


## The Wanted rival whose last-known position is nearest (0: none).
func _nearest_wanted() -> int:
	if server == null or server.world.hunt == null:
		return 0
	var social := server.world.hunt.social
	var me := local_id()
	var at := _position_of(me)
	var best := 0
	var best_d := INF
	for id: int in social.last_known:
		if id != me and social.is_wanted(id) and social.contracts.get(me, 0) != id:
			var d := at.distance_to(social.last_known[id].position)
			if d < best_d:
				best_d = d
				best = id
	return best


## THE HUNT's objective line: what we carry (and the extraction count), the
## alarm, or how many of our assignments are left.
func _update_hunt_objective(h: HuntRules, tick: int) -> void:
	var me := local_id()
	var carried := h.carried_by(me)
	# The guided first run (Guide): one step at a time, with the distance.
	var career := Profile.career()
	if int(career.d.runs) == 0 and h.extract_progress.get(me, 0) == 0 and h.social.proposals.get(me, {}).is_empty():
		var at := _position_of(me)
		var obj := Guide.run_objective(career, h, me, at, tick)
		hud.set_objective(tr("GUIDE_STEP") % obj.step + "  " + str(obj.text) + Guide.distance_text(at, obj.target),
				UiStyle.ACCENT)
		return
	if carried != null:
		var what := _treasure_name(carried, me)
		var progress: int = h.extract_progress.get(me, 0)
		if progress > 0:
			var left := ceili((HuntRules.EXTRACT_TICKS - progress) / float(Sim.TICK_RATE))
			hud.set_objective(tr("HUNT_OBJ_EXTRACTING") % [what, left], HuntHud.PAD)
		else:
			hud.set_objective(tr("HUNT_OBJ_CARRY") % what, HuntHud.GRAND if carried.kind == HuntRules.Kind.GRAND else HuntHud.OWN)
		return
	var offer: Dictionary = h.social.proposals.get(me, {})
	if not offer.is_empty():
		hud.set_objective(tr("HUNT_PROPOSAL") % [_display_name(int(offer.from)), h.social.rep_of(int(offer.from))],
				UiStyle.ACCENT)
		return
	var ally: int = h.social.allies.get(me, 0)
	if ally != 0 and carried == null and h.cache_of(me) == null and h.vault_unlocker != me \
			and not h.final_phase(tick) and h.stolen_from_hunter(me) == null:
		hud.set_objective(tr("HUNT_ALLIED_WITH") % _display_name(ally), UiStyle.GOOD)
		return
	if h.vault_unlocker == me:
		hud.set_objective(tr("HUNT_UNLOCKING") % ceili((h.vault_ticks() - h.vault_progress)
				/ float(Sim.TICK_RATE)), UiStyle.GOOD)
		return
	var cache := h.cache_of(me)
	if cache != null:
		var res: Dictionary = HuntResources.TYPES[cache.resource]
		hud.set_objective(tr("HUNT_COLLECTING") % [tr(res.name_key),
				ceili((int(res.collect_ticks) - cache.progress) / float(Sim.TICK_RATE))], UiStyle.GOOD)
		return
	if h.final_phase(tick):
		var secs := ceili(h.ticks_left(tick) / float(Sim.TICK_RATE))
		hud.set_objective(tr("HUNT_LAST_EXTRACTION") % secs if tick >= h.end_tick - HuntRules.LAST_EXTRACTION_TICKS
				else tr("HUNT_EXTRACTION_CLOSING") % (secs - HuntRules.LAST_EXTRACTION_TICKS / Sim.TICK_RATE), UiStyle.WARN)
		return
	var stolen := h.stolen_from_hunter(me)
	if stolen != null and stolen.carrier != 0 and stolen.carrier != me:
		var clue: Dictionary = h.recovery_clues.get(me, {})
		var age := (tick - int(clue.tick)) / Sim.TICK_RATE if not clue.is_empty() else -1
		hud.set_objective(tr("HUNT_RECOVER") % [_treasure_name(stolen, me), age] if age >= 0
				else tr("HUNT_RECOVER_NO_CLUE") % _treasure_name(stolen, me), HuntVisuals.OWN)
		return
	if h.social.is_wanted(me):
		hud.set_objective(tr("HUNT_WANTED_SELF") % h.social.bounty.get(me, 0), UiStyle.WARN)
		return
	if h.is_revealed(me, tick):
		hud.set_objective(tr("HUNT_REVEALED"), UiStyle.WARN)
		return
	var left := 0
	for t: HuntRules.Treasure in h.assignments_of(me):
		left += 0 if t.banked else 1
	if left > 0:
		hud.set_objective(tr("HUNT_OBJ_FIND") % left, HuntHud.OWN)
	else:
		hud.set_objective(tr("HUNT_OBJ_DONE"), HuntHud.DANGER)


func _treasure_name(t: HuntRules.Treasure, me: int) -> String:
	if t.kind == HuntRules.Kind.GRAND:
		return tr("HUNT_TREASURE_GRAND")
	if t.kind == HuntRules.Kind.PROOF:
		return tr("HUNT_TREASURE_PROOF")
	if t.kind == HuntRules.Kind.RESOURCE and HuntResources.has(t.resource):
		return tr(HuntResources.TYPES[t.resource].name_key)
	return tr("HUNT_TREASURE_OWN") if t.owner == me else tr("HUNT_TREASURE_RIVAL")


## THE HUNT events: kill-feed lines, captions and cues.
## THE HUNT's squad (docs/game-plan.md): once the run has seated its
## nations, the AI take names from their nations' rosters and their
## characters (Nations.personality), and your squadmate the career's pacing
## (whether it may turn on you this run, and any grudge it holds).
var _squad_done := false
var _squadmate := ""       ## this run's squadmate's name
var _squad_outcome := ""   ## "", "turned_on_me" or "i_turned" (Career.record_squad_run)


func _setup_squad() -> void:
	if _squad_done or server == null or server.world.hunt == null or server.world.hunt.nations.is_empty():
		return
	_squad_done = true
	var h := server.world.hunt
	var career := Profile.career()
	var me := ServerSession.LOCAL_PLAYER_ID
	var mate: int = h.social.allies.get(me, 0) if h.social.is_squad(me) else 0
	var used := {}
	if mate != 0:
		_squadmate = career.pick_squadmate(server.world.match_seed)
		used[_squadmate] = true
	var ids: Array = h.nations.keys()
	ids.sort()
	for id: int in ids:
		var p: SimPlayer = server.world.players.get(id)
		if p == null or not p.is_bot:
			continue
		var who := _squadmate if id == mate else _roster_name(h.nation_of(id), used, server.world.match_seed + id)
		if who.is_empty():
			continue
		used[who] = true
		server.rename_bot(id, who)
		h.personalities[id] = Nations.personality(who)
		_rebuild[id] = true  # the body and nameplate take the new name and colours
	if mate != 0:
		h.may_turn[mate] = career.squadmate_may_turn(_squadmate)
		h.grudges[mate] = career.grudge(_squadmate)
		var line := tr("SQUAD_GRUDGE") if career.grudge(_squadmate) else tr("SQUAD_WITH")
		_kill_feed.add_note(_squadmate, line, Nations.color(career.nation()), true)


func _roster_name(nation: int, used: Dictionary, seed_value: int) -> String:
	var free := Nations.names(nation).filter(func(n: String) -> bool: return not used.has(n))
	return free[absi(seed_value) % free.size()] if not free.is_empty() else ""


## Down at someone's hands in a run or out in the valley: robbed (Career
## .robbed, decision 4). The Marshals' arrest is its own thing (busted).
func _on_local_death(e: Dictionary) -> void:
	if server == null or (config.game_mode != GameMode.HUNT and config.game_mode != GameMode.CITY):
		return
	var killer := int(e.killer)
	if killer == 0 or killer == local_id() or _display_name(killer).contains(CityMode.POLICE):
		return
	var lost := Profile.career().robbed()
	if lost.items.is_empty() and lost.gear.is_empty():
		return
	config.primary = 0
	server.set_primary(local_id(), 0)  # your nation re-issues the Pulse
	Profile.save()
	var n := 0
	for k: String in lost.items:
		n += int(lost.items[k])
	_kill_feed.add_note(tr("ROBBED_TITLE"), tr("ROBBED_TEXT") % n, UiStyle.DANGER, true)


func _on_hunt_event(e: Dictionary, me: int) -> void:
	var who := _display_name(e.player) if e.player != 0 else ""
	var color := HuntVisuals.GRAND if e.kind == HuntRules.Kind.GRAND else (HuntVisuals.ALARM if e.kind == HuntRules.Kind.PROOF \
			else (HuntVisuals.OWN if e.get("owner", 0) == me else HuntVisuals.RIVAL))
	var t := HuntRules.Treasure.new()
	t.kind = e.kind if e.kind >= 0 else HuntRules.Kind.PERSONAL
	t.owner = e.get("owner", 0)
	var what := _treasure_name(t, me)
	match e.action:
		"stow":
			if e.player == me:
				hud.show_caption(tr("HUNT_STOWED") % what)
			return
		"search":
			if e.player == me:
				hud.show_caption(tr("HUNT_SEARCHING"))
			return
		"unstow":
			if e.player == me:
				_kill_feed.add_note("", tr("HUNT_UNSTOWED") % what, color, true)
			elif int(e.get("from", 0)) == me:
				_kill_feed.add_note(who, tr("HUNT_HOLD_ROBBED") % what, UiStyle.WARN, true)
			return
		"take":
			_kill_feed.add_note(who, tr("HUNT_FEED_TAKE") % what, color, e.player == me)
			if e.player == me:
				audio.play_ui("pickup", -4.0)
				if e.kind == HuntRules.Kind.GRAND:
					_hunt_banner("HUNT_BANNER_GRAND", tr("HUNT_BANNER_GRAND_SUB"), HuntHud.GRAND)
		"drop":
			_kill_feed.add_note(who, tr("HUNT_FEED_DROP") % what, color, e.player == me)
		"steal":
			_kill_feed.add_note(who, tr("HUNT_FEED_STEAL") % what, UiStyle.WARN, e.player == me or e.victim == me)
			audio.play_ui("shield_break")
			if e.player == me:
				_hunt_banner("HUNT_BANNER_STOLE", tr("HUNT_BANNER_STOLE_SUB"), HuntHud.OWN)
			elif e.victim == me:
				_hunt_banner("HUNT_BANNER_ROBBED", tr("HUNT_BANNER_ROBBED_SUB") % who, HuntHud.DANGER)
		"extract":
			_kill_feed.add_note(who, tr("HUNT_FEED_EXTRACT") % [what, e.points], UiStyle.GOOD, e.player == me)
			audio.play_ui("kill_confirm")
			if e.player == me:
				_hunt_banner("HUNT_BANNER_EXTRACTED", tr("HUNT_BANNER_REWARD") % [e.points,
						roundi(int(e.points) * HuntEconomy.EXTRACT_CREDIT_SHARE)], HuntHud.GRAND)
		"alarm":
			_kill_feed.add_note(who, tr("HUNT_FEED_ALARM"), HuntVisuals.ALARM, e.player == me)
			audio.play_ui("countdown")
		"grand_ready":
			_kill_feed.add_note("", tr("HUNT_FEED_GRAND_READY"), HuntVisuals.GRAND)
		"bounty":
			# Only the moment someone becomes Wanted, or our own bounty grows.
			var crossed: bool = e.wanted and int(e.bounty) - int(e.amount) < HuntSocial.WANTED_BOUNTY
			if crossed:
				_kill_feed.add_note(who, tr("HUNT_FEED_WANTED") % e.bounty, HuntVisuals.ALARM, e.player == me)
				if e.player == me:
					_hunt_banner("HUNT_BANNER_WANTED", tr("HUNT_BANNER_WANTED_SUB") % e.bounty, HuntHud.DANGER)
				audio.play_ui("shield_break" if e.player == me else "countdown")
			elif e.player == me:
				_kill_feed.add_note(who, tr("HUNT_FEED_BOUNTY_UP") % [e.amount, e.bounty], HuntVisuals.ALARM, true)
			return
		"contract":
			if e.player == me:
				_kill_feed.add_note(who, tr("HUNT_FEED_CONTRACT") % _display_name(e.target), HuntVisuals.ALARM, true)
			return
		"bounty_proof":
			_kill_feed.add_note(who, tr("HUNT_FEED_BOUNTY_CLAIMED") % [_display_name(e.victim), e.points],
					HuntVisuals.ALARM, e.player == me or e.victim == me)
			if e.player == me:
				_hunt_banner("HUNT_BANNER_BOUNTY", tr("HUNT_BANNER_BOUNTY_SUB") % e.points, HuntHud.GRAND)
		"proof_destroyed", "proof_expired", "recovery_clue", "recovery_closed", "clock":
			return
		"final_warning":
			_kill_feed.add_note("", tr("HUNT_FEED_FINAL_WARNING"), UiStyle.WARN)
			audio.play_ui("countdown")
			return
		"last_extraction":
			_kill_feed.add_note("", tr("HUNT_FEED_LAST_EXTRACTION"), UiStyle.WARN)
			audio.play_ui("shield_break")
			_hunt_banner("HUNT_BANNER_LAST", tr("HUNT_BANNER_LAST_SUB"), UiStyle.WARN)
		"squad_formed", "squad_order", "squad_rule", "squad_spread", "squad_strategy", "squad_down", "squad_spotted":
			if e.player == me:
				var line := ""
				match e.action:
					"squad_order":
						var to := tr("SQUAD_ORDER_" + str(e.order).to_upper())
						line = tr("SQUAD_FEED_ORDER") % [to if str(e.role) == "" else "%s: %s" % [tr("SQUAD_ROLE_" + str(e.role).to_upper()), to]]
					"squad_rule":
						line = tr("SQUAD_FEED_RULE") % tr("SQUAD_RULE_" + str(e.rule).to_upper())
					"squad_spread":
						line = tr("SQUAD_SPREAD_" + str(e.spread).to_upper())
					"squad_strategy":
						line = tr("SQUAD_FEED_PLAN") % tr("SQUAD_STRATEGY_" + str(e.strategy).to_upper())
						_hunt_banner("SQUAD_STRATEGY_" + str(e.strategy).to_upper(), tr("SQUAD_STRATEGY_" + str(e.strategy).to_upper() + "_SUB"), HuntHud.ALLY)
					"squad_down":
						line = tr("SQUAD_FEED_DOWN") % tr("SQUAD_ROLE_" + str(e.role).to_upper())
					"squad_spotted":
						line = tr("SQUAD_FEED_SPOTTED") % _display_name(int(e.target))
				if not line.is_empty():
					_kill_feed.add_note("", line, HuntHud.ALLY, true)
			return
		"merc_hired", "merc_order", "merc_ended":
			if e.player == me:
				var key: String = {"merc_hired": "HUNT_FEED_MERC_HIRED", "merc_order": "HUNT_FEED_MERC_ORDER",
						"merc_ended": "HUNT_FEED_MERC_ENDED"}[e.action]
				var detail: String = str(e.get("order", e.get("reason", "")))
				_kill_feed.add_note("", tr(key) % tr("HUNT_WORD_" + detail.to_upper()) if detail != "" else tr(key),
						UiStyle.ACCENT, true)
			return
		"credits":
			return
		"intel":
			if e.player == me:
				_kill_feed.add_note("", _intel_text(e.intel), Color(0.75, 0.55, 1.0), true)
			return
		"cache_spawned":
			var res: Dictionary = HuntResources.TYPES.get(e.resource, {})
			if not res.is_empty():
				_kill_feed.add_note("", tr("HUNT_FEED_CACHE") % [tr(res.name_key), res.points], HuntVisuals.CACHE)
			return
		"cache_started", "vault_unlocking":
			return
		"vault_open":
			_kill_feed.add_note("", tr("HUNT_FEED_VAULT_OPEN"), HuntVisuals.GRAND)
			return
		"pit_rule":
			var key: String = ["PIT_STANDARD", "PIT_ORE_SEAM", "PIT_ONE_PAD", "PIT_HOT_VAULT"][clampi(int(e.rule), 0, 3)]
			_hunt_banner(key, tr(key + "_SUB"), HuntHud.GRAND)
			_kill_feed.add_note("", tr(key + "_SUB"), UiStyle.WARN)
			return
		"vault_interrupted":
			if e.player == me:
				_kill_feed.add_note("", tr("HUNT_FEED_UNLOCK_INTERRUPTED"), UiStyle.WARN, true)
			return
		"vault_unlocked":
			_kill_feed.add_note(who, tr("HUNT_FEED_VAULT_UNLOCKED"), HuntVisuals.GRAND, e.player == me)
			if e.player == me:
				_hunt_banner("HUNT_BANNER_VAULT", tr("HUNT_BANNER_VAULT_SUB"), HuntHud.GRAND)
			return
		"alliance_proposed":
			if e.target == me:
				_kill_feed.add_note(who, tr("HUNT_FEED_PROPOSED_YOU"), UiStyle.ACCENT, true)
				audio.play_ui("countdown")
			return
		"alliance_formed":
			_kill_feed.add_note(who, tr("HUNT_FEED_ALLIED") % _display_name(e.target), UiStyle.GOOD,
					e.player == me or e.target == me)
			return
		"alliance_rejected":
			if e.target == me:
				_kill_feed.add_note(who, tr("HUNT_FEED_REJECTED"), UiStyle.TEXT_DIM, true)
			return
		"alliance_leaving":
			if e.target == me or e.player == me:
				_kill_feed.add_note(who, tr("HUNT_FEED_LEAVING"), UiStyle.TEXT_DIM, true)
			return
		"alliance_ended":
			return
		"alliance_betrayed":
			_kill_feed.add_note(who, tr("HUNT_FEED_BETRAYED") % _display_name(e.target), UiStyle.WARN,
					e.player == me or e.target == me)
			if e.get("squad", false) and (e.player == me or e.target == me):
				_squad_outcome = "i_turned" if e.player == me else "turned_on_me"
			if e.target == me:
				audio.play_ui("shield_break")
				# Each way of turning reads as what it is (never the same scene).
				var key: String = {"fire": "HUNT_TURNED_FIRE", "grudge": "HUNT_TURNED_GRUDGE", "prize": "HUNT_TURNED_PRIZE",
						"grand": "HUNT_TURNED_GRAND"}.get(str(e.get("reason", "")), "HUNT_BETRAYED_YOU")
				hud.show_caption(tr(key) % who)
			elif e.player == me and e.get("squad", false):
				hud.show_caption(tr("HUNT_YOU_TURNED") % _display_name(e.target))
			return
		"squad_formed":
			return
		"friendly_fire":
			if e.player == me:
				hud.show_caption(tr("HUNT_FF_HOLD") % _display_name(e.target))
			elif e.target == me:
				hud.show_caption(tr("HUNT_FF_WATCH") % who)
			return
		"cooperation_bonus":
			_kill_feed.add_note(who, tr("HUNT_FEED_COOP_BONUS") % e.points, UiStyle.GOOD, e.player == me)
			return
		"cache_interrupted":
			if e.player == me:
				_kill_feed.add_note("", tr("HUNT_FEED_CACHE_INTERRUPTED"), UiStyle.WARN, true)
			return
		"cache_collected":
			_kill_feed.add_note(who, tr("HUNT_FEED_CACHE_COLLECTED") % what, HuntVisuals.CACHE, e.player == me)
		"cargo_lost":
			if e.player == me:
				_kill_feed.add_note("", tr("HUNT_FEED_CARGO_LOST") % what, UiStyle.WARN, true)
			return
		"recovery_open":
			if e.player == me:
				_kill_feed.add_note(_display_name(e.thief), tr("HUNT_FEED_STOLE_YOURS") % what, UiStyle.WARN, true)
			return
		"recovered":
			_kill_feed.add_note(who, tr("HUNT_FEED_RECOVERED") % [what, e.points], UiStyle.GOOD, e.player == me)
			if e.player == me:
				_hunt_banner("HUNT_BANNER_RECOVERED", tr("HUNT_BANNER_REWARD") % [e.points,
						roundi(int(e.points) * HuntEconomy.EXTRACT_CREDIT_SHARE)], HuntHud.OWN)
		"recovery_failed":
			if e.player == me:
				_kill_feed.add_note("", tr("HUNT_FEED_RECOVERY_FAILED") % what, UiStyle.WARN, true)
			return
		"wanted_ping":
			return  # drawn as a marker (HuntVisuals), not a feed line
		_:
			return
	effects.pickup_burst(e.position + Vector3(0.0, 0.8, 0.0), color)


## THE HUNT: the deployment settles into the persistent career from the
## server's own record of what we extracted (host only; once per result).
func _settle_career(result_id: String, me: int) -> void:
	if server == null or server.world.hunt == null or result_id.is_empty():
		return
	var career := Profile.career()
	if not result_id in career.d.settled:
		career.record_squad_run(_squadmate, _squad_outcome)  # before settle counts the run
	var report := career.settle(result_id, server.world.hunt.haul.get(me, []))
	if report.applied:
		career.d["last_report"] = report
		if bool(report.get("ruby_found", false)) and _kill_feed != null:
			_kill_feed.add_note(tr("RUBY_FOUND"), "", HuntHud.ALLY, true)  # the dig's rare find
		Profile.save()
		Log.i("career", "run settled: %s" % report)


func _movement() -> MovementConfig:
	return HUNT_MOVEMENT if config != null and (config.game_mode == GameMode.HUNT or config.game_mode == GameMode.CITY) else MOVEMENT


## THE HUNT: the suit's state goes back to the career when leaving a place.
func store_kit() -> void:
	if server == null or (config.game_mode != GameMode.HUNT and config.game_mode != GameMode.CITY):
		return
	var me := _local_player()
	if me == null:
		return
	var s := me.state
	Profile.career().store_kit(s.oxygen if s.alive else Survival.RESPAWN_OXYGEN, s.o2_spares, s.fatigue,
			s.water if s.alive else 60.0, s.water_spares, s.grenades, s.food if s.alive else 60.0)
	Profile.save()


## A friend who agreed to come along joins the run (a free contract to its
## end, like a hired gun with their name and the Hollow's colours).
func _bring_companion() -> void:
	var c := Profile.career()
	var who: String = c.d.get("companion", "")
	if config.game_mode != GameMode.HUNT or server.world.hunt == null or who.is_empty() or not c.is_friend(who):
		return
	var h := server.world.hunt
	if h.economy.bring_friend(server.world, ServerSession.LOCAL_PLAYER_ID, Career.PEOPLE[who].name, h.end_tick + 600):
		_kill_feed.add_note(Career.PEOPLE[who].name, tr("HUNT_FEED_FRIEND_JOINS"), HuntHud.ALLY, true)


## Your squad deploys with you (Career.squad, paid as it goes): AI
## teammates you command from the phone (HuntSquad).
func _bring_squad() -> void:
	if config.game_mode != GameMode.HUNT or server.world.hunt == null:
		return
	var roles := Profile.career().squad_deploy()
	if roles.is_empty():
		return
	if server.world.hunt.squad.form(server.world, ServerSession.LOCAL_PLAYER_ID, roles):
		Profile.save()
		_kill_feed.add_note("", tr("SQUAD_FEED_DEPLOYS") % roles.size(), HuntHud.ALLY, true)


## After a deployment's results: back to Tharsis Gate (once).
func _back_to_city() -> void:
	if _leaving:
		return
	store_kit()
	_leaving = true
	Profile.save()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MatchConfig.pending = MatchConfig.for_place(GameMode.CITY, config.player_name)
	# Back to free roam where the run ended (at the dig pad if we fell).
	var me := _local_player()
	MatchConfig.spawn_at = WorldLayout.dig_pad()
	if config.map == GameMode.CITY_MAP and me != null and me.state.alive:
		MatchConfig.spawn_at = me.state.position + Vector3(0, 0.3, 0)
	LoadingCover.change_scene(get_tree(), "res://game/match.tscn")


func _hunt_banner(title_key: String, sub: String, color: Color) -> void:
	if hunt_hud != null:
		hunt_hud.banner(tr(title_key), sub, color)


func _flag_dropped(f: Variant) -> bool:
	return f.carrier == 0 and (f.return_tick > 0 if f is SimWorld.Flag else f.return_ticks > 0)


func _flag_return_ticks(f: Variant) -> int:
	return maxi(f.return_tick - server.world.tick, 0) if f is SimWorld.Flag else int(f.return_ticks)


func _update_match_ui(delta: float) -> void:
	hud.set_view(view.global_position, input.look_yaw)
	var phase := server.phase if server != null else client.phase
	var ends := server.phase_ends_tick if server != null else client.phase_ends_tick
	var now := float(server.world.tick) if server != null else client.clock.server_time()
	var playing := phase == MatchPhase.PLAYING or phase == MatchPhase.SUDDEN_DEATH
	# Co-op has no clock: the waves end it.
	hud.set_timer(maxi(ceili((ends - now) / Sim.TICK_RATE), 0), playing and _game_mode() != GameMode.WAVES)
	_update_objective()
	var my_team := _team_of(local_id())
	# Co-op shows the wave instead (_update_objective).
	hud.set_teams(my_team, _team_scores() if my_team < 2 and _game_mode() != GameMode.WAVES else PackedInt32Array())
	var me := _local_player()
	if me != null:
		var names := PackedStringArray()
		for i in me.state.weapons.size():
			var w := me.state.weapon(i)
			names.append(KillFeed.weapon_tag(w.id) if KillFeed.WEAPON_TAGS.has(w.id) else tr(w.display_name))
		hud.set_slots(names, me.state.weapon_slot)
		_local_sounds(me.state)
	# Death cam: 3 s looking at the killer from where we died.
	var dead := me != null and not me.state.alive
	if dead and not _death_cam.is_empty() and _time < _death_cam.until:
		var killer_pos := _position_of(_death_cam.killer)
		if not _death_cam.suicide and killer_pos != Vector3.INF:
			view.death_cam(_death_cam.pos, killer_pos + Vector3(0.0, 1.3, 0.0), delta)
			var v := _vitals_of(_death_cam.killer)
			_death_label.text = "%s\n%s\n%s" % [tr("DEATH_KILLED_BY") % _display_name(_death_cam.killer),
					tr("DEATH_KILLER_STATUS") % [ceili(v.x), ceili(v.y)],
					tr("DEATH_DAMAGE") % [roundi(_life_dealt), roundi(_life_taken)]]
		else:
			_death_label.text = tr("DEATH_SUICIDE")
		_death_label.visible = true
	else:
		_death_label.visible = false
	var choosing := dead and not _results.visible
	input.keep_cursor = choosing
	if choosing != _loadout_bar.visible:
		_loadout_bar.visible = choosing
		if not Platform.is_mobile() and not _paused:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if choosing else Input.MOUSE_MODE_CAPTURED
			# Firing when we died: that button's release may land on the
			# loadout bar, so don't carry the held trigger into the respawn.
			input.release_mouse()
	_banner.visible = not _results.visible
	# Results until the next match starts; the scoreboard while held.
	if _results.visible:
		if phase != MatchPhase.POST_MATCH:
			_results.visible = false
		else:
			_results.footer.text = (_results.footer_extra + "\n" if not _results.footer_extra.is_empty() else "") \
					+ tr("RESULTS_NEXT_MATCH") % maxi(ceili(_results_until - _time), 0)
	var subtitle := tr(MatchPhase.label_key(phase)) if phase != MatchPhase.PLAYING else ""
	# Co-op waves has teams but no team score race (its progress is on the HUD).
	var team_scores := _team_scores() if GameMode.is_team_mode(_game_mode()) and _game_mode() != GameMode.WAVES \
			else PackedInt32Array()
	if Input.is_action_pressed("scoreboard") and not _results.visible and not _paused:
		_scoreboard.show_scoreboard(_roster(), local_id(), subtitle, team_scores)
	else:
		_scoreboard.visible = false
	# The pause menu shows the scores too (the way to see them on touch).
	if _paused:
		_pause_scores.show_scoreboard(_roster(), local_id(), subtitle, team_scores)


## Our own reload, weapon switch and shield recharge sounds, from state changes.
func _local_sounds(s: PlayerSimState) -> void:
	if s.weapon_slot != _last_slot and _last_slot >= 0 and s.alive:
		audio.play_ui("switch", -4.0)
	_last_slot = s.weapon_slot
	var reloading: int = s.reload[s.weapon_slot]
	var held := s.weapon()
	var shells := held != null and held.reload_per_round
	# Shell-by-shell reloads restart the timer for each shell.
	if reloading > 0 and (_last_reload == 0 or (shells and reloading > _last_reload)):
		audio.play_at("reload_shell" if shells else "reload", view.global_position, "UI", 2, -6.0)
	_last_reload = reloading
	var rising := s.shield > _last_shield + 0.01
	if rising and not _shield_rising and s.shield < Balance.PLAYER.max_shield * 0.5:
		audio.cue("shield_recharge", "CAPTION_SHIELD_RECHARGING")
	_shield_rising = rising
	_last_shield = s.shield


func _local_player() -> SimPlayer:
	if server != null:
		return server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	return client.pred


## `character`, `color`: the player's picks (CharacterRig.SELECTABLE and
## PlayerVisual.PALETTE indices); the visual is rebuilt if they change (a
## client may see a player before the roster arrives).
## Visuals to build again (a body changed): net id -> true.
var _rebuild := {}


func rebuild_visual(id: int) -> void:
	_rebuild[id] = true


func _visual_for(id: int, display_name: String, is_bot: bool, character: int, color_pick: int) -> PlayerVisual:
	var v: PlayerVisual = _visuals.get(id)
	var style := CharacterRig.selectable_style(character)
	if _game_mode() == GameMode.HUNT or _game_mode() == GameMode.CITY:
		style = "mercenary"  # THE HUNT's own contractors, not IONFALL's troopers
		# Uniforms: the Concern's raiders; the Hollow's militia and friends
		# who come along (RaidDirector, HuntEconomy.names).
		if display_name.begins_with(CityMode.POLICE):
			style = "marshal"  # the Kasei Marshals: Mars' police
		elif display_name.begins_with("Concern·") or display_name.begins_with("Xanadu·"):
			style = "concern"
		elif display_name.begins_with("Hollow·") or display_name.begins_with("Varga") or _is_friend_name(display_name):
			style = "militia"
	var team := _team_of(id)
	var color: Color = GameMode.team_color(team) if team < 2 else PlayerVisual.color_for(id, color_pick, is_bot)
	if id == local_id() and _game_mode() == GameMode.CITY and CityStyle.suit_color() != null:
		color = CityStyle.suit_color()  # the suit you wear (the Style menu)
	var nation := _nation_of(id)
	if nation != Nations.NONE:
		color = Nations.color(nation)  # a run: everyone wears their nation's colours
	if v != null and (v.rig_style != style or v.color != color or _rebuild.has(id)):
		_rebuild.erase(id)
		v.queue_free()
		v = null
	if v == null:
		v = PlayerVisual.new()
		add_child(v)
		# The body: yours is your choice (the career); everyone else's, half
		# and half (CharacterRig: odd variants are women).
		var variant := id
		if id == local_id() and (_game_mode() == GameMode.HUNT or _game_mode() == GameMode.CITY):
			variant = 1 if Profile.career().d.get("body", "male") == "female" else 0
		v.setup(display_name, is_bot, color, variant, style)
		if team < 2:
			v.set_label_color(color.lightened(0.35))
			v.set_team(team, color.lightened(0.35))
		_visuals[id] = v
		v.face_movement = _game_mode() == GameMode.HUNT or _game_mode() == GameMode.CITY
		v.holstered = _game_mode() == GameMode.CITY and (city == null or not city.raid_on())
	if nation != Nations.NONE:
		v.nameplate_color = Nations.color(nation).lightened(0.25)
		v.nameplate_nation = nation
		v.nameplate_squad = id != local_id() and server.world.hunt.social.allied(local_id(), id)
	return v


## A hunter's nation in a run (Nations.NONE outside one).
func _nation_of(id: int) -> int:
	if server == null or server.world.hunt == null:
		return Nations.NONE
	return server.world.hunt.nation_of(id)


static func _is_friend_name(n: String) -> bool:
	for who: String in Career.PEOPLE:
		if n == Career.PEOPLE[who].name:
			return true
	return false


## Third person: our own body (no nameplate), facing like everyone else's.
func _own_visual(display_name: String, is_bot: bool, character: int, color_pick: int, id: int = -1) -> PlayerVisual:
	var v := _visual_for(local_id() if id < 0 else id, display_name, is_bot, character, color_pick)
	v.hide_nameplate()
	return v


## A quality change that moves characters to another tier (MeshyRig.TIERS)
## rebuilds the players' bodies; the next frame makes them again.
func _rebuild_visuals_for_tier() -> void:
	var tier := MeshyRig.current_tier()
	if tier == _visual_tier:
		return
	_visual_tier = tier
	for id in _visuals:
		_visuals[id].queue_free()
	_visuals.clear()


func _prune_visuals(seen: Dictionary) -> void:
	for id in _visuals.keys():
		if not seen.has(id):
			_visuals[id].queue_free()
			_visuals.erase(id)
			audio.forget_player(id)


func _update_banner() -> void:
	var phase := server.phase if server != null else client.phase
	var ends := server.phase_ends_tick if server != null else client.phase_ends_tick
	var now := float(server.world.tick) if server != null else client.clock.server_time()
	var text := ""
	match phase:
		MatchPhase.WAITING:
			text = tr("PHASE_WAITING")
		MatchPhase.COUNTDOWN:
			text = tr("PHASE_COUNTDOWN") % maxi(ceili((ends - now) / Sim.TICK_RATE), 1)
		MatchPhase.POST_MATCH:
			text = tr("PHASE_POST_MATCH")
		MatchPhase.PLAYING:
			if _banner_phase == MatchPhase.COUNTDOWN:
				_go_until = _time + 1.2
			if _time < _go_until:
				text = tr("PHASE_GO")
	_banner_phase = phase
	text = text.to_upper()
	if text != _banner.text:
		_banner.text = text
		# Each new line (countdown numbers, FIGHT) pops in.
		_banner.pivot_offset = _banner.size * 0.5
		_banner.scale = Vector2(1.35, 1.35)
		_banner.modulate = UiStyle.ACCENT if phase == MatchPhase.PLAYING else Color.WHITE
		create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).tween_property(_banner, "scale", Vector2.ONE, 0.3)
		# Free roam has no match to start: no countdown beeps entering the city.
		if (phase == MatchPhase.COUNTDOWN or phase == MatchPhase.PLAYING) and config.game_mode != GameMode.CITY:
			audio.play_ui("go" if phase == MatchPhase.PLAYING else "countdown", -6.0)


func _handle_event(e: Dictionary) -> void:
	if not effects.first_time(e):
		return
	_track_tally(e)
	var me := local_id()
	if city != null:
		city.on_event(e)  # the valley's people and fighters react
	match e.type:
		"fire":
			var local: bool = e.shooter == me
			var sound := "arc_launch" if e.weapon == &"arc_launcher" else String(e.weapon)
			audio.play_at(sound, e.origin, "Weapons", 2 if local else 4, -4.0 if local else 0.0)
			if not local and e.origin.distance_to(view.global_position) < 25.0:
				hud.on_gunfire_from(e.origin)
			var muzzle := Vector3.INF
			if (not local or view.third_person) and _visuals.has(e.shooter):
				var shooter: PlayerVisual = _visuals[e.shooter]
				shooter.on_fire()
				muzzle = shooter.muzzle_position()
				if muzzle != Vector3.INF and e.weapon not in [&"melee", &"frag_grenade"]:
					effects.muzzle_flash(muzzle)
			if local and e.weapon == &"melee":
				view.melee()
			elif local and e.weapon == &"frag_grenade":
				view.throw()
			elif local:
				var heavy: bool = e.weapon in [&"arc_launcher", &"rail_sniper", &"scatter_gun"]
				view.kick(2.0 if heavy else 1.0)
				hud.on_fired(2.0 if heavy else 1.0)
				if e.get("predicted_hit", false):
					hud.on_hit_marker(false, false)
			if e.has("end"):
				var from: Vector3 = view.muzzle_position() if local and not view.third_person \
						else (muzzle if muzzle != Vector3.INF else e.origin)
				effects.tracer(from, e.end, e.weapon == &"rail_sniper")
				if e.hit_world or e.hit_player:
					effects.impact(e.end, e.hit_player)
		"explosion":
			effects.explosion(e.position, 4.0)
			audio.play_at("explosion", e.position, "World", 3)
		"hit":
			if _visuals.has(e.target) and e.target != me:
				(_visuals[e.target] as PlayerVisual).flash_hit(e.shield_broken, _position_of(e.attacker))
			# A graphic burst (no words) where a body is hit; bigger on a kill.
			if _game_mode() == GameMode.HUNT and e.target != me and _position_of(e.target) != Vector3.INF:
				effects.hit_burst(_position_of(e.target) + Vector3(0, 1.3, 0), e.killed)
			if e.attacker == me and e.target != me:
				hud.on_hit_marker(true, e.killed)
				audio.play_ui("kill_confirm" if e.killed else "hit_marker", -2.0)
				if view.meleeing():  # hits don't name the weapon; our bash is in flight
					view.melee_impact()
					audio.play_ui("melee_hit", 0.0)
				_life_dealt += e.amount
			if e.target == me:
				_life_taken += e.amount
				if e.attacker != me and _position_of(e.attacker) != Vector3.INF:
					hud.on_damaged_from(_position_of(e.attacker), e.attacker)
				else:
					hud.on_damaged()
				if e.shield_broken:
					hud.on_shield_broken()
					audio.cue("shield_break", "CAPTION_SHIELD_BROKEN")
		"death":
			if city == null or int(e.killer) == me or int(e.victim) == me:
				_kill_feed.add_death(e, _display_name, me)
			if e.victim != me and _visuals.has(e.victim):
				effects.derez(e.position, (_visuals[e.victim] as PlayerVisual).color)
			if e.victim == me:
				_death_cam = {"pos": e.position + Vector3(0.0, 1.6, 0.0), "killer": e.killer,
						"until": _time + DEATH_CAM_SECONDS, "suicide": e.suicide}
				_on_local_death(e)
		"results":
			_results.show_results(e, -1 if spectating() else me)
			_results_applied = true
			_results.footer_extra = ""
			if not spectating():  # watching earns nothing
				var gained := Profile.apply_results(e, me)
				_results.show_xp(gained, Profile.data.xp())
				_settle_career(str(e.get("result_id", "")), me)
			_results_until = _time + Balance.MODES.post_match_ticks / float(Sim.TICK_RATE)
		"spawn":
			if e.player == me:
				input.look_yaw = e.yaw
				input.look_pitch = 0.0
				_death_cam = {}
				_life_dealt = 0.0
				_life_taken = 0.0
				audio.play_ui("spawn", -6.0)
			elif _visuals.has(e.player):
				effects.spawn_in(e.position, (_visuals[e.player] as PlayerVisual).color)
				audio.play_at("spawn", e.position, "World", 1, -4.0)
		"flag":
			_on_flag_event(e, me)
		"hunt":
			_on_hunt_event(e, me)
		"wave":
			if e.action == "start":
				_kill_feed.add_note(tr("WAVES_WAVE") % e.wave, tr("WAVES_INCOMING") % e.enemies, UiStyle.WARN)
				audio.cue("countdown", tr("CAPTION_WAVE_START") % e.wave)
			else:
				_kill_feed.add_note(tr("WAVES_WAVE") % e.wave, tr("WAVES_CLEARED"), UiStyle.GOOD)
				audio.cue("go", "CAPTION_WAVE_CLEARED")
		"pickup":
			effects.pickup_burst(e.position + Vector3(0.0, 0.6, 0.0), PickupVisuals.color_of(e.weapon))
			if e.player == me:
				audio.play_ui("pickup", -4.0)
				var g := PickupItems.career_item(e)
				if not g.is_empty():
					Profile.career().receive_pickup(String(g.item), int(g.count))
			else:
				audio.play_at("pickup", e.position, "World", 1, -6.0)


## CTF events: a kill-feed line, a caption and a cue for the ones about us.
func _on_flag_event(e: Dictionary, me: int) -> void:
	var team: int = e.team
	var who := _display_name(e.player) if e.player != 0 else tr("CTF_NOBODY")
	var mine := team == _team_of(me)
	var keys := {"take": "CTF_FEED_TAKE", "drop": "CTF_FEED_DROP", "return": "CTF_FEED_RETURN", "capture": "CTF_FEED_CAPTURE"}
	var what: String = tr(keys[e.action]) % GameMode.team_name(team)
	var carrier_team: int = 1 - team if e.action in ["take", "drop", "capture"] else team
	_kill_feed.add_note(who, what, GameMode.team_color(carrier_team), e.player == me)
	if e.action == "take":
		audio.cue("shield_break", "CAPTION_OUR_FLAG_TAKEN" if mine else "CAPTION_FLAG_TAKEN")
	elif e.action == "capture":
		audio.cue("kill_confirm", "CAPTION_FLAG_LOST" if mine else "CAPTION_FLAG_CAPTURED")
	elif e.action == "return":
		audio.cue("pickup", "CAPTION_FLAG_RETURNED")
	effects.pickup_burst(e.position + Vector3(0.0, 0.8, 0.0), GameMode.team_color(team))


func _net_info() -> String:
	if client != null:
		var st := client.transport.stats
		var last_cmd := client.latest_snapshot.last_cmd_tick if client.latest_snapshot != null else 0
		return "NET client id %d  rtt %.0f ms  interp %d  rate %.3f\nlead %.1f ticks (pred %d, server %.1f, last cmd %d)  clock samples %d\nin %.1f kB/s  out %.1f kB/s (wire)  snapshot p50 %d max %d B\ncorrections %d  visible %d  snaps %d  bad snapshots %d" % [
			client.local_id, client.clock.rtt_ms, client.interp_ticks, client.rate(),
			client.pred_tick - client.clock.server_time(), client.pred_tick, client.clock.server_time(), last_cmd,
			client.clock.sample_count(),
			st.wire_bytes_in_per_s() / 1000.0, st.wire_bytes_out_per_s() / 1000.0,
			st.snapshot_sizes.percentile(50.0), st.max_snapshot,
			client.corrections, client.visible_corrections, client.snaps, client.undecodable_snapshots]
	if server != null and server.networked:
		var st := server.transport.stats
		var rtts := PackedStringArray()
		for c: ServerSession.Client in server.clients.values():
			rtts.append("%d:%.0fms" % [c.player_id, c.rtt_ms])
		return "NET host  clients %d [%s]\nin %.1f kB/s  out %.1f kB/s (wire)  snapshot p50 %d max %d B\nanomalies %d  ingress drops %d" % [
			server.clients.size(), " ".join(rtts), st.wire_bytes_in_per_s() / 1000.0, st.wire_bytes_out_per_s() / 1000.0,
			st.snapshot_sizes.percentile(50.0), st.max_snapshot, server.anomalies, server.transport.ingress_drops]
	return "NET offline"


# --- UI, pause, leaving ---

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var nameplates := Nameplates.new()
	nameplates.visuals = _visuals
	layer.add_child(nameplates)  # under the HUD
	hud = HUD_SCENE.instantiate()
	layer.add_child(hud)
	hud.pause_requested.connect(_set_paused.bind(true))
	_banner = _make_label(44, UiStyle.TEXT)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 120.0
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_banner)
	_info = _make_label(18, UiStyle.TEXT_DIM)
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_info.offset_top = -40.0
	_info.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(_info)
	_kill_feed = KillFeed.new()
	_kill_feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_kill_feed.offset_left = -560.0
	_kill_feed.offset_right = -24.0
	_kill_feed.offset_top = 176.0 if DisplayServer.is_touchscreen_available() else 24.0
	_kill_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	layer.add_child(_kill_feed)
	_death_label = _make_label(28, UiStyle.TEXT)
	_death_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_death_label.offset_top = -250.0
	_death_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_death_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_label.visible = false
	layer.add_child(_death_label)
	_loadout_bar = HBoxContainer.new()
	_loadout_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_loadout_bar.offset_top = -190.0
	_loadout_bar.offset_bottom = -120.0
	_loadout_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loadout_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_loadout_bar.add_theme_constant_override("separation", 12)
	_loadout_bar.visible = false
	var caption := _make_label(18, UiStyle.TEXT_DIM)
	caption.text = "LOADOUT_PRIMARY"
	_loadout_bar.add_child(caption)
	for i in Loadouts.PRIMARIES.size():
		var b := Button.new()
		b.text = Loadouts.PRIMARIES[i].display_name
		b.toggle_mode = true
		b.button_pressed = i == config.primary
		b.custom_minimum_size = Vector2(170, 56)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_choose_primary.bind(i))
		_loadout_bar.add_child(b)
	layer.add_child(_loadout_bar)
	if config.game_mode == GameMode.HUNT:
		_build_hunt_menu(layer)
	elif config.game_mode == GameMode.CITY:
		view.third_person = true
		hud.hunt_style = true  # no arena vitals or weapon card in the city
		hud.attacker_position = _position_of
		touch.hidden_ids = ["fire", "scope", "grenade", "crouch"]  # weapons holstered
		city = CityMode.new()
		city.match_node = self
		add_child(city)
		city.setup(layer)
	_scoreboard = MatchPanel.new()
	layer.add_child(_scoreboard)
	_results = MatchPanel.new()
	layer.add_child(_results)
	touch.input = input
	touch.hud_target = hud.touch_target
	layer.add_child(touch)
	if hunt_menu != null:
		layer.move_child(touch, hunt_menu.get_index())  # the open phone draws over the buttons
	_pause_panel = _make_pause_panel()
	layer.add_child(_pause_panel)
	_confirm_panel = _make_confirm_panel()
	layer.add_child(_confirm_panel)
	_settings_menu = SettingsMenu.new()
	layer.add_child(_settings_menu)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiStyle.font_display_bold)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_pause_panel() -> Control:
	var parts := UiStyle.menu_overlay()
	var root: Control = parts[0]
	var box: VBoxContainer = parts[1]
	root.visible = false
	box.add_child(UiStyle.label("PAUSE_TITLE", &"HeaderLabel"))
	var bar := ColorRect.new()
	bar.color = UiStyle.ACCENT
	bar.custom_minimum_size = Vector2(72, 4)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(bar)
	box.add_child(Control.new())
	var resume := UiStyle.menu_button("PAUSE_RESUME", &"PrimaryButton")
	resume.pressed.connect(_set_paused.bind(false))
	box.add_child(resume)
	root.visibility_changed.connect(func() -> void:
		if root.visible:
			resume.grab_focus())
	var settings := UiStyle.menu_button("MENU_SETTINGS")
	settings.pressed.connect(func() -> void: _settings_menu.open())
	box.add_child(settings)
	var leave := UiStyle.menu_button("PAUSE_LEAVE", &"GhostButton")
	leave.pressed.connect(_ask_leave)
	box.add_child(leave)
	var hint := UiStyle.label("PAUSE_CONTROLS_HINT", &"DimLabel")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.visible = not DisplayServer.is_touchscreen_available()
	box.add_child(Control.new())
	box.add_child(hint)
	if config.mode == MatchConfig.Mode.HOST:
		box.add_child(_make_join_code())
	_pause_scores = MatchPanel.new()
	# Centred in the space right of the button column.
	_pause_scores.anchor_left = 0.68
	_pause_scores.anchor_right = 0.68
	root.add_child(_pause_scores)
	return root


## Hosts show their join code under the pause buttons: the online invite
## code, or a LAN QR code (PLAN §3.6) that a phone camera opens as an
## ionfall://join link, which starts the game and joins.
func _make_join_code() -> Control:
	var addresses := Discovery.lan_addresses()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	if not _online_code.is_empty():
		box.add_child(UiStyle.label("PAUSE_INVITE_CODE", &"DimLabel", HORIZONTAL_ALIGNMENT_LEFT))
		var code := UiStyle.label(_online_code, &"TitleLabel", HORIZONTAL_ALIGNMENT_LEFT)
		box.add_child(code)
		return box
	if addresses.is_empty():
		return box
	var link := "ionfall://join?host=%s&port=%d" % [addresses[0], config.port]
	var qr := QrCode.encode(link)
	if qr == null:
		return box
	box.add_child(UiStyle.label("PAUSE_SCAN_TO_JOIN", &"DimLabel", HORIZONTAL_ALIGNMENT_LEFT))
	var tex := TextureRect.new()
	tex.texture = ImageTexture.create_from_image(qr.to_image(8))
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.custom_minimum_size = Vector2(170, 170)
	tex.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(tex)
	box.add_child(UiStyle.label("%s:%d" % [addresses[0], config.port], &"DimLabel", HORIZONTAL_ALIGNMENT_LEFT))
	return box


## Leaving an online match asks first (PLAN §3.5.1); offline just leaves.
func _ask_leave() -> void:
	if config.mode == MatchConfig.Mode.OFFLINE:
		_leave()
		return
	var label: Label = _confirm_panel.find_child("Text", true, false)
	label.text = tr("LEAVE_CONFIRM_HOST") if config.mode == MatchConfig.Mode.HOST else tr("LEAVE_CONFIRM_CLIENT")
	_confirm_panel.visible = true


func _make_confirm_panel() -> Control:
	var parts := UiStyle.menu_overlay()
	var root: Control = parts[0]
	var box: VBoxContainer = parts[1]
	box.name = "Box"
	root.visible = false
	var text := UiStyle.label("", &"HeaderLabel")
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.add_theme_font_size_override("font_size", 30)
	box.add_child(text)
	var no := UiStyle.menu_button("LEAVE_CONFIRM_NO", &"PrimaryButton")
	no.pressed.connect(func() -> void: root.visible = false)
	box.add_child(no)
	var yes := UiStyle.menu_button("LEAVE_CONFIRM_YES")
	yes.pressed.connect(_leave)
	box.add_child(yes)
	return root


## Offline, pausing stops the simulation. Online matches can't pause: the
## panel only stops local input (PLAN §3.5.1).
func _set_paused(paused: bool) -> void:
	if paused != _paused:
		Log.d("match", "paused" if paused else "resumed")
	_paused = paused
	_pause_panel.visible = paused
	_kill_feed.visible = not paused  # on touch it sits where the pause scoreboard opens
	if not paused:
		_confirm_panel.visible = false
	input.enabled = not paused and not spectating()
	input.reset_held()
	touch.release_all()
	if server != null and config.mode == MatchConfig.Mode.OFFLINE:
		server.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if paused or spectating():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not Platform.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Primary for the next spawn, saved to the profile (PLAN §2.5).
func _choose_primary(i: int) -> void:
	config.primary = i
	Settings.set_value("profile", "primary", i)
	Settings.save_settings()
	if server != null:
		server.set_primary(server.local_player_id, i)
	elif client != null:
		client.send_loadout(i)
	for k in Loadouts.PRIMARIES.size():
		(_loadout_bar.get_child(k + 1) as Button).button_pressed = k == i


## The lobby match is over (results shown): everyone goes back to the
## host's lobby. The host tells the clients first, then reopens the lobby on
## the same port or online game.
func _back_to_lobby() -> void:
	if _leaving:
		return
	_leaving = true
	_to_lobby = true
	Platform.perf_log("MATCH over: back to the lobby")
	if server != null:
		server.notify_clients(Protocol.Notice.RETURN_TO_LOBBY)
		await get_tree().create_timer(0.5).timeout
	else:
		client.leave()
	config.mode = MatchConfig.Mode.HOST if server != null else MatchConfig.Mode.JOIN
	config.from_lobby = true
	config.reconnect_token = 0
	config.map_retried = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	MatchConfig.pending = config
	get_tree().change_scene_to_file.call_deferred(LOBBY)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	store_kit()
	Log.i("match", "leaving to the main menu%s" % (": %s" % MatchConfig.last_error if not MatchConfig.last_error.is_empty() else ""))
	_save_partial(MatchConfig.last_error.is_empty())  # host gone: unconfirmed
	if client != null:
		client.leave()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU)


## Back to the menu, which shows `reason` (a translation key or text).
func _fail(reason: String) -> void:
	if _to_lobby:
		return  # the host closed the match on purpose
	MatchConfig.last_error = reason
	Platform.perf_log("MATCH left: %s" % tr(reason))
	# Lost to the network after joining: the menu offers to rejoin while the
	# server would still take our token back.
	if client != null and client.reconnect_token != 0 and reason.begins_with("NET_"):
		MatchConfig.rejoin = {"config": config, "token": client.reconnect_token,
				"until_ms": Time.get_ticks_msec() + ServerSession.RECONNECT_WINDOW_MS - 10000}
	_leave()


## Escape / Android back (Platform turns it into ui_cancel): dismiss the
## leave question, else toggle the pause menu.
func _unhandled_input(event: InputEvent) -> void:
	if spectating() and not _paused and _spectator_switch(event) != 0:
		_cycle_spectator(_spectator_switch(event))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if _confirm_panel.visible:
			_confirm_panel.visible = false
		else:
			_set_paused(not _paused)
		get_viewport().set_input_as_handled()


## Spectator controls: click, Space or → for the next player; right click
## or ← for the previous one. A tap arrives as a click (unless a button took
## it). 0: not a switch.
func _spectator_switch(event: InputEvent) -> int:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			return 1
		if event.button_index == MOUSE_BUTTON_RIGHT:
			return -1
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_right"):
		return 1
	elif event.is_action_pressed("ui_left"):
		return -1
	return 0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_paused_at_ms = Time.get_ticks_msec()
			if server != null:
				server.notify_clients(Protocol.Notice.HOST_PAUSED)
			if _started:
				_set_paused(true)
		NOTIFICATION_APPLICATION_RESUMED:
			_on_resumed()


## Best effort after a suspension (PLAN §3.5.1): a host tells its clients it
## is back; a client away long enough for the server to drop it rejoins with
## its reconnect token for up to 60 s.
func _on_resumed() -> void:
	var away_ms := Time.get_ticks_msec() - _paused_at_ms if _paused_at_ms != 0 else 0
	_paused_at_ms = 0
	if server != null:
		server.notify_clients(Protocol.Notice.HOST_RESUMED)
	elif client != null and _started and not _leaving and away_ms > RECONNECT_AFTER_MS:
		_reconnect_until_ms = Time.get_ticks_msec() + ServerSession.RECONNECT_WINDOW_MS - away_ms
		_reconnect_step()


func _on_focus_lost() -> void:
	if _started and not _paused:
		Log.i("match", "window lost focus: pausing")
		_set_paused(true)
