class_name MarsNetPanel
extends Control
## MarsNet on your phone (ComicUI): the valley's feed, newest first. Posts
## from people around the valley, the news, and what you've been up to
## (MarsNet notices); your snaps with their likes. Snap posts a photo of
## where you are (the panel steps aside for the shot).

signal closed
signal snap

var _list: VBoxContainer
var _head: Label
var _thumbs := {}  ## image path -> ImageTexture


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.01, 0.07, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ComicUI.box(Color(ComicUI.INK, 0.95), ComicUI.CYAN, 4, 0.04))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -330
	panel.offset_bottom = 330
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var title := Label.new()
	title.text = "MarsNet"
	title.add_theme_font_override("font", UiStyle.font_hud_big)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", ComicUI.CYAN)
	col.add_child(title)
	_head = Label.new()
	_head.add_theme_font_override("font", UiStyle.font_hud_bold)
	_head.add_theme_font_size_override("font_size", 22)
	_head.add_theme_color_override("font_color", ComicUI.YELLOW)
	col.add_child(_head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	row.add_child(_button("MARSNET_SNAP", ComicUI.MAGENTA, _on_snap))
	row.add_child(_button("TALK_LEAVE", ComicUI.PAPER, _on_leave))


func _button(key: String, accent: Color, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = tr(key)
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(240, 58)
	ComicUI.style_button(btn, accent, 25, UiStyle.font_hud_bold)
	btn.pressed.connect(action)
	return btn


func _on_snap() -> void:
	snap.emit()


func _on_leave() -> void:
	visible = false
	closed.emit()


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	var c := Profile.career()
	_head.text = tr("MARSNET_FAME") % [str(Career.FAME_TIERS[c.fame_tier()][1]), int(c.d.fame)]
	for n in _list.get_children():
		_list.remove_child(n)
		n.queue_free()
	if (c.d.feed as Array).is_empty():
		var empty := Label.new()
		empty.text = tr("MARSNET_EMPTY")
		empty.add_theme_font_override("font", UiStyle.font_hud_bold)
		empty.add_theme_font_size_override("font_size", 22)
		empty.add_theme_color_override("font_color", ComicUI.PAPER)
		_list.add_child(empty)
	for p: Dictionary in c.d.feed:
		_list.add_child(_card(p))


func _card(p: Dictionary) -> Control:
	var card := PanelContainer.new()
	var you := str(p.who) == tr("MARSNET_YOU")
	card.add_theme_stylebox_override("panel", ComicUI.box(Color(0.12, 0.06, 0.14, 0.95), ComicUI.MAGENTA if you else ComicUI.PAPER, 2,
			0.02))
	var col := VBoxContainer.new()
	card.add_child(col)
	var who := Label.new()
	who.text = "@" + str(p.who) + (" · " + CityStyle.title() if you and not CityStyle.title().is_empty() else "")
	who.add_theme_font_override("font", UiStyle.font_hud_big)
	who.add_theme_font_size_override("font_size", 22)
	who.add_theme_color_override("font_color", ComicUI.MAGENTA if you else ComicUI.CYAN)
	col.add_child(who)
	var text := Label.new()
	text.text = str(p.text)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 580
	text.add_theme_font_override("font", UiStyle.font_hud_bold)
	text.add_theme_font_size_override("font_size", 21)
	text.add_theme_color_override("font_color", ComicUI.PAPER)
	col.add_child(text)
	if p.has("img"):
		var tex := _thumb(str(p.img))
		if tex != null:
			var pic := TextureRect.new()
			pic.texture = tex
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.custom_minimum_size = Vector2(580, 300)
			col.add_child(pic)
	var likes := Label.new()
	likes.text = tr("MARSNET_LIKES") % int(p.likes)
	likes.add_theme_font_override("font", UiStyle.font_hud_bold)
	likes.add_theme_font_size_override("font_size", 18)
	likes.add_theme_color_override("font_color", ComicUI.RED)
	col.add_child(likes)
	return card


func _thumb(path: String) -> Texture2D:
	if _thumbs.has(path):
		return _thumbs[path]
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null:
		return null
	var tex := ImageTexture.create_from_image(img)
	_thumbs[path] = tex
	return tex
