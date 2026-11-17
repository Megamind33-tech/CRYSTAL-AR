class_name Nations
extends RefCounted
## THE HUNT's four nations (docs/game-plan.md): invented expeditions sent to
## Mars for its minerals. You belong to one, chosen when you first arrive.
## Every hunter in a dig run belongs to one too: its suit and name wear the
## nation's colour and its shape (never colour alone, PLAN §3.16), and the
## hunters of one nation start a run as a squad.
##
## Colours are far apart in hue and none is the HUD's danger red or the
## good green, which keep their meanings.

const IDS := ["aurora", "meridian", "vesper", "halden"]
const NONE := -1

const NATIONS := {
	"aurora": {"name_key": "NATION_AURORA", "motto_key": "NATION_AURORA_MOTTO", "color": Color(0.16, 0.78, 1.0),
			"shape": [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)],
			"names": ["Ilsa Varn", "Teo Marsh", "Nadia Okoro", "Ruben Hale", "Kaito Bryn", "Sefa Lund"]},
	"meridian": {"name_key": "NATION_MERIDIAN", "motto_key": "NATION_MERIDIAN_MOTTO", "color": Color(1.0, 0.76, 0.12),
			"shape": [Vector2(0, -1), Vector2(0.95, 0.75), Vector2(-0.95, 0.75)],
			"names": ["Amara Quist", "Dov Reyes", "Lio Banda", "Petra Solis", "Hamid Crane", "June Okafor"]},
	"vesper": {"name_key": "NATION_VESPER", "motto_key": "NATION_VESPER_MOTTO", "color": Color(1.0, 0.32, 0.78),
			"shape": [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.8), Vector2(-0.8, 0.8)],
			"names": ["Mira Tal", "Oskar Venn", "Zuri Adeyemi", "Cal Moreau", "Ines Park", "Bo Sterling"]},
	"halden": {"name_key": "NATION_HALDEN", "motto_key": "NATION_HALDEN_MOTTO", "color": Color(0.9, 0.93, 1.0),
			"shape": [Vector2(0, -1), Vector2(0.87, -0.5), Vector2(0.87, 0.5), Vector2(0, 1), Vector2(-0.87, 0.5),
					Vector2(-0.87, -0.5)],
			"names": ["Greta Holm", "Femi Rask", "Yusuf Aldane", "Liv Corran", "Anton Mbeki", "Rosa Vahl"]},
}

## AI squadmates have a character (docs/game-plan.md, decision 3): it
## decides whether, why and how they'd ever turn on you.
##   loyal: never turns first; turns only if you've hurt or betrayed them.
##   steady: turns only on a grudge, or for the grand prize when you're beaten.
##   ambitious: will take a prize off a weak partner when it pays.
const PERSONALITIES := ["loyal", "steady", "ambitious"]


static func index_of(id: String) -> int:
	return IDS.find(id)


static func id_of(i: int) -> String:
	return IDS[i] if i >= 0 and i < IDS.size() else ""


static func color(i: int) -> Color:
	return NATIONS[IDS[i]].color if i >= 0 and i < IDS.size() else Color(0.7, 0.7, 0.7)


static func display_name(i: int) -> String:
	return TranslationServer.translate(NATIONS[IDS[i]].name_key) if i >= 0 and i < IDS.size() else ""


static func motto(i: int) -> String:
	return TranslationServer.translate(NATIONS[IDS[i]].motto_key) if i >= 0 and i < IDS.size() else ""


static func shape(i: int) -> Array:
	return NATIONS[IDS[i]].shape if i >= 0 and i < IDS.size() else []


## The roster of nation `i`: the people who can be your squadmates.
static func names(i: int) -> Array:
	return NATIONS[IDS[i]].names if i >= 0 and i < IDS.size() else []


## Which nation a name belongs to (NONE for anyone else).
static func of_name(n: String) -> int:
	for i in IDS.size():
		if n in NATIONS[IDS[i]].names:
			return i
	return NONE


## A person's character, fixed for them (the same squadmate is the same
## person every run you meet them).
static func personality(person: String) -> String:
	return PERSONALITIES[absi(hash(person)) % PERSONALITIES.size()]


static var _shapes: Dictionary = {}  ## nation -> ImageTexture


## The nation's shape as a white texture (tinted when drawn).
static func shape_texture(i: int, size: int = 48) -> ImageTexture:
	var key := i * 1000 + size
	if _shapes.has(key):
		return _shapes[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var poly := PackedVector2Array()
	var r := size * 0.42
	for p: Vector2 in shape(i):
		poly.append(Vector2(size, size) * 0.5 + p * r)
	var outline := Geometry2D.offset_polygon(poly, size * 0.06)
	for y in size:
		for x in size:
			var at := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(at, poly):
				img.set_pixel(x, y, Color.WHITE)
			elif not outline.is_empty() and Geometry2D.is_point_in_polygon(at, outline[0]):
				img.set_pixel(x, y, Color(0, 0, 0, 0.75))
	var tex := ImageTexture.create_from_image(img)
	_shapes[key] = tex
	return tex


## Seats the hunters of a run (sorted net ids, `home`: nation per human id)
## so each nation has company: a human's nation gets one AI squadmate, the
## remaining AI fill the other nations in turn. Deterministic for `seed`.
static func seat(ids: Array, humans: Dictionary, seed_value: int) -> Dictionary:
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var others: Array = []
	for i in IDS.size():
		others.append(i)
	for id: int in ids:
		if humans.has(id):
			out[id] = int(humans[id])
			others.erase(int(humans[id]))
	# Shuffle the rest so who you face changes from run to run.
	for i in range(others.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = others[i]
		others[i] = others[j]
		others[j] = t
	var squad_needed: Array = []  ## human nations still without an AI squadmate
	for id: int in ids:
		if humans.has(id) and not squad_needed.has(int(humans[id])):
			squad_needed.append(int(humans[id]))
	var k := 0
	var bots: Array = ids.filter(func(id: int) -> bool: return not humans.has(id))
	for id: int in bots:
		if not squad_needed.is_empty():
			out[id] = squad_needed.pop_front()
		elif others.is_empty():
			out[id] = rng.randi_range(0, IDS.size() - 1)
		else:
			out[id] = others[k % others.size()]
			k += 1
	return out
