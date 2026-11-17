class_name BotBrain
extends RefCounted
## Server-side bot (PLAN §2.7): produces the same PlayerCommand stream a
## human does, so bots use the same movement, weapons, validation and
## replication. Utility goals (attack / chase / retreat to regenerate /
## grab a power weapon or grenades / roam), path following with traversal links, human-like aim (reaction
## delay, turn-rate limit, tracking error; no wallhacks, no perfect aim) and
## stuck recovery. Perception runs at 10 Hz, re-pathing at most 2 Hz,
## staggered across bots.

enum Goal { ROAM, ATTACK, CHASE, RETREAT, PICKUP, OBJECTIVE }

const Held := PlayerCommand.Held
const Action := PlayerCommand.Action
const T := BotNavigation.Traversal

enum Difficulty { EASY, NORMAL, HARD, INSANE }
const DIFFICULTY_IDS := ["easy", "normal", "hard", "insane"]
## The tuning: difficulty levels (reaction, turn speed, aim error, grenade
## use), perception, fighting ranges and retreating.
const CONFIG: BotConfig = preload("res://data/bots.tres")
const PERCEPTION_INTERVAL := 6
const REPATH_INTERVAL := 30
const STUCK_CHECK_TICKS := 90
## A jump pad path point is reached this close (pads launch at their edge,
## JumpPads.RADIUS).
const PAD_REACH := 1.2
const SLOT_PRIMARY := 0
const SLOT_SIDEARM := 1
## THE HUNT: how far a dropped treasure is noticed, a carrier is worth
## chasing to steal from, the alarm is heard, and a melee swing reaches.
const HUNT_NOTICE_RANGE := 22.0
const HUNT_STEAL_RANGE := 25.0
const HUNT_ALARM_RANGE := 45.0
const HUNT_MELEE_RANGE := 2.2
const HUNT_ENGAGE_RANGE := 18.0
const HUNT_BOUNTY_RANGE := 80.0
const HUNT_BOUNTY_MIN_HEALTH := 150.0
const HUNT_RECOVERY_RANGE := 90.0
const HUNT_CLUE_TTL := 1500
const HUNT_RUN_SPEED := 6.0  ## m/s a bot covers on the navmesh, roughly (sprinting, turns)
const HUNT_LAST_CAMP_SECONDS := 25.0
const HUNT_CREDIT_MARGIN := 50
const HUNT_TRUST := 60  ## reputation a bot trusts as an ally
const HUNT_PROPOSAL_COOLDOWN := 600
const HUNT_BETRAY_WEAK := 60.0
const HUNT_BETRAY_LATE_TICKS := 14400  ## the last 4 minutes
const HUNT_ALLY_FAR := 60.0
const HUNT_ALLY_FAR_TICKS := 1200
const HUNT_INTEL_COOLDOWN := 1800

var goal: int = Goal.ROAM
var difficulty: int = Difficulty.NORMAL
var target_id: int = 0
var stuck_teleports: int = 0

var _world: SimWorld
var _nav: BotNavigation
var _id: int = 0
var _rng := RandomNumberGenerator.new()
var _presses := PackedByteArray([0, 0, 0, 0, 0, 0, 0])
var _yaw: float = 0.0
var _pitch: float = 0.0
var _disc: int = -1
var _visible: bool = false
var _seen_since: int = 0
var _last_seen_pos := Vector3.ZERO
var _last_seen_tick: int = -100000
var _retreat_until: int = 0
var _path: Array = []
var _path_i: int = 0
var _path_goal := Vector3.INF
var _last_repath: int = -100000
var _strafe: float = 1.0
var _strafe_until: int = 0
var _slot: int = SLOT_PRIMARY
var _throw_at: int = 0  ## tick to throw a grenade at the current target
var _noise_phase := Vector4.ZERO
var _progress_pos := Vector3.ZERO
var _progress_tick: int = 0
var _stuck_stage: int = 0
## THE HUNT: extraction pads this bot found it can't reach (zone index ->
## until tick), so it carries to another (_stuck_recovery).
var _blocked_zones: Dictionary = {}
const BLOCKED_TICKS := 1800
var _sidestep_until: int = 0
var _traversal: int = T.NONE
var _traversal_jumps: int = 0
var _destination := Vector3.INF  ## explicit roam target (objectives, pickups)
var _hit_tick: int = -100000  ## when we last took damage (THE HUNT: who to fight)
var _last_proposal: int = -100000  ## THE HUNT: when we last proposed an alliance
var _ally_far_since: int = -1
var _last_intel: int = -100000
## Co-op waves: hunt the nearest human instead of roaming.
var hunt: bool = false


## Roam towards `pos` instead of random points (until reached).
func go_to(pos: Vector3) -> void:
	_destination = pos
	_path = []
	_last_repath = -100000


var _reaction_ticks: int = 15
var _recoil_control: float = 0.5  ## share of the recoil pulled back down
var _max_turn: float = 0.1
var _aim_error: float = 0.035
var _aim_speed_error: float = 0.006
var _grenade_chance: float = 0.2
var _view_cos: float = cos(deg_to_rad(CONFIG.field_of_view_degrees) * 0.5)


func _init(world: SimWorld, nav: BotNavigation, id: int, seed_value: int, p_difficulty: int = Difficulty.NORMAL) -> void:
	_world = world
	_nav = nav
	_id = id
	_rng.seed = seed_value
	difficulty = clampi(p_difficulty, 0, CONFIG.difficulties.size() - 1)
	var t := CONFIG.difficulty(difficulty)
	_reaction_ticks = t.reaction_ticks
	_max_turn = deg_to_rad(t.turn_speed_degrees_per_second) / Sim.TICK_RATE
	_aim_error = deg_to_rad(t.aim_error_degrees)
	_aim_speed_error = deg_to_rad(t.moving_target_error_degrees)
	_grenade_chance = t.grenade_chance
	_recoil_control = t.recoil_control
	_noise_phase = Vector4(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)


