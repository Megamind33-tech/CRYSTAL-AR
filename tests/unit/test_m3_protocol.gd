extends GutTest
## M3 wire additions: snapshot items and spot timers, owner weapon slots and
## grenades, pickup events, the loadout message and the primary in HELLO.


func test_snapshot_items_and_owner_slots_round_trip() -> void:
	var snap := Snapshot.new()
	snap.id = 77
	snap.items = [{"id": 5, "weapon": Weapons.RAIL, "position": Vector3(1, 2, 3)}, {"id": 6, "weapon": -1, "position": Vector3(-4, 0, 2)}]
	snap.spot_ticks = PackedInt32Array([0, 1234])
	var s := PlayerSimState.new()
	s.init_weapons(Loadouts.make(2))
	s.set_slot(0, Weapons.ARC, 1, 3)
	s.grenades = 1
	s.melee_cooldown = 12
	snap.owner_state = s
	snap.owner_gen = 3
	snap.projectiles = [{"owner": 2, "gen": 1, "action": 9, "weapon": Weapons.FRAG, "position": Vector3.ONE, "velocity": Vector3.UP}]
	var back := Snapshot.decode(snap.encode({}, []), {})
	assert_not_null(back)
	assert_eq(back.items.size(), 2)
	assert_eq(back.items[0].weapon, Weapons.RAIL)
	assert_eq(back.items[1].weapon, -1, "grenade")
	assert_almost_eq((back.items[0].position as Vector3).distance_to(Vector3(1, 2, 3)), 0.0, 0.02)
	assert_eq(back.spot_ticks, PackedInt32Array([0, 1234]))
	assert_eq(back.owner_state.weapons, PackedInt32Array([Weapons.ARC, Weapons.PISTOL]))
	assert_eq(back.owner_state.grenades, 1)
	assert_eq(back.owner_state.melee_cooldown, 12)
	assert_eq(back.projectiles[0].weapon, &"frag_grenade")


func test_pickup_event_round_trip() -> void:
	var e := {"type": "pickup", "id": "p:12:3456", "player": 4, "weapon": &"rail_sniper", "position": Vector3(1, 0, 2)}
	var w := Wire.Writer.new()
	assert_true(Protocol.write_event(w, e))
	var back := Protocol.read_event(Wire.Reader.new(w.data()))
	assert_eq(back.id, e.id, "same id, so presentation de-duplicates")
	assert_eq(back.weapon, &"rail_sniper")
	assert_eq(back.player, 4)


func test_loadout_message_and_hello_primary() -> void:
	assert_eq(Protocol.decode_loadout(Protocol.encode_loadout(2)), 2)
	assert_eq(Protocol.decode_loadout(Protocol.encode_loadout(9)), -1, "out of range")
	assert_true(Protocol.Msg.LOADOUT in Protocol.CLIENT_MESSAGES)
	var hello := Protocol.decode_hello(Protocol.encode_hello("c", "b", "u", "Name", 0, 1, 2, 2))
	assert_eq(hello.primary, 2)
func test_hunt_events_cross_the_wire() -> void:
	var e := {"type": "hunt", "id": "hw:12", "tick": 12, "action": "unit_called", "player": 3, "unit": "tank",
			"position": Vector3(1.5, 2.0, -3.25), "treasure": 0, "kind": -1, "mods": ["low_gravity"]}
	var back := Protocol.decode_event_message(Protocol.encode_event_message(7, e))
	assert_eq(back.get("action"), "unit_called")
	assert_eq(back.get("unit"), "tank")
	assert_eq(back.get("position"), Vector3(1.5, 2.0, -3.25))
	assert_eq(back.get("mods"), ["low_gravity"])


func test_hunt_event_garbage_is_refused() -> void:
	var w := Wire.Writer.new().u8(Protocol.Msg.EVENT).u32(7).u8(Protocol.Event.HUNT).u16(3)
	w.bytes(PackedByteArray([1, 2, 3]))
	var back := Protocol.decode_event_message(w.data())
	assert_true(back.is_empty() or back.get("type") != "hunt", "junk never becomes an event")


func test_war_state_round_trips_to_a_client_mirror() -> void:
	var host := HuntWar.new()
	host.enabled = true
	host.objective = HuntWar.Objective.HOLD
	host.hold = {101: 600, 102: 120}
	host.holder = 101
	var c := HuntWar.Camp.new()
	c.side = 101
	c.at = Vector3(10, 0, 5)
	host.camps.append(c)
	var b := HuntCamps.Built.new()
	b.modules = {0: "turret", 2: "air_defense"}
	b.walls = true
	host.builds.built.append(b)
	var state := {"enabled": true, "objective": host.objective, "hold": host.hold, "holder": 101, "sides": {3: 101, 4: 102},
			"camps": [{"side": 101, "at": c.at, "charges": 3, "modules": b.modules, "walls": true, "gate": 0.5}]}
	var e := {"type": "hunt", "id": "hws:60", "tick": 60, "action": "war_state", "player": 0, "treasure": 0, "kind": -1,
			"state": state}
	var back := Protocol.decode_event_message(Protocol.encode_event_message(1, e))
	var mirror := HuntRules.new()
	mirror.war.apply_state(back.state)
	assert_eq(mirror.war.objective, HuntWar.Objective.HOLD)
	assert_eq(mirror.war.side_of(mirror, 3), 101, "sides come from the host")
	assert_eq(mirror.war.leader_side(), 101)
	assert_eq(mirror.war.camps.size(), 1)
	assert_eq(mirror.war.builds.built[0].modules, {0: "turret", 2: "air_defense"})
	assert_true(mirror.war.builds.built[0].walls)


