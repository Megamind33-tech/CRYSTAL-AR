class_name HuntRules
extends RefCounted
## THE HUNT (solo-first MVP): treasure-hunting rules, server-authoritative
## like Capture the Flag. Every hunter gets two personal assignments
## (treasures placed at random treasure spots) and everyone races for one
## shared grand treasure in the vault. Treasures are carried by touching
## them, dropped on death or by pressing interact, stolen by a melee hit on
## the carrier, and banked by standing in an extraction zone.
##
## The rules only see SimPlayer state and the executed actions of each
## player's PlayerCommand, so a human and a bot are treated exactly alike
## (bots press the same buttons through BotBrain). Points go into
## SimWorld.scores, so the existing leaderboard, results and end-of-match
## logic work unchanged. State lives here (not in presentation) so a later
## multiplayer milestone only has to replicate it.

## Appended only: the kind goes into events (and later the wire).
## PROOF: a bounty proof dropped by a Wanted hunter's death (HuntSocial).
## RESOURCE: a collected resource cache's load (HuntResources).
enum Kind { PERSONAL, GRAND, PROOF, RESOURCE }

const ASSIGNMENTS_PER_HUNTER := 2
## Touching a treasure takes it: as close as a flag (SimWorld.FLAG_RADIUS).
const PICKUP_RADIUS := 1.4
const PICKUP_HEIGHT := 1.8
## Standing this long in an extraction zone banks the carried treasure.
const EXTRACT_TICKS := 180
const EXTRACT_RADIUS := 3.5
## After dropping (or losing) a treasure, the same hunter can't take it back
## for this long, so a manual drop isn't undone on the next tick.
const REPICK_TICKS := 90
## Points (PLAN-style explicit score: the leaderboard is SimWorld.scores).
const OWN_POINTS := 100
const STOLEN_POINTS := 50  ## extracting another hunter's assignment
const GRAND_POINTS := 300
## A kill already scores 1 in SimWorld._kill; the hunt tops it up to this.
const KILL_POINTS := 10
## The grand treasure returns to the vault this long after it is banked.
const GRAND_RESPAWN_TICKS := 3600
## A dropped treasure nobody touches goes back to where it was placed.
const DROPPED_RETURN_TICKS := 2700
## Limited ammunition: each life starts with one spare magazine per weapon.
const SPARE_MAGS := 1
## The alarm trap: stepping near it reveals the intruder to everyone.
const TRAP_RADIUS := 4.0
const TRAP_REVEAL_TICKS := 600
const TRAP_REARM_TICKS := 1200
## A bounty proof nobody extracts disappears after this long.
const PROOF_EXPIRE_TICKS := 3600
## Recovery Contract: the hunter a treasure was stolen from gets a clue to
## where it is every RECOVERY_CLUE_TICKS (fuzzed by RECOVERY_CLUE_FUZZ m)
## and RECOVERY_POINTS for taking it back, once per item.
const RECOVERY_CLUE_TICKS := 900
const RECOVERY_CLUE_FUZZ := 10.0
const RECOVERY_POINTS := 30
## Last Extraction: a warning this long before the end, then every pad but
## one closes this long before the end; cargo still carried at the bell is
## lost (it never scored: only extraction scores).
const FINAL_WARNING_TICKS := 10800
const LAST_EXTRACTION_TICKS := 7200
## Resource Dispute: how close a hunter must stand to collect a cache.
const CACHE_RADIUS := 2.0
## Grand Vault Standoff: the grand treasure appears locked; unlocking it
## takes VAULT_UNLOCK_TICKS of interacting next to it (damage or leaving
## interrupts) and releases VAULT_SHARE_CREDITS, split between the unlocker
## and its ally if the ally is inside the vault. The treasure itself stays
## one contested item.
const VAULT_UNLOCK_TICKS := 240
const VAULT_UNLOCK_RADIUS := 2.5
const VAULT_SHARE_CREDITS := 150
const VAULT_SHARE_RADIUS := 12.0


## Resource Dispute: a contested cache at a treasure spot. One load; one
## collector at a time.
class Cache:
	var id: int = 0
	var resource: String = ""
	var position := Vector3.ZERO
	var collector: int = 0  ## net id while being collected
	var progress: int = 0
	var collector_hp: float = 0.0  ## shield + health when last checked (damage interrupts)
	var empty: bool = false


class Treasure:
	var id: int = 0
	var kind: int = Kind.PERSONAL
	var owner: int = 0  ## the assigned hunter's net id; 0 for the grand treasure
	var home := Vector3.ZERO  ## where it was placed
	var position := Vector3.ZERO
	var carrier: int = 0  ## net id, 0 = none
	var banked: bool = false
	var return_tick: int = 0  ## dropped: when it goes home by itself (0 = not dropped)
	var available_tick: int = 0  ## grand only: when it (re)appears in the vault
	var blocked_id: int = 0  ## who can't retake it until blocked_until
	var blocked_until: int = 0
	var value: int = 0  ## PROOF: the bounty it pays when extracted
	var proof_target: int = 0  ## PROOF: whose bounty it is
	var resource: String = ""  ## RESOURCE: its HuntResources type
	var locked: bool = false  ## GRAND: must be unlocked before it can be taken
	var stolen_from: int = 0  ## Recovery Contract: who it was stolen from (0 = not stolen)
	var vehicle: int = -1  ## stowed in this vehicle's hold (hidden), -1 = not
	var stowed_by: int = 0  ## who put it there (takes it back at once)
	var recovery_paid: bool = false  ## the recovery bonus is paid once per item
	var next_clue_tick: int = 0

	func on_ground() -> bool:
		return carrier == 0 and not banked and vehicle < 0


