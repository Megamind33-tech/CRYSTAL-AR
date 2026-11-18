class_name HuntMenu
extends Control
## THE HUNT's phone (the match keeps running). A round phone button by the
## radar, or the H key, slides a handset up at the bottom right: a home
## screen with the clock, your cash and four apps (JOBS, CREW, DEALS,
## INTEL); each app lists its actions as cards. Every card is a
## HuntRules.request(), the same entry point the bots use, so the phone
## only decides what to show; the rules validate everything.

const TABS := ["jobs", "camp", "squad", "crew", "deals", "intel"]
const PHONE_SIZE := Vector2(340, 600)
const APPS := {
	"jobs": {"color": Color("e5484d"), "glyph": "target"},
	"camp": {"color": Color("a16207"), "glyph": "rings"},
	"squad": {"color": Color("f59e0b"), "glyph": "people"},
	"crew": {"color": Color("3b82f6"), "glyph": "people"},
	"deals": {"color": Color("22b35e"), "glyph": "rings"},
	"intel": {"color": Color("8b5cf6"), "glyph": "eye"},
}

## Callables set by the match: request(action, args) -> bool, and state()
## -> {"hunt": HuntRules, "world": SimWorld, "me": int}.
var request: Callable
var state: Callable
## () -> Vector2: where the phone button sits (next to the radar).
var button_anchor: Callable

var _toggle: Button
var _panel: PanelContainer
var _home: Control
var _app: VBoxContainer
var _app_head: PanelContainer
var _app_title: Label
var _list: VBoxContainer
var _clock: Label
var _cash: Label
var _status_time: Label
var _tab: String = ""  ## "" = home screen
var _rows: Array = []  ## [Button, label Callable, action Callable, enabled Callable, tab]
var _was_captured := false
var _slide: float = 0.0  ## 0 = put away, 1 = up
var _open: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toggle = _PhoneButton.new()
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.custom_minimum_size = Vector2(64, 64)
	_toggle.size = Vector2(64, 64)
	_toggle.tooltip_text = tr("HUNT_PHONE_BUTTON")
	_toggle.pressed.connect(toggle)
	add_child(_toggle)

	_panel = PanelContainer.new()
	var bezel := StyleBoxFlat.new()
	bezel.bg_color = Color(0.03, 0.03, 0.035)
	bezel.set_corner_radius_all(44)
	bezel.border_color = Color(0.32, 0.3, 0.3)
	bezel.set_border_width_all(3)
	bezel.set_content_margin_all(12)
	bezel.shadow_color = Color(0, 0, 0, 0.5)
	bezel.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", bezel)
	_panel.size = PHONE_SIZE
	_panel.visible = false
	add_child(_panel)
	var screen := Control.new()
	screen.clip_contents = true
	_panel.add_child(screen)
	var wall := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color("2a1530"), Color("7a3420"), Color("d9793a")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8
	gt.height = 256
	wall.texture = gt
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(wall)
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_theme_constant_override("separation", 0)
	screen.add_child(body)
	# Status bar.
	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 34
	var pad_l := Control.new()
	pad_l.custom_minimum_size.x = 22
	bar.add_child(pad_l)
	_status_time = _label(UiStyle.font_hud_bold, 22, Color.WHITE)
	_status_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status_time)
	bar.add_child(_label(UiStyle.font_hud_bold, 20, Color.WHITE, "RUSTNET  5G   84%"))
	var pad_r := Control.new()
	pad_r.custom_minimum_size.x = 20
	bar.add_child(pad_r)
	body.add_child(bar)
	# Home screen: clock, cash, the app grid.
	_home = VBoxContainer.new()
	_home.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home.add_theme_constant_override("separation", 2)
	body.add_child(_home)
	var gap := Control.new()
	gap.custom_minimum_size.y = 22
	_home.add_child(gap)
	_clock = _label(UiStyle.font_hud_big, 76, Color.WHITE)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.add_child(_clock)
	var date := _label(UiStyle.font_hud_bold, 22, Color(1, 1, 1, 0.8), tr("HUNT_PHONE_DATE"))
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.add_child(date)
	_cash = _label(UiStyle.font_hud_big, 34, Color("8fe388"))
	_cash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_home.add_child(_cash)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home.add_child(spacer)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for t: String in TABS:
		var app := _AppButton.new()
		app.app_color = APPS[t].color
		app.glyph = APPS[t].glyph
		app.caption = tr("HUNT_TAB_" + t.to_upper())
		app.custom_minimum_size = Vector2(124, 128)
		app.focus_mode = Control.FOCUS_NONE
		app.pressed.connect(open_tab.bind(t))
		grid.add_child(app)
	_home.add_child(grid)
	var dock := Control.new()
	dock.custom_minimum_size.y = 30
	_home.add_child(dock)
	# App screen: a coloured header with a back arrow, then the cards.
	_app = VBoxContainer.new()
	_app.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_app.add_theme_constant_override("separation", 10)
	_app.visible = false
	body.add_child(_app)
	_app_head = PanelContainer.new()
	_app.add_child(_app_head)
	var head_row := HBoxContainer.new()
	_app_head.add_child(head_row)
	var back := Button.new()
	back.text = "‹"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(52, 52)
	back.add_theme_font_override("font", UiStyle.font_body_bold)
	back.add_theme_font_size_override("font_size", 40)
	back.pressed.connect(func() -> void: _show(""))
	head_row.add_child(back)
	_app_title = _label(UiStyle.font_hud_big, 34, Color.WHITE)
	_app_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(_app_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_app.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margin)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	margin.add_child(_list)
	var home_bar := Control.new()
	home_bar.custom_minimum_size.y = 14
	_app.add_child(home_bar)


