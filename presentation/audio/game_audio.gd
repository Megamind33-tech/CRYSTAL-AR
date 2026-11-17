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
## Footsteps follow the leg cadence of the movement tier: seconds per step,
## and a volume offset (dB) per tier. Speeds in m/s: below JOG_SPEED is a walk,
## below RUN_SPEED a jog, and a sprint or faster is a run.
const STEP_INTERVAL := {"walk": 0.55, "jog": 0.38, "run": 0.3}
const STEP_DB := {"walk": -4.0, "jog": 0.0, "run": 1.0}
const JOG_SPEED := 4.5
const RUN_SPEED := 7.5
const CROUCH_DB := -10.0  ## crouch-walking is quiet, not silent
const STEP_JITTER_DB := 1.0  ## each step is a little louder or softer
const STEP_RANGE := 45.0  ## other players' steps beyond this are not played
const CEILING_RANGE := 4.5  ## a ceiling this close overhead means indoors (metal floors)

var listener: Node3D  ## the camera: listener position for occlusion

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _meta: Dictionary = {}  ## voice -> {category, priority, started, source, next_check}
var _steps: Dictionary = {}  ## player id -> {pos, clock, airborne, sliding}
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
## frame time (negative: the engine's last frame time). Steps come on a clock
## that runs while the player moves on the ground, so their rhythm follows
## the walk, jog or run tier; a crouch-walk is quieter.
func update_player(id: int, s: PlayerSimState, local: bool, ally: bool = false, delta: float = -1.0) -> void:
	if delta < 0.0:
		delta = _frame_delta
	var st: Dictionary = _steps.get(id, {})
	if st.is_empty() or not s.alive:
		_steps[id] = {"pos": s.position, "clock": 0.0, "fresh": true, "airborne": false, "sliding": false}
		return
	var airborne := s.move_state == PlayerSimState.Move.AIR
	var sliding := s.move_state == PlayerSimState.Move.SLIDE
	var vol := -8.0 if local else (-3.0 if ally else 0.0)
	var priority := 1 if local else (2 if ally else 3)
	if airborne and not st.airborne and s.velocity.y > PAD_LAUNCH_SPEED:
		play_at("jump_pad", s.position, "Footsteps", priority, vol + 2.0)
		launched.emit(s.position)
	elif airborne and not st.airborne and s.velocity.y > 2.0:
		play_at("jump", s.position, "Footsteps", priority, vol - 4.0)
	if not airborne and st.airborne:
		play_at("land", s.position, "Footsteps", priority, vol)
		st.clock = 0.0
	if sliding and not st.sliding:
		play_at("slide", s.position, "Footsteps", priority, vol - 2.0)
	var moved := Vector2(s.position.x - st.pos.x, s.position.z - st.pos.z).length()
	if not airborne and not sliding and moved > 0.0005 and delta > 0.0:
		var speed := moved / delta
		var tier := step_tier(speed, s.sprinting)
		var interval: float = STEP_INTERVAL[tier]
		st.clock += delta
		# The first step after standing still comes at once; then one per interval.
		if st.fresh or st.clock >= interval:
			st.clock = 0.0 if st.fresh else maxf(st.clock - interval, 0.0)
			st.fresh = false
			var db: float = vol + float(STEP_DB[tier]) + randf_range(-STEP_JITTER_DB, STEP_JITTER_DB)
			if s.stance == PlayerSimState.Stance.CROUCH:
				db += CROUCH_DB
			_play_step(s.position, priority, db, ally, local)
	else:
		# Standing still (or in the air or a slide): the next step comes at once.
		st.clock = 0.0
		st.fresh = true
	st.pos = s.position
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


## Seconds between footsteps at a ground speed (m/s).
static func step_interval(speed: float, sprinting: bool) -> float:
	return STEP_INTERVAL[step_tier(speed, sprinting)]


## One footstep: metal panels indoors, ground outdoors, the soft teammate
## set for allies. Other players' steps past STEP_RANGE are not played.
func _play_step(at: Vector3, priority: int, db: float, ally: bool, local: bool) -> void:
	if not local and listener != null and listener.global_position.distance_to(at) > STEP_RANGE:
		return
	var sound: String
	if ally:
		sound = "footstep_ally_%d" % (randi() % 3 + 1)
	elif _indoors(at):
		sound = "footstep_%d" % (randi() % 3 + 1)
	else:
		sound = "footstep_ground_%d" % (randi() % 3 + 1)
	steps_played += 1
	last_step = {"sound": sound, "db": db}
	play_at(sound, at, "Footsteps", priority, db)


## True when a ceiling is close overhead (one ray, only when a step plays).
func _indoors(at: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.UP * CEILING_RANGE, Sim.LAYER_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


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
