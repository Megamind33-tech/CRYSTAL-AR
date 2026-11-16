class_name Jetpack
extends RefCounted
## THE HUNT's jetpack (simulation; predicted like the rest of movement):
## hold jump in the air and it thrusts you up (Mars' low gravity makes it
## a long, floating hop) and lets you steer; it burns fuel and refills on
## the ground. Only for players carrying one (PlayerSimState.jetpack).

const THRUST := 13.0         ## m/s^2 up while held (gravity is 3.72)
const MAX_CLIMB := 7.0       ## m/s up at most
const BURN := 20.0           ## fuel percent a second of thrust (about 5 s)
const REFILL := 22.0         ## percent a second on the ground
const LIFT_DELAY := 8        ## ticks off the ground before it lights (a jump first)
const AIR_CONTROL := 4.0     ## m/s^2 of steering while thrusting


## One tick in the air: thrust if held. True while it's firing.
static func air(s: PlayerSimState, held: bool, wish_dir: Vector3, dt: float) -> bool:
	if not s.jetpack or not held or s.jet_fuel <= 0.0 or s.ticks_since_floor < LIFT_DELAY:
		return false
	s.velocity.y = minf(s.velocity.y + THRUST * dt, MAX_CLIMB)
	s.velocity.x += wish_dir.x * AIR_CONTROL * dt
	s.velocity.z += wish_dir.z * AIR_CONTROL * dt
	s.jet_fuel = maxf(s.jet_fuel - BURN * dt, 0.0)
	return true


static func ground(s: PlayerSimState, dt: float) -> void:
	if s.jetpack:
		s.jet_fuel = minf(s.jet_fuel + REFILL * dt, 100.0)