var spots: Array[Vector3] = []
var zones: Array[Vector3] = []
var vault := Vector3.ZERO
var trap := Vector3.INF  ## Vector3.INF: the map has no trap
var trap_rearm_tick: int = 0  ## 0 = armed
var treasures: Array[Treasure] = []
var extract_progress: Dictionary = {}  ## net id -> ticks in a zone while carrying
var revealed_until: Dictionary = {}  ## net id -> tick the alarm reveal ends
var banked_count: Dictionary = {}  ## net id -> treasures extracted (stats)
## Career (persistent) side: what each hunter extracted this run, as loot
## items {"item", "value"} (the server's record; Career.settle reads it), and
## the gear each hunter deployed with {"shield_bonus", "spare_mags"}.
var haul: Dictionary = {}
var gear: Dictionary = {}
## Bounties and Wanted status (Most Wanted); later alliances and reputation.
var social := HuntSocial.new()
## Nations (docs/game-plan.md): net id -> Nations index, seated at reset.
## The hunters of one nation start the run allied (a squad).
var nations: Dictionary = {}
## The humans' own nations (net id -> Nations index), set before the run.
var home_nations: Dictionary = {}
## AI squadmates who may turn on their partner this run (net id -> bool;
## missing: may, as AI squads always could). The career paces it for the
## human's squadmate so it never becomes a pattern (Match).
var may_turn: Dictionary = {}
## AI who hold a grudge against their partner (it turned on them before).
var grudges: Dictionary = {}
## Each AI's character (Nations.PERSONALITIES), by net id.
var personalities: Dictionary = {}
## Operational credits and mercenary contracts.
var economy := HuntEconomy.new()
var squad := HuntSquad.new()  ## the hunters' AI teammates
var war := HuntWar.new()  ## what wins the run: sides, objectives (battlegrounds)
var army := HuntArmy.new()  ## the hunters' units: drones, gunships, jets, tanks, machines
var mods := HuntMods.new()  ## this match's modifiers (a war's: storm, low gravity, gold rush...)
## Tools and tests: these modifiers every match (empty: drawn).
static var force_mods: Array = []
## Recovery Contract: victim id -> {"treasure", "position" (fuzzed), "tick"}.
var recovery_clues: Dictionary = {}
## Last Extraction: the match's end tick (0: no clock, every pad stays open),
## the pad that stays open to the end, and which announcements were made.
var caches: Array[Cache] = []
## Grand Vault Standoff: who is unlocking the vault and how far along.
var vault_unlocker: int = 0
var vault_progress: int = 0
var _unlocker_hp: float = 0.0
var end_tick: int = 0
var final_zone: int = -1
## The pit's conditions this run (maps that opt in with "pit_rules": the
## dig): the same pit doesn't play the same way twice.
##   STANDARD: as ever, a few resource caches about the pit.
##   ORE_SEAM: a seam's been opened: many more caches to work.
##   ONE_PAD: a cave-in: one extraction pad works the whole run.
##   HOT_VAULT: the vault's lock is failing: it opens twice as fast.
enum PitRule { STANDARD, ORE_SEAM, ONE_PAD, HOT_VAULT }
const PIT_CACHES := {PitRule.STANDARD: 3, PitRule.ORE_SEAM: 8, PitRule.ONE_PAD: 3, PitRule.HOT_VAULT: 3}
var pit_rules: bool = false
var pit_rule: int = PitRule.STANDARD
var _announced: int = 0  ## 1 warning, 2 pads closed, 3 the bell

var _rng := RandomNumberGenerator.new()
var _next_id: int = 1


## `map`: {"treasure_spots": [Vector3], "extraction_zones": [Vector3],
## "vault": Vector3, "trap": Vector3 (optional)}.
func configure(map: Dictionary, seed_value: int) -> void:
	spots.assign(map.get("treasure_spots", []))
	zones.assign(map.get("extraction_zones", []))
	vault = map.get("vault", Vector3.ZERO)
	trap = map.get("trap", Vector3.INF)
	pit_rules = bool(map.get("pit_rules", false))
	war.configure(map)
	_rng.seed = seed_value
	social.reset(seed_value)


## A new match: a fresh grand treasure and two new assignments each.
func reset(world: SimWorld) -> void:
	_rng.seed = world.match_seed
	opened_tick = -1
	treasures.clear()
	extract_progress.clear()
	revealed_until.clear()
	banked_count.clear()
	haul.clear()
	recovery_clues.clear()
	caches.clear()
	vault_unlocker = 0
	vault_progress = 0
	_searching.clear()
	economy.reset()
	squad.reset()
	army.reset()
	end_tick = 0
	final_zone = -1
	_announced = 0
	social.reset(world.match_seed)
	trap_rearm_tick = 0
	_next_id = 1
	var grand := _new_treasure(Kind.GRAND, 0, vault)
	grand.available_tick = 0
	grand.locked = true
	_emit(world, grand, "vault_open", 0)
	var ids := world.players.keys()
	ids.sort()
	for id in ids:
		# economy.reset() above queued any mercenary bodies for removal: they
		# are no hunters (no assignments, no credits).
		if not economy.pending_dismissals.has(id) and not squad.pending_dismissals.has(id):
			economy.add_hunter(id)
			_assign(world, id)
	_seat_nations(world, ids)
	mods.start(world, self, force_mods)  # before the pit's caches (gold rush)
	if pit_rules:
		_set_pit(world)
	war.start(world, self)


## Seats every hunter in a nation and allies each nation's first two (one
## alliance per hunter: a squad of two).
func _seat_nations(world: SimWorld, ids: Array) -> void:
	nations.clear()
	if home_nations.is_empty():
		return  # a run without nations (tests, old saves): as before
	var hunters := ids.filter(func(id: int) -> bool: return not _aux(id) and not economy.pending_dismissals.has(id))
	nations = Nations.seat(hunters, home_nations, world.match_seed)
	# A war is a duel (two nations) or a four-way war: in a duel the AI are
	# seated with you or with one rival nation.
	if war.enabled and HuntWar.duel_for(world.match_seed):
		var mine := -1
		for id: int in hunters:
			if home_nations.has(id):
				mine = int(home_nations[id])
		var rival := -1
		for id: int in hunters:
			if int(nations[id]) != mine:
				rival = int(nations[id])
				break
		if mine >= 0 and rival >= 0:
			var k := 0
			for id: int in hunters:
				if not home_nations.has(id):
					nations[id] = mine if k % 3 == 0 else rival  # a third with you, the rest against
					k += 1
	var by_nation := {}
	for id: int in hunters:
		var n: int = nations[id]
		var list: Array = by_nation.get(n, [])
		list.append(id)
		by_nation[n] = list
	for n: int in by_nation:
		var list: Array = by_nation[n]
		if list.size() >= 2:
			social.form(world, list[0], list[1])


func nation_of(id: int) -> int:
	return nations.get(id, Nations.NONE)


## Hunters who don't fight each other unprovoked (bots don't target them):
## an employer and its mercenary, and allies. Allies CAN be hurt (friendly
## fire is on: anyone can turn on anyone), see protects().
func friendly(a: int, b: int) -> bool:
	return economy.protects(a, b) or squad.same_side(a, b) or social.allied(a, b) \
			or (war.enabled and war.sides_allied(war.side_of(self, a), war.side_of(self, b)))


