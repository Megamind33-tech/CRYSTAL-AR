class_name Career
extends RefCounted
## THE HUNT's persistent career: what survives a deployment. Wallet, stash,
## gear, faction standing, the contract board and the city market. Stored in
## the profile (data.career) and changed only through these functions, which
## validate everything (no negative wallet, no selling what isn't in the
## stash, a run settles once). The host settles a run from the server's own
## record of what was extracted (HuntRules.haul), never from client claims.
##
## The loop: take a contract at the board -> buy gear -> deploy to the
## extraction zone -> extract loot (only extracted loot counts) -> settle:
## contract pay, standing, loot into the stash -> sell at the market (prices
## fall as you sell, recover between runs) -> better gear next time.

## Original factions of the Martian settlements.
const FACTIONS := {
	"tharsis": {"name": "Tharsis Mining Concern", "short": "THARSIS"},
	"kasei": {"name": "Kasei Freight Union", "short": "KASEI"},
	"ledger": {"name": "The Crimson Ledger", "short": "LEDGER"},
}
## Loot from a run (HuntRules.haul item ids) and its market base price.
const ITEMS := {
	"cargo_case": {"name": "Sealed cargo case", "base": 140},
	"stolen_cargo": {"name": "Stolen cargo (hot)", "base": 95},
	"vault_relic": {"name": "Vault relic", "base": 520},
	"bounty_proof": {"name": "Bounty proof", "base": 160},
	"helium3": {"name": "Helium-3 canister", "base": 180},
	"rare_ore": {"name": "Rare ore sample", "base": 150},
	"water_ice": {"name": "Water ice core", "base": 90},
	"supply_crate": {"name": "Supply crate", "base": 45},
	"refined_ingot": {"name": "Refined ingot", "base": 210},
	"oxygen_canister": {"name": "Oxygen canister", "base": 55},
	"scrap": {"name": "Hull scrap", "base": 70},
	"red_dust": {"name": "Red Dust (contraband)", "base": 0, "contraband": true},
	"dust_frost": {"name": "Frost Dust (contraband)", "base": 0, "contraband": true},
	"dust_bloom": {"name": "Bloom Dust (contraband)", "base": 0, "contraband": true},
	"dust_float": {"name": "Float Dust (contraband)", "base": 0, "contraband": true},
	"dust_spark": {"name": "Spark Dust (contraband)", "base": 0, "contraband": true},
	"parcel": {"name": "Courier parcel", "base": 0, "no_sale": true},
	"fresh_food": {"name": "Fresh greens (Deep Furrow)", "base": 60},
	# Meat on Mars: vat-grown is everyday; fresh, from Deep Furrow's rabbit
	# hutches, is a luxury (like greens, a sign of wealth).
	"vat_meat": {"name": "Vat meat", "base": 25},
	"fresh_meat": {"name": "Fresh meat (Deep Furrow)", "base": 120},
	"meal_pack": {"name": "Meal pack", "base": 15},
	"red_ale": {"name": "Red ale", "base": 8},
	"torch": {"name": "Torch", "base": 15, "tool": true},
	"cutter": {"name": "Plasma saw", "base": 140, "tool": true},
	"timber": {"name": "Mars timber", "base": 90},
	"ring_bonds": {"name": "Helios Ring bearer bonds", "base": 0, "no_sale": true},
	"jetpack": {"name": "Jetpack", "base": 900, "tool": true},
	"grill_plate": {"name": "Grill plate", "base": 30},
	"water_ration": {"name": "Water ration", "base": 45},
	"algae_culture": {"name": "O2 algae culture (stolen)", "base": 150},
	"cred_chip": {"name": "Credit chips", "base": 40},
	# Guns (Loadouts.PRIMARIES index): carried in the pack, one equipped.
	# The Pulse rifle is standard issue, always yours.
	"burst_rifle": {"name": "Burst rifle", "base": 380, "weapon": 1},
	"scatter_gun": {"name": "Scatter gun", "base": 340, "weapon": 2},
	"flux_smg": {"name": "Flux SMG", "base": 300, "weapon": 3},
	"frag_grenade": {"name": "Frag grenade", "base": 45},
	# Tools and kit (what each does: TOOLS and USE below).
	"crowbar": {"name": "Crowbar", "base": 25, "tool": true},
	"lockpick": {"name": "Lockpicks", "base": 20},
	"medkit": {"name": "Medkit", "base": 50},
	"armour_plate": {"name": "Armour plate", "base": 70},
	"stim_cola": {"name": "Stim cola", "base": 12},
	"mask": {"name": "Mask", "base": 60, "tool": true},
	"hand_drill": {"name": "Hand drill", "base": 150, "tool": true},
	"fuel_cell": {"name": "Fuel cell", "base": 20},
	"repair_kit": {"name": "Repair kit", "base": 35},
	"binoculars": {"name": "Binoculars", "base": 50, "tool": true},
	"scanner": {"name": "Scanner", "base": 110, "tool": true},
}
## Rover kit used at the hatch: what each puts back (percent).
const ROVER_KIT := {"fuel_cell": ["fuel", 50.0], "repair_kit": ["condition", 60.0]}
## Joe's Respray & Chop (the garage outside the gate): a respray clears
## the Marshals' interest (if none of them sees you drive in), the chop
## shop buys rovers that aren't yours (once per rover per CHOP_COOLDOWN),
## and fuel and repairs for any rover.
const RESPRAY_BASE := 100
const RESPRAY_PER_STAR := 100
const CHOP_PRICE := {"concern": 450, "public": 250}
const CHOP_COOLDOWN := 1800
const GARAGE_FUEL := 1.0        ## $ per percent of a tank
const GARAGE_REPAIR := 1.5      ## $ per percent of condition
## Used from the pack: what each restores (health, shield, stamina, fatigue).
const USE := {"medkit": {"health": 50.0}, "armour_plate": {"shield": 100.0},
		"stim_cola": {"stamina": 100.0, "fatigue": -25.0},
		# Food: how much it fills you (and fresh meat puts strength back).
		"meal_pack": {"food": 25.0}, "fresh_food": {"food": 25.0, "stamina": 30.0},
		"vat_meat": {"food": 40.0}, "fresh_meat": {"food": 65.0, "health": 10.0},
		"water_ration": {"water": 60.0},
		"red_ale": {"water": 25.0, "fatigue": -15.0, "stamina": 20.0}, "grill_plate": {"food": 75.0, "health": 15.0}}
## Break-in tools: [seconds at the lock, the crime it is]. Lockpicks are
## quiet and quick, one used per lock; a crowbar is loud and slow, but lasts.
const BREAK_TOOLS := {"lockpick": [2.5, "burglary_quiet"], "crowbar": [4.0, "burglary"]}
const GRENADES_MAX := 9  ## how many you can carry
## Shops with a counter you walk up to (CityLayout.shops): what each sells
## and its price, and what it buys ("all" sellable goods, "weapons", or
## nothing). The arms dealers also fit armour and webbing (GEAR).
const SHOPS := {
	"exchange": {"name": "Kasei Exchange", "keeper": "Mbeki", "friend": "trader",
			"sells": {"supply_crate": 60, "water_ration": 70, "oxygen_canister": 85, "stim_cola": 18, "scanner": 220,
					"vat_meat": 40},
			"buys": "all"},
	"arms": {"name": "Varga's Arms", "keeper": "Varga", "friend": "armourer", "gear": true,
			"sells": {"burst_rifle": 520, "scatter_gun": 460, "flux_smg": 420, "frag_grenade": 60, "armour_plate": 110},
			"buys": "weapons"},
	"store": {"name": "Gate General Store", "keeper": "Ama",
			"sells": {"water_ration": 70, "oxygen_canister": 85, "fresh_food": 55, "medkit": 80, "stim_cola": 15, "crowbar": 40,
					"meal_pack": 20, "vat_meat": 35,
					"fuel_cell": 35, "binoculars": 90, "torch": 30},
			"buys": ""},
	"salvage": {"name": "Rook's Pawn & Salvage", "keeper": "Rook",
			"sells": {"crowbar": 35, "hand_drill": 240, "fuel_cell": 30, "repair_kit": 60, "torch": 28, "cutter": 160}, "buys": "all"},
	# The bars: drink, a hot plate, and talk (rumours).
	"bar": {"name": "The Red Lantern", "keeper": "Lena", "hours": "bar",
			"sells": {"red_ale": 12, "grill_plate": 45, "water_ration": 60, "stim_cola": 15}, "buys": ""},
	"saloon": {"name": "Dust Devil Saloon", "keeper": "Okon", "hours": "bar",
			"sells": {"red_ale": 15, "grill_plate": 50, "meal_pack": 25, "water_ration": 75}, "buys": ""},
	"guns": {"name": "Ironside Guns", "keeper": "Ironside", "gear": true,
			"sells": {"scatter_gun": 480, "flux_smg": 400, "frag_grenade": 55, "armour_plate": 100, "lockpick": 30, "mask": 90,
					"jetpack": 1500},
			"buys": "weapons"},
	"post": {"name": "Hollow Trading Post", "keeper": "Kofi",
			"sells": {"water_ration": 90, "oxygen_canister": 110, "burst_rifle": 560, "flux_smg": 380, "medkit": 95,
					"lockpick": 35, "hand_drill": 260, "fuel_cell": 45, "repair_kit": 75, "binoculars": 110, "meal_pack": 28,
					"vat_meat": 50}, "buys": "all"},
	# The Prism Galleria (the outlands' mall, west of the city).
	"tech": {"name": "Nova Tech", "keeper": "Yusuf",
			"sells": {"torch": 32, "binoculars": 95, "scanner": 210, "jetpack": 1450, "fuel_cell": 38, "repair_kit": 65},
			"buys": ""},
	"foodcourt": {"name": "Orbit Food Court", "keeper": "Chidi",
			"sells": {"grill_plate": 40, "meal_pack": 18, "fresh_food": 50, "fresh_meat": 70, "stim_cola": 12, "red_ale": 11,
					"water_ration": 62}, "buys": ""},
	"pharmacy": {"name": "Helix Pharmacy", "keeper": "Dr. Sato",
			"sells": {"medkit": 75, "oxygen_canister": 80, "water_ration": 65, "stim_cola": 14}, "buys": ""},
	"outfitter": {"name": "Redline Outfitters", "keeper": "Kaya", "gear": true,
			"sells": {"armour_plate": 105, "mask": 85, "lockpick": 32, "crowbar": 38, "hand_drill": 230, "cutter": 150}, "buys": ""},
	"prism": {"name": "Prism Exchange", "keeper": "Amara",
			"sells": {"supply_crate": 65, "vat_meat": 38, "fuel_cell": 40}, "buys": "all"},
	"noodle": {"name": "Red Planet Noodles", "keeper": "Mei", "hours": "bar",
			"sells": {"meal_pack": 16, "grill_plate": 42, "red_ale": 12, "stim_cola": 12}, "buys": ""},
}
const WEAPON_RESALE := 0.5  ## a used gun sells for half its list value
## Your residence (a hab in Tharsis Gate): a locker for what you don't
## carry, and its lock. While you're away, thieves try it every
## BURGLARY_EVERY seconds; a lock holds with its chance (`resist`).
const LOCKER_SLOTS := 20
const LOCKS := [{"name": "Basic latch", "cost": 0, "resist": 0.6}, {"name": "Reinforced lock", "cost": 250, "resist": 0.85},
		{"name": "Alarm and bolt", "cost": 600, "resist": 0.97}]
