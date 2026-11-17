class_name CityTrade
extends RefCounted
## The Red Dust Trade (free roam, with CityMode): the Ledger's line of
## work, our own take on the drug-trade loop. Sable's chain starts it (a
## consignment and three names; then the cuts; then a corner taken from the
## Blue Line crew). Clients text orders: meet them where they say before the
## time runs out, hand it over, they pay (more if it's the cut they like,
## more as they come to trust you). Mix cuts at home. Your gang's crew can
## deal for you in the districts (a fifth for them, and they can be robbed).
## Carrying dust in town, a Marshal on the beat may stop you: stay and lose
## it (and a fine), or walk away fast (that's a crime).

const MEET_REACH := 3.0
const STOP_REACH := 6.0
const SEARCH_SECONDS := 3.0
const ESCAPE := 10.0
const TURF_REACH := 70.0
const DISTRICTS := ["hollow", "galleria", "terrace", "helios", "skyport"]

var city: CityMode
var turf: RaidDirector
var _tick_t: float = 0.0
var _search_t: float = 0.0
var _searcher: Array = []        ## [visual, state] of the Marshal searching you
var _stop_cool: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_city: CityMode) -> void:
	city = p_city
	_rng.randomize()


func _now() -> int:
	return int(Time.get_unix_time_from_system())


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


func fighters() -> Array[int]:
	var out: Array[int] = []
	if turf != null:
		out.append_array(turf.raiders)
	return out


func in_fight() -> bool:
	return turf != null


func update(me: SimPlayer, busy: bool) -> String:
	var c := Profile.career()
	var pos := me.state.position
	var dt := city.match_node.get_process_delta_time()
	_tick_t -= dt
	if _tick_t <= 0.0:
		_tick_t = 2.0
		_step_orders(c)
	_step_search(me, c, dt)
	_step_turf(me, c)
	if busy or me.state.vehicle >= 0:
		return ""
	if pos.distance_to(WorldLayout.ledger_drop()) < 2.6:
		return "trade:sable"
	var orders: Array = c.trade().orders
	for i in orders.size():
		if pos.distance_to(WorldLayout.client_spot(orders[i].client)) < MEET_REACH:
			return "trade:deliver:%d" % i
	return ""


## New orders come in, old ones go cold, dealers report; the clients who
## are waiting stand at their spots.
func _step_orders(c: Career) -> void:
	var now := _now()
	if c.chain_step() >= 1:
		var o := c.next_order(now, _rng.randf())
		if not o.is_empty():
			city._note(_t("TRADE_ORDER") % [Career.CLIENTS[o.client][0], int(o.count), Career.ITEMS[o.variant].name,
					_t("MAP_" + str(Career.CLIENTS[o.client][1]).to_upper()) if str(Career.CLIENTS[o.client][1]) != "city"
					else _t("MAP_CITY")], ComicUI.MAGENTA)
			Profile.save()
		if c.expire_orders(now) > 0:
			city._note(_t("TRADE_ORDER_COLD"), ComicUI.YELLOW)
			Profile.save()
	if not (c.trade().dealers as Dictionary).is_empty():
		var rolls := []
		for i in 8:
			rolls.append(_rng.randf())
		var got := c.settle_dealers(now, rolls)
		if int(got.cash) > 0:
			city._note(_t("TRADE_DEALERS_PAID") % int(got.cash), ComicUI.GREEN)
		for district: String in got.robbed:
			city._note(_t("TRADE_DEALER_ROBBED") % _t("MAP_" + district.to_upper()), ComicUI.RED)
		if int(got.cash) > 0 or not (got.robbed as Array).is_empty():
			Profile.save()
	if city._people == null:
		return
	var waiting := {}
	for o: Dictionary in c.trade().orders:
		waiting["client:" + str(o.client)] = true
		city._people.meet("client:" + str(o.client), Career.CLIENTS[o.client][0], WorldLayout.client_spot(o.client))
	for key: String in city._people._meets.keys():
		if key.begins_with("client:") and not waiting.has(key):
			city._people.unmeet(key)