## Damage tells a bot where its attacker is, even out of sight. THE HUNT:
## the vault alarm tells every bot nearby who set it off and where.
func on_event(e: Dictionary) -> void:
	if e.type == "hunt" and e.action == "alarm" and e.player != _id:
		var me: SimPlayer = _world.players.get(_id)
		if me != null and me.state.position.distance_to(e.position) <= HUNT_ALARM_RANGE \
				and _world.hunt.carried_by(_id) == null:
			_last_seen_pos = e.position
			_last_seen_tick = _world.tick
			target_id = e.player
		return
	if e.type == "hit" and e.target == _id and e.attacker != _id:
		_hit_tick = _world.tick
		var attacker: SimPlayer = _world.players.get(e.attacker)
		if attacker != null and not _visible:
			_last_seen_pos = attacker.state.position
			_last_seen_tick = _world.tick
			target_id = e.attacker


func command_for(tick: int, p: SimPlayer) -> PlayerCommand:
	var s := p.state
	if s.discontinuity_gen != _disc:  # spawned or teleported
		_disc = s.discontinuity_gen
		_yaw = s.yaw
		_pitch = 0.0
		_path = []
		_slot = SLOT_PRIMARY
		goal = Goal.ROAM
		target_id = 0
		_visible = false
		_progress_pos = s.position
		_progress_tick = tick
	var c := PlayerCommand.new()
	c.tick = tick
	if not s.alive or _nav == null or not _nav.ready_for_queries:
		c.set_look(_yaw, _pitch)
		c.presses = _presses.duplicate()
		return c
	if (tick + _id) % PERCEPTION_INTERVAL == 0:
		_perceive(tick, p)
		_choose_goal(tick, p)
	var held := 0
	var move := Vector3.ZERO
	var look_at := Vector3.INF
	var target: SimPlayer = _world.players.get(target_id)
	match goal:
		Goal.ATTACK:
			move = _attack_move(tick, p, target)
			look_at = _aim_point(target, p)
			# THE HUNT: close in on a treasure carrier and steal with a melee
			# hit (the same press a human makes).
			if _world.hunt != null and target != null and _world.hunt.carried_by(target.net_id) != null \
					and _world.hunt.carried_by(_id) == null:
				var to_target := target.state.position - p.state.position
				if to_target.length() > HUNT_MELEE_RANGE:
					move = Vector3(to_target.x, 0.0, to_target.z).normalized()
				elif p.state.melee_cooldown == 0:
					_press(Action.MELEE)
		Goal.CHASE:
			move = _follow(tick, p, _last_seen_pos)
			held |= Held.SPRINT if move.length() > 0.5 else 0
		Goal.RETREAT, Goal.PICKUP, Goal.OBJECTIVE:
			move = _follow(tick, p, _path_goal)
			held |= Held.SPRINT if move.length() > 0.5 else 0
			if goal == Goal.PICKUP and _power_weapon_in_reach(p):
				_press(Action.INTERACT)  # weapons aren't taken by walking over them
		_:
			if _destination != Vector3.INF:
				move = _follow(tick, p, _destination)
				if move == Vector3.ZERO and not _path.is_empty() and _path_i >= _path.size():
					_destination = Vector3.INF  # arrived
			else:
				if _path_goal == Vector3.INF or _path.is_empty() or _path_i >= _path.size():
					# A new wander target: drop the finished path so _follow
					# plans one (it re-paths only for an empty path or a goal
					# that moved, and _path_goal is the goal it compares with).
					_path_goal = _nav.random_point()
					_path = []
					_last_repath = -100000
				move = _follow(tick, p, _path_goal)
			held |= Held.SPRINT if move.length() > 0.5 else 0
	move = _stuck_recovery(tick, p, move)
	held |= _traversal_inputs(p, move)
	# Look: at the target while fighting, along the way otherwise.
	var want_yaw := _yaw
	var want_pitch := 0.0
	if look_at != Vector3.INF:
		var to := look_at - p.eye_position()
		want_yaw = atan2(-to.x, -to.z)
		want_pitch = atan2(to.y, Vector2(to.x, to.z).length())
		# Hold the weapon down against its recoil (shots go along look + recoil).
		want_yaw -= p.state.recoil.x * _recoil_control
		want_pitch -= p.state.recoil.y * _recoil_control
	elif move.length_squared() > 0.01:
		want_yaw = atan2(-move.x, -move.z)
	_yaw += clampf(wrapf(want_yaw - _yaw, -PI, PI), -_max_turn, _max_turn)
	_yaw = wrapf(_yaw, -PI, PI)
	_pitch += clampf(want_pitch - _pitch, -_max_turn, _max_turn)
	if goal == Goal.ATTACK and target != null:
		held = (held & ~Held.SPRINT) | _trigger(tick, p, target, want_yaw, want_pitch)
		# Scope in for longer shots, like players do.
		if p.state.position.distance_to(target.state.position) >= CONFIG.scope_range:
			held |= Held.AIM
	else:
		_manage_weapons_out_of_combat(p)
	c.set_look(_yaw, _pitch)
	c.set_move(_local(move))
	c.held = held
	c.weapon_slot = _slot if _slot != s.weapon_slot else -1
	c.presses = _presses.duplicate()
	return c


# --- Perception & goals ---

