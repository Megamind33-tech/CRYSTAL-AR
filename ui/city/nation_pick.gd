class_name NationPick
extends Control
## First arrival (docs/game-plan.md §7): choose the nation you came to Mars
## for. Four cards, each its colour, shape, name and motto; one tap
## chooses. Shown over the city until you do.

signal chosen(nation: int)


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
	title.text = tr("NATION_PICK_TITLE")
	title.add_theme_font_override("font", UiStyle.font_hud_big)
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", ComicUI.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var intro := Label.new()
	intro.text = tr("NATION_PICK_INTRO")
	intro.add_theme_font_override("font", UiStyle.font_hud_bold)
	intro.add_theme_font_size_override("font_size", 26)
	intro.add_theme_color_override("font_color", ComicUI.PAPER)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(intro)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in Nations.IDS.size():
		row.add_child(_card(i))


func _card(i: int) -> Button:
	var b := Button.new()
	b.name = "Nation_%s" % Nations.id_of(i)
	b.custom_minimum_size = Vector2(250, 250)
	b.text = "%s\n%s" % [Nations.display_name(i).to_upper(), Nations.motto(i)]
	b.icon = Nations.shape_texture(i, 88)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ComicUI.style_button(b, Nations.color(i), 26)
	for k in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color"]:
		b.add_theme_color_override(k, Nations.color(i))
	b.pressed.connect(func() -> void: chosen.emit(i))
	return b
