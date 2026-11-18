class_name CityVenues
extends RefCounted
## Free roam's newer venues (with CityMode, which owns the prompts and the
## interact button): the Land Office desk on the plaza (LandOffice: plots
## out in the flats, building, bot tenants paying rent every sol), the Pit
## under the Red Lantern (FightClub: bets and your own bout), and the ruby
## cutter's bench at the trading post (cut raw rubies, sell a vault relic).
## Keys for CityMode's _near: "venue:land", "venue:pit", "venue:cutter".

const REACH := 2.4
const SETTLE_EVERY := 5.0  ## seconds between rent settles

var city: CityMode
var land_panel: LandOfficePanel
var pit_panel: FightClubPanel
var club: FightClub
var _club_day: int = -1
var _settle_t: float = 0.0
var _plots_root: Node3D
var _plots_body: StaticBody3D
var _placed := {}  ## plot id -> the building node shown
var allies := {}   ## person id -> net id of their body walking with you
var _ally_t: float = 0.0
var _ally_down := {}  ## person id -> unix time they're back on their feet


func _init(p_city: CityMode) -> void:
	city = p_city
	var ui_parent: Node = city.hud_layer.get_parent()
	land_panel = LandOfficePanel.new()
	land_panel.visible = false
	ui_parent.add_child(land_panel)
	land_panel.closed.connect(_closed)
	land_panel.changed.connect(func() -> void:
		Profile.save()
		_place_buildings())
	pit_panel = FightClubPanel.new()
	pit_panel.visible = false
	ui_parent.add_child(pit_panel)
	pit_panel.closed.connect(_closed)
	pit_panel.bet.connect(_on_bet)
	pit_panel.watch.connect(_on_watch)
	pit_panel.enter_ring.connect(_on_ring)
	_plots_root = Node3D.new()
	_plots_root.name = "LandPlots"
	city.match_node.add_child(_plots_root)
	_plots_body = StaticBody3D.new()
	_plots_root.add_child(_plots_body)
	_sign(land_desk(), tr("LAND_SIGN"), ComicUI.GREEN)
	_sign(pit_stairs(), tr("PIT_SIGN"), ComicUI.RED)
	_sign(cutter_bench(), tr("CUTTER_SIGN"), ComicUI.MAGENTA)
	for id: String in LandOffice.PLOTS:
		var post := LandOffice.ground(id) + Vector3(0, 6, 0)
		_sign(post, tr("LAND_PLOT_SIGN") % id.to_upper(), ComicUI.CYAN, 120)
	_place_buildings()


static func _beside_shop(i: int, side: float) -> Vector3:
	var s: Array = WorldLayout.shops()[i]
	return (s[1] as Vector3) + Basis(Vector3.UP, float(s[3]) - PI) * Vector3(side, 0, 0)


## The Land Office desk: on the plaza beside the trading post's door.
static func land_desk() -> Vector3:
	return _beside_shop(6, 3.2)


## The stairs down to the Pit: beside the Red Lantern's door.
static func pit_stairs() -> Vector3:
	return _beside_shop(5, -3.0)


## The ruby cutter's bench: the trading post's other side.
static func cutter_bench() -> Vector3:
	return _beside_shop(6, -3.2)


func busy() -> bool:
	return land_panel.visible or pit_panel.visible


func land_state() -> Dictionary:
	var d: Dictionary = Profile.career().d
	if not d.land is Dictionary or not d.land.has("plots"):
		d.land = LandOffice.new_state()
	return d.land


func _now() -> int:
	return int(Time.get_unix_time_from_system())


## Each frame: rent comes in, and what's in reach ("" or a venue key).
func update(me: SimPlayer, delta: float, panels_open: bool) -> String:
	_settle_t += delta
	if _settle_t >= SETTLE_EVERY:
		_settle_t = 0.0
		var out := LandOffice.settle(land_state(), Profile.career().d, _now())
		for m: Array in out.moved_in:
			city._note(tr("LAND_TENANT_IN") % [m[1], str(m[0]).to_upper()], ComicUI.GREEN)
		if int(out.income) > 0 or int(out.upkeep) > 0:
			city._note(tr("LAND_RENT") % [int(out.income), int(out.upkeep)], ComicUI.YELLOW)
			Profile.save()
		_place_buildings()
	_ally_t += delta
	if _ally_t >= 1.0:
		_ally_t = 0.0
		step_allies(me)
	if panels_open or me.state.vehicle >= 0:
		return ""
	var pos := me.state.position
	if pos.distance_to(land_desk()) < REACH:
		return "venue:land"
	if pos.distance_to(pit_stairs()) < REACH:
		return "venue:pit"
	if pos.distance_to(cutter_bench()) < REACH:
		return "venue:cutter"
	return ""


func prompt(key: String) -> String:
	match key:
		"venue:land": return tr("LAND_PROMPT")
		"venue:pit": return tr("PIT_PROMPT")
		"venue:cutter": return tr("CUTTER_PROMPT")
	return ""


func act(key: String, _me: SimPlayer) -> void:
	match key:
		"venue:land":
			land_panel.open(land_state(), Profile.career().d, _now())
			_lock()
		"venue:pit":
			var day := int(_now() / GameClock.DAY_SECONDS)
			if club == null or day != _club_day:
				club = FightClub.new(day)
				_club_day = day
			pit_panel.open(club, int(Profile.career().d.wallet))
			_lock()
		"venue:cutter":
			cut_and_sell()