## Searches, one compartment at a time: a SALTS officer on the beat stops
## you on foot and searches your pack; the gatehouse inspects a vehicle's
## hold as it comes through. Neither touches the other compartment.
func _step_search(me: SimPlayer, c: Career, dt: float) -> void:
	_stop_cool = maxf(_stop_cool - dt, 0.0)
	if _step_inspection(me, c, dt):
		return
	if not _searcher.is_empty():
		_search_t -= dt
		var st: PlayerSimState = _searcher[1]
		var d := st.position.distance_to(me.state.position)
		if d > ESCAPE:
			_searcher = []
			city._flash_text(_t("TRADE_RAN"), ComicUI.RED)
			city.crime("evading")
		elif _search_t <= 0.0:
			_searcher = []
			var n := c.confiscate()
			Profile.save()
			if n > 0:
				city._flash_text(_t("TRADE_CONFISCATED") % [n, Career.SEARCH_FINE], ComicUI.RED)
		return
	if _stop_cool > 0.0 or city._people == null or not c.carrying_dust() or not city.region in WorldLayout.LAWFUL \
			or me.state.vehicle >= 0 or city.in_fight():
		return
	for m: Array in city._people.marshals:
		var st: PlayerSimState = m[1]
		if (m[0] as Node3D).visible and st.position.distance_to(me.state.position) < STOP_REACH:
			_stop_cool = 60.0
			if _rng.randf() < 0.45:
				_searcher = m
				_search_t = SEARCH_SECONDS
				city._people.say(m[0], CityNpcs._line("TRADE_STOP"), true)
				city._flash_text(_t("TRADE_STOPPED"), ComicUI.YELLOW)
			return


## The gatehouse's vehicle inspection: driving through the hall with dust
## in the hold, you're waved down; stay stopped INSPECT_SECONDS while they
## search the hold (your pack isn't searched); drive off and you're evading.
const INSPECT_SECONDS := 4.0
var _inspect_t: float = -1.0
var _inspected_cool: float = 0.0


func _step_inspection(me: SimPlayer, c: Career, dt: float) -> bool:
	_inspected_cool = maxf(_inspected_cool - dt, 0.0)
	var gate := TitanSettlement.piece("titan/gatehouse")
	if gate.is_empty():
		return false
	var in_hall := me.state.vehicle >= 0 and absf(me.state.position.x - (gate[1] as Vector3).x) < 4.0 \
			and absf(me.state.position.z - (gate[1] as Vector3).z) < 5.0
	if _inspect_t >= 0.0:
		if me.state.vehicle < 0 or absf(me.state.vehicle_speed) > 3.0 and not in_hall:
			_inspect_t = -1.0
			city._flash_text(_t("TRADE_RAN"), ComicUI.RED)
			city.crime("evading")
			return true
		_inspect_t -= dt
		if _inspect_t <= 0.0:
			_inspect_t = -1.0
			_inspected_cool = 90.0
			var n := c.confiscate_hold()
			Profile.save()
			city._flash_text(_t("TITAN_HOLD_SEIZED") % [n, Career.SEARCH_FINE] if n > 0 else _t("TITAN_HOLD_CLEAR"),
					ComicUI.RED if n > 0 else ComicUI.GREEN)
		return true
	if in_hall and _inspected_cool <= 0.0 and c.hold_has_dust():
		_inspect_t = INSPECT_SECONDS
		city._flash_text(_t("TITAN_INSPECTION"), ComicUI.YELLOW)
		return true
	return false


## Step 3 of Sable's chain: the Blue Line crew holds the Galleria corner.
func _step_turf(me: SimPlayer, c: Career) -> void:
	if c.chain_step() != 3:
		if turf != null:
			turf.finish()
			turf = null
			city._sync_combat()
		return
	if turf == null and me.state.position.distance_to(WorldLayout.turf_spot()) < TURF_REACH:
		var at := WorldLayout.turf_spot()
		city._bake_around(at)
		turf = RaidDirector.new(city.match_node.server)
		turf.start_guards(me.net_id, [at + Vector3(0, 0.3, 0), at + Vector3(4, 0.3, 3), at + Vector3(-4, 0.3, 2)],
				"raider", "BlueLine·%d")
		city._flash_text(_t("TRADE_TURF_FIGHT"), ComicUI.RED)
		city._sync_combat()
		return
	if turf == null:
		return
	var state := turf.step()
	if state == 1:
		turf.finish()
		turf = null
		c.won_turf()
		Profile.save()
		city._flash_text(_t("TRADE_TURF_WON"), ComicUI.GREEN)
		city.news("MARSNET_TURF", [], 10)
		city._sync_combat()
	elif state == 2:
		turf.finish()
		turf = null
		city._sync_combat()


