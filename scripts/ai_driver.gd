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

var track
var lane_offset := 0.0      # metres right of the centerline to aim for
var lookahead := 6         # samples ahead of the nearest sample to aim at
var steer_gain := 2.5
var use_delay := 1.5        # seconds an item is held before the AI considers using it
var idx := -1
var hold_time := 0.0
var stuck_time := 0.0
var reverse_time := 0.0

func _init(track_data, lane := 0.0, delay := 1.5) -> void:
	track = track_data
	lane_offset = lane
	use_delay = delay

## Returns {throttle, brake, steer, drift} for this tick. controllable is false while
## the kart is spinning out (stuck detection is paused then).
func decide(delta: float, pos: Vector3, heading: float, speed: float, controllable := true) -> Dictionary:
	idx = track.nearest_index(pos, idx)
	var ti: int = (idx + lookahead) % track.count
	var target: Vector3 = track.points[ti] + track.right_of(ti) * lane_offset
	var want := atan2(-(target.x - pos.x), -(target.z - pos.z))
	var err := wrapf(want - heading, -PI, PI)
	var steer := clampf(-err * steer_gain, -1.0, 1.0)

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

## Highest speed at which the upcoming bend can be taken with CORNER_TURN_RATE of steering.
func corner_speed(i: int) -> float:
	var ang := absf(wrapf(track.heading_at((i + CORNER_SAMPLES) % track.count) - track.heading_at(i), -PI, PI))
	if ang < 0.01:
		return INF
	return maxf(CORNER_TURN_RATE * CORNER_SAMPLES * track.spacing / ang, MIN_CORNER_SPEED)

## Should the AI use its held item now? gap_ahead / gap_behind: distance to the nearest
## rival in front / behind (INF if none).
func wants_use(delta: float, item: int, gap_ahead: float, gap_behind: float) -> bool:
	if item == Items.Type.NONE:
		hold_time = 0.0
		return false
	hold_time += delta
	if hold_time < use_delay:
		return false
	var use := false
	match item:
		Items.Type.MUSHROOM:
			use = true
		Items.Type.SHELL:
			use = gap_ahead < 50.0 or hold_time > 10.0
		Items.Type.RED_SHELL:
			use = gap_ahead < 80.0 or hold_time > 10.0
		Items.Type.STAR, Items.Type.LIGHTNING:
			use = true
		Items.Type.BANANA:
			use = gap_behind < 20.0 or hold_time > 8.0
	if use:
		hold_time = 0.0
	return use
