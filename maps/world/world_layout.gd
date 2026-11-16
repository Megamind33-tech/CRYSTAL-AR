class_name WorldLayout
extends RefCounted
## Kasei Valley, THE HUNT's open world (800 x 800 m, WorldTerrain): the
## protected city of Tharsis Gate on its plateau (CityLayout), the frontier
## mining settlement of Dust Hollow in the valley, the Rustwood Dig down in
## the eastern canyon (the lawless extraction site: deploy there), and
## landmarks to discover. Gameplay (collision) and presentation read this.

const HOLLOW := Vector3(60.0, 2.0, -60.0)
## The lift house at the Anvil's foot, and Deep Furrow, the underground farm
## hall below it (the hall's lift end is straight under the lift house).
const LIFT := Vector3(-245.0, 0.0, -158.0)
const FARM_FLOOR := -200.0
## Drill rigs: [site, rig position (x, z), what it yields per shift].
const RIGS := [
	["hollow_rig", Vector2(96, -94), {"rare_ore": 1, "helium3": 1}],
	["crater_cutter", Vector2(168, -228), {"water_ice": 2}],
]
const RIG_SECONDS := 8.0       ## a shift at the controls
const RIG_COOLDOWN := 120      ## seconds before a rig can run again
## The dig's deploy pad on the canyon floor.
const DIG_X := 238.0
const DEPLOY_RADIUS := 4.5

## Regions (for the HUD's location line): [id, centre (x, z), radius].
const REGIONS := [
	["city", Vector2(-220, 20), 78.0],
	["hollow", Vector2(60, -60), 72.0],
	["dig", Vector2(238, 165), 60.0],
]
## Landmarks you can discover: [id, centre (x, z), radius, survey fee].
const LANDMARKS := [
	["wreck", Vector2(-130, -110), 30.0, 60],
	["crater", Vector2(150, -240), 45.0, 80],
	["relay", Vector2(255, -60), 36.0, 50],
	["mesa", Vector2(-310, -210), 48.0, 70],
	["dig_rim", Vector2(200, 110), 26.0, 40],
]


## Where rovers stand at the start: [position, yaw] (yaw PI faces south).
## A Concern supply rover parked on the valley road, its hold loaded (it
## restocks CONVOY_RESTOCK s after a robbery), and where its guards come
## from when someone opens the hold: [position, yaw].
const CONVOY_RESTOCK := 1200
const CONVOY_CARGO := {"supply_crate": 3, "refined_ingot": 2, "helium3": 1, "water_ration": 2, "oxygen_canister": 2,
		"cred_chip": 4}


static func convoy_spot() -> Array:
	return [WorldTerrain.at(-70.0, -30.0) + Vector3(0, 0.3, 0), 1.9]


static func convoy_guard_posts() -> Array:
	var c: Vector3 = convoy_spot()[0]
	return [WorldTerrain.at(c.x + 22, c.z - 14), WorldTerrain.at(c.x - 20, c.z + 18), WorldTerrain.at(c.x + 6, c.z + 26)]


## Joe's Respray & Chop: a hangar off the road outside the city gate; drive
## a rover into its bay (BAY_RADIUS of the spot) and stop.
const GARAGE := Vector2(-176.0, 108.0)  # just off the road out of the gate
## Kasei Motors, the rover factory on the road between the city and the
## Hollow: its bay door faces the road (+Z). Local spots on its floor:
## the showroom, the line, the arms (x, z).
const FACTORY := Vector2(-95.0, 28.0)
const FACTORY_ARMS := [Vector2(-3.2, -14), Vector2(3.2, -8), Vector2(-3.2, 0), Vector2(3.2, 6), Vector2(-3.2, 12)]


static func factory_at(local: Vector3) -> Vector3:
	return WorldTerrain.at(FACTORY.x, FACTORY.y) + Vector3(0, 0.05, 0) + local


static func showroom_spot() -> Vector3:
	return factory_at(Vector3(8.0, 0.0, 14.5))
const BAY_RADIUS := 6.5


