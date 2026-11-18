class_name TouchControls
extends Control
## On-screen touch controls with finger ownership classes (PLAN §3.11):
## 1. move finger: floating joystick on the left; the gait chips (walk, jog,
##    run, crouch: a column on the left edge) set how fast a full push goes
## 2. look fingers: started on empty space on the right
## 3. fire finger: combined fire + look; dragging it also turns the camera
## 4. button fingers: all other buttons, exclusive, never become look fingers
## Layout: the right-hand buttons form one thumb cluster around Fire,
## anchored to the bottom-right corner and measured in screen heights, so it
## keeps its shape on 16:9 and 20:9 screens alike: Jump in the corner where
## the thumb rests, Crouch below Fire, Scope (a toggle) on its left, Grenade
## above Jump. Kept to the essentials: tapping a weapon chip in the HUD
## switches to it, tapping the ammo counter reloads (empty magazines reload
## on their own), and firing at an enemy within arm's reach melees. Icons
## only, each a picture of the action.
## Layout editor (PLAN §3.11): each button's position and size can be
## overridden (settings input/touch_layout) and all share an opacity; in
## `editing` mode fingers (or the mouse) drag buttons instead of playing.

signal selection_changed(id: String)

enum Kind { MOVE, LOOK, FIRE, BUTTON }

const LOOK_RADIANS_PER_PIXEL := 0.0045
const JOYSTICK_RADIUS := 110.0

var input: InputAdapter
## Aim assist slowdown on look fingers (AimAssist.slowdown).
var assist_scale: float = 1.0
## The scope button's toggle: holds aim until tapped again. The match turns
## it off on death.
var scope_on: bool = false:
	set(v):
		if v != scope_on:
			scope_on = v
			if input != null:
				if v:
					input.touch_held |= PlayerCommand.Held.AIM
				else:
					input.touch_held &= ~PlayerCommand.Held.AIM
			queue_redraw()
## Taps that miss every button go here first (Hud.touch_target): returns
## "slot:N", "reload" or "".
var hud_target: Callable
## (pos) -> bool: true when overlay UI owns that touch (no look, move or button).
var ui_blocks: Callable
## True while on-screen controls are showing (prompts then name no keys).
static var on_screen: bool = false
## Buttons left off the screen (THE HUNT's peaceful open world hides the
## weapon buttons: fire, scope, grenade, crouch).
var hidden_ids: Array = []
## The interact button shows only while something can be picked up.
var show_interact: bool = false:
	set(v):
		if v != show_interact:
			show_interact = v
			queue_redraw()

## Driving a rover (THE HUNT): car controls instead of the stick and the
## weapon buttons: steering arrows under the left thumb, the gas and brake
## pedals under the right (brake held at a stop reverses). The camera still
## turns with a drag on empty space; the context button gets you out.
var driving: bool = false:
	set(v):
		if v != driving:
			release_all()
			driving = v
			_drive_axes = {}
			if input != null:
				input.touch_move = Vector2.ZERO
			queue_redraw()
var _drive_axes := {}  ## finger index -> control id held
## Flying (an aircraft from the Skyport): climb and descend buttons too.
var flying: bool = false:
	set(v):
		if v != flying:
			flying = v
			queue_redraw()
const FLY := {
	"climb": ["left", Vector2(0.16, 0.5), Vector2(0.085, 0.085)],
	"dive": ["left", Vector2(0.42, 0.5), Vector2(0.085, 0.085)],
}


func _drive_ids() -> Array:
	return DRIVE.keys() + (FLY.keys() if flying else [])
## id -> [anchor ("left"/"right"), offset in screen heights from that bottom
## corner, size in screen heights]: circles for steering, tall pedals.
const DRIVE := {
	"steer_left": ["left", Vector2(0.16, 0.2), Vector2(0.11, 0.11)],
	"steer_right": ["left", Vector2(0.42, 0.2), Vector2(0.11, 0.11)],
	"gas": ["right", Vector2(0.12, 0.22), Vector2(0.15, 0.34)],
	"brake": ["right", Vector2(0.33, 0.17), Vector2(0.15, 0.24)],
}


