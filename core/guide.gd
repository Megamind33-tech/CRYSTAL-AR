class_name Guide
extends RefCounted
## The objective tracker and the guided first run (docs/game-plan.md §7):
## one thing to do at a time, where it is, and how far. The career stores
## how far the first run has got (Career.d.guide); in a run the step comes
## from what you're doing (carrying, banked), so it can't fall out of step.
##
## The first run: choose a nation -> take a contract from the Broker ->
## deploy -> find your cargo -> carry it to a pad -> sell at the Trader.
## After that the tracker keeps showing the next useful thing.

enum Step { NATION, BOARD, DEPLOY, RUN, SELL, DONE }

const BOARD := 0   ## CityLayout.terminals() rows
const MARKET := 1


## The stored step, moved on by what the career shows.
static func step(c: Career) -> int:
	var g := int(c.d.guide)
	if g == Step.NATION and c.nation() != Nations.NONE:
		g = Step.BOARD
	if g == Step.BOARD and not c.d.contract.is_empty():
		g = Step.DEPLOY
	if g < Step.SELL and int(c.d.runs) > 0:
		g = Step.SELL  # back from the first run with something to sell
	if g == Step.SELL and not _has_goods(c):
		g = Step.DONE
	c.d.guide = g
	return g


static func _has_goods(c: Career) -> bool:
	for item: String in c.d.stash:
		if Career.ITEMS.has(item) and int(Career.ITEMS[item].get("base", 0)) > 0 and not Career.is_weapon(item):
			return true
	return false


## Whether the first run is still being taught (the tracker says "1/5").
static func teaching(c: Career) -> bool:
	return step(c) < Step.DONE


## The city's objective: {"text", "target" (Vector3 or INF), "step" (1..5,
## 0 when not teaching)}.
static func city_objective(c: Career) -> Dictionary:
	var board: Vector3 = CityLayout.terminals()[BOARD][1]
	match step(c):
		Step.NATION:
			return {"text": tr_("GUIDE_NATION"), "target": Vector3.INF, "step": 1}
		Step.BOARD:
			return {"text": tr_("GUIDE_BOARD"), "target": board, "step": 2}
		Step.DEPLOY:
			return {"text": tr_("GUIDE_DEPLOY"), "target": board, "step": 3}
		Step.SELL:
			return {"text": tr_("GUIDE_SELL"), "target": CityLayout.terminals()[MARKET][1], "step": 5}
	if not c.d.contract.is_empty():
		return {"text": tr_("GUIDE_NEXT_DEPLOY") % c.d.contract.title, "target": board, "step": 0}
	if _has_goods(c):
		return {"text": tr_("GUIDE_NEXT_SELL"), "target": CityLayout.terminals()[MARKET][1], "step": 0}
	return {"text": tr_("GUIDE_NEXT_BOARD"), "target": board, "step": 0}


## The run's objective for hunter `me`: find your cargo, carry it to the
## nearest open pad. {"text", "target", "step"} (step 4 on the first run).
static func run_objective(c: Career, h: HuntRules, me: int, at: Vector3, tick: int) -> Dictionary:
	var first := int(c.d.runs) == 0
	var carried := h.carried_by(me)
	if carried != null:
		return {"text": tr_("GUIDE_RUN_EXTRACT"), "target": h.nearest_zone(at, tick), "step": 4 if first else 0}
	var best := Vector3.INF
	for t: HuntRules.Treasure in h.assignments_of(me):
		if t.banked or t.carrier != 0:
			continue
		if best == Vector3.INF or at.distance_to(t.position) < at.distance_to(best):
			best = t.position
	if best != Vector3.INF:
		return {"text": tr_("GUIDE_RUN_CARGO"), "target": best, "step": 4 if first else 0}
	return {"text": tr_("GUIDE_RUN_ANY"), "target": Vector3.INF, "step": 4 if first else 0}


## "· 42 m" after the text, or nothing without a target.
static func distance_text(from: Vector3, target: Vector3) -> String:
	if target == Vector3.INF:
		return ""
	return "  ·  %d m" % roundi(Vector2(from.x - target.x, from.z - target.z).length())


static func tr_(key: String) -> String:
	return TranslationServer.translate(key)