## The valley's roads: polylines (x, z) between the places (the terrain's
## colour already follows them: tools/blender/build_world.py ROADS), paved
## by the presentation, driven by traffic, drawn on the minimap.
static func roads() -> Array:
	return [
		[Vector2(-220, 62), Vector2(-220, 84), Vector2(-170, 92), Vector2(-110, 70), Vector2(-40, 20), Vector2(20, -30),
				Vector2(60, -60)],
		[Vector2(60, -60), Vector2(110, -10), Vector2(160, 60), Vector2(205, WorldTerrain.canyon_center(205)),
				Vector2(240, WorldTerrain.canyon_center(240))],
		[Vector2(60, -60), Vector2(110, -150), Vector2(140, -190)],
		[Vector2(-110, 70), Vector2(-160, -60), Vector2(-240, -146)],  # to the lift down to Deep Furrow
	]


## A road sampled every `step` metres: [position, direction] pairs.
static func road_samples(road: Array, step: float) -> Array:
	var out := []
	for i in road.size() - 1:
		var a: Vector2 = road[i]
		var b: Vector2 = road[i + 1]
		var n := maxi(int(a.distance_to(b) / step), 1)
		for k in n:
			var p := a.lerp(b, float(k) / n)
			out.append([p, (b - a).normalized()])
	var last: Vector2 = road[road.size() - 1]
	out.append([last, (last - (road[road.size() - 2] as Vector2)).normalized()])
	return out


static func garage_spot() -> Vector3:
	return WorldTerrain.at(GARAGE.x, GARAGE.y)


static func rover_spots() -> Array:
	var gate := CityLayout.ORIGIN + Vector3(7, 0, 52)
	return [
		[WorldTerrain.at(gate.x, gate.z) + Vector3(0, 0.3, 0), PI],
		[WorldTerrain.at(gate.x - 8, gate.z) + Vector3(0, 0.3, 0), PI],
		[WorldTerrain.at(HOLLOW.x - 16, HOLLOW.z + 24) + Vector3(0, 0.3, 0), 0.6],
	]


# --- The Rustwood Dig: the extraction run, in the canyon itself ---

## A point on the canyon floor at x (`off`: metres across the channel).
static func canyon(x: float, off: float = 0.0) -> Vector3:
	return WorldTerrain.at(x, WorldTerrain.canyon_center(x) + off)


## HuntRules map data for a run at the dig: cargo spots on the canyon floor
## and around its rim, the relic vault at the canyon's deep east end,
## extraction pads at the west exit, the east ramp and on the north rim.
static func dig_hunt_data() -> Dictionary:
	var spots: Array[Vector3] = []
	for x in [130.0, 155.0, 180.0, 205.0, 260.0, 280.0, 320.0]:
		spots.append(canyon(x, -6.0 if int(x) % 2 == 0 else 6.0))
	for p: Vector2 in [Vector2(170, 112), Vector2(250, 98), Vector2(300, 82), Vector2(150, 238),
			Vector2(215, 232), Vector2(280, 200), Vector2(110, 150), Vector2(330, 165), Vector2(235, 120)]:
		spots.append(WorldTerrain.at(p.x, p.y))
	return {
		"treasure_spots": spots,
		"extraction_zones": [canyon(68.0), canyon(350.0), WorldTerrain.at(200.0, 118.0)],
		"vault": canyon(300.0),
	}


## Where hunters (re)spawn during a run: along the canyon and its rim.
static func dig_spawns() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for x in [120.0, 170.0, 220.0, 260.0, 310.0, 340.0]:
		out.append(Transform3D(Basis.IDENTITY, canyon(x) + Vector3(0, 0.2, 0)))
	for p: Vector2 in [Vector2(140, 120), Vector2(190, 225), Vector2(260, 105), Vector2(300, 195),
			Vector2(100, 200), Vector2(330, 90)]:
		out.append(Transform3D(Basis.IDENTITY, WorldTerrain.at(p.x, p.y) + Vector3(0, 0.2, 0)))
	return out


