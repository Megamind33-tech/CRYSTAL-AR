class_name HuntHud
extends Control
## THE HUNT's HUD (ComicUI kit: slanted ink panels, key-art colours). Layout
## after open-world shooters, for touch: compass strip (top centre),
## objective tracker (top left), minimap with cash, wanted stars and rank
## (top right), slanted shield and health bars (bottom left), weapon hotbar
## (bottom centre, tap to switch), mission subtitle above it, banners.
## Drawn over the shared Hud (which keeps the
## crosshair, hit markers, damage arcs, scope and respawn countdown):
##   - a round radar that turns with the camera, with the yard drawn under
##     it and blips for objectives, pads, caches, allies and pinged rivals
##     (objective blips stick to the rim when out of range), with health and
##     armour arcs hugging it;
##   - top right: clock, cash, wanted stars, points and rank, weapon block;
##   - a help box for the context action;
##   - mission subtitles at the bottom, the key words coloured;
##   - big banners for the moments that matter (extracted, wanted, vault).
## Touch screens put the radar top left (the thumbs own the bottom corners).
## Presentation only: it reads the simulation through `state`.

const RADAR_RANGE := 55.0  ## metres from the centre to the rim
const MAP_HALF := 80.0  ## the radar texture covers ±MAP_HALF metres
const MAP_PX_PER_M := 3.0
const CASH := Color("8fe388")
const HEALTH_COL := Color("5fd35f")
const ARMOUR_COL := Color("4aa8ff")
const STAR := Color("f4f4f4")
const STAR_HOT := Color("ff5a4e")
const HELP_BG := Color(0.0, 0.0, 0.0, 0.72)
const OWN := Color("4ee06a")
const GRAND := Color("ffc93c")
const PAD := Color("47e0a0")
const CACHE := Color("ff9a2e")
const DANGER := Color("ff4b4b")
const ALLY := Color("5aa9ff")
const MERC := Color("6ee7f9")
const INTEL := Color("b88cff")
const BANNER_TIME := 3.6

## () -> {"world": SimWorld, "hunt": HuntRules, "me": int, "yaw": float}, or {}.
var state: Callable
var hud: Hud
var touch: bool = false

var _map_tex: ImageTexture
## The area the radar texture covers: centre (x, z) and half size, metres.
var _map_c := Vector2.ZERO
var _map_half: float = MAP_HALF
var _time: float = 0.0
var _s: float = 1.0
var _banner_title: String = ""
var _banner_sub: String = ""
var _banner_color := Color.WHITE
var _banner_t: float = 0.0
var _cash_shown: float = -1.0
var _cash_flash: float = 0.0
var _radar_center := Vector2.ZERO
var _radar_r: float = 92.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch = DisplayServer.is_touchscreen_available()
	_map_tex = build_map_texture()


