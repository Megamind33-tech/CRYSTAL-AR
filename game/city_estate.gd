class_name CityEstate
extends RefCounted
## Free roam's holdings and papers (with CityMode, which owns the prompts
## and menus): every tower's door (rent a flat, buy it, look around; its
## interior is deep under the valley), the Galleria units you can run as a
## business, the Immigration office (visas: a flight licence, Helios
## residency, a work visa), Kasei Aero at the Skyport (aircraft), your gang
## (form it, recruit, rank up on respect; the crew walks with you and fights
## beside you), and the trees you can fell with a plasma saw (timber; the
## city's trees are protected).

const DOOR_REACH := 2.6
const CUT_SECONDS := 3.5
const HELIOS_WARN := 20.0       ## seconds in Helios without a visa before a warning
const HELIOS_CALL := 45.0       ## ... before the Marshals are called
const GANG_NAMES := ["Tholin Kings", "Kraken Cartel", "Huygens Wolves", "Ontario Syndicate", "Shangri-La Vipers"]

var city: CityMode
var inside: Array = []          ## [property id, interior kind, the door to go back out to] or []
var flying: bool = false
var _cutting: String = ""       ## the tree being cut
var _cut_t: float = 0.0
var _settle_t: float = 0.0
var _helios_t: float = 0.0
var _helios_warned: bool = false
var _aircraft_checked: bool = false
var _stars_seen: int = 0
var _felled_shown := {}


func _init(p_city: CityMode) -> void:
	city = p_city


func _now() -> int:
	return int(Time.get_unix_time_from_system())


## Each frame: what's in reach (a key for CityMode's _near, or ""), and the
## running things (rent and takings, the Helios visa check, a tree being
## cut, felled trees, the crew, respect).
func update(me: SimPlayer, busy: bool) -> String:
	var c := Profile.career()
	var pos := me.state.position
	var dt := city.match_node.get_process_delta_time()
	if not inside.is_empty() and pos.y > WorldLayout.INTERIOR_Y + 100.0:
		inside = []  # out another way (a respawn)
	_ensure_aircraft(me)
	var model := me.state.vehicle_model if me.state.vehicle >= 0 else -1
	flying = model >= 0 and VehicleSim.flies(model)
	city.match_node.touch.flying = flying
	city.match_node.view.flying = flying
	# Rent due and takings, every few seconds.
	_settle_t -= dt
	if _settle_t <= 0.0:
		_settle_t = 5.0
		var got := c.settle_property(_now())
		if int(got.income) > 0 or int(got.rent) > 0 or not (got.evicted as Array).is_empty():
			Profile.save()
		if int(got.income) > 0:
			city._note(_t("ESTATE_INCOME") % int(got.income), ComicUI.GREEN)
		for id: String in got.evicted:
			city._note(_t("ESTATE_EVICTED") % Career.PROPERTIES[id].name, ComicUI.RED)
		_sync_trees()
	_step_helios(dt)
	_step_respect(c)
	if city._people != null:
		city._people.set_crew((c.d.gang.get("members", []) as Array) if c.in_gang() else [])
		city._people.crew_hidden = city._police != null or city._raid != null or city._guards != null or not inside.is_empty() \
				or me.state.vehicle >= 0
	# A tree under the saw.
	if not _cutting.is_empty():
		var tree := _tree(_cutting)
		if tree.is_empty() or pos.distance_to(tree[1]) > 3.2 or not me.state.alive or busy:
			_cutting = ""
		else:
			_cut_t += dt
			if _cut_t >= CUT_SECONDS:
				_fell(tree)
	if me.state.vehicle >= 0 or busy:
		return ""
	# Inside: the way out, your bed and locker.
	if not inside.is_empty():
		var kind: String = inside[1]
		var o: Vector3 = WorldLayout.INTERIORS[kind]
		if pos.distance_to(o + Vector3(0, 0, 5.2 if kind == "apartment" else 4.7)) < 1.4:
			return "estate:exit"
		if kind == "apartment" and pos.distance_to(o + Vector3(5.6, 0, -2.8)) < 2.0:
			return "estate:bed"
		var locker := o + (Vector3(7.3, 0, 3.6) if kind == "apartment" else Vector3(5.0, 0, 3.6))
		if pos.distance_to(locker) < 1.8:
			return "estate:locker"
		return ""
	for d: Array in WorldLayout.property_doors():
		if pos.distance_to(d[1]) < DOOR_REACH:
			return "estate:door:" + str(d[0])
	if pos.distance_to(WorldLayout.visa_office()) < 2.4:
		return "estate:visa"
	if pos.distance_to(WorldLayout.aero_counter()) < 2.4:
		return "estate:aero"
	if pos.distance_to(gang_spot()) < 2.4:
		return "estate:gang"
	if c.d.stash.get("cutter", 0) > 0 or not _cutting.is_empty():
		for t: Array in WorldLayout.trees():
			if not felled(str(t[0])) and Vector2(pos.x - (t[1] as Vector3).x, pos.z - (t[1] as Vector3).z).length() < 2.6:
				return "estate:tree:" + str(t[0])
	return ""