## A drive control's rectangle on screen.
func _drive_rect(id: String) -> Rect2:
	var screen := _screen()
	var d: Array = DRIVE[id] if DRIVE.has(id) else FLY[id]
	var size: Vector2 = (d[2] as Vector2) * screen.y
	var off: Vector2 = (d[1] as Vector2) * screen.y
	var c := Vector2(off.x, screen.y - off.y) if d[0] == "left" else Vector2(screen.x - off.x, screen.y - off.y)
	if d[0] == "left":
		return Rect2(c - size, size * 2.0)
	return Rect2(c - size * 0.5, size)


func _drive_at(pos: Vector2) -> String:
	for id: String in _drive_ids():
		if _drive_rect(id).grow(_screen().y * 0.02).has_point(pos):
			return id
	return ""


func _apply_drive() -> void:
	var held := _drive_axes.values()
	input.touch_move = Vector2((1.0 if "steer_right" in held else 0.0) - (1.0 if "steer_left" in held else 0.0),
			(1.0 if "gas" in held else 0.0) - (1.0 if "brake" in held else 0.0))
	input.touch_held = (PlayerCommand.Held.JUMP if "climb" in held else 0) | (PlayerCommand.Held.CROUCH if "dive" in held else 0)
	queue_redraw()


func _draw_drive() -> void:
	var s := _screen().y
	for id: String in _drive_ids():
		var r := _drive_rect(id)
		var on := id in _drive_axes.values()
		if FLY.has(id):
			var cc := r.get_center()
			var rr := r.size.x * 0.5
			_sb.circle(cc + Vector2(4, 5), rr, Color(ComicUI.MAGENTA.darkened(0.6), 0.55))
			_sb.circle(cc, rr * (0.94 if on else 1.0), Color(ComicUI.CYAN, 0.55) if on else Color(ComicUI.INK, 0.62))
			_sb.arc(cc, rr, 0.0, TAU, 48, ComicUI.INK, 6.0)
			_sb.arc(cc, rr - 3.0, 0.0, TAU, 48, ComicUI.CYAN, 2.5)
			var up := -1.0 if id == "climb" else 1.0
			_sb.colored_polygon(PackedVector2Array([cc + Vector2(0, up * rr * 0.5), cc + Vector2(-rr * 0.42, -up * rr * 0.25),
					cc + Vector2(rr * 0.42, -up * rr * 0.25)]), Color(1, 1, 1, 0.9))
			ComicUI.draw_text(self, cc + Vector2(0, rr + s * 0.03), tr("TOUCH_CLIMB" if id == "climb" else "TOUCH_DIVE"),
					UiStyle.font_hud_bold, roundi(s * 0.026), Color(1, 1, 1, 0.9), 1, 3)
			continue
		var accent: Color = ComicUI.GREEN if id == "gas" else (ComicUI.RED if id == "brake" else ComicUI.YELLOW)
		var fill := Color(accent, 0.55) if on else Color(ComicUI.INK, 0.62)
		if id.begins_with("steer"):
			var c := r.get_center()
			var rad := r.size.x * 0.5
			_sb.circle(c + Vector2(4, 5), rad, Color(ComicUI.MAGENTA.darkened(0.6), 0.55))
			_sb.circle(c, rad * (0.94 if on else 1.0), fill)
			_sb.arc(c, rad, 0.0, TAU, 48, ComicUI.INK, 6.0)
			_sb.arc(c, rad - 3.0, 0.0, TAU, 48, accent, 2.5)
			var dir := -1.0 if id == "steer_left" else 1.0
			_sb.colored_polygon(PackedVector2Array([c + Vector2(dir * rad * 0.5, 0), c + Vector2(-dir * rad * 0.25, -rad * 0.42),
					c + Vector2(-dir * rad * 0.25, rad * 0.42)]), Color(1, 1, 1, 0.9))
		else:
			var q := ComicUI.quad(r, r.size.y * 0.08)
			var sh := q.duplicate()
			for i in sh.size():
				sh[i] += Vector2(4, 5)
			_sb.colored_polygon(sh, Color(ComicUI.MAGENTA.darkened(0.6), 0.55))
			_sb.colored_polygon(q, fill)
			var line := q.duplicate()
			line.append(q[0])
			_sb.polyline(line, ComicUI.INK, 6.0)
			_sb.polyline(line, accent, 2.5)
			for k in 4:  # the pedal's tread
				var y := r.position.y + r.size.y * (0.25 + k * 0.15)
				_sb.line(Vector2(r.position.x + r.size.x * 0.22, y), Vector2(r.end.x - r.size.x * 0.12, y), Color(1, 1, 1, 0.5), 3.0)
			ComicUI.draw_text(self, Vector2(r.get_center().x, r.end.y - s * 0.02), tr("TOUCH_GAS" if id == "gas" else "TOUCH_BRAKE"),
					UiStyle.font_hud_big, roundi(s * 0.032), Color(1, 1, 1, 0.95), 1, 4)