## The yard from above, for the radar: dark ground, the play area, walls,
## vault, cover and crates. Built once from HuntLayout (the same data as the
## collision), so the radar can't disagree with the world.
static func build_map_texture() -> ImageTexture:
	var px := int(MAP_HALF * 2.0 * MAP_PX_PER_M)
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.05, 0.045, 1.0))
	var ground := Color(0.2, 0.12, 0.085, 1.0)
	_fill(img, Vector3.ZERO, Vector3(HuntLayout.HALF * 2.0, 0, HuntLayout.HALF * 2.0), ground)
	# A faint 10 m survey grid, like a site plan.
	var grid := Color(0.24, 0.15, 0.105, 1.0)
	for i in range(-7, 8):
		_fill(img, Vector3(i * 10.0, 0, 0), Vector3(0.35, 0, HuntLayout.HALF * 2.0), grid)
		_fill(img, Vector3(0, 0, i * 10.0), Vector3(HuntLayout.HALF * 2.0, 0, 0.35), grid)
	# Haul roads: a ring round the vault and spokes out to the pads.
	var road := Color(0.29, 0.19, 0.13, 1.0)
	for i in 64:
		var a := i * TAU / 64.0
		_fill(img, Vector3(sin(a) * 31.0, 0, -cos(a) * 31.0), Vector3(4.5, 0, 4.5), road)
	for z: Vector3 in HuntLayout.extraction_zones():
		for k in 26:
			var p := z * (k / 26.0)
			if p.length() > 31.0:
				_fill(img, p, Vector3(4.0, 0, 4.0), road)
	# Shed floors read as buildings.
	for s: Array in HuntLayout.sheds():
		_fill(img, s[0], Vector3(HuntLayout.SHED_SIZE, 0, HuntLayout.SHED_SIZE), Color(0.33, 0.24, 0.19, 1.0))
	_fill(img, Vector3.ZERO, Vector3(HuntLayout.VAULT_HALF * 2.0, 0, HuntLayout.VAULT_HALF * 2.0), Color(0.36, 0.28, 0.14, 1.0))
	for b: Array in HuntLayout.boxes():
		match int(b[0]):
			HuntLayout.Kind.WALL:
				_fill(img, b[1], b[2] + Vector3(0.4, 0, 0.4), Color(0.72, 0.6, 0.5, 1.0))
			HuntLayout.Kind.VAULT_WALL:
				_fill(img, b[1], b[2] + Vector3(0.4, 0, 0.4), Color(0.95, 0.75, 0.3, 1.0))
	for c: Array in HuntLayout.covers():
		_fill(img, c[0], c[1] + Vector3(0.3, 0, 0.3), Color(0.5, 0.4, 0.33, 1.0))
	for p: Array in HuntLayout.props():
		_fill(img, p[1], Vector3(2.2, 0, 2.2), Color(0.45, 0.36, 0.3, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _fill(img: Image, center: Vector3, size3: Vector3, color: Color) -> void:
	var a := _px(Vector2(center.x - size3.x * 0.5, center.z - size3.z * 0.5))
	var b := _px(Vector2(center.x + size3.x * 0.5, center.z + size3.z * 0.5))
	var r := Rect2i(a, (b - a).max(Vector2i.ONE)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.has_area():
		img.fill_rect(r, color)


static func _px(world_xz: Vector2) -> Vector2i:
	return Vector2i(((world_xz + Vector2(MAP_HALF, MAP_HALF)) * MAP_PX_PER_M).round())


## Kasei Valley's runs: the radar shows the terrain around the dig (dust
## on high ground, darker low ground, 6 m contours, steep slopes as rock).
func use_world_map(center: Vector2, half: float) -> void:
	_map_c = center
	_map_half = half
	var px := int(half * 2.0)
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	for j in px:
		for i in px:
			var x := center.x - half + i
			var z := center.y - half + j
			var h := WorldTerrain.height(x, z)
			var slope := absf(WorldTerrain.height(x + 1.0, z) - h) + absf(WorldTerrain.height(x, z + 1.0) - h)
			var c := Color(0.2, 0.12, 0.085).lerp(Color(0.34, 0.21, 0.14), clampf((h + 28.0) / 50.0, 0.0, 1.0))
			if slope > 0.9:
				c = c.darkened(0.35)
			if absf(fposmod(h, 6.0)) < 0.35:
				c = c.lightened(0.18)
			img.set_pixel(i, j, c)
	img.generate_mipmaps()
	_map_tex = ImageTexture.create_from_image(img)


## A big centre-screen banner ("TREASURE EXTRACTED" / "+100 PTS  +$50").
func banner(title: String, sub: String, color: Color) -> void:
	_banner_title = title
	_banner_sub = sub
	_banner_color = color
	_banner_t = BANNER_TIME


func radar_rect() -> Rect2:
	return Rect2(_radar_center - Vector2(_radar_r, _radar_r), Vector2(_radar_r, _radar_r) * 2.0)


func _process(delta: float) -> void:
	_time += delta
	_banner_t = maxf(0.0, _banner_t - delta)
	_cash_flash = maxf(0.0, _cash_flash - delta)
	queue_redraw()


func _draw() -> void:
	var st: Dictionary = state.call() if state.is_valid() else {}
	if st.is_empty():
		return
	_s = Settings.get_value("accessibility", "hud_scale")
	var world: SimWorld = st.world
	var h: HuntRules = st.hunt
	var me: SimPlayer = world.get_player(int(st.me))
	if me == null:
		return
	var yaw := float(st.yaw)
	_radar_r = 78.0 * _s
	_radar_center = Vector2(size.x - 34.0 * _s - _radar_r, 26.0 * _s + _radar_r)
	if not h.mods.has("no_minimap"):  # a blackout: no minimap
		_draw_radar(world, h, me, yaw)
	_draw_status(world, h, me)
	_draw_compass(h, me, yaw, world.tick)
	_draw_tracker(h, me)
	if me.state.alive:
		SurvivalHud.draw(self, me.state, Vector2(44 * _s, size.y - 118 * _s), _s)
		_draw_bars(me)
		_draw_hotbar(me)
		_draw_help()
		_draw_mission()
	_draw_banner()

# --- Radar ---

func _to_radar(d: Vector3, yaw: float) -> Vector2:
	var r := d.x * cos(yaw) - d.z * sin(yaw)
	var f := -d.x * sin(yaw) - d.z * cos(yaw)
	return Vector2(r, -f) * (_radar_r / RADAR_RANGE)


func _draw_radar(world: SimWorld, h: HuntRules, me: SimPlayer, yaw: float) -> void:
	var c := _radar_center
	var r := _radar_r
	var s := _s
	# An octagon frame: hard shadow, ink rim, cyan inner line.
	var frame := _octagon(c, r + 6 * s)
	var shadow := frame.duplicate()
	for i in shadow.size():
		shadow[i] += Vector2(6, 7) * s
	draw_colored_polygon(shadow, Color(ComicUI.MAGENTA.darkened(0.6), 0.85))
	draw_colored_polygon(frame, ComicUI.INK)
	# The map, turned with the camera: a circle of vertices whose UVs are the
	# world points under them (the mapping is affine, so it's exact).
	var pos := me.state.position
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var k := RADAR_RANGE / r
	for corner in _octagon(Vector2.ZERO, r):
		var sp: Vector2 = corner
		var rr := sp.x * k
		var ff := -sp.y * k
		var wx := pos.x + rr * cos(yaw) - ff * sin(yaw)
		var wz := pos.z - rr * sin(yaw) - ff * cos(yaw)
		pts.append(c + sp)
		uvs.append(Vector2((wx - _map_c.x + _map_half) / (_map_half * 2.0), (wz - _map_c.y + _map_half) / (_map_half * 2.0)))
	draw_polygon(pts, PackedColorArray([Color(1, 1, 1, 0.94)]), uvs, _map_tex)
	var rim := _octagon(c, r)
	rim.append(rim[0])
	draw_polyline(rim, Color(ComicUI.CYAN, 0.8), 2.0 * s)
	var north := _to_radar(Vector3(0, 0, -1), yaw).normalized() * (r + 1 * s)
	draw_circle(c + north, 11 * s, Color(0.04, 0.03, 0.03, 1.0))
	_text_c(c + north + Vector2(0, 7 * s), "N", UiStyle.font_hud_bold, 19, Color.WHITE)
	var tick := world.tick
	var me_id := me.net_id
	# Pads: always faint; bright (and pinned to the rim) while carrying.
	var carrying := h.carried_by(me_id) != null
	for i in h.zones.size():
		var open := h.zone_open(i, tick)
		if not open:
			continue
		_blip(h.zones[i] - pos, yaw, "pad", PAD if carrying else Color(PAD, 0.55), carrying or h.final_phase(tick))
	# The vault.
	_blip(h.vault - pos, yaw, "vault", Color(GRAND, 0.8), false)
	for t: HuntRules.Treasure in h.treasures:
		if t.banked or t.carrier == me_id:
			continue
		if t.kind == HuntRules.Kind.GRAND and tick < t.available_tick:
			continue
		var at := t.position
		if t.carrier != 0 and world.players.has(t.carrier):
			at = world.players[t.carrier].state.position
		match t.kind:
			HuntRules.Kind.GRAND:
				_blip(at - pos, yaw, "grand", GRAND, true)
			HuntRules.Kind.PERSONAL:
				if t.owner == me_id:
					_blip(at - pos, yaw, "own", OWN, true)
				elif t.carrier == 0 and t.return_tick > 0:
					_blip(at - pos, yaw, "drop", Color(1, 1, 1, 0.85), false)
			HuntRules.Kind.PROOF:
				_blip(at - pos, yaw, "drop", DANGER, false)
			HuntRules.Kind.RESOURCE:
				_blip(at - pos, yaw, "cache", CACHE, false)
	for cache: HuntRules.Cache in h.caches:
		if not cache.empty:
			_blip(cache.position - pos, yaw, "cache", CACHE, true)
	# Rivals: only what the rules reveal (alarm, wanted pings, intel).
	for id: int in world.players:
		if id == me_id:
			continue
		var p: SimPlayer = world.players[id]
		if not p.state.alive:
			continue
		if h.social.allied(me_id, id):
			_blip(p.state.position - pos, yaw, "ally", ALLY, true)
		elif h.economy.mercs.get(id, 0) == me_id:
			_blip(p.state.position - pos, yaw, "ally", MERC, false)
		elif h.is_revealed(id, tick):
			_blip(p.state.position - pos, yaw, "hostile", DANGER, false)
	for id: int in h.social.last_known:
		var seen: Dictionary = h.social.last_known[id]
		if id != me_id and h.social.is_wanted(id) and tick - int(seen.tick) < 20 * Sim.TICK_RATE:
			var pulse := 0.55 + 0.45 * sin(_time * 6.0)
			_blip((seen.position as Vector3) - pos, yaw, "wanted", Color(DANGER, pulse), false)
	for rep: Dictionary in h.economy.intel_of(me_id, tick):
		if rep.position != Vector3.INF and h.intel_useful(rep, tick):
			_blip((rep.position as Vector3) - pos, yaw, "intel", INTEL, false)
	# Us: an arrow, always pointing up (the map turns, not the arrow).
	var a := 10.0 * s
	var arrow := PackedVector2Array([c + Vector2(0, -a * 1.25), c + Vector2(a * 0.85, a), c + Vector2(0, a * 0.45),
			c + Vector2(-a * 0.85, a)])
	draw_colored_polygon(arrow, Color.WHITE)
	arrow.append(arrow[0])
	draw_polyline(arrow, Color(0, 0, 0, 0.8), 2.0 * s)


## One blip: `kind` picks the icon; `pin` sticks it to the rim when out of range.
func _blip(d: Vector3, yaw: float, kind: String, col: Color, pin: bool) -> void:
	var p := _to_radar(d, yaw)
	var edge := _radar_r - 9.0 * _s
	if p.length() > edge:
		if not pin:
			return
		p = p.normalized() * edge
	var at := _radar_center + p
	var s := _s
	var outline := Color(0, 0, 0, 0.85 * col.a)
	match kind:
		"own":
			draw_rect(Rect2(at - Vector2(7, 7) * s, Vector2(14, 14) * s), outline)
			draw_rect(Rect2(at - Vector2(5, 5) * s, Vector2(10, 10) * s), col)
		"grand":
			var g := 9.0 * s * (1.0 + 0.12 * sin(_time * 5.0))
			draw_colored_polygon(_diamond(at, g + 2.5 * s), outline)
			draw_colored_polygon(_diamond(at, g), col)
		"pad":
			draw_circle(at, 9.5 * s, outline)
			draw_circle(at, 7.5 * s, col)
			_text_c(at + Vector2(0, 6 * s), "E", UiStyle.font_hud_bold, 17, Color(0.02, 0.1, 0.05))
		"vault":
			draw_rect(Rect2(at - Vector2(7, 7) * s, Vector2(14, 14) * s), outline, false, 4.0 * s)
			draw_rect(Rect2(at - Vector2(7, 7) * s, Vector2(14, 14) * s), col, false, 2.0 * s)
		"cache":
			draw_circle(at, 7.5 * s, outline)
			draw_circle(at, 5.5 * s, col)
		"drop":
			draw_circle(at, 5.5 * s, outline)
			draw_circle(at, 4.0 * s, col)
		"ally":
			draw_circle(at, 7.0 * s, outline)
			draw_circle(at, 5.0 * s, col)
		"hostile", "wanted":
			draw_circle(at, 7.0 * s, outline)
			draw_circle(at, 5.0 * s, col)
			if kind == "wanted":
				draw_arc(at, 11.0 * s, 0, TAU, 20, col, 2.0 * s)
		"intel":
			draw_arc(at, 7.0 * s, 0, TAU, 20, outline, 4.5 * s)
			draw_arc(at, 7.0 * s, 0, TAU, 20, col, 2.5 * s)


static func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


## Health (left) and armour (right) as thick arcs round the radar's base.
static func _octagon(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * r / cos(PI / 8.0) * 0.96)
	return pts


## Bottom left: shield over health, slanted and segmented, with numbers.
func _draw_bars(me: SimPlayer) -> void:
	var s := _s
	var x := 34.0 * s
	var y := size.y - 30.0 * s
	var hp := clampf(me.state.health / Balance.PLAYER.max_health, 0.0, 1.0)
	var sh_max := maxf(Balance.PLAYER.max_shield, me.state.shield)
	var sh := clampf(me.state.shield / sh_max, 0.0, 1.0) if sh_max > 0.0 else 0.0
	var low := hp < 0.35
	var hcol := ComicUI.RED if not low else Color(ComicUI.RED, 0.55 + 0.45 * sin(_time * 9.0))
	_bar(Rect2(x + 10 * s, y - 62 * s, 230 * s, 20 * s), sh, ComicUI.CYAN, "%d" % ceili(me.state.shield), "◈")
	_bar(Rect2(x, y - 30 * s, 260 * s, 26 * s), hp, hcol, "%d" % ceili(me.state.health), "✚")


func _bar(r: Rect2, f: float, col: Color, num: String, icon: String) -> void:
	var s := _s
	var k := r.size.y * 0.6
	ComicUI.draw_panel(self, r, Color(ComicUI.INK, 0.8), ComicUI.INK, 3.0 * s, k)
	if f > 0.0:
		var inner := Rect2(r.position + Vector2(4, 4) * s, Vector2((r.size.x - 8 * s) * f, r.size.y - 8 * s))
		draw_colored_polygon(ComicUI.quad(inner, inner.size.y * 0.6), col)
		# Segment ticks.
		var seg := (r.size.x - 8 * s) / 10.0
		for i in range(1, 10):
			var tx := inner.position.x + seg * i
			if tx < inner.end.x:
				draw_line(Vector2(tx + inner.size.y * 0.6, inner.position.y), Vector2(tx, inner.end.y), Color(ComicUI.INK, 0.6), 2.0 * s)
	ComicUI.draw_text(self, Vector2(r.position.x - 4 * s, r.end.y - 3 * s), icon, UiStyle.font_body_bold, roundi(r.size.y * 0.95), col, 2, roundi(5 * s))
	ComicUI.draw_text(self, Vector2(r.end.x + k + 10 * s, r.end.y - 1 * s), num, UiStyle.font_hud_big, roundi(r.size.y * 1.15), ComicUI.PAPER, 0, roundi(5 * s))

# --- Top right: clock, cash, wanted, points, weapon ---

## Under the minimap: clock, cash, wanted stars, points and rank.
func _draw_status(world: SimWorld, h: HuntRules, me: SimPlayer) -> void:
	var s := _s
	var right := size.x - 30.0 * s
	var y := _radar_center.y + _radar_r + 14.0 * s
	var credits: int = h.economy.credits.get(me.net_id, 0)
	if _cash_shown < 0.0:
		_cash_shown = credits
	if absf(_cash_shown - credits) > 0.5:
		if credits > _cash_shown:
			_cash_flash = 1.2
		_cash_shown = move_toward(_cash_shown, credits, maxf(2.0, absf(credits - _cash_shown) * 0.12))
	var cash_col := ComicUI.GREEN.lerp(Color.WHITE, clampf(_cash_flash, 0.0, 1.0) * 0.6)
	ComicUI.draw_text(self, Vector2(right, y + 40 * s), "$%s" % _thousands(roundi(_cash_shown)), UiStyle.font_hud_big,
			roundi(44 * s), cash_col, 2, roundi(7 * s))
	y += 46 * s
	var bounty: int = h.social.bounty.get(me.net_id, 0)
	if bounty > 0:
		var stars := clampi(ceili(bounty / 50.0), 1, 5)
		var flash := h.social.is_wanted(me.net_id) and int(_time * 3.0) % 2 == 0
		for i in 5:
			var cx := right - 14.0 * s - i * 30.0 * s
			var on := (4 - i) < stars
			var col := (ComicUI.MAGENTA if flash else ComicUI.YELLOW) if on else Color(1, 1, 1, 0.18)
			draw_colored_polygon(_star(Vector2(cx + 3 * s, y + 19 * s), 15.0 * s), Color(ComicUI.INK, 0.85 if on else 0.3))
			draw_colored_polygon(_star(Vector2(cx, y + 16 * s), 12.5 * s), col)
		y += 36 * s
	var mine: int = world.scores.get(me.net_id, 0)
	var rank := 1
	var field := 0
	for id: int in world.players:
		if h.economy.is_merc(id):
			continue
		field += 1
		if int(world.scores.get(id, 0)) > mine:
			rank += 1
	var line := "%d PTS  ·  %s / %d" % [mine, _ordinal(rank), field]
	if hud != null and hud.timer_shown():
		var secs := hud.timer_seconds()
		line = "%d:%02d   ·   " % [floori(secs / 60.0), secs % 60] + line
	ComicUI.draw_text(self, Vector2(right, y + 22 * s), line, UiStyle.font_hud_bold, roundi(24 * s), ComicUI.PAPER, 2, roundi(5 * s))


## Top centre: a compass strip; objectives ride on it with their distance.
func _draw_compass(h: HuntRules, me: SimPlayer, yaw: float, tick: int) -> void:
	var s := _s
	var w := 460.0 * s
	var r := Rect2(Vector2((size.x - w) * 0.5, 16 * s), Vector2(w, 34 * s))
	ComicUI.draw_panel(self, r, Color(ComicUI.INK, 0.72), ComicUI.INK, 3.0 * s, 0.0)
	var heading := wrapf(-rad_to_deg(yaw), 0.0, 360.0)  # 0 = north (-Z), clockwise
	var span := 100.0  # degrees across the strip
	var px_per_deg := w / span
	var cx := r.get_center().x
	var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
	for deg in range(0, 360, 15):
		var off := wrapf(deg - heading, -180.0, 180.0)
		if absf(off) > span * 0.5:
			continue
		var x := cx + off * px_per_deg
		if names.has(deg):
			ComicUI.draw_text(self, Vector2(x, r.end.y - 8 * s), names[deg], UiStyle.font_hud_big, roundi(20 * s),
					ComicUI.YELLOW if deg == 0 else ComicUI.PAPER, 1, roundi(3 * s))
		else:
			draw_line(Vector2(x, r.end.y - 12 * s), Vector2(x, r.end.y - 5 * s), Color(ComicUI.PAPER, 0.5), 2.0 * s)
	# The nearest objective: carried -> nearest open pad; else own cargo / relic.
	var pos := me.state.position
	var target := Vector3.INF
	var col := ComicUI.PAPER
	if h.carried_by(me.net_id) != null:
		target = h.nearest_zone(pos, tick)
		col = PAD
	else:
		var best := INF
		for t: HuntRules.Treasure in h.treasures:
			if t.banked or t.carrier != 0 or (t.kind == HuntRules.Kind.PERSONAL and t.owner != me.net_id):
				continue
			if t.kind == HuntRules.Kind.GRAND and tick < t.available_tick:
				continue
			if t.kind != HuntRules.Kind.PERSONAL and t.kind != HuntRules.Kind.GRAND:
				continue
			var d := pos.distance_to(t.position)
			if d < best:
				best = d
				target = t.position
				col = GRAND if t.kind == HuntRules.Kind.GRAND else OWN
	if target != Vector3.INF:
		var to := target - pos
		var bearing := wrapf(rad_to_deg(atan2(to.x, -to.z)), 0.0, 360.0)
		var off := clampf(wrapf(bearing - heading, -180.0, 180.0), -span * 0.5, span * 0.5)
		var x := cx + off * px_per_deg
		draw_colored_polygon(_diamond(Vector2(x, r.end.y + 12 * s), 9 * s), ComicUI.INK)
		draw_colored_polygon(_diamond(Vector2(x, r.end.y + 12 * s), 6.5 * s), col)
		ComicUI.draw_text(self, Vector2(x, r.end.y + 40 * s), "%dm" % roundi(Vector2(to.x, to.z).length()),
				UiStyle.font_hud_bold, roundi(20 * s), col, 1, roundi(4 * s))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 7 * s, r.position.y - 1), Vector2(cx + 7 * s, r.position.y - 1),
			Vector2(cx, r.position.y + 9 * s)]), ComicUI.YELLOW)