## Weapons and ammunition lying around the dig during a run.
static func dig_pickups() -> Array:
	return [
		{"weapon": &"pulse_rifle", "position": canyon(190.0, 4.0), "respawn_ticks": 2400},
		{"weapon": &"mag_pistol", "position": canyon(270.0, -4.0), "respawn_ticks": 2400},
		{"weapon": &"grenade", "position": canyon(230.0, 8.0), "respawn_ticks": 1800},
		{"weapon": &"rail_sniper", "position": WorldTerrain.at(215.0, 120.0), "respawn_ticks": 7200},
	]


## The bots' navigation covers the dig and its approaches only.
static func dig_nav_area() -> AABB:
	return AABB(Vector3(40, -60, 40), Vector3(340, 140, 230))


## People who aren't at a city terminal: [who (Career.PEOPLE), position,
## facing yaw]. Dr. Okafor at her lab off the market row, Tunde's job
## centre by the plaza, and Sable, the Ledger's dealer, behind Dust
## Hollow's bunkhouses.
static func people_spots() -> Array:
	var o := CityLayout.ORIGIN
	return [
		["chemist", o + Vector3(-29.5, 0, 17.5), -PI * 0.5],
		["jobs", o + Vector3(12, 0, 22), PI],
		["dealer", WorldTerrain.at(HOLLOW.x - 40, HOLLOW.z - 30), PI * 0.25],
		["farmer", farm_origin() + Vector3(-3, 0, 18), 0.0],
	]


## Bunks where you can sleep: inside the walk-in habitats.
static func bunks() -> Array:
	return [
		[CityLayout.ORIGIN + Vector3(-36, 0, -36), "CITY_NAME"],
		[WorldTerrain.at(HOLLOW.x - 26, HOLLOW.z - 16), "WORLD_HOLLOW"],
		[farm_origin() + Vector3(8, 0, 22), "WORLD_FARM"],
	]


static func lift_top() -> Vector3:
	return WorldTerrain.at(LIFT.x, LIFT.z)


## Deep Furrow's hall origin (its floor centre); the lift end is +Z.
static func farm_origin() -> Vector3:
	return Vector3(LIFT.x, FARM_FLOOR, LIFT.z - 32.0)


## Where the lift lets you out at the bottom (inside the hall's door).
static func lift_bottom() -> Vector3:
	return farm_origin() + Vector3(0, 0.3, 26.0)


## Deep Furrow is pressurised: its whole hall.
## Where Deep Furrow's guards walk (baked when you take the lift down).
static func farm_nav_area() -> AABB:
	return AABB(farm_origin() + Vector3(-16, -4, -36), Vector3(32, 18, 78))


static func farm_air() -> AABB:
	return AABB(farm_origin() + Vector3(-12, -2, -32), Vector3(24, 14, 70))


## Things to scavenge (water is scarce): [id, position, loot table
## [[item, count, weight]], prompt key]. Each refills after LOOT_COOLDOWN.
const LOOT_COOLDOWN := 300
const WATERY := [["water_ration", 2, 4.0], ["oxygen_canister", 1, 2.0], ["water_ice", 1, 1.0], ["scrap", 2, 2.0]]


static func loot_spots() -> Array:
	var h := HOLLOW
	return [
		["hollow_crates_a", WorldTerrain.at(h.x + 8, h.z - 4), WATERY, "LOOT_CRATES"],
		["hollow_crates_b", WorldTerrain.at(h.x + 12, h.z + 14), WATERY, "LOOT_CRATES"],
		["hollow_lockers", WorldTerrain.at(h.x - 30, h.z + 10), [["water_ration", 1, 3.0], ["oxygen_canister", 1, 2.0]], "LOOT_LOCKERS"],
		["kestrel_hold", WorldTerrain.at(-136, -118), [["water_ration", 3, 3.0], ["oxygen_canister", 2, 2.0], ["scrap", 3, 2.0]],
				"LOOT_WRECK"],
		["dig_camp", canyon(DIG_X - 6, 9.0), WATERY, "LOOT_CRATES"],
		["anvil_hut", WorldTerrain.at(-296, -200), [["water_ration", 2, 3.0], ["water_ice", 2, 2.0]], "LOOT_LOCKERS"],
	]


