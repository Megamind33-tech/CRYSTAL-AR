class_name HuntMods
extends RefCounted
## Match modifiers ("mods", part of HuntRules): every war run draws one or
## two from the deck (from the match seed), announced at the start. A
## modifier is data: a name and a set of effects, so players can write
## their own (JSON files in user://mods/, the same effect keys) and they
## join the deck.
##
## Effects:
##   gravity (x)        movement's gravity, times x (low gravity surge)
##   drops (x)          resource drops and pit caches, x times as many
##   resource_pay (x)   what extracted resources pay, times x
##   no_minimap         the HUD hides the minimap (blackout)
##   no_shields         nobody spawns with a shield (hardcore)
##   merc_cost (x)      hired guns cost x as much; merc_cap (n): this many at once
##   fog                enemy camps hidden until you're near (FOG_RANGE)
##   storm              a methane squall all match long
##   pad_shift (s)      the extraction pads move every s seconds

const DECK := {
	"methane_storm": {"storm": true, "pad_shift": 300},
	"low_gravity": {"gravity": 0.6},
	"gold_rush": {"drops": 2.0, "resource_pay": 2.0},
	"blackout": {"no_minimap": true},
	"hardcore": {"no_shields": true},
	"mercenary_market": {"merc_cost": 0.5, "merc_cap": 4},
	"fog_of_war": {"fog": true},
}
const FOG_RANGE := 60.0
## Players' own modifiers, read once (user://mods/*.json: {"name": ..., effects}).
static var _custom: Dictionary = {}
static var _custom_loaded := false

var active: Array = []  ## modifier ids this match
var effects: Dictionary = {}  ## merged effects
var _next_shift: int = 0


static func deck() -> Dictionary:
	if not _custom_loaded:
		_custom_loaded = true
		_load_custom()
	var out := DECK.duplicate()
	out.merge(_custom)
	return out


## Reads the players' own modifiers (only known effect keys are kept).
static func _load_custom() -> void:
	var dir := DirAccess.open("user://mods")
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://mods/" + f))
		if not data is Dictionary:
			continue
		var fx := {}
		for k: String in ["gravity", "drops", "resource_pay", "no_minimap", "no_shields", "merc_cost", "merc_cap", "fog",
				"storm", "pad_shift"]:
			if (data as Dictionary).has(k):
				fx[k] = data[k]
		if not fx.is_empty():
			_custom["custom:" + str(data.get("name", f.get_basename()))] = fx


## A new war run: draw the modifiers and set them going.
func start(world: SimWorld, hunt: HuntRules, forced: Array = []) -> void:
	active.clear()
	effects.clear()
	var cards := deck().keys()
	cards.sort()
	if not forced.is_empty():
		active = forced.duplicate()
	elif hunt.war.enabled:
		var r := RandomNumberGenerator.new()
		r.seed = hash(["mods", world.match_seed])
		var n := 1 if r.randf() < 0.6 else 2
		for k in n:
			var pick: String = cards[r.randi_range(0, cards.size() - 1)]
			if not pick in active:
				active.append(pick)
	for id: String in active:
		effects.merge(deck().get(id, {}), true)
	_apply(world, hunt)
	_next_shift = world.tick + int(effects.get("pad_shift", 0)) * Sim.TICK_RATE
	if not active.is_empty():
		world._emit("hmod:%d" % world.tick, "hunt", {"action": "mods", "player": 0, "position": Vector3.ZERO,
				"treasure": 0, "kind": -1, "mods": active})


func has(effect: String) -> bool:
	if not effects.has(effect):
		return false
	var v: Variant = effects[effect]
	return not (v is bool and v == false)


func value(effect: String, default: float = 1.0) -> float:
	return float(effects.get(effect, default))


func _apply(world: SimWorld, hunt: HuntRules) -> void:
	var cfg := world.movement_config
	if cfg != null:
		# The config is shared: its own gravity is kept aside while changed.
		if cfg.has_meta("base_gravity"):
			cfg.gravity = float(cfg.get_meta("base_gravity"))
			cfg.remove_meta("base_gravity")
		if has("gravity"):
			cfg.set_meta("base_gravity", cfg.gravity)
			cfg.gravity *= value("gravity")
	Survival.forced_storm = has("storm")
	hunt.economy.merc_cost = roundi(HuntEconomy.MERC_COST * value("merc_cost"))
	hunt.economy.merc_cap = int(value("merc_cap", HuntEconomy.MAX_ACTIVE_MERCS))


## The pads move (pad_shift): each to another cargo spot of the site.
func step(world: SimWorld, hunt: HuntRules) -> void:
	if not has("pad_shift") or world.tick < _next_shift or hunt.spots.is_empty():
		return
	_next_shift = world.tick + int(effects.pad_shift) * Sim.TICK_RATE
	var r := RandomNumberGenerator.new()
	r.seed = hash(["shift", world.match_seed, world.tick])
	for i in hunt.zones.size():
		hunt.zones[i] = hunt._floor_at(world, hunt.spots[r.randi_range(0, hunt.spots.size() - 1)] + Vector3.UP * 1.5)
	world._emit("hpad:%d" % world.tick, "hunt", {"action": "pads_shifted", "player": 0, "position": Vector3.ZERO,
			"treasure": 0, "kind": -1})


## The match is over: put shared settings back (gravity, the storm).
func clear(world: SimWorld) -> void:
	var cfg := world.movement_config
	if cfg != null and cfg.has_meta("base_gravity"):
		cfg.gravity = float(cfg.get_meta("base_gravity"))
		cfg.remove_meta("base_gravity")
	Survival.forced_storm = false
