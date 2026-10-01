extends RefCounted
## Start countdown (3-2-1-GO) and the Mario Kart style rocket start.
## Pressing the throttle in the last BOOST_WINDOW seconds before GO gives a start boost
## (stronger the closer to GO). Holding it from earlier, or never pressing, gives none.

signal go

const COUNT_TIME := 3.0
const BOOST_WINDOW := 0.8
const MAX_BOOST := 1.2
const MIN_BOOST := 0.4
const GO_SHOW_TIME := 1.0

var remaining := COUNT_TIME
var started := false
var since_go := 0.0
var _press_remaining := -1.0    # countdown value when the throttle was pressed (-1 = not held)
var _was_held := false
var _held_from_early := false

## Throttle press timing -> boost duration in seconds (0 = none / too early).
static func boost_for_press(remaining_at_press: float) -> float:
	if remaining_at_press < 0.0 or remaining_at_press > BOOST_WINDOW:
		return 0.0
	return lerpf(MAX_BOOST, MIN_BOOST, remaining_at_press / BOOST_WINDOW)

## Advance the clock. Returns true on the frame GO happens.
func update(delta: float, throttle_held: bool) -> bool:
	if started:
		since_go += delta
		return false
	if throttle_held and not _was_held:
		_press_remaining = remaining
	elif not throttle_held:
		_press_remaining = -1.0
	_was_held = throttle_held
	remaining -= delta
	if remaining <= 0.0:
		remaining = 0.0
		started = true
		go.emit()
		return true
	return false

## Boost the player earns for the moment they pressed the throttle (call after GO).
func start_boost() -> float:
	return boost_for_press(_press_remaining)

func is_counting() -> bool:
	return not started

## Big on-screen text: "3", "2", "1", then "GO!" for a moment.
func label() -> String:
	if not started:
		return str(int(ceil(remaining)))
	return "GO!" if since_go < GO_SHOW_TIME else ""