## A hit between hunters: fire on an ally is friendly fire (HuntSocial).
func on_damage(world: SimWorld, attacker: int, target: int, amount: float, killed: bool) -> void:
	social.friendly_fire(world, attacker, target, amount, killed)


func add_player(world: SimWorld, p: SimPlayer) -> void:
	if _aux(p.net_id):
		return  # a hired mercenary: no assignments, no credits
	if treasures.is_empty():
		_new_treasure(Kind.GRAND, 0, vault).locked = true
	economy.add_hunter(p.net_id)
	_assign(world, p.net_id)


## A leaving hunter drops what it carries; its assignments stay in the world
## (anyone can still steal them).
func remove_player(world: SimWorld, p: SimPlayer) -> void:
	_drop(world, p)
	extract_progress.erase(p.net_id)
	revealed_until.erase(p.net_id)
	social.remove_player(p.net_id)
	if economy.contracts.has(p.net_id):
		economy.end_contract(world, p.net_id, "left")
	elif economy.is_merc(p.net_id):
		economy.end_contract(world, economy.mercs[p.net_id], "merc_down")
	elif squad.is_member(p.net_id):
		squad.on_death(world, p.net_id)
	squad.disband(world, p.net_id)  # a leader leaving takes their squad


## Limited ammunition: at most SPARE_MAGS spare magazines per weapon.
func on_spawn(_world: SimWorld, p: SimPlayer) -> void:
	var s := p.state
	var kit: Dictionary = gear.get(p.net_id, {})
	var mags := SPARE_MAGS + int(kit.get("spare_mags", 0))
	for i in s.weapons.size():
		var w := Weapons.at(s.weapons[i])
		if w != null:
			s.reserve[i] = mini(s.reserve[i], w.mag_size * mags)
	s.shield += float(kit.get("shield_bonus", 0.0))
	if mods.has("no_shields"):
		s.shield = 0.0  # hardcore


## Death: the carried treasure falls where the carrier was; a kill is worth
## KILL_POINTS in total.
## Most Wanted: a Wanted victim leaves a bounty proof where it fell.
func on_kill(world: SimWorld, victim: SimPlayer, killer: int, suicide: bool) -> void:
	var carried := carried_by(victim.net_id) != null
	_drop(world, victim)
	extract_progress.erase(victim.net_id)
	economy.on_death(world, victim.net_id)
	if squad.is_member(victim.net_id):
		war.builds.on_teammate_down(world, self, squad.leader_of(victim.net_id), squad.by_id[victim.net_id].role)
	squad.on_death(world, victim.net_id)
	war.on_death(self, victim.net_id)
	if _aux(killer) or _aux(victim.net_id):
		if _aux(killer) and not suicide and world.scores.has(killer):
			world.scores[killer] -= 1  # hired guns don't score
		return
	if not suicide and world.scores.has(killer):
		world.scores[killer] += KILL_POINTS - 1
	var claim := social.on_kill(world, victim, killer, suicide, carried)
	if claim > 0:
		var proof := _new_treasure(Kind.PROOF, killer, _floor_at(world, victim.state.position))
		proof.value = claim
		proof.proof_target = victim.net_id
		proof.return_tick = world.tick + PROOF_EXPIRE_TICKS
		_emit(world, proof, "bounty_proof", killer, {"victim": victim.net_id, "points": claim})


## Stealing: a melee hit on a carrier takes the treasure, if the attacker's
## hands are free.
func on_melee_hit(world: SimWorld, attacker: SimPlayer, target: SimPlayer) -> void:
	if _aux(attacker.net_id):
		return  # mercenaries fight; they don't carry treasure
	var t := carried_by(target.net_id)
	if t == null or carried_by(attacker.net_id) != null:
		return
	t.carrier = attacker.net_id
	extract_progress.erase(target.net_id)
	t.blocked_id = target.net_id
	t.blocked_until = world.tick + REPICK_TICKS
	if t.stolen_from == attacker.net_id:
		_recover(world, t, attacker.net_id)  # taking back what was ours is no crime
		return
	_emit(world, t, "steal", attacker.net_id, {"victim": target.net_id})
	if t.stolen_from == 0:
		# The first theft opens a recovery contract for the hunter who lost it.
		t.stolen_from = target.net_id
		t.next_clue_tick = world.tick + RECOVERY_CLUE_TICKS
		_emit(world, t, "recovery_open", target.net_id, {"thief": attacker.net_id})
	# Theft is a crime (Most Wanted); carrying treasure on its own is not.
	social.add_bounty(world, attacker.net_id,
			HuntSocial.STEAL_BOUNTY_BASE + int(value_for(t, attacker.net_id) * HuntSocial.STEAL_BOUNTY_SHARE), "theft")