func prompt(key: String) -> String:
	if key == "trade:sable":
		return _t("TRADE_PROMPT_SABLE")
	if key.begins_with("trade:deliver:"):
		var orders: Array = Profile.career().trade().orders
		var i := int(key.get_slice(":", 2))
		if i >= orders.size():
			return ""
		var o: Dictionary = orders[i]
		return _t("TRADE_PROMPT_DELIVER") % [int(o.count), Career.ITEMS[o.variant].name, Career.CLIENTS[o.client][0]]
	return ""


func act(key: String, _me: SimPlayer) -> void:
	var c := Profile.career()
	if key == "trade:sable":
		city.open_menu(_t("TRADE_SABLE"), _sable_line(), _sable_options())
		return
	if key.begins_with("trade:deliver:"):
		var i := int(key.get_slice(":", 2))
		if i >= (c.trade().orders as Array).size():
			return
		var o: Dictionary = c.trade().orders[i]
		var who: String = Career.CLIENTS[o.client][0]
		var pay := c.deliver(i, _now())
		if pay > 0:
			Profile.save()
			city._flash_text(_t("TRADE_DELIVERED") % [who, pay], ComicUI.GREEN)
			var v := city._people.meet_visual("client:" + str(o.client)) if city._people != null else null
			if v != null:
				city._people.say(v, CityNpcs._line("TRADE_THANKS"), true)  # they leave on the next round
		else:
			city._note(_t("TRADE_SHORT") % [int(o.count), Career.ITEMS[o.variant].name], ComicUI.YELLOW)


func _sable_line() -> String:
	var c := Profile.career()
	return _t("TRADE_CHAIN_%d" % c.chain_step()) % (Career.CHAIN_SELL - mini(int(c.trade().sold), Career.CHAIN_SELL)) \
			if c.chain_step() == 1 else _t("TRADE_CHAIN_%d" % c.chain_step())


func _sable_options() -> Array:
	var c := Profile.career()
	var out := []
	match c.chain_step():
		0:
			out.append([_t("TRADE_TAKE_WORK"), true, ComicUI.MAGENTA, "trade:advance"])
		1:
			out.append([_t("TRADE_SOLD_THEM"), int(c.trade().sold) >= Career.CHAIN_SELL, ComicUI.MAGENTA, "trade:advance"])
		2:
			out.append([_t("TRADE_BRING_ICE"), int(c.d.stash.get("water_ice", 0)) >= 2, ComicUI.MAGENTA, "trade:advance"])
	if c.chain_step() >= 1:
		out.append([_t("TRADE_BUY_DUST") % (Career.DUST_BASE / 2 * 5), c.d.wallet >= Career.DUST_BASE / 2 * 5, ComicUI.YELLOW,
				"trade:buy"])
	return out


## The burner: orders, cuts to mix (at home), dealers.
func open_burner() -> void:
	city.open_menu(_t("TRADE_BURNER"), _burner_line(), _burner_options())


func _burner_line() -> String:
	var c := Profile.career()
	var lines := PackedStringArray()
	var now := _now()
	for o: Dictionary in c.trade().orders:
		var region := str(Career.CLIENTS[o.client][1])
		lines.append(_t("TRADE_ORDER_LINE") % [Career.CLIENTS[o.client][0], int(o.count), Career.ITEMS[o.variant].name,
				_t("MAP_" + region.to_upper()), maxi(ceili((int(o.due) - now) / 60.0), 0)])
	if lines.is_empty():
		lines.append(_t("TRADE_NO_ORDERS"))
	var stock := PackedStringArray()
	for v: String in Career.VARIANTS:
		if int(c.d.stash.get(v, 0)) > 0:
			stock.append("%d× %s" % [int(c.d.stash[v]), Career.ITEMS[v].name])
	lines.append(_t("TRADE_CARRYING") % (", ".join(stock) if not stock.is_empty() else _t("TRADE_NOTHING")))
	for district: String in c.trade().dealers:
		var dl: Dictionary = c.trade().dealers[district]
		var n := 0
		for v: String in dl.stock:
			n += int(dl.stock[v])
		lines.append(_t("TRADE_DEALER_LINE") % [dl.who, _t("MAP_" + district.to_upper()), n, _t("TRADE_ARMED") if dl.armed else ""])
	return "\n".join(lines)