func _perceive(tick: int, p: SimPlayer) -> void:
	var eye := p.eye_position()
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var best := 0
	var best_d := INF
	for id in _world.players:
		if id == _id:
			continue
		var o: SimPlayer = _world.players[id]
		if not o.state.alive or (_world.teams_enabled and o.team == p.team):
			continue
		if _world.hunt != null and _world.hunt.friendly(_id, id):
			continue  # THE HUNT: our employer, our mercenary, our ally
		var chest := o.state.position + Vector3(0.0, 1.2, 0.0)
		var to := chest - eye
		var d := to.length()
		if d > CONFIG.view_range:
			continue
		var flat := Vector3(to.x, 0.0, to.z).normalized()
		if d > CONFIG.close_awareness and flat.dot(forward) < _view_cos and id != target_id:
			continue
		var space := p.get_world_3d().direct_space_state
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, chest, Sim.LAYER_WORLD)).is_empty():
			continue
		if d < best_d:
			best_d = d
			best = id
	var was_visible := _visible
	_visible = best != 0
	if _visible:
		if not was_visible or best != target_id:
			_seen_since = tick
			_strafe_until = 0
			# Splash primaries only at a safe range; the sidearm up close.
			var primary := p.state.weapon(SLOT_PRIMARY)
			_slot = SLOT_PRIMARY
			if primary.is_projectile() and (best_d < CONFIG.splash_min_range or best_d > CONFIG.splash_max_range):
				_slot = SLOT_SIDEARM
			if p.state.grenades > 0 and best_d >= CONFIG.grenade_min_range and best_d <= CONFIG.grenade_max_range \
					and _rng.randf() < _grenade_chance:
				_throw_at = tick + _reaction_ticks + 10
		target_id = best
		_last_seen_pos = _world.players[best].state.position
		_last_seen_tick = tick


func _choose_goal(tick: int, p: SimPlayer) -> void:
	var s := p.state
	if goal == Goal.RETREAT and tick < _retreat_until and s.shield < CONFIG.retreat_until_shield:
		return
	var target: SimPlayer = _world.players.get(target_id)
	# A flag carrier runs home, fights or not.
	if _world.flag_of(_id) != null:
		_set_objective(_objective(p))
		return
	if _world.hunt != null:
		_hunt_contracts(p)
		_hunt_diplomacy(tick, p)
	# THE HUNT: a treasure carrier heads for extraction; it only turns to
	# fight when someone is right on top of it.
	if _world.hunt != null and _world.hunt.carried_by(_id) != null:
		var close := _visible and target != null and target.state.position.distance_to(s.position) < 6.0
		if not close:
			_set_objective(_objective(p))
			return
	# THE HUNT: treasure first. A distant hunter is ignored unless it
	# carries treasure or is shooting at us (then on_event made it our
	# target and we remember being hit).
	# The opening truce: nobody opens fire; only someone who shot at us gets
	# shot back.
	if _world.hunt != null and _world.hunt.in_truce(tick) and tick - _hit_tick > CONFIG.chase_memory_ticks:
		var calm := _objective(p)
		if calm != Vector3.INF:
			_set_objective(calm)
			return
	if _world.hunt != null and _visible and target != null \
			and target.state.position.distance_to(s.position) > HUNT_ENGAGE_RANGE \
			and _world.hunt.carried_by(target_id) == null and not _world.hunt.social.is_wanted(target_id) \
			and tick - _hit_tick > CONFIG.chase_memory_ticks:
		var objective := _objective(p)
		if objective != Vector3.INF:
			_set_objective(objective)
			return
	if _visible and target != null:
		var losing := s.shield <= 0.0 and s.health < CONFIG.retreat_health \
				and target.state.shield + target.state.health > s.health + CONFIG.retreat_margin
		if losing and goal != Goal.RETREAT:
			goal = Goal.RETREAT
			_retreat_until = tick + CONFIG.retreat_ticks
			_path_goal = _retreat_point(p, target)
			_path = []
			_last_repath = -100000
			return
		goal = Goal.ATTACK
	elif tick - _last_seen_tick < CONFIG.chase_memory_ticks and target_id != 0:
		goal = Goal.CHASE
	else:
		target_id = 0
		var objective := _objective(p)
		if objective != Vector3.INF:
			_set_objective(objective)
			return
		var item := _wanted_item(p)
		if item != Vector3.INF:
			if goal != Goal.PICKUP or _path_goal.distance_to(item) > 0.5:
				_path_goal = item
				_path = []  # repath now: _follow keeps a path whose goal hasn't moved
				_last_repath = -100000
			goal = Goal.PICKUP
			return
		if goal != Goal.ROAM:
			_path_goal = Vector3.INF
		goal = Goal.ROAM


func _set_objective(at: Vector3) -> void:
	if at == Vector3.INF:
		return
	if goal != Goal.OBJECTIVE or _path_goal.distance_to(at) > 0.5:
		_path_goal = at
		_path = []
		_last_repath = -100000
	goal = Goal.OBJECTIVE


## Where the mode wants us (INF: nowhere in particular). Co-op hunters go for
## the nearest human. CTF: a carrier heads home; one bot in three defends
## (its own flag, or the base while the flag is home); the others take the
## enemy flag or escort its carrier; anyone recovers their own dropped flag.
func _objective(p: SimPlayer) -> Vector3:
	var s := p.state
	if _world.hunt != null:
		return _patient(p, _hunt_objective(p))
	if hunt:
		var best := Vector3.INF
		var best_d := INF
		for other: SimPlayer in _world.players.values():
			if other.team != p.team and other.state.alive and other.state.position.distance_to(s.position) < best_d:
				best_d = other.state.position.distance_to(s.position)
				best = other.state.position
		return best
	if _world.flags.size() < 2 or p.team > 1:
		return Vector3.INF
	var own: SimWorld.Flag = _world.flags[p.team]
	var enemy: SimWorld.Flag = _world.flags[1 - p.team]
	if enemy.carrier == _id:
		return own.base
	if not own.at_base() and own.carrier == 0:
		return own.position  # dropped: return it
	if _id % 3 == 0:  # defender
		if own.carrier != 0:
			return own.position  # chase the thief
		return own.base if s.position.distance_to(own.base) > 10.0 else Vector3.INF
	if enemy.carrier == 0:
		return enemy.position
	return enemy.position if enemy.carrier != _id else own.base  # escort our carrier


