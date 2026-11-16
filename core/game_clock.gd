class_name GameClock
extends RefCounted
## THE HUNT's clock on Mars: a sol (day) passes every DAY_SECONDS of real
## time, so evenings come round while you play. Shops open and close by it,
## people keep their hours, the sky darkens at night.

const DAY_SECONDS := 2400.0   ## 40 minutes a sol
const OPEN_HOURS := Vector2(7, 22)   ## most shops
const BAR_HOURS := Vector2(16, 4)    ## the bars: late afternoon till four


## The hour of the sol (0..24) at unix time `now`.
static func hour(now: float) -> float:
	return fmod(now, DAY_SECONDS) / DAY_SECONDS * 24.0


## Whether `h` falls in `hours` (from, to), which may wrap past midnight.
static func within(hours: Vector2, h: float) -> bool:
	if hours.x <= hours.y:
		return h >= hours.x and h < hours.y
	return h >= hours.x or h < hours.y


## "14:20".
static func label(h: float) -> String:
	var m := int(h * 60.0) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## 0 at night .. 1 at noon: how much daylight there is.
static func daylight(h: float) -> float:
	return clampf(sin((h - 6.0) / 12.0 * PI) * 1.6, 0.0, 1.0)
