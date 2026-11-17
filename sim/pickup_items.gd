class_name PickupItems
extends RefCounted
## What a world pickup puts in the career pack. The sim's "pickup" event
## carries {kind, item, count}; `career_item` maps it to a Career.ITEMS id.
## Career.ITEMS needs these ids (agent F): pulse_rifle, mag_pistol,
## rail_sniper, rocket_launcher (the arc launcher), bullets (loose rounds),
## ammo_case (a case of bullets); burst_rifle, scatter_gun, flux_smg and
## frag_grenade already exist.

const WEAPON_ITEM := {
	&"pulse_rifle": "pulse_rifle",
	&"burst_rifle": "burst_rifle",
	&"scatter_gun": "scatter_gun",
	&"flux_smg": "flux_smg",
	&"mag_pistol": "mag_pistol",
	&"rail_sniper": "rail_sniper",
	&"arc_launcher": "rocket_launcher",
}


## {item: String, count: int} for a pickup event, or {} when it adds nothing.
static func career_item(e: Dictionary) -> Dictionary:
	var n: int = e.get("count", 1)
	match e.get("kind", &"weapon"):
		&"grenade":
			return {"item": "frag_grenade", "count": 1}
		&"ammo_box":
			return {"item": "ammo_case", "count": 1}
		&"ammo":
			return {"item": "bullets", "count": n} if n > 0 else {}
		_:
			var id: String = WEAPON_ITEM.get(e.get("item", &""), "")
			return {"item": id, "count": 1} if id != "" else {}
