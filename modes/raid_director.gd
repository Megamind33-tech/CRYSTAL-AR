class_name RaidDirector
extends RefCounted
## A Concern raid on Dust Hollow (server only): raiders (team 1, hunting
## the defenders, they don't respawn) come in along the east road; the
## Hollow's militia (team 0, the local player's side) holds the settlement.
## Damage is on for the fight only. step(): 0 while it goes on, 1 when the
## raiders are all down, 2 when the defending player falls.

const NEVER := 0x7FFFFFFF
const RAIDER_NAMES := ["Concern·Halden", "Concern·Mirek", "Concern·Sauer", "Concern·Petrova", "Concern·Okafor", "Concern·Lind"]
const MILITIA_NAMES := ["Hollow·Ike", "Hollow·Rama", "Hollow·Bisi", "Varga's gunner"]

var raiders: Array[int] = []
var militia: Array[int] = []
var _session: ServerSession
var _defender: int = 0


func _init(session: ServerSession) -> void:
	_session = session


func start(defender: int, hollow: Vector3, raider_count: int, militia_count: int) -> void:
	_defender = defender
	var world := _session.world
	world.teams_enabled = true
	world.damage_enabled = true
	var me: SimPlayer = world.players.get(defender)
	if me != null:
		me.team = 0
	for i in raider_count:
		var at := WorldTerrain.at(hollow.x + 62.0 + (i % 3) * 4.0, hollow.z + 18.0 - (i / 3) * 6.0 + i * 1.5)
		raiders.append(_bot(RAIDER_NAMES[i % RAIDER_NAMES.size()], 1, true, at, "concern"))
	for i in militia_count:
		var at := WorldTerrain.at(hollow.x - 4.0 + i * 2.5, hollow.z - 14.0)
		militia.append(_bot(MILITIA_NAMES[i % MILITIA_NAMES.size()], 0, false, at))
	world._emit("raid:start:%d" % world.tick, "raid", {"action": "start", "raiders": raider_count,
			"militia": militia_count})


## Deep Furrow's guards answering a theft: they come down at `posts` and
## hunt the thief (step() 1 when they're down, 2 when the thief is).
func start_guards(thief: int, posts: Array, role: String = "guard", names: String = "Xanadu·Guard %d", first: int = 1) -> void:
	_defender = thief
	var world := _session.world
	world.teams_enabled = true
	world.damage_enabled = true
	var me: SimPlayer = world.players.get(thief)
	if me != null:
		me.team = 0
	for i in posts.size():
		raiders.append(_bot(names % (i + first), 1, true, posts[i], role))


func _bot(bot_name: String, team: int, hunting: bool, at: Vector3, role: String = "") -> int:
	var id := 1000 + _session._bot_seq
	var brain := BotBrain.new(_session.world, _session.bot_nav, id, _session._rng.randi(), _session.bot_difficulty)
	brain.hunt = hunting
	var p := _session.add_bot(bot_name, brain)
	p.team = team
	_session.world.teleport(p, at + Vector3(0, 0.3, 0))
	if not role.is_empty():  # what they carry: dropped where they fall
		_session.world.packs[p.net_id] = Robbery.pack_for(role, _session._rng.randi())
	return p.net_id


## The hostile fighter `id` gives up in a hold-up: their pack drops at their
## feet and they're out of the fight. False if they're not ours to take.
func surrender(id: int) -> bool:
	var p: SimPlayer = _session.world.players.get(id)
	if p == null or not p.state.alive or not (id in raiders):
		return false
	_session.world.drop_pack(p, "surrender")
	raiders.erase(id)
	_session.remove_bot(id)
	return true


func raiders_left() -> int:
	var n := 0
	for id in raiders:
		var p: SimPlayer = _session.world.players.get(id)
		if p != null and p.state.alive:
			n += 1
	return n


func militia_left() -> int:
	var n := 0
	for id in militia:
		var p: SimPlayer = _session.world.players.get(id)
		if p != null and p.state.alive:
			n += 1
	return n


func step() -> int:
	var world := _session.world
	for id in raiders + militia:
		var p: SimPlayer = world.players.get(id)
		if p != null and not p.state.alive:
			p.state.respawn_tick = NEVER  # a raid's fighters don't come back
	var me: SimPlayer = world.players.get(_defender)
	if me != null and not me.state.alive:
		return 2
	return 1 if raiders_left() == 0 else 0


## The raid is over: its fighters leave, the Hollow is quiet again.
func finish() -> void:
	for id in raiders + militia:
		if _session.bots.has(id):
			_session.remove_bot(id)
	raiders.clear()
	militia.clear()
	_session.world.teams_enabled = false
	_session.world.damage_enabled = false