## Where you form and run your gang: the back room of the Dust Devil Saloon's
## yard in Dust Hollow (the Hollow's kind of place).
static func gang_spot() -> Vector3:
	return WorldTerrain.at(WorldLayout.HOLLOW.x + 22, WorldLayout.HOLLOW.z + 40) + Vector3(0, 0.1, 0)


func prompt(key: String) -> String:
	var c := Profile.career()
	var parts := key.split(":")
	match parts[1]:
		"exit":
			return _t("ESTATE_PROMPT_EXIT")
		"bed":
			return _t("CITY_PROMPT_SLEEP") if _yours() else _t("ESTATE_NOT_YOURS")
		"locker":
			return _t("CITY_PROMPT_LOCKER") if _yours() else _t("ESTATE_NOT_YOURS")
		"door":
			var id := parts[2]
			var info: Dictionary = Career.PROPERTIES[id]
			if c.has_property(id, _now()):
				return _t("ESTATE_PROMPT_HOME") % info.name
			return _t("ESTATE_PROMPT_DOOR") % info.name
		"visa":
			return _t("ESTATE_PROMPT_VISA")
		"aero":
			return _t("ESTATE_PROMPT_AERO")
		"gang":
			return _t("ESTATE_PROMPT_GANG")
		"tree":
			if _cutting == parts[2]:
				return _t("ESTATE_CUTTING") % roundi(_cut_t / CUT_SECONDS * 100.0)
			return _t("ESTATE_PROMPT_TREE")
	return ""


## Interact on `key` (CityMode calls this for "estate:..." keys).
func act(key: String, me: SimPlayer) -> void:
	var c := Profile.career()
	var parts := key.split(":")
	match parts[1]:
		"exit":
			var door: Vector3 = inside[2]
			inside = []
			city.match_node.server.world.teleport(me, door + Vector3(0, 0.2, 0))
		"bed":
			if _yours():
				c.rest()
				me.state.fatigue = 0.0
				Profile.save()
				city._note(_t("CITY_SLEPT"), ComicUI.CYAN)
		"locker":
			if _yours():
				city._open_shelf({"mode": "hold", "title": _t("SHELF_LOCKER"), "right": c.d.home.locker})
		"door":
			_door_menu(parts[2])
		"visa":
			city.open_menu(_t("VISA_OFFICE"), _visa_line(), _visa_options())
		"aero":
			city.open_menu(_t("AERO_NAME"), _aero_line(), _aero_options())
		"gang":
			city.open_menu(_t("GANG_TITLE"), _gang_line(), _gang_options())
		"tree":
			if _cutting.is_empty():
				_cutting = parts[2]
				_cut_t = 0.0


