class_name CityStyle
extends RefCounted
## Your look and the season (free roam, with CityMode): the Style menu.
## The season track (XP from what you do: news you make, deals, events)
## pays cosmetics and cash on its free track; the premium track is shown
## but waits for the real store (no paid anything is faked here). The
## wardrobe equips what you own; the shop sells looks for your cash; emotes
## play standing still. Looks only: nothing here buys power or money.

var city: CityMode
var _page: String = "season"
var _suit_seen: String = ""
var _flame_seen: String = "?"


func _init(p_city: CityMode) -> void:
	city = p_city


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


func open() -> void:
	_page = "season"
	city.open_menu(_t("STYLE_TITLE"), _line(), _options())


func _line() -> String:
	var c := Profile.career()
	var tier := c.season_tier()
	var into := int(c.d.season.xp) - tier * Career.XP_PER_TIER
	var lines := PackedStringArray([_t("STYLE_SEASON") % [Career.SEASON_NAME, tier, Career.SEASON_TIERS, into, Career.XP_PER_TIER]])
	var on := PackedStringArray()
	for kind: String in ["suit", "flame", "paint", "title"]:
		var id := c.equipped(kind)
		if not id.is_empty():
			on.append(str(Career.COSMETICS[id].name))
	lines.append(_t("STYLE_WEARING") % (", ".join(on) if not on.is_empty() else _t("STYLE_DEFAULT")))
	match _page:
		"season":
			lines.append(_t("STYLE_PAGE_SEASON"))
		"wardrobe":
			lines.append(_t("STYLE_PAGE_WARDROBE"))
		"shop":
			lines.append(_t("STYLE_PAGE_SHOP") % int(c.d.wallet))
		"emotes":
			lines.append(_t("STYLE_PAGE_EMOTES"))
	return "\n".join(lines)


func _options() -> Array:
	var c := Profile.career()
	var out := []
	for page: String in ["season", "wardrobe", "shop", "emotes"]:
		if page != _page:
			out.append([_t("STYLE_TAB_" + page.to_upper()), true, ComicUI.PAPER, "style:page:" + page])
	match _page:
		"season":
			var shown := 0
			for t in range(1, Career.SEASON_TIERS + 1):
				if t in c.d.season.claimed:
					continue
				var r := c.season_reward(t)
				var what := str(Career.COSMETICS[r.cosmetic].name) if r.has("cosmetic") else "$%d" % int(r.cash)
				out.append([_t("STYLE_CLAIM") % [t, what], t <= c.season_tier(), ComicUI.YELLOW, "style:claim:%d" % t])
				shown += 1
				if shown >= 3:
					break
			out.append([_t("STYLE_PREMIUM"), false, ComicUI.MAGENTA, "none"])
		"wardrobe":
			for id: String in c.d.cosmetics:
				var cos: Dictionary = Career.COSMETICS.get(id, {})
				if cos.is_empty() or cos.kind == "emote":
					continue
				var on := c.equipped(cos.kind) == id
				out.append([(_t("STYLE_TAKE_OFF") if on else _t("STYLE_WEAR")) % cos.name, true, ComicUI.CYAN, "style:equip:" + id])
		"shop":
			for id: String in Career.COSMETICS:
				var cos: Dictionary = Career.COSMETICS[id]
				if not cos.has("price") or c.owns_cosmetic(id):
					continue
				out.append([_t("STYLE_BUY") % [cos.name, int(cos.price)], c.d.wallet >= int(cos.price), ComicUI.GREEN,
						"style:buy:" + id])
		"emotes":
			for id: String in c.d.cosmetics:
				var cos: Dictionary = Career.COSMETICS.get(id, {})
				if not cos.is_empty() and cos.kind == "emote":
					out.append([_t("STYLE_EMOTE") % cos.name, true, ComicUI.MAGENTA, "style:emote:" + id])
	return out


func menu_act(what: String) -> void:
	var c := Profile.career()
	var parts := what.split(":")
	match parts[0]:
		"page":
			_page = parts[1]
		"claim":
			var r := c.claim_season(int(parts[1]))
			if not r.is_empty():
				city._note(_t("STYLE_CLAIMED") % (str(Career.COSMETICS[r.cosmetic].name) if r.has("cosmetic") else "$%d" % int(r.cash)),
						ComicUI.YELLOW)
		"equip":
			c.equip_cosmetic(parts[1])
		"buy":
			if c.buy_cosmetic(parts[1]):
				c.equip_cosmetic(parts[1])
				city._note(_t("STYLE_BOUGHT") % Career.COSMETICS[parts[1]].name, ComicUI.GREEN)
		"emote":
			_play_emote(str(Career.COSMETICS[parts[1]].clip))
			Profile.save()
			city.garage.visible = false
			city._close_talk()
			return
	Profile.save()
	apply()
	city.garage.set_menu(_line(), _options())


func _play_emote(clip: String) -> void:
	var v: PlayerVisual = city.match_node._visuals.get(ServerSession.LOCAL_PLAYER_ID)
	if v != null and v.rig != null:
		v.rig.emote = clip


## What's equipped, on you: the suit (your body's colour, rebuilt when it
## changes), the jetpack flame, your rovers' paint (RoverVisuals reads it).
func apply() -> void:
	var c := Profile.career()
	var suit := c.equipped("suit")
	if suit != _suit_seen:
		_suit_seen = suit
		city.match_node.rebuild_visual(ServerSession.LOCAL_PLAYER_ID)
	var flame := c.equipped("flame")
	if flame != _flame_seen and city._jet_fx != null:
		_flame_seen = flame
		var col: Color = Career.COSMETICS[flame].color if not flame.is_empty() else Color(1.0, 0.8, 0.4)
		var ramp := ((city._jet_fx.process_material as ParticleProcessMaterial).color_ramp as GradientTexture1D).gradient
		ramp.set_color(0, Color(col, 1.0))
		ramp.set_color(1, Color(col.darkened(0.5), 0.0))


## The suit colour for your body (Match._visual_for asks), or null.
static func suit_color() -> Variant:
	var id := Profile.career().equipped("suit")
	return Career.COSMETICS[id].color if not id.is_empty() else null


static func paint_color() -> Variant:
	var id := Profile.career().equipped("paint")
	return Career.COSMETICS[id].color if not id.is_empty() else null


static func title() -> String:
	var id := Profile.career().equipped("title")
	return str(Career.COSMETICS[id].name) if not id.is_empty() else ""
