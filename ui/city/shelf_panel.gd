class_name ShelfPanel
extends Control
## THE HUNT's goods on shelves (ComicUI), not lists: your pack on the left,
## and on the right whatever you're looking into: a shop's counter (with
## price tags; tap theirs to buy, yours to sell), a dropped pack or a held-up
## fighter's (take one stack or everything), a rover's hold (yours: load and
## unload; anyone else's: take). With nothing on the right, the selected
## item is shown large with what you can do with it (equip a gun). Every
## item is drawn as the thing it is on its shelf, a count on it.
##
## open() takes {"mode": "pack"|"shop"|"loot"|"hold", "title": String,
## "right": Dictionary (loot / hold: the live {item: count}), "shop": id}.

signal closed
## Something changed hands: kind "buy", "sell", "take", "take_all", "load",
## "unload", "equip"; the city reacts (alarms, the loadout).
signal acted(kind: String, item: String)

const COLS := 5
const ROWS := 4
const BASE := Vector2(1280, 720)

## How each item looks on the shelf: [colour, shape].
const LOOK := {
	"cargo_case": [Color("c8a24a"), "case"], "stolen_cargo": [Color("ff7a3d"), "case"],
	"vault_relic": [Color("b06cff"), "relic"], "bounty_proof": [Color("ffd23f"), "proof"],
	"helium3": [Color("ffd23f"), "canister"], "rare_ore": [Color("c0587a"), "ore"],
	"water_ice": [Color("a8f0ff"), "ice"], "supply_crate": [Color("b27a3e"), "crate"],
	"refined_ingot": [Color("e8c35a"), "ingot"], "oxygen_canister": [Color("3ee0ff"), "canister"],
	"scrap": [Color("8a8f99"), "scrap"], "red_dust": [Color("ff2d78"), "pills"],
	"parcel": [Color("d9b88a"), "parcel"], "fresh_food": [Color("6be36b"), "leaf"],
	"water_ration": [Color("4aa8ff"), "drop"], "algae_culture": [Color("3fd18b"), "jar"],
	"cred_chip": [Color("7dff6a"), "chips"], "burst_rifle": [Color("5b6170"), "rifle"],
	"scatter_gun": [Color("7a5440"), "shotgun"], "flux_smg": [Color("3a7d8c"), "smg"],
	"pulse_rifle": [Color("6b7a8f"), "rifle"],
	"crowbar": [Color("c0392b"), "crowbar"], "lockpick": [Color("b8bcc6"), "picks"],
	"medkit": [Color("f2f2ee"), "medkit"], "armour_plate": [Color("4a5568"), "plate"],
	"stim_cola": [Color("e23b3b"), "can"], "mask": [Color("1d1a22"), "mask"],
	"hand_drill": [Color("f2b01e"), "drill"],
	"vat_meat": [Color("d9707a"), "meat"], "fresh_meat": [Color("c0392b"), "meat"],
	"meal_pack": [Color("8fae5a"), "case"],
	"fuel_cell": [Color("f2b01e"), "canister"], "repair_kit": [Color("c0392b"), "medkit"],
	"binoculars": [Color("2b2b30"), "binoculars"], "scanner": [Color("3ee0ff"), "scanner"],
}

var mode: String = "pack"
var cfg_cache: int = -1  ## "cache" mode: which of the career's stashes
var hide_here: bool = false  ## "pack" mode: offer to make a stash where you stand
## Searching someone: their compartments, each its own (pack, vehicle hold,
## home locker): [[title, Dictionary], ...]; one shown at a time.
var compartments: Array = []
var _compartment: int = 0
var title: String = ""
var right: Dictionary = {}
var shop: String = ""
var vehicle: SimVehicle  ## a rover's hold: its fuel and condition can be seen to
var _sel_side: int = -1  ## 0: your pack, 1: the other shelf
var _sel_item: String = ""
var _slots: Array = []   ## [Rect2, side, item] from the last draw
var _buttons: HBoxContainer
var _note: String = ""
var _s: float = 1.0
## Items shown as their real 3D model, rendered once off-screen.
const MODEL_OF := {"pulse_rifle": &"pulse_rifle", "burst_rifle": &"burst_rifle", "scatter_gun": &"scatter_gun",
		"flux_smg": &"flux_smg", "frag_grenade": &"frag_grenade"}
var _models := {}  ## item -> SubViewport
var _redraws: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	add_child(_buttons)
	resized.connect(_layout)


func open(cfg: Dictionary) -> void:
	mode = cfg.get("mode", "pack")
	cfg_cache = int(cfg.get("cache", -1))
	hide_here = bool(cfg.get("hide_here", false))
	title = cfg.get("title", "")
	right = cfg.get("right", {}) if mode != "shop" else {}
	shop = cfg.get("shop", "")
	vehicle = cfg.get("vehicle", null)
	compartments = cfg.get("compartments", [])
	_compartment = 0
	if not compartments.is_empty():
		title = compartments[0][0]
		right = compartments[0][1]
	_sel_side = -1
	_sel_item = ""
	_note = ""
	visible = true
	refresh()


func close() -> void:
	visible = false
	closed.emit()


## The pack: the career's stash, plus the issue rifle you always carry.
func _left() -> Dictionary:
	var out := {"pulse_rifle": 1}
	out.merge(Profile.career().d.stash)
	return out


## The other shelf's goods: a shop's stock (1 each, it never runs out), or
## the live pack / hold.
func _right() -> Dictionary:
	if mode == "shop":
		var out := {}
		for item: String in Career.SHOPS[shop].sells:
			out[item] = 0
		if Career.SHOPS[shop].get("gear", false):
			for g: String in Career.GEAR:
				out["gear:" + g] = 0
		return out
	return right


