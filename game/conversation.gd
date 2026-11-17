class_name Conversation
extends RefCounted
## Talking to people (Career.PEOPLE) as people: offline, deterministic,
## topic-based. What they say depends on WHO they are (role, faction, a
## nation of origin and a fixed character from Nations.personality), WHAT
## THEY REMEMBER of you (past talks, favours, betrayals, trust) and THE
## SITUATION (hour, place, your fame and wanted stars).
##
## A conversation is limited: each person has patience for a few topics a
## sol (more if they like you, fewer if you're wanted). You can ask them to
## join you: an ally who follows and fights for you. Some missions they
## offer "need a squad": they won't send you alone.
##
## Memory is a plain Dictionary (who -> record) so the career can persist it
## (Career.d.talk_memory) or save it to user:// with save_to/load_from.
## Nothing here touches the scene tree or the network.

const MEMORY_PATH := "user://talk_memory.json"
const LOG_MAX := 12          ## remembered events per person
const ALLY_TRUST := 60       ## trust before anyone will walk with you
const ALLY_MAX := 2
const SOL_SECONDS := 88775   ## a Martian sol: patience refills each sol
const BETRAY_TRUST := -30

## Missions people hand out. `squad`: they refuse to send you alone.
const MISSIONS := {
	"foreman": [
		{"id": "pipeline_sweep", "title": "Sweep the pipeline for saboteurs", "pay": 220, "squad": false},
		{"id": "hollow_raid", "title": "Clear the raiders out of the north shafts", "pay": 640, "squad": true},
	],
	"armourer": [
		{"id": "test_fire", "title": "Field-test a prototype rifle", "pay": 180, "squad": false},
		{"id": "ledger_escort", "title": "Escort a Ledger convoy through the dunes", "pay": 560, "squad": true},
	],
	"broker": [
		{"id": "quiet_pickup", "title": "A quiet pickup at the Exchange", "pay": 200, "squad": false},
		{"id": "vault_job", "title": "Crack a Meridian supply vault", "pay": 900, "squad": true},
	],
	"dealer": [
		{"id": "dead_drop", "title": "Collect from a dead drop", "pay": 260, "squad": false},
	],
	"farmer": [
		{"id": "dome_pests", "title": "Hunt the pests in dome three", "pay": 120, "squad": false},
	],
	"chemist": [
		{"id": "sample_run", "title": "Fetch ice core samples from the rim", "pay": 240, "squad": true},
	],
	"jobs": [],
	"trader": [],
}

## Colony talk by faction; rumours by faction (indexed deterministically).
const COLONY := {
	"kasei": "Kasei runs on contracts and water. Keep your ledger clean and the domes stay open to you.",
	"ledger": "The Ledger keeps the books nobody else wants kept. Everyone owes somebody here.",
	"tharsis": "The Concern digs, the city spends. Out at the Hollow we remember who brought supplies.",
}
const RUMOURS := [
	"They say a Vesper crew found a vault seam under the old pad and never came back up.",
	"Somebody's buying red dust by the crate. Somebody with a badge.",
	"The Meridian convoy runs light on guards after the dust storms.",
	"Halden pays double for anyone who's seen the north shafts and lived.",
	"Aurora hunters move in pairs now. Something out there hunts them back.",
	"The Exchange cooks its prices on the hour. Sell at dusk.",
]
const WORK := {
	"chemist": "Synthesis, mostly. Clean work, if you don't ask what it's for.",
	"dealer": "I sell what the Exchange won't. Discretion's included in the price.",
	"jobs": "I match people to shifts. There's always a shift.",
	"farmer": "Three domes, a thousand plants and never enough water.",
	"broker": "Contracts. I find the client, you find the cargo.",
	"trader": "Buy low on the pad, sell high in the domes.",
	"armourer": "I keep hunters alive. Mostly by selling them better plates.",
	"foreman": "Holding Dust Hollow together with wire and stubbornness.",
}
## How each character speaks (greeting by personality, then mood).
const GREET := {
	"loyal": {"stranger": "Hello. Don't think I know you.", "known": "Good to see you again.", "friend": "There you are! I was hoping you'd come by."},
	"steady": {"stranger": "Yes?", "known": "You again. Fine. What is it?", "friend": "Pull up a crate. What do you need?"},
	"ambitious": {"stranger": "You look like someone with money. Do you?", "known": "Back for business?", "friend": "My favourite hunter. Let's make some credits."},
}

var memory: Dictionary = {}


func _init(p_memory: Dictionary = {}) -> void:
	memory = p_memory


# --- Who they are ---

## The nation someone came to Mars with (fixed per person).
static func nation_of(who: String) -> String:
	return Nations.IDS[absi(hash("nation:" + who)) % Nations.IDS.size()]


static func character(who: String) -> String:
	return Nations.personality(who)


