class_name TalkPanel
extends Control
## Talking to someone in Kasei Valley (ComicUI): their name and role, how
## well they know you (a trust bar, FRIEND at Career.FRIEND), what they say
## (by trust), and what you can do together: chat (once per deployment),
## their trade (opens the CityScreen tab), and the foreman's settlement
## business (deliver supplies, collect ingots, stake a claim on Dust
## Hollow). Every button goes through Career; the profile saves after each.

signal open_tab(tab: String)
signal closed

const TABS := {"broker": "contracts", "trader": "market", "armourer": "outfitter"}

var who: String = ""
var _name: Label
var _role: Label
var _line: Label
var _trust: ProgressBar
var _trust_label: Label
var _buttons: VBoxContainer
var _note: String = ""
## Set by CityMode before open(): {"region": region, "stars": wanted.stars}.
var situation: Dictionary = {}
var conv: Conversation   ## topics, memory, allies (game/conversation.gd)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.01, 0.07, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ComicUI.box(Color(ComicUI.INK, 0.94), ComicUI.YELLOW, 4, 0.04))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -340
	panel.offset_bottom = -24
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	panel.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 430
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	_name = _label(UiStyle.font_hud_big, 46, ComicUI.YELLOW)
	left.add_child(_name)
	_role = _label(UiStyle.font_hud_bold, 24, Color(ComicUI.PAPER, 0.8))
	left.add_child(_role)
	_trust_label = _label(UiStyle.font_hud_bold, 22, ComicUI.CYAN)
	left.add_child(_trust_label)
	_trust = ProgressBar.new()
	_trust.show_percentage = false
	_trust.custom_minimum_size = Vector2(380, 16)
	_trust.add_theme_stylebox_override("background", ComicUI.box(Color(0, 0, 0, 0.6), ComicUI.INK, 2, 0.0, false))
	_trust.add_theme_stylebox_override("fill", ComicUI.box(ComicUI.CYAN, ComicUI.INK, 2, 0.0, false))
	left.add_child(_trust)
	_line = _label(UiStyle.font_hud_bold, 27, ComicUI.PAPER)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.x = 420
	left.add_child(_line)
	# Many things to do (the job centre's list): the buttons scroll.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 290
	row.add_child(scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.add_theme_constant_override("separation", 8)
	scroll.add_child(_buttons)


func _label(f: Font, px: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	return l


func open(p_who: String) -> void:
	who = p_who
	conv = conversation()
	_note = conv.greeting(who, context())
	visible = true
	refresh()


func refresh() -> void:
	var c := Profile.career()
	var person: Dictionary = Career.PEOPLE[who]
	_name.text = str(person.name).to_upper()
	_role.text = "%s · %s" % [person.role, Career.FACTIONS[person.faction].name]
	var t := c.trust(who)
	_trust.value = t
	_trust_label.text = tr("TALK_TRUST") % [t, tr("TALK_MOOD_" + c.mood(who).to_upper())]
	var line := tr("NPC_%s_%s" % [who.to_upper(), c.mood(who).to_upper()])
	if who == "foreman" and c.owns_hollow():
		line = tr("NPC_FOREMAN_BOSS")
	elif conv != null:
		line = conv.greeting(who, context())  # who they are, what they remember, the hour
	_line.text = "“%s”" % (_note if not _note.is_empty() else line)
	for b in _buttons.get_children():
		b.queue_free()
	_conversation_buttons(c)
	_mission_report(c)
	var talked := int(c.d.talked.get(who, -1)) == int(c.d.runs)
	_button(tr("TALK_CHAT") if not talked else tr("TALK_CHATTED"), not talked, ComicUI.CYAN, func() -> void:
		if c.talk(who):
			_note = tr("NPC_%s_CHAT" % who.to_upper()))
	if TABS.has(who):
		_button(tr("TALK_TAB_" + who.to_upper()), true, ComicUI.YELLOW, func() -> void:
			visible = false
			open_tab.emit(TABS[who]))
	if who == "trader":
		_button(tr("TALK_BUY_SUPPLY") % Career.SUPPLY_PRICE, c.d.wallet >= Career.SUPPLY_PRICE, ComicUI.GREEN,
				func() -> void: c.buy_supplies(1))
	if who == "trader":
		_button(tr("TALK_BUY_WATER") % Career.BUY.water_ration, c.d.wallet >= int(Career.BUY.water_ration), ComicUI.CYAN,
				func() -> void: c.buy("water_ration"))
	if who == "trader":
		_button(tr("TALK_BUY_O2") % Career.BUY.oxygen_canister, c.d.wallet >= int(Career.BUY.oxygen_canister), ComicUI.CYAN,
				func() -> void: c.buy("oxygen_canister"))
	if who == "farmer":
		_button(tr("TALK_BUY_FOOD") % Career.BUY.fresh_food, c.d.wallet >= int(Career.BUY.fresh_food), ComicUI.GREEN,
				func() -> void: c.buy("fresh_food"))
		_button(tr("TALK_BUY_MEAT") % Career.BUY.fresh_meat, c.d.wallet >= int(Career.BUY.fresh_meat), ComicUI.RED,
				func() -> void: c.buy("fresh_meat"))
	if who == "chemist":
		var now := int(Time.get_unix_time_from_system())
		for r: String in Career.RECIPES:
			var rec: Dictionary = Career.RECIPES[r]
			var why := c.lab_blocker(r)
			var text := tr("TALK_LAB_" + r.to_upper()) % [rec.cash, rec.count, rec.seconds]
			if why == "inputs":
				text += "\n" + tr("TALK_LAB_NEED")
			_button(text, why.is_empty(), ComicUI.MAGENTA if r == "red_dust" else ComicUI.CYAN, func() -> void:
				c.lab_start(r, now))
		var left := c.lab_left(now)
		if left >= 0:
			var item: String = c.d.lab.output
			_button(tr("TALK_LAB_COLLECT") % [int(c.d.lab.count), Career.ITEMS[item].name] if left == 0
					else tr("TALK_LAB_WAIT") % left, left == 0, ComicUI.GREEN, func() -> void: c.lab_collect(now))
	if who == "dealer":
		var doses: int = c.d.stash.get("red_dust", 0)
		_button(tr("TALK_DEALER_SELL") % [doses, Career.DEALER_PRICE], doses > 0, ComicUI.MAGENTA, func() -> void:
			var got := c.sell_contraband()
			_note = tr("NPC_DEALER_PAID") % got)
	if who == "jobs":
		if not c.d.job.is_empty():
			_button(tr("TALK_JOB_ACTIVE") % Career.JOBS[c.d.job.id].title, false, ComicUI.YELLOW, func() -> void: pass)
		for j: String in Career.JOBS:
			_button(tr("TALK_JOB_TAKE") % [Career.JOBS[j].title, int(Career.JOBS[j].pay)], c.job_available(j), ComicUI.YELLOW,
					func() -> void: c.take_job(j))
	if who in ["foreman", "armourer"] and c.is_friend(who):
		var coming: bool = c.d.get("companion", "") == who
		_button(tr("TALK_COMPANION_STOP") if coming else tr("TALK_COMPANION"), true, ComicUI.GREEN, func() -> void:
			c.set_companion("" if coming else who)
			_note = tr("NPC_COMPANION_NO") if coming else tr("NPC_COMPANION_YES"))
	if who == "foreman" and not c.d.job.is_empty() and c.d.job.id == "courier":
		_button(tr("TALK_DELIVER_PARCEL"), int(c.d.stash.get("parcel", 0)) > 0, ComicUI.YELLOW, func() -> void:
			var done := c.finish_job()
			if not done.is_empty():
				_note = tr("NPC_FOREMAN_PARCEL") % done.pay)
	if who == "foreman":
		var crates: int = c.d.stash.get("supply_crate", 0)
		_button(tr("TALK_DELIVER") % crates, crates > 0, ComicUI.GREEN, func() -> void:
			var n := c.deliver_supplies()
			_note = tr("NPC_FOREMAN_THANKS") % n)
		if c.owns_hollow():
			_button(tr("TALK_COLLECT") % int(c.d.hollow.ingots), int(c.d.hollow.ingots) > 0, ComicUI.YELLOW,
					func() -> void: c.collect_ingots())
		else:
			var why := c.claim_blocker()
			var text := tr("TALK_CLAIM") % Career.CLAIM_COST
			if why == "trust":
				text += "\n" + tr("TALK_CLAIM_NEED_TRUST") % Career.CLAIM_TRUST
			elif why == "money":
				text += "\n" + tr("TALK_CLAIM_NEED_MONEY")
			_button(text, why.is_empty(), ComicUI.MAGENTA, func() -> void:
				if c.claim_hollow():
					_note = tr("NPC_FOREMAN_CLAIMED"))
	_button(tr("TALK_LEAVE"), true, ComicUI.PAPER, func() -> void:
		visible = false
		closed.emit())


## The memory store: in the career when the director has added
## `talk_memory` to it, else a file of our own under user://.
static func conversation() -> Conversation:
	var c := Profile.career()
	if c.d.get("memory") is Dictionary:
		return Conversation.new(c.d.memory)  # the career keeps what people remember
	if c.d.get("talk_memory") is Dictionary:
		return Conversation.new(c.d.talk_memory)
	return Conversation.load_from()


## The situation the person sees you in.
func context() -> Dictionary:
	var c := Profile.career()
	var ctx := {"trust": c.trust(who), "now": int(Time.get_unix_time_from_system()),
			"fame": c.fame_tier(), "nation": str(c.d.get("nation", ""))}
	ctx.hour = fmod(GameClock.hour(ctx.now) + CityNpcs.hour_offset, 24.0)
	ctx.merge(situation, true)
	return ctx


func _conversation_buttons(c: Career) -> void:
	var ctx := context()
	_trust_label.text += "  ·  " + tr("TALK_TOPICS") % conv.topics_left(who, ctx) \
			if tr("TALK_TOPICS") != "TALK_TOPICS" else "  ·  %d topics left" % conv.topics_left(who, ctx)
	for o: Dictionary in conv.options(who, ctx):
		var accent := ComicUI.MAGENTA if str(o.id).begins_with("mission:") else (ComicUI.GREEN if o.id in ["join", "dismiss"] else ComicUI.CYAN)
		var text: String = o.text
		if not bool(o.enabled) and o.why in ["squad", "trust", "betrayed"]:
			text += "\n" + conv.refusal(who, o.why)
		var id: String = o.id
		_button(text, bool(o.enabled), accent, func() -> void:
			var r := conv.choose(who, id, context())
			_note = r.line
			if int(r.trust) != 0:
				c.d.trust[who] = clampi(c.trust(who) + int(r.trust), 0, 100)
			if r.has("ally") and c.d.has("companion"):
				var first: Array = conv.allies()
				c.set_companion(first[0] if not first.is_empty() else "")
			if r.has("mission"):
				c.d["talk_mission"] = {"who": who, "id": r.mission.id, "title": str(r.mission.get("title", "")),
						"pay": r.mission.pay, "squad": r.mission.squad, "runs": int(c.d.runs)}
			if not c.d.get("memory") is Dictionary and not c.d.get("talk_memory") is Dictionary:
				conv.save_to())


## A mission taken in talk is done after a run out (a deploy) and reported
## back to whoever gave it: pay, a favour remembered, more trust.
func _mission_report(c: Career) -> void:
	var m: Dictionary = c.d.get("talk_mission", {})
	if m.is_empty() or str(m.get("who", "")) != who:
		return
	var done := int(c.d.runs) > int(m.get("runs", 0))
	_button(tr("TALK_MISSION_REPORT") % [str(m.get("title", m.id)), int(m.pay)] if done else tr("TALK_MISSION_PENDING") % str(m.get("title", m.id)),
			done, ComicUI.GREEN, func() -> void:
		c.d.wallet = int(c.d.wallet) + int(m.pay)
		c.d.earned = int(c.d.earned) + int(m.pay)
		c.d.trust[who] = clampi(c.trust(who) + 6, 0, 100)
		conv.remember(who, "favour", str(m.id), int(Time.get_unix_time_from_system()))
		c.d.erase("talk_mission")
		_note = tr("TALK_MISSION_THANKS"))


func _button(text: String, enabled: bool, accent: Color, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 58
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ComicUI.style_button(b, accent, 25, UiStyle.font_hud_bold)
	b.pressed.connect(func() -> void:
		action.call()
		Profile.save()
		if visible:
			refresh())
	_buttons.add_child(b)
