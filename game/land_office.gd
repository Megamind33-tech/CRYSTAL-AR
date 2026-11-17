class_name LandOffice
extends RefCounted
## Land, building and renting (free roam). Plots on the map you buy and sell,
## build on from a catalogue of Titan capsule modules, keep up, and rent out
## to bot tenants (rent each in-game day) or list for other players (data
## only for now). All state lives in one Dictionary the career keeps:
##   career.d["land"] = LandOffice.new_state()
## Every function takes that dictionary, the wallet holder (a Dictionary with
## "wallet", e.g. career.d) and `now` in game seconds. Pure data, no nodes;
## LandOffice.place() builds the presentation + collision.

const DAY := int(GameClock.DAY_SECONDS)
const SELL_BACK := 0.8          ## the office buys plots back at 80% of list
const BUILDING_RESALE := 0.5    ## half a finished building's cost adds to a sale
const VACANCY_DAYS := 2         ## days an empty building waits before a bot tenant moves in

## id -> {pos, size (m, square), price, zone}
const PLOTS := {
	"r1": {"pos": Vector3(60, 0, 40), "size": 24.0, "price": 18000, "zone": "residential"},
	"r2": {"pos": Vector3(90, 0, 40), "size": 24.0, "price": 18000, "zone": "residential"},
	"r3": {"pos": Vector3(60, 0, 75), "size": 30.0, "price": 26000, "zone": "residential"},
	"c1": {"pos": Vector3(-70, 0, 30), "size": 30.0, "price": 40000, "zone": "commercial"},
	"c2": {"pos": Vector3(-70, 0, 70), "size": 30.0, "price": 40000, "zone": "commercial"},
	"i1": {"pos": Vector3(0, 0, -120), "size": 40.0, "price": 55000, "zone": "industrial"},
	"i2": {"pos": Vector3(50, 0, -120), "size": 40.0, "price": 55000, "zone": "industrial"},
}

## id -> {name, piece (art/environment/<piece>.glb), zone, cost, build_days, upkeep/day, rent/day, footprint m}
const BUILDINGS := {
	"hab_r14": {"name": "Hab R14", "piece": "titan/hab_r14", "zone": "residential", "cost": 30000,
		"build_days": 2, "upkeep": 120, "rent": 600, "footprint": 20.0},
	"market_hub": {"name": "Market Hub", "piece": "titan/market_hub", "zone": "commercial", "cost": 60000,
		"build_days": 3, "upkeep": 300, "rent": 1400, "footprint": 26.0},
	"plant_ex03": {"name": "Plant EX-03", "piece": "titan/plant_ex03", "zone": "industrial", "cost": 90000,
		"build_days": 4, "upkeep": 500, "rent": 2200, "footprint": 36.0},
}

const TENANT_FIRST := ["Ade", "Mira", "Juno", "Kofi", "Tess", "Rui", "Oksana", "Bram", "Lio", "Sefa"]
const TENANT_LAST := ["Okoro", "Vance", "Halloran", "Ishida", "Brask", "Moreau", "Teague", "Quill"]


static func new_state() -> Dictionary:
	## plots: id -> {building, built_at, tenant, tenant_kind ("bot"/"player"/""),
	## vacant_since, listed_rent, paid_to}; income: lifetime rent collected.
	return {"plots": {}, "income": 0, "seed": 1}


static func plot(s: Dictionary, id: String) -> Dictionary:
	return s.plots.get(id, {})


static func owned(s: Dictionary, id: String) -> bool:
	return s.plots.has(id)


static func price(s: Dictionary, id: String) -> int:
	## What the office asks for a plot (0 if it's yours or unknown).
	return 0 if owned(s, id) or not PLOTS.has(id) else int(PLOTS[id].price)


static func sale_value(s: Dictionary, id: String, now: int) -> int:
	if not owned(s, id):
		return 0
	var v := int(PLOTS[id].price * SELL_BACK)
	if built(s, id, now):
		v += int(BUILDINGS[plot(s, id).building].cost * BUILDING_RESALE)
	return v


static func buy(s: Dictionary, holder: Dictionary, id: String, now: int) -> bool:
	if not PLOTS.has(id) or owned(s, id) or int(holder.wallet) < int(PLOTS[id].price):
		return false
	holder.wallet = int(holder.wallet) - int(PLOTS[id].price)
	s.plots[id] = {"building": "", "built_at": 0, "tenant": "", "tenant_kind": "", "vacant_since": now,
		"listed_rent": 0, "paid_to": now}
	return true


static func sell(s: Dictionary, holder: Dictionary, id: String, now: int) -> int:
	if not owned(s, id):
		return 0
	settle(s, holder, now)
	var v := sale_value(s, id, now)
	holder.wallet = int(holder.wallet) + v
	s.plots.erase(id)
	return v


