class_name GuideIntro
extends Control
## "What you can do here": the short card shown once after choosing a
## nation (Guide.intro_keys()). Three plain steps and the two paths.

signal done


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.01, 0.06, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 820
	panel.add_theme_stylebox_override("panel", ComicUI.box(Color(ComicUI.INK, 0.95), ComicUI.YELLOW, 4, 0.04))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(_text(tr("GUIDE_INTRO_TITLE"), UiStyle.font_hud_big, 40, ComicUI.YELLOW))
	var keys := Guide.intro_keys()
	for i in keys.size():
		var gov := keys[i] == "GUIDE_PATH_GOV"
		var free := keys[i] == "GUIDE_PATH_FREE"
		col.add_child(_text(tr(keys[i]), UiStyle.font_hud_bold, 24,
				ComicUI.CYAN if gov else (ComicUI.MAGENTA if free else Color.WHITE)))
	var ok := Button.new()
	ok.text = tr("GUIDE_INTRO_OK")
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(220, 64)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ComicUI.style_button(ok, ComicUI.GREEN, 30)
	ok.pressed.connect(func() -> void:
		done.emit()
		queue_free())
	col.add_child(ok)


func _text(t: String, f: Font, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", ComicUI.INK)
	l.add_theme_constant_override("outline_size", 4)
	return l
