class_name PathPick
extends Control
## After arrival: work with the government or freelance (Arrival.PATHS).

signal chosen(path: String)

const TEXT := {"government": ["PATH_GOVERNMENT", "PATH_GOVERNMENT_SUB", Color(0.16, 0.78, 1.0)],
		"freelance": ["PATH_FREELANCE", "PATH_FREELANCE_SUB", Color(1.0, 0.76, 0.12)]}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(ComicUI.INK, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	center.add_child(col)
	var title := Label.new()
	title.text = tr("PATH_TITLE")
	title.add_theme_font_override("font", UiStyle.font_hud_big)
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", ComicUI.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	for p: String in Arrival.PATHS:
		var b := Button.new()
		b.name = "Path_%s" % p
		b.custom_minimum_size = Vector2(300, 200)
		b.text = "%s\n%s" % [tr(TEXT[p][0]), tr(TEXT[p][1])]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ComicUI.style_button(b, TEXT[p][2], 26)
		b.pressed.connect(func() -> void: chosen.emit(p))
		row.add_child(b)
