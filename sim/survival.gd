class_name Survival
extends RefCounted
## THE HUNT's survival on Mars (simulation; same rules for players and bots,
## a process-wide switch like WeaponSim.limited_ammo, on in THE HUNT's modes):
##   - Oxygen: the suit tank drains outside pressurised zones (the city's
##     dome); a spare canister swaps in when it runs low; empty, you
##     suffocate. A kill takes the victim's spare canisters and some of the
##     air left in their tank.
##   - Stamina: sprinting spends it; empty, no sprint until it recovers.
##   - Fatigue: grows the longer you're up (faster at a sprint); tired, you
##     move slower. Sleep in a bunk to clear it.
##   - Water: thirst grows everywhere (scarce on Mars); a carried ration is
##     drunk when you run dry; dry, your breath comes back slowly and you
##     weaken. A kill takes the victim's water rations too.

const TANK_SECONDS := 600.0          ## a full tank outdoors (10 min)
const SWAP_AT := 8.0                 ## a spare goes in below this
const SUFFOCATE_PER_SECOND := 6.0    ## health lost with an empty tank
const STAMINA_DRAIN := 11.0          ## per second sprinting
const STAMINA_REGEN := 16.0
const STAMINA_RESUME := 25.0         ## sprint again once back to this
const FATIGUE_SECONDS := 1800.0      ## awake time to full fatigue (sprint x2)
const TIRED := 70.0
const EXHAUSTED := 90.0
const KILL_AIR_SHARE := 0.5          ## of the victim's tank the killer gets
const RESPAWN_OXYGEN := 60.0
const WATER_SECONDS := 1500.0         ## a full canteen lasts 25 minutes
const DRINK_AT := 10.0
const THIRST_PER_SECOND := 1.0        ## health lost while dry
const FOOD_SECONDS := 2400.0          ## a full belly lasts 40 minutes (sprinting: faster)
const HUNGRY := 30.0                  ## the HUD warns below this
const STARVE_PER_SECOND := 0.5        ## health lost while starving

## Dust storms (deterministic from the tick, so server and clients agree):
## the first after STORM_FIRST seconds, then every STORM_EVERY, each
## STORM_LENGTH long with STORM_RAMP to build and clear. Outside the domes a
## storm clogs suit filters and dries you out.
const STORM_FIRST := 200.0
const STORM_EVERY := 420.0
const STORM_LENGTH := 110.0
const STORM_RAMP := 20.0
const STORM_AIR := 1.75     ## oxygen use at the storm's height
const STORM_WATER := 1.4

static var enabled: bool = false
## Storms on (Kasei Valley); off on maps without weather.
static var weather: bool = false
## Pressurised zones: Vector3(x, z, radius) on the ground plane.
static var air_zones: Array[Vector3] = []
## Pressurised rooms that aren't a dome over open ground (underground halls).
static var air_boxes: Array[AABB] = []


static func in_air(pos: Vector3) -> bool:
	for b in air_boxes:
		if b.has_point(pos):
			return true
	for z in air_zones:
		if Vector2(pos.x - z.x, pos.z - z.y).length() < z.z:
			return true
	return false


## 0 (clear) .. 1 (the storm's height) at `tick`.
static func storm_at(tick: int) -> float:
	if not weather:
		return 0.0
	var t := tick * Sim.TICK_DT - STORM_FIRST
	if t < 0.0:
		return 0.0
	t = fmod(t, STORM_EVERY)
	if t >= STORM_LENGTH:
		return 0.0
	return clampf(minf(t, STORM_LENGTH - t) / STORM_RAMP, 0.0, 1.0)


## One tick of a living player's survival (after movement; the owner's
## client predicts it too). Returns the health lost to suffocation and
## thirst this tick (the server applies it).
static func step(s: PlayerSimState, tick: int = 0) -> float:
	if not enabled or not s.alive:
		return 0.0
	var dt := Sim.TICK_DT
	var inside := in_air(s.position)
	var storm := 0.0 if inside else storm_at(tick)
	if inside:
		s.oxygen = minf(s.oxygen + 100.0 / 30.0 * dt, 100.0)  # the dome refills the suit
	else:
		s.oxygen = maxf(s.oxygen - 100.0 / TANK_SECONDS * dt * lerpf(1.0, STORM_AIR, storm), 0.0)
		if s.oxygen < SWAP_AT and s.o2_spares > 0:
			s.o2_spares -= 1
			s.oxygen = 100.0
	s.water = maxf(s.water - 100.0 / WATER_SECONDS * dt * lerpf(1.0, STORM_WATER, storm), 0.0)
	if s.water < DRINK_AT and s.water_spares > 0:
		s.water_spares -= 1
		s.water = 100.0
	s.food = maxf(s.food - 100.0 / FOOD_SECONDS * dt * (1.5 if s.sprinting else 1.0), 0.0)
	var dry := s.water <= 0.0
	var starving := s.food <= 0.0
	if s.sprinting:
		s.stamina = maxf(s.stamina - STAMINA_DRAIN * dt, 0.0)
		if s.stamina <= 0.0:
			s.winded = true
	else:
		s.stamina = minf(s.stamina + STAMINA_REGEN * (0.4 if dry else 1.0) * (0.5 if starving else 1.0) * dt, 100.0)
		if s.stamina >= STAMINA_RESUME:
			s.winded = false
	s.fatigue = minf(s.fatigue + 100.0 / FATIGUE_SECONDS * dt * (2.0 if s.sprinting else 1.0), 100.0)
	return (SUFFOCATE_PER_SECOND * dt if s.oxygen <= 0.0 else 0.0) + (THIRST_PER_SECOND * dt if dry else 0.0) \
			+ (STARVE_PER_SECOND * dt if starving else 0.0)


## Speed multiplier from fatigue.
static func pace(s: PlayerSimState) -> float:
	if not enabled:
		return 1.0
	return 0.7 if s.fatigue >= EXHAUSTED else (0.85 if s.fatigue >= TIRED else 1.0)


## Sprinting allowed?
static func can_sprint(s: PlayerSimState) -> bool:
	return not enabled or not s.winded


## A kill: the killer takes the victim's spares and part of their air.
static func on_kill(victim: PlayerSimState, killer: PlayerSimState) -> Dictionary:
	if not enabled or killer == null:
		return {}
	var spares := victim.o2_spares
	var air := victim.oxygen * KILL_AIR_SHARE
	killer.o2_spares += spares
	killer.oxygen = minf(killer.oxygen + air, 100.0)
	victim.o2_spares = 0
	var water := victim.water_spares
	killer.water_spares += water
	victim.water_spares = 0
	return {"spares": spares, "air": roundi(air), "water": water}