## Top left: the career contract and this run's checklist.
func _draw_tracker(h: HuntRules, me: SimPlayer) -> void:
	var s := _s
	var x := 34.0 * s
	var y := 22.0 * s
	var c: Dictionary = Profile.career().d.contract
	var title := tr("HUD_NO_CONTRACT") if c.is_empty() else str(c.title).to_upper()
	var tag := Rect2(Vector2(x, y), Vector2(150 * s, 28 * s))
	ComicUI.draw_panel(self, tag, ComicUI.YELLOW, ComicUI.INK, 3.0 * s)
	ComicUI.draw_text(self, tag.position + Vector2(18 * s, 23 * s), tr("HUD_CONTRACT"), UiStyle.font_hud_big, roundi(20 * s),
			ComicUI.INK, 0, 0)
	ComicUI.draw_text(self, Vector2(x, y + 62 * s), title, UiStyle.font_hud_big, roundi(26 * s), ComicUI.PAPER, 0, roundi(5 * s))
	var yy := y + 92 * s
	if not c.is_empty():
		var got := 0
		for item: Dictionary in h.haul.get(me.net_id, []):
			got += 1 if item.get("item", "") == c.need else 0
		var done := got >= int(c.count)
		var mark := "☑" if done else "☐"
		ComicUI.draw_text(self, Vector2(x, yy), "%s  %s  %d/%d" % [mark, Career.ITEMS[c.need].name, mini(got, int(c.count)),
				int(c.count)], UiStyle.font_hud_bold, roundi(23 * s), ComicUI.GREEN if done else ComicUI.PAPER, 0, roundi(4 * s))
		yy += 28 * s
	var haul: Array = h.haul.get(me.net_id, [])
	ComicUI.draw_text(self, Vector2(x, yy), tr("HUD_SECURED") % haul.size(), UiStyle.font_hud_bold, roundi(22 * s),
			Color(ComicUI.PAPER, 0.85), 0, roundi(4 * s))