func _label(f: Font, px: int, col: Color, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A card in app `tab`: `label` () -> String, `action` () -> void (it calls
## request), `enabled` () -> bool.
func add_row(label: Callable, action: Callable, enabled: Callable, tab: String = "jobs") -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", UiStyle.font_hud_bold)
	b.add_theme_font_size_override("font_size", 25)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.38))
	var col: Color = APPS.get(tab, APPS.jobs).color
	b.add_theme_stylebox_override("normal", _card(Color(0, 0, 0, 0.45), col))
	b.add_theme_stylebox_override("hover", _card(Color(0, 0, 0, 0.6), col))
	b.add_theme_stylebox_override("pressed", _card(Color(col, 0.9), col))
	b.add_theme_stylebox_override("disabled", _card(Color(0, 0, 0, 0.22), Color(1, 1, 1, 0.15)))
	b.pressed.connect(func() -> void:
		action.call()
		_refresh())
	_list.add_child(b)
	_rows.append([b, label, action, enabled, tab])


func toggle() -> void:
	_open = not _open
	if _open:
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show("")
	elif _was_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _open


## Opens straight into an app (a notification can send the player there).
func open_tab(tab: String) -> void:
	if not _open:
		toggle()
	_show(tab)


## True if a touch at `pos` belongs to the phone (so it isn't also a look
## drag or a fire press).
func blocks(pos: Vector2) -> bool:
	return _toggle.get_global_rect().grow(6).has_point(pos) or (_panel.visible and _panel.get_global_rect().has_point(pos))


func _show(tab: String) -> void:
	_tab = tab
	_home.visible = tab.is_empty()
	_app.visible = not tab.is_empty()
	if not tab.is_empty():
		_app_title.text = tr("HUNT_TAB_" + tab.to_upper())
		_app_head.add_theme_stylebox_override("panel", _round(APPS[tab].color, 0))
	_refresh()


func _process(delta: float) -> void:
	if button_anchor.is_valid():
		_toggle.position = button_anchor.call()
	_slide = move_toward(_slide, 1.0 if _open else 0.0, delta * 6.0)
	_panel.visible = _slide > 0.0
	if _panel.visible:
		var ease_v := 1.0 - pow(1.0 - _slide, 3.0)
		var top := size.y - PHONE_SIZE.y - 24.0
		_panel.position = Vector2(size.x - PHONE_SIZE.x - 36.0, lerpf(size.y + 20.0, top, ease_v))
		_panel.size = PHONE_SIZE
		if Engine.get_process_frames() % 10 == 0:
			_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		toggle()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var st: Dictionary = state.call() if state.is_valid() else {}
	if st.is_empty():
		return
	var h: HuntRules = st.hunt
	var world: SimWorld = st.world
	var secs := world.tick / Sim.TICK_RATE
	var clock := "%02d:%02d" % [(18 + secs / 60) % 24, secs % 60]
	_status_time.text = clock
	_clock.text = clock
	_cash.text = "$%d" % h.economy.credits.get(st.me, 0)
	for row: Array in _rows:
		var b: Button = row[0]
		b.visible = row[4] == _tab
		if b.visible:
			b.text = (row[1] as Callable).call()
			b.disabled = not (row[3] as Callable).call()


