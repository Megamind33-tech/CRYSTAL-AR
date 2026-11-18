extends GutTest
## game/conversation.gd: topic dialogue, memory, patience, allies, squads.

const NOW := 1_000_000


func _ctx(trust: int, extra: Dictionary = {}) -> Dictionary:
	var c := {"trust": trust, "now": NOW, "hour": 12.0}
	c.merge(extra, true)
	return c


func _opt(conv: Conversation, who: String, id: String, ctx: Dictionary) -> Dictionary:
	for o: Dictionary in conv.options(who, ctx):
		if o.id == id:
			return o
	return {}


func test_deterministic_identity() -> void:
	for who: String in Career.PEOPLE:
		assert_eq(Conversation.nation_of(who), Conversation.nation_of(who))
		assert_true(Conversation.nation_of(who) in Nations.IDS)
		assert_true(Conversation.character(who) in Nations.PERSONALITIES)
	var a := Conversation.new({})
	var b := Conversation.new({})
	assert_eq(a.greeting("foreman", _ctx(20)), b.greeting("foreman", _ctx(20)), "same inputs, same words")


func test_topics_answer_and_are_limited() -> void:
	var conv := Conversation.new({})
	var left := conv.topics_left("trader", _ctx(0))
	assert_gt(left, 0)
	var r := conv.choose("trader", "colony", _ctx(0))
	assert_true(r.ok)
	assert_eq(r.line, Conversation.COLONY["kasei"])
	assert_eq(conv.topics_left("trader", _ctx(0)), left - 1)
	assert_false(conv.choose("trader", "colony", _ctx(0)).ok, "asked already")
	for id: String in ["work", "rumours", "you"]:
		conv.choose("trader", id, _ctx(0))
	assert_eq(conv.topics_left("trader", _ctx(0)), 0, "patience spent")
	assert_eq(_opt(conv, "trader", "work", _ctx(0)).why, "tired")
	# Next sol: patience refills.
	var later := _ctx(0, {"now": NOW + Conversation.SOL_SECONDS})
	assert_eq(conv.topics_left("trader", later), Conversation.patience("trader", 0, 0))
	assert_true(conv.choose("trader", "colony", later).ok)


func test_wanted_shortens_patience_friends_lengthen() -> void:
	assert_lt(Conversation.patience("broker", 0, 3), Conversation.patience("broker", 0, 0))
	assert_gt(Conversation.patience("broker", 90, 0), Conversation.patience("broker", 0, 0))


func test_memory_recalls_and_survives_save() -> void:
	var conv := Conversation.new({})
	assert_eq(conv.recall("farmer"), "")
	conv.remember("farmer", "favour", "the water pump", NOW)
	assert_string_contains(conv.recall("farmer"), "the water pump")
	assert_eq(conv.trust_of("farmer", 20), 30, "a favour adds trust")
	var path := "user://test_talk_memory.json"
	assert_true(conv.save_to(path))
	var back := Conversation.load_from(path)
	assert_string_contains(back.recall("farmer"), "the water pump")
	assert_string_contains(back.greeting("farmer", _ctx(20)), "the water pump")
	DirAccess.remove_absolute(path)


func test_ally_needs_trust_and_betrayal_ends_it() -> void:
	var conv := Conversation.new({})
	assert_eq(_opt(conv, "armourer", "join", _ctx(30)).why, "trust")
	var r := conv.choose("armourer", "join", _ctx(70))
	assert_true(r.ok)
	assert_true(r.ally)
	assert_eq(conv.allies(), ["armourer"])
	conv.remember("armourer", "betrayal", "shot them in the shafts", NOW)
	assert_eq(conv.allies(), [], "betrayal breaks the alliance")
	assert_eq(_opt(conv, "armourer", "join", _ctx(100)).why, "betrayed")
	assert_string_contains(conv.greeting("armourer", _ctx(50)), "nerve")


func test_squad_missions_refuse_you_alone() -> void:
	var conv := Conversation.new({})
	var solo := _opt(conv, "foreman", "mission:pipeline_sweep", _ctx(40))
	var squad := _opt(conv, "foreman", "mission:hollow_raid", _ctx(40))
	assert_true(solo.enabled, "solo missions are fine alone")
	assert_false(squad.enabled)
	assert_eq(squad.why, "squad")
	assert_string_contains(conv.choose("foreman", "mission:hollow_raid", _ctx(40)).line, "squad")
	conv.choose("armourer", "join", _ctx(80))
	assert_true(_opt(conv, "foreman", "mission:hollow_raid", _ctx(40)).enabled, "with an ally it's on")
	var m := conv.choose("foreman", "mission:hollow_raid", _ctx(40))
	assert_eq(m.mission.id, "hollow_raid")
	assert_string_contains(Conversation.new(conv.memory).recall("foreman"), "north shafts")


func test_situation_colours_greeting() -> void:
	var conv := Conversation.new({})
	assert_string_contains(conv.greeting("jobs", _ctx(0, {"stars": 4})), "looking for you")
	assert_string_contains(conv.greeting("jobs", _ctx(0, {"hour": 2.0})), "late")
	var n := Conversation.nation_of("jobs")
	assert_string_contains(conv.greeting("jobs", _ctx(0, {"nation": n})), "fellow")


func test_talk_panel_compiles() -> void:
	var s: GDScript = load("res://ui/city/talk_panel.gd")
	assert_true(s != null and s.can_instantiate(), "the panel that hosts the conversation compiles")