const BURGLARY_EVERY := 1800
## Breaking into someone else's: how long you work the lock, what's inside
## ([item, count, weight], picked twice), and when it's restocked.
const BREAKIN_SECONDS := 4.0
const BREAKIN_COOLDOWN := 1200
const HOME_LOOT := [["cred_chip", 4, 3.0], ["water_ration", 2, 3.0], ["vat_meat", 2, 2.0], ["oxygen_canister", 2, 2.0], ["fresh_food", 2, 2.0],
		["refined_ingot", 1, 1.0], ["frag_grenade", 1, 1.0], ["red_dust", 1, 0.6], ["flux_smg", 1, 0.3]]
## The rover's hold: how many stacks it takes.
const ROVER_SLOTS := 12
## Prices at the city exchange to buy what the colony needs.
const BUY := {"oxygen_canister": 85, "fresh_food": 45, "water_ration": 70, "fresh_meat": 140}  ## greens: a trade route up to the city
## The lab (Dr. Okafor's, Tharsis Gate): [inputs, cash, output, count, seconds].
## Oxygen from ice by electrolysis; Red Dust, the stim the Ledger moves, is
## illegal in the city (checkpoints search for it).
const RECIPES := {
	"oxygen": {"inputs": {"water_ice": 1}, "cash": 15, "output": "oxygen_canister", "count": 3, "seconds": 90},
	"red_dust": {"inputs": {"rare_ore": 1, "helium3": 1}, "cash": 40, "output": "red_dust", "count": 3, "seconds": 180},
	"water": {"inputs": {"water_ice": 1}, "cash": 10, "output": "water_ration", "count": 2, "seconds": 60},
	"algae_oxygen": {"inputs": {"algae_culture": 1}, "cash": 20, "output": "oxygen_canister", "count": 5, "seconds": 120},
}
const DEALER_PRICE := 240          ## the Ledger's dealer pays per dose
const SEARCH_CHANCE := 0.35        ## a checkpoint search on entering the city
const SEARCH_FINE := 120
## Job centre (Tunde, Tharsis Gate): repeatable work in the valley, each job
## once per deployment. [title, place, reward items, cash, trust (who)].
## Jobs come round again JOB_COOLDOWN seconds after you do one. `vehicle`:
## it's done at the place only if you arrive driving.
const JOBS := {
	"courier": {"title": "Courier run to Dust Hollow", "pay": 180, "trust": "foreman"},
	"salvage": {"title": "Salvage the Kestrel wreck", "pay": 60, "items": {"scrap": 3}},
	"ice": {"title": "Cut ice at the crater", "pay": 50, "items": {"water_ice": 2}},
	"taxi": {"title": "Taxi: drive a fare out to Dust Hollow", "pay": 220, "vehicle": true},
	"haul": {"title": "Haul parts to Kasei Motors", "pay": 260, "vehicle": true},
	"line": {"title": "A shift on the Kasei Motors line", "pay": 120},
	"patrol": {"title": "Patrol the pipeline for the Concern", "pay": 140, "trust": "foreman"},
}
const JOB_COOLDOWN := 300
## THE HUNT's people you can get to know: trust 0..100 each. Trust grows by
## talking (once per deployment), by working for their faction and by
## favours; at FRIEND trust they help you.
const PEOPLE := {
	"chemist": {"name": "Dr. Okafor", "role": "Lab chemist", "faction": "kasei"},
	"dealer": {"name": "Sable", "role": "Ledger dealer", "faction": "ledger"},
	"jobs": {"name": "Tunde", "role": "Job centre", "faction": "kasei"},
	"farmer": {"name": "Ngozi", "role": "Deep Furrow steward", "faction": "kasei"},
	"broker": {"name": "Oyelaran", "role": "Kasei broker", "faction": "kasei"},
	"trader": {"name": "Mbeki", "role": "Exchange trader", "faction": "kasei"},
	"armourer": {"name": "Varga", "role": "Armourer", "faction": "ledger"},
	"foreman": {"name": "Adaeze", "role": "Hollow foreman", "faction": "tharsis"},
}
const TALK_TRUST := 4
const CONTRACT_TRUST := 8   ## for everyone of the contract's faction
const DELIVERY_TRUST := 3   ## the foreman, per supply crate delivered
const FRIEND := 50
## Friends' help: the trader pays more, the armourer charges less, the
## broker's contracts pay more.
const FRIEND_SELL_BONUS := 0.1
const FRIEND_GEAR_DISCOUNT := 0.15
const FRIEND_PAY_BONUS := 0.15
## Supplies bought in the city (carried in the stash to Dust Hollow).
const SUPPLY_PRICE := 60
## Dust Hollow: the claim and the refinery it brings.
const CLAIM_COST := 800
const CLAIM_TRUST := 40      ## the foreman must back you
const CLAIM_STANDING_LOSS := 20  ## Tharsis lose the settlement to you
const REFINERY_PER_RUN := 2  ## ingots per deployment, one crate each
const REFINERY_CAP := 8
const UNREST_LIMIT := 3      ## deployments without supplies before it's lost
## Concern raids on a Hollow you hold: one is due every RAID_EVERY
## deployments. Defend it in person (fight it at the Hollow) or leave it to
## the militia: an undefended raid is held off only by a strong militia
## (friends send fighters), and still costs supplies and ingots.
const RAID_EVERY := 2
const MILITIA_HOLDS := 3
const RAID_REWARD := 150
const RAID_TRUST := 10
## Contract templates: `need` items of the haul, `count` of them.
const CONTRACTS := [
	{"id": "recover_cargo", "faction": "tharsis", "need": "cargo_case", "count": 1, "pay": 260,
			"title": "Recover the Concern's cargo", "brief": "Find your assigned cargo case in Rustwood Yard and extract it."},
	{"id": "recover_two", "faction": "tharsis", "need": "cargo_case", "count": 2, "pay": 560,
			"title": "Full manifest", "brief": "Extract both of your assigned cargo cases."},
	{"id": "crack_vault", "faction": "kasei", "need": "vault_relic", "count": 1, "pay": 780,
			"title": "Crack the Rustwood vault", "brief": "Unlock the vault, take the relic and get it to a pad."},
	{"id": "lift_rival", "faction": "ledger", "need": "stolen_cargo", "count": 1, "pay": 340,
			"title": "Lift a rival's cargo", "brief": "Take another hunter's cargo by force and extract it."},
	{"id": "collect_bounty", "faction": "kasei", "need": "bounty_proof", "count": 1, "pay": 420,
			"title": "Collect a bounty", "brief": "Take down a Wanted hunter and extract the bounty proof."},
]
const BOARD_SIZE := 3
## Gear bought in the city, applied at the next deployment (HuntRules.gear).
const GEAR := {
	"plating": {"name": "Armour plating", "levels": [250, 420, 650], "per_level": "+15 starting armour"},
	"ammo": {"name": "Ammo webbing", "levels": [160, 320], "per_level": "+1 spare magazine per weapon"},
}
const START_WALLET := 300
const SELL_IMPACT := 0.07  ## each sale lowers that item's price multiplier
const PRICE_MIN := 0.5
const PRICE_MAX := 1.5
const RECOVERY := 0.35  ## per run, prices move this share of the way back to 1
const FAIL_STANDING := -5
const DONE_STANDING := 10

var d: Dictionary


static func fresh() -> Dictionary:
	return {"wallet": START_WALLET, "stash": {}, "gear": {"plating": 0, "ammo": 0}, "standing": {},
			"contract": {}, "market": {}, "runs": 0, "settled": [], "earned": 0, "trust": {}, "talked": {},
			"hollow": {"owner": "tharsis", "supplies": 0, "ingots": 0, "unrest": 0, "since_raid": 0, "raid_due": false},
			"oxygen": 100.0, "fatigue": 0.0, "water": 100.0, "lab": {}, "job": {}, "jobs_done": {}, "companion": "",
			"armed": "", "rover_cargo": {},
			"home": {"locker": {}, "lock": 0, "checked_at": 0, "robbed": {}}, "ride": 0,
			"aircraft": -1, "visas": {}, "property": {}, "gang": {}, "felled": {}, "bounty": {}, "bounties_done": {},
			"trade": {"chain": 0, "sold": 0, "learned": [], "clients": {}, "orders": [], "dealers": {}, "order_at": 0},
			"heist": {}, "heists_done": {},
			"feed": [], "fame": 0, "partner": {},
			"cosmetics": ["emote_dance", "emote_talk"], "equipped": {}, "season": {"xp": 0, "claimed": []}}


func _init(data: Dictionary = {}) -> void:
	d = data if not data.is_empty() else fresh()
	normalize()