## How many topics they'll talk through in a sol.
static func patience(who: String, trust: int, stars: int) -> int:
	var base := {"loyal": 4, "steady": 3, "ambitious": 3}[character(who)] as int
	base += 1 if trust >= Career.FRIEND else 0
	base += 1 if trust >= 80 else 0
	base -= 2 if stars >= 3 else (1 if stars >= 1 else 0)
	return maxi(base, 1)


# --- Memory ---

func record(who: String) -> Dictionary:
	if not memory.has(who):
		memory[who] = {"talks": 0, "favours": 0, "betrayals": 0, "trust": 0, "log": [],
				"sol": -1, "used": 0, "ally": false, "asked": [], "last": 0}
	return memory[who]


## Remember something: kind is "talk", "favour", "betrayal", "mission",
## "ally", "refused". Favours and betrayals shift memory-trust.
func remember(who: String, kind: String, detail: String, at: int) -> void:
	var r := record(who)
	match kind:
		"talk":
			r.talks = int(r.talks) + 1
		"favour":
			r.favours = int(r.favours) + 1
			r.trust = clampi(int(r.trust) + 10, -100, 100)
		"betrayal":
			r.betrayals = int(r.betrayals) + 1
			r.trust = clampi(int(r.trust) + BETRAY_TRUST, -100, 100)
			r.ally = false
	var log: Array = r.log
	log.append({"kind": kind, "detail": detail, "at": at})
	while log.size() > LOG_MAX:
		log.pop_front()
	r.last = at


## What they recall about you, as a line (empty if nothing worth saying).
func recall(who: String) -> String:
	var r := record(who)
	if int(r.betrayals) > 0:
		return "I haven't forgotten what you did. %d time%s." % [r.betrayals, "" if int(r.betrayals) == 1 else "s"]
	var log: Array = r.log
	for i in range(log.size() - 1, -1, -1):
		var e: Dictionary = log[i]
		if e.kind == "favour":
			return "I still owe you for %s." % e.detail
		if e.kind == "mission":
			return "Word is you handled %s. Nice work." % e.detail
	if int(r.talks) >= 5:
		return "We've talked a lot, you and I. I trust your read on things."
	if int(r.talks) > 0:
		return "We talked before, didn't we?"
	return ""


## Effective trust: the career's trust plus what memory adds (favours,
## betrayals), clamped 0..100.
func trust_of(who: String, career_trust: int) -> int:
	return clampi(career_trust + int(record(who).trust), 0, 100)


func allies() -> Array:
	var out := []
	for who: String in memory:
		if bool(memory[who].get("ally", false)):
			out.append(who)
	out.sort()
	return out


# --- The conversation ---

## ctx: {trust:int, now:int, hour:float, region:String, fame:int,
## stars:int, nation:String}. Missing keys default sensibly.
static func _ctx(ctx: Dictionary) -> Dictionary:
	var d := {"trust": 0, "now": 0, "hour": 12.0, "region": "city", "fame": 0, "stars": 0, "nation": ""}
	d.merge(ctx, true)
	return d


func _sol(now: int) -> int:
	return int(floor(float(now) / SOL_SECONDS))


func _left(who: String, c: Dictionary) -> int:
	var r := record(who)
	var used := int(r.used) if int(r.sol) == _sol(c.now) else 0
	return patience(who, trust_of(who, c.trust), c.stars) - used


func topics_left(who: String, ctx: Dictionary) -> int:
	return maxi(_left(who, _ctx(ctx)), 0)


static func mood_for(t: int) -> String:
	return "stranger" if t < 15 else ("known" if t < Career.FRIEND else "friend")


## Their opening line: greeting by character and mood, coloured by the
## hour, your notoriety, shared nation and what they remember.
func greeting(who: String, ctx: Dictionary) -> String:
	var c := _ctx(ctx)
	var r := record(who)
	var t := trust_of(who, c.trust)
	if int(r.betrayals) > 0 and t < 40:
		return "You've got nerve showing your face. Say it quickly."
	var parts: Array[String] = [GREET[character(who)][mood_for(t)]]
	var h: float = c.hour
	if h < 5.0 or h >= 22.0:
		parts.append("Bit late to be wandering about.")
	elif h < 8.0:
		parts.append("Early start?")
	if int(c.stars) >= 3:
		parts.append("Half the valley's looking for you, you know.")
	elif int(c.fame) >= 3 and t < 15:
		parts.append("Wait, I know your face from MarsNet.")
	if str(c.nation) != "" and str(c.nation) == nation_of(who):
		parts.append("And a fellow %s, too." % str(c.nation).capitalize())
	var mem := recall(who)
	if not mem.is_empty():
		parts.append(mem)
	return " ".join(parts)