## One tick, after movement and combat. `interacting`: ids whose interact
## press executed this tick (a carrier drops its treasure).
func step(world: SimWorld, ids: Array, interacting: Dictionary) -> void:
	var tick := world.tick
	for t in treasures:
		if t.kind == Kind.GRAND and t.banked and tick >= t.available_tick:
			t.banked = false
			t.locked = true
			t.position = t.home
			_emit(world, t, "grand_ready", 0)
			_emit(world, t, "vault_open", 0)  # every hunter learns where
		_recovery_clue(world, t)
		if t.carrier == 0 and t.return_tick > 0 and tick >= t.return_tick:
			_close_recovery(world, t, "recovery_closed")  # back at its spot: no thief to chase
			if t.kind == Kind.PROOF:
				t.banked = true  # an unclaimed proof is gone for good
				t.return_tick = 0
				_emit(world, t, "proof_expired", 0)
				continue
			t.position = t.home
			t.return_tick = 0
			_emit(world, t, "return", 0)
	# Carriers: follow, drop on interact, extract in a zone.
	for t in treasures:
		if t.carrier == 0:
			continue
		var c: SimPlayer = world.players.get(t.carrier)
		if c == null or not c.state.alive:
			t.carrier = 0  # on_kill / remove_player already dropped it
			continue
		t.position = c.state.position
		if interacting.has(c.net_id):
			var hold := _hold_at(world, c.state.position)
			if hold >= 0 and stowed_in(hold).size() < HOLD_CAPACITY:
				_stow(world, c, t, hold)  # into the vehicle: out of sight
				interacting.erase(c.net_id)  # the press is spent
			else:
				_drop(world, c)
			continue
		if _in_zone(c.state.position, tick):
			# An extraction machine of yours at the pad (HuntArmy): faster; in a
			# war a heavy load (the relic, resources) goes out only beside one.
			var boost := army.extraction_boost(world, self, c.net_id, nearest_zone(c.state.position, tick))
			if war.blocks_extract(t):
				continue  # a King war: the relic stays in play
			if war.enabled and _heavy(t) and boost == 0:
				extract_progress[c.net_id] = 0
				continue
			var ticks: int = extract_progress.get(c.net_id, 0) + 1 + boost
			extract_progress[c.net_id] = ticks
			if ticks >= EXTRACT_TICKS:
				_bank(world, c, t)
		else:
			extract_progress.erase(c.net_id)
	# Pickups: in treasure order, the closest free hunter (ties: lowest id).
	for t in treasures:
		if not t.on_ground() or (t.kind == Kind.GRAND and (tick < t.available_tick or t.locked)):
			continue
		var best: SimPlayer = null
		var best_d := INF
		for id in ids:
			var p: SimPlayer = world.players[id]
			if not p.state.alive or carried_by(id) != null or (_aux(id) and not _may_carry(id, t)):
				continue
			if id == t.blocked_id and tick < t.blocked_until:
				continue
			var d := p.state.position - t.position
			var flat := Vector2(d.x, d.z).length()
			if flat <= PICKUP_RADIUS and absf(d.y) <= PICKUP_HEIGHT and flat < best_d:
				best_d = flat
				best = p
		if best != null and t.kind == Kind.PROOF and best.net_id == t.proof_target:
			t.banked = true  # a target can't cash in its own bounty: touching it destroys it
			t.return_tick = 0
			_emit(world, t, "proof_destroyed", best.net_id)
		elif best != null:
			t.carrier = best.net_id
			t.return_tick = 0
			best.state.spawn_protection_ticks = 0
			_emit(world, t, "take", best.net_id)
			if t.stolen_from == best.net_id:
				_recover(world, t, best.net_id)
	_step_holds(world, ids, interacting)
	_step_caches(world, ids, interacting)
	_step_vault(world, ids, interacting)
	social.step(world, ids)
	economy.step(world)
	squad.step(world, self)
	war.step(world, self, ids, interacting)
	army.step(world, self)
	mods.step(world, self)
	_step_last_extraction(world)
	# The alarm trap.
	if trap != Vector3.INF:
		if trap_rearm_tick > 0 and tick >= trap_rearm_tick:
			trap_rearm_tick = 0
		if trap_rearm_tick == 0:
			for id in ids:
				var p: SimPlayer = world.players[id]
				if p.state.alive and not _aux(id) and p.state.position.distance_to(trap) <= TRAP_RADIUS:
					revealed_until[id] = tick + TRAP_REVEAL_TICKS
					trap_rearm_tick = tick + TRAP_REARM_TICKS
					world._emit("ha:%d" % tick, "hunt", {"action": "alarm", "player": id, "position": p.state.position,
							"treasure": 0, "kind": -1})
					break


# --- Queries (AI, HUD) ---

func carried_by(net_id: int) -> Treasure:
	for t in treasures:
		if t.carrier == net_id and net_id != 0:
			return t
	return null


func assignments_of(net_id: int) -> Array[Treasure]:
	var out: Array[Treasure] = []
	for t in treasures:
		if t.kind == Kind.PERSONAL and t.owner == net_id:
			out.append(t)
	return out


func grand() -> Treasure:
	for t in treasures:
		if t.kind == Kind.GRAND:
			return t
	return null


func grand_available(tick: int) -> bool:
	var g := grand()
	return g != null and g.on_ground() and tick >= g.available_tick


func is_revealed(net_id: int, tick: int) -> bool:
	return revealed_until.get(net_id, 0) > tick


## The nearest extraction pad still open at `tick` (-1: ignore closures).
func nearest_zone(from: Vector3, tick: int = -1) -> Vector3:
	var best := Vector3.INF
	for i in zones.size():
		var z := zones[i]
		if tick >= 0 and not zone_open(i, tick):
			continue
		if best == Vector3.INF or from.distance_squared_to(z) < from.distance_squared_to(best):
			best = z
	return best


# --- Resource Dispute ---

## A cache of `resource` at `at` (the director picks reachable treasure
## spots). Returns null for an unknown type.
func spawn_cache(world: SimWorld, resource: String, at: Vector3) -> Cache:
	if not HuntResources.has(resource):
		return null
	var c := Cache.new()
	c.id = _next_id
	_next_id += 1
	c.resource = resource
	c.position = at
	caches.append(c)
	world._emit("hy:%d:%d" % [c.id, world.tick], "hunt", {"action": "cache_spawned", "player": 0, "treasure": c.id,
			"kind": Kind.RESOURCE, "resource": resource, "position": at})
	return c


func active_caches() -> Array[Cache]:
	var out: Array[Cache] = []
	for c in caches:
		if not c.empty:
			out.append(c)
	return out


## Interact next to a cache with free hands starts collecting it; staying
## put and unhurt for its collect time turns it into carried cargo.
func _step_caches(world: SimWorld, ids: Array, interacting: Dictionary) -> void:
	for c in caches:
		if c.empty:
			continue
		if c.collector != 0:
			var p: SimPlayer = world.players.get(c.collector)
			var hp := p.state.shield + p.state.health if p != null else 0.0
			if p == null or not p.state.alive or carried_by(c.collector) != null \
					or _flat(p.state.position, c.position) > CACHE_RADIUS or hp < c.collector_hp - 0.01:
				_emit_cache(world, c, "cache_interrupted", c.collector)
				c.collector = 0
				c.progress = 0
				continue
			c.collector_hp = hp
			c.progress += 1 + squad.work_bonus(world, c.collector)  # an engineer beside you
			if c.progress >= HuntResources.collect_ticks(c.resource):
				var t := _new_treasure(Kind.RESOURCE, c.collector, c.position)
				t.resource = c.resource
				t.value = HuntResources.points(c.resource)
				t.carrier = c.collector
				c.empty = true
				_emit(world, t, "cache_collected", c.collector, {"resource": c.resource})
				c.collector = 0
			continue
		for id in ids:
			if not interacting.has(id) or _aux(id) or carried_by(id) != null:
				continue
			var p: SimPlayer = world.players[id]
			if p.state.alive and _flat(p.state.position, c.position) <= CACHE_RADIUS and not _collecting(id):
				c.collector = id
				c.progress = 0
				c.collector_hp = p.state.shield + p.state.health
				_emit_cache(world, c, "cache_started", id)
				break