## Bottom centre: weapon slots (tap one to switch), ammo in the active one,
## grenades at the end.
func _draw_hotbar(me: SimPlayer) -> void:
	var s := _s
	var st := me.state
	var n := st.weapons.size()
	var bw := 112.0 * s
	var bh := 58.0 * s
	var gap := 14.0 * s
	var total := (n + 1) * bw + n * gap
	var x := (size.x - total) * 0.5
	var y := size.y - bh - 18.0 * s
	var rects: Array[Rect2] = []
	for i in n + 1:
		var r := Rect2(Vector2(x + i * (bw + gap), y), Vector2(bw, bh))
		var active := i == st.weapon_slot
		if i < n:
			rects.append(r.grow(4 * s))
		var fill := Color(ComicUI.INK, 0.78) if not active else Color(ComicUI.VIOLET, 0.92)
		ComicUI.draw_panel(self, r, fill, ComicUI.YELLOW if active else ComicUI.INK, (4.0 if active else 3.0) * s)
		if i == n:
			ComicUI.draw_text(self, r.position + Vector2(16 * s, 26 * s), tr("HUD_FRAG"), UiStyle.font_hud_bold, roundi(20 * s),
					Color(ComicUI.PAPER, 0.7), 0, 0)
			ComicUI.draw_text(self, r.position + Vector2(16 * s, 52 * s), "×%d" % st.grenades, UiStyle.font_hud_big,
					roundi(26 * s), ComicUI.PAPER if st.grenades > 0 else Color(ComicUI.PAPER, 0.35), 0, roundi(4 * s))
			continue
		var w := Weapons.at(st.weapons[i])
		if w == null:
			continue
		var label := KillFeed.weapon_tag(w.id) if KillFeed.WEAPON_TAGS.has(w.id) else tr(w.display_name)
		ComicUI.draw_text(self, r.position + Vector2(16 * s, 24 * s), "%d  %s" % [i + 1, label.to_upper()], UiStyle.font_hud_bold,
				roundi(19 * s), ComicUI.YELLOW if active else Color(ComicUI.PAPER, 0.7), 0, 0)
		var reserve := "∞" if WeaponSim.endless_reserve(w) else str(st.reserve[i])
		if active and st.reload[i] > 0:
			ComicUI.draw_text(self, r.position + Vector2(16 * s, 51 * s), tr("HUD_RELOADING").to_upper(), UiStyle.font_hud_big,
					roundi(22 * s), ComicUI.YELLOW, 0, roundi(4 * s))
		else:
			var mag: int = st.mag[i]
			var low := mag <= ceili(maxi(w.mag_size, 1) * 0.25)
			var wd := ComicUI.draw_text(self, r.position + Vector2(16 * s, 52 * s), str(mag), UiStyle.font_hud_big,
					roundi(28 * s), ComicUI.RED if mag == 0 else (ComicUI.YELLOW if low else ComicUI.PAPER), 0, roundi(4 * s))
			ComicUI.draw_text(self, r.position + Vector2(22 * s + wd, 52 * s), "| " + reserve, UiStyle.font_hud_bold,
					roundi(22 * s), Color(ComicUI.PAPER, 0.6), 0, 0)
	if hud != null:
		hud.hunt_slot_rects = rects