## Deep Furrow's oxygen-algae beds you can lift cultures from (guarded).
static func algae_spots() -> Array:
	var o := farm_origin()
	return [o + Vector3(-7.5, 0, -12), o + Vector3(7.5, 0, -12)]


## Where the farm's guards come down: between you and the lift.
static func guard_posts() -> Array:
	var o := farm_origin()
	return [o + Vector3(-4, 0.3, 20), o + Vector3(4, 0.3, 20), o + Vector3(0, 0.3, 14)]


static func rig_spot(i: int) -> Vector3:
	var p: Vector2 = RIGS[i][1]
	return WorldTerrain.at(p.x, p.y)


## Where a job's work is done: job -> [position, radius].
static func job_sites() -> Dictionary:
	return {
		"salvage": [WorldTerrain.at(-130, -110), 16.0],
		"ice": [WorldTerrain.at(150, -240), 22.0],
		"taxi": [WorldTerrain.at(HOLLOW.x, HOLLOW.z), 28.0],
		"haul": [factory_at(Vector3(0, 0, 30)), 16.0],
		"line": [factory_at(Vector3(0, 0, 2)), 5.0],
		"patrol": [WorldTerrain.at(-20.0, 0.0), 14.0],
	}


## The foreman's spot by the Hollow's work-board kiosk.
static func foreman_spot() -> Vector3:
	return WorldTerrain.at(HOLLOW.x - 4, HOLLOW.z - 21.6)


static func dig_pad() -> Vector3:
	return WorldTerrain.at(DIG_X, WorldTerrain.canyon_center(DIG_X))


static func region_at(x: float, z: float) -> String:
	for r: Array in REGIONS:
		if Vector2(x, z).distance_to(r[1]) < float(r[2]):
			return r[0]
	return "open"


static func landmark_at(x: float, z: float) -> Array:
	for l: Array in LANDMARKS:
		if Vector2(x, z).distance_to(l[1]) < float(l[2]):
			return l
	return []


## Dust Hollow and the dig, as kit pieces on the ground: [piece, x, z,
## yaw, scale, collision box size (ZERO: none)].
## Shops with a walk-in counter: [Career.SHOPS id, where you stand at the
## counter, where the keeper stands, the keeper's yaw]. The city's five
## shopfronts in CityLayout order, then the Hollow's trading post.
const SHOP_KINDS := ["exchange", "arms", "store", "salvage", "guns", "bar", "post", "saloon"]


## Buildings you can walk into, and whether there's air inside: a roof
## isn't air. Only rooms under the city's dome (its air) and Deep Furrow
## (sealed) are pressurised; Dust Hollow's habitats (their airlocks stand
## open), its trading post, the hangars and the lift house are not.
## Footprints are squared off around each piece (rotation-proof).
const ROOM_SIZE := {"shopfront": Vector3(12, 3.6, 12), "life/hab_open": Vector3(12, 3.2, 12), "hangar": Vector3(14, 5.5, 14),
		"life/factory": Vector3(26, 11, 44),
		"life/lift_head": Vector3(5, 4.6, 5)}
const DOME_RADIUS := 72.0
static var _rooms: Array = []

const NO_ROOM := 0
const ROOM_AIR := 1      ## inside, and pressurised
const ROOM_NO_AIR := 2   ## inside, but breathe from your suit


static func rooms() -> Array:
	if not _rooms.is_empty():
		return _rooms
	var placed := []
	for p: Array in CityLayout.pieces():
		placed.append([p[0], p[1], float(p[3])])
	for p: Array in pieces():
		placed.append([p[0], WorldTerrain.at(p[1], p[2]), float(p[4])])
	for p: Array in placed:
		if not ROOM_SIZE.has(p[0]):
			continue
		var size: Vector3 = ROOM_SIZE[p[0]] * p[2]
		var at: Vector3 = p[1]
		var box := AABB(at - Vector3(size.x * 0.5, 0.2, size.z * 0.5), Vector3(size.x, size.y, size.z))
		var dome := Vector2(at.x - CityLayout.ORIGIN.x, at.z - CityLayout.ORIGIN.z).length() < DOME_RADIUS
		_rooms.append([box, dome])
	_rooms.append([farm_air(), true])
	return _rooms