static func _round(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## A list card: dark glass with the app's colour as a stripe on the left.
static func _card(bg: Color, stripe: Color) -> StyleBoxFlat:
	var s := _round(bg, 14)
	s.border_color = stripe
	s.border_width_left = 6
	s.content_margin_left = 18
	return s


## The round phone button: a dark disc with a handset drawn on it.
class _PhoneButton extends Button:
	func _ready() -> void:
		flat = true
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.4))
		draw_circle(c, r, Color(0.05, 0.04, 0.04, 0.9) if not is_pressed() else Color(UiStyle.ACCENT_DEEP))
		draw_arc(c, r - 1.5, 0, TAU, 40, Color(1, 1, 1, 0.25), 2.0)
		var body := Rect2(c - Vector2(11, 19), Vector2(22, 38))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(5)
		draw_style_box(sb, body)
		draw_rect(Rect2(body.position + Vector2(3, 5), body.size - Vector2(6, 12)), Color(0.85, 0.42, 0.18))
		draw_circle(Vector2(c.x, body.end.y - 3.5), 1.8, Color(0.1, 0.1, 0.1))


## An app icon: a rounded tile in the app's colour with a drawn glyph and
## its name under it.
class _AppButton extends Button:
	var app_color := Color.WHITE
	var glyph: String = ""
	var caption: String = ""

	func _ready() -> void:
		flat = true
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		var tile := 92.0
		var r := Rect2(Vector2((size.x - tile) * 0.5, 4), Vector2(tile, tile))
		var sb := StyleBoxFlat.new()
		sb.bg_color = app_color.darkened(0.25) if is_pressed() else app_color
		sb.set_corner_radius_all(24)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
		draw_style_box(sb, r)
		var gloss := StyleBoxFlat.new()
		gloss.bg_color = Color(1, 1, 1, 0.12)
		gloss.corner_radius_top_left = 24
		gloss.corner_radius_top_right = 24
		draw_style_box(gloss, Rect2(r.position, Vector2(tile, tile * 0.45)))
		var c := r.get_center()
		var w := Color.WHITE
		match glyph:
			"target":
				draw_arc(c, 24, 0, TAU, 40, w, 5)
				draw_arc(c, 11, 0, TAU, 30, w, 4)
				for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(c + d * 18, c + d * 32, w, 4)
			"people":
				draw_circle(c + Vector2(-12, -10), 9, Color(w, 0.75))
				draw_circle(c + Vector2(12, -12), 11, w)
				_half_disc(c + Vector2(-12, 20), 15, Color(w, 0.75))
				_half_disc(c + Vector2(12, 20), 19, w)
			"rings":
				draw_arc(c + Vector2(-10, 0), 16, 0, TAU, 36, w, 5)
				draw_arc(c + Vector2(10, 0), 16, 0, TAU, 36, w, 5)
			"eye":
				var pts := PackedVector2Array()
				for i in 25:
					var t := -1.0 + i / 12.0
					pts.append(c + Vector2(t * 30, -cos(t * PI * 0.5) * 17))
				for i in range(1, 24):
					var t := 1.0 - i / 12.0
					pts.append(c + Vector2(t * 30, cos(t * PI * 0.5) * 17))
				draw_colored_polygon(pts, w)
				draw_circle(c, 11, app_color.darkened(0.1))
				draw_circle(c, 5, Color(0.05, 0.05, 0.08))
		var f: Font = UiStyle.font_hud_bold
		var px := 24
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := Vector2((size.x - tw) * 0.5, tile + 30)
		draw_string_outline(f, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, Color(0, 0, 0, 0.5))
		draw_string(f, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)

	func _half_disc(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 17:
			var a := PI + i * PI / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, col)