static func can_build(s: Dictionary, holder: Dictionary, id: String, building: String) -> String:
	## "" when allowed, else why not.
	if not owned(s, id):
		return "not your plot"
	if not BUILDINGS.has(building):
		return "unknown building"
	if plot(s, id).building != "":
		return "already built"
	var b: Dictionary = BUILDINGS[building]
	if b.zone != PLOTS[id].zone:
		return "zoned %s" % PLOTS[id].zone
	if float(b.footprint) > float(PLOTS[id].size):
		return "too big for the plot"
	if int(holder.wallet) < int(b.cost):
		return "can't afford"
	return ""


static func build(s: Dictionary, holder: Dictionary, id: String, building: String, now: int) -> bool:
	if can_build(s, holder, id, building) != "":
		return false
	var b: Dictionary = BUILDINGS[building]
	holder.wallet = int(holder.wallet) - int(b.cost)
	var p := plot(s, id)
	p.building = building
	p.built_at = now + int(b.build_days) * DAY
	p.paid_to = p.built_at
	p.vacant_since = p.built_at
	return true


static func built(s: Dictionary, id: String, now: int) -> bool:
	var p := plot(s, id)
	return not p.is_empty() and p.building != "" and now >= int(p.built_at)


static func build_left(s: Dictionary, id: String, now: int) -> int:
	## Seconds until it's finished (0 when done or nothing building).
	var p := plot(s, id)
	return 0 if p.is_empty() or p.building == "" else maxi(0, int(p.built_at) - now)


static func list_for_players(s: Dictionary, id: String, rent: int, now: int) -> bool:
	## Offer a finished building without a bot tenant to other players at
	## `rent`/day (0 withdraws). Data only for now.
	if not built(s, id, now) or plot(s, id).tenant_kind == "bot":
		return false
	plot(s, id).listed_rent = maxi(0, rent)
	return true


static func listings(s: Dictionary) -> Array:
	## [{plot, building, rent}] open to other players.
	var out := []
	for id: String in s.plots:
		var p: Dictionary = s.plots[id]
		if int(p.listed_rent) > 0 and p.tenant == "":
			out.append({"plot": id, "building": p.building, "rent": int(p.listed_rent)})
	return out


static func player_rents(s: Dictionary, id: String, player_name: String, now: int) -> bool:
	var p := plot(s, id)
	if p.is_empty() or int(p.listed_rent) <= 0 or p.tenant != "" or not built(s, id, now):
		return false
	p.tenant = player_name
	p.tenant_kind = "player"
	return true


static func evict(s: Dictionary, id: String, now: int) -> void:
	var p := plot(s, id)
	if not p.is_empty():
		p.tenant = ""
		p.tenant_kind = ""
		p.vacant_since = now


static func vacant(s: Dictionary, id: String, now: int) -> bool:
	return built(s, id, now) and plot(s, id).tenant == ""


static func _tenant_name(s: Dictionary) -> String:
	var n := int(s.seed)
	s.seed = (n * 1103515245 + 12345) % 2147483648
	return "%s %s" % [TENANT_FIRST[n % TENANT_FIRST.size()], TENANT_LAST[(n / 7) % TENANT_LAST.size()]]


static func settle(s: Dictionary, holder: Dictionary, now: int) -> Dictionary:
	## Runs whole days since last settle on every finished building: upkeep
	## out, rent in; a bot tenant moves into one vacant VACANCY_DAYS (unless
	## it's listed for players). Returns {income, upkeep, moved_in: [[plot, name]]}.
	var out := {"income": 0, "upkeep": 0, "moved_in": []}
	for id: String in s.plots:
		var p: Dictionary = s.plots[id]
		if p.building == "":
			continue
		var b: Dictionary = BUILDINGS[p.building]
		var t := int(p.paid_to)
		while t + DAY <= now:
			if p.tenant == "" and int(p.listed_rent) == 0 and t >= int(p.vacant_since) + VACANCY_DAYS * DAY:
				p.tenant = _tenant_name(s)
				p.tenant_kind = "bot"
				out.moved_in.append([id, p.tenant])
			out.upkeep += int(b.upkeep)
			if p.tenant != "":
				out.income += int(p.listed_rent) if p.tenant_kind == "player" else int(b.rent)
			t += DAY
		p.paid_to = t
	holder.wallet = int(holder.wallet) + int(out.income) - int(out.upkeep)
	s.income = int(s.income) + int(out.income)
	return out


## Presentation + collision for a finished building: kit instance under
## `parent`, its walls (KitCollision) on `body`. Null while under construction.
static func place(s: Dictionary, id: String, now: int, parent: Node3D, body: StaticBody3D) -> MeshInstance3D:
	if not built(s, id, now):
		return null
	var piece: String = BUILDINGS[plot(s, id).building].piece
	var at: Vector3 = PLOTS[id].pos
	var mi := Comic.kit_instance(piece, at)
	mi.name = "Land_" + id
	parent.add_child(mi)
	KitCollision.add(body, piece, at, 0.0)
	return mi
