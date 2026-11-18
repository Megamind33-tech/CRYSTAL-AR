class_name Stride
extends RefCounted
## The walk cycle, shared by the bodies (ArmoredRig, MeshyRig) and the
## footsteps (GameAudio), so a step sounds when a boot comes down.
##
## The Walk, Jog_Fwd and Sprint clips are stretched to one common cycle and
## blended in step (their feet touch down at the same point of the cycle),
## played at `rate(speed)` cycles a second. The blend picks the stride that
## covers the ground at that cadence, so the planted foot stays put on the
## floor instead of sliding. Numbers from tools/gait_measure.gd.

## Cycles a second against ground speed (m/s): a slow stroll, a brisk walk
## (the touch WALK gait, 1.8 m/s, ~114 steps a minute), the jog (5 m/s,
## ~130), the sprint (7.2 m/s, ~160). Below the first point the cycle slows
## with the speed (the feet stay planted).
const CADENCE := [[0.87, 0.75], [1.8, 0.95], [5.35, 1.07], [8.3, 1.5]]
const MIN_RATE := 0.45
## Under this ground speed (m/s) a body stands (the idle clip) and no steps
## sound; starting to move again starts the cycle over.
const MOVING := 0.3
## Where each boot touches down, as a fraction of the cycle (left, right):
## the clips agree within 0.05 (Walk 0.08/0.57, Jog 0.04-0.09/0.55, Sprint
## 0.06-0.16/0.61).
const CONTACTS := [0.07, 0.57]
## Metres covered by one cycle of Walk, Jog_Fwd, Sprint (in place clips:
## the planted foot's speed times the clip's length) per body family.
const MESHY := [1.16, 4.99, 5.53]
const ARMORED := [1.37, 5.84, 6.34]
## Crouch-walking (Crouch_Fwd is not blended): metres per cycle.
const CROUCH_STRIDE := 1.4


## Cycles a second at a ground speed.
static func rate(speed: float) -> float:
	var pts: Array = CADENCE
	if speed <= pts[0][0]:
		return maxf(speed / (float(pts[0][0]) / float(pts[0][1])), MIN_RATE) if speed > 0.0 else 0.0
	for i in range(1, pts.size()):
		if speed <= pts[i][0]:
			var t := (speed - float(pts[i - 1][0])) / (float(pts[i][0]) - float(pts[i - 1][0]))
			return lerpf(pts[i - 1][1], pts[i][1], t)
	var last: Array = pts[pts.size() - 1]
	return float(last[1]) * speed / float(last[0])  # faster: the sprint's stride, quicker


## Cycles a second crouch-walking.
static func crouch_rate(speed: float) -> float:
	return speed / CROUCH_STRIDE


## The blend over [Walk, Jog_Fwd, Sprint] (0 = Walk, 1 = Jog_Fwd, 2 =
## Sprint) whose stride covers `speed` at `rate(speed)`, for a body whose
## clips cover `strides` metres a cycle (scaled by `size`).
static func blend(speed: float, strides: Array, size: float = 1.0) -> float:
	var r := rate(speed)
	if r <= 0.0:
		return 0.0
	var want := speed / r / maxf(size, 0.01)
	if want <= strides[0]:
		return 0.0
	for i in range(1, strides.size()):
		if want <= strides[i]:
			return float(i - 1) + (want - float(strides[i - 1])) / (float(strides[i]) - float(strides[i - 1]))
	return float(strides.size() - 1)


## The boots that touch down while the cycle goes from `from` to `to`
## (cycles, not wrapped): 0 left, 1 right, in order.
static func contacts_between(from: float, to: float) -> Array[int]:
	var out: Array[int] = []
	if to <= from:
		return out
	var base := floorf(from)
	while base <= to:
		for side in 2:
			var c := base + float(CONTACTS[side])
			if c > from and c <= to:
				out.append(side)
		base += 1.0
	return out