## A choice from one of the menus above ("estate:..." ids from GaragePanel).
func menu_act(what: String, me: SimPlayer) -> void:
	var c := Profile.career()
	var now := _now()
	var parts := what.split(":")
	match parts[0]:
		"enter":
			_enter(parts[1], me)
			return
		"rent":
			if c.rent_property(parts[1], now):
				city._flash_text(_t("ESTATE_RENTED") % Career.PROPERTIES[parts[1]].name, ComicUI.GREEN)
			city.garage.set_menu(_door_line(parts[1]), _door_options(parts[1]))
		"buy":
			if c.buy_property(parts[1], now):
				city._flash_text(_t("ESTATE_BOUGHT") % Career.PROPERTIES[parts[1]].name, ComicUI.GREEN)
				city.news("MARSNET_BOUGHT", [Career.PROPERTIES[parts[1]].name], 6)
			city.garage.set_menu(_door_line(parts[1]), _door_options(parts[1]))
		"visa":
			if c.buy_visa(parts[1], now):
				city._flash_text(_t("VISA_ISSUED") % Career.VISAS[parts[1]].name, ComicUI.GREEN)
			city.garage.set_menu(_visa_line(), _visa_options())
		"plane":
			var model := int(parts[1])
			if c.buy_aircraft(model, now):
				_place_aircraft(me, model)
				city.news("MARSNET_AIRCRAFT", [VehicleSim.MODELS[model].name], 5)
				city._flash_text(_t("AERO_BOUGHT") % VehicleSim.MODELS[model].name, ComicUI.GREEN)
			city.garage.set_menu(_aero_line(), _aero_options())
		"form":
			if c.form_gang(GANG_NAMES[int(parts[1])]):
				city._flash_text(_t("GANG_FORMED") % c.d.gang.name, ComicUI.MAGENTA)
			city.garage.set_menu(_gang_line(), _gang_options())
		"recruit":
			var who := c.recruit()
			if not who.is_empty():
				city._note(_t("GANG_RECRUITED") % who, ComicUI.MAGENTA)
			city.garage.set_menu(_gang_line(), _gang_options())
		"dismiss":
			c.dismiss(parts[1])
			city.garage.set_menu(_gang_line(), _gang_options())
	Profile.save()


func _yours() -> bool:
	return not inside.is_empty() and Profile.career().has_property(str(inside[0]), _now())


func _door(id: String) -> Array:
	for d: Array in WorldLayout.property_doors():
		if d[0] == id:
			return d
	return []


func _enter(id: String, me: SimPlayer) -> void:
	var d := _door(id)
	if d.is_empty() or str(d[2]).is_empty():
		return
	city.garage.visible = false
	city._close_talk()
	inside = [id, d[2], d[1]]
	city.match_node.server.world.teleport(me, WorldLayout.interior_exit(d[2]) + Vector3(0, 0, -1.6))
	var c := Profile.career()
	city._note(_t("ESTATE_WELCOME") % Career.PROPERTIES[id].name if c.has_property(id, _now()) else _t("ESTATE_VIEWING"),
			ComicUI.CYAN)


func _door_menu(id: String) -> void:
	city.open_menu(Career.PROPERTIES[id].name, _door_line(id), _door_options(id))


func _door_line(id: String) -> String:
	var c := Profile.career()
	var info: Dictionary = Career.PROPERTIES[id]
	var lines := PackedStringArray()
	if c.property_owned(id):
		lines.append(_t("ESTATE_OWNED"))
	elif c.has_property(id, _now()):
		lines.append(_t("ESTATE_RENTING") % int(info.rent))
	else:
		lines.append(_t("ESTATE_FOR_LET") % [int(info.rent), int(info.price)])
	if info.has("income"):
		lines.append(_t("ESTATE_BUSINESS") % int(info.income))
	var block := c.property_blocker(id, _now())
	if not block.is_empty() and not c.has_property(id, _now()):
		lines.append(_t("ESTATE_NEEDS_VISA") % Career.VISAS[block].name)
	lines.append(_t("ESTATE_WALLET") % int(c.d.wallet))
	return "\n".join(lines)


func _door_options(id: String) -> Array:
	var c := Profile.career()
	var info: Dictionary = Career.PROPERTIES[id]
	var now := _now()
	var out := []
	var d := _door(id)
	var has_inside := not d.is_empty() and not str(d[2]).is_empty()
	var mine := c.has_property(id, now)
	var free := c.property_blocker(id, now).is_empty()
	if has_inside:
		out.append([_t("ESTATE_GO_IN") if mine else _t("ESTATE_LOOK"), true, ComicUI.CYAN, "estate:enter:" + id])
	if not mine:
		out.append([_t("ESTATE_RENT") % int(info.rent), free and c.d.wallet >= int(info.rent), ComicUI.YELLOW, "estate:rent:" + id])
	if not c.property_owned(id):
		out.append([_t("ESTATE_BUY") % int(info.price), free and c.d.wallet >= int(info.price), ComicUI.GREEN, "estate:buy:" + id])
	return out