## NO_ROOM, ROOM_AIR or ROOM_NO_AIR at `pos`.
static func room_at(pos: Vector3) -> int:
	for r: Array in rooms():
		if (r[0] as AABB).has_point(pos):
			return ROOM_AIR if r[1] else ROOM_NO_AIR
	return NO_ROOM


## Residences: [id, the locker inside (where you open or break it), whose
## it is ("" = yours)]. Yours is the gate-side hab in Tharsis Gate.
static func residences() -> Array:
	var out := []
	var habs := []
	for p: Array in CityLayout.pieces():
		if p[0] == "life/hab_open":
			habs.append([p[1], float(p[2])])
	var h := HOLLOW
	habs.append([WorldTerrain.at(h.x - 8, h.z + 28), 170.0])
	var owners := ["", "Okonkwo", "Varela", "Hollow·Bisi"]
	for i in habs.size():
		var b := Basis(Vector3.UP, deg_to_rad(habs[i][1]))
		out.append(["home_%d" % i, (habs[i][0] as Vector3) + b * Vector3(0, 0, -3.4), owners[i] if i < owners.size() else "Resident"])
	return out


## Whether a shop of `kind` is open at hour `h` (bars keep late hours).
static func shop_open(kind: String, h: float) -> bool:
	var hours := GameClock.BAR_HOURS if Career.SHOPS[kind].get("hours", "") == "bar" else GameClock.OPEN_HOURS
	return GameClock.within(hours, h)


## Where person `who` is at hour `h` (Vector3.INF: away, asleep): at work by
## day, in the bar of an evening (the Hollow's at the saloon), home at night.
## Sable deals at night. Ngozi lives on her farm.
static func person_at(who: String, work: Vector3, h: float) -> Vector3:
	if who == "farmer":
		return work
	if who == "dealer":
		return work if GameClock.within(Vector2(18, 6), h) else Vector3.INF
	if GameClock.within(Vector2(7, 18), h):
		return work
	if GameClock.within(Vector2(18, 23.5), h):
		var bar: Array = shops()[7 if who == "foreman" else 5]  # the saloon / the Red Lantern
		var slot := Vector3(float(who.hash() % 5) - 2.0, 0.0, 0.4)  # along the bar, not on one spot
		return (bar[1] as Vector3) + Basis(Vector3.UP, float(bar[3]) - PI) * slot
	return Vector3.INF


static func shops() -> Array:
	var fronts := []
	for p: Array in CityLayout.pieces():
		if p[0] == "shopfront":
			fronts.append([p[1], p[2], p[3]])
	for p: Array in pieces():
		if p[0] == "shopfront":
			fronts.append([WorldTerrain.at(p[1], p[2]), p[3], p[4]])
	var out := []
	for i in fronts.size():
		var f: Array = fronts[i]
		var b := Basis(Vector3.UP, deg_to_rad(f[1]))
		var sc: float = f[2]
		var kind: String = SHOP_KINDS[i] if i < SHOP_KINDS.size() else "store"
		out.append([kind, (f[0] as Vector3) + b * Vector3(0, 0, 0.5 * sc), (f[0] as Vector3) + b * Vector3(0, 0, -2.4 * sc),
				deg_to_rad(f[1]) + PI])
	return out


