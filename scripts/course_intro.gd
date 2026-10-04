extends RefCounted
## Mario Kart 64 style course intro: before the countdown the camera flies over the course in a
## few cuts while a card at the bottom of the screen names the course (MK64 shows the course name
## over a fly-by of the track after the select screen; Start skips it). Pure timing / camera maths;
## main.gd drives the camera and the HUD card from it, and `pending` says whether the next race
## scene should open with the intro (the menu sets it; tools that load the race scene directly
## never see one).

const Attract := preload("res://scripts/attract.gd")

## The whole intro, in seconds, and the cuts it is made of (each flies along a different stretch
## of the road; the last one ends over the grid, where the race camera takes over).
const TIME := 6.0
const CUTS := 3
const CUT_TIME := TIME / CUTS
## Fly-over camera: speed along the road, height over it, offset to the right of the centre
## line, how far down the road it looks (samples) and how high above the road it aims.
const FLY_SPEED := 22.0
const FLY_UP := 10.0
const FLY_SIDE := 7.0
const FLY_AHEAD := 12
const FLY_LOOK_UP := 1.0
## Samples before the line the last cut ends at (over the back of the grid).
const GRID_BACK := 4
## The name card fades in while rising CARD_RISE px, and fades out at the end of the intro.
const CARD_IN := 0.35
const CARD_OUT := 0.35
const CARD_RISE := 24.0

## True when the next race scene should open with the intro (set by the menu / the next cup race).
static var pending := false

## Which cut `t` seconds into the intro belongs to (clamped to the last). Pure.
static func cut_index(t: float) -> int:
	return clampi(int(floor(t / CUT_TIME)), 0, CUTS - 1)

## Where along the loop (in samples) the camera is `t` seconds in: cut i runs forward along the
## road and ends GRID_BACK samples before fraction (i + 1) / CUTS of the loop, so the last cut
## ends behind the start line, over the grid. Pure.
static func fly_s(t: float, count: int, spacing: float) -> float:
	var i := cut_index(t)
	var into := clampf(t - i * CUT_TIME, 0.0, CUT_TIME)
	var end := float(count) * (i + 1) / CUTS - GRID_BACK
	return end - (CUT_TIME - into) * FLY_SPEED / spacing

## Camera pose `t` seconds in: FLY_SIDE right of the road, FLY_UP above it, looking down the
## road at the point FLY_AHEAD samples on (a little above it). Pure.
static func cam_pose(t: float, points: PackedVector3Array, spacing: float) -> Dictionary:
	var s := fly_s(t, points.size(), spacing)
	var pos := Attract.loop_sample(points, s)
	var ahead := Attract.loop_sample(points, s + FLY_AHEAD)
	var dir := Vector3(ahead.x - pos.x, 0.0, ahead.z - pos.z)
	dir = dir.normalized() if dir.length() > 0.001 else Vector3(0, 0, -1)
	var right := dir.cross(Vector3.UP)
	return {"pos": pos + right * FLY_SIDE + Vector3(0, FLY_UP, 0), "look": ahead + Vector3(0, FLY_LOOK_UP, 0)}

## The name card `t` seconds in: alpha (in over CARD_IN, out over the last CARD_OUT) and its
## y offset (CARD_RISE px low while it fades in, 0 once up). Pure.
static func card_pose(t: float) -> Dictionary:
	var a_in := clampf(t / CARD_IN, 0.0, 1.0)
	var a_out := clampf((TIME - t) / CARD_OUT, 0.0, 1.0)
	var u := 1.0 - (1.0 - a_in) * (1.0 - a_in)
	return {"alpha": minf(a_in, a_out), "y": CARD_RISE * (1.0 - u)}

## True once `t` seconds have passed, or at once when the player skips (MK64: Start skips the intro). Pure.
static func finished(t: float, skip: bool) -> bool:
	return skip or t >= TIME

## The line over the course name: the mode and the class — "GRAND PRIX  ·  RACE 1 / 4  ·  150cc",
## "TIME TRIAL  ·  100cc" or "150cc  ·  3 LAPS" for a single race. Pure.
static func caption(gp_label: String, time_trial: bool, engine_name: String, laps: int) -> String:
	if gp_label != "":
		return "GRAND PRIX  ·  %s  ·  %s" % [gp_label, engine_name]
	if time_trial:
		return "TIME TRIAL  ·  %s" % engine_name
	return "%s  ·  %d %s" % [engine_name, laps, "LAP" if laps == 1 else "LAPS"]