func refresh() -> void:
	if _sel_item != "" and not (_left() if _sel_side == 0 else _right()).has(_sel_item):
		_sel_item = ""
	for b in _buttons.get_children():
		_buttons.remove_child(b)  # out now, so the row's width is the new buttons'
		b.queue_free()
	_buttons.remove_theme_constant_override("separation")
	_buttons.add_theme_constant_override("separation", 14)
	var c := Profile.career()
	# One compartment at a time: a tab for each, with what's in it.
	if compartments.size() > 1:
		for k in compartments.size():
			var comp: Array = compartments[k]
			var n := 0
			for it: String in comp[1]:
				n += int(comp[1][it])
			_button("%s · %d" % [comp[0], n], k != _compartment, ComicUI.CYAN if k != _compartment else ComicUI.PAPER,
					func() -> void:
						_compartment = k
						title = compartments[k][0]
						right = compartments[k][1]
						_sel_side = -1
						_sel_item = ""
						refresh())
	var item := _sel_item
	if item != "":
		if _sel_side == 1 and mode == "shop":
			if item.begins_with("gear:"):
				var g := item.substr(5)
				var cost := c.gear_cost(g)
				_button(tr("SHELF_FIT") % cost if cost >= 0 else tr("SHELF_MAXED"), cost >= 0 and c.d.wallet >= cost,
						ComicUI.GREEN, func() -> void:
							if c.buy_gear(g):
								_done("buy", item, tr("SHELF_FITTED") % Career.GEAR[g].name))
			else:
				var cost := c.shop_price(shop, item)
				_button(tr("SHELF_BUY") % cost, c.d.wallet >= cost, ComicUI.GREEN, func() -> void:
					if c.buy_at(shop, item):
						_done("buy", item, tr("SHELF_BOUGHT") % _name(item)))
				var rub := c.shop_price_rubies(shop, item)
				if rub >= 0:
					_button(tr("SHELF_BUY_RUBIES") % rub, c.rubies() >= rub, ComicUI.MAGENTA, func() -> void:
						if c.buy_at_rubies(shop, item):
							_done("buy", item, tr("SHELF_BOUGHT") % _name(item)))
		elif _sel_side == 0 and mode == "shop" and item != "pulse_rifle":
			var offer := c.shop_offer(shop, item)
			_button(tr("SHELF_SELL") % offer if offer > 0 else tr("SHELF_WONT_BUY"), offer > 0, ComicUI.YELLOW,
					func() -> void:
						var got := c.sell_at(shop, item)
						if got > 0:
							_done("sell", item, tr("SHELF_SOLD") % [_name(item), got]))
		elif _sel_side == 0 and mode == "cache" and item != "pulse_rifle":
			_button(tr("SHELF_HIDE"), true, ComicUI.CYAN, func() -> void:
				if c.hide_in(int(cfg_cache), item) > 0:
					_done("hide", item, tr("SHELF_HIDDEN") % _name(item)))
		elif _sel_side == 1 and mode in ["loot", "hold", "cache"]:
			var n: int = right.get(item, 0)
			_button(tr("SHELF_TAKE") % n, n > 0, ComicUI.GREEN, func() -> void:
				var moved := Robbery.take(right, c.d.stash, item, n)
				if moved > 0:
					_done("take", item, tr("SHELF_TOOK") % [moved, _name(item)]))
		elif _sel_side == 0 and mode == "hold" and is_same(right, c.d.home.locker) and item != "pulse_rifle":
			_button(tr("SHELF_STORE"), true, ComicUI.CYAN, func() -> void:
				if c.store_home(item):
					_done("store", item, tr("SHELF_STORED") % _name(item))
				else:
					_note = tr("SHELF_LOCKER_FULL")
					refresh())
		elif _sel_side == 0 and mode == "hold" and is_same(right, c.d.rover_cargo) and item != "pulse_rifle":
			_button(tr("SHELF_LOAD"), true, ComicUI.CYAN, func() -> void:
				if c.load_rover(item, int(c.d.stash.get(item, 0))):
					_done("load", item, tr("SHELF_LOADED") % _name(item))
				else:
					_note = tr("SHELF_HOLD_FULL")
					refresh())
		if _sel_side == 0 and Career.USE.has(item):
			_button(tr("SHELF_EAT") if Career.USE[item].has("food") else tr("SHELF_USE"), true, ComicUI.GREEN, func() -> void:
				acted.emit("use", item))
		if _sel_side == 0 and item == "mask":
			var on := c.masked()
			_button(tr("SHELF_MASK_OFF") if on else tr("SHELF_MASK_ON"), true, ComicUI.MAGENTA, func() -> void:
				c.set_masked(not on)
				_done("mask", item, tr("SHELF_MASK_OFF_DONE") if on else tr("SHELF_MASK_ON_DONE")))
		if _sel_side == 0 and (Career.is_weapon(item) or item == "pulse_rifle"):
			var armed: bool = (c.d.armed == item) or (item == "pulse_rifle" and c.primary_index() == 0)
			_button(tr("SHELF_EQUIPPED") if armed else tr("SHELF_EQUIP"), not armed, ComicUI.MAGENTA, func() -> void:
				if c.equip("" if item == "pulse_rifle" else item):
					_done("equip", item, tr("SHELF_NOW_CARRY") % _name(item)))
	if vehicle != null:
		for kit: String in Career.ROVER_KIT:
			var n: int = c.d.stash.get(kit, 0)
			var what: Array = Career.ROVER_KIT[kit]
			var now_pct: float = vehicle.get(what[0])
			_button(tr("SHELF_ROVER_" + kit.to_upper()) % [n, roundi(now_pct)], n > 0 and now_pct < 99.0, ComicUI.CYAN, func() -> void:
				if c.use_up(kit):
					vehicle.set(what[0], minf(float(vehicle.get(what[0])) + float(what[1]), 100.0))
					_done("rover_kit", kit, tr("SHELF_ROVER_DONE") % Career.ITEMS[kit].name))
	if mode == "hold" and is_same(right, c.d.home.locker):
		var cost := c.lock_cost()
		if cost >= 0:
			var next: Dictionary = Career.LOCKS[int(c.d.home.lock) + 1]
			_button(tr("SHELF_LOCK") % [next.name, cost], c.d.wallet >= cost, ComicUI.YELLOW, func() -> void:
				if c.upgrade_lock():
					_done("lock", "", tr("SHELF_LOCK_FITTED") % next.name))
	if mode == "pack":
		var woman: bool = c.d.get("body", "male") == "female"
		_button(tr("SHELF_BODY_MAN") if woman else tr("SHELF_BODY_WOMAN"), true, ComicUI.CYAN, func() -> void:
			c.d["body"] = "male" if woman else "female"
			_done("body", "", tr("SHELF_BODY_DONE")))
	if mode == "pack" and hide_here:
		_button(tr("SHELF_HIDE_HERE"), true, ComicUI.CYAN, func() -> void:
			acted.emit("hide_here", ""))
	if mode in ["loot", "hold", "cache"] and not right.is_empty():
		_button(tr("SHELF_TAKE_ALL"), true, ComicUI.GREEN, func() -> void:
			var moved := Robbery.take_all(right, c.d.stash)
			_done("take_all", "", tr("SHELF_TOOK_ALL") % moved.size())
			close())  # grab and go
	_button(tr("SHELF_CLOSE"), true, ComicUI.PAPER, close)
	_layout()
	queue_redraw()