func test_site_tagged_maps() -> void:
	assert_true(Maps.has("city@crater"))
	assert_false(Maps.has("city@nowhere"), "unknown sites refused")
	assert_eq(Maps.base("city@crater"), "city")
	assert_eq(Maps.site_of("city@crater"), "crater")
	assert_eq(Maps.site_of("station"), "")


func test_hunt_requests_are_checked() -> void:
	var ok := Protocol.decode_hunt_request(Protocol.encode_hunt_request("call_unit", {"unit": "tank", "target": Vector3(1, 2, 3)}))
	assert_eq(ok.action, "call_unit")
	assert_eq(ok.args.unit, "tank")
	assert_eq(ok.args.target, Vector3(1, 2, 3))
	assert_true(Protocol.decode_hunt_request(Protocol.encode_hunt_request("quit_game", {})).is_empty(), "unknown actions refused")
	var junk := Protocol.decode_hunt_request(Protocol.encode_hunt_request("build", {"module": "walls", "x": [1, 2], 5: "y"}))
	assert_eq(junk.args, {"module": "walls"}, "only plain values under string keys")


func test_private_state_mirrors_a_players_phone() -> void:
	var host := HuntRules.new()
	host.economy.credits[3] = 450
	host.army.rosters[3] = {"tank": [2, 1]}
	host.social.allies[3] = 4
	var data := var_to_bytes({"credits": 450, "merc_cost": 200, "army": {"tank": [2, 1]}, "ally": 4, "dissolving": false,
			"merc_order": 1, "squad": {"rule": 2, "spread": 1, "strategy": "raid", "roles": ["gunner", "medic"], "ready": ["scan"]}})
	var mirror := HuntRules.new()
	mirror.apply_private(3, bytes_to_var(data))
	assert_eq(mirror.economy.credits[3], 450)
	assert_eq(mirror.army.left(3, "tank"), 2)
	assert_eq(mirror.social.allies[3], 4)
	assert_true(mirror.economy.contracts.has(3))
	var sq := mirror.squad.squad_of(3)
	assert_eq(sq.members.size(), 2)
	assert_eq(sq.strategy, "raid")
	assert_eq(mirror.remote_ready, ["scan"])


func test_field_state_mirrors_cargo_and_aircraft() -> void:
	var data := {"end": 9000, "final": -1, "trap": 0,
			"t": [[7, HuntRules.Kind.PERSONAL, 3, Vector3(4, 0, 2), 0, false, -1, 0, false]],
			"calls": [["gunship", 3, "aurora", Vector3(10, 0, 10), Vector3(0, 0, 0), 100, 2000, 0.0, 1]]}
	var mirror := HuntRules.new()
	mirror.apply_field(bytes_to_var(var_to_bytes(data)))
	assert_eq(mirror.treasures.size(), 1)
	assert_eq(mirror.treasures[0].position, Vector3(4, 0, 2))
	assert_eq(mirror.army.calls.size(), 1)
	var first := mirror.army.calls[0]
	mirror.apply_field(data)
	assert_same(mirror.army.calls[0], first, "the same aircraft stays the same object (no flicker)")
	data.calls = [["not_a_unit", 3, "", Vector3.ZERO, Vector3.ZERO, 0, 0, 0.0, 0]]
	mirror.apply_field(data)
	assert_eq(mirror.army.calls.size(), 0, "unknown units refused")


func test_a_clients_kit_is_checked() -> void:
	var world := SimHarness.make_world()
	add_child_autofree(world)
	await wait_physics_frames(1)
	var h := HuntRules.new()
	world.hunt = h
	world.add_player(3, SimHarness.loadout(), "p3", false)
	assert_true(h.request(world, 3, "bring_kit", {"army": "tank:9:1,scout_drone:2:0,nuke:5:0,raptor:1:0", "roles": "medic,wizard"}))
	assert_eq(h.army.left(3, "tank"), HuntRules.KIT_MAX_EACH, "a few of each at most")
	assert_eq(h.army.left(3, "scout_drone"), 0, "over the command points: left behind")
	assert_eq(h.army.left(3, "raptor"), 0, "another nation's unique unit")
	assert_eq(h.squad.squad_of(3).members.size(), 1, "known roles only")
	assert_false(h.request(world, 3, "bring_kit", {"army": "tank:1:0", "roles": ""}), "once a run")