## THE HUNT (HuntRules), in order: extract what we carry; grab a dropped
## treasure we notice nearby; chase a visible carrier to steal; collect our
## own assignments; raid the vault for the grand treasure (every other bot
## goes for it first, the rest once their assignments are banked). INF:
## explore (roam).
func _hunt_objective(p: SimPlayer) -> Vector3:
	var h := _world.hunt
	var at := p.state.position
	var tick := _world.tick
	if h.carried_by(_id) != null:
		return _reachable_zone(h, at, tick)  # Last Extraction: only pads still open
	# Last Extraction: in the final phase, no new chases; only treasure we
	# can still bank in time; otherwise contest the last pad, and leave it
	# in the closing seconds instead of camping.
	var late := h.final_phase(tick)
	var secs_left := h.ticks_left(tick) / float(Sim.TICK_RATE)
	var best := Vector3.INF
	var best_d := INF
	for t: HuntRules.Treasure in h.treasures:
		if t.on_ground() and t.return_tick > 0 and not (t.blocked_id == _id and _world.tick < t.blocked_until):
			var d := t.position.distance_to(at)
			if d < HUNT_NOTICE_RANGE and d < best_d and (not late or _can_bank_in_time(at, t.position, secs_left, tick)):
				best_d = d
				best = t.position
	if best != Vector3.INF:
		return best
	var target: SimPlayer = _world.players.get(target_id)
	if _visible and target != null and h.carried_by(target_id) != null \
			and target.state.position.distance_to(at) < HUNT_STEAL_RANGE:
		return target.state.position
	# Recovery Contract: follow the latest clue to our stolen treasure, unless
	# it's stale, too far, or we're too hurt to take it back.
	var clue: Dictionary = h.recovery_clues.get(_id, {}) if not late else {}
	if not clue.is_empty() and _world.tick - int(clue.tick) < HUNT_CLUE_TTL \
			and at.distance_to(clue.position) < HUNT_RECOVERY_RANGE \
			and p.state.shield + p.state.health >= HUNT_BOUNTY_MIN_HEALTH * 0.8:
		return clue.position
	var bounty_at := _bounty_target(p) if not late else Vector3.INF
	if bounty_at != Vector3.INF:
		return bounty_at
	var own_left := false
	for t: HuntRules.Treasure in h.assignments_of(_id):
		if t.on_ground() and (not late or _can_bank_in_time(at, t.position, secs_left, tick)):
			own_left = true
			var d := t.position.distance_to(at)
			if d < best_d:
				best_d = d
				best = t.position
	var grand := h.grand()
	var grand_open := h.grand_available(_world.tick)
	if late and grand_open and not _can_bank_in_time(at, grand.position, secs_left, tick):
		grand_open = false
	var cache_at := _cache_choice(p, best_d if best != Vector3.INF else INF, late, secs_left)
	if cache_at != Vector3.INF:
		return cache_at
	if grand_open and (not own_left or _id % 2 == 0 and grand.position.distance_to(at) < best_d * 1.5):
		return _vault_move(p, grand)
	if best != Vector3.INF:
		return best
	if late:
		return h.nearest_zone(at, tick) if secs_left > HUNT_LAST_CAMP_SECONDS else Vector3.INF
	if grand != null and grand.carrier != 0 and grand.carrier != _id:
		var c: SimPlayer = _world.players.get(grand.carrier)
		if c != null and h.is_revealed(grand.carrier, _world.tick):
			return c.state.position
	if not late:
		return _intel_lead(p)
	return Vector3.INF


## Informant: with nothing else to do, buy a rival's position (if the
## credits allow with a margin, not too often) and follow it only when that
## rival carries cargo worth stealing. Positions come from bought intel,
## never from the rules' live state.
func _intel_lead(p: SimPlayer) -> Vector3:
	var h := _world.hunt
	var at := p.state.position
	if p.state.shield + p.state.health < HUNT_BOUNTY_MIN_HEALTH:
		return Vector3.INF
	for r: Dictionary in h.economy.intel_of(_id, _world.tick):
		if r.kind == "rival_position" and r.get("carrying", false) and h.intel_useful(r, _world.tick) \
				and at.distance_to(r.position) < HUNT_BOUNTY_RANGE:
			return r.position
	var cost: int = HuntEconomy.INTEL.rival_position.cost
	if _world.tick - _last_intel > HUNT_INTEL_COOLDOWN and h.economy.credits.get(_id, 0) >= cost + HUNT_CREDIT_MARGIN:
		_last_intel = _world.tick
		h.request(_world, _id, "buy_intel", {"kind": "rival_position"})
	return Vector3.INF


## Grand Vault Standoff: unlock the grand treasure (interact, hold still);
## while an ally unlocks, cover it; a rival unlocking is contested only by
## a stronger bot (perception then fights it at close range).
func _vault_move(p: SimPlayer, grand: HuntRules.Treasure) -> Vector3:
	var h := _world.hunt
	var at := p.state.position
	if not grand.locked:
		return grand.position
	if h.vault_unlocker == _id:
		return at
	if h.vault_unlocker != 0:
		var u: SimPlayer = _world.players.get(h.vault_unlocker)
		if h.social.allied(_id, h.vault_unlocker):
			return at if at.distance_to(grand.position) < 6.0 else grand.position
		if u != null and u.state.shield + u.state.health > p.state.shield + p.state.health:
			return at if at.distance_to(grand.position) < 14.0 else grand.position  # wait for a better moment
		return grand.position
	if HuntRules._flat(at, grand.position) <= HuntRules.VAULT_UNLOCK_RADIUS - 0.3:
		_press(Action.INTERACT)
	return grand.position