## Buttons: `pos` is the centre's offset from the bottom-right corner and
## `radius` its size, both in screen heights. `press` actions fire on touch,
## `held` flags stay set while the finger is down.
const DEFAULT_BUTTONS := [
	{"id": "fire", "label": "TOUCH_FIRE", "pos": Vector2(0.27, 0.31), "radius": 0.1, "kind": Kind.FIRE},
	{"id": "jump", "label": "TOUCH_JUMP", "pos": Vector2(0.09, 0.12), "radius": 0.075, "press": PlayerCommand.Action.JUMP, "held": PlayerCommand.Held.JUMP},
	{"id": "scope", "label": "TOUCH_SCOPE", "pos": Vector2(0.48, 0.26), "radius": 0.065, "toggle": PlayerCommand.Held.AIM},
	{"id": "grenade", "label": "TOUCH_GRENADE", "pos": Vector2(0.09, 0.36), "radius": 0.055, "press": PlayerCommand.Action.GRENADE},
	{"id": "interact", "label": "TOUCH_INTERACT", "pos": Vector2(0.44, 0.49), "radius": 0.06, "press": PlayerCommand.Action.INTERACT,
			"contextual": true},
]
## Saved layouts older than this are dropped for the new defaults (v1 used
## fractions of the screen, v2 had Reload, Swap and Melee buttons).
const LAYOUT_VERSION := 4
## Gait selector: a row along the bottom between the stick and the jump
## button (walk, jog, run, crouch), GAIT_RADIUS screen heights wide, the first
## centre GAIT_X from the left edge and GAIT_DX apart, GAIT_Y up from the
## bottom (all in screen heights). Not part of the layout editor.
const GAIT_X := 0.6
const GAIT_DX := 0.105
const GAIT_Y := 0.07
const GAIT_RADIUS := 0.04
const GAIT_IDS := ["walk", "jog", "run", "crouch"]
const GAIT_OF := {"walk": InputAdapter.Gait.WALK, "jog": InputAdapter.Gait.JOG, "run": InputAdapter.Gait.RUN}
const GAIT_LABEL := {"walk": "TOUCH_WALK", "jog": "TOUCH_JOG", "run": "TOUCH_RUN"}
## Crouch (a toggle on the gait column): holds the crouch while on.
var crouch_on: bool = false:
	set(v):
		if v != crouch_on:
			crouch_on = v
			if input != null:
				if v:
					input.touch_held |= PlayerCommand.Held.CROUCH
				else:
					input.touch_held &= ~PlayerCommand.Held.CROUCH
			queue_redraw()
## Where the floating stick's resting hint sits: offset from the
## bottom-left corner, in screen heights.
const STICK_HINT := Vector2(0.17, 0.28)
const MIN_SCALE := 0.6
const ICONS := {
	"fire": preload("res://art/ui/touch/fire.png"),
	"scope": preload("res://art/ui/touch/scope.png"),
	"jump": preload("res://art/ui/touch/jump.png"),
	"crouch": preload("res://art/ui/touch/crouch.png"),
	"grenade": preload("res://art/ui/touch/grenade.png"),
	"interact": preload("res://art/ui/touch/interact.png"),
}
const MAX_SCALE := 1.8

