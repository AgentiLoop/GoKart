extends RefCounted
## Computer driver for AI karts (pure logic, no nodes): pure-pursuit steering along the
## track centerline with a personal lane offset, stuck recovery (reverse out of walls)
## and a simple item-use policy. Unit tested.

const Items := preload("res://scripts/items.gd")

const STUCK_SPEED := 1.5
const STUCK_TIME := 1.2
const REVERSE_TIME := 0.9
const CORNER_SAMPLES := 12     # samples ahead used to measure how sharp the upcoming bend is
const CORNER_TURN_RATE := 1.5  # rad/s the AI is willing to turn at when picking a corner speed
const MIN_CORNER_SPEED := 14.0
const DODGE_LOOKAHEAD := 4     # samples ahead aimed at while steering round traffic (sharper than lookahead)
const ICE_LOOKAHEAD := 24      # samples ahead an icy stretch is allowed for when picking a corner speed
## Mario Kart 64 rubber-banding: gaps inside BAND_DEAD metres leave the AI alone; from there the
## top-speed bonus (behind the player) or penalty (ahead) grows linearly to its full value at BAND_RANGE.
const BAND_DEAD := 10.0
const BAND_RANGE := 90.0
## Mario Kart 64 item tricks: a single shell is fired straight back at a rival this close behind
## (when nobody is in range ahead); a banana / fake box is tossed ahead at a rival this close in front.
const BACK_SHOT_RANGE := 15.0
const TOSS_RANGE := 12.0

var track
var lane_offset := 0.0      # metres right of the centerline to aim for
var lookahead := 6         # samples ahead of the nearest sample to aim at
var steer_gain := 2.5
var use_delay := 1.5        # seconds an item is held before the AI considers using it
var idx := -1
var hold_time := 0.0
var use_alt := false        # set by wants_use: fire / toss the item the other way (see use_item)
var stuck_time := 0.0
var reverse_time := 0.0
## Set each tick by the race scene: a level crossing just ahead is blocked by the train, so stop
## and wait for it to pass (MK64 CPU drivers always do).
var wait := false
## Set each tick by the race scene on a traffic course: the vehicles ahead block lane_offset, so aim
## for dodge_lane instead until the way is clear (MK64 CPU karts weave through Toad's Turnpike traffic).
var dodging := false
var dodge_lane := 0.0
## Set each tick by the race scene: KartPhysics.ICE_GRIP when the kart is on, or about to reach, an icy
## stretch (MK64 Sherbet Land) — the driver only counts on that much of its steering for the bend ahead.
var grip := 1.0

func _init(track_data, lane := 0.0, delay := 1.5) -> void:
	track = track_data
	lane_offset = lane
	use_delay = delay

## Returns {throttle, brake, steer, drift} for this tick. controllable is false while
## the kart is spinning out (stuck detection is paused then).
func decide(delta: float, pos: Vector3, heading: float, speed: float, controllable := true) -> Dictionary:
	idx = track.nearest_index(pos, idx)
	var ti: int = (idx + (DODGE_LOOKAHEAD if dodging else lookahead)) % track.count
	var target: Vector3 = track.points[ti] + track.right_of(ti) * (dodge_lane if dodging else lane_offset)
	var want := atan2(-(target.x - pos.x), -(target.z - pos.z))
	var err := wrapf(want - heading, -PI, PI)
	var steer := clampf(-err * steer_gain, -1.0, 1.0)

	if wait:
		stuck_time = 0.0   # standing at the crossing is not being stuck
		return {"throttle": 0.0, "brake": 1.0 if speed > 0.0 else 0.0, "steer": steer, "drift": false}
	if not controllable or absf(speed) >= STUCK_SPEED:
		stuck_time = 0.0
	elif reverse_time <= 0.0:
		stuck_time += delta
		if stuck_time >= STUCK_TIME:
			stuck_time = 0.0
			reverse_time = REVERSE_TIME
	if reverse_time > 0.0:
		reverse_time -= delta
		# steering is mirrored while reversing, so flip it to swing the nose toward the target
		return {"throttle": 0.0, "brake": 1.0, "steer": -steer, "drift": false}
	var safe := corner_speed(idx)
	if speed > safe + 2.0:
		return {"throttle": 0.0, "brake": 0.5 if speed > safe + 8.0 else 0.0, "steer": steer, "drift": false}
	return {"throttle": 1.0, "brake": 0.0, "steer": steer, "drift": false}

## Highest speed at which the upcoming bend can be taken with CORNER_TURN_RATE of steering. On ice the
## kart runs wide while the slide builds before the tires catch up, so the driver only counts on
## grip squared of its steering there.
func corner_speed(i: int) -> float:
	var ang := absf(wrapf(track.heading_at((i + CORNER_SAMPLES) % track.count) - track.heading_at(i), -PI, PI))
	if ang < 0.01:
		return INF
	return maxf(CORNER_TURN_RATE * grip * grip * CORNER_SAMPLES * track.spacing / ang, MIN_CORNER_SPEED)

## Top-speed multiplier for an AI kart that is `gap` metres behind the player (negative = ahead).
## strength is the largest fraction added when far behind or removed when far ahead (0 = off).
static func rubber_band(gap: float, strength: float) -> float:
	if strength <= 0.0 or absf(gap) <= BAND_DEAD:
		return 1.0
	var g := (absf(gap) - BAND_DEAD) / (BAND_RANGE - BAND_DEAD)
	return 1.0 + signf(gap) * clampf(g, 0.0, 1.0) * strength

## Should the AI use its held item now? gap_ahead / gap_behind: distance to the nearest
## rival in front / behind (INF if none). Sets use_alt when the item should go the other way
## (Mario Kart 64 CPU tricks): a single shell fired back at a tailgater when nobody is in range
## ahead, a banana / fake box tossed ahead at a rival just in front when nobody follows.
func wants_use(delta: float, item: int, gap_ahead: float, gap_behind: float) -> bool:
	use_alt = false
	if item == Items.Type.NONE:
		hold_time = 0.0
		return false
	hold_time += delta
	if hold_time < use_delay:
		return false
	var use := false
	match item:
		Items.Type.MUSHROOM, Items.Type.TRIPLE_MUSHROOM, Items.Type.GOLDEN_MUSHROOM:
			use = true
		Items.Type.SHELL:
			use_alt = not gap_ahead < 50.0 and gap_behind < BACK_SHOT_RANGE
			use = gap_ahead < 50.0 or use_alt or hold_time > 10.0
		Items.Type.TRIPLE_SHELL:
			use = gap_ahead < 50.0 or hold_time > 10.0
		Items.Type.RED_SHELL:
			use_alt = not gap_ahead < 80.0 and gap_behind < BACK_SHOT_RANGE
			use = gap_ahead < 80.0 or use_alt or hold_time > 10.0
		Items.Type.TRIPLE_RED_SHELL:
			use = gap_ahead < 80.0 or hold_time > 10.0
		Items.Type.STAR, Items.Type.LIGHTNING, Items.Type.BLUE_SHELL, Items.Type.BOO:
			use = true
		Items.Type.BANANA, Items.Type.FAKE_ITEM_BOX:
			use_alt = not gap_behind < 20.0 and gap_ahead < TOSS_RANGE
			use = gap_behind < 20.0 or use_alt or hold_time > 8.0
		Items.Type.BANANA_BUNCH:
			use = gap_behind < 20.0 or hold_time > 8.0
	if use:
		hold_time = 0.0
	return use