## Alliances (Vault Standoff, Double-Cross). Accept a proposal from a
## reliable hunter (reputation >= HUNT_TRUST) when it helps us (we're
## outmatched, at the vault, or outnumbered); never from a Wanted hunter or
## one holding something stolen from us. Propose to a rival at the vault who
## is at least as strong as we are. The same requests a human makes.
func _hunt_diplomacy(tick: int, p: SimPlayer) -> void:
	var h := _world.hunt
	var social := h.social
	var at := p.state.position
	var offer: Dictionary = social.proposals.get(_id, {})
	if not offer.is_empty():
		var from: SimPlayer = _world.players.get(int(offer.from))
		var accept := from != null and social.rep_of(from.net_id) >= HUNT_TRUST and not social.is_wanted(from.net_id)
		var stolen := h.stolen_from_hunter(_id)
		if accept and stolen != null and stolen.carrier == from.net_id:
			accept = false
		if accept:
			var outmatched := from.state.shield + from.state.health > p.state.shield + p.state.health
			var near_vault := at.distance_to(h.vault) < 25.0
			accept = outmatched or near_vault or _visible_rivals(p) >= 2
		h.request(_world, _id, "respond_alliance", {"accept": accept})
		return
	if social.allies.has(_id):
		_keep_or_break(tick, p)
		return
	if tick - _last_proposal < HUNT_PROPOSAL_COOLDOWN:
		return
	var g := h.grand()
	if g == null or not h.grand_available(tick) or at.distance_to(h.vault) > 20.0:
		return
	var target: SimPlayer = _world.players.get(target_id)
	if _visible and target != null and not h.economy.is_merc(target_id) and social.rep_of(target_id) >= HUNT_TRUST \
			and target.state.position.distance_to(at) < 20.0 \
			and target.state.shield + target.state.health >= p.state.shield + p.state.health:
		_last_proposal = tick
		h.request(_world, _id, "propose_alliance", {"target": target_id})


## Double-Cross: a bot honours its alliance unless a reason that fits who
## it is holds (HuntRules.personalities, docs/game-plan.md decision 3). It
## never turns when the run says it may not (HuntRules.may_turn: the career
## paces turns on you so they never become a pattern). Nothing random.
##   grudge (its partner turned on it before): it settles the score when the
##     partner is cashing in (extracting) or down to half strength, close by.
##   ambitious: takes the grand treasure or a 100+ prize off a badly hurt
##     partner when time is short or it trails on points.
##   steady: only the grand treasure, only late, only off a beaten partner.
##   loyal: never turns first.
## Pacts (not squads) also end peacefully when the partner has been far
## away for a while: the alliance no longer helps.
func _keep_or_break(tick: int, p: SimPlayer) -> void:
	var h := _world.hunt
	var partner_id: int = h.social.allies[_id]
	var partner: SimPlayer = _world.players.get(partner_id)
	if partner == null or h.social.dissolving.has(_id):
		return
	var d := partner.state.position.distance_to(p.state.position)
	var reason := _turn_reason(tick, p, partner, d) if bool(h.may_turn.get(_id, true)) else ""
	if reason != "":
		h.request(_world, _id, "betray_alliance", {"reason": reason})
		target_id = partner_id  # and go for the cargo (steal by melee)
		return
	if h.social.is_squad(_id):
		return  # a squad splits up and meets again; it doesn't dissolve
	if d > HUNT_ALLY_FAR:
		if _ally_far_since < 0:
			_ally_far_since = tick
		elif tick - _ally_far_since > HUNT_ALLY_FAR_TICKS:
			h.request(_world, _id, "leave_alliance")
			_ally_far_since = -1
	else:
		_ally_far_since = -1


## Why this bot would turn on `partner` now ("" for no reason): the forms
## differ by character, so a turn is never the same scene twice.
func _turn_reason(tick: int, p: SimPlayer, partner: SimPlayer, d: float) -> String:
	var h := _world.hunt
	var mine := p.state.shield + p.state.health
	var theirs := partner.state.shield + partner.state.health
	if mine < HUNT_BOUNTY_MIN_HEALTH or d > 15.0:
		return ""
	var cargo := h.carried_by(partner.net_id)
	if bool(h.grudges.get(_id, false)):
		if cargo != null and (int(h.extract_progress.get(partner.net_id, 0)) > 0 or theirs < HUNT_BETRAY_WEAK * 1.5):
			return "grudge"
		return ""
	if cargo == null:
		return ""
	var late := h.ticks_left(tick) < HUNT_BETRAY_LATE_TICKS
	match str(h.personalities.get(_id, "ambitious")):
		"ambitious":
			if (cargo.kind == HuntRules.Kind.GRAND or HuntRules.value_for(cargo, _id) >= 100) and theirs < HUNT_BETRAY_WEAK \
					and (late or _world.scores.get(_id, 0) < _world.scores.get(partner.net_id, 0)):
				return "prize"
		"steady":
			if cargo.kind == HuntRules.Kind.GRAND and theirs < HUNT_BETRAY_WEAK * 0.6 and late:
				return "grand"
	return ""


func _visible_rivals(p: SimPlayer) -> int:
	var n := 0
	var eye := p.eye_position()
	var space := p.get_world_3d().direct_space_state
	for id: int in _world.players:
		var o: SimPlayer = _world.players[id]
		if id == _id or not o.state.alive or o.state.position.distance_to(p.state.position) > 30.0:
			continue
		if _world.hunt.friendly(_id, id):
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, o.state.position + Vector3(0, 1.2, 0), Sim.LAYER_WORLD)).is_empty():
			n += 1
	return n


## Resource Dispute: a cache worth more (per metre) than our best
## assignment; one a rival is collecting only when we're healthy and it
## looks weak; in the final phase only if it can still be banked. At the
## cache: interact (the same press a human makes) and hold still.
func _cache_choice(p: SimPlayer, own_d: float, late: bool, secs_left: float) -> Vector3:
	var h := _world.hunt
	var at := p.state.position
	var mine := h.cache_of(_id)
	if mine != null:
		return at  # collecting: stay put
	var best: HuntRules.Cache = null
	var best_score := 100.0 / maxf(own_d, 8.0) if own_d < INF else 0.0
	for c: HuntRules.Cache in h.active_caches():
		if late and not _can_bank_in_time(at, c.position, secs_left, _world.tick):
			continue
		if c.collector != 0:
			var rival: SimPlayer = _world.players.get(c.collector)
			if rival == null or p.state.shield + p.state.health < HUNT_BOUNTY_MIN_HEALTH \
					or rival.state.shield + rival.state.health > 100.0:
				continue
		var score := HuntResources.points(c.resource) / maxf(at.distance_to(c.position), 8.0)
		if score > best_score:
			best_score = score
			best = c
	if best == null:
		return Vector3.INF
	if best.collector == 0 and HuntRules._flat(at, best.position) <= HuntRules.CACHE_RADIUS - 0.3:
		_press(Action.INTERACT)
	return best.position


