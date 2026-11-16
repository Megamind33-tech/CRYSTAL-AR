class_name PlayButton
extends Button
## THE HUNT's big home-screen button: a bright slab with the action in Anton
## ("PLAY") and a line under it, a pulsing edge, and a lift on hover/focus.

var title: String = ""
var subtitle: String = ""
var _time: float = 0.0


func _ready() -> void:
	flat = true
	custom_minimum_size = Vector2(440, 128)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# A slanted comic panel (ComicUI): yellow slab, ink outline, hard magenta
	# shadow; lifts on hover, dips when pressed.
	var lift := -4.0 if (is_hovered() or has_focus()) and not is_pressed() else (3.0 if is_pressed() else 0.0)
	var r := Rect2(Vector2(0, 10 + lift), size - Vector2(size.y * ComicUI.SKEW + 8, 14))
	var fill := ComicUI.YELLOW if not is_pressed() else ComicUI.MAGENTA
	ComicUI.draw_panel(self, r, fill, ComicUI.INK, 5.0)
	# A play arrow in an ink disc.
	var c := r.position + Vector2(62 + r.size.y * ComicUI.SKEW * 0.5, r.size.y * 0.5)
	draw_circle(c, 36, ComicUI.INK)
	draw_arc(c, 36, 0, TAU, 40, Color(ComicUI.MAGENTA, 0.6 + 0.4 * sin(_time * 3.0)), 3)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -17), c + Vector2(19, 0), c + Vector2(-11, 17)]), ComicUI.PAPER)
	var x := r.position.x + 122 + r.size.y * ComicUI.SKEW * 0.5
	ComicUI.draw_text(self, Vector2(x, r.position.y + 70), title, UiStyle.font_hud_big, 58, ComicUI.INK, 0, 0)
	ComicUI.draw_text(self, Vector2(x + 2, r.position.y + 103), subtitle, UiStyle.font_hud_bold, 25, ComicUI.INK, 0, 0)