func _visa_line() -> String:
	var c := Profile.career()
	var lines := PackedStringArray([_t("VISA_LINE")])
	for id: String in Career.VISAS:
		var left := c.visa_left(id, _now())
		lines.append("%s: %s" % [Career.VISAS[id].name, _t("VISA_VALID") % ceili(left / GameClock.DAY_SECONDS) if left > 0
				else _t("VISA_NONE")])
	return "\n".join(lines)


func _visa_options() -> Array:
	var c := Profile.career()
	var out := []
	for id: String in Career.VISAS:
		var v: Dictionary = Career.VISAS[id]
		var key := "VISA_EXTEND" if c.has_visa(id, _now()) else "VISA_BUY"
		out.append([_t(key) % [v.name, int(v.price), int(v.sols)], c.d.wallet >= int(v.price), ComicUI.CYAN, "estate:visa:" + id])
	return out


func _aero_line() -> String:
	var c := Profile.career()
	var have := int(c.d.get("aircraft", -1))
	var line := _t("AERO_LINE") % (VehicleSim.MODELS[have].name if have >= 0 else _t("AERO_NONE"))
	if not c.has_visa("flight", _now()):
		line += "\n" + _t("AERO_NEED_LICENCE")
	return line


func _aero_options() -> Array:
	var c := Profile.career()
	var out := []
	var licensed := c.has_visa("flight", _now())
	for i in VehicleSim.MODELS.size():
		if not VehicleSim.flies(i):
			continue
		var m: Dictionary = VehicleSim.MODELS[i]
		if i == int(c.d.get("aircraft", -1)):
			out.append([_t("MOTORS_YOURS") % m.name, false, ComicUI.PAPER, "none"])
			continue
		var cost := c.aircraft_price(i)
		out.append([_t("AERO_BUY") % [m.name, roundi(float(m.max) * 3.6), cost], licensed and c.d.wallet >= cost, ComicUI.CYAN,
				"estate:plane:%d" % i])
	return out


## Your aircraft waits on its pad at the Skyport (added once, then it's
## where you left it this session).
func _ensure_aircraft(me: SimPlayer) -> void:
	if _aircraft_checked:
		return
	_aircraft_checked = true
	var model := int(Profile.career().d.get("aircraft", -1))
	if model >= 0:
		_place_aircraft(me, model)


func _place_aircraft(_me: SimPlayer, model: int) -> void:
	var world: SimWorld = city.match_node.server.world
	for v: SimVehicle in world.vehicles:
		if v.owner == ServerSession.LOCAL_PLAYER_ID and VehicleSim.flies(v.model):
			v.model = model
			return
	var spot := WorldLayout.aircraft_spot()
	var v := world.add_vehicle(spot[0], spot[1])
	v.owner = ServerSession.LOCAL_PLAYER_ID
	v.model = model


func _gang_line() -> String:
	var c := Profile.career()
	if not c.in_gang():
		return _t("GANG_NONE") % Career.GANG_COST
	var r := c.gang_rank()
	var next := _t("GANG_TOP") if r >= Career.GANG_RANKS.size() - 1 else _t("GANG_NEXT") % [int(Career.GANG_RANKS[r + 1][1]),
			Career.GANG_RANKS[r + 1][0]]
	return _t("GANG_LINE") % [c.d.gang.name, Career.GANG_RANKS[r][0], int(c.d.gang.respect), next,
			(c.d.gang.members as Array).size(), c.gang_slots()]


func _gang_options() -> Array:
	var c := Profile.career()
	var out := []
	if not c.in_gang():
		for i in GANG_NAMES.size():
			out.append([_t("GANG_FORM") % GANG_NAMES[i], c.d.wallet >= Career.GANG_COST, ComicUI.MAGENTA, "estate:form:%d" % i])
		return out
	var full := (c.d.gang.members as Array).size() >= c.gang_slots()
	out.append([_t("GANG_RECRUIT") % Career.RECRUIT_COST, not full and c.d.wallet >= Career.RECRUIT_COST, ComicUI.MAGENTA,
			"estate:recruit"])
	for who: String in c.d.gang.members:
		out.append([_t("GANG_DISMISS") % who, true, ComicUI.PAPER, "estate:dismiss:" + who])
	return out


