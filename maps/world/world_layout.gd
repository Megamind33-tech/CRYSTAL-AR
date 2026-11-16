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
	["helios", Vector2(-520, -470), 150.0],
	["galleria", Vector2(-560, 200), 105.0],
	["terrace", Vector2(470, 430), 140.0],
	["skyport", Vector2(520, -440), 140.0],
]
## Where the Marshals' law runs (shots and break-ins are crimes there).
const LAWFUL := ["city", "hollow", "helios", "galleria", "terrace", "skyport"]

## The outlands' districts (WorldTerrain.SITES): centres on their flats.
const HELIOS := Vector2(-520, -470)
const GALLERIA := Vector2(-560, 200)
const TERRACE := Vector2(470, 430)
const SKYPORT := Vector2(520, -440)
## Landmarks you can discover: [id, centre (x, z), radius, survey fee].
const LANDMARKS := [
	["wreck", Vector2(-130, -110), 30.0, 60],
	["crater", Vector2(150, -240), 45.0, 80],
	["relay", Vector2(255, -60), 36.0, 50],
	["mesa", Vector2(-310, -210), 48.0, 70],
	["dig_rim", Vector2(200, 110), 26.0, 40],
	["lowell", Vector2(-330, 400), 60.0, 90],
	["helios_ring", Vector2(-520, -470), 40.0, 60],
	["skyport_pads", Vector2(500, -490), 30.0, 50],
	["far_mesa", Vector2(640, -60), 60.0, 80],
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
		# The outlands: west to the Galleria, on past the lift to Helios, south
		# to Nova Terrace, east from the Hollow to the Skyport, and the
		# canyon road out of the dig to the Terrace.
		[Vector2(-220, 84), Vector2(-300, 140), Vector2(-420, 190), Vector2(-482, 200)],
		[Vector2(-240, -146), Vector2(-330, -290), Vector2(-420, -390), Vector2(-455, -430)],
		[Vector2(-170, 92), Vector2(-160, 200), Vector2(-100, 300), Vector2(150, 385), Vector2(370, 425)],
		[Vector2(60, -60), Vector2(250, -150), Vector2(400, -300), Vector2(460, -385)],
		[Vector2(240, WorldTerrain.canyon_center(240)), Vector2(300, WorldTerrain.canyon_center(300)),
				Vector2(370, WorldTerrain.canyon_center(370)), Vector2(420, 300), Vector2(440, 345)],
		[Vector2(-560, 120), Vector2(-590, -60), Vector2(-570, -250), Vector2(-540, -350)],
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
		"life/lift_head": Vector3(5, 4.6, 5), "districts/galleria": Vector3(100, 12, 38),
		"districts/pod_a": Vector3(9, 3.4, 9), "districts/pod_b": Vector3(9, 3.4, 9), "districts/pod_c": Vector3(9, 3.4, 9)}
## Sealed buildings out in the open: the Galleria (air curtains at its
## doors) and Nova Terrace's homes (airlocked).
const PRESSURISED := ["districts/galleria", "districts/pod_a", "districts/pod_b", "districts/pod_c"]
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
		_rooms.append([box, dome or p[0] in PRESSURISED])
	_rooms.append([farm_air(), true])
	for air: AABB in interior_air():
		_rooms.append([air, true])
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
	# Nova Terrace's pod homes: the locker by the back wall.
	var names := ["Mensah", "Ito", "Ruiz", "Adeyemi", "Kowalski", "Nwosu", "Haddad", "Silva", "Obi", "Lindqvist", "Achebe", "Moreau"]
	var k := 0
	for p: Array in pieces():
		if str(p[0]).begins_with("districts/pod_"):
			var b := Basis(Vector3.UP, deg_to_rad(p[3]))
			out.append(["home_%d" % out.size(), WorldTerrain.at(p[1], p[2]) + b * Vector3(3.5, 0, -3.4),
					"Terrace·" + names[k % names.size()]])
			k += 1
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
	# The Prism Galleria's shops, at their counters along the concourse.
	var g := WorldTerrain.at(GALLERIA.x, GALLERIA.y)
	for u: Array in GALLERIA_SHOPS:
		var side: float = u[2]
		var x: float = u[1]
		# Blender's +Y side of the hall is Godot's -Z.
		out.append([u[0], g + Vector3(x, 0, -side * 8.9), g + Vector3(x, 0, -side * 11.6), PI if side > 0 else 0.0])
	return out


## The Galleria's shops: [Career.SHOPS id, x along the hall, side (+1 north, -1 south)].
const GALLERIA_SHOPS := [["tech", -35.0, 1.0], ["foodcourt", -15.0, 1.0], ["pharmacy", 15.0, 1.0], ["outfitter", 35.0, 1.0],
		["prism", -25.0, -1.0], ["noodle", 25.0, -1.0]]


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
	out.append_array(district_pieces())
	return out


