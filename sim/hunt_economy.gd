class_name HuntEconomy
extends RefCounted
## THE HUNT's economy, part of HuntRules (server-authoritative, identical
## for humans and bots): operational credits and mercenary contracts.
##
## Credits: every hunter starts with START_CREDITS and earns more only by
## extracting (half the points banked) up to MAX_CREDITS, so credits can't
## be farmed. Mercenary Contract: one active mercenary per hunter (and at
## most MAX_ACTIVE_MERCS in the match, for phones); the server spawns it as
## an ordinary bot body (same models, weapons, navigation, damage) driven
## by MercBrain. Employer and mercenary can't hurt each other. The contract
## ends on the employer's death or extraction, the mercenary's death,
## dismissal, or expiry.

enum Order { FOLLOW, HOLD, DEFEND, RETREAT }
const ORDER_IDS := ["follow", "hold", "defend", "retreat"]

const START_CREDITS := 250
const MAX_CREDITS := 1000
## Extraction pays credits too: this share of the points banked.
const EXTRACT_CREDIT_SHARE := 0.5
const MERC_COST := 200
const MERC_CONTRACT_TICKS := 9000  ## 150 s
const MAX_ACTIVE_MERCS := 2
## Informant: what each kind of intelligence costs, how sure it is, how
## long it stays useful (ticks; 0 = until its subject is gone) and how far
## a position is fuzzed. Data, not code.
const INTEL := {
	"cache_clue": {"cost": 40, "confidence": 0.9, "ttl": 0, "fuzz": 3.0},
	"vault_status": {"cost": 30, "confidence": 1.0, "ttl": 1800, "fuzz": 0.0},
	"rival_position": {"cost": 60, "confidence": 0.6, "ttl": 2700, "fuzz": 12.0},
}
const INTEL_IDS := ["cache_clue", "vault_status", "rival_position"]
const MAX_INTEL := 3  ## reports kept per hunter


class Contract:
	var employer: int = 0
	var merc: int = 0  ## the mercenary's net id once spawned (0 while pending)
	var order: int = Order.FOLLOW
	var hold_at := Vector3.ZERO
	var expires_tick: int = 0


var credits: Dictionary = {}  ## hunter id -> credits
var contracts: Dictionary = {}  ## employer id -> Contract
var mercs: Dictionary = {}  ## mercenary id -> employer id
## Server work queues (the simulation can't create bodies itself).
var pending_hires: Array[int] = []  ## employers waiting for a mercenary
var pending_dismissals: Array[int] = []  ## mercenary ids to remove
## Informant: hunter id -> Array of reports {"kind", "tick", "expires",
## "confidence", "position", "subject", "text_args"}.
var intel: Dictionary = {}
## Friends who came along (THE HUNT's companions): employer -> their name.
var names: Dictionary = {}


func reset() -> void:
	credits.clear()
	intel.clear()
	contracts.clear()
	pending_hires.clear()
	for m: int in mercs:
		pending_dismissals.append(m)
	mercs.clear()


func is_merc(id: int) -> bool:
	return mercs.has(id)


## Employer and mercenary never hurt each other.
func protects(a: int, b: int) -> bool:
	return mercs.get(a, 0) == b or mercs.get(b, 0) == a


func add_hunter(id: int) -> void:
	if not credits.has(id):
		credits[id] = START_CREDITS


func earn(world: SimWorld, id: int, amount: int, reason: String) -> void:
	if amount <= 0 or is_merc(id) or not credits.has(id):
		return
	var before: int = credits[id]
	credits[id] = mini(before + amount, MAX_CREDITS)
	if credits[id] != before:
		world._emit("he:%d:%d:%s" % [id, world.tick, reason], "hunt", {"action": "credits", "player": id,
				"amount": credits[id] - before, "credits": credits[id], "reason": reason, "position": Vector3.ZERO,
				"treasure": 0, "kind": -1})