func _at_home() -> bool:
	var me: SimPlayer = city.match_node.server.world.get_player(ServerSession.LOCAL_PLAYER_ID)
	if me == null:
		return false
	if city.estate != null and city.estate._yours():
		return true
	return me.state.position.distance_to(WorldLayout.residences()[0][1]) < 5.0


func _burner_options() -> Array:
	var c := Profile.career()
	var out := []
	var home := _at_home()
	for v: String in c.trade().learned:
		var add: String = Career.VARIANTS[v].with
		var can := mini(int(c.d.stash.get("red_dust", 0)), int(c.d.stash.get(add, 0)))
		out.append([_t("TRADE_MIX") % [Career.ITEMS[v].name, Career.ITEMS[add].name, can] + ("" if home else _t("TRADE_MIX_HOME")),
				home and can > 0, ComicUI.CYAN, "trade:mix:" + v])
	if c.chain_step() >= 4 and c.in_gang():
		for district: String in DISTRICTS:
			if c.trade().dealers.has(district):
				out.append([_t("TRADE_RESTOCK") % _t("MAP_" + district.to_upper()), c.carrying_dust(), ComicUI.GREEN,
						"trade:restock:" + district])
				if not bool(c.trade().dealers[district].armed):
					out.append([_t("TRADE_ARM") % _t("MAP_" + district.to_upper()), int(c.d.stash.get("armour_plate", 0)) > 0,
							ComicUI.YELLOW, "trade:arm:" + district])
			else:
				var free := _free_member(c)
				out.append([_t("TRADE_STATION") % [free if not free.is_empty() else "—", _t("MAP_" + district.to_upper())],
						not free.is_empty(), ComicUI.MAGENTA, "trade:station:" + district])
	return out


func _free_member(c: Career) -> String:
	for who: String in c.d.gang.get("members", []):
		var busy := false
		for k: String in c.trade().dealers:
			if c.trade().dealers[k].who == who:
				busy = true
		if not busy:
			return who
	return ""


func menu_act(what: String) -> void:
	var c := Profile.career()
	var parts := what.split(":")
	var now := _now()
	match parts[0]:
		"advance":
			if c.chain_advance(now):
				city._flash_text(_t("TRADE_CHAIN_DONE_%d" % c.chain_step()), ComicUI.MAGENTA)
			city.garage.set_menu(_sable_line(), _sable_options())
		"buy":
			if c.pay(Career.DUST_BASE / 2 * 5):
				c.receive("red_dust", 5)
			city.garage.set_menu(_sable_line(), _sable_options())
		"mix":
			var made := c.mix(parts[1], 99)
			if made > 0:
				city._note(_t("TRADE_MIXED") % [made, Career.ITEMS[parts[1]].name], ComicUI.CYAN)
			city.garage.set_menu(_burner_line(), _burner_options())
		"station":
			c.set_dealer(parts[1], _free_member(c), now)
			city.garage.set_menu(_burner_line(), _burner_options())
		"restock":
			for v: String in Career.VARIANTS:
				c.supply_dealer(parts[1], v, int(c.d.stash.get(v, 0)))
			city.garage.set_menu(_burner_line(), _burner_options())
		"arm":
			c.arm_dealer(parts[1])
			city.garage.set_menu(_burner_line(), _burner_options())
	Profile.save()


## Clients waiting (and the corner, when it's time) on the minimap.
func map_places() -> Array:
	var out := []
	for o: Dictionary in Profile.career().trade().orders:
		out.append([WorldLayout.client_spot(o.client), "$", ComicUI.MAGENTA])
	if Profile.career().chain_step() == 3:
		out.append([WorldLayout.turf_spot(), "!", ComicUI.RED])
	return out