func _done(kind: String, item: String, note: String) -> void:
	_note = note
	Profile.save()
	acted.emit(kind, item)
	refresh()


func _button(text: String, enabled: bool, accent: Color, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 64) * _s
	ComicUI.style_button(b, accent, roundi(26 * _s), UiStyle.font_hud_big)
	b.pressed.connect(action)
	_buttons.add_child(b)


func _layout() -> void:
	_s = minf(size.x / BASE.x, size.y / BASE.y) if size.x > 0 else 1.0
	_buttons.position = Vector2(size.x - 40 * _s, size.y - 98 * _s)
	_buttons.size = Vector2.ZERO
	_buttons.reset_size()
	# Many buttons: tighter and smaller, so the row stays on screen.
	var room := size.x - 80 * _s
	if _buttons.size.x > room:
		for b: Button in _buttons.get_children():
			b.add_theme_font_size_override("font_size", roundi(20 * _s))
			b.custom_minimum_size.x = 100 * _s
		_buttons.add_theme_constant_override("separation", roundi(8 * _s))
		_buttons.reset_size()
	_buttons.position.x = maxf(size.x - 40 * _s - _buttons.size.x, 40 * _s)
	queue_redraw()


func _name(item: String) -> String:
	if item == "pulse_rifle":
		return tr("SHELF_PULSE")
	if item.begins_with("gear:"):
		return str(Career.GEAR[item.substr(5)].name)
	return str(Career.ITEMS[item].name) if Career.ITEMS.has(item) else item


# --- Drawing ---

func _draw() -> void:
	var s := _s
	var c := Profile.career()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.01, 0.06, 0.94))
	var w := (size.x - 120 * s) * 0.5
	var top := 92 * s
	var h := size.y - top - 128 * s
	var left_r := Rect2(40 * s, top, w, h)
	var right_r := Rect2(80 * s + w, top, w, h)
	ComicUI.draw_text(self, Vector2(48 * s, 64 * s), tr("SHELF_YOUR_PACK"), UiStyle.font_hud_big, roundi(38 * s), ComicUI.YELLOW)
	ComicUI.draw_text(self, Vector2(size.x * 0.5, 64 * s), "$%d" % int(c.d.wallet), UiStyle.font_hud_big, roundi(40 * s),
			ComicUI.GREEN, 1)
	ComicUI.draw_text(self, Vector2(size.x * 0.5, 100 * s), "%d R" % c.rubies(), UiStyle.font_hud_bold, roundi(26 * s),
			ComicUI.MAGENTA, 1)
	ComicUI.draw_text(self, Vector2(size.x - 48 * s, 64 * s), title.to_upper(), UiStyle.font_hud_big, roundi(34 * s),
			ComicUI.CYAN, 2)
	_slots.clear()
	_shelf(left_r, _left(), 0)
	if mode == "pack":
		_card(right_r)
	else:
		_shelf(right_r, _right(), 1)
	# The selected item's name and value, the last thing that happened.
	var info := _note
	if _sel_item != "":
		info = _name(_sel_item) + "  ·  " + _describe(_sel_item) + ("" if _note.is_empty() else "   —   " + _note)
	ComicUI.draw_text(self, Vector2(48 * s, size.y - 54 * s), info, UiStyle.font_hud_bold, roundi(24 * s), ComicUI.PAPER)