var editing: bool = false
var selected: String = ""
var _buttons: Array = []  ## DEFAULT_BUTTONS with the layout applied
var _drag_offset := Vector2.ZERO
var _fingers: Dictionary = {}  ## index -> {kind, origin, pos, button}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # icons drawn well below 256 px
	visible = DisplayServer.is_touchscreen_available()
	apply_layout(Settings.get_value("input", "touch_layout"))
	modulate.a = float(Settings.get_value("input", "touch_opacity"))
	Events.settings_changed.connect(func(section: String, key: String, value: Variant) -> void:
		if section == "input" and key == "touch_layout":
			apply_layout(value)
		elif section == "input" and key == "touch_opacity":
			modulate.a = float(value))
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw.call_deferred()


## Layout uses the viewport size directly: this control's own size can still
## be zero on the first frame.
func _screen() -> Vector2:
	return get_viewport_rect().size


## Buttons from the defaults with `layout` ({v, id: [x, y, scale]}, x and y
## as in DEFAULT_BUTTONS) applied.
func apply_layout(layout: Variant) -> void:
	_buttons = []
	var valid: bool = layout is Dictionary and int(layout.get("v", 1)) == LAYOUT_VERSION
	for d: Dictionary in DEFAULT_BUTTONS:
		var b := d.duplicate()
		b["base_radius"] = d.radius
		b["scale"] = 1.0
		if valid and layout.has(d.id) and layout[d.id] is Array and (layout[d.id] as Array).size() == 3:
			var o: Array = layout[d.id]
			b.pos = _clamp_offset(Vector2(o[0], o[1]))
			b.scale = clampf(o[2], MIN_SCALE, MAX_SCALE)
			b.radius = d.radius * b.scale
		_buttons.append(b)
	queue_redraw()


## Keeps a corner offset on a 16:9 screen or wider.
static func _clamp_offset(o: Vector2) -> Vector2:
	return Vector2(clampf(o.x, 0.04, 1.7), clampf(o.y, 0.04, 0.96))


## The current layout, for saving: {v, id: [x, y, scale]}.
func layout() -> Dictionary:
	var out := {"v": LAYOUT_VERSION}
	for b: Dictionary in _buttons:
		out[b.id] = [b.pos.x, b.pos.y, b.scale]
	return out


## A button's centre on screen.
func _center(b: Dictionary) -> Vector2:
	var screen := _screen()
	return screen - (b.pos as Vector2) * screen.y


func set_scale_of(id: String, value: float) -> void:
	for b: Dictionary in _buttons:
		if b.id == id:
			b.scale = clampf(value, MIN_SCALE, MAX_SCALE)
			b.radius = b.base_radius * b.scale
	queue_redraw()


func scale_of(id: String) -> float:
	for b: Dictionary in _buttons:
		if b.id == id:
			return b.scale
	return 1.0


func _edit_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventScreenTouch and event.pressed) or \
			(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	var up: bool = (event is InputEventScreenTouch and not event.pressed) or \
			(event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)
	var drag: bool = event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT)
	if down:
		var b := _button_at(event.position)
		if not b.is_empty():
			selected = b.id
			_drag_offset = _center(b) - event.position
			selection_changed.emit(selected)
			get_viewport().set_input_as_handled()
		else:
			selected = ""
	elif drag and not selected.is_empty():
		for b: Dictionary in _buttons:
			if b.id == selected:
				var screen := _screen()
				b.pos = _clamp_offset((screen - (event.position + _drag_offset)) / screen.y)
		get_viewport().set_input_as_handled()
	elif up:
		_drag_offset = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if editing:
		_edit_input(event)
		return
	if not visible or input == null or not input.enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_down(event.index, event.position)
		else:
			_on_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.relative)
		get_viewport().set_input_as_handled()


func release_all() -> void:
	for index in _fingers.keys():
		_on_up(index)
	scope_on = false
	crouch_on = false


