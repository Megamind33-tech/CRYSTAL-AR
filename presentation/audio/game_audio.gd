class_name GameAudio
extends Node3D
## In-match sound (PLAN §3.12): a pool of 32 voices with per-category caps
## and priorities, occlusion v1 (one ray per sound start and every 100 ms
## for longer sounds, ≤ 16 rays per frame; occluded sounds go through the
## Occluded bus), footsteps from movement state, and captions for important
## cues. Sounds are driven by simulation events that the caller has already
## de-duplicated by event id (PLAN §3.1).

signal caption(text: String)
## A player was thrown by a jump pad at `at` (seen from movement state).
signal launched(at: Vector3)

const DIR := "res://audio/generated/"
const MAX_VOICES := 32
const CAPS := {"Weapons": 8, "Footsteps": 6, "World": 8, "UI": 4}
const MAX_RAYS_PER_FRAME := 16
const OCCLUSION_INTERVAL := 0.1
const BELOW_METRES := 2.5  ## sounds this far under the listener get the Below bus
## Take-offs faster than any jump (6 m/s) come from a jump pad.
const PAD_LAUNCH_SPEED := 8.0
## Footsteps land when the boots do: GameAudio runs the same walk cycle as
## the bodies (Stride: cadence by ground speed, contacts at fixed points of
## the cycle, restarting when a player starts off), so each step sounds as
## a foot comes down. Tiers set the loudness only: below JOG_SPEED is a
## walk, below RUN_SPEED (or sprinting) a jog, else a run.
const STEP_DB := {"walk": -5.0, "jog": -1.0, "run": 0.0}
const JOG_SPEED := 3.0
const RUN_SPEED := 6.5
const CROUCH_DB := -10.0  ## crouch-walking is quiet, not silent
const STEP_JITTER_DB := 1.5  ## each step is a little louder or softer
const STEP_VARIANTS := 6  ## footstep_<surface>_1..6
## What's underfoot: the walk-in pieces by name (KitCollision), the rest by
## shape: the valley's ground is sand and gravel, the city's paving concrete.
const PIECE_SURFACE := {"districts/galleria": "wood", "districts/pod_a": "wood", "districts/pod_b": "wood",
		"districts/pod_c": "wood", "districts/apartment": "wood", "districts/office": "wood", "shopfront": "concrete",
		"life/greenhouse": "concrete", "life/farm_hall": "concrete"}
const STEP_RANGE := 45.0  ## other players' steps beyond this are not played

var listener: Node3D  ## the camera: listener position for occlusion

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _meta: Dictionary = {}  ## voice -> {category, priority, started, source, next_check}
var _steps: Dictionary = {}  ## player id -> {phase, moving, airborne, sliding, last}
var _rays_this_frame: int = 0
var steps_played: int = 0  ## footsteps started so far (for tests and debugging)
var _frame_delta: float = 0.0  ## last frame's time, the default for update_player
var last_step: Dictionary = {}  ## {sound, db} of the latest footstep
var _music: AudioStreamPlayer


func _ready() -> void:
	for f in DirAccess.get_files_at(DIR):
		var file := f.trim_suffix(".import")
		if file.ends_with(".wav") and not _streams.has(file.get_basename()):
			_streams[file.get_basename()] = load(DIR + file)
	for i in MAX_VOICES:
		var v := AudioStreamPlayer3D.new()
		v.max_distance = 70.0
		v.unit_size = 6.0
		v.attenuation_filter_cutoff_hz = 20500.0
		add_child(v)
		_voices.append(v)
	for i in 4:
		var u := AudioStreamPlayer.new()
		u.bus = "UI"
		add_child(u)
		_ui.append(u)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.stream = _streams.get("ambient_loop")
	_music.volume_db = -18.0  # well under the gunfire and footsteps
	add_child(_music)
	_music.play()


