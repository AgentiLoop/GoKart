extends RefCounted
## Computer driver for a Mario Kart 64 battle (pure logic, no nodes): with an empty slot it hunts
## the nearest item box, with an item it chases the nearest kart that still has balloons; a bomb
## kart just chases. Simple feelers ahead keep it off the walls, the forts and the lava, with the
## same stuck recovery as the race driver. Unit tested.

const Items := preload("res://scripts/items.gd")

const STUCK_SPEED := 1.5
const STUCK_TIME := 1.2
const REVERSE_TIME := 0.9
const FEELER := 9.0            # metres ahead the driver looks for an obstacle
const FEELER_ANGLE := 0.6      # radians the side feelers are swung out
const SHELL_RANGE := 35.0      # fire a shell when a rival is this close ahead
const DROP_RANGE := 14.0       # drop a banana / fake box when a rival is this close behind
const BACK_SHOT_RANGE := 12.0  # fire a single shell straight back at a rival this close behind (nobody ahead)
const TOSS_RANGE := 12.0       # toss a banana / fake box ahead at a rival this close in front (nobody behind)
const MUSHROOM_RANGE := 25.0   # boost at a target further away than this
const STEER_GAIN := 2.5
const TURN_SPEED := 18.0       # ease off above this while turning hard towards the target

var arena
var goal = null                # Vector3 to drive at (set by the scene each tick), or null
var use_delay := 1.5
var hold_time := 0.0
var use_alt := false           # set by wants_use: fire / toss the item the other way (see use_item)
var stuck_time := 0.0
var reverse_time := 0.0
var avoiding := 0.0            # last avoidance steer (for checks/tests)

func _init(arena_data, delay := 1.5) -> void:
	arena = arena_data
	use_delay = delay

static func _forward(heading: float) -> Vector3:
	return Vector3(-sin(heading), 0, -cos(heading))

## Where to drive: the nearest available box when the slot is empty (and we're allowed to pick up),
## otherwise the nearest kart in `targets`. null when there is nothing to go for.
static func pick_goal(pos: Vector3, item: int, boxes: Array, targets: Array, can_pickup := true):
	var pool: Array = boxes if (item == Items.Type.NONE and can_pickup and not boxes.is_empty()) else targets
	var best = null
	var best_d := INF
	for p in pool:
		var d: float = Vector2(p.x - pos.x, p.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best

## Steering (-1..1) that keeps the kart clear of what the feelers find: 0 when the way is clear.
func avoid_steer(pos: Vector3, heading: float) -> float:
	var fwd := _forward(heading)
	var ahead: bool = arena.obstacle_at(pos + fwd * FEELER)
	var left: bool = arena.obstacle_at(pos + _forward(heading + FEELER_ANGLE) * FEELER)
	var right: bool = arena.obstacle_at(pos + _forward(heading - FEELER_ANGLE) * FEELER)
	if not ahead and not left and not right:
		return 0.0
	if ahead and left and right:
		# boxed in: turn away from the arena wall / towards the centre
		return 1.0 if Vector3(pos.x, 0, pos.z).cross(fwd).y < 0.0 else -1.0
	if left and not right:
		return 1.0    # steer right
	if right and not left:
		return -1.0   # steer left
	# only straight ahead is blocked: swing towards the freer side (centre of the arena)
	return 1.0 if Vector3(pos.x, 0, pos.z).cross(fwd).y < 0.0 else -1.0

## Returns {throttle, brake, steer, drift} for this tick, driving at `goal` (cruising when null).
## Same signature as the race driver so the kart node can run either.
func decide(delta: float, pos: Vector3, heading: float, speed: float, controllable := true) -> Dictionary:
	var steer := 0.0
	if goal != null:
		var want := atan2(-(goal.x - pos.x), -(goal.z - pos.z))
		var err := wrapf(want - heading, -PI, PI)
		steer = clampf(-err * STEER_GAIN, -1.0, 1.0)
	var av := avoid_steer(pos, heading)
	avoiding = av
	if av != 0.0:
		steer = av
	if not controllable or absf(speed) >= STUCK_SPEED:
		stuck_time = 0.0
	elif reverse_time <= 0.0:
		stuck_time += delta
		if stuck_time >= STUCK_TIME:
			stuck_time = 0.0
			reverse_time = REVERSE_TIME
	if reverse_time > 0.0:
		reverse_time -= delta
		return {"throttle": 0.0, "brake": 1.0, "steer": -steer, "drift": false}
	var hard_turn := absf(steer) > 0.8 and speed > TURN_SPEED
	return {"throttle": 0.0 if hard_turn else 1.0, "brake": 0.0, "steer": steer, "drift": false}

## Use the held item? gap_ahead / gap_behind: distance to the nearest rival roughly in front /
## behind (INF if none), as the item manager measures them. Sets use_alt when the item should go the
## other way (Mario Kart 64): a single shell fired back at a kart close behind when nobody is ahead,
## a banana / fake box tossed ahead at a kart close in front when nobody follows.
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
		Items.Type.SHELL:
			use_alt = not gap_ahead < SHELL_RANGE and gap_behind < BACK_SHOT_RANGE
			use = gap_ahead < SHELL_RANGE or use_alt or hold_time > 10.0
		Items.Type.TRIPLE_SHELL:
			use = gap_ahead < SHELL_RANGE or hold_time > 10.0
		Items.Type.RED_SHELL:
			use_alt = not gap_ahead < SHELL_RANGE * 1.5 and gap_behind < BACK_SHOT_RANGE
			use = gap_ahead < SHELL_RANGE * 1.5 or use_alt or hold_time > 8.0
		Items.Type.TRIPLE_RED_SHELL:
			use = gap_ahead < SHELL_RANGE * 1.5 or hold_time > 8.0
		Items.Type.BANANA, Items.Type.FAKE_ITEM_BOX:
			use_alt = not gap_behind < DROP_RANGE and gap_ahead < TOSS_RANGE
			use = gap_behind < DROP_RANGE or use_alt or hold_time > 6.0
		Items.Type.BANANA_BUNCH:
			use = gap_behind < DROP_RANGE or hold_time > 6.0
		Items.Type.MUSHROOM, Items.Type.TRIPLE_MUSHROOM, Items.Type.GOLDEN_MUSHROOM:
			use = (gap_ahead > MUSHROOM_RANGE and gap_ahead < INF) or hold_time > 6.0
		_:
			use = true   # star, Boo (and anything else) right away
	if use:
		hold_time = 0.0
	return use