## Mercenary Contract: hire protection when there is something worth
## protecting (Wanted, carrying the grand treasure, or going for it) and the
## credits allow it with a margin; keep the mercenary defending while we
## carry and following otherwise. The same requests a human makes.
func _hunt_contracts(p: SimPlayer) -> void:
	var h := _world.hunt
	var econ := h.economy
	if econ.is_merc(_id):
		return
	var carrying := h.carried_by(_id)
	var c: HuntEconomy.Contract = econ.contracts.get(_id)
	if c == null:
		var worth := h.social.is_wanted(_id) or (carrying != null and carrying.kind == HuntRules.Kind.GRAND) \
				or (h.grand_available(_world.tick) and p.state.position.distance_to(h.grand().position) < 40.0)
		if worth and econ.credits.get(_id, 0) >= HuntEconomy.MERC_COST + HUNT_CREDIT_MARGIN and not h.final_phase(_world.tick):
			h.request(_world, _id, "hire_mercenary")
		return
	var want := "defend" if carrying != null else "follow"
	if HuntEconomy.ORDER_IDS[c.order] != want:
		h.request(_world, _id, "merc_order", {"order": want})


## Last Extraction: whether a treasure at `item` can still reach an open pad
## before the bell (running speed, plus the extraction time and a margin).
func _can_bank_in_time(at: Vector3, item: Vector3, secs_left: float, tick: int) -> bool:
	var zone := _world.hunt.nearest_zone(item, tick + int(secs_left * Sim.TICK_RATE * 0.5))
	if zone == Vector3.INF:
		return false
	var metres := at.distance_to(item) + item.distance_to(zone)
	return metres / HUNT_RUN_SPEED + HuntRules.EXTRACT_TICKS / float(Sim.TICK_RATE) + 8.0 < secs_left


## Most Wanted: the best Wanted hunter worth chasing, by its published
## last-known position only (no live tracking). Only when healthy and armed,
## and only if the bounty is worth the distance; accepts the contract (the
## same request a human makes from the menu).
func _bounty_target(p: SimPlayer) -> Vector3:
	var s := p.state
	var social := _world.hunt.social
	if s.shield + s.health < HUNT_BOUNTY_MIN_HEALTH or not (s.mag[SLOT_PRIMARY] > 0 or s.has_reserve(SLOT_PRIMARY)):
		return Vector3.INF
	var best := Vector3.INF
	var best_score := 0.0
	var best_id := 0
	for id: int in social.last_known:
		if id == _id or not social.is_wanted(id):
			continue
		var lk: Dictionary = social.last_known[id]
		var d := s.position.distance_to(lk.position)
		var score := float(social.bounty.get(id, 0)) - d * 0.6
		if d < HUNT_BOUNTY_RANGE and score > best_score:
			best_score = score
			best = lk.position
			best_id = id
	if best_id != 0 and social.contracts.get(_id, 0) != best_id:
		_world.hunt.request(_world, _id, "accept_bounty", {"target": best_id})
	return best


## The nearest power weapon (holding none) or grenade pickup (short of
## grenades) in fetching range, or INF.
func _wanted_item(p: SimPlayer) -> Vector3:
	var s := p.state
	var best := Vector3.INF
	var best_d := INF
	for it: SimWorld.Item in _world.items:
		var d := it.position.distance_to(s.position)
		var want := false
		if it.weapon < 0:
			want = s.grenades < Balance.PLAYER.grenades_per_life and d < CONFIG.grenade_fetch_range
		else:
			want = Weapons.at(it.weapon).is_power_weapon and not s.weapon(0).is_power_weapon and d < CONFIG.power_fetch_range
		if want and d < best_d:
			best_d = d
			best = it.position
	return best


## Whether a power weapon lies within pickup reach while `p` holds none (so
## interact takes it, not the primary it drops a tick later).
func _power_weapon_in_reach(p: SimPlayer) -> bool:
	var s := p.state
	if s.weapon(0).is_power_weapon:
		return false
	for it: SimWorld.Item in _world.items:
		if it.weapon < 0 or not Weapons.at(it.weapon).is_power_weapon:
			continue
		var d := s.position - it.position
		if Vector2(d.x, d.z).length() <= Balance.PLAYER.pickup_radius and absf(d.y) <= SimWorld.PICKUP_HEIGHT:
			return true
	return false


func _retreat_point(p: SimPlayer, threat: SimPlayer) -> Vector3:
	var best := p.state.position
	var best_d := -1.0
	for i in 6:
		var candidate := _nav.random_point()
		var d := candidate.distance_to(threat.state.position) - candidate.distance_to(p.state.position) * 0.5
		if d > best_d:
			best_d = d
			best = candidate
	return best


# --- Movement ---

func _attack_move(tick: int, p: SimPlayer, target: SimPlayer) -> Vector3:
	if target == null:
		return Vector3.ZERO
	var to := target.state.position - p.state.position
	to.y = 0.0
	var d := to.length()
	if d > CONFIG.follow_beyond:
		return _follow(tick, p, target.state.position)
	if tick >= _strafe_until:
		_strafe = -_strafe if _rng.randf() < 0.7 else _strafe
		_strafe_until = tick + _rng.randi_range(30, 80)
	var dir := to / maxf(d, 0.01)
	var side := Vector3(-dir.z, 0.0, dir.x) * _strafe
	var approach := 0.0
	if d > CONFIG.approach_beyond:
		approach = 0.7
	elif d < CONFIG.back_off_within:
		approach = -0.6
	if _rng.randf() < 0.008:
		_press(Action.JUMP)
	return (side + dir * approach).limit_length(1.0)


## Whether `pos` is far from any baked navmesh (no path can be had there).
## Feelers for open ground: a wall, rock or building straight ahead turns the
## bot along it (45° then 90° either side, the side it last chose first)
## instead of running into it.
var _feel_side: float = 1.0


