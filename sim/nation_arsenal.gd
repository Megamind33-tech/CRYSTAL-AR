class_name NationArsenal
extends RefCounted
## Each nation fights its own way (docs/war-plan.md): a doctrine of
## strengths and weaknesses over the army's units and the camp's defences,
## and one unique unit only it fields. Read by HuntArmy (damage, health,
## extraction), HuntCamps (defences, building costs) and Career (prices,
## what the depot sells you).
##
## Multipliers per unit or module: "damage", "hp", "range", "cost" (1.0 when
## not given). A unique unit is listed in `unique` and is only for its
## nation.

const ARSENALS := {
	"aurora": {"doctrine": "DOCTRINE_AURORA", "unique": "swarm", "mods": {
		"scout_drone": {"hp": 1.3, "cost": 0.8}, "attack_drone": {"damage": 1.3, "hp": 1.2, "cost": 0.85},
		"gunship": {"damage": 1.15, "cost": 0.9}, "swarm": {"damage": 1.0},
		"tank": {"hp": 0.75, "damage": 0.85, "cost": 1.25}, "crawler": {"cost": 1.1},
	}},
	"meridian": {"doctrine": "DOCTRINE_MERIDIAN", "unique": "aegis_battery", "mods": {
		"turret": {"damage": 1.3, "range": 1.25}, "air_defense": {"damage": 1.3, "range": 1.3, "cost": 0.8},
		"walls": {"cost": 0.7}, "med_bay": {"cost": 0.8}, "barracks": {"cost": 0.8},
		"strike_jet": {"damage": 0.75}, "gunship": {"hp": 0.85},
	}},
	"vesper": {"doctrine": "DOCTRINE_VESPER", "unique": "raptor", "mods": {
		"strike_jet": {"damage": 1.35, "cost": 0.8}, "raptor": {"damage": 1.0}, "crawler": {"extract": 2.0},  # (extract: one more step a tick)
		"attack_drone": {"damage": 1.1},
		"turret": {"damage": 0.75}, "air_defense": {"damage": 0.7}, "tank": {"hp": 0.85},
	}},
	"halden": {"doctrine": "DOCTRINE_HALDEN", "unique": "bastion", "mods": {
		"tank": {"hp": 1.45, "damage": 1.25, "cost": 0.85}, "bastion": {"damage": 1.0}, "crawler": {"hp": 1.3},
		"scout_drone": {"cost": 1.2}, "attack_drone": {"damage": 0.75, "cost": 1.2}, "strike_jet": {"cost": 1.3},
	}},
}
## The unique units: which nation fields each.
const UNIQUE := {"swarm": "aurora", "aegis_battery": "meridian", "raptor": "vesper", "bastion": "halden"}


## A nation's multiplier `stat` for `unit` (1.0 for none, or no nation).
static func mod(nation: String, unit: String, stat: String) -> float:
	var a: Dictionary = ARSENALS.get(nation, {})
	return float(a.get("mods", {}).get(unit, {}).get(stat, 1.0))


## Whether `nation` may field `unit` (uniques are for their own nation).
static func allowed(nation: String, unit: String) -> bool:
	return not UNIQUE.has(unit) or UNIQUE[unit] == nation


## A hunter's nation id in a run ("" without one).
static func of(hunt: HuntRules, id: int) -> String:
	var who := hunt.squad.leader_of(id) if hunt.squad.is_member(id) else id
	var n := hunt.nation_of(who)
	if n == Nations.NONE and hunt.home_nations.has(who):
		n = int(hunt.home_nations[who])
	return Nations.id_of(n) if n != Nations.NONE else ""