static var _district_pieces: Array = []


## The outlands' districts as kit pieces (same format as pieces(); a piece
## named "" is collision only). Helios Arcology: the ring habitat over its
## plaza, the twisting spires, the arch towers, solar trees. The Prism
## Galleria (walk-in mall) and its forecourts. Nova Terrace: pod homes in two
## rings round a plaza. Kasei Skyport: pads, shuttles, the tower, hangars.
static func district_pieces() -> Array:
	if not _district_pieces.is_empty():
		return _district_pieces
	var out := []
	var at := func(c: Vector2, piece: String, dx: float, dz: float, yaw: float, sc: float, col: Vector3) -> void:
		out.append([piece, c.x + dx, c.y + dz, yaw, sc, col])
	var facing := func(dx: float, dz: float) -> float:  # yaw that turns a piece's front to the district's centre
		return rad_to_deg(atan2(-dx, -dz))
	# --- Helios Arcology
	var h := HELIOS
	at.call(h, "districts/ring_hab", 0, 0, 0.0, 1.0, Vector3(9.5, 30, 9.5))
	for sa: Array in [[-62.0, -58.0, 1.0], [-92.0, 30.0, 0.8]]:
		var sc: float = sa[2]
		at.call(h, "districts/spire_a", sa[0], sa[1], facing.call(sa[0], sa[1]), sc, Vector3(34, 8.5, 34) * sc)
		at.call(h, "", sa[0], sa[1], facing.call(sa[0], sa[1]), sc, Vector3(24, 100, 24) * sc)
	at.call(h, "districts/spire_b", 66.0, -54.0, facing.call(66.0, -54.0), 1.0, Vector3(30, 6, 20))
	at.call(h, "", 66.0, -54.0, facing.call(66.0, -54.0), 1.0, Vector3(26, 75, 15))
	at.call(h, "districts/arc_towers", 0.0, -92.0, 0.0, 1.0, Vector3.ZERO)
	for sx in [-1.0, 1.0]:
		at.call(h, "", sx * 17.0, -92.0, 0.0, 1.0, Vector3(20, 66, 16))
	at.call(h, "", 0.0, -92.0, 0.0, 1.0, Vector3(24, 8, 12) + Vector3(0, 0, 0))
	for i in 10:
		var a := i * TAU / 10.0 + 0.3
		at.call(h, "districts/solar_tree", cos(a) * 54.0, sin(a) * 54.0, 0.0, 1.0, Vector3(0.8, 7, 0.8))
	for q: Vector2 in [Vector2(40, 70), Vector2(-40, 70), Vector2(80, 20), Vector2(-80, -20)]:
		at.call(h, "districts/holo_sign", q.x, q.y, facing.call(q.x, q.y), 1.0, Vector3(0.7, 8, 0.7))
	for q: Vector2 in [Vector2(88, 52), Vector2(100, 18), Vector2(64, 92), Vector2(30, 104)]:
		at.call(h, "districts/pod_" + ["a", "b", "c"][int(q.x) % 3], q.x, q.y, facing.call(q.x, q.y), 1.0, Vector3.ZERO)
	for i in 6:
		at.call(h, "districts/planter", -30.0 + i * 12.0, 46.0, 0.0, 1.0, Vector3(4.4, 1, 2.4))
	# --- The Prism Galleria (long along x; doors at x = ±50)
	var g := GALLERIA
	at.call(g, "districts/galleria", 0, 0, 0.0, 1.0, Vector3.ZERO)
	for e in [-1.0, 1.0]:
		for k in 3:
			var z := -14.0 + k * 14.0
			at.call(g, "districts/lamp_neo", e * 64.0, z, 90.0 * e, 1.0, Vector3(0.3, 6, 0.3))
		at.call(g, "districts/holo_sign", e * 60.0, -22.0, -90.0 * e, 1.0, Vector3(0.7, 8, 0.7))
		at.call(g, "districts/planter", e * 58.0, 16.0, 0.0, 1.0, Vector3(4.4, 1, 2.4))
		at.call(g, "districts/solar_tree", e * 70.0, 26.0, 0.0, 1.0, Vector3(0.8, 7, 0.8))
		at.call(g, "districts/solar_tree", e * 70.0, -26.0, 0.0, 1.0, Vector3(0.8, 7, 0.8))
	for k in 5:
		at.call(g, "districts/lamp_neo", -40.0 + k * 20.0, 26.0, 0.0, 1.0, Vector3(0.3, 6, 0.3))
		at.call(g, "districts/lamp_neo", -40.0 + k * 20.0, -26.0, 180.0, 1.0, Vector3(0.3, 6, 0.3))
	# --- Nova Terrace: two rings of homes round a plaza (gaps where the roads come in)
	var ter := TERRACE
	var n := 0
	for ring: Array in [[42.0, 10], [74.0, 16]]:
		for i in int(ring[1]):
			var a := i * TAU / float(ring[1]) + 0.2
			var dx: float = cos(a) * float(ring[0])
			var dz: float = sin(a) * float(ring[0])
			# Keep the west and north approaches open.
			if absf(wrapf(a - PI, -PI, PI)) < 0.32 or absf(wrapf(a - PI * 1.5, -PI, PI)) < 0.38:
				continue
			at.call(ter, "districts/pod_" + ["a", "b", "c"][n % 3], dx, dz, facing.call(dx, dz), 1.0, Vector3.ZERO)
			n += 1
	at.call(ter, "districts/spire_b", 0.0, 100.0, 180.0, 0.7, Vector3(30, 6, 20) * 0.7)
	at.call(ter, "", 0.0, 100.0, 180.0, 0.7, Vector3(26, 75, 15) * 0.7)
	at.call(ter, "districts/holo_sign", 0.0, 0.0, 0.0, 1.0, Vector3(0.7, 8, 0.7))
	for i in 6:
		var a := i * TAU / 6.0
		at.call(ter, "districts/solar_tree", cos(a) * 16.0, sin(a) * 16.0, 0.0, 1.0, Vector3(0.8, 7, 0.8))
		at.call(ter, "districts/planter", cos(a + 0.5) * 24.0, sin(a + 0.5) * 24.0, rad_to_deg(-a), 1.0, Vector3.ZERO)
	# --- Kasei Skyport
	var sp := SKYPORT
	for pad: Array in [[-20.0, -50.0, 30.0], [45.0, -30.0, -40.0], [55.0, 42.0, 200.0]]:
		at.call(sp, "districts/landing_pad", pad[0], pad[1], 0.0, 1.0, Vector3.ZERO)
	at.call(sp, "districts/shuttle", -20.0, -50.0, 30.0, 1.0, Vector3(8, 9, 24))
	at.call(sp, "districts/shuttle", 55.0, 42.0, 200.0, 1.0, Vector3(8, 9, 24))
	at.call(sp, "districts/control_tower", -62.0, -8.0, 0.0, 1.0, Vector3(5, 38, 5))
	at.call(sp, "hangar", -30.0, 62.0, 90.0, 1.7, Vector3.ZERO)
	at.call(sp, "hangar", 0.0, 82.0, 90.0, 1.7, Vector3.ZERO)
	at.call(sp, "tank_cluster", -78.0, 40.0, 0.0, 1.3, Vector3(11, 9, 6))
	at.call(sp, "crate_stack", -50.0, 30.0, 20.0, 1.0, Vector3(3.6, 3, 2))
	at.call(sp, "crate_stack", -44.0, 36.0, -15.0, 1.0, Vector3(3.6, 3, 2))
	at.call(sp, "districts/holo_sign", -50.0, 60.0, 135.0, 1.0, Vector3(0.7, 8, 0.7))
	for k in 6:
		at.call(sp, "districts/lamp_neo", -40.0 + k * 18.0, 12.0, 0.0, 1.0, Vector3(0.3, 6, 0.3))
	_district_pieces = out
	return out