func _feel(p: SimPlayer, dir: Vector3) -> Vector3:
	if not p.is_inside_tree():
		return dir
	var space := p.get_world_3d().direct_space_state
	var from := p.state.position + Vector3(0, 0.7, 0)
	for turn: float in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0]:
		var d := dir.rotated(Vector3.UP, deg_to_rad(turn * _feel_side))
		var q := PhysicsRayQueryParameters3D.create(from, from + d * 2.5, Sim.LAYER_WORLD)
		if space.intersect_ray(q).is_empty():
			if turn < 0.0:
				_feel_side = -_feel_side
			return d
	return dir


func _off_mesh(pos: Vector3) -> bool:
	if not _nav.ready_for_queries:
		return false
	return _nav.closest_point(pos).distance_to(pos) > 4.0


## Steers along a navmesh path to `goal_pos`; returns a world-space
## direction (length ≤ 1). Re-paths at most every REPATH_INTERVAL ticks.
func _follow(tick: int, p: SimPlayer, goal_pos: Vector3) -> Vector3:
	var pos := p.state.position
	var moved_goal := _path_goal == Vector3.INF or _path_goal.distance_to(goal_pos) > 2.0
	if (moved_goal or _path.is_empty()) and tick - _last_repath >= REPATH_INTERVAL:
		_path_goal = goal_pos
		_path = _nav.path(pos, goal_pos)
		_path_i = 1 if _path.size() > 1 else 0
		_last_repath = tick
	if _path.is_empty() and _off_mesh(pos):
		# Open ground no navmesh covers (THE HUNT's valley): head straight there.
		var straight := Vector3(goal_pos.x - pos.x, 0.0, goal_pos.z - pos.z)
		if straight.length() <= 1.0:
			return Vector3.ZERO
		return _feel(p, straight.normalized())
	if _path.is_empty() or _path_i >= _path.size():
		return Vector3.ZERO
	var next: Vector3 = _path[_path_i][0]
	var flat := Vector3(next.x - pos.x, 0.0, next.z - pos.z)
	# The navmesh floats ~0.5 m above the floor: compare heights loosely. A
	# pad launches on its edge, so a pad's centre counts as reached early.
	var reach := PAD_REACH if _path[_path_i][1] == T.PAD else 0.6
	if flat.length() < reach and absf(next.y - 0.5 - pos.y) < 1.2:
		_path_i += 1
		_traversal = T.NONE
		_traversal_jumps = 0
		if _path_i >= _path.size():
			return Vector3.ZERO
		next = _path[_path_i][0]
		flat = Vector3(next.x - pos.x, 0.0, next.z - pos.z)
	# Entering a link segment: the previous point's traversal applies.
	var link: int = _path[_path_i - 1][1] if _path_i > 0 else T.NONE
	if link != _traversal:
		_traversal = link
		_traversal_jumps = 0
	return flat.normalized()


## Jumps for traversal links: jump + hold for mantles, a second jump near the
## apex for tall ledges. Mantling itself is the normal movement code.
func _traversal_inputs(p: SimPlayer, move: Vector3) -> int:
	if _traversal == T.NONE or _traversal == T.DROP or _traversal == T.PAD or move.length_squared() < 0.01:
		return 0
	var s := p.state
	var on_floor := s.move_state != PlayerSimState.Move.AIR and s.move_state != PlayerSimState.Move.MANTLE
	if on_floor and _traversal_jumps == 0:
		_press(Action.JUMP)
		_traversal_jumps = 1
	elif _traversal == T.DOUBLE_JUMP_MANTLE and _traversal_jumps == 1 and not on_floor and s.velocity.y < 1.5:
		_press(Action.JUMP)
		_traversal_jumps = 2
	return Held.JUMP


## No progress for 90 ticks → jump, then sidestep, then re-path, then
## teleport to the nearest navmesh point (last resort, logged).
## Progress toward the objective: a target the bot gets no closer to in
## PATIENCE_TICKS is out of reach from where it is (a ledge the navmesh
## thinks is a ramp). A pad is given up for BLOCKED_TICKS (a carrier takes
## another); anything else for a while, roaming somewhere else meanwhile.
const PATIENCE_TICKS := 900
var _aim_target := Vector3.INF
var _aim_best := INF
var _aim_since: int = 0
var _avoid_target := Vector3.INF
var _avoid_until: int = 0


func _patient(p: SimPlayer, target: Vector3) -> Vector3:
	var tick := _world.tick
	if target == Vector3.INF:
		_aim_target = Vector3.INF
		return target
	if _avoid_target != Vector3.INF and tick < _avoid_until and target.distance_to(_avoid_target) < 4.0:
		return Vector3.INF  # roam elsewhere first
	if _aim_target == Vector3.INF or target.distance_to(_aim_target) > 4.0:
		_aim_target = target
		_aim_best = INF
		_aim_since = tick
	var d := p.state.position.distance_to(target)
	if d < _aim_best - 2.0:
		_aim_best = d
		_aim_since = tick
	elif tick - _aim_since > PATIENCE_TICKS and d > 2.5:
		var zone := _zone_near(target)
		if zone >= 0 and _world.hunt.carried_by(_id) != null:
			_blocked_zones[zone] = tick + BLOCKED_TICKS
		else:
			_avoid_target = target
			_avoid_until = tick + PATIENCE_TICKS * 2
		_aim_target = Vector3.INF
		_last_repath = -100000
		return _patient(p, _hunt_objective(p))
	return target


## The nearest open pad this bot hasn't found unreachable (INF if all of
## them are: it moves elsewhere and tries again once the block expires).
func _reachable_zone(h: HuntRules, at: Vector3, tick: int) -> Vector3:
	var best := Vector3.INF
	for i in h.zones.size():
		if not h.zone_open(i, tick) or int(_blocked_zones.get(i, -1)) > tick:
			continue
		if best == Vector3.INF or at.distance_squared_to(h.zones[i]) < at.distance_squared_to(best):
			best = h.zones[i]
	return best  # INF when every open pad is out of reach from here: roam, then try again