static func pieces() -> Array:
	var h := HOLLOW
	var out := [
		# Dust Hollow: the refinery (hangar), tanks, pipes, bunkhouses, the canteen.
		["hangar", h.x + 18, h.z - 14, 0.0, 1.5, Vector3.ZERO],
		["tank_cluster", h.x + 30, h.z + 12, 90.0, 1.3, Vector3(6, 9, 11)],
		["tank_cluster", h.x + 38, h.z + 12, 90.0, 1.3, Vector3(6, 9, 11)],
		["pipe_run", h.x + 26, h.z + 2, 0.0, 1.2, Vector3.ZERO],
		["pipe_run", h.x + 16, h.z + 2, 0.0, 1.2, Vector3.ZERO],
		["life/hab_open", h.x - 26, h.z - 16, 60.0, 1.0, Vector3.ZERO],
		["life/hab_open", h.x - 30, h.z + 10, 100.0, 1.0, Vector3.ZERO],
		["life/hab_open", h.x - 8, h.z + 28, 170.0, 1.0, Vector3.ZERO],
		["life/greenhouse", h.x - 14, h.z + 2, 20.0, 1.0, Vector3.ZERO],
		["shopfront", h.x - 4, h.z - 30, 0.0, 1.0, Vector3.ZERO],
		["shopfront", h.x + 12, h.z + 32, 180.0, 1.0, Vector3.ZERO],  # the Dust Devil Saloon
		["comms_tower", h.x + 4, h.z + 4, 0.0, 1.2, Vector3(2.4, 20, 2.4)],
		["crate_stack", h.x + 8, h.z - 4, 20.0, 1.0, Vector3(3.6, 3, 2)],
		["crate_stack", h.x + 12, h.z + 14, -35.0, 1.0, Vector3(3.6, 3, 2)],
		["street_lamp", h.x - 12, h.z - 8, 0.0, 1.0, Vector3(0.3, 5, 0.3)],
		["street_lamp", h.x + 2, h.z - 18, 180.0, 1.0, Vector3(0.3, 5, 0.3)],
		["kiosk", h.x - 4, h.z - 20, 0.0, 1.0, Vector3(1.2, 2.4, 1.2)],
		# Drill rigs (mining): the Hollow's ore seam, the crater's ice cutter.
		["life/mining_rig", h.x + 36, h.z - 34, -30.0, 1.0, Vector3.ZERO],
		["life/mining_rig", 168.0, -228.0, 15.0, 1.0, Vector3.ZERO],
		# The lift down to Deep Furrow, the farm under the Anvil.
		["life/lift_head", LIFT.x, LIFT.z, 180.0, 1.0, Vector3.ZERO],
		["hangar", GARAGE.x, GARAGE.y, 0.0, 1.3, Vector3.ZERO],  # Joe's Respray & Chop
		["life/factory", FACTORY.x, FACTORY.y, 0.0, 1.0, Vector3.ZERO],  # Kasei Motors
		# The Rustwood Dig: a field camp on the canyon floor.
		["hangar", DIG_X + 14, WorldTerrain.canyon_center(DIG_X + 14) - 10, 90.0, 1.1, Vector3(12, 7, 16)],
		["tank_cluster", DIG_X - 16, WorldTerrain.canyon_center(DIG_X - 16) - 9, 0.0, 1.0, Vector3(8.5, 7, 5)],
		["crate_stack", DIG_X - 6, WorldTerrain.canyon_center(DIG_X) + 9, 10.0, 1.0, Vector3(3.6, 3, 2)],
		["comms_tower", 205.0, 112.0, 0.0, 1.2, Vector3(2.4, 20, 2.4)],
		# Landmarks.
		["world/freighter_wreck", -130.0, -110.0, 35.0, 1.4, Vector3(10, 7, 46)],
		["comms_tower", 255.0, -60.0, 0.0, 1.6, Vector3.ZERO],
		["hab_dome", -300.0, -205.0, 0.0, 0.8, Vector3.ZERO],
	]
	return out


## Dust Hollow's people: the foreman at the kiosk and the workers' loops.
static func hollow_walks() -> Array:
	var h := HOLLOW
	return [
		[Vector3(h.x - 20, 0, h.z - 6), Vector3(h.x + 10, 0, h.z - 6), Vector3(h.x + 10, 0, h.z + 18)],
		[Vector3(h.x + 6, 0, h.z - 24), Vector3(h.x + 6, 0, h.z + 22)],
		[Vector3(h.x - 14, 0, h.z + 16), Vector3(h.x - 14, 0, h.z - 24), Vector3(h.x - 2, 0, h.z - 24)],
		[Vector3(h.x + 20, 0, h.z + 24), Vector3(h.x - 4, 0, h.z + 24), Vector3(h.x - 4, 0, h.z + 8)],
		[Vector3(h.x + 26, 0, h.z - 2), Vector3(h.x + 26, 0, h.z - 28), Vector3(h.x + 10, 0, h.z - 28)],
	]