func _collecting(id: int) -> bool:
	for c in caches:
		if c.collector == id:
			return true
	return false


func cache_of(collector: int) -> Cache:
	for c in caches:
		if c.collector == collector:
			return c
	return null


func _emit_cache(world: SimWorld, c: Cache, action: String, player: int) -> void:
	world._emit("hz%s:%d:%d" % [action.right(3), c.id, world.tick], "hunt", {"action": action, "player": player,
			"treasure": c.id, "kind": Kind.RESOURCE, "resource": c.resource, "position": c.position})


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Grand Vault Standoff ---

## Interact next to the locked grand treasure (free hands) starts unlocking;
## anyone can interrupt by damage. Done: unlocked, and the vault's
## secondary credits shared with an ally inside.
func _step_vault(world: SimWorld, ids: Array, interacting: Dictionary) -> void:
	var g := grand()
	if g == null or not g.locked or not g.on_ground() or world.tick < g.available_tick:
		vault_unlocker = 0
		return
	if vault_unlocker != 0:
		var p: SimPlayer = world.players.get(vault_unlocker)
		var hp := p.state.shield + p.state.health if p != null else 0.0
		if p == null or not p.state.alive or carried_by(vault_unlocker) != null \
				or _flat(p.state.position, g.position) > VAULT_UNLOCK_RADIUS or hp < _unlocker_hp - 0.01:
			_emit(world, g, "vault_interrupted", vault_unlocker)
			vault_unlocker = 0
			vault_progress = 0
			return
		_unlocker_hp = hp
		vault_progress += 1 + squad.work_bonus(world, vault_unlocker)
		if vault_progress >= vault_ticks():
			_unlock_vault(world, g, vault_unlocker)
		return
	for id in ids:
		if not interacting.has(id) or _aux(id) or carried_by(id) != null:
			continue
		var p: SimPlayer = world.players[id]
		if p.state.alive and _flat(p.state.position, g.position) <= VAULT_UNLOCK_RADIUS:
			vault_unlocker = id
			vault_progress = 0
			_unlocker_hp = p.state.shield + p.state.health
			_emit(world, g, "vault_unlocking", id)
			return


func _unlock_vault(world: SimWorld, g: Treasure, unlocker: int) -> void:
	g.locked = false
	vault_unlocker = 0
	vault_progress = 0
	var sharers: Array[int] = [unlocker]
	var ally: int = social.allies.get(unlocker, 0)
	var a: SimPlayer = world.players.get(ally)
	if a != null and a.state.alive and _flat(a.state.position, vault) <= VAULT_SHARE_RADIUS:
		sharers.append(ally)
	for id in sharers:
		economy.earn(world, id, VAULT_SHARE_CREDITS / sharers.size(), "vault_share")
	_emit(world, g, "vault_unlocked", unlocker, {"sharers": sharers})


# --- Last Extraction ---

## The match clock (the server calls this when play starts).
## When the run's clock started (-1: not yet): the opening truce counts from it.
var opened_tick: int = -1
## The first minute of a run, rival hunters go for the cargo, not each other
## (unless shot at, crowded or facing a carrier): no gunfire everywhere the
## moment you arrive.
const OPENING_TRUCE_TICKS := 60 * 60


func in_truce(tick: int) -> bool:
	return opened_tick >= 0 and tick - opened_tick < OPENING_TRUCE_TICKS


func set_clock(world: SimWorld, p_end_tick: int) -> void:
	if opened_tick < 0:
		opened_tick = world.tick
	end_tick = p_end_tick
	_announced = 0
	var keep := pit_rules and pit_rule == PitRule.ONE_PAD and final_zone >= 0
	var drawn := _rng.randi_range(0, zones.size() - 1) if not zones.is_empty() else -1
	final_zone = final_zone if keep else drawn
	world._emit("hk:%d" % world.tick, "hunt", {"action": "clock", "player": 0, "position": Vector3.ZERO,
			"treasure": 0, "kind": -1, "end_tick": end_tick})


## Rolls this run's pit conditions (from the match seed, on a stream of its
## own: the other draws stay as they were) and lays out the caches.
func _set_pit(world: SimWorld) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(["pit", world.match_seed])
	pit_rule = r.randi_range(0, PitRule.size() - 1)
	if pit_rule == PitRule.ONE_PAD and not zones.is_empty():
		final_zone = r.randi_range(0, zones.size() - 1)
	var free: Array[Vector3] = []
	for sp in spots:
		var used := false
		for t in treasures:
			if _flat(t.home, sp) < 3.0:
				used = true
				break
		if not used:
			free.append(sp)
	for k in mini(roundi(int(PIT_CACHES[pit_rule]) * mods.value("drops")), free.size()):
		var at: Vector3 = free.pop_at(r.randi_range(0, free.size() - 1))
		var res: String = HuntResources.IDS[r.randi_range(0, HuntResources.IDS.size() - 1)]
		if k < HuntResources.IDS.size():
			res = HuntResources.IDS[k]  # every kind at least once (the contracts ask for each)
		spawn_cache(world, res, _floor_at(world, at + Vector3.UP * 1.5))
	world._emit("hp:%d" % world.tick, "hunt", {"action": "pit_rule", "player": 0, "position": Vector3.ZERO,
			"treasure": 0, "kind": -1, "rule": pit_rule})


## Ticks of interacting it takes to open the vault (half on a hot vault).
func vault_ticks() -> int:
	return VAULT_UNLOCK_TICKS / 2 if pit_rules and pit_rule == PitRule.HOT_VAULT else VAULT_UNLOCK_TICKS


func zone_open(i: int, tick: int) -> bool:
	if pit_rules and pit_rule == PitRule.ONE_PAD and final_zone >= 0:
		return i == final_zone  # the cave-in: the one pad that works
	if end_tick <= 0 or tick < end_tick - LAST_EXTRACTION_TICKS:
		return true
	return i == final_zone


func final_phase(tick: int) -> bool:
	return end_tick > 0 and tick >= end_tick - FINAL_WARNING_TICKS


func ticks_left(tick: int) -> int:
	return maxi(end_tick - tick, 0) if end_tick > 0 else 1 << 30