## The index of the pad nearest `where` (-1 if none within 20 m).
func _zone_near(where: Vector3) -> int:
	var h := _world.hunt
	for i in h.zones.size():
		if HuntRules._flat(h.zones[i], where) < 20.0:
			return i
	return -1


func _stuck_recovery(tick: int, p: SimPlayer, move: Vector3) -> Vector3:
	if tick < _sidestep_until:
		return Vector3(-move.z, 0.0, move.x) if move.length_squared() > 0.01 else Vector3.RIGHT
	if move.length_squared() < 0.01 or goal == Goal.ATTACK:
		_progress_pos = p.state.position
		_progress_tick = tick
		_stuck_stage = 0
		return move
	if tick - _progress_tick < STUCK_CHECK_TICKS:
		return move
	if p.state.position.distance_to(_progress_pos) > 1.0:
		_stuck_stage = 0
	else:
		_stuck_stage += 1
		match _stuck_stage:
			1:
				_press(Action.JUMP)
			2:
				_sidestep_until = tick + 30
			3:
				_path = []
				_path_goal = _nav.random_point() if goal == Goal.ROAM else _path_goal
				_last_repath = -100000
			_:
				var spot := _nav.closest_point(p.state.position + Vector3(0.0, 1.0, 0.0))
				if spot.distance_to(p.state.position) < 1.5 and _world.hunt != null:
					# On the navmesh already, and still no way on: the place it
					# heads for can't be reached from here. Give up on it for a
					# while (a carrier picks another pad) rather than loop, and
					# step out of the pocket to open ground a few metres off.
					_blocked_zones[_zone_near(_path_goal)] = tick + BLOCKED_TICKS
					_last_repath = -100000
					var a := float(tick % 360) * 0.0174533 * 37.0
					var out := _nav.closest_point(p.state.position + Vector3(cos(a), 0.0, sin(a)) * 4.0 + Vector3.UP)
					if out.distance_to(p.state.position) > 1.5:
						_world.teleport(p, out + Vector3(0.0, 0.1, 0.0))
						stuck_teleports += 1
				else:
					_world.teleport(p, spot + Vector3(0.0, 0.1, 0.0))
					stuck_teleports += 1
					print("BOT %d stuck at %s: teleported to %s" % [_id, p.state.position, spot])
				_stuck_stage = 0
				_path = []
	_progress_pos = p.state.position
	_progress_tick = tick
	return move


# --- Aim & weapons ---

## Chest, or the feet for splash weapons, plus smooth tracking error that
## grows with the target's sideways speed.
func _aim_point(target: SimPlayer, p: SimPlayer) -> Vector3:
	if target == null:
		return Vector3.INF
	var ts := target.state
	var splash := p.state.weapon(_slot) != null and p.state.weapon(_slot).is_projectile()
	var base := ts.position + Vector3(0.0, 0.3 if splash else 1.2, 0.0)
	var to := base - p.eye_position()
	var d := maxf(to.length(), 1.0)
	var lateral := (ts.velocity - ts.velocity.project(to.normalized())).length()
	var amplitude := _aim_error + _aim_speed_error * lateral
	var t := float(_world.tick) * 0.05
	var err_yaw := amplitude * (sin(t * 1.3 + _noise_phase.x) * 0.7 + sin(t * 3.1 + _noise_phase.y) * 0.3)
	var err_pitch := amplitude * 0.6 * (sin(t * 1.7 + _noise_phase.z) * 0.7 + sin(t * 2.9 + _noise_phase.w) * 0.3)
	var right := to.cross(Vector3.UP).normalized()
	return base + right * tan(err_yaw) * d + Vector3.UP * tan(err_pitch) * d


func _trigger(tick: int, p: SimPlayer, target: SimPlayer, want_yaw: float, want_pitch: float) -> int:
	var s := p.state
	if tick - _seen_since < _reaction_ticks or not _visible:
		return 0
	var w := s.weapon_slot
	var d := p.state.position.distance_to(target.state.position)
	if d < CONFIG.melee_range and s.melee_cooldown == 0:
		_press(Action.MELEE)
		return 0
	if _throw_at > 0 and tick >= _throw_at:
		_throw_at = 0
		if s.grenades > 0 and d >= CONFIG.grenade_min_range:
			_press(Action.GRENADE)
			return 0
	if w != _slot or s.switch_ticks > 0:
		return 0
	# Out of ammo: sidearm is faster than reloading the primary.
	if s.mag[w] <= 0:
		if w == SLOT_PRIMARY and s.mag[SLOT_SIDEARM] > 0:
			_slot = SLOT_SIDEARM
		elif w == SLOT_SIDEARM and (s.mag[SLOT_PRIMARY] > 0 or s.has_reserve(SLOT_PRIMARY)):
			_slot = SLOT_PRIMARY
		elif s.reload[w] == 0:
			_press(Action.RELOAD)
		return 0
	var aim_error := absf(wrapf(want_yaw - _yaw, -PI, PI)) + absf(want_pitch - _pitch)
	if aim_error > atan2(0.45, d) + 0.03:
		return 0
	var data := s.weapon(w)
	if data.fire_mode == WeaponData.FireMode.AUTO:
		return Held.FIRE
	if s.cooldown[w] == 0 and s.reload[w] == 0:
		_press(Action.FIRE)
	return 0


func _manage_weapons_out_of_combat(p: SimPlayer) -> void:
	var s := p.state
	_slot = SLOT_PRIMARY
	var w := s.weapon_slot
	if w == SLOT_PRIMARY and s.reload[w] == 0 and s.mag[w] * 2 < s.weapon(w).mag_size \
			and s.has_reserve(w):
		_press(Action.RELOAD)


# --- Helpers ---

func _press(action: int) -> void:
	_presses[action] = (_presses[action] + 1) & 0xFF


## World direction → move vector relative to the view (x right, y forward).
func _local(dir: Vector3) -> Vector2:
	var forward := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	return Vector2(dir.dot(right), dir.dot(forward)).limit_length(1.0)
