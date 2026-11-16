class_name GaragePanel
extends Control
## Joe's Respray & Chop (ComicUI): opens when you stop a rover in the bay.
## A respray loses the Marshals (if none of them sees you come in), the chop
## shop buys a rover that isn't yours (its hold goes to your pack), and any
## rover can be refuelled and repaired for cash. The city does the work
## (`act` -> CityMode); this shows the choices and their prices.

signal closed
signal act(what: String)

var _title: Label
var _line: Label
var _buttons: VBoxContainer
## What the city tells us: {"stars", "seen", "fuel", "condition", "chop" (kind
## or ""), "hot" (seconds till the chop shop takes it again), "wallet"}.
var info: Dictionary = {}
var note: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.01, 0.07, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ComicUI.box(Color(ComicUI.INK, 0.94), ComicUI.YELLOW, 4, 0.04))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -360
	panel.offset_bottom = -24
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	panel.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	row.add_child(left)
	_title = Label.new()
	_title.add_theme_font_override("font", UiStyle.font_hud_big)
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", ComicUI.YELLOW)
	_title.text = tr("GARAGE_NAME").to_upper()
	left.add_child(_title)
	_line = Label.new()
	_line.add_theme_font_override("font", UiStyle.font_hud_bold)
	_line.add_theme_font_size_override("font_size", 26)
	_line.add_theme_color_override("font_color", ComicUI.PAPER)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.x = 390
	left.add_child(_line)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.add_theme_constant_override("separation", 8)
	row.add_child(_buttons)


## Another counter using this panel (Kasei Motors' showroom): a title, a
## line, and [text, enabled, accent, id] options (`act` gets the id).
var _menu: Array = []


func open_menu(title: String, line: String, options: Array) -> void:
	_menu = options
	_title.text = title.to_upper()
	_line.text = line
	visible = true
	_menu_buttons()


func set_menu(line: String, options: Array) -> void:
	_menu = options
	_line.text = line
	_menu_buttons()


func _menu_buttons() -> void:
	for b in _buttons.get_children():
		_buttons.remove_child(b)
		b.queue_free()
	for o: Array in _menu:
		_button(o[0], o[1], o[2], o[3])
	_button(tr("TALK_LEAVE"), true, ComicUI.PAPER, "leave")


func open(p_info: Dictionary) -> void:
	_menu = []
	_title.text = tr("GARAGE_NAME").to_upper()
	info = p_info
	note = ""
	visible = true
	refresh()


func refresh() -> void:
	if not _menu.is_empty():
		_menu_buttons()
		return
	for b in _buttons.get_children():
		_buttons.remove_child(b)
		b.queue_free()
	var wallet: int = info.get("wallet", 0)
	var stars: int = info.get("stars", 0)
	var lines := PackedStringArray([tr("GARAGE_LINE") % [roundi(info.get("fuel", 0.0)), roundi(info.get("condition", 0.0))]])
	if not note.is_empty():
		lines.append(note)
	_line.text = "\n".join(lines)
	if stars > 0:
		var cost := Profile.career().respray_cost(stars)
		var seen: bool = info.get("seen", false)
		_button(tr("GARAGE_RESPRAY_SEEN") if seen else tr("GARAGE_RESPRAY") % cost, not seen and wallet >= cost,
				ComicUI.MAGENTA, "respray")
	var kind: String = info.get("chop", "")
	if not kind.is_empty():
		var hot: int = info.get("hot", 0)
		_button(tr("GARAGE_CHOP_HOT") % ceili(hot / 60.0) if hot > 0 else tr("GARAGE_CHOP") % Career.CHOP_PRICE[kind],
				hot <= 0, ComicUI.RED, "chop")
	var fuel_cost := ceili((100.0 - float(info.get("fuel", 100.0))) * Career.GARAGE_FUEL)
	_button(tr("GARAGE_FUEL") % fuel_cost, fuel_cost > 0 and wallet >= fuel_cost, ComicUI.CYAN, "fuel")
	var fix_cost := ceili((100.0 - float(info.get("condition", 100.0))) * Career.GARAGE_REPAIR)
	_button(tr("GARAGE_REPAIR") % fix_cost, fix_cost > 0 and wallet >= fix_cost, ComicUI.GREEN, "repair")
	_button(tr("TALK_LEAVE"), true, ComicUI.PAPER, "leave")


func _button(text: String, enabled: bool, accent: Color, what: String) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 58
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ComicUI.style_button(b, accent, 25, UiStyle.font_hud_bold)
	b.pressed.connect(func() -> void:
		if what == "leave":
			visible = false
			closed.emit()
		else:
			act.emit(what))
	_buttons.add_child(b)