## JSON gives floats and may lack newer keys: restore the shape.
func normalize() -> void:
	var f := fresh()
	for k in f:
		if not d.has(k):
			d[k] = f[k]
	d.wallet = int(d.wallet)
	d.runs = int(d.runs)
	d.earned = int(d.earned)
	for k in d.stash:
		d.stash[k] = int(d.stash[k])
	for k in d.rover_cargo:
		d.rover_cargo[k] = int(d.rover_cargo[k])
	for k in fresh().home:
		if not d.home.has(k):
			d.home[k] = fresh().home[k]
	for k in d.home.locker:
		d.home.locker[k] = int(d.home.locker[k])
	d.home.lock = int(d.home.lock)
	d.home.checked_at = int(d.home.checked_at)
	for k in GEAR:
		d.gear[k] = int(d.gear.get(k, 0))
	for k in d.standing:
		d.standing[k] = int(d.standing[k])
	d.settled = Array(d.settled)
	for k in d.trust:
		d.trust[k] = int(d.trust[k])
	for k in d.talked:
		d.talked[k] = int(d.talked[k])
	for k in ["supplies", "ingots", "unrest", "since_raid"]:
		d.hollow[k] = int(d.hollow.get(k, 0))
	d.hollow["raid_due"] = bool(d.hollow.get("raid_due", false))
	d.oxygen = float(d.oxygen)
	d.fatigue = float(d.fatigue)
	d.water = float(d.get("water", 100.0))
	d["food"] = float(d.get("food", 100.0))
	for k in d.jobs_done:
		d.jobs_done[k] = int(d.jobs_done[k])
	if d.lab.has("ready_at"):
		d.lab.ready_at = int(d.lab.ready_at)
		d.lab.count = int(d.lab.count)


# --- Contract board ---

## The board's offers: BOARD_SIZE templates, a different set each run.
func offers() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["board", d.runs])
	var pool := range(CONTRACTS.size())
	var out := []
	while out.size() < BOARD_SIZE and not pool.is_empty():
		out.append(CONTRACTS[pool.pop_at(rng.randi() % pool.size())])
	return out


func accept(contract_id: String) -> bool:
	if not d.contract.is_empty():
		return false
	for c: Dictionary in offers():
		if c.id == contract_id:
			d.contract = c.duplicate()
			return true
	return false


func abandon() -> bool:
	if d.contract.is_empty():
		return false
	_standing(d.contract.faction, FAIL_STANDING)
	d.contract = {}
	return true


func standing(faction: String) -> int:
	return int(d.standing.get(faction, 0))


func _standing(faction: String, delta: int) -> void:
	d.standing[faction] = clampi(standing(faction) + delta, -100, 100)


# --- Market ---

func price(item: String) -> int:
	if not ITEMS.has(item):
		return 0
	var bonus := 1.0 + (FRIEND_SELL_BONUS if is_friend("trader") else 0.0)
	return maxi(roundi(ITEMS[item].base * float(d.market.get(item, 1.0)) * bonus), 1)


func sell(item: String, count: int = 1) -> int:
	var have: int = d.stash.get(item, 0)
	if count <= 0 or have < count or not sellable(item):
		return 0
	var got := 0
	for i in count:
		got += price(item)
		d.market[item] = maxf(float(d.market.get(item, 1.0)) - SELL_IMPACT, PRICE_MIN)
	d.stash[item] = have - count
	if d.stash[item] == 0:
		d.stash.erase(item)
	d.wallet += got
	d.earned += got
	return got


## Cost of the next level of `gear` (-1: maxed or unknown).
func gear_cost(gear: String) -> int:
	if not GEAR.has(gear):
		return -1
	var lv: int = d.gear.get(gear, 0)
	var levels: Array = GEAR[gear].levels
	if lv >= levels.size():
		return -1
	return roundi(int(levels[lv]) * (1.0 - (FRIEND_GEAR_DISCOUNT if is_friend("armourer") else 0.0)))


func buy_gear(gear: String) -> bool:
	var cost := gear_cost(gear)
	if cost < 0 or d.wallet < cost:
		return false
	d.wallet -= cost
	d.gear[gear] = int(d.gear[gear]) + 1
	return true


## What HuntRules applies at spawn: {"shield_bonus": float, "spare_mags": int}.
func loadout() -> Dictionary:
	return {"shield_bonus": 15.0 * int(d.gear.plating), "spare_mags": int(d.gear.ammo)}


# --- Settling a run ---

## Settles deployment `run_id` from `haul` (Array of {"item", "value"}, the
## server's record of what this hunter extracted). Once per run id. Returns
## {"items": {item: n}, "contract": "done"/"failed"/"", "pay": int}.
func settle(run_id: String, haul: Array) -> Dictionary:
	var out := {"items": {}, "contract": "", "pay": 0, "applied": false}
	if run_id in d.settled:
		return out
	d.settled.append(run_id)
	d.settled = d.settled.slice(-50)
	out.applied = true
	for h: Dictionary in haul:
		var item := str(h.get("item", ""))
		if not ITEMS.has(item):
			continue
		d.stash[item] = int(d.stash.get(item, 0)) + 1
		out.items[item] = int(out.items.get(item, 0)) + 1
	if not d.contract.is_empty():
		var c: Dictionary = d.contract
		if int(out.items.get(c.need, 0)) >= int(c.count):
			# The client takes the goods it asked for: the contract's items
			# leave the stash, the pay and standing come in.
			d.stash[c.need] = int(d.stash[c.need]) - int(c.count)
			if d.stash[c.need] <= 0:
				d.stash.erase(c.need)
			var pay := roundi(int(c.pay) * (1.0 + (FRIEND_PAY_BONUS if is_friend("broker") else 0.0)))
			d.wallet += pay
			d.earned += pay
			_standing(c.faction, DONE_STANDING)
			for who: String in PEOPLE:
				if PEOPLE[who].faction == c.faction:
					_trust(who, CONTRACT_TRUST)
			out.contract = "done"
			out.pay = pay
		else:
			_standing(c.faction, FAIL_STANDING)
			out.contract = "failed"
		d.contract = {}
	out.hollow = _run_refinery()
	# Between runs the settlements' NPC trade absorbs what was sold.
	for item: String in d.market.keys():
		d.market[item] = lerpf(float(d.market[item]), 1.0, RECOVERY)
	d.runs += 1
	return out


# --- People ---

func trust(who: String) -> int:
	return int(d.trust.get(who, 0))


func is_friend(who: String) -> bool:
	return trust(who) >= FRIEND


func _trust(who: String, delta: int) -> void:
	if PEOPLE.has(who):
		d.trust[who] = clampi(trust(who) + delta, 0, 100)


## A chat: trust once per deployment (talking again the same day is just
## talk). True if it counted.
func talk(who: String) -> bool:
	if not PEOPLE.has(who) or int(d.talked.get(who, -1)) == int(d.runs):
		return false
	d.talked[who] = int(d.runs)
	_trust(who, TALK_TRUST)
	return true


## What `who` says now: a line key by how well they know you.
func mood(who: String) -> String:
	var t := trust(who)
	return "stranger" if t < 15 else ("known" if t < FRIEND else "friend")


# --- Dust Hollow ---

func buy_supplies(count: int = 1) -> bool:
	if count <= 0 or d.wallet < SUPPLY_PRICE * count:
		return false
	d.wallet -= SUPPLY_PRICE * count
	d.stash["supply_crate"] = int(d.stash.get("supply_crate", 0)) + count
	return true


## Crates carried from the stash to the Hollow (at its foreman): the
## settlement's stock, and the foreman's thanks.
func deliver_supplies() -> int:
	var n: int = d.stash.get("supply_crate", 0)
	if n <= 0:
		return 0
	d.stash.erase("supply_crate")
	d.hollow.supplies = int(d.hollow.supplies) + n
	_trust("foreman", DELIVERY_TRUST * n)
	return n


func owns_hollow() -> bool:
	return d.hollow.owner == "player"


## Why a claim can't be made now ("" = it can).
func claim_blocker() -> String:
	if owns_hollow():
		return "owned"
	if trust("foreman") < CLAIM_TRUST:
		return "trust"
	if d.wallet < CLAIM_COST:
		return "money"
	return ""


## Stake the claim: the foreman backs you, the Concern loses the settlement
## (standing), the Crimson Ledger likes it. The refinery is yours to run.
func claim_hollow() -> bool:
	if not claim_blocker().is_empty():
		return false
	d.wallet -= CLAIM_COST
	d.hollow.owner = "player"
	d.hollow.unrest = 0
	d.hollow.since_raid = 0
	d.hollow.raid_due = false
	_standing("tharsis", -CLAIM_STANDING_LOSS)
	_standing("ledger", 10)
	return true


## Refined ingots waiting at the Hollow go to your stash.
func collect_ingots() -> int:
	var n: int = d.hollow.ingots
	if n <= 0 or not owns_hollow():
		return 0
	d.hollow.ingots = 0
	d.stash["refined_ingot"] = int(d.stash.get("refined_ingot", 0)) + n
	return n


## Each deployment the refinery runs on its supplies (no supplies: no
## output, and unrest grows; too long and the Concern takes it back). No
## free money: every ingot costs a crate someone hauled out there.
func _run_refinery() -> String:
	if not owns_hollow():
		return ""
	var h: Dictionary = d.hollow
	# A raid nobody came to fight: the militia's strength decides it.
	if h.raid_due:
		h.raid_due = false
		h.since_raid = 0
		if militia() >= MILITIA_HOLDS:
			h.supplies = int(h.supplies) / 2
			h.ingots = 0
			return "raid held"
		_lose_hollow()
		return "raid lost"
	h.since_raid = int(h.since_raid) + 1
	if int(h.since_raid) >= RAID_EVERY:
		h.raid_due = true
	if int(h.supplies) <= 0:
		h.unrest = int(h.unrest) + 1
		if int(h.unrest) >= UNREST_LIMIT:
			_lose_hollow()
			return "lost"
		return "idle"
	var made := mini(REFINERY_PER_RUN, REFINERY_CAP - int(h.ingots))
	made = mini(made, int(h.supplies))
	h.supplies = int(h.supplies) - maxi(made, 1)
	h.ingots = int(h.ingots) + made
	h.unrest = 0
	return "made %d" % made