func _step_last_extraction(world: SimWorld) -> void:
	if end_tick <= 0 or zones.is_empty():
		return
	var tick := world.tick
	if _announced < 1 and tick >= end_tick - FINAL_WARNING_TICKS:
		_announced = 1
		world._emit("hw:%d" % tick, "hunt", {"action": "final_warning", "player": 0, "treasure": 0, "kind": -1,
				"position": zones[final_zone], "zone": final_zone})
	if _announced < 2 and tick >= end_tick - LAST_EXTRACTION_TICKS:
		_announced = 2
		for id: int in extract_progress.keys():
			var c: SimPlayer = world.players.get(id)
			if c == null or not _in_zone(c.state.position, tick):
				extract_progress.erase(id)  # its pad just closed
		world._emit("hl:%d" % tick, "hunt", {"action": "last_extraction", "player": 0, "treasure": 0, "kind": -1,
				"position": zones[final_zone], "zone": final_zone})
	if _announced < 3 and tick >= end_tick:
		_announced = 3
		for t in treasures:
			if t.carrier != 0 and not t.banked:
				_emit(world, t, "cargo_lost", t.carrier)


## Points a hunter would bank for `t`.
static func value_for(t: Treasure, hunter: int) -> int:
	if t.kind == Kind.GRAND:
		return GRAND_POINTS
	if t.kind == Kind.PROOF or t.kind == Kind.RESOURCE:
		return t.value
	return OWN_POINTS if t.owner == hunter else STOLEN_POINTS


# --- Requests: one entry point for a human's menu and a bot's choices ---

## A hunter's deliberate choice. Every option a player can pick from a menu
## goes through here, for humans and bots alike, and is validated here (a
## network client would send the same request). Returns whether it was
## accepted. `action`: "accept_bounty" {target}.
func request(world: SimWorld, hunter: int, action: String, args: Dictionary = {}) -> bool:
	if not world.players.has(hunter):
		return false
	match action:
		"accept_bounty":
			return social.accept_contract(world, hunter, int(args.get("target", 0)))
		"hire_mercenary":
			return economy.hire(world, hunter)
		"merc_order":
			return economy.order(world, hunter, str(args.get("order", "")))
		"squad_order":
			return squad.order(world, hunter, str(args.get("order", "")), str(args.get("role", "")), int(args.get("target", 0)),
					args.get("point", Vector3.INF))
		"squad_ability":
			return squad.ability(world, self, hunter, str(args.get("ability", "")), args.get("point", Vector3.INF))
		"squad_rule":
			return squad.set_rule(world, hunter, str(args.get("rule", "")))
		"squad_spread":
			return squad.set_spread(world, hunter, str(args.get("spread", "")))
		"call_unit":
			return army.call_unit(world, self, hunter, str(args.get("unit", "")), args.get("target", Vector3.ZERO))
		"repair_camp":
			return war.enabled and war.builds.repair(world, self, hunter)
		"upgrade_module":
			return war.enabled and war.builds.upgrade(world, self, hunter, str(args.get("module", "")))
		"fly_to_camp":
			return war.enabled and war.builds.fly_to_camp(world, self, hunter)
		"war_ally":
			return war.propose_alliance(world, self, hunter, int(args.get("side", -1)))
		"war_betray":
			return war.break_alliance(world, self, hunter)
		"build":
			return war.enabled and war.builds.build(world, self, hunter, str(args.get("module", "")))
		"squad_strategy":
			return squad.set_strategy(world, hunter, str(args.get("strategy", "")), _plan_places(world, hunter))
		"dismiss_merc":
			if not economy.contracts.has(hunter):
				return false
			economy.end_contract(world, hunter, "dismissed")
			return true
		"propose_alliance":
			var to := int(args.get("target", 0))
			return not _aux(to) and not _aux(hunter) and social.propose(world, hunter, to)
		"respond_alliance":
			return social.respond(world, hunter, bool(args.get("accept", false)))
		"leave_alliance":
			return social.leave(world, hunter)
		"betray_alliance":
			return social.betray(world, hunter, str(args.get("reason", "")))
		"buy_intel":
			return buy_intel(world, hunter, str(args.get("kind", "")))
	return false


# --- Informant ---

## Buys a report (HuntEconomy.INTEL) from what the rules know, fuzzed by
## its confidence. Refused, at no cost, when there's nothing to report. An
## ally gets a copy (allies share information).
func buy_intel(world: SimWorld, hunter: int, kind: String) -> bool:
	if not HuntEconomy.INTEL.has(kind) or _aux(hunter) or not world.players.has(hunter):
		return false
	var spec: Dictionary = HuntEconomy.INTEL[kind]
	var me: SimPlayer = world.players[hunter]
	var report := {"kind": kind, "tick": world.tick, "confidence": spec.confidence, "subject": 0,
			"position": Vector3.INF, "expires": world.tick + int(spec.ttl) if int(spec.ttl) > 0 else 0}
	match kind:
		"cache_clue":
			var best: Cache = null
			for c in active_caches():
				if best == null or c.position.distance_to(me.state.position) < best.position.distance_to(me.state.position):
					best = c
			if best == null:
				return false
			report.position = _fuzz(best.position, spec.fuzz)
			report.subject = best.id
			report.resource = best.resource
		"vault_status":
			var g := grand()
			if g == null:
				return false
			report.position = vault
			report.locked = g.locked
			report.unlocking = vault_unlocker
			report.carrier = g.carrier
			report.back_in = maxi(g.available_tick - world.tick, 0) if g.banked else 0
		"rival_position":
			var target: SimPlayer = null
			for p: SimPlayer in world.players.values():
				if p.net_id == hunter or not p.state.alive or _aux(p.net_id) or social.allied(hunter, p.net_id):
					continue
				var carrying := carried_by(p.net_id) != null
				var better := target == null or (carrying and carried_by(target.net_id) == null) \
						or (carrying == (carried_by(target.net_id) != null) \
						and p.state.position.distance_to(me.state.position) < target.state.position.distance_to(me.state.position))
				if better:
					target = p
			if target == null:
				return false
			report.position = _fuzz(target.state.position, spec.fuzz)
			report.subject = target.net_id
			report.carrying = carried_by(target.net_id) != null
	if not economy.spend(hunter, int(spec.cost)):
		return false
	economy.add_intel(hunter, report)
	var ally: int = social.allies.get(hunter, 0)
	if ally != 0:
		economy.add_intel(ally, report.duplicate())
	world._emit("hi:%d:%d:%s" % [hunter, world.tick, kind], "hunt", {"action": "intel", "player": hunter,
			"intel": kind, "position": report.position, "treasure": 0, "kind": -1, "credits": economy.credits[hunter]})
	return true