## The monorail: from the Galleria past Tharsis Gate's west wall to Helios.
## A polyline (x, z); the track rides MONO_HEIGHT above the ground.
const MONO_HEIGHT := 10.0


static func monorail() -> Array:
	return [Vector2(-560, 158), Vector2(-470, 110), Vector2(-380, 60), Vector2(-312, 20), Vector2(-330, -80),
			Vector2(-390, -200), Vector2(-440, -300), Vector2(-470, -368)]


## Districts' walkers: [district centre, loops of local points].
static func district_walks() -> Array:
	return [
		[HELIOS, [[Vector2(-30, 40), Vector2(30, 40), Vector2(48, -10)], [Vector2(50, 50), Vector2(-50, 50)],
				[Vector2(-40, -20), Vector2(-45, 30), Vector2(10, 46)]]],
		[GALLERIA, [[Vector2(-44, 0), Vector2(44, 0)], [Vector2(40, 2), Vector2(-40, 2), Vector2(-40, -3)],
				[Vector2(-8, 4), Vector2(8, -4), Vector2(30, -4)], [Vector2(70, 10), Vector2(56, -12)]]],
		[TERRACE, [[Vector2(-30, 0), Vector2(0, 30), Vector2(30, 0), Vector2(0, -30)], [Vector2(-58, 10), Vector2(-58, -40)],
				[Vector2(20, 58), Vector2(-20, 58)]]],
		[SKYPORT, [[Vector2(-40, 20), Vector2(20, 12), Vector2(30, 60)], [Vector2(-60, 0), Vector2(-40, -40)]]],
	]


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