## A positional sound. Higher `priority` wins when voices run out: nearby
## enemy gunfire/footsteps > own weapon > world > ambience.
func play_at(sound: String, position: Vector3, category: String, priority: int, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if OS.has_environment("HUNT_DEBUG_AUDIO"):
		print("AUDIO %d %s %s %s" % [Time.get_ticks_msec(), sound, category, position])
	if stream == null:
		return
	var v := _take_voice(category, priority)
	if v == null:
		return
	v.stream = stream
	v.global_position = position
	v.volume_db = volume_db
	v.pitch_scale = randf_range(0.96, 1.04)
	_meta[v] = {"category": category, "priority": priority, "started": Time.get_ticks_msec(), "next_check": 0.0}
	v.bus = _occluded_bus(category, position)
	v.play()


## A non-positional sound (UI, our own hit confirmations).
func play_ui(sound: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if OS.has_environment("HUNT_DEBUG_AUDIO"):
		print("AUDIO-UI %d %s" % [Time.get_ticks_msec(), sound])
	if stream == null:
		return
	var best := _ui[0]
	for u in _ui:
		if not u.playing:
			best = u
			break
	best.stream = stream
	best.volume_db = volume_db
	best.play()


## Important cues get a caption when captions are on (PLAN §3.16).
func cue(sound: String, caption_key: String) -> void:
	play_ui(sound)
	if Settings.get_value("accessibility", "captions"):
		caption.emit(tr(caption_key))


## Footsteps, jumps, landings and slides from movement state (PLAN §3.12).
## Call every frame for each visible player; `local` steps are quieter and
## `ally` (teammate) steps duller, so enemy steps stand out. `delta` is the
## frame time (negative: the engine's last frame time). Steps come at the
## boots' contacts in the walk cycle (Stride) that runs while the player
## moves on the ground; a crouch-walk is quieter.
func update_player(id: int, s: PlayerSimState, local: bool, ally: bool = false, delta: float = -1.0) -> void:
	if delta < 0.0:
		delta = _frame_delta
	var st: Dictionary = _steps.get(id, {})
	if st.is_empty() or not s.alive:
		_steps[id] = {"phase": 0.0, "moving": false, "airborne": false, "sliding": false, "last": 0}
		return
	var airborne := s.move_state == PlayerSimState.Move.AIR
	var sliding := s.move_state == PlayerSimState.Move.SLIDE
	var vol := -10.0 if local else (-3.0 if ally else 0.0)
	var priority := 1 if local else (2 if ally else 3)
	if airborne and not st.airborne and s.velocity.y > PAD_LAUNCH_SPEED:
		play_at("jump_pad", s.position, "Footsteps", priority, vol + 2.0)
		launched.emit(s.position)
	elif airborne and not st.airborne and s.velocity.y > 2.0:
		play_at("jump", s.position, "Footsteps", priority, vol - 4.0)
	if not airborne and st.airborne:
		play_at("land", s.position, "Footsteps", priority, vol)
	if sliding and not st.sliding:
		play_at("slide", s.position, "Footsteps", priority, vol - 2.0)
	var speed := Vector2(s.velocity.x, s.velocity.z).length()
	if not airborne and not sliding and speed >= Stride.MOVING and delta > 0.0:
		if not st.moving:
			st.phase = 0.0  # starting off: the cycle starts over, as the body's does
			st.moving = true
		var crouched := s.stance != PlayerSimState.Stance.STAND
		var next: float = st.phase + (Stride.crouch_rate(speed) if crouched else Stride.rate(speed)) * delta
		for side in Stride.contacts_between(st.phase, next):
			var db: float = vol + float(STEP_DB[step_tier(speed, s.sprinting)]) + randf_range(-STEP_JITTER_DB, STEP_JITTER_DB)
			if crouched:
				db += CROUCH_DB
			_play_step(st, s.position, priority, db, ally, local)
		st.phase = fposmod(next, 1.0)
	else:
		st.moving = false  # standing, in the air or sliding: the next step starts a cycle
	st.airborne = airborne
	st.sliding = sliding
	_steps[id] = st


## The walk, jog or run tier for a ground speed (m/s).
static func step_tier(speed: float, sprinting: bool) -> String:
	if sprinting or speed >= RUN_SPEED:
		return "run"
	if speed >= JOG_SPEED:
		return "jog"
	return "walk"


## Seconds between footsteps at a ground speed (m/s): half a walk cycle.
static func step_interval(speed: float, _sprinting: bool = false) -> float:
	var r := Stride.rate(speed)
	return 0.5 / r if r > 0.0 else INF


## One footstep: the set for what's underfoot (never the same take twice
## running), the soft teammate set for allies. Other players' steps past
## STEP_RANGE are not played.
func _play_step(st: Dictionary, at: Vector3, priority: int, db: float, ally: bool, local: bool) -> void:
	if not local and listener != null and listener.global_position.distance_to(at) > STEP_RANGE:
		return
	var sound: String
	if ally:
		sound = "footstep_ally_%d" % (randi() % 3 + 1)
	else:
		var take := randi() % (STEP_VARIANTS - 1) + 1
		if take >= int(st.get("last", 0)):
			take += 1  # skips the last take: 1..6 without a repeat
		st.last = take
		sound = "footstep_%s_%d" % [surface_at(at), take]
	steps_played += 1
	last_step = {"sound": sound, "db": db}
	play_at(sound, at, "Footsteps", priority, db)


## What's underfoot at `at`: "wood", "metal", "concrete" or "sand" (one ray,
## only when a step plays).
func surface_at(at: Vector3) -> String:
	if not is_inside_tree():
		return surface_of(null, at)
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 0.6, Sim.LAYER_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var shape: Shape3D = null
	if not hit.is_empty() and hit.collider is CollisionObject3D:
		var body := hit.collider as CollisionObject3D
		var cs := body.shape_owner_get_owner(body.shape_find_owner(int(hit.shape))) as CollisionShape3D
		if cs != null:
			shape = cs.shape
	return surface_of(shape, at)


## The surface a collision `shape` at `at` is (null: nothing under, the
## valley's ground).
static func surface_of(shape: Shape3D, at: Vector3) -> String:
	if shape is ConcavePolygonShape3D:
		# Titan's modules, hangars, rigs: deck plate.
		return PIECE_SURFACE.get(KitCollision.piece_of(shape), "metal")
	if shape is BoxShape3D:
		return "metal"  # crates, tanks, kiosks
	var o := CityLayout.ORIGIN
	var g := WorldLayout.GALLERIA
	if (absf(at.x - o.x) < CityLayout.HALF and absf(at.z - o.z) < CityLayout.HALF) \
			or (absf(at.x - g.x) < 78.0 and absf(at.z - g.y) < 32.0):
		return "concrete"  # the city's paving, the Galleria's forecourt
	return "sand"


func forget_player(id: int) -> void:
	_steps.erase(id)


func _process(delta: float) -> void:
	_frame_delta = delta
	_rays_this_frame = 0
	# Re-check occlusion for longer sounds every 100 ms.
	var now := Time.get_ticks_msec() / 1000.0
	for v in _voices:
		if not v.playing or not _meta.has(v):
			continue
		var m: Dictionary = _meta[v]
		if now >= m.next_check:
			m.next_check = now + OCCLUSION_INTERVAL
			v.bus = _occluded_bus(m.category, v.global_position)


## The bus for a sound at `position`: Occluded behind walls, Below when it
## comes from more than BELOW_METRES under the listener, else its category.
func _occluded_bus(category: String, position: Vector3) -> String:
	if listener == null or category == "UI":
		return category
	var from := listener.global_position
	var fallback := "Below" if position.y < from.y - BELOW_METRES else category
	if _rays_this_frame >= MAX_RAYS_PER_FRAME or from.distance_squared_to(position) < 1.0:
		return fallback
	_rays_this_frame += 1
	var q := PhysicsRayQueryParameters3D.create(from, position, Sim.LAYER_WORLD)
	return "Occluded" if not get_world_3d().direct_space_state.intersect_ray(q).is_empty() else fallback


## A free voice, or one stolen from the same category (over its cap) or from
## lower-priority sounds; null if everything playing matters more.
func _take_voice(category: String, priority: int) -> AudioStreamPlayer3D:
	var in_category: Array[AudioStreamPlayer3D] = []
	var free: AudioStreamPlayer3D = null
	for v in _voices:
		if not v.playing:
			if free == null:
				free = v
		elif _meta.has(v) and _meta[v].category == category:
			in_category.append(v)
	if in_category.size() >= CAPS.get(category, 8):
		return _oldest(in_category, priority)
	if free != null:
		return free
	return _oldest(_voices.filter(func(v: AudioStreamPlayer3D) -> bool: return _meta.has(v)), priority)


func _oldest(candidates: Array, priority: int) -> AudioStreamPlayer3D:
	var pick: AudioStreamPlayer3D = null
	for v in candidates:
		var m: Dictionary = _meta[v]
		if m.priority > priority:
			continue
		if pick == null or m.priority < _meta[pick].priority or (m.priority == _meta[pick].priority and m.started < _meta[pick].started):
			pick = v
	if pick != null:
		pick.stop()
	return pick