## Respect: every crime, every escape from the Marshals (more for more
## stars); jobs add theirs in Career.finish_job. A new rank is news.
func _step_respect(c: Career) -> void:
	var stars := city.wanted.stars
	if stars == 0 and _stars_seen > 0 and Profile.career() == c:
		_respect(c, 12 * _stars_seen)  # got away
	_stars_seen = stars


func on_crime() -> void:
	_respect(Profile.career(), 5)


func _respect(c: Career, n: int) -> void:
	if not c.in_gang():
		return
	if c.gang_respect(n):
		city._flash_text(_t("GANG_RANK_UP") % [c.d.gang.name, Career.GANG_RANKS[c.gang_rank()][0]], ComicUI.MAGENTA)
		city.news("MARSNET_GANG_RANK", [c.d.gang.name, Career.GANG_RANKS[c.gang_rank()][0]], 8)
	Profile.save()


## Your crew in a fight: they come in as fighters on your side.
func crew_join(director: RaidDirector, me: SimPlayer) -> void:
	var c := Profile.career()
	if not c.in_gang():
		return
	var k := 0
	if c.partner_met() and c.bond() >= Career.BOND_FIGHTS:  # she has your back
		director.militia.append(director._bot(c.PARTNER.name, 0, true, me.state.position + Vector3(-2, 0.3, 2)))
	for who: String in c.d.gang.members:
		var a := k * 1.7
		var at := me.state.position + Vector3(cos(a), 0, sin(a)) * 3.0
		director.militia.append(director._bot(str(c.d.gang.name).get_slice(" ", 0) + "·" + who, 0, true,
				Vector3(at.x, WorldTerrain.surface(at.x, at.z), at.z) if inside.is_empty() else at))
		k += 1


## Helios is for residents: without the visa you're warned, then reported.
func _step_helios(dt: float) -> void:
	if city.region != "helios" or Profile.career().has_visa("helios", _now()):
		_helios_t = 0.0
		_helios_warned = false
		return
	_helios_t += dt
	if _helios_t > HELIOS_WARN and not _helios_warned:
		_helios_warned = true
		city._flash_text(_t("VISA_HELIOS_WARN"), ComicUI.YELLOW)
	if _helios_t > HELIOS_CALL:
		_helios_t = 0.0
		city.crime("trespass")


# --- trees ------------------------------------------------------------------

func felled(id: String) -> bool:
	return int((Profile.career().d.get("felled", {}) as Dictionary).get(id, 0)) > _now()


func _tree(id: String) -> Array:
	for t: Array in WorldLayout.trees():
		if t[0] == id:
			return t
	return []


func _fell(tree: Array) -> void:
	var c := Profile.career()
	_cutting = ""
	var f: Dictionary = c.d.get("felled", {})
	f[tree[0]] = _now() + WorldLayout.TREE_REGROW
	c.d["felled"] = f
	c.receive("timber", 2)
	Profile.save()
	city._note(_t("ESTATE_FELLED"), ComicUI.GREEN)
	if tree[2]:
		city.crime("vandalism")  # the city's trees are everyone's air
	var node := _tree_node(str(tree[0]))
	if node != null:
		var tw := node.create_tween()
		tw.tween_property(node, "rotation:x", node.rotation.x + 1.5, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: node.visible = false)
	_felled_shown[tree[0]] = true


var _tree_nodes := {}


func _tree_node(id: String) -> Node3D:
	if not _tree_nodes.has(id):
		var world_view := city.match_node.get_tree().root.find_child("Presentation", true, false)
		var found := (world_view if world_view != null else city.match_node.get_tree().root).find_child("Tree_" + id, true, false)
		_tree_nodes[id] = found
	return _tree_nodes[id] as Node3D


## Felled trees stay down until they've grown back.
func _sync_trees() -> void:
	for t: Array in WorldLayout.trees():
		var down := felled(str(t[0]))
		if down == bool(_felled_shown.get(t[0], false)):
			continue
		_felled_shown[t[0]] = down
		var node := _tree_node(str(t[0]))
		if node != null:
			node.visible = not down
			if not down:
				node.rotation.x = 0.0


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