## One shelf unit: a dark cabinet, planks, the goods standing on them.
func _shelf(r: Rect2, goods: Dictionary, side: int) -> void:
	var s := _s
	ComicUI.draw_panel(self, r, Color(0.13, 0.07, 0.1, 0.96), ComicUI.INK, 4.0 * s, 0.0)
	draw_rect(r.grow(-10 * s), Color(0.2, 0.11, 0.12), true)
	var row_h := (r.size.y - 20 * s) / ROWS
	var col_w := (r.size.x - 20 * s) / COLS
	for row in ROWS:
		var plank_y := r.position.y + 10 * s + row_h * (row + 1) - 14 * s
		var plank := Rect2(r.position.x + 6 * s, plank_y, r.size.x - 12 * s, 12 * s)
		draw_rect(plank, Color("8a4b2a"))
		draw_rect(Rect2(plank.position, Vector2(plank.size.x, 3 * s)), Color("c27a45"))
		draw_rect(plank, ComicUI.INK, false, 2.0 * s)
	var items := goods.keys()
	items.sort_custom(func(a: String, b: String) -> bool: return _order(a) < _order(b))
	for i in mini(items.size(), COLS * ROWS):
		var item: String = items[i]
		var row := i / COLS
		var col := i % COLS
		var cell := Rect2(r.position.x + 10 * s + col * col_w, r.position.y + 10 * s + row * row_h, col_w, row_h - 14 * s)
		var obj := Rect2(cell.position + Vector2(cell.size.x * 0.14, cell.size.y * 0.12), cell.size * Vector2(0.72, 0.86))
		var picked := _sel_side == side and _sel_item == item
		if picked:
			draw_rect(cell.grow(-2 * s), Color(ComicUI.YELLOW, 0.22))
			draw_rect(cell.grow(-2 * s), ComicUI.YELLOW, false, 3.0 * s)
		_draw_item(item, obj)
		var n: int = goods[item]
		if n > 1:
			ComicUI.draw_text(self, cell.position + Vector2(cell.size.x - 6 * s, 26 * s), "×%d" % n, UiStyle.font_hud_big,
					roundi(24 * s), ComicUI.PAPER, 2, roundi(5 * s))
		var tag := _tag(item, side)
		if not tag.is_empty():
			var tr_ := Rect2(cell.position + Vector2(cell.size.x * 0.5 - 38 * s, cell.size.y - 4 * s), Vector2(76 * s, 24 * s))
			draw_rect(tr_, ComicUI.YELLOW if side == 1 else Color(ComicUI.GREEN, 0.9))
			draw_rect(tr_, ComicUI.INK, false, 2.0 * s)
			ComicUI.draw_text(self, tr_.position + Vector2(tr_.size.x * 0.5, 19 * s), tag, UiStyle.font_hud_bold,
					roundi(18 * s), ComicUI.INK, 1, 0)
		_slots.append([cell, side, item])
	if items.is_empty():
		ComicUI.draw_text(self, r.get_center(), tr("SHELF_EMPTY"), UiStyle.font_hud_bold, roundi(26 * s),
				Color(ComicUI.PAPER, 0.6), 1)


## Price tags: a shop's asking price on its shelf; on yours, what it'd pay.
func _tag(item: String, side: int) -> String:
	if mode != "shop":
		return ""
	var c := Profile.career()
	if side == 1:
		if item.begins_with("gear:"):
			var cost := c.gear_cost(item.substr(5))
			return "$%d" % cost if cost >= 0 else "MAX"
		var rub := c.shop_price_rubies(shop, item)
		return "$%d" % c.shop_price(shop, item) + (" / %d R" % rub if rub >= 0 else "")
	var offer := c.shop_offer(shop, item) if item != "pulse_rifle" else 0
	return "$%d" % offer if offer > 0 else ""


## Guns first, then the valuable, then the rest.
func _order(item: String) -> int:
	if item == "pulse_rifle":
		return -2000
	if Career.is_weapon(item) or item.begins_with("gear:"):
		return -1000 + (int(Career.ITEMS[item].weapon) if Career.ITEMS.has(item) else 10)
	return -int(Career.ITEMS[item].base) if Career.ITEMS.has(item) else 0


func _describe(item: String) -> String:
	var c := Profile.career()
	if item.begins_with("gear:"):
		return str(Career.GEAR[item.substr(5)].per_level)
	if item == "pulse_rifle":
		return tr("SHELF_PULSE_DESC")
	var info: Dictionary = Career.ITEMS[item]
	if info.has("weapon"):
		if _sel_side == 1:
			return tr("SHELF_WEAPON_DESC") % (tr("SHELF_FOR_SALE") if mode == "shop" else tr("SHELF_THEIRS"))
		return tr("SHELF_WEAPON_DESC") % (tr("SHELF_EQUIPPED") if c.d.armed == item else tr("SHELF_IN_PACK"))
	if info.get("contraband", false):
		return tr("SHELF_CONTRABAND")
	if Career.USE.has(item) and Career.USE[item].has("food"):
		return tr("SHELF_DESC_FOOD") % [roundi(Career.USE[item].food), c.price(item)]
	if ["crowbar", "lockpick", "medkit", "armour_plate", "stim_cola", "mask", "hand_drill", "fuel_cell", "repair_kit",
			"binoculars", "scanner"].has(item):
		return tr("SHELF_DESC_" + item.to_upper())
	if info.get("no_sale", false):
		return tr("SHELF_NO_SALE")
	return tr("SHELF_WORTH") % c.price(item)


## The selected item, large, in pack mode.
func _card(r: Rect2) -> void:
	var s := _s
	ComicUI.draw_panel(self, r, Color(0.08, 0.03, 0.1, 0.96), ComicUI.YELLOW, 4.0 * s, 0.0)
	if _sel_item == "":
		ComicUI.draw_text(self, r.get_center(), tr("SHELF_PICK"), UiStyle.font_hud_bold, roundi(26 * s),
				Color(ComicUI.PAPER, 0.7), 1)
		return
	var big := Rect2(r.position + Vector2(r.size.x * 0.25, 40 * s), Vector2(r.size.x * 0.5, r.size.y * 0.55))
	_draw_item(_sel_item, big)
	ComicUI.draw_text(self, Vector2(r.get_center().x, big.end.y + 56 * s), _name(_sel_item).to_upper(),
			UiStyle.font_hud_big, roundi(40 * s), ComicUI.YELLOW, 1)
	ComicUI.draw_text(self, Vector2(r.get_center().x, big.end.y + 96 * s), _describe(_sel_item),
			UiStyle.font_hud_bold, roundi(24 * s), ComicUI.PAPER, 1)