func _on_down(index: int, pos: Vector2) -> void:
	# Taps on overlay UI (THE HUNT's phone) belong to that UI alone.
	if ui_blocks.is_valid() and ui_blocks.call(pos):
		return
	# The weapon chips are small and sit near the action buttons: a tap on
	# one switches weapon rather than pressing the button under it.
	var target: String = hud_target.call(pos) if hud_target.is_valid() else ""
	if target.begins_with("slot:") and _hud_tap(pos):
		_fingers[index] = {"kind": Kind.BUTTON, "origin": pos, "pos": pos, "button": {"id": "hud"}}
		queue_redraw()
		return
	if driving:
		var ctl := _drive_at(pos)
		if not ctl.is_empty():
			_drive_axes[index] = ctl
			_fingers[index] = {"kind": Kind.BUTTON, "origin": pos, "pos": pos, "button": {"id": "drive_" + ctl}}
			_apply_drive()
			return
		var b := _button_at(pos)
		if not b.is_empty() and b.id == "interact":
			input.press(b.press)
			_fingers[index] = {"kind": Kind.BUTTON, "origin": pos, "pos": pos, "button": b}
		else:
			_fingers[index] = {"kind": Kind.LOOK, "origin": pos, "pos": pos}
		queue_redraw()
		return
	var chip := gait_at(pos) if _gait_shown() else ""
	if not chip.is_empty():
		if chip == "crouch":
			crouch_on = not crouch_on
		else:
			input.gait = GAIT_OF[chip]
		_fingers[index] = {"kind": Kind.BUTTON, "origin": pos, "pos": pos, "button": {"id": "gait_" + chip}}
		queue_redraw()
		return
	var button := _button_at(pos)
	if not button.is_empty():
		var kind: int = button.get("kind", Kind.BUTTON)
		_fingers[index] = {"kind": kind, "origin": pos, "pos": pos, "button": button}
		if kind == Kind.FIRE:
			input.press(PlayerCommand.Action.FIRE)
			input.touch_held |= PlayerCommand.Held.FIRE
		elif button.has("toggle"):
			scope_on = not scope_on
		else:
			if button.has("press"):
				input.press(button.press)
			if button.has("held"):
				input.touch_held |= button.held
	elif _hud_tap(pos):
		_fingers[index] = {"kind": Kind.BUTTON, "origin": pos, "pos": pos, "button": {"id": "hud"}}
	elif pos.x < _screen().x * 0.4 and not _has_kind(Kind.MOVE):
		_fingers[index] = {"kind": Kind.MOVE, "origin": pos, "pos": pos}
	else:
		_fingers[index] = {"kind": Kind.LOOK, "origin": pos, "pos": pos}
	queue_redraw()


## Weapon panel taps: switch weapon or reload. True if the tap was used.
func _hud_tap(pos: Vector2) -> bool:
	var target: String = hud_target.call(pos) if hud_target.is_valid() else ""
	if target == "reload":
		input.press(PlayerCommand.Action.RELOAD)
	elif target.begins_with("slot:"):
		input.select_slot(target.get_slice(":", 1).to_int())
	return not target.is_empty()


func _on_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if not _fingers.has(index):
		return
	var f: Dictionary = _fingers[index]
	f.pos = pos
	match f.kind:
		Kind.MOVE:
			var v: Vector2 = (pos - f.origin) / JOYSTICK_RADIUS
			v = v.limit_length(1.0)
			input.touch_move = Vector2(v.x, -v.y)
		Kind.LOOK, Kind.FIRE:
			var sens: float = Settings.get_value("input", "touch_sensitivity") * assist_scale * input.look_scale
			input.add_look(-relative.x * LOOK_RADIANS_PER_PIXEL * sens,
					-relative.y * LOOK_RADIANS_PER_PIXEL * sens)
	queue_redraw()