## Fighters who stand with you at the Hollow: its crew, more when the
## foreman is a friend, one of Varga's gunners when the armourer is.
func militia() -> int:
	return 1 + (2 if is_friend("foreman") else 0) + (1 if is_friend("armourer") else 0)


## Concern raiders in the next raid: more the more they hate you.
func raiders() -> int:
	return 4 + (1 if standing("tharsis") <= -30 else 0) + (1 if standing("tharsis") <= -60 else 0)


## You fought the raid off yourself.
func raid_won() -> void:
	d.hollow.raid_due = false
	d.hollow.since_raid = 0
	d.wallet += RAID_REWARD
	d.earned += RAID_REWARD
	_trust("foreman", RAID_TRUST)
	_standing("tharsis", -5)


## You fell defending it: the Concern has the Hollow back.
func raid_lost() -> void:
	_lose_hollow()


func _lose_hollow() -> void:
	var h: Dictionary = d.hollow
	h.owner = "tharsis"
	h.unrest = 0
	h.ingots = 0
	h.raid_due = false
	h.since_raid = 0



# --- Shops, guns, the rover's hold ---

## What `shop` charges for `item` (-1: it doesn't sell it).
func shop_price(shop: String, item: String) -> int:
	var sells: Dictionary = SHOPS[shop].sells
	if not sells.has(item):
		return -1
	var friend: String = SHOPS[shop].get("friend", "")
	var off := FRIEND_GEAR_DISCOUNT if not friend.is_empty() and is_friend(friend) else 0.0
	return roundi(int(sells[item]) * (1.0 - off))


## Whether `shop` buys `item` from you, and for how much (0: it doesn't).
func shop_offer(shop: String, item: String) -> int:
	var buys: String = SHOPS[shop].buys
	if not sellable(item):
		return 0
	if is_weapon(item):
		return roundi(int(ITEMS[item].base) * WEAPON_RESALE) if buys in ["all", "weapons"] else 0
	return price(item) if buys == "all" else 0


func buy_at(shop: String, item: String) -> bool:
	var cost := shop_price(shop, item)
	if cost < 0 or d.wallet < cost:
		return false
	d.wallet -= cost
	receive(item, 1)
	return true


## Sells one `item` at `shop`; returns the money (0: no sale).
func sell_at(shop: String, item: String) -> int:
	var got := shop_offer(shop, item)
	if got <= 0 or int(d.stash.get(item, 0)) <= 0:
		return 0
	if not is_weapon(item):
		return sell(item, 1)
	_set_count(item, int(d.stash[item]) - 1)
	if d.armed == item and not d.stash.has(item):
		d.armed = ""  # sold the gun you carried: back to the issue rifle
	d.wallet += got
	d.earned += got
	return got


static func is_weapon(item: String) -> bool:
	return ITEMS.has(item) and ITEMS[item].has("weapon")


## Carry `item` as your primary (it must be in the pack; "" = the Pulse).
func equip(item: String) -> bool:
	if item != "" and (not is_weapon(item) or int(d.stash.get(item, 0)) <= 0):
		return false
	d.armed = item
	return true


## The equipped gun's Loadouts.PRIMARIES index (the Pulse if it's gone).
func primary_index() -> int:
	var item: String = d.armed
	if is_weapon(item) and int(d.stash.get(item, 0)) > 0:
		return int(ITEMS[item].weapon)
	return 0


## Goods into the pack (found, taken, bought).
func receive(item: String, n: int) -> void:
	if ITEMS.has(item) and n > 0:
		d.stash[item] = int(d.stash.get(item, 0)) + n


## The rover's hold <-> the pack, one stack's worth at a time.
func load_rover(item: String, n: int = 1) -> bool:
	var have: int = d.stash.get(item, 0)
	var cargo: Dictionary = d.rover_cargo
	if n <= 0 or have < n or (not cargo.has(item) and cargo.size() >= ride_slots()):
		return false
	if d.armed == item and have == n:
		d.armed = ""
	_set_count(item, have - n)
	cargo[item] = int(cargo.get(item, 0)) + n
	return true


func unload_rover(item: String, n: int = 1) -> bool:
	var cargo: Dictionary = d.rover_cargo
	var have: int = cargo.get(item, 0)
	if n <= 0 or have < n:
		return false
	if have == n:
		cargo.erase(item)
	else:
		cargo[item] = have - n
	receive(item, n)
	return true


# --- Your residence ---

## Pack -> locker (all of one item).
func store_home(item: String) -> bool:
	var have: int = d.stash.get(item, 0)
	var locker: Dictionary = d.home.locker
	if have <= 0 or (not locker.has(item) and locker.size() >= LOCKER_SLOTS):
		return false
	if d.armed == item:
		d.armed = ""
	d.stash.erase(item)
	locker[item] = int(locker.get(item, 0)) + have
	return true


func lock_cost() -> int:
	var next: int = int(d.home.lock) + 1
	return int(LOCKS[next].cost) if next < LOCKS.size() else -1


func upgrade_lock() -> bool:
	var cost := lock_cost()
	if cost < 0 or d.wallet < cost:
		return false
	d.wallet -= cost
	d.home.lock = int(d.home.lock) + 1
	return true


## While you were away: one try by thieves per BURGLARY_EVERY s since the
## last check (at most 3). `roll` (0..1 per try) beats the lock's resist:
## they take up to two stacks, half of each (rounded up). Returns what went.
func burglary(now: int, rolls: Array) -> Dictionary:
	var taken := {}
	var last: int = d.home.checked_at
	if last == 0:
		d.home.checked_at = now
		return taken
	var tries := mini((now - last) / BURGLARY_EVERY, 3)
	if tries <= 0:
		return taken
	d.home.checked_at = now
	var resist: float = LOCKS[int(d.home.lock)].resist
	var locker: Dictionary = d.home.locker
	for t in tries:
		var roll: float = rolls[t] if t < rolls.size() else 1.0
		if roll <= resist or locker.is_empty():
			continue
		var keys := locker.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(ITEMS[a].base) * int(locker[a]) > int(ITEMS[b].base) * int(locker[b]) if ITEMS.has(a) and ITEMS.has(b) else a < b)
		for item: String in keys.slice(0, 2):
			var n: int = int(ceil(int(locker[item]) / 2.0))
			locker[item] = int(locker[item]) - n
			if int(locker[item]) <= 0:
				locker.erase(item)
			taken[item] = int(taken.get(item, 0)) + n
	d.home.robbed = taken
	return taken


## Someone else's residence `id`, once the lock gives: what's inside (two
## picks from HOME_LOOT by `rolls`), or {} while it's still bare.
func break_in(id: String, rolls: Array, now: int) -> Dictionary:
	if loot_wait("home:" + id, now) > 0:
		return {}
	var looted: Dictionary = d.get("looted", {})
	looted["home:" + id] = now + BREAKIN_COOLDOWN
	d["looted"] = looted
	var total := 0.0
	for row: Array in HOME_LOOT:
		total += float(row[2])
	var out := {}
	for r: float in rolls:
		var pick := r * total
		for row: Array in HOME_LOOT:
			pick -= float(row[2])
			if pick <= 0.0:
				out[row[0]] = int(out.get(row[0], 0)) + int(row[1])
				break
	return out


# --- Tools and kit ---

## One `item` used from the pack (USE): true if you had one.
func use_up(item: String) -> bool:
	var have: int = d.stash.get(item, 0)
	if have <= 0:
		return false
	_set_count(item, have - 1)
	return true


## The break-in tool you'd reach for ("" = none): lockpicks before a crowbar.
func break_tool() -> String:
	for t: String in ["lockpick", "crowbar"]:
		if int(d.stash.get(t, 0)) > 0:
			return t
	return ""


## Wearing a mask (one in the pack): crimes cost one star less.
func masked() -> bool:
	return bool(d.get("masked", false)) and int(d.stash.get("mask", 0)) > 0


func set_masked(on: bool) -> bool:
	if on and int(d.stash.get("mask", 0)) <= 0:
		return false
	d["masked"] = on
	return true


# --- The garage ---

func respray_cost(stars: int) -> int:
	return RESPRAY_BASE + RESPRAY_PER_STAR * stars


func pay(amount: int) -> bool:
	if amount < 0 or d.wallet < amount:
		return false
	d.wallet -= amount
	return true


## Selling rover `id` to the chop shop (kind "concern" or "public"): the
## money, or 0 while that rover's still hot from the last one.
func chop(id: String, kind: String, now: int) -> int:
	if loot_wait("chop:" + id, now) > 0 or not CHOP_PRICE.has(kind):
		return 0
	var looted: Dictionary = d.get("looted", {})
	looted["chop:" + id] = now + CHOP_COOLDOWN
	d["looted"] = looted
	var got: int = CHOP_PRICE[kind]
	d.wallet += got
	d.earned += got
	return got


# --- Your ride (Kasei Motors) ---

## How many stacks your ride's hold takes (by model).
func ride_slots() -> int:
	return int(VehicleSim.MODELS[clampi(int(d.get("ride", 0)), 0, VehicleSim.MODELS.size() - 1)].slots)


## A new ride from the factory: its price less TRADE_IN for your old one.
## The hold's goods move over (what doesn't fit comes to your pack).
const TRADE_IN := 0.35


func ride_price(model: int) -> int:
	var old: int = VehicleSim.MODELS[clampi(int(d.get("ride", 0)), 0, VehicleSim.MODELS.size() - 1)].price
	return maxi(int(VehicleSim.MODELS[model].price) - roundi(old * TRADE_IN), 0)


func buy_ride(model: int) -> bool:
	if model < 0 or model >= VehicleSim.MODELS.size() or model == int(d.get("ride", 0)) or VehicleSim.flies(model):
		return false
	var cost := ride_price(model)
	if d.wallet < cost:
		return false
	d.wallet -= cost
	d["ride"] = model
	var cargo: Dictionary = d.rover_cargo
	while cargo.size() > ride_slots():  # too much for the new hold: into the pack
		var item: String = cargo.keys()[0]
		receive(item, int(cargo[item]))
		cargo.erase(item)
	return true