## A cache report stays useful while its cache does.
func intel_useful(report: Dictionary, tick: int) -> bool:
	if int(report.expires) > 0 and tick >= int(report.expires):
		return false
	if report.kind == "cache_clue":
		for c in caches:
			if c.id == int(report.subject):
				return not c.empty
		return false
	return true


func _fuzz(at: Vector3, radius: float) -> Vector3:
	if radius <= 0.0:
		return at
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(radius * 0.4, radius)
	return at + Vector3(cos(a) * r, 0.0, sin(a) * r)


## Players who can't hurt each other (SimWorld._can_hurt): an employer and
## its mercenary. Allies can: turning on your squad is always possible
## (docs/game-plan.md, decision 3), and HuntSocial makes it a betrayal.
func protects(a: int, b: int) -> bool:
	return economy.protects(a, b) or squad.same_side(a, b)


## A hired gun or a squad's teammate: no hunter (no assignments, credits,
## bounties, alliances).
func _aux(id: int) -> bool:
	return economy.is_merc(id) or squad.is_member(id)


## Where a squad plan sends them: the enemy camp nearest the leader, the
## war's control point.
func _plan_places(world: SimWorld, leader: int) -> Dictionary:
	var out := {}
	var p: SimPlayer = world.players.get(leader)
	if p == null:
		return out
	if war.enabled:
		out["point"] = war.point
		var best := INF
		for c in war.camps:
			if c.side != war.side_of(self, leader) and c.at.distance_to(p.state.position) < best:
				best = c.at.distance_to(p.state.position)
				out["enemy_camp"] = c.at
	return out


## A heavy load: it needs an extraction machine at the pad in a war.
func _heavy(t: Treasure) -> bool:
	return t.kind == Kind.GRAND or t.kind == Kind.RESOURCE


## A teammate may pick up its leader's own cargo (to extract it for them).
func _may_carry(id: int, t: Treasure) -> bool:
	return squad.is_member(id) and t.kind == Kind.PERSONAL and t.owner == squad.leader_of(id)


# --- Internals ---

## The hunter it was stolen from has it back: the recovery bonus (once per
## item) and the contract closes.
func _recover(world: SimWorld, t: Treasure, hunter: int) -> void:
	var points := 0
	if not t.recovery_paid:
		t.recovery_paid = true
		points = RECOVERY_POINTS
		world.scores[hunter] = world.scores.get(hunter, 0) + points
	_emit(world, t, "recovered", hunter, {"points": points})
	t.stolen_from = 0
	recovery_clues.erase(hunter)


func _close_recovery(world: SimWorld, t: Treasure, action: String) -> void:
	if t.stolen_from == 0:
		return
	var victim := t.stolen_from
	t.stolen_from = 0
	recovery_clues.erase(victim)
	_emit(world, t, action, victim)


## While someone else carries a stolen treasure, its victim gets a fuzzed
## clue every RECOVERY_CLUE_TICKS (limited tracking, not a live marker).
func _recovery_clue(world: SimWorld, t: Treasure) -> void:
	if t.stolen_from == 0 or t.banked or t.carrier == 0 or t.carrier == t.stolen_from:
		return
	if world.tick < t.next_clue_tick or not world.players.has(t.stolen_from):
		return
	t.next_clue_tick = world.tick + RECOVERY_CLUE_TICKS
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(RECOVERY_CLUE_FUZZ * 0.4, RECOVERY_CLUE_FUZZ)
	var approx := t.position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	recovery_clues[t.stolen_from] = {"treasure": t.id, "position": approx, "tick": world.tick}
	world._emit("hr:%d:%d" % [t.id, world.tick], "hunt", {"action": "recovery_clue", "player": t.stolen_from,
			"treasure": t.id, "kind": t.kind, "owner": t.owner, "position": approx})


## The treasure stolen from `hunter` that is still out there, or null.
func stolen_from_hunter(hunter: int) -> Treasure:
	for t in treasures:
		if t.stolen_from == hunter and not t.banked:
			return t
	return null


func _floor_at(world: SimWorld, at: Vector3) -> Vector3:
	var hit := world._ray(at + Vector3.UP * 0.5, at + Vector3.DOWN * 20.0)
	return hit.position if not hit.is_empty() else at


func _assign(world: SimWorld, net_id: int) -> void:
	if spots.is_empty():
		return
	var free: Array[Vector3] = []
	for s in spots:
		var used := false
		for t in treasures:
			if _flat(t.home, s) < 0.5 and not t.banked:  # on the ground under the spot
				used = true
				break
		if not used:
			free.append(s)
	if free.size() < ASSIGNMENTS_PER_HUNTER:
		free = spots.duplicate()
	for i in ASSIGNMENTS_PER_HUNTER:
		var at: Vector3 = free[_rng.randi_range(0, free.size() - 1)]
		free.erase(at)
		# On the real ground (a spot from the terrain's formula can float
		# over a dip or sit in rock: out of reach for anyone on foot).
		_new_treasure(Kind.PERSONAL, net_id, _floor_at(world, at + Vector3.UP * 1.5))
		if free.is_empty():
			free = spots.duplicate()
	world._emit("hs:%d:%d" % [net_id, world.tick], "hunt", {"action": "assigned", "player": net_id,
			"position": Vector3.ZERO, "treasure": 0, "kind": Kind.PERSONAL})


func _new_treasure(kind: int, owner_id: int, at: Vector3) -> Treasure:
	var t := Treasure.new()
	t.id = _next_id
	_next_id += 1
	t.kind = kind
	t.owner = owner_id
	t.home = at
	t.position = at
	treasures.append(t)
	return t


func _drop(world: SimWorld, p: SimPlayer) -> void:
	var t := carried_by(p.net_id)
	if t == null:
		return
	var floor_hit := world._ray(p.state.position + Vector3.UP * 0.5, p.state.position + Vector3.DOWN * 20.0)
	t.carrier = 0
	t.position = floor_hit.position if not floor_hit.is_empty() else p.state.position
	t.return_tick = world.tick + DROPPED_RETURN_TICKS
	t.blocked_id = p.net_id
	t.blocked_until = world.tick + REPICK_TICKS
	extract_progress.erase(p.net_id)
	_emit(world, t, "drop", p.net_id)


# --- Vehicle holds (two compartments: what you carry, what your vehicle
# holds; robbing you never touches the vehicle, and its hold is searched
# separately, at its hatch) ---

## Treasures in vehicle `v`'s hold.
const HOLD_CAPACITY := 3
## Someone else's hold takes this long to search (interact held at the
## hatch); the one who stowed it takes it back at once.
const SEARCH_TICKS := 180
var _searching: Dictionary = {}  ## hunter id -> [vehicle, ticks searched]


