class_name DustStorms
extends Node
## Kasei Valley's dust storms as you see and hear them: the schedule is the
## simulation's (Survival.storm_at, from the world tick, so it's the same
## storm that drains your suit); the air thickens to an orange wall (fog),
## the sun dims, the wind howls. The HUD reads `storm` to warn you.
## `tick_source` () -> int gives the world tick.


static var storm: float = 0.0  ## 0 clear .. 1 the storm's height
var tick_source: Callable
var _wind: AudioStreamPlayer

var _time: float = 0.0
var _env: Environment
var _sun: DirectionalLight3D
var _base_fog: float
var _base_sun: float
## THE HUNT's sol (GameClock): night darkens the sun, the sky and the fill;
## the city's lamps and windows carry the evening. Off where there's no
## clock (`day_cycle` false: runs keep their fixed light).
var day_cycle: bool = true
var hour_offset: float = 0.0  ## for screenshots: so many hours later
var _sky: ProceduralSkyMaterial
var _base_ambient: float
var _base_top: Color
var _base_horizon: Color
var daylight: float = 1.0


func _ready() -> void:
	storm = 0.0
	for n in get_parent().get_children():
		if n is WorldEnvironment:
			_env = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D:
			_sun = n
	if _env != null:
		_base_fog = _env.fog_density
	if _sun != null:
		_base_sun = _sun.light_energy
	if _env != null:
		_base_ambient = _env.ambient_light_energy
		_sky = _env.sky.sky_material as ProceduralSkyMaterial if _env.sky != null else null
		if _sky != null:
			_base_top = _sky.sky_top_color
			_base_horizon = _sky.sky_horizon_color
	_wind = AudioStreamPlayer.new()
	_wind.stream = DustStorms.looping("res://audio/generated/storm_wind.wav")
	_wind.bus = "World" if AudioServer.get_bus_index("World") >= 0 else "Master"
	_wind.volume_db = -80.0
	add_child(_wind)


## A generated WAV set to loop end to end.
static func looping(path: String) -> AudioStream:
	var s: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2
	return s


## For screenshots: pretend the world is this many ticks further on.
var tick_offset: int = 0


func _process(delta: float) -> void:
	_time += delta
	var tick: int = (tick_source.call() if tick_source.is_valid() else int(_time * Sim.TICK_RATE)) + tick_offset
	storm = Survival.storm_at(tick) if Survival.weather else 0.0
	if storm > 0.01 and not _wind.playing:
		_wind.play()
	elif storm <= 0.01 and _wind.playing:
		_wind.stop()
	_wind.volume_db = linear_to_db(maxf(storm, 0.001)) - 4.0
	var h := GameClock.hour(Time.get_unix_time_from_system()) + hour_offset
	daylight = GameClock.daylight(fmod(h, 24.0)) if day_cycle else 1.0
	var night := 1.0 - daylight
	if _env != null:
		_env.fog_density = lerpf(_base_fog, 0.035, storm)
		_env.fog_light_color = Color(0.78, 0.5, 0.33).lerp(Color(0.6, 0.33, 0.18), storm).lerp(Color(0.12, 0.1, 0.18), night * 0.8)
		_env.ambient_light_energy = lerpf(_base_ambient, _base_ambient * 0.62, night)  # moonlit, never black
		if _sky != null:
			_sky.sky_top_color = _base_top.lerp(Color(0.02, 0.02, 0.06), night)
			_sky.sky_horizon_color = _base_horizon.lerp(Color(0.16, 0.1, 0.16), night)
	if _sun != null:
		_sun.light_energy = lerpf(_base_sun, _base_sun * 0.35, storm) * lerpf(0.3, 1.0, daylight)
		_sun.light_color = Color(1.0, 0.9, 0.78).lerp(Color(0.55, 0.62, 0.95), night)