# --- Aircraft (Kasei Aero, at the Skyport) ----------------------------------

## Your aircraft (a VehicleSim model that flies), bought outright: a flight
## licence first. A second one trades the first in like a ride.
func buy_aircraft(model: int, now: int) -> bool:
	if not VehicleSim.flies(model) or model == int(d.get("aircraft", -1)) or not has_visa("flight", now):
		return false
	var cost := aircraft_price(model)
	if not pay(cost):
		return false
	d["aircraft"] = model
	return true


func aircraft_price(model: int) -> int:
	var old := int(d.get("aircraft", -1))
	var back := roundi(float(VehicleSim.MODELS[old].price) * TRADE_IN) if old >= 0 else 0
	return maxi(int(VehicleSim.MODELS[model].price) - back, 0)


# --- Visas and permits (the Immigration office in Tharsis Gate) -------------

## Papers the colony asks for: a flight licence to buy and fly aircraft;
## a Helios residency visa to stay in the Arcology (and live there); a work
## visa to run a business in the outlands. Each lasts so many sols.
const VISAS := {
	"flight": {"name": "Flight licence", "price": 650, "sols": 10},
	"helios": {"name": "Helios residency visa", "price": 420, "sols": 7},
	"work": {"name": "Outlands work visa", "price": 180, "sols": 5},
}


func visa_left(id: String, now: int) -> int:
	return maxi(int(d.visas.get(id, 0)) - now, 0)


func has_visa(id: String, now: int) -> bool:
	return visa_left(id, now) > 0


## Buys (or extends) a visa: VISAS[id].sols sols from now or its expiry.
func buy_visa(id: String, now: int) -> bool:
	if not VISAS.has(id) or not pay(int(VISAS[id].price)):
		return false
	d.visas[id] = maxi(int(d.visas.get(id, 0)), now) + int(VISAS[id].sols * GameClock.DAY_SECONDS)
	return true


# --- Property: rent or own (homes and businesses) ---------------------------

## Places you can rent by the sol or buy outright. Homes give you a bed (a
## checkpoint) and your locker; businesses pay you every sol. Some need a
## visa to take on. Where their doors are: WorldLayout.property_doors().
const PROPERTIES := {
	"helios_spire": {"name": "Helios Spire penthouse", "price": 48000, "rent": 900, "visa": "helios"},
	"helios_spire_2": {"name": "Spire Two apartment", "price": 30000, "rent": 600, "visa": "helios"},
	"helios_lens": {"name": "Lens Tower sky-deck flat", "price": 36000, "rent": 700, "visa": "helios"},
	"helios_arc": {"name": "Arc Towers bridge loft", "price": 42000, "rent": 800, "visa": "helios"},
	"helios_ring": {"name": "Ring habitat suite", "price": 55000, "rent": 1000, "visa": "helios"},
	"terrace_tower": {"name": "Terrace Tower flat", "price": 16000, "rent": 320},
	"skyport_office": {"name": "Skyport tower office", "price": 22000, "rent": 450, "income": 700, "visa": "work"},
	"galleria_unit_a": {"name": "Galleria shop unit A", "price": 26000, "rent": 520, "income": 820, "visa": "work"},
	"galleria_unit_b": {"name": "Galleria shop unit B", "price": 26000, "rent": 520, "income": 820, "visa": "work"},
}


## Whether `id` is yours now (owned, or rent paid up).
func has_property(id: String, now: int) -> bool:
	var p: Dictionary = d.property.get(id, {})
	return not p.is_empty() and (bool(p.get("own", false)) or int(p.get("paid_to", 0)) > now)


func property_owned(id: String) -> bool:
	return bool((d.property.get(id, {}) as Dictionary).get("own", false))


## Why you can't take `id` on ("" if you can).
func property_blocker(id: String, now: int) -> String:
	var info: Dictionary = PROPERTIES[id]
	if info.has("visa") and not has_visa(info.visa, now):
		return info.visa
	return ""


## Rents `id` for a sol (it renews itself every sol after: settle_property).
func rent_property(id: String, now: int) -> bool:
	if not PROPERTIES.has(id) or property_owned(id) or not property_blocker(id, now).is_empty():
		return false
	if not pay(int(PROPERTIES[id].rent)):
		return false
	var p: Dictionary = d.property.get(id, {"income_at": now})
	p["own"] = false
	p["paid_to"] = maxi(int(p.get("paid_to", 0)), now) + int(GameClock.DAY_SECONDS)
	d.property[id] = p
	return true


func buy_property(id: String, now: int) -> bool:
	if not PROPERTIES.has(id) or property_owned(id) or not property_blocker(id, now).is_empty():
		return false
	if not pay(int(PROPERTIES[id].price)):
		return false
	var p: Dictionary = d.property.get(id, {"income_at": now})
	p["own"] = true
	d.property[id] = p
	return true


## Every sol: rent comes out of your wallet (no money: you're out), and
## businesses you hold pay their takings. Returns what happened.
func settle_property(now: int) -> Dictionary:
	var out := {"rent": 0, "income": 0, "evicted": []}
	var day := int(GameClock.DAY_SECONDS)
	for id: String in d.property.keys():
		var p: Dictionary = d.property[id]
		var info: Dictionary = PROPERTIES.get(id, {})
		if info.is_empty():
			d.property.erase(id)
			continue
		if not bool(p.get("own", false)):
			while int(p.get("paid_to", 0)) <= now:
				if not pay(int(info.rent)):
					d.property.erase(id)
					out.evicted.append(id)
					break
				p["paid_to"] = int(p.get("paid_to", now)) + day
				out.rent += int(info.rent)
			if id in out.evicted:
				continue
		if info.has("income"):
			var since := int(p.get("income_at", now))
			var sols := (now - since) / day
			if sols > 0:
				var got := sols * int(info.income)
				d.wallet += got
				d.earned += got
				out.income += got
				p["income_at"] = since + sols * day
	return out


# --- The Red Dust Trade (the Ledger's line of work) -------------------------

## Red Dust and what it's cut with: each variant is one dose of dust mixed
## with one of an additive, worth more ("mult") to the clients who like it.
## Learned from Sable (TRADE_CHAIN step 2).
const DUST_BASE := 90
const VARIANTS := {
	"red_dust": {"with": "", "mult": 1.0},
	"dust_spark": {"with": "stim_cola", "mult": 1.4},
	"dust_frost": {"with": "water_ice", "mult": 1.6},
	"dust_float": {"with": "helium3", "mult": 1.8},
	"dust_bloom": {"with": "algae_culture", "mult": 2.1},
}
## The trade's people: [name, district, the variant they like best].
## Where they meet you: WorldLayout.client_spot(id).
const CLIENTS := {
	"lena": ["Lena V.", "galleria", "dust_frost"], "rook_jr": ["Rook Jr.", "city", "red_dust"],
	"mags": ["Mags", "hollow", "dust_spark"], "tobi": ["Tobi", "terrace", "dust_float"],
	"saoirse": ["Saoirse", "helios", "dust_bloom"], "dex": ["Dex", "skyport", "dust_frost"],
	"nadia": ["Nadia", "galleria", "dust_bloom"], "pike": ["Pike", "hollow", "red_dust"],
	"juno": ["Juno", "terrace", "dust_spark"], "ash": ["Ash", "helios", "dust_float"],
}
const FIRST_CLIENTS := ["rook_jr", "mags", "pike"]       ## Sable's introductions (step 1)
const TURF_CLIENTS := ["lena", "tobi", "saoirse", "dex", "nadia", "juno", "ash"]  ## after the turf (step 3)
const ORDER_EVERY := 150     ## seconds between new orders
const ORDER_TIME := 600      ## seconds to deliver one
const MAX_ORDERS := 3
const DEALER_CUT := 0.2      ## a dealer keeps a fifth
const DEALER_SALES := 6      ## doses a dealer moves in a sol
const DEALER_RISK := 0.12    ## chance a sol that they're robbed (half if armed)
## Sable's chain: 0 not started, 1 the first consignment (sell 4), 2 learn
## a cut (bring her 2 water ice), 3 the turf (beat the Blue Line crew at the
## Galleria), 4 done (dealers, all clients).
const CHAIN_SELL := 4


func trade() -> Dictionary:
	return d.trade


func dust_price(variant: String, client: String) -> int:
	var mult: float = VARIANTS[variant].mult
	var c: Dictionary = trade().clients.get(client, {})
	var loyal := float(c.get("loyalty", 0)) / 200.0
	var likes := 1.25 if CLIENTS.has(client) and CLIENTS[client][2] == variant else 1.0
	return roundi(DUST_BASE * mult * likes * (1.0 + loyal))


## Mixes `n` doses of a variant (dust + additive each). How many were made.
func mix(variant: String, n: int) -> int:
	if not VARIANTS.has(variant) or variant == "red_dust" or not variant in trade().learned:
		return 0
	var add: String = VARIANTS[variant].with
	var made := mini(n, mini(int(d.stash.get("red_dust", 0)), int(d.stash.get(add, 0))))
	for i in made:
		use_up("red_dust")
		use_up(add)
	if made > 0:
		receive(variant, made)
	return made


func meet_client(id: String) -> void:
	if CLIENTS.has(id) and not trade().clients.has(id):
		trade().clients[id] = {"loyalty": 10}


## A new order from a client who knows you (every ORDER_EVERY s, up to
## MAX_ORDERS open). `roll` picks who and what (0..1, the caller rolls).
func next_order(now: int, roll: float) -> Dictionary:
	var t := trade()
	if (t.clients as Dictionary).is_empty() or (t.orders as Array).size() >= MAX_ORDERS or now < int(t.order_at):
		return {}
	t.order_at = now + ORDER_EVERY - 25 * fame_tier()  # word gets round
	var ids: Array = t.clients.keys()
	var who: String = ids[int(roll * ids.size()) % ids.size()]
	for o: Dictionary in t.orders:
		if o.client == who:
			return {}
	var likes: String = CLIENTS[who][2]
	var variant := likes if likes in t.learned or likes == "red_dust" else "red_dust"
	var o := {"client": who, "variant": variant, "count": 1 + int(roll * 7.0) % 3, "due": now + ORDER_TIME}
	(t.orders as Array).append(o)
	return o