## The thing itself, flat colours and an ink line (the comic look).
func _draw_item(item: String, r: Rect2) -> void:
	var key := item.substr(5) if item.begins_with("gear:") else item
	var look: Array = LOOK.get(key, [Color("c27a45"), "plate" if key == "plating" else ("webbing" if key == "ammo" else "crate")])
	var col: Color = look[0]
	var shape: String = look[1]
	var ink := ComicUI.INK
	var lw := 3.0 * _s
	var cx := r.get_center().x
	var bottom := r.end.y
	if ResourceLoader.exists(ITEM_MODEL % key):
		var it := _item_icon(key)
		if it != null:
			# The thing itself, lit in a little studio, with a soft shadow.
			var side := minf(r.size.x * 1.25, r.size.y * 1.25)
			var dst := Rect2(Vector2(cx - side * 0.5, bottom - side), Vector2(side, side))
			draw_texture_rect(it, Rect2(dst.position + Vector2(4, 6) * _s, dst.size), false, Color(0, 0, 0, 0.45))
			draw_texture_rect(it, dst, false)
			return
	if MODEL_OF.has(key):
		var tex := _model_icon(key)
		if tex != null:
			# The real model, side on, with an ink edge (offset dark copies).
			var aspect := 1.0 if key == "frag_grenade" else 2.0
			var w := minf(r.size.x * (0.8 if key == "frag_grenade" else 1.38), r.size.y * aspect * 1.1)
			var dst := Rect2(Vector2(cx - w * 0.5, bottom - w / aspect), Vector2(w, w / aspect))
			draw_texture_rect(tex, Rect2(dst.position + Vector2(4, 6) * _s, dst.size), false, Color(0, 0, 0, 0.45))
			draw_texture_rect(tex, dst, false)
			return
	match shape:
		"canister":
			var body := Rect2(cx - r.size.x * 0.2, r.position.y + r.size.y * 0.18, r.size.x * 0.4, r.size.y * 0.8)
			_poly(_round_rect(body, body.size.x * 0.35), col, ink, lw)
			draw_rect(Rect2(body.position.x, body.position.y + body.size.y * 0.42, body.size.x, body.size.y * 0.14), ink)
			_poly(_rect_pts(Rect2(cx - body.size.x * 0.18, r.position.y + r.size.y * 0.06, body.size.x * 0.36, r.size.y * 0.14)),
					Color("8a8f99"), ink, lw)
			draw_rect(Rect2(body.position.x + body.size.x * 0.16, body.position.y + body.size.y * 0.1, body.size.x * 0.14,
					body.size.y * 0.28), Color(1, 1, 1, 0.45))
		"drop":
			var pts := PackedVector2Array()
			var rad := r.size.x * 0.3
			var c := Vector2(cx, bottom - rad - r.size.y * 0.04)
			pts.append(Vector2(cx, r.position.y + r.size.y * 0.1))
			for k in 13:
				var a := -PI * 0.17 + k * (PI * 1.34 / 12.0)
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			_poly(pts, col, ink, lw)
			draw_circle(c + Vector2(-rad * 0.35, -rad * 0.2), rad * 0.18, Color(1, 1, 1, 0.55))
		"leaf":
			for k in 3:
				var a := -0.6 + k * 0.6
				var base := Vector2(cx, bottom - r.size.y * 0.05)
				var tip := base + Vector2(sin(a), -cos(a)) * r.size.y * 0.85
				var mid := (base + tip) * 0.5
				var side := Vector2(-(tip - base).y, (tip - base).x).normalized() * r.size.x * 0.16
				_poly(PackedVector2Array([base, mid + side, tip, mid - side]), col.darkened(k * 0.12), ink, lw)
				draw_line(base, tip, ink, lw * 0.6)
		"ore", "ice", "scrap":
			var pts := PackedVector2Array()
			var c := Vector2(cx, bottom - r.size.y * 0.38)
			var n := 6 if shape == "ice" else 8
			for k in n:
				var a := TAU * k / n + 0.3
				var jag := 1.0 if shape == "ice" else (0.75 + 0.25 * float((k * 7) % 3))
				pts.append(c + Vector2(cos(a) * r.size.x * 0.42, sin(a) * r.size.y * 0.36) * jag)
			_poly(pts, col, ink, lw)
			draw_line(c, pts[1], Color(1, 1, 1, 0.5), lw * 0.7)
			draw_line(c, pts[n / 2], Color(ink, 0.6), lw * 0.7)
		"ingot":
			var y0 := bottom - r.size.y * 0.42
			_poly(PackedVector2Array([Vector2(r.position.x + r.size.x * 0.2, y0), Vector2(r.end.x - r.size.x * 0.2, y0),
					Vector2(r.end.x, bottom), Vector2(r.position.x, bottom)]), col, ink, lw)
			draw_line(Vector2(r.position.x + r.size.x * 0.28, y0 + 6 * _s), Vector2(r.end.x - r.size.x * 0.3, y0 + 6 * _s),
					Color(1, 1, 1, 0.6), lw)
		"crate", "parcel", "case", "plate", "webbing":
			var hgt := r.size.y * (0.55 if shape == "case" else 0.75)
			var box := Rect2(r.position.x + r.size.x * 0.05, bottom - hgt, r.size.x * 0.9, hgt)
			_poly(_rect_pts(box), col, ink, lw)
			if shape == "crate":
				draw_line(box.position, box.end, ink, lw)
				draw_line(Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), ink, lw)
			elif shape == "parcel":
				draw_line(Vector2(box.get_center().x, box.position.y), Vector2(box.get_center().x, box.end.y), Color("c0392b"), lw * 1.4)
				draw_line(Vector2(box.position.x, box.get_center().y), Vector2(box.end.x, box.get_center().y), Color("c0392b"), lw * 1.4)
			elif shape == "case":
				draw_rect(Rect2(box.get_center().x - box.size.x * 0.18, box.position.y - 10 * _s, box.size.x * 0.36, 10 * _s), ink, false, lw)
				draw_rect(Rect2(box.position.x, box.get_center().y - 3 * _s, box.size.x, 6 * _s), ink)
			elif shape == "plate":
				draw_rect(box.grow(-box.size.x * 0.18), col.lightened(0.25), false, lw)
			else:
				for k in 3:
					draw_rect(Rect2(box.position.x + box.size.x * (0.12 + k * 0.28), box.position.y + box.size.y * 0.2,
							box.size.x * 0.2, box.size.y * 0.6), Color("d8b04a"))
		"crowbar":
			var a := Vector2(r.position.x + r.size.x * 0.12, bottom - r.size.y * 0.1)
			var b := Vector2(r.end.x - r.size.x * 0.18, r.position.y + r.size.y * 0.2)
			draw_line(a, b, ink, lw * 3.2)
			draw_line(a, b, col, lw * 2.0)
			draw_line(b, b + Vector2(r.size.x * 0.14, r.size.y * 0.06), ink, lw * 3.2)
			draw_line(b, b + Vector2(r.size.x * 0.14, r.size.y * 0.06), col, lw * 2.0)
			draw_line(a, a + Vector2(-r.size.x * 0.06, -r.size.y * 0.14), ink, lw * 3.2)
		"picks":
			var roll := Rect2(r.position.x + r.size.x * 0.1, bottom - r.size.y * 0.32, r.size.x * 0.8, r.size.y * 0.3)
			_poly(_rect_pts(roll), Color("6b3e26"), ink, lw)
			for k in 4:
				var x := roll.position.x + roll.size.x * (0.2 + k * 0.2)
				draw_line(Vector2(x, roll.position.y + 4 * _s), Vector2(x + 6 * _s, roll.position.y - r.size.y * 0.45), ink, lw * 1.6)
				draw_line(Vector2(x, roll.position.y + 4 * _s), Vector2(x + 6 * _s, roll.position.y - r.size.y * 0.45), col, lw * 0.8)
		"medkit":
			var box := Rect2(r.position.x + r.size.x * 0.1, bottom - r.size.y * 0.62, r.size.x * 0.8, r.size.y * 0.62)
			_poly(_rect_pts(box), col, ink, lw)
			var cc := box.get_center()
			var arm := box.size.y * 0.3
			draw_rect(Rect2(cc - Vector2(arm, arm * 0.33), Vector2(arm * 2, arm * 0.66)), ComicUI.RED)
			draw_rect(Rect2(cc - Vector2(arm * 0.33, arm), Vector2(arm * 0.66, arm * 2)), ComicUI.RED)
			draw_rect(Rect2(box.get_center().x - box.size.x * 0.18, box.position.y - 8 * _s, box.size.x * 0.36, 8 * _s), ink, false, lw)
		"can":
			var can := Rect2(cx - r.size.x * 0.2, r.position.y + r.size.y * 0.25, r.size.x * 0.4, r.size.y * 0.73)
			_poly(_round_rect(can, can.size.x * 0.12), col, ink, lw)
			draw_rect(Rect2(can.position.x, can.position.y + can.size.y * 0.35, can.size.x, can.size.y * 0.25), ComicUI.PAPER)
			draw_line(Vector2(can.position.x + can.size.x * 0.2, can.position.y + can.size.y * 0.47),
					Vector2(can.end.x - can.size.x * 0.2, can.position.y + can.size.y * 0.47), col, lw * 1.4)
		"mask":
			var c2 := Vector2(cx, bottom - r.size.y * 0.42)
			_poly(_ellipse(c2, Vector2(r.size.x * 0.32, r.size.y * 0.4)), col, ink, lw)
			for sx in [-1.0, 1.0]:
				draw_colored_polygon(_ellipse(c2 + Vector2(sx * r.size.x * 0.13, -r.size.y * 0.08), Vector2(r.size.x * 0.08, r.size.y * 0.05)), ComicUI.PAPER)
			draw_colored_polygon(_ellipse(c2 + Vector2(0, r.size.y * 0.18), Vector2(r.size.x * 0.09, r.size.y * 0.04)), ComicUI.PAPER)
		"drill":
			var body := Rect2(r.position.x + r.size.x * 0.12, bottom - r.size.y * 0.75, r.size.x * 0.55, r.size.y * 0.3)
			_poly(_round_rect(body, body.size.y * 0.3), col, ink, lw)
			_poly(_rect_pts(Rect2(body.position.x + body.size.x * 0.25, body.end.y, body.size.x * 0.28, r.size.y * 0.42)), Color("2b2b30"), ink, lw)
			draw_line(Vector2(body.end.x, body.get_center().y), Vector2(r.end.x - r.size.x * 0.04, body.get_center().y), ink, lw * 2.4)
			draw_line(Vector2(body.end.x, body.get_center().y), Vector2(r.end.x - r.size.x * 0.04, body.get_center().y), Color("b8bcc6"), lw * 1.2)
		"meat":
			# A cut on the bone: a rounded slab, a fat rim, the bone's end.
			var cc := Vector2(cx - r.size.x * 0.06, bottom - r.size.y * 0.36)
			_poly(_ellipse(cc, Vector2(r.size.x * 0.34, r.size.y * 0.3)), col, ink, lw)
			draw_arc(cc, r.size.x * 0.25, -0.4, 1.9, 16, Color("f6e3d0"), 3.0 * _s)
			var bone := cc + Vector2(r.size.x * 0.3, -r.size.y * 0.16)
			draw_line(cc + Vector2(r.size.x * 0.12, -r.size.y * 0.05), bone, ink, lw * 3.0)
			draw_line(cc + Vector2(r.size.x * 0.12, -r.size.y * 0.05), bone, Color("f2ead8"), lw * 1.8)
			draw_circle(bone, r.size.x * 0.07, Color("f2ead8"))
			draw_arc(bone, r.size.x * 0.07, 0.0, TAU, 12, ink, lw * 0.7)
		"binoculars":
			for sx in [-1.0, 1.0]:
				var tube := Rect2(cx + sx * r.size.x * 0.2 - r.size.x * 0.15, bottom - r.size.y * 0.62, r.size.x * 0.3, r.size.y * 0.6)
				_poly(_round_rect(tube, tube.size.x * 0.3), col, ink, lw)
				draw_circle(Vector2(tube.get_center().x, tube.position.y + tube.size.x * 0.4), tube.size.x * 0.28, ComicUI.CYAN)
			draw_rect(Rect2(cx - r.size.x * 0.08, bottom - r.size.y * 0.45, r.size.x * 0.16, r.size.y * 0.12), ink)
		"scanner":
			var body := Rect2(cx - r.size.x * 0.28, bottom - r.size.y * 0.8, r.size.x * 0.56, r.size.y * 0.78)
			_poly(_round_rect(body, body.size.x * 0.12), Color("2b2b30"), ink, lw)
			var scr := body.grow(-body.size.x * 0.14)
			scr.size.y *= 0.6
			draw_rect(scr, Color("0b3a40"))
			draw_arc(scr.get_center(), scr.size.x * 0.32, 0.0, TAU, 24, col, 2.0 * _s)
			draw_line(scr.get_center(), scr.get_center() + Vector2(scr.size.x * 0.3, -scr.size.y * 0.25), col, 2.0 * _s)
		"relic":
			var c := Vector2(cx, bottom - r.size.y * 0.45)
			draw_circle(c, r.size.x * 0.45, Color(col, 0.25))
			_poly(PackedVector2Array([c + Vector2(0, -r.size.y * 0.42), c + Vector2(r.size.x * 0.3, 0),
					c + Vector2(0, r.size.y * 0.42), c + Vector2(-r.size.x * 0.3, 0)]), col, ink, lw)
		"proof":
			var c := Vector2(cx, bottom - r.size.y * 0.42)
			draw_circle(c, r.size.x * 0.36, ink)
			draw_circle(c, r.size.x * 0.32, col)
			var star := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + k * PI / 5.0
				star.append(c + Vector2(cos(a), sin(a)) * r.size.x * (0.22 if k % 2 == 0 else 0.1))
			draw_colored_polygon(star, ink)
		"pills", "jar":
			var vial := Rect2(cx - r.size.x * 0.22, r.position.y + r.size.y * 0.15, r.size.x * 0.44, r.size.y * 0.83)
			_poly(_round_rect(vial, vial.size.x * 0.2), Color(0.85, 0.95, 1.0, 0.55), ink, lw)
			draw_rect(Rect2(vial.position.x + 4 * _s, vial.position.y + vial.size.y * 0.4, vial.size.x - 8 * _s, vial.size.y * 0.55), col)
			draw_rect(Rect2(vial.position.x - 2 * _s, vial.position.y - 8 * _s, vial.size.x + 4 * _s, 12 * _s), ink)
		"chips":
			for k in 4:
				var c := Vector2(cx + (k % 2) * r.size.x * 0.12 - r.size.x * 0.06, bottom - 10 * _s - k * r.size.y * 0.13)
				_poly(_ellipse(c, Vector2(r.size.x * 0.34, r.size.y * 0.09)), col, ink, lw * 0.8)
		"rifle", "shotgun", "smg":
			var long := 1.0 if shape == "rifle" else (0.86 if shape == "shotgun" else 0.66)
			var y := bottom - r.size.y * 0.45
			var x0 := cx - r.size.x * 0.55 * long
			var x1 := cx + r.size.x * 0.55 * long
			var bh := r.size.y * (0.13 if shape != "shotgun" else 0.16)
			var pts := PackedVector2Array([Vector2(x0, y), Vector2(x1, y), Vector2(x1, y + bh), Vector2(cx + r.size.x * 0.05, y + bh),
					Vector2(cx - r.size.x * 0.02, y + bh + r.size.y * 0.24), Vector2(cx - r.size.x * 0.15, y + bh + r.size.y * 0.24),
					Vector2(cx - r.size.x * 0.12, y + bh), Vector2(x0 + r.size.x * 0.12, y + bh),
					Vector2(x0, y + bh + r.size.y * 0.16), Vector2(x0 - r.size.x * 0.06, y + bh + r.size.y * 0.16)])
			_poly(pts, col, ink, lw)
			draw_rect(Rect2(cx - r.size.x * 0.1, y - r.size.y * 0.08, r.size.x * 0.22, r.size.y * 0.08), ink)
			draw_line(Vector2(x0 + 6 * _s, y + 4 * _s), Vector2(x1 - 6 * _s, y + 4 * _s), Color(1, 1, 1, 0.35), lw * 0.8)
			# Each gun its own: an accent stripe, a magazine where it takes one.
			var accent: Color = {"pulse_rifle": ComicUI.CYAN, "burst_rifle": Color("ff8a2a"), "flux_smg": ComicUI.GREEN,
					"scatter_gun": Color("e8c35a")}.get(key, ComicUI.PAPER)
			draw_rect(Rect2(x1 - r.size.x * 0.3, y + bh * 0.3, r.size.x * 0.16, bh * 0.45), accent)
			if key != "scatter_gun":
				var mag_w := r.size.x * (0.1 if key == "flux_smg" else 0.08)
				var mag := Rect2(cx + r.size.x * 0.12, y + bh, mag_w, r.size.y * (0.3 if key == "burst_rifle" else 0.2))
				_poly(_rect_pts(mag), col.darkened(0.3), ink, lw * 0.8)
		_:
			_poly(_rect_pts(r), col, ink, lw)


