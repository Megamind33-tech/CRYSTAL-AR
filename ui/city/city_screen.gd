class_name CityScreen
extends Control
## Tharsis Gate, the protected city between deployments: the contract
## board, the market (sell what you extracted), the outfitter (gear for the
## next run), faction standing and the last run's report, then DEPLOY to
## the extraction zone. Every button goes through Career, which validates
## it; the profile is saved after each change. (First version of the city:
## these become NPC terminals in the walkable hub.)

signal deploy_requested
signal closed

const TABS := ["contracts", "market", "outfitter"]
const TAB_COLORS := {"contracts": ComicUI.MAGENTA, "market": ComicUI.GREEN, "outfitter": ComicUI.CYAN}
const CASH := ComicUI.GREEN

var _tab := "contracts"
var _wallet: Label
var _standing: Label
var _report: Label
var _list: VBoxContainer
var _tabs: Dictionary = {}
var _deploy: PlayButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.texture = load("res://art/ui/key_art_city.jpg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.01, 0.08, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36 if side != "top" else 24)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	# Left: the city, the wallet, standing, last run.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 420
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	var back := Button.new()
	back.text = "‹  " + tr("CITY_BACK")
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.add_theme_font_override("font", UiStyle.font_hud_bold)
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	left.add_child(back)
	left.add_child(_label(tr("CITY_NAME"), UiStyle.font_hud_big, 72, Color.WHITE))
	left.add_child(_label(tr("CITY_SUB"), UiStyle.font_hud_bold, 26, UiStyle.ACCENT))
	_wallet = _label("", UiStyle.font_hud_big, 54, CASH)
	left.add_child(_wallet)
	_standing = _label("", UiStyle.font_hud_bold, 24, Color(1, 1, 1, 0.85))
	left.add_child(_standing)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_report = _label("", UiStyle.font_hud_bold, 24, Color.WHITE)
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var report_box := PanelContainer.new()
	report_box.add_theme_stylebox_override("panel", _card(Color(0, 0, 0, 0.55), UiStyle.ACCENT))
	report_box.add_child(_report)
	left.add_child(report_box)
	# Right: the terminals and DEPLOY.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 10)
	right.add_child(tab_row)
	for t: String in TABS:
		var b := Button.new()
		b.text = tr("CITY_TAB_" + t.to_upper())
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 60
		ComicUI.style_button(b, TAB_COLORS[t], 28)
		b.pressed.connect(func() -> void:
			_tab = t
			refresh())
		tab_row.add_child(b)
		_tabs[t] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_deploy = PlayButton.new()
	_deploy.title = tr("CITY_DEPLOY")
	_deploy.size_flags_horizontal = Control.SIZE_SHRINK_END
	_deploy.pressed.connect(func() -> void: deploy_requested.emit())
	right.add_child(_deploy)
	refresh()


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	var c := Profile.career()
	_wallet.text = "$%d" % c.d.wallet
	var parts := PackedStringArray()
	for f: String in Career.FACTIONS:
		parts.append("%s %+d" % [Career.FACTIONS[f].short, c.standing(f)])
	_standing.text = "   ".join(parts)
	_report.text = _report_text(c)
	_deploy.subtitle = tr("CITY_DEPLOY_SUB") % (c.d.contract.title if not c.d.contract.is_empty() else tr("CITY_NO_CONTRACT"))
	_deploy.queue_redraw()
	for t: String in _tabs:
		var on := t == _tab
		(_tabs[t] as Button).add_theme_stylebox_override("normal", ComicUI.box(TAB_COLORS[t] if on else ComicUI.PANEL,
				ComicUI.INK if on else TAB_COLORS[t]))
		(_tabs[t] as Button).add_theme_color_override("font_color", ComicUI.INK if on else ComicUI.PAPER)
	for child in _list.get_children():
		child.queue_free()
	match _tab:
		"contracts":
			_fill_contracts(c)
		"market":
			_fill_market(c)
		"outfitter":
			_fill_outfitter(c)


func _report_text(c: Career) -> String:
	var r: Dictionary = c.d.get("last_report", {})
	if r.is_empty():
		return tr("CITY_REPORT_NONE")
	var items := PackedStringArray()
	for item: String in r.get("items", {}):
		items.append("%d× %s" % [int(r.items[item]), Career.ITEMS[item].name])
	var lines := [tr("CITY_REPORT_TITLE") % int(c.d.runs)]
	lines.append(tr("CITY_REPORT_LOOT") % (", ".join(items) if not items.is_empty() else tr("CITY_REPORT_EMPTY")))
	match str(r.get("contract", "")):
		"done":
			lines.append(tr("CITY_REPORT_DONE") % int(r.pay))
		"failed":
			lines.append(tr("CITY_REPORT_FAILED"))
	return "\n".join(lines)


func _fill_contracts(c: Career) -> void:
	if not c.d.contract.is_empty():
		var k: Dictionary = c.d.contract
		_row("%s\n%s" % [tr("CITY_ACTIVE") % k.title, k.brief], "", false, TAB_COLORS.contracts)
		_row(tr("CITY_ABANDON") % [Career.FACTIONS[k.faction].short, Career.FAIL_STANDING], "abandon", true,
				Color(1, 1, 1, 0.3), func() -> void: c.abandon())
	for k: Dictionary in c.offers():
		var text := "%s   $%d\n%s · %s" % [k.title, k.pay, Career.FACTIONS[k.faction].name, k.brief]
		_row(text, "", c.d.contract.is_empty(), TAB_COLORS.contracts, func() -> void: c.accept(k.id))


func _fill_market(c: Career) -> void:
	_row(tr("CITY_BUY_SUPPLY") % [Career.SUPPLY_PRICE, int(c.d.stash.get("supply_crate", 0))], "",
			c.d.wallet >= Career.SUPPLY_PRICE, TAB_COLORS.market, func() -> void: c.buy_supplies(1))
	if c.d.stash.is_empty():
		_row(tr("CITY_STASH_EMPTY"), "", false, TAB_COLORS.market)
	for item: String in c.d.stash:
		if not c.sellable(item):
			continue
		var n: int = c.d.stash[item]
		var p := c.price(item)
		var base: int = Career.ITEMS[item].base
		var trend := tr("CITY_PRICE_LOW") if p < base else (tr("CITY_PRICE_HIGH") if p > base else tr("CITY_PRICE_STEADY"))
		_row(tr("CITY_SELL") % [Career.ITEMS[item].name, n, p, trend], "", true, TAB_COLORS.market,
				func() -> void: c.sell(item, 1))


func _fill_outfitter(c: Career) -> void:
	for g: String in Career.GEAR:
		var lv: int = c.d.gear[g]
		var cost := c.gear_cost(g)
		var text := "%s  ·  level %d/%d\n%s" % [Career.GEAR[g].name, lv, Career.GEAR[g].levels.size(), Career.GEAR[g].per_level]
		if cost < 0:
			_row(text + "   " + tr("CITY_MAXED"), "", false, TAB_COLORS.outfitter)
		else:
			_row(text + "   $%d" % cost, "", c.d.wallet >= cost, TAB_COLORS.outfitter, func() -> void: c.buy_gear(g))


func _row(text: String, _id: String, enabled: bool, stripe: Color, action: Callable = Callable()) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.y = 78
	b.disabled = not enabled or not action.is_valid()
	b.add_theme_font_override("font", UiStyle.font_hud_bold)
	b.add_theme_font_size_override("font_size", 25)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.75 if not action.is_valid() else 0.4))
	b.add_theme_stylebox_override("normal", _card(Color(0, 0, 0, 0.55), stripe))
	b.add_theme_stylebox_override("hover", _card(Color(0, 0, 0, 0.7), stripe))
	b.add_theme_stylebox_override("pressed", _card(Color(stripe, 0.85), stripe))
	b.add_theme_stylebox_override("disabled", _card(Color(0, 0, 0, 0.35), Color(stripe, 0.4)))
	if action.is_valid():
		b.pressed.connect(func() -> void:
			action.call()
			Profile.save()
			refresh())
	_list.add_child(b)


func _label(text: String, f: Font, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", ComicUI.INK)
	l.add_theme_constant_override("outline_size", maxi(px / 6, 4))
	return l


## Panels in the ComicUI kit: slanted, ink-dark, outlined in the accent.
static func _card(bg: Color, stripe: Color) -> StyleBoxFlat:
	var s := ComicUI.box(Color(ComicUI.INK, maxf(bg.a, 0.72)) if bg.a < 0.8 else bg, stripe, 3, 0.08)
	s.content_margin_left = 26
	return s