## Hands over order `i`: paid, and they like you more. 0 if you don't have it.
func deliver(i: int, now: int) -> int:
	var t := trade()
	if i < 0 or i >= (t.orders as Array).size():
		return 0
	var o: Dictionary = t.orders[i]
	if int(d.stash.get(o.variant, 0)) < int(o.count):
		return 0
	var pay := dust_price(o.variant, o.client) * int(o.count)
	_set_count(o.variant, int(d.stash.get(o.variant, 0)) - int(o.count))
	d.wallet += pay
	d.earned += pay
	var c: Dictionary = t.clients[o.client]
	c.loyalty = mini(int(c.loyalty) + (10 if now <= int(o.due) else 2), 100)
	t.sold = int(t.sold) + int(o.count)
	add_xp(20)
	(t.orders as Array).remove_at(i)
	_standing("ledger", 1)
	gang_respect(3)
	return pay


## Orders past due go cold (the client trusts you less). Returns how many.
func expire_orders(now: int) -> int:
	var t := trade()
	var gone := 0
	for i in range((t.orders as Array).size() - 1, -1, -1):
		var o: Dictionary = t.orders[i]
		if now > int(o.due):
			var c: Dictionary = t.clients.get(o.client, {})
			if not c.is_empty():
				c.loyalty = maxi(int(c.loyalty) - 15, 0)
			(t.orders as Array).remove_at(i)
			gone += 1
	return gone


## Sable's chain: what she asks, and whether you've done it.
func chain_step() -> int:
	return int(trade().chain)


func chain_advance(now: int) -> bool:
	var t := trade()
	match int(t.chain):
		0:  # she fronts you four doses and three names
			t.chain = 1
			receive("red_dust", CHAIN_SELL)
			for id: String in FIRST_CLIENTS:
				meet_client(id)
			t.order_at = now
			t.sold = 0
			return true
		1:
			if int(t.sold) < CHAIN_SELL:
				return false
			t.chain = 2
			return true
		2:  # two water ice cores and she shows you the cuts
			if int(d.stash.get("water_ice", 0)) < 2:
				return false
			use_up("water_ice")
			use_up("water_ice")
			t.learned = ["dust_spark", "dust_frost", "dust_float", "dust_bloom"]
			t.chain = 3
			return true
	return false


## The Blue Line crew's beaten at the Galleria: the corner's yours.
func won_turf() -> void:
	var t := trade()
	if int(t.chain) != 3:
		return
	t.chain = 4
	for id: String in TURF_CLIENTS:
		meet_client(id)
	_standing("ledger", 10)
	gang_respect(60)


## Dealers (from your gang's crew) sell in a district while you're away.
func set_dealer(district: String, who: String, now: int) -> bool:
	if chain_step() < 4 or not in_gang() or not who in d.gang.members:
		return false
	for k: String in trade().dealers:
		if trade().dealers[k].who == who:
			return false
	trade().dealers[district] = {"who": who, "stock": {}, "since": now, "armed": false}
	return true


## Hands a dealer `n` doses of `variant` from your pack.
func supply_dealer(district: String, variant: String, n: int) -> int:
	var dl: Dictionary = trade().dealers.get(district, {})
	if dl.is_empty():
		return 0
	var moved := mini(n, int(d.stash.get(variant, 0)))
	if moved > 0:
		_set_count(variant, int(d.stash.get(variant, 0)) - moved)
		dl.stock[variant] = int(dl.stock.get(variant, 0)) + moved
	return moved


func arm_dealer(district: String) -> bool:
	var dl: Dictionary = trade().dealers.get(district, {})
	if dl.is_empty() or bool(dl.armed) or not use_up("armour_plate"):
		return false
	dl.armed = true
	return true


## Every sol each dealer sells up to DEALER_SALES doses (you get the money
## less their cut), unless robbed (they lose the stock). `rolls` 0..1, one
## per dealer per sol (the caller rolls). Returns {"cash", "robbed": [district]}.
func settle_dealers(now: int, rolls: Array) -> Dictionary:
	var out := {"cash": 0, "robbed": []}
	var day := int(GameClock.DAY_SECONDS)
	var k := 0
	for district: String in trade().dealers:
		var dl: Dictionary = trade().dealers[district]
		var sols := (now - int(dl.since)) / day
		for i in sols:
			var roll: float = rolls[k % maxi(rolls.size(), 1)] if not rolls.is_empty() else 1.0
			k += 1
			if roll < DEALER_RISK * (0.5 if bool(dl.armed) else 1.0):
				dl.stock = {}
				out.robbed.append(district)
				continue
			var left := DEALER_SALES
			for variant: String in (dl.stock as Dictionary).keys():
				var n := mini(left, int(dl.stock[variant]))
				if n <= 0:
					continue
				var cash := roundi(DUST_BASE * float(VARIANTS[variant].mult) * n * (1.0 - DEALER_CUT))
				out.cash += cash
				left -= n
				dl.stock[variant] = int(dl.stock[variant]) - n
				if int(dl.stock[variant]) <= 0:
					dl.stock.erase(variant)
		if sols > 0:
			dl.since = int(dl.since) + sols * day
	d.wallet += int(out.cash)
	d.earned += int(out.cash)
	return out


## A Marshal's search: every dose you carry is taken, and a fine.
func confiscate() -> int:
	var n := 0
	for variant: String in VARIANTS:
		n += int(d.stash.get(variant, 0))
		d.stash.erase(variant)
	if n > 0:
		d.wallet = maxi(int(d.wallet) - SEARCH_FINE, 0)
	return n


func carrying_dust() -> bool:
	for variant: String in VARIANTS:
		if int(d.stash.get(variant, 0)) > 0:
			return true
	return false


# --- Cosmetics and the season (looks only: never power, never cash) ---------

## Suits (your colour), jetpack flames, rover paint, titles (on MarsNet),
## emotes (ArmoredRig.EMOTES). Some bought with your cash in the Style
## menu ("price"), some earned on the season track ("season": the tier).
const COSMETICS := {
	"suit_crimson": {"kind": "suit", "name": "Crimson suit", "color": Color(0.85, 0.12, 0.15), "price": 800},
	"suit_cobalt": {"kind": "suit", "name": "Cobalt suit", "color": Color(0.15, 0.35, 0.9), "price": 800},
	"suit_jade": {"kind": "suit", "name": "Jade suit", "color": Color(0.1, 0.7, 0.45), "price": 800},
	"suit_onyx": {"kind": "suit", "name": "Onyx suit", "color": Color(0.14, 0.14, 0.16), "season": 5},
	"suit_gold": {"kind": "suit", "name": "Gold suit", "color": Color(0.95, 0.75, 0.2), "season": 10},
	"flame_blue": {"kind": "flame", "name": "Blue flame", "color": Color(0.3, 0.6, 1.0), "price": 400},
	"flame_pink": {"kind": "flame", "name": "Pink flame", "color": Color(1.0, 0.3, 0.7), "price": 400},
	"flame_green": {"kind": "flame", "name": "Green flame", "color": Color(0.4, 1.0, 0.4), "season": 3},
	"paint_neon": {"kind": "paint", "name": "Neon paint", "color": Color(1.0, 0.25, 0.6), "price": 1200},
	"paint_sand": {"kind": "paint", "name": "Dune paint", "color": Color(0.95, 0.75, 0.5), "price": 900},
	"paint_chrome": {"kind": "paint", "name": "Chrome paint", "color": Color(0.8, 0.85, 0.95), "season": 15},
	"title_hunter": {"kind": "title", "name": "Bounty Hunter", "season": 2},
	"title_tycoon": {"kind": "title", "name": "Tycoon", "season": 12},
	"title_legend": {"kind": "title", "name": "Legend of Kasei", "season": 20},
	"emote_dance": {"kind": "emote", "name": "Dance", "clip": "Dance"},
	"emote_talk": {"kind": "emote", "name": "Chat", "clip": "Idle_Talking"},
	"emote_sit": {"kind": "emote", "name": "Sit", "clip": "Sitting_Idle", "season": 4},
	"emote_fix": {"kind": "emote", "name": "Tinker", "clip": "Fixing_Kneeling", "season": 7},
}
const SEASON_NAME := "Season 1: Dust & Glory"
const SEASON_TIERS := 20
const XP_PER_TIER := 250


func owns_cosmetic(id: String) -> bool:
	return id in d.cosmetics


func buy_cosmetic(id: String) -> bool:
	if not COSMETICS.has(id) or owns_cosmetic(id) or not COSMETICS[id].has("price") or not pay(int(COSMETICS[id].price)):
		return false
	(d.cosmetics as Array).append(id)
	return true


func equip_cosmetic(id: String) -> bool:
	if not owns_cosmetic(id):
		return false
	var kind: String = COSMETICS[id].kind
	if d.equipped.get(kind, "") == id:
		d.equipped.erase(kind)  # take it off
	else:
		d.equipped[kind] = id
	return true


## The equipped cosmetic of `kind` ("" for none).
func equipped(kind: String) -> String:
	return str(d.equipped.get(kind, ""))


func season_tier() -> int:
	return mini(int(d.season.xp) / XP_PER_TIER, SEASON_TIERS)


func add_xp(n: int) -> void:
	d.season.xp = int(d.season.xp) + maxi(n, 0)


## What tier `t` of the free track gives: a cosmetic, or cash.
func season_reward(t: int) -> Dictionary:
	for id: String in COSMETICS:
		if int(COSMETICS[id].get("season", -1)) == t:
			return {"cosmetic": id}
	return {"cash": 150 * t}


func claim_season(t: int) -> Dictionary:
	if t < 1 or t > season_tier() or t in d.season.claimed:
		return {}
	(d.season.claimed as Array).append(t)
	var r := season_reward(t)
	if r.has("cosmetic"):
		(d.cosmetics as Array).append(r.cosmetic)
	else:
		d.wallet += int(r.cash)
	return r