## A friend comes along for the whole run: a free contract to its end,
## spawned like a hired mercenary (same brain, orders and protections).
func bring_friend(world: SimWorld, employer: int, friend_name: String, until_tick: int) -> bool:
	var p: SimPlayer = world.players.get(employer)
	if p == null or contracts.has(employer):
		return false
	var c := Contract.new()
	c.employer = employer
	c.expires_tick = until_tick
	contracts[employer] = c
	names[employer] = friend_name
	pending_hires.append(employer)
	return true


func active_mercs() -> int:
	return contracts.size()


func hire(world: SimWorld, employer: int) -> bool:
	var p: SimPlayer = world.players.get(employer)
	if p == null or not p.state.alive or is_merc(employer) or contracts.has(employer) \
			or credits.get(employer, 0) < MERC_COST or active_mercs() >= MAX_ACTIVE_MERCS:
		return false
	credits[employer] -= MERC_COST
	var c := Contract.new()
	c.employer = employer
	c.expires_tick = world.tick + MERC_CONTRACT_TICKS
	contracts[employer] = c
	pending_hires.append(employer)
	world._emit("hm:%d:%d" % [employer, world.tick], "hunt", {"action": "merc_hired", "player": employer,
			"credits": credits[employer], "position": p.state.position, "treasure": 0, "kind": -1})
	return true


## The server spawned the body for `employer`'s contract.
func bind(employer: int, merc_id: int) -> void:
	var c: Contract = contracts.get(employer)
	if c == null:
		pending_dismissals.append(merc_id)
		return
	c.merc = merc_id
	mercs[merc_id] = employer


func order(world: SimWorld, employer: int, order_id: String) -> bool:
	var c: Contract = contracts.get(employer)
	var o := ORDER_IDS.find(order_id)
	if c == null or o < 0:
		return false
	c.order = o
	if o == Order.HOLD and world.players.has(c.merc):
		c.hold_at = world.players[c.merc].state.position
	world._emit("ho:%d:%d" % [employer, world.tick], "hunt", {"action": "merc_order", "player": employer,
			"order": order_id, "position": Vector3.ZERO, "treasure": 0, "kind": -1})
	return true


func end_contract(world: SimWorld, employer: int, reason: String) -> void:
	var c: Contract = contracts.get(employer)
	if c == null:
		return
	contracts.erase(employer)
	pending_hires.erase(employer)
	if c.merc != 0:
		mercs.erase(c.merc)
		pending_dismissals.append(c.merc)
	world._emit("hx:%d:%d" % [employer, world.tick], "hunt", {"action": "merc_ended", "player": employer,
			"reason": reason, "position": Vector3.ZERO, "treasure": 0, "kind": -1})


func spend(id: int, amount: int) -> bool:
	if credits.get(id, 0) < amount:
		return false
	credits[id] -= amount
	return true


func add_intel(id: int, report: Dictionary) -> void:
	var list: Array = intel.get(id, [])
	list.push_front(report)
	intel[id] = list.slice(0, MAX_INTEL)


## Reports still useful at `tick` (expired ones are dropped).
func intel_of(id: int, tick: int) -> Array:
	var list: Array = intel.get(id, []).filter(func(r: Dictionary) -> bool:
		return int(r.expires) == 0 or tick < int(r.expires))
	intel[id] = list
	return list


func step(world: SimWorld) -> void:
	for employer: int in contracts.keys():
		var c: Contract = contracts[employer]
		if world.tick >= c.expires_tick:
			end_contract(world, employer, "expired")
		elif not world.players.has(employer):
			end_contract(world, employer, "left")


## A death: the employer's ends its contract, as does the mercenary's.
func on_death(world: SimWorld, victim: int) -> void:
	if contracts.has(victim):
		end_contract(world, victim, "employer_down")
	elif mercs.has(victim):
		end_contract(world, mercs[victim], "merc_down")