## The item's 3D model side on (a small transparent render, made once).
func _model_icon(key: String) -> Texture2D:
	if _models.has(key):
		return (_models[key] as SubViewport).get_texture()
	var vp := SubViewport.new()
	vp.size = Vector2i(200, 200) if key == "frag_grenade" else Vector2i(320, 160)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var model: Node3D
	var length := 0.3
	if key == "frag_grenade":
		model = WeaponModels.grenade(0.14)
		length = 0.16
	else:
		model = WeaponModels.instantiate(MODEL_OF[key])
		length = float(WeaponModels.MODELS[MODEL_OF[key]][0])
	vp.add_child(model)
	var centre := Vector3(0, 0, 0)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = 0.0  # always the full model up close
		mi.visibility_range_begin = 0.0
		centre = mi.global_transform * mi.get_aabb().get_center() if mi.is_inside_tree() else centre
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = length * 0.62
	cam.near = 0.01
	cam.far = 10.0
	vp.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.9, 0)
	sun.light_energy = 2.4
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.72, 0.8)
	env.environment.ambient_light_energy = 1.6
	vp.add_child(env)
	add_child(vp)
	# Frame the model's bounds from its side (the muzzle points right).
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center() if not first else centre
	var span := maxf(box.size.z, box.size.y * 2.0) if not first else length
	cam.size = span * 0.56
	if key == "frag_grenade":
		cam.size = maxf(box.size.y, box.size.z) * 1.15 if not first else 0.16
	cam.look_at_from_position(c + Vector3(1.0, 0.0, 0.0), c, Vector3.UP)
	_models[key] = vp
	_redraws = 4  # draw again once it has rendered
	return vp.get_texture()


