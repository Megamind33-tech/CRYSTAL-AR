class_name ComicUI
extends RefCounted
## THE HUNT's interface kit, taken from the key art: angular panels with a
## heavy ink outline and a hard offset shadow, magenta / yellow / cyan on a
## deep violet, Anton for titles and Teko for labels. Style boxes for
## Controls and draw helpers for the HUD, so every screen matches.

const INK := Color("120914")
const VIOLET := Color("2a0f3a")
const PANEL := Color(0.09, 0.03, 0.12, 0.88)
const MAGENTA := Color("ff2d78")
const YELLOW := Color("ffd23f")
const CYAN := Color("3ee0ff")
const PAPER := Color("f4ead8")
const RED := Color("ff3b3b")
const GREEN := Color("7dff6a")
const SKEW := 0.18  ## panel slant (x per y)


## An angular comic panel: slanted, ink border, hard shadow.
static func box(fill: Color, border: Color = INK, width: int = 4, skew: float = SKEW, shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.skew = Vector2(skew, 0.0)
	s.anti_aliasing = true
	if shadow:
		s.shadow_color = Color(MAGENTA.darkened(0.55), 0.85)
		s.shadow_size = 1
		s.shadow_offset = Vector2(6, 7)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


## A button in the kit: dark panel, accent border; filled accent when pressed.
static func style_button(b: Button, accent: Color, size_px: int = 28, font: Font = null) -> void:
	b.add_theme_font_override("font", font if font != null else UiStyle.font_hud_big)
	b.add_theme_font_size_override("font_size", size_px)
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(k, PAPER)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(PAPER, 0.35))
	b.add_theme_stylebox_override("normal", box(PANEL, accent))
	b.add_theme_stylebox_override("hover", box(Color(accent, 0.25), accent))
	b.add_theme_stylebox_override("pressed", box(accent, INK))
	b.add_theme_stylebox_override("focus", box(Color(accent, 0.18), YELLOW))
	b.add_theme_stylebox_override("disabled", box(Color(PANEL, 0.6), Color(accent, 0.35), 3, SKEW, false))


# --- Draw helpers (CanvasItem) ---

## A slanted quad from `r` (top edge shifted right by `slant` px).
static func quad(r: Rect2, slant: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(slant, 0), Vector2(r.end.x + slant, r.position.y),
			r.end, Vector2(r.position.x, r.end.y)])


## Slanted panel with ink outline and hard shadow.
static func draw_panel(ci: CanvasItem, r: Rect2, fill: Color, border: Color = INK, width: float = 3.0,
		slant: float = -1.0, shadow: bool = true) -> void:
	var k := r.size.y * SKEW if slant < 0.0 else slant
	var q := quad(r, k)
	if shadow:
		var sh := q.duplicate()
		for i in sh.size():
			sh[i] += Vector2(5, 6)
		ci.draw_colored_polygon(sh, Color(MAGENTA.darkened(0.6), 0.8 * fill.a))
	ci.draw_colored_polygon(q, fill)
	var line := q.duplicate()
	line.append(q[0])
	ci.draw_polyline(line, border, width)


## Outlined text (ink outline) at baseline `pos`; `align` 0 left, 1 centre, 2 right.
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, font: Font, px: int, col: Color,
		align: int = 0, outline: int = 6) -> float:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if align == 1:
		pos.x -= w * 0.5
	elif align == 2:
		pos.x -= w
	if outline > 0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(INK, col.a))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	return w