## Choices on offer: [{id, text, enabled, why}]. `why` explains a disabled
## one ("tired", "trust", "squad", "allies", "betrayed").
func options(who: String, ctx: Dictionary) -> Array:
	var c := _ctx(ctx)
	var r := record(who)
	var t := trust_of(who, c.trust)
	var tired := _left(who, c) <= 0
	var out := []
	var asked: Array = r.asked if int(r.sol) == _sol(c.now) else []
	for topic: Array in [["colony", "Ask about the colony"], ["work", "Ask about their work"],
			["rumours", "Any rumours?"], ["you", "Ask about them"]]:
		var done: bool = asked.has(topic[0])
		out.append({"id": topic[0], "text": topic[1], "enabled": not tired and not done,
				"why": "tired" if tired else ("asked" if done else "")})
	for m: Dictionary in MISSIONS.get(who, []):
		var why := ""
		if tired:
			why = "tired"
		elif t < 25:
			why = "trust"
		elif bool(m.squad) and allies().filter(func(a: String) -> bool: return a != who).is_empty() and not bool(r.ally):
			why = "squad"
		var text := "Mission: %s (%d cr)%s" % [m.title, m.pay, " [needs a squad]" if m.squad else ""]
		out.append({"id": "mission:" + str(m.id), "text": text, "enabled": why.is_empty(), "why": why})
	if bool(r.ally):
		out.append({"id": "dismiss", "text": "Tell them to head home", "enabled": true, "why": ""})
	else:
		var why := ""
		if int(r.betrayals) > 0:
			why = "betrayed"
		elif t < ALLY_TRUST:
			why = "trust"
		elif allies().size() >= ALLY_MAX:
			why = "allies"
		elif tired:
			why = "tired"
		out.append({"id": "join", "text": "Ask them to join you", "enabled": why.is_empty(), "why": why})
	return out


## Pick a choice. Returns {line, trust (career trust change), ally (bool
## if changed), mission (the mission dict if taken), ok}.
func choose(who: String, id: String, ctx: Dictionary) -> Dictionary:
	var c := _ctx(ctx)
	var r := record(who)
	var out := {"line": "", "trust": 0, "ok": false}
	var opt := {}
	for o: Dictionary in options(who, ctx):
		if o.id == id:
			opt = o
	if opt.is_empty():
		return out
	if not bool(opt.enabled):
		out.line = refusal(who, str(opt.why))
		return out
	var sol := _sol(c.now)
	if int(r.sol) != sol:
		r.sol = sol
		r.used = 0
		r.asked = []
	var t := trust_of(who, c.trust)
	out.ok = true
	if id == "dismiss":
		r.ally = false
		out.ally = false
		out.line = "Right. Call me when you need me."
		remember(who, "ally", "parted ways", c.now)
		return out
	r.used = int(r.used) + 1
	(r.asked as Array).append(id)
	match id:
		"colony":
			out.line = COLONY[Career.PEOPLE[who].faction]
			out.trust = 1
		"work":
			out.line = WORK[who]
			out.trust = 1
		"rumours":
			if t < 15 and character(who) != "loyal":
				out.line = "Rumours cost money, stranger. Or time."
			else:
				var i := absi(hash(who + str(sol))) % RUMOURS.size()
				out.line = RUMOURS[i]
				out.trust = 1
		"you":
			out.line = _about(who, t)
			out.trust = 2
		"join":
			r.ally = true
			out.ally = true
			out.line = {"loyal": "I've got your back. Always.", "steady": "Fine. I'll watch your flank.",
					"ambitious": "For you? Sure. We split anything we find."}[character(who)]
			remember(who, "ally", "joined you", c.now)
		_:
			if id.begins_with("mission:"):
				for m: Dictionary in MISSIONS.get(who, []):
					if "mission:" + str(m.id) == id:
						out.mission = m
						out.line = "It's yours. %s" % ("Take your squad and stay close." if m.squad else "Don't make me regret it.")
						remember(who, "mission", str(m.title).to_lower(), c.now)
	remember(who, "talk", id, c.now)
	return out


func _about(who: String, t: int) -> String:
	var n := nation_of(who).capitalize()
	if t < 15:
		return "I came out with the %s expedition. That's all you need to know." % n
	var ch := {"loyal": "I stay because people here need me. You don't walk out on people.",
			"steady": "I like things quiet and predictable. Mars isn't, so I make my corner of it so.",
			"ambitious": "I'm not staying a %s forever. Give it two sols and I'll own the stall." % Career.PEOPLE[who].role.to_lower()}
	return "%s expedition, originally. %s" % [n, ch[character(who)]]


## How they turn you down.
func refusal(who: String, why: String) -> String:
	match why:
		"tired":
			return "I've got work to do. Come back next sol."
		"asked":
			return "We already went over that."
		"trust":
			return "I don't know you well enough for that."
		"squad":
			return "Alone? No. That one needs a squad. Bring someone who'll watch your back."
		"allies":
			return "You've already got a crowd following you."
		"betrayed":
			return "Walk with you? After last time? No."
	return "No."


# --- Persistence ---

func to_dict() -> Dictionary:
	return memory.duplicate(true)


func save_to(path: String = MEMORY_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(memory))
	return true


static func load_from(path: String = MEMORY_PATH) -> Conversation:
	var conv := Conversation.new({})
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			conv.memory = parsed
			# JSON numbers come back as floats; records are read with int().
	return conv
