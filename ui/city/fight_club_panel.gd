class_name FightClubPanel
extends Control
## The Pit (ComicUI): tonight's fight card with odds, the bet stake, and the
## way into the ring. The city does the work (`bet`, `watch`, `enter_ring`
## -> CityMode with FightClub); this shows the card and the choices.

signal closed
signal bet(fight: int, corner: int, stake: int)
signal watch(fight: int)
signal enter_ring

const STAKES := [10, 50, 100, 500, 1000]

var club: FightClub
var wallet: int = 0
var note: String = ""
var _stake_i: int = 1
var _title: Label
var _line: Label
var _buttons: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.01, 0.07, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ComicUI.box(Color(ComicUI.INK, 0.94), ComicUI.RED, 4, -0.03))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -480
	panel.offset_right = 480
	panel.offset_top = -300
	panel.offset_bottom = 300
	add_child(panel)
	var col := VBoxContainer.new()
	panel.add_child(col)
	_title = Label.new()
	_title.add_theme_font_override("font", UiStyle.font_hud_big)
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", ComicUI.YELLOW)
	_title.text = "THE PIT"
	col.add_child(_title)
	_line = Label.new()
	_line.add_theme_font_override("font", UiStyle.font_hud_bold)
	_line.add_theme_font_size_override("font_size", 24)
	_line.add_theme_color_override("font_color", ComicUI.PAPER)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_line)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.add_theme_constant_override("separation", 8)
	scroll.add_child(_buttons)


func open(p_club: FightClub, p_wallet: int) -> void:
	club = p_club
	wallet = p_wallet
	note = ""
	visible = true
	refresh()


func refresh() -> void:
	for b in _buttons.get_children():
		_buttons.remove_child(b)
		b.queue_free()
	var stake: int = STAKES[_stake_i]
	_line.text = "Wallet %d  |  Stake %d%s" % [wallet, stake, ("\n" + note) if not note.is_empty() else ""]
	_button("STAKE: %d (change)" % stake, true, ComicUI.CYAN, func() -> void:
		_stake_i = (_stake_i + 1) % STAKES.size()
		refresh())
	for i in club.card.size():
		var f: Dictionary = club.card[i]
		var done := club.results.has(i)
		var head := "%s (%d)  vs  %s (%d)" % [f.red.name, f.red.rating, f.blue.name, f.blue.rating]
		if done:
			head += "  -  WON BY %s" % (f.red.name if club.results[i] == 0 else f.blue.name).to_upper()
		_button(head, not done, ComicUI.PAPER, func() -> void: watch.emit(i))
		if not done:
			for c in 2:
				var who: Dictionary = f.red if c == 0 else f.blue
				_button("   BET %d ON %s  @ %.2f" % [stake, who.name.to_upper(), f.odds[c]],
						wallet >= stake, ComicUI.RED if c == 0 else ComicUI.CYAN,
						func() -> void: bet.emit(i, c, stake))
	_button("STEP INTO THE RING (purse %d)" % FightClub.PURSE_WIN, true, ComicUI.YELLOW, func() -> void: enter_ring.emit())
	_button(tr("TALK_LEAVE"), true, ComicUI.PAPER, func() -> void:
		visible = false
		closed.emit())


func _button(text: String, enabled: bool, accent: Color, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 52
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ComicUI.style_button(b, accent, 22, UiStyle.font_hud_bold)
	b.pressed.connect(on_press)
	_buttons.add_child(b)