# --- MarsNet (the valley's feed) and fame ----------------------------------

const FEED_MAX := 40
## [fame needed, what people call you].
const FAME_TIERS := [[0, "Nobody"], [40, "Local name"], [150, "Talk of the valley"], [400, "MarsNet star"],
		[1000, "Legend of Kasei"]]


## A post on MarsNet (newest first). `fame`: what it does for yours.
func post(who: String, text: String, likes: int, now: int, fame: int = 0, img: String = "") -> void:
	var p := {"who": who, "text": text, "likes": likes, "at": now}
	if not img.is_empty():
		p["img"] = img
	(d.feed as Array).push_front(p)
	add_xp(fame * 15)
	while (d.feed as Array).size() > FEED_MAX:
		(d.feed as Array).pop_back()
	d.fame = maxi(int(d.fame) + fame, 0)


func fame_tier() -> int:
	var t := 0
	for i in FAME_TIERS.size():
		if int(d.fame) >= int(FAME_TIERS[i][0]):
			t = i
	return t


# --- A companion (MarsNet DMs: invites to hang out) --------------------------

## Someone you meet at the Galleria. They ask you out (a place, a time);
## turn up and stay a while and the bond grows, stand them up and it falls.
## At BOND_FIGHTS they fight beside you; at BOND_HOME they live with you.
const PARTNER := {"name": "Rhea Okoye", "role": "Skyport engineer"}
const BOND_FIGHTS := 40
const BOND_HOME := 75
const INVITE_EVERY := 420
const INVITE_TIME := 360
const HANGOUT_SECONDS := 20.0
const HANGOUTS := ["bar", "atrium", "helios", "skyport"]


func partner_met() -> bool:
	return not (d.partner as Dictionary).is_empty()


func meet_partner(now: int) -> void:
	if not partner_met():
		d.partner = {"bond": 10, "invite": {}, "invite_at": now + 120}


func bond() -> int:
	return int(d.partner.get("bond", 0))


## A new invite when it's time (`roll` 0..1 picks the place).
func next_invite(now: int, roll: float) -> Dictionary:
	if not partner_met() or not (d.partner.invite as Dictionary).is_empty() or now < int(d.partner.invite_at):
		return {}
	d.partner.invite = {"place": HANGOUTS[int(roll * HANGOUTS.size()) % HANGOUTS.size()], "due": now + INVITE_TIME}
	return d.partner.invite


## You turned up and stayed: the bond grows.
func hung_out(now: int) -> void:
	if not partner_met():
		return
	d.partner.bond = mini(bond() + 12, 100)
	d.partner.invite = {}
	d.partner.invite_at = now + INVITE_EVERY


## Stood up: it falls. True when an invite lapsed.
func invite_lapsed(now: int) -> bool:
	if not partner_met() or (d.partner.invite as Dictionary).is_empty() or now <= int(d.partner.invite.due):
		return false
	d.partner.bond = maxi(bond() - 8, 0)
	d.partner.invite = {}
	d.partner.invite_at = now + INVITE_EVERY
	return true


# --- Heists (planned at your gang's back room) ------------------------------

## A heist in stages: prep jobs out in the world, then the approach you
## choose (it changes the guards, what you need and when you can go), then
## the finale and the getaway. The take is split with your crew.
const HEISTS := {
	"ring": {"name": "The Helios Ring vault", "take": 32000, "preps": ["codes", "intel", "ride"]},
}
const HEIST_APPROACHES := {
	"quiet": {"guards": 3, "needs": "mask", "night": true, "mult": 1.15, "stars": 1},
	"loud": {"guards": 4, "needs": "armour_plate", "night": false, "mult": 1.0, "stars": 3},
	"con": {"guards": 2, "visa": "helios", "night": false, "mult": 1.05, "stars": 2},
}
const HEIST_COOLDOWN := 3600
const CREW_CUT := 0.08   ## each crew member's share


func heist() -> Dictionary:
	return d.heist


func heist_wait(id: String, now: int) -> int:
	return maxi(int(d.heists_done.get(id, 0)) + HEIST_COOLDOWN - now, 0)


func plan_heist(id: String, now: int) -> bool:
	if not HEISTS.has(id) or not heist().is_empty() or heist_wait(id, now) > 0:
		return false
	d.heist = {"id": id, "preps": [], "approach": "", "stage": "prep"}
	return true


func heist_prep(prep: String) -> bool:
	if heist().is_empty() or not prep in HEISTS[heist().id].preps or prep in heist().preps:
		return false
	(heist().preps as Array).append(prep)
	return true


func heist_ready() -> bool:
	return not heist().is_empty() and (heist().preps as Array).size() == (HEISTS[heist().id].preps as Array).size()


## Why you can't go with `approach` now ("" if you can).
func approach_blocker(approach: String, now: int, night: bool) -> String:
	var a: Dictionary = HEIST_APPROACHES[approach]
	if a.has("needs") and int(d.stash.get(a.needs, 0)) <= 0:
		return "item"
	if a.has("visa") and not has_visa(a.visa, now):
		return "visa"
	if bool(a.get("night", false)) and not night:
		return "night"
	return ""


func choose_approach(approach: String, now: int, night: bool) -> bool:
	if not heist_ready() or not HEIST_APPROACHES.has(approach) or not approach_blocker(approach, now, night).is_empty():
		return false
	heist().approach = approach
	heist().stage = "finale"
	return true


## The getaway's made with the bonds: the take, less the crew's shares.
func heist_payout(now: int) -> int:
	if heist().is_empty() or int(d.stash.get("ring_bonds", 0)) <= 0:
		return 0
	_set_count("ring_bonds", 0)
	var h: Dictionary = HEISTS[heist().id]
	var crew := (d.gang.get("members", []) as Array).size() if in_gang() else 0
	var take := roundi(float(h.take) * float(HEIST_APPROACHES[heist().approach].mult))
	var pay := roundi(take * maxf(1.0 - CREW_CUT * crew, 0.4))
	d.wallet += pay
	d.earned += pay
	d.heists_done[heist().id] = now
	d.heist = {}
	gang_respect(120)
	return pay


func abandon_heist() -> void:
	_set_count("ring_bonds", 0)
	d.heist = {}


# --- The Marshals' Bounty Board (free roam) --------------------------------

## Wanted outlaws of Kasei Valley. Each has a story, a hideout
## (WorldLayout.bounty_hideout) and a kind: a lone "gunman", one "guarded"
## by two, or a "crew" of three. Alive pays BOUNTY_ALIVE times the reward
## (hold them up: the Marshals collect); dead pays the reward against the
## proof from their body. A bounty comes back on the board after a while.
const BOUNTY_ALIVE := 1.6
const BOUNTY_COOLDOWN := 1800
const BOUNTIES := {
	"kroll": {"name": "Vesna Kroll", "kind": "gunman", "reward": 900,
			"crime": "Opened the Hollow refinery's valves: three dead in the fumes."},
	"orlov": {"name": "Dima \"Rust\" Orlov", "kind": "guarded", "reward": 1400,
			"crime": "Robbed the Concern's payroll hauler and burned it."},
	"amos": {"name": "Brother Amos", "kind": "crew", "reward": 2200,
			"crime": "Leads a cult that poisoned Deep Furrow's algae beds."},
	"vance": {"name": "Kemi Vance", "kind": "gunman", "reward": 1100,
			"crime": "Emptied Nova Terrace's water fund and fled with it."},
	"hex": {"name": "Hex", "kind": "guarded", "reward": 1600,
			"crime": "Ledger hacker: blacked out the Galleria's air curtains."},
	"marrow": {"name": "The Marrow Twins", "kind": "crew", "reward": 2600,
			"crime": "Ambush rovers on the outland roads and strip them."},
	"brandt": {"name": "Captain Ilse Brandt", "kind": "guarded", "reward": 2000,
			"crime": "Flew a stolen shuttle's cargo of medicine to the black market."},
	"jonah": {"name": "Old Jonah", "kind": "gunman", "reward": 800,
			"crime": "Killed a Marshal at a checkpoint and walked into the dust."},
}


func bounty_wait(id: String, now: int) -> int:
	return maxi(int(d.bounties_done.get(id, 0)) + BOUNTY_COOLDOWN - now, 0)


func take_bounty(id: String, now: int) -> bool:
	if not BOUNTIES.has(id) or not (d.bounty as Dictionary).is_empty() or bounty_wait(id, now) > 0:
		return false
	d.bounty = {"id": id, "since": now}
	return true


func drop_bounty() -> void:
	d.bounty = {}


## The bounty's paid: alive (held up, the Marshals take them) or dead
## (against the proof, which is handed over). Returns the pay (0: no claim).
func claim_bounty(alive: bool, now: int) -> int:
	if (d.bounty as Dictionary).is_empty():
		return 0
	var id: String = d.bounty.id
	if not alive:
		if int(d.stash.get("bounty_proof", 0)) <= 0:
			return 0
		use_up("bounty_proof")
	var pay := roundi(float(BOUNTIES[id].reward) * (BOUNTY_ALIVE if alive else 1.0))
	d.wallet += pay
	d.earned += pay
	d.bounties_done[id] = now
	d.bounty = {}
	_standing("kasei", 3)
	gang_respect(25 if alive else 15)
	return pay


# --- Your gang --------------------------------------------------------------

## A crew of your own: you name it, recruit people, and earn respect (jobs
## done, raids won, robberies, fights with the Marshals); respect lifts its
## rank, and a higher rank holds more members. Members walk with you in
## town and fight beside you when it comes to it.
const GANG_COST := 1500
const RECRUIT_COST := 250
## [rank name, respect needed, members it can hold].
const GANG_RANKS := [["Street crew", 0, 2], ["Runners", 100, 3], ["Enforcers", 300, 4], ["Syndicate", 700, 6],
		["Cartel", 1500, 8], ["Kingpins of Mars", 3000, 10]]
const RECRUITS := ["Zuri", "Dax", "Imani", "Kofi", "Rhea", "Tomas", "Lerato", "Yuki", "Bram", "Ola", "Nikolai", "Sade"]