## Who walks with you: allies won in talk (Conversation) and your companion.
func wanted_allies() -> Array:
	var out: Array = TalkPanel.conversation().allies()
	var comp := str(Profile.career().d.get("companion", ""))
	if not comp.is_empty() and not out.has(comp):
		out.append(comp)
	return out.slice(0, Conversation.ALLY_MAX)


## Allies are bodies in the sim with a MercBrain: they follow a few metres
## behind and fight whoever hurts you. Dismissed or dead: they're gone.
func step_allies(me: SimPlayer) -> void:
	var server: ServerSession = city.match_node.server
	if server == null or server.bot_nav == null:
		return
	var want := wanted_allies() if me.state.alive and city.region != "interior" else []
	for who: String in allies.keys():
		var p: SimPlayer = server.world.players.get(allies[who])
		if not want.has(who) or p == null or not p.state.alive:
			if p != null and not p.state.alive:
				_ally_down[who] = _now() + 120  # patched up in a couple of minutes
			if p != null:
				server.remove_bot(int(allies[who]))
			allies.erase(who)
	for who: String in want:
		if allies.has(who) or not Career.PEOPLE.has(who) or int(_ally_down.get(who, 0)) > _now():
			continue
		var id := 1000 + server._bot_seq
		var brain := MercBrain.ally(server.world, server.bot_nav, id, server._rng.randi(), me.net_id)
		var p := server.add_bot(str(Career.PEOPLE[who].name), brain)
		p.team = me.team
		var at := me.state.position + Vector3(-2.5 - allies.size() * 1.5, 0.3, 2.5)
		server.world.teleport(p, at)
		allies[who] = p.net_id


## The cutter's bench: every raw ruby cut, a vault relic sold for rubies.
func cut_and_sell() -> Dictionary:
	var c := Profile.career()
	var cut := c.cut_rubies()
	var relic := c.sell_special("vault_relic") if int(c.d.stash.get("vault_relic", 0)) > 0 else 0
	if cut + relic == 0:
		city._note(tr("CUTTER_NOTHING"), ComicUI.PAPER)
	else:
		city._note(tr("CUTTER_DONE") % [cut + relic, c.rubies()], ComicUI.MAGENTA)
		Profile.save()
	return {"cut": cut, "relic": relic}


func _on_bet(fight: int, corner: int, stake: int) -> void:
	var c := Profile.career()
	pit_panel.note = tr("PIT_BET_OK") if club.place_bet(c, fight, corner, stake) else tr("PIT_BET_NO")
	pit_panel.wallet = int(c.d.wallet)
	Profile.save()
	pit_panel.refresh()


func _on_watch(fight: int) -> void:
	var c := Profile.career()
	var bout := club.run_fight(fight)
	var paid := club.settle(c, fight)
	var f: Dictionary = club.card[fight]
	var who: String = f.red.name if bout.winner == 0 else f.blue.name
	pit_panel.note = tr("PIT_RESULT") % [who, bout.how.to_upper(), paid]
	pit_panel.wallet = int(c.d.wallet)
	Profile.save()
	pit_panel.refresh()


## Your own bout: you against the next name on tonight's card. Your corner
## fights on your fitness (fame); a win pays the purse and a ruby.
func _on_ring() -> void:
	var c := Profile.career()
	var bout := FightClub.Bout.new()
	var opp: Dictionary = club.card[0].blue if not club.card.is_empty() else {"name": "Big Lenny", "rating": 1100}
	var you := FightBrain.new(clampf(0.35 + 0.08 * float(c.fame_tier()), 0.1, 0.9), _club_day * 7 + 1)
	var them := FightBrain.new(FightClub.skill_of(int(opp.rating)), _club_day * 7 + 2)
	while not bout.over:
		var a := you.decide(bout.red, bout.blue)
		var b := them.decide(bout.blue, bout.red)
		bout.tick(a[0], a[1], b[0], b[1])
	var won := bout.winner == 0
	var purse := FightClub.purse(won)
	c.d.wallet = int(c.d.wallet) + purse
	if won:
		c.add_rubies(1)
	pit_panel.note = (tr("PIT_RING_WON") if won else tr("PIT_RING_LOST")) % [opp.name, bout.how.to_upper(), purse]
	pit_panel.wallet = int(c.d.wallet)
	Profile.save()
	pit_panel.refresh()


func _lock() -> void:
	city.match_node.input.enabled = false
	city.match_node.touch.release_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _closed() -> void:
	city.match_node.input.enabled = true
	Profile.save()


## Finished buildings stand on their plots (kit piece + walls); a sale
## takes the building and its walls away (all walls rebuilt).
func _place_buildings() -> void:
	var s := land_state()
	var now := _now()
	var want := {}
	for id: String in LandOffice.PLOTS:
		if LandOffice.owned(s, id) and LandOffice.built(s, id, now):
			want[id] = true
	if want.keys().all(func(k: String) -> bool: return _placed.has(k)) and _placed.size() == want.size():
		return
	for id: String in _placed:
		(_placed[id] as Node).queue_free()
	_placed.clear()
	_plots_body.queue_free()
	_plots_body = StaticBody3D.new()
	_plots_root.add_child(_plots_body)
	for id: String in want:
		var mi := LandOffice.place(s, id, now, _plots_root, _plots_body)
		if mi != null:
			_placed[id] = mi


func _sign(at: Vector3, text: String, color: Color, px: int = 90) -> void:
	var l := Label3D.new()
	l.font = UiStyle.font_hud_big
	l.font_size = px
	l.pixel_size = 0.01
	l.outline_size = 18
	l.outline_modulate = ComicUI.INK
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.text = text
	l.position = at + Vector3(0, 2.6, 0)
	_plots_root.add_child(l)