func _on_up(index: int) -> void:
	if not _fingers.has(index):
		return
	var f: Dictionary = _fingers[index]
	_fingers.erase(index)
	if _drive_axes.has(index):
		_drive_axes.erase(index)
		_apply_drive()
		return
	match f.kind:
		Kind.MOVE:
			input.touch_move = Vector2.ZERO
		Kind.FIRE:
			input.touch_held &= ~PlayerCommand.Held.FIRE
		Kind.BUTTON:
			if f.button.has("held"):
				input.touch_held &= ~int(f.button.held)
	queue_redraw()


## A gait chip's centre on screen.
func _gait_center(id: String) -> Vector2:
	var screen := _screen()
	return Vector2((GAIT_X + GAIT_DX * GAIT_IDS.find(id)) * screen.y, screen.y * (1.0 - GAIT_Y))


## The id of the gait chip under `pos` (generous, like the buttons) or "".
func gait_at(pos: Vector2) -> String:
	var r := _screen().y * GAIT_RADIUS * 1.2
	for id: String in GAIT_IDS:
		if pos.distance_to(_gait_center(id)) <= r:
			return id
	return ""


func _gait_shown() -> bool:
	return not driving and not editing


func _button_at(pos: Vector2) -> Dictionary:
	var screen := _screen()
	for b in _buttons:
		if b.get("contextual", false) and not show_interact and not editing:
			continue
		if b.id in hidden_ids and not editing:
			continue
		if pos.distance_to(_center(b)) <= b.radius * screen.y * 1.15:
			return b
	return {}


func _has_kind(kind: int) -> bool:
	for f in _fingers.values():
		if f.kind == kind:
			return true
	return false


func _is_pressed(button: Dictionary) -> bool:
	for f in _fingers.values():
		if f.has("button") and f.button.id == button.id:
			return true
	return false


## Shapes first, then the icons and text (2D batching: a button's circle,
## icon and circle again in turn cost a draw call each).
var _icons: Array = []  ## [texture, rect, colour] queued during _draw
var _queue_icons: bool = false


var _sb: ShapeBatch  ## circles, rings and arrows: one draw call


func _draw() -> void:
	if _sb == null:
		_sb = ShapeBatch.new(self)
	_sb.begin()
	_icons.clear()
	_queue_icons = true
	ComicUI.begin_text_batch(self, _sb)
	_draw_controls()
	_queue_icons = false
	_icons.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Texture2D).get_instance_id() < (b[0] as Texture2D).get_instance_id())
	for i: Array in _icons:
		draw_texture_rect(i[0], i[1], false, i[2])
	_icons.clear()
	ComicUI.flush_text_batch(self)
	_sb.flush()