func in_gang() -> bool:
	return not (d.gang as Dictionary).is_empty()


func form_gang(gang_name: String) -> bool:
	if in_gang() or gang_name.strip_edges().is_empty() or not pay(GANG_COST):
		return false
	d.gang = {"name": gang_name.strip_edges().left(24), "respect": 0, "members": []}
	return true


func gang_rank() -> int:
	var r := 0
	for i in GANG_RANKS.size():
		if int(d.gang.get("respect", 0)) >= int(GANG_RANKS[i][1]):
			r = i
	return r


func gang_slots() -> int:
	return int(GANG_RANKS[gang_rank()][2]) if in_gang() else 0


## Respect for the gang; returns true when it climbs a rank.
func gang_respect(amount: int) -> bool:
	if not in_gang():
		return false
	var before := gang_rank()
	d.gang.respect = maxi(int(d.gang.respect) + amount, 0)
	return gang_rank() > before


## Takes on the next recruit who isn't in already ("" if full or broke).
func recruit() -> String:
	if not in_gang() or (d.gang.members as Array).size() >= gang_slots():
		return ""
	for who: String in RECRUITS:
		if not who in d.gang.members:
			if not pay(RECRUIT_COST):
				return ""
			(d.gang.members as Array).append(who)
			return who
	return ""


func dismiss(who: String) -> bool:
	if not in_gang() or not who in d.gang.members:
		return false
	(d.gang.members as Array).erase(who)
	return true


func sellable(item: String) -> bool:
	return ITEMS.has(item) and not ITEMS[item].get("no_sale", false) and not ITEMS[item].get("contraband", false)


# --- Survival kit (oxygen, spares, fatigue) between places ---

## [oxygen, spare canisters, fatigue, water, water rations] for the next
## spawn (spares are the stash's canisters and rations: carried on you).
func kit() -> Array:
	return [float(d.oxygen), int(d.stash.get("oxygen_canister", 0)), float(d.fatigue), float(d.water),
			int(d.stash.get("water_ration", 0)), mini(int(d.stash.get("frag_grenade", 0)), GRENADES_MAX), float(d.food),
			int(d.stash.get("jetpack", 0)) > 0]


## What the suit held when leaving a place: the tank, spares used or taken.
func store_kit(oxygen: float, spares: int, fatigue: float, water: float = -1.0, rations: int = -1,
		grenades: int = -1, food: float = -1.0) -> void:
	if food >= 0.0:
		d.food = clampf(food, 0.0, 100.0)
	if grenades >= 0:
		_set_count("frag_grenade", grenades)
	d.oxygen = clampf(oxygen, 0.0, 100.0)
	d.fatigue = clampf(fatigue, 0.0, 100.0)
	_set_count("oxygen_canister", spares)
	if water >= 0.0:
		d.water = clampf(water, 0.0, 100.0)
	if rations >= 0:
		_set_count("water_ration", rations)


func _set_count(item: String, n: int) -> void:
	if n > 0:
		d.stash[item] = n
	else:
		d.stash.erase(item)


func buy(item: String, count: int = 1) -> bool:
	if not BUY.has(item) or count <= 0 or d.wallet < int(BUY[item]) * count:
		return false
	d.wallet -= int(BUY[item]) * count
	d.stash[item] = int(d.stash.get(item, 0)) + count
	return true


## Sleep in a bunk: fatigue gone.
func rest() -> void:
	d.fatigue = 0.0


# --- The lab ---

## Why `recipe` can't start now ("" = it can).
func lab_blocker(recipe: String) -> String:
	if not RECIPES.has(recipe):
		return "unknown"
	if not d.lab.is_empty():
		return "busy"
	var r: Dictionary = RECIPES[recipe]
	for item: String in r.inputs:
		if int(d.stash.get(item, 0)) < int(r.inputs[item]):
			return "inputs"
	if d.wallet < int(r.cash):
		return "money"
	return ""


func lab_start(recipe: String, now: int) -> bool:
	if not lab_blocker(recipe).is_empty():
		return false
	var r: Dictionary = RECIPES[recipe]
	for item: String in r.inputs:
		d.stash[item] = int(d.stash[item]) - int(r.inputs[item])
		if d.stash[item] <= 0:
			d.stash.erase(item)
	d.wallet -= int(r.cash)
	d.lab = {"output": r.output, "count": int(r.count), "ready_at": now + int(r.seconds)}
	return true


## Seconds until the batch is ready (0: ready; -1: nothing brewing).
func lab_left(now: int) -> int:
	return -1 if d.lab.is_empty() else maxi(int(d.lab.ready_at) - now, 0)


func lab_collect(now: int) -> int:
	if d.lab.is_empty() or now < int(d.lab.ready_at):
		return 0
	var n := int(d.lab.count)
	d.stash[d.lab.output] = int(d.stash.get(d.lab.output, 0)) + n
	d.lab = {}
	return n


# --- The black market ---

func sell_contraband(item: String = "red_dust") -> int:
	var n: int = d.stash.get(item, 0)
	if n <= 0:
		return 0
	d.stash.erase(item)
	var got := n * DEALER_PRICE
	d.wallet += got
	d.earned += got
	_standing("ledger", 2 * n)
	return got


## Entering the city with contraband: a search finds it with `roll` <
## SEARCH_CHANCE (the caller rolls). Returns what was confiscated.
func checkpoint(roll: float) -> int:
	var n: int = d.stash.get("red_dust", 0)
	if n <= 0 or roll >= SEARCH_CHANCE:
		return 0
	d.stash.erase("red_dust")
	d.wallet = maxi(d.wallet - SEARCH_FINE, 0)
	_standing("kasei", -5)
	return n


# --- Jobs ---

func job_available(job: String, now: int = -1) -> bool:
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	return JOBS.has(job) and d.job.is_empty() and now - int(d.jobs_done.get(job, -JOB_COOLDOWN)) >= JOB_COOLDOWN


func take_job(job: String) -> bool:
	if not job_available(job):
		return false
	d.job = {"id": job}
	if job == "courier":
		d.stash["parcel"] = 1
	return true


## The job's work is done at its place (wreck, crater, the Hollow's foreman).
func finish_job() -> Dictionary:
	if d.job.is_empty():
		return {}
	var job: String = d.job.id
	var j: Dictionary = JOBS[job]
	if job == "courier":
		if int(d.stash.get("parcel", 0)) <= 0:
			return {}
		d.stash.erase("parcel")
	for item: String in j.get("items", {}):
		d.stash[item] = int(d.stash.get(item, 0)) + int(j.items[item])
	d.wallet += int(j.pay)
	d.earned += int(j.pay)
	if j.has("trust"):
		_trust(j.trust, 4)
	d.jobs_done[job] = int(Time.get_unix_time_from_system())
	d.job = {}
	gang_respect(10)
	return {"job": job, "pay": int(j.pay)}


# --- Companions ---

## A friend comes with you on runs (fights at your side as a hired gun would).
func set_companion(who: String) -> bool:
	if who != "" and (not PEOPLE.has(who) or not is_friend(who)):
		return false
	d.companion = who
	return true



# --- Mining ---

## Seconds until rig `site` can run again (0: now).
func rig_wait(site: String, now: int) -> int:
	return maxi(int(d.get("mined", {}).get(site, 0)) - now, 0)


## A finished shift at a rig: its yield into the stash (double at the
## Hollow's rig when the Hollow is yours).
func mine(site: String, yields: Dictionary, now: int, cooldown: int) -> Dictionary:
	if rig_wait(site, now) > 0:
		return {}
	var mined: Dictionary = d.get("mined", {})
	mined[site] = now + cooldown
	d["mined"] = mined
	var out := {}
	var mult := 2 if site == "hollow_rig" and owns_hollow() else 1
	var drill := 1 if int(d.stash.get("hand_drill", 0)) > 0 else 0  # your own drill bites deeper
	for item: String in yields:
		var n := int(yields[item]) * mult + drill
		d.stash[item] = int(d.stash.get(item, 0)) + n
		out[item] = n
	return out



# --- Scavenging and theft ---

## Seconds until loot spot `id` has something again.
func loot_wait(id: String, now: int) -> int:
	return maxi(int(d.get("looted", {}).get(id, 0)) - now, 0)


## Search a crate or a building: `roll` (0..1) picks from `table`
## ([[item, count, weight], ...]); the spot refills after `cooldown` s.
func scavenge(id: String, table: Array, roll: float, now: int, cooldown: int) -> Dictionary:
	if loot_wait(id, now) > 0 or table.is_empty():
		return {}
	var looted: Dictionary = d.get("looted", {})
	looted[id] = now + cooldown
	d["looted"] = looted
	var total := 0.0
	for row: Array in table:
		total += float(row[2])
	var pick := roll * total
	for row: Array in table:
		pick -= float(row[2])
		if pick <= 0.0:
			d.stash[row[0]] = int(d.stash.get(row[0], 0)) + int(row[1])
			return {row[0]: int(row[1])}
	return {}


## Lifting algae cultures from Deep Furrow's oxygen beds (guards respond).
func steal_algae(n: int) -> void:
	d.stash["algae_culture"] = int(d.stash.get("algae_culture", 0)) + n


## Caught: the guards take back what you stole and fine you.
## Down while the Marshals were after you: a fine (a tenth of your money,
## at least SEARCH_FINE) and anything illegal or stolen confiscated.
func busted() -> int:
	var fine := mini(maxi(d.wallet / 10, SEARCH_FINE), d.wallet)
	d.wallet -= fine
	for item in ["red_dust", "algae_culture", "stolen_cargo"]:
		d.stash.erase(item)
	return fine


## The Concern's escort caught you at their supply rover: a fine, standing.
func caught_by_escort() -> void:
	d.wallet = maxi(d.wallet - SEARCH_FINE, 0)
	_standing("tharsis", -10)


func caught_stealing() -> void:
	d.stash.erase("algae_culture")
	d.wallet = maxi(d.wallet - SEARCH_FINE, 0)
	_trust("farmer", -15)
	_standing("kasei", -10)
