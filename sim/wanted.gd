class_name Wanted
extends RefCounted
## THE HUNT's wanted level with the Kasei Marshals (Mars' police): crimes
## raise it (0..MAX stars); the Marshals send more officers the higher it
## is; out of their sight long enough and they lose you (the stars clear).
## Pure rules: the city counts what the Marshals can see.

const MAX := 5
## Officers out after you, by stars.
const OFFICERS := [0, 2, 3, 5, 6, 8]
## Crimes and their stars.
const CRIMES := {"holdup": 1, "convoy": 2, "theft": 2, "rover": 1, "officer_down": 1, "assault": 1, "burglary": 2, "burglary_quiet": 1, "shots": 1, "trespass": 1,
		"vandalism": 1}

var stars: int = 0
var unseen: float = 0.0  ## seconds out of every officer's sight


## `masked`: they can't name you, one star less (never below one).
func commit(crime: String, masked: bool = false) -> int:
	var add := int(CRIMES.get(crime, 1))
	if masked:
		add = maxi(add - 1, 1)
	stars = mini(stars + add, MAX)
	unseen = 0.0
	return stars


## How long you must stay out of sight to lose them.
func escape_time() -> float:
	return 8.0 + 5.0 * stars


## One step: `seen` while any officer has eyes on you. True when they lose you.
func step(dt: float, seen: bool) -> bool:
	if stars == 0:
		return false
	if seen:
		unseen = 0.0
		return false
	unseen += dt
	if unseen >= escape_time():
		stars = 0
		unseen = 0.0
		return true
	return false


func officers() -> int:
	return OFFICERS[stars]


func clear() -> void:
	stars = 0
	unseen = 0.0
