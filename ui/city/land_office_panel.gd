class_name LandOfficePanel
extends Control
## The land office (ComicUI): every plot with its zone, size and price; buy,
## sell, build from the Titan module catalogue, see build time, tenants and
## rent; list a finished building for other players. Works on LandOffice
## state: open(land_state, holder_with_wallet, now).

signal closed
signal changed  ## something was bought/sold/built: re-place buildings, save

var _s: Dictionary
var _holder: Dictionary
var _now := 0
var _list: VBoxContainer
var _head: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.01, 0.07, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ComicUI.box(Color(ComicUI.INK, 0.95), ComicUI.YELLOW, 4, 0.04))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -340
	panel.offset_bottom = 340
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(_label("LAND OFFICE", 46, ComicUI.YELLOW, UiStyle.font_hud_big))
	_head = _label("", 22, ComicUI.CYAN)
	col.add_child(_head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	col.add_child(_button("LEAVE", ComicUI.PAPER, _on_leave))


func _label(text: String, px: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font if font else UiStyle.font_hud_bold)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, accent: Color, action: Callable, enabled: bool = true) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(150, 50)
	ComicUI.style_button(btn, accent, 20, UiStyle.font_hud_bold)
	btn.pressed.connect(action)
	return btn


func open(land_state: Dictionary, holder: Dictionary, now: int) -> void:
	_s = land_state
	_holder = holder
	_now = now
	LandOffice.settle(_s, _holder, _now)
	visible = true
	refresh()


func refresh() -> void:
	_head.text = "Wallet %d   ·   rent collected %d" % [int(_holder.wallet), int(_s.income)]
	for n in _list.get_children():
		_list.remove_child(n)
		n.queue_free()
	for id: String in LandOffice.PLOTS:
		_list.add_child(_row(id))


func _row(id: String) -> Control:
	var info: Dictionary = LandOffice.PLOTS[id]
	var box := PanelContainer.new()
	var accent := {"residential": ComicUI.CYAN, "commercial": ComicUI.MAGENTA, "industrial": ComicUI.YELLOW}[info.zone]
	box.add_theme_stylebox_override("panel", ComicUI.box(ComicUI.PANEL, accent, 3, 0.04, false))
	var col := VBoxContainer.new()
	box.add_child(col)
	col.add_child(_label("PLOT %s  ·  %s  ·  %dm" % [id.to_upper(), str(info.zone).to_upper(), int(info.size)], 24, accent))
	col.add_child(_label(_status(id), 20, ComicUI.PAPER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	if not LandOffice.owned(_s, id):
		row.add_child(_button("BUY %d" % LandOffice.price(_s, id), ComicUI.GREEN, _act.bind("buy", id, ""),
			int(_holder.wallet) >= LandOffice.price(_s, id)))
		return box
	var p := LandOffice.plot(_s, id)
	if p.building == "":
		for b: String in LandOffice.BUILDINGS:
			if LandOffice.BUILDINGS[b].zone == info.zone:
				row.add_child(_button("BUILD %s %d" % [LandOffice.BUILDINGS[b].name, LandOffice.BUILDINGS[b].cost],
					ComicUI.YELLOW, _act.bind("build", id, b), LandOffice.can_build(_s, _holder, id, b) == ""))
	elif LandOffice.vacant(_s, id, _now):
		var listed := int(p.listed_rent) > 0
		var rent := int(LandOffice.BUILDINGS[p.building].rent)
		row.add_child(_button("UNLIST" if listed else "LIST %d/DAY" % rent, ComicUI.CYAN,
			_act.bind("list", id, "0" if listed else str(rent))))
	elif p.tenant_kind != "":
		row.add_child(_button("EVICT", ComicUI.RED, _act.bind("evict", id, "")))
	row.add_child(_button("SELL %d" % LandOffice.sale_value(_s, id, _now), ComicUI.MAGENTA, _act.bind("sell", id, "")))
	return box


func _status(id: String) -> String:
	if not LandOffice.owned(_s, id):
		return "For sale"
	var p := LandOffice.plot(_s, id)
	if p.building == "":
		return "Yours · empty lot"
	var b: Dictionary = LandOffice.BUILDINGS[p.building]
	var left := LandOffice.build_left(_s, id, _now)
	if left > 0:
		return "%s under construction · %.1f days left" % [b.name, float(left) / LandOffice.DAY]
	var who := "Vacant" if p.tenant == "" else "Tenant: %s (%s)" % [p.tenant, p.tenant_kind]
	if p.tenant == "" and int(p.listed_rent) > 0:
		who = "Listed for players at %d/day" % int(p.listed_rent)
	return "%s · %s · rent %d · upkeep %d per day" % [b.name, who, int(b.rent), int(b.upkeep)]


func _act(what: String, id: String, arg: String) -> void:
	match what:
		"buy": LandOffice.buy(_s, _holder, id, _now)
		"sell": LandOffice.sell(_s, _holder, id, _now)
		"build": LandOffice.build(_s, _holder, id, arg, _now)
		"list": LandOffice.list_for_players(_s, id, int(arg), _now)
		"evict": LandOffice.evict(_s, id, _now)
	changed.emit()
	refresh()


func _on_leave() -> void:
	visible = false
	closed.emit()
