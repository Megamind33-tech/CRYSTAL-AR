class_name Registration
extends Control
## First launch: your name, then your body (CharacterRig.SELECTABLE). Saves
## into the career (Career.register) and the profile settings. The nation
## is picked next, on arrival (NationPick).

signal done

var _name: LineEdit
var _body := 0
var _warn: Label
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(ComicUI.INK, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)
	col.add_child(_label(tr("REG_TITLE"), 54, ComicUI.YELLOW))
	col.add_child(_label(tr("REG_NAME"), 26, ComicUI.PAPER))
	_name = LineEdit.new()
	_name.name = "Name"
	_name.max_length = 16
	_name.text = MatchConfig.profile_name()
	_name.custom_minimum_size = Vector2(360, 56)
	col.add_child(_name)
	col.add_child(_label(tr("REG_BODY"), 26, ComicUI.PAPER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in CharacterRig.SELECTABLE.size():
		var b := Button.new()
		b.name = "Body_%d" % i
		b.toggle_mode = true
		b.button_pressed = i == 0
		b.text = tr("CHAR_%s" % CharacterRig.SELECTABLE[i].to_upper())
		b.custom_minimum_size = Vector2(170, 90)
		ComicUI.style_button(b, ComicUI.YELLOW, 22)
		b.pressed.connect(_pick_body.bind(i))
		_buttons.append(b)
		row.add_child(b)
	_warn = _label("", 22, Color(1, 0.4, 0.4))
	col.add_child(_warn)
	var go := Button.new()
	go.name = "Continue"
	go.text = tr("REG_NEXT")
	go.custom_minimum_size = Vector2(300, 70)
	ComicUI.style_button(go, ComicUI.YELLOW, 30)
	go.pressed.connect(submit)
	col.add_child(go)


func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", UiStyle.font_hud_big)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _pick_body(i: int) -> void:
	_body = i
	for k in _buttons.size():
		_buttons[k].button_pressed = k == i


## Registers with the entered name and chosen body; false on a bad name.
func submit() -> bool:
	var career := Profile.career()
	if not career.register(_name.text, _body):
		_warn.text = tr("REG_BAD_NAME")
		return false
	Settings.set_value("profile", "name", career.d.reg.name)
	Settings.set_value("profile", "character", CharacterRig.SELECTABLE[int(career.d.reg.body)])
	Settings.save_settings()
	Profile.save()
	done.emit()
	queue_free()
	return true