static func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


static func _thousands(v: int) -> String:
	var t := str(absi(v))
	var out := ""
	while t.length() > 3:
		out = "," + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("-" if v < 0 else "") + t + out


static func _ordinal(n: int) -> String:
	var suffix := "TH"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "ST", 2: "ND", 3: "RD"}.get(n % 10, "TH")
	return "%d%s" % [n, suffix]


# --- Help box, mission subtitle, banners ---

func _draw_help() -> void:
	var text := hud.prompt_text() if hud != null else ""
	if text.is_empty():
		return
	var s := _s
	var f := UiStyle.font_hud_bold
	var px := roundi(28 * s)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := Rect2(Vector2((size.x - tw) * 0.5 - 22 * s, 104 * s), Vector2(tw + 44 * s, 46 * s))
	ComicUI.draw_panel(self, r, Color(ComicUI.INK, 0.85), ComicUI.YELLOW, 3.0 * s)
	draw_string(f, r.position + Vector2(24 * s, 33 * s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ComicUI.PAPER)

func _draw_mission() -> void:
	if hud == null or hud.objective_text().is_empty():
		return
	var text := hud.objective_text()
	var hl := hud.objective_color()
	var parts := []
	var on := false
	for chunk in text.split("«"):
		var sub := chunk.split("»")
		if sub.size() == 2:
			parts.append([sub[0], true])
			parts.append([sub[1], false])
		else:
			parts.append([chunk, on])
	var f := UiStyle.font_hud_bold
	var px := roundi(31 * _s)
	var total := 0.0
	for p: Array in parts:
		total += f.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var y := size.y - 104.0 * _s
	if touch:  # over the gait chips (TouchControls), which sit over the hotbar
		y = minf(y, size.y * (1.0 - TouchControls.GAIT_Y - TouchControls.GAIT_RADIUS) - 10.0 * _s)
	var x := (size.x - total) * 0.5
	for p: Array in parts:
		var col: Color = hl if p[1] else Color.WHITE
		draw_string_outline(f, Vector2(x, y), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, px, roundi(6 * _s), Color(0, 0, 0, 0.85))
		draw_string(f, Vector2(x, y), p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		x += f.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## A comic caption panel: a tilted slab in the banner colour with a heavy
## ink outline and an offset shadow, the title in Anton, the line under it
## in a black caption box.
func _draw_banner() -> void:
	if _banner_t <= 0.0:
		return
	var s := _s
	var age := BANNER_TIME - _banner_t
	var a := clampf(age / 0.12, 0.0, 1.0) * clampf(_banner_t / 0.4, 0.0, 1.0)
	var grow := 1.0 + 0.35 * (1.0 - clampf(age / 0.18, 0.0, 1.0))
	var f := UiStyle.font_hud_big
	var px := roundi(64 * s * grow)
	var tw := f.get_string_size(_banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var c := Vector2(size.x * 0.5, size.y * 0.3)
	var hw := tw * 0.5 + 34 * s
	var hh := 50 * s * grow
	draw_set_transform(c, -0.06, Vector2.ONE)
	var slab := PackedVector2Array([Vector2(-hw - 14 * s, -hh), Vector2(hw + 10 * s, -hh - 6 * s),
			Vector2(hw + 16 * s, hh), Vector2(-hw - 8 * s, hh + 5 * s)])
	var shadow := slab.duplicate()
	for i in shadow.size():
		shadow[i] += Vector2(9, 10) * s
	var ink := Color(0.06, 0.02, 0.08, a)
	draw_colored_polygon(shadow, Color(0.12, 0.02, 0.2, 0.8 * a))
	draw_colored_polygon(slab, Color(_banner_color, a))
	var line := slab.duplicate()
	line.append(slab[0])
	draw_polyline(line, ink, 6.0 * s)
	var pos := Vector2(-tw * 0.5, px * 0.36)
	draw_string_outline(f, pos, _banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, roundi(4 * s), Color(1, 1, 1, a))
	draw_string(f, pos, _banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)
	if not _banner_sub.is_empty():
		var sf := UiStyle.font_hud_bold
		var spx := roundi(30 * s)
		var sw := sf.get_string_size(_banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, spx).x
		var box := Rect2(Vector2(-sw * 0.5 - 16 * s, hh + 10 * s), Vector2(sw + 32 * s, 42 * s))
		draw_rect(box, ink)
		draw_string(sf, box.position + Vector2(16 * s, 32 * s), _banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, spx, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Text helpers (outlined, for readability on Titan's bright haze) ---

func _text(pos: Vector2, text: String, f: Font, size_px: float, col: Color) -> void:
	var px := roundi(size_px * _s)
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, roundi(5 * _s), Color(0, 0, 0, 0.75 * col.a))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _text_r(pos: Vector2, text: String, f: Font, size_px: float, col: Color) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size_px * _s)).x
	_text(pos - Vector2(w, 0), text, f, size_px, col)


func _text_c(pos: Vector2, text: String, f: Font, size_px: float, col: Color) -> void:
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(size_px * _s)).x
	_text(pos - Vector2(w * 0.5, 0), text, f, size_px, col)