# --- Estates: interiors, property doors, the visa office, Kasei Aero, trees ---

## Interiors deep under the valley (a building's door takes you in): kind
## -> floor centre ("districts/<kind>" pieces; their door wall faces +Z).
const INTERIOR_Y := -450.0
const INTERIORS := {"apartment": Vector3(0, -450, 0), "office": Vector3(80, -450, 0)}


static func interior_exit(kind: String) -> Vector3:
	return (INTERIORS[kind] as Vector3) + Vector3(0, 0.1, 4.6 if kind == "apartment" else 4.1)


## Interiors have air.
static func interior_air() -> Array:
	return [AABB(INTERIORS.apartment + Vector3(-8.2, -0.5, -5.8), Vector3(16.4, 4.4, 11.6)),
			AABB(INTERIORS.office + Vector3(-6.2, -0.5, -5.3), Vector3(12.4, 4.4, 10.6))]


## Property doors: [Career.PROPERTIES id, where you stand at the door,
## interior kind ("" for a unit you walk into)]. From the district pieces.
static func property_doors() -> Array:
	var out := []
	var h := HELIOS
	var door := func(id: String, c: Vector2, dx: float, dz: float, yaw_deg: float, local: Vector3, sc: float, kind: String) -> void:
		var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
		var p := b * (local * sc)
		out.append([id, WorldTerrain.at(c.x + dx + p.x, c.y + dz + p.z) + Vector3(0, 0.1, 0), kind])
	var face := func(dx: float, dz: float) -> float:
		return rad_to_deg(atan2(-dx, -dz))
	door.call("helios_spire", h, -62.0, -58.0, face.call(-62.0, -58.0), Vector3(0, 0, 19.5), 1.0, "apartment")
	door.call("helios_spire_2", h, -92.0, 30.0, face.call(-92.0, 30.0), Vector3(0, 0, 19.5), 0.8, "apartment")
	door.call("helios_lens", h, 66.0, -54.0, face.call(66.0, -54.0), Vector3(0, 0, 11.6), 1.0, "apartment")
	door.call("helios_arc", h, 0.0, -92.0, 0.0, Vector3(-20, 0, 9.6), 1.0, "apartment")
	door.call("helios_ring", h, 0.0, 0.0, 0.0, Vector3(0, 0, 5.6), 1.0, "apartment")
	door.call("terrace_tower", TERRACE, 0.0, 100.0, 180.0, Vector3(0, 0, 11.6), 0.7, "apartment")
	door.call("skyport_office", SKYPORT, -62.0, -8.0, 0.0, Vector3(0, 0, 3.2), 1.0, "office")
	var g := WorldTerrain.at(GALLERIA.x, GALLERIA.y)
	out.append(["galleria_unit_a", g + Vector3(-35, 0.1, 8.9), ""])
	out.append(["galleria_unit_b", g + Vector3(35, 0.1, 8.9), ""])
	return out


## The Immigration office (visas and permits), by Tharsis Gate's gate, and
## Kasei Aero's counter at the Skyport (aircraft); where aircraft park.
static func visa_office() -> Vector3:
	return CityLayout.ORIGIN + Vector3(-12, 0, 27)


static func aero_counter() -> Vector3:
	return WorldTerrain.at(SKYPORT.x - 40, SKYPORT.y + 20) + Vector3(0, 0.1, 0)


static func aircraft_spot() -> Array:
	return [WorldTerrain.at(SKYPORT.x + 45, SKYPORT.y - 30) + Vector3(0, 0.6, 0), PI * 0.5]


## Trees you can cut (a plasma saw): the city's park trees (protected: it's
## vandalism) and the outland groves of rust pine (timber, no questions).
## [id, position, protected].
const GROVES := [Vector2(-250, 300), Vector2(225, -390), Vector2(-60, 430), Vector2(560, 120)]
const TREE_REGROW := 900  ## seconds before a felled tree stands again


static func trees() -> Array:
	var out := []
	var i := 0
	for p: Array in CityLayout.plants():
		if p[0] == "life/tree":
			out.append(["c%d" % i, p[1], true])
			i += 1
	for gi in GROVES.size():
		var c: Vector2 = GROVES[gi]
		for k in 9:
			var a := k * TAU / 9.0 + gi
			var r := 7.0 + float((k * 37 + gi * 11) % 13)
			out.append(["g%d_%d" % [gi, k], WorldTerrain.at(c.x + cos(a) * r, c.y + sin(a) * r), false])
	return out