func stowed_in(v: int) -> Array[Treasure]:
	var out: Array[Treasure] = []
	for t in treasures:
		if t.vehicle == v and not t.banked:
			out.append(t)
	return out


## Whether `p` stands at a vehicle's hatch with cargo to stow or to take
## (then interact is for the hold, not for boarding).
func at_a_hold_with_business(world: SimWorld, p: SimPlayer) -> bool:
	var hold := _hold_at(world, p.state.position)
	if hold < 0:
		return false
	return carried_by(p.net_id) != null or not stowed_in(hold).is_empty()


## The vehicle whose hatch `at` stands at (-1: none).
func _hold_at(world: SimWorld, at: Vector3) -> int:
	for i in world.vehicles.size():
		if VehicleSim.at_hold(world.vehicles[i], at):
			return i
	return -1


func _stow(world: SimWorld, c: SimPlayer, t: Treasure, v: int) -> void:
	t.carrier = 0
	t.vehicle = v
	t.stowed_by = c.net_id
	t.position = world.vehicles[v].position
	extract_progress.erase(c.net_id)
	_emit(world, t, "stow", c.net_id, {"vehicle": v})


## Holds: their cargo rides with the vehicle; a driver on a pad banks it
## all (whoever drives it there: a stolen vehicle pays its thief); a free
## hunter at a hatch takes one (searching someone else's takes a while).
func _step_holds(world: SimWorld, ids: Array, interacting: Dictionary) -> void:
	for t in treasures:
		if t.vehicle >= 0 and t.vehicle < world.vehicles.size():
			t.position = world.vehicles[t.vehicle].position
	for i in world.vehicles.size():
		var v: SimVehicle = world.vehicles[i]
		var cargo := stowed_in(i)
		if v.driver == 0 or cargo.is_empty():
			continue
		var d: SimPlayer = world.players.get(v.driver)
		if d == null or carried_by(v.driver) != null:
			continue  # (a carrier extracts by the usual count)
		if _in_zone(v.position, world.tick):
			var ticks: int = extract_progress.get(v.driver, 0) + 1 + army.extraction_boost(world, self, v.driver, v.position)
			extract_progress[v.driver] = ticks
			if ticks >= EXTRACT_TICKS:
				for t in cargo:
					t.vehicle = -1
					_bank(world, d, t)
		else:
			extract_progress.erase(v.driver)
	for id in ids:
		var p: SimPlayer = world.players[id]
		var hold := _hold_at(world, p.state.position) if p.state.alive and p.state.vehicle < 0 else -1
		if hold < 0 or carried_by(id) != null or _aux(id) or stowed_in(hold).is_empty():
			_searching.erase(id)
			continue
		var t: Treasure = stowed_in(hold)[0]
		var mine: bool = t.stowed_by == id
		if mine and interacting.has(id):
			_unstow(world, p, t)
			continue
		if mine:
			continue
		# Someone else's: hold interact at the hatch for SEARCH_TICKS.
		var s: Array = _searching.get(id, [hold, 0])
		if interacting.has(id) or int(s[1]) > 0:
			if s[0] != hold:
				s = [hold, 0]
			s[1] = int(s[1]) + 1
			_searching[id] = s
			if int(s[1]) == 1:
				_emit(world, t, "search", id, {"vehicle": hold})
			if int(s[1]) >= SEARCH_TICKS:
				_searching.erase(id)
				_unstow(world, p, t)


func _unstow(world: SimWorld, p: SimPlayer, t: Treasure) -> void:
	t.vehicle = -1
	t.carrier = p.net_id
	t.position = p.state.position
	_emit(world, t, "unstow", p.net_id, {"from": t.stowed_by})


func _bank(world: SimWorld, p: SimPlayer, t: Treasure) -> void:
	if squad.is_member(p.net_id) and world.players.has(squad.leader_of(p.net_id)):
		t.carrier = 0
		p = world.players[squad.leader_of(p.net_id)]  # a teammate banks for its leader
	var points := value_for(t, p.net_id)
	world.scores[p.net_id] = world.scores.get(p.net_id, 0) + points
	banked_count[p.net_id] = banked_count.get(p.net_id, 0) + 1
	var credit := int(points * HuntEconomy.EXTRACT_CREDIT_SHARE)
	if t.kind == Kind.RESOURCE:
		credit = roundi(HuntResources.credits(t.resource) * mods.value("resource_pay"))  # resources pay the expedition
	economy.earn(world, p.net_id, credit, "extraction")
	war.on_banked(world, self, p.net_id, t)
	economy.end_contract(world, p.net_id, "extracted")  # a contract ends on extraction
	extract_progress.erase(p.net_id)
	t.carrier = 0
	t.banked = true
	t.return_tick = 0
	if t.stolen_from != 0 and t.stolen_from != p.net_id:
		_close_recovery(world, t, "recovery_failed")  # the thief got away with it
	if t.kind == Kind.GRAND:
		t.available_tick = world.tick + GRAND_RESPAWN_TICKS
		social.on_grand_banked(world, p.net_id)
	var list: Array = haul.get(p.net_id, [])
	list.append({"item": loot_item(t, p.net_id), "value": points})
	haul[p.net_id] = list
	_emit(world, t, "extract", p.net_id, {"points": points})


## The career item an extraction yields (Career.ITEMS).
func loot_item(t: Treasure, hunter: int) -> String:
	match t.kind:
		Kind.GRAND:
			return "vault_relic"
		Kind.PROOF:
			return "bounty_proof"
		Kind.RESOURCE:
			return t.resource
	return "cargo_case" if t.owner == hunter else "stolen_cargo"


func _in_zone(pos: Vector3, tick: int = -1) -> bool:
	for i in zones.size():
		if tick >= 0 and not zone_open(i, tick):
			continue
		var z := zones[i]
		var d := pos - z
		if Vector2(d.x, d.z).length() <= EXTRACT_RADIUS and absf(d.y) <= PICKUP_HEIGHT:
			return true
	return false


func _emit(world: SimWorld, t: Treasure, action: String, player: int, extra: Dictionary = {}) -> void:
	var data := {"action": action, "player": player, "treasure": t.id, "kind": t.kind, "owner": t.owner,
			"position": t.position}
	data.merge(extra)
	world._emit("h%s:%d:%d:%d" % [action.left(2), t.id, player, world.tick], "hunt", data)