## The other goods' models (tools/blender/build_items.py), item -> path.
const ITEM_MODEL := "res://art/items/%s.glb"


## An item's model in a small studio: three-quarter view, a warm key light
## with shadows, a cool fill, a rim from behind. Rendered once.
func _item_icon(key: String) -> Texture2D:
	if _models.has(key):
		return (_models[key] as SubViewport).get_texture()
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var model: Node3D = (load(ITEM_MODEL % key) as PackedScene).instantiate()
	vp.add_child(model)
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b := mi.transform * mi.get_aabb()
		var parent := mi.get_parent()
		while parent != null and parent != model:
			if parent is Node3D:
				b = (parent as Node3D).transform * b
			parent = parent.get_parent()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.02)
	var cam := Camera3D.new()
	cam.fov = 26.0
	cam.near = 0.005
	cam.far = 20.0
	var dir := Vector3(0.55, 0.5, 1.0).normalized()
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.02
	vp.add_child(cam)
	cam.look_at_from_position(c + dir * dist, c, Vector3.UP)
	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.95, 0.86)
	key_light.light_energy = 2.2
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = dist * 3.0
	vp.add_child(key_light)
	key_light.look_at_from_position(c + Vector3(1.0, 1.6, 0.8), c, Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.7
	vp.add_child(fill)
	fill.look_at_from_position(c + Vector3(-1.2, 0.4, 0.6), c, Vector3.UP)
	var rim := DirectionalLight3D.new()
	rim.light_energy = 1.4
	vp.add_child(rim)
	rim.look_at_from_position(c + Vector3(-0.3, 0.8, -1.2), c, Vector3.UP)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.52, 0.58)
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A bright studio for metal and glass to reflect (the backdrop stays clear).
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.85, 0.88, 0.95)
	sm.sky_horizon_color = Color(0.95, 0.85, 0.72)
	sm.ground_bottom_color = Color(0.2, 0.17, 0.16)
	sm.ground_horizon_color = Color(0.6, 0.5, 0.42)
	sky.sky_material = sm
	env.environment.sky = sky
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	vp.add_child(env)
	add_child(vp)
	_models[key] = vp
	_redraws = 4
	return vp.get_texture()


func _process(_delta: float) -> void:
	if _redraws > 0 and visible:
		_redraws -= 1
		queue_redraw()


func _poly(pts: PackedVector2Array, fill: Color, ink: Color, w: float) -> void:
	draw_colored_polygon(pts, fill)
	var line := pts.duplicate()
	line.append(pts[0])
	draw_polyline(line, ink, w, true)


static func _rect_pts(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func _round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad), r.end - Vector2(rad, rad),
			Vector2(r.position.x + rad, r.end.y - rad)]
	for k in 4:
		for j in 5:
			var a := PI + k * PI * 0.5 + j * PI * 0.125
			pts.append((corners[k] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts


static func _ellipse(c: Vector2, half: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(c + Vector2(cos(a) * half.x, sin(a) * half.y))
	return pts


func _gui_input(event: InputEvent) -> void:
	var at := Vector2.INF
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		at = event.position
	if at == Vector2.INF:
		return
	for slot: Array in _slots:
		if (slot[0] as Rect2).has_point(at):
			_sel_side = slot[1]
			_sel_item = slot[2]
			_note = ""
			refresh()
			accept_event()
			return
