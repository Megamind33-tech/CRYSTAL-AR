class_name Robbery
extends RefCounted
## THE HUNT's packs and robbery (simulation; the server's word): what a
## fighter carries (SimWorld.packs: net id -> {item: count}), the pack a
## fighter drops when killed (SimWorld.drops, searchable for a while), a
## hold-up when you have the upper hand, and the rover's hold, reached from
## behind it (VehicleSim.at_hold).
##
## A hold-up needs the edge: you're close, armed and on your feet, aiming at
## them, and they're badly hurt or caught from behind with you the stronger.

const HOLDUP_RANGE := 4.5
const AIM_COS := 0.9          ## within about 25 degrees of your aim
const WEAK := 35.0            ## their health at or under this: they give up
const EDGE := 40.0            ## or you're this much stronger (health + shield) and behind them
const DROP_SECONDS := 300.0   ## a dropped pack lies there five minutes
const SEARCH_RANGE := 2.6


## Where `s` faces on the ground.
static func facing(s: PlayerSimState) -> Vector3:
	return Vector3(-sin(s.yaw), 0.0, -cos(s.yaw))


## Whether `robber` can hold up `victim` right now. `slack` > 1 keeps a
## hold-up already offered while they shift about (more range, wider aim).
static func can_hold_up(robber: PlayerSimState, victim: PlayerSimState, slack: float = 1.0) -> bool:
	if not robber.alive or not victim.alive or robber.vehicle >= 0 or victim.vehicle >= 0:
		return false
	var to := victim.position - robber.position
	to.y = 0.0
	var dist := to.length()
	if dist > HOLDUP_RANGE * slack or dist < 0.01:
		return false
	if facing(robber).dot(to / dist) < AIM_COS - (slack - 1.0) * 0.5:
		return false  # not covering them
	if victim.health <= WEAK:
		return true
	var behind := facing(victim).dot(-to / dist) < -0.2  # they face away from you
	return behind and (robber.health + robber.shield) >= (victim.health + victim.shield) + EDGE


## Moves up to `n` of `item` from one pack (or hold) to another; returns how
## many moved.
static func take(from: Dictionary, to: Dictionary, item: String, n: int) -> int:
	var have: int = from.get(item, 0)
	var moved := mini(have, n)
	if moved <= 0:
		return 0
	if moved == have:
		from.erase(item)
	else:
		from[item] = have - moved
	to[item] = int(to.get(item, 0)) + moved
	return moved


## Everything in `from` into `to`; returns what moved.
static func take_all(from: Dictionary, to: Dictionary) -> Dictionary:
	var moved := from.duplicate()
	for item: String in moved:
		take(from, to, item, int(moved[item]))
	return moved


## What a fighter of `role` carries (deterministic from `roll`).
static func pack_for(role: String, roll: int) -> Dictionary:
	var r := absi(roll)
	var out := {"cred_chip": 1 + r % 3}
	match role:
		"concern":
			out["refined_ingot"] = 1 if r % 2 == 0 else 0
			out["supply_crate"] = 1 + (r / 2) % 2
			out["oxygen_canister"] = 1
		"guard":
			out["water_ration"] = 1 + r % 2
			out["fresh_food"] = 1 + (r / 3) % 2
			out["vat_meat"] = 1 if r % 2 == 0 else 0
		"raider":
			out["scrap"] = 1 + r % 2
			out["red_dust"] = 1 if (r / 5) % 3 == 0 else 0
		"marshal":
			out["frag_grenade"] = 1 if r % 3 == 0 else 0
			out["oxygen_canister"] = 1
	if (r / 7) % 4 == 0:
		out[["flux_smg", "scatter_gun", "burst_rifle"][(r / 11) % 3]] = 1
	for k: String in out.keys():
		if int(out[k]) <= 0:
			out.erase(k)
	return out