func _draw_controls() -> void:
	var screen := _screen()
	if driving and not editing:
		_draw_drive()
		for b in _buttons:
			if b.id == "interact" and show_interact:
				var c := _center(b)
				var r: float = b.radius * screen.y
				_sb.circle(c, r, Color(ComicUI.INK, 0.62))
				_sb.arc(c, r, 0.0, TAU, 48, ComicUI.INK, 6.0)
				_sb.arc(c, r - 3.0, 0.0, TAU, 48, ComicUI.GREEN, 2.5)
				_icon(b.id, c, r * 0.66, Color(1, 1, 1, 0.9))
		return
	for b in _buttons:
		if b.get("contextual", false) and not show_interact and not editing:
			continue
		if b.id in hidden_ids and not editing:
			continue
		var center := _center(b)
		var r: float = b.radius * screen.y
		var pressed: bool = _is_pressed(b) or (b.has("toggle") and scope_on)
		# ComicUI: ink discs with a hard shadow and an accent ring (fire in
		# magenta, the context action in green, the rest in yellow).
		var accent: Color = ComicUI.MAGENTA if b.id == "fire" else ComicUI.YELLOW
		if b.get("contextual", false):
			accent = ComicUI.GREEN
		if pressed:
			r *= 0.94  # a slight push-in
		_sb.circle(center + Vector2(4, 5), r, Color(ComicUI.MAGENTA.darkened(0.6), 0.55))
		_sb.circle(center, r, Color(accent, 0.55) if pressed else Color(ComicUI.INK, 0.62))
		_sb.arc(center, r, 0.0, TAU, 48, ComicUI.INK, 6.0)
		_sb.arc(center, r - 3.0, 0.0, TAU, 48, Color(accent, 1.0 if pressed else 0.85), 3.0 if b.id == "fire" else 2.5)
		if b.id == "fire":
			_sb.arc(center, r * 0.8, 0.0, TAU, 48, Color(accent, 0.35), 2.0)
		_icon(b.id, center, r * (0.5 if b.id == "fire" else 0.66), Color(1, 1, 1, 0.95 if pressed else 0.88))
		if editing and b.id == selected:
			_sb.arc(center, r + 8.0, 0.0, TAU, 48, UiStyle.WARN, 3.0)
	if _gait_shown():
		_draw_gait(screen)
	var moving := false
	for f in _fingers.values():
		if f.kind == Kind.MOVE:
			moving = true
			var offset: Vector2 = (f.pos - f.origin).limit_length(JOYSTICK_RADIUS)
			_sb.circle(f.origin, JOYSTICK_RADIUS, Color(ComicUI.INK, 0.35))
			_sb.arc(f.origin, JOYSTICK_RADIUS, 0.0, TAU, 64, Color(ComicUI.YELLOW, 0.6), 3.0)
			_sb.circle(f.origin + offset, 36.0, Color(ComicUI.YELLOW, 0.45))
			_sb.arc(f.origin + offset, 36.0, 0.0, TAU, 40, Color(1, 1, 1, 0.5), 2.0)
	if not moving:
		# Ghost stick where the left thumb rests (it floats: any touch on the
		# left side starts it), with the sprint notch on top.
		var hint := Vector2(STICK_HINT.x * screen.y, screen.y * (1.0 - STICK_HINT.y))
		_sb.circle(hint, JOYSTICK_RADIUS * 0.8, Color(ComicUI.INK, 0.28))
		_sb.arc(hint, JOYSTICK_RADIUS * 0.8, 0.0, TAU, 48, Color(ComicUI.YELLOW, 0.45), 2.5)
		_sb.circle(hint, 30.0, Color(ComicUI.YELLOW, 0.22))
		_sb.arc(hint, 30.0, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 1.5)


func _draw_gait(screen: Vector2) -> void:
	var r := GAIT_RADIUS * screen.y
	for id: String in GAIT_IDS:
		var c := _gait_center(id)
		var on: bool = crouch_on if id == "crouch" else (input != null and input.gait == GAIT_OF[id])
		var accent: Color = ComicUI.CYAN if id == "crouch" else ComicUI.YELLOW
		_sb.circle(c + Vector2(3, 4), r, Color(ComicUI.MAGENTA.darkened(0.6), 0.55))
		_sb.circle(c, r, Color(accent, 0.55) if on else Color(ComicUI.INK, 0.62))
		_sb.arc(c, r, 0.0, TAU, 40, ComicUI.INK, 5.0)
		_sb.arc(c, r - 2.5, 0.0, TAU, 40, Color(accent, 1.0 if on else 0.7), 2.5)
		if id == "crouch":
			_icon("crouch", c, r * 0.62, Color(1, 1, 1, 0.95 if on else 0.8))
		else:
			ComicUI.draw_text(self, c + Vector2(0, r * 0.2), tr(GAIT_LABEL[id]), UiStyle.font_hud_bold,
					roundi(r * 0.62), Color(1, 1, 1, 0.98 if on else 0.8), 1, 3)


## Icons that picture the action, so buttons read without text: white
## masks tinted when drawn (art/ui/touch; sources in art/ASSETS.csv). `s` is
## about the icon's half-size.
func _icon(id: String, c: Vector2, s: float, col: Color) -> void:
	var tex: Texture2D = ICONS.get(id)
	if tex == null:
		_sb.circle(c, s * 0.3, col)
		return
	if _queue_icons:
		_icons.append([tex, Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), col])
		return
	draw_texture_rect(tex, Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false, col)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE:
		on_screen = is_visible_in_tree()
	elif what == NOTIFICATION_EXIT_TREE:
		on_screen = false
