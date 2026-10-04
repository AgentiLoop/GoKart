extends RefCounted
## Pure arcade kart model (no scene dependencies) so it can be unit tested.
## Handles speed, steering, Mario Kart 64 style powerslides, the stick-toggle mini-turbo and the
## slipstream draft boost (the race scene says each frame whether the kart sits in another's wake).

signal drift_started(direction: int)
signal drift_level_changed(level: int)
signal boost_started(level: int)
signal boost_ended
signal spin_started
signal spin_ended
signal star_started
signal star_ended
signal shrink_started
signal shrink_ended
signal ghost_started
signal ghost_ended
signal stall_started
signal stall_ended
signal draft_started
signal draft_ended

var max_speed := 30.0
var reverse_max_speed := 10.0
var acceleration := 16.0
var brake_force := 40.0
var friction := 8.0
var turn_rate := 2.3            # rad/s at full steer (low speed)
var high_speed_turn_scale := 0.75   # fraction of turn_rate left at top speed (stability)
var min_drift_speed := 10.0
## MK64 mini-turbo: the charge is the number of steering toggles made during the slide (steer out of the
## drift, then back in). One toggle turns the smoke yellow (level 1), a second turns it red (level 2);
## only a red slide gives a boost when the drift is released.
var drift_charge_thresholds := [1.0, 2.0]
var boost_durations := [0.0, 1.3]
## Stick deflection (|steer| against / with the drift) that counts as steering out / back in.
const TOGGLE_STEER := 0.3
var boost_speed_factor := 1.4
var boost_acceleration := 45.0
var surface_scale := 1.0        # <1 on grass/off-road: scales top speed (boost ignores it)

var speed := 0.0
var drifting := false
var drift_direction := 0
var drift_charge := 0.0         # completed steering toggles in the current slide
var drift_level := 0
var drift_outward := false      # the stick has been pushed against the drift; back in completes a toggle
var boost_time := 0.0
var boost_level := 0
var boost_from_drift := false   # true while the current boost is a drift mini-turbo
var spin_duration := 1.2        # seconds spent spinning out after a hit (banana / shell)
var hit_immunity_time := 1.5    # grace period after recovering from a spin
var spin_time := 0.0
var immunity_time := 0.0
var star_duration := 7.0        # seconds of invincibility from a star
var star_speed_factor := 1.2
var star_time := 0.0
var shrink_duration := 7.0      # seconds a lightning strike keeps a kart small and slow
var shrink_speed_factor := 0.7
var shrink_time := 0.0
var ghost_duration := 5.0       # seconds a Boo keeps the kart see-through and untouchable
var ghost_time := 0.0
var stall_duration := 1.5       # MK64 false start: the tires burn out and the kart goes nowhere
var stall_time := 0.0
## MK64 slipstream: trail close behind another kart for draft_charge_time and the kart gets a brief
## burst of speed (the top speed rises by draft_speed_factor for draft_boost_duration).
var draft_charge_time := 2.0
var draft_boost_duration := 1.5
var draft_speed_factor := 1.15
var draft_time := 0.0           # seconds spent in another kart's wake so far (0 when out of it)
var draft_boost_time := 0.0

func is_boosting() -> bool:
	return boost_time > 0.0

func is_drafting() -> bool:
	return draft_time > 0.0

func is_draft_boosting() -> bool:
	return draft_boost_time > 0.0

## Called every physics frame with whether the kart sits in another kart's wake (Slipstream.in_wake):
## the time in the wake adds up and after draft_charge_time the draft boost fires (and the count
## starts over); leaving the wake, a spin or a false start drops the charge. Returns true on the
## frame the boost fires.
func update_draft(delta: float, in_wake: bool) -> bool:
	if not in_wake or is_spinning() or is_stalled():
		draft_time = 0.0
		return false
	draft_time += delta
	if draft_time < draft_charge_time:
		return false
	draft_time = 0.0
	var was := is_draft_boosting()
	draft_boost_time = draft_boost_duration
	if not was:
		draft_started.emit()
	return true

## Drops the draft boost (a hit, a dead stop); emits draft_ended if one was running.
func _end_draft() -> void:
	draft_time = 0.0
	if draft_boost_time > 0.0:
		draft_boost_time = 0.0
		draft_ended.emit()

func is_stalled() -> bool:
	return stall_time > 0.0

## Mario Kart 64 false start: the throttle was held too early during the countdown, so the kart
## sits still with spinning tires for stall_duration before it can pull away.
func stall(duration := -1.0) -> void:
	var was := is_stalled()
	stall_time = maxf(stall_time, stall_duration if duration < 0.0 else duration)
	speed = 0.0
	if not was:
		stall_started.emit()

## Mario Kart 64 engine class: scales this kart's top speed and acceleration (50cc < 100cc < 150cc).
## Call once, right after creation.
func apply_engine_class(speed_scale: float, accel_scale: float) -> void:
	max_speed *= speed_scale
	reverse_max_speed *= speed_scale
	acceleration *= accel_scale
	boost_acceleration *= accel_scale

## Mario Kart 64 weight class: the same scaling, stacked on top of the engine class
## (light = quicker pick-up, heavy = higher top speed).
func apply_weight_class(speed_scale: float, accel_scale: float) -> void:
	apply_engine_class(speed_scale, accel_scale)

func is_star() -> bool:
	return star_time > 0.0

## Invincible: hits do nothing and the kart runs a bit faster, even off-road.
func apply_star(duration := -1.0) -> void:
	var was := is_star()
	star_time = maxf(star_time, star_duration if duration < 0.0 else duration)
	if not was:
		star_started.emit()

func is_shrunk() -> bool:
	return shrink_time > 0.0

func is_ghost() -> bool:
	return ghost_time > 0.0

## Boo (Mario Kart 64): the kart turns translucent and, like a star, nothing can hit it —
## shells and bananas pass straight through — but it gets no speed bonus.
func apply_ghost(duration := -1.0) -> void:
	var was := is_ghost()
	ghost_time = maxf(ghost_time, ghost_duration if duration < 0.0 else duration)
	if not was:
		ghost_started.emit()

## Lightning strike: smaller and slower for shrink_duration. A star or ghost kart is immune (returns false).
func apply_shrink(duration := -1.0) -> bool:
	if is_star() or is_ghost():
		return false
	var was := is_shrunk()
	shrink_time = maxf(shrink_time, shrink_duration if duration < 0.0 else duration)
	if not was:
		shrink_started.emit()
	return true

func current_max_speed() -> float:
	if is_boosting():
		return max_speed * boost_speed_factor
	if is_star():
		return max_speed * star_speed_factor
	if is_draft_boosting():
		return max_speed * draft_speed_factor * surface_scale
	if is_shrunk():
		return max_speed * shrink_speed_factor * surface_scale
	return max_speed * surface_scale

func is_spinning() -> bool:
	return spin_time > 0.0

## 0..1 through the current spin (0 when not spinning).
func spin_progress() -> float:
	return 1.0 - spin_time / spin_duration if is_spinning() else 0.0

## Get hit: lose control, boost and drift for spin_duration. Returns false (no effect)
## if already spinning or still immune.
func spin_out() -> bool:
	if is_spinning() or immunity_time > 0.0 or is_star() or is_ghost():
		return false
	spin_time = spin_duration
	boost_time = 0.0
	boost_level = 0
	boost_from_drift = false
	_end_draft()
	speed *= 0.5
	if drifting:
		drifting = false
		drift_direction = 0
		drift_charge = 0.0
		if drift_level != 0:
			drift_level = 0
			drift_level_changed.emit(0)
	spin_started.emit()
	return true

## Dead stop (fished out of the water by Lakitu): speed, boost and drift are all gone.
func stop() -> void:
	speed = 0.0
	if boost_time > 0.0:
		boost_time = 0.0
		boost_level = 0
		boost_from_drift = false
		boost_ended.emit()
	_end_draft()
	drifting = false
	drift_direction = 0
	drift_charge = 0.0
	if drift_level != 0:
		drift_level = 0
		drift_level_changed.emit(0)

## Instant boost (mushroom, boost pad, start boost).
func apply_boost(duration: float, level: int = 1, from_drift: bool = false) -> void:
	var was := is_boosting()
	boost_time = maxf(boost_time, duration)
	boost_level = maxi(boost_level, level)
	if from_drift or not was:
		boost_from_drift = from_drift
	if not was or from_drift:
		boost_started.emit(level)

func _update_level() -> void:
	var lvl := 0
	for i in drift_charge_thresholds.size():
		if drift_charge >= drift_charge_thresholds[i]:
			lvl = i + 1
	if lvl != drift_level:
		drift_level = lvl
		drift_level_changed.emit(lvl)

func _start_drift(steer: float) -> void:
	drifting = true
	drift_direction = 1 if steer > 0.0 else -1
	drift_charge = 0.0
	drift_level = 0
	drift_outward = false
	drift_started.emit(drift_direction)

func _end_drift() -> void:
	if drift_level > 0 and boost_durations[drift_level - 1] > 0.0:
		apply_boost(boost_durations[drift_level - 1], drift_level, true)
	drifting = false
	drift_direction = 0
	drift_charge = 0.0
	if drift_level != 0:
		drift_level = 0
		drift_level_changed.emit(0)

## Eases a digital steering input toward its target (Mario Kart style): ramps up quickly,
## returns to centre a bit faster, and counter-steering reverses faster still.
static func smooth_steer(current: float, target: float, delta: float) -> float:
	var rate := 7.0
	if absf(target) < 0.01:
		rate = 10.0
	elif signf(target) != signf(current) and absf(current) > 0.01:
		rate = 14.0
	return move_toward(current, target, rate * delta)

## Advance one tick. steer: -1 (left) .. +1 (right). Returns yaw change in radians
## (positive = turn left / counter-clockwise seen from above).
func step(delta: float, throttle: float, brake: float, steer: float, drift_held: bool) -> float:
	# --- boost timer
	if boost_time > 0.0:
		boost_time -= delta
		if boost_time <= 0.0:
			boost_time = 0.0
			boost_level = 0
			boost_from_drift = false
			boost_ended.emit()

	if draft_boost_time > 0.0:
		draft_boost_time -= delta
		if draft_boost_time <= 0.0:
			draft_boost_time = 0.0
			draft_ended.emit()

	if star_time > 0.0:
		star_time -= delta
		if star_time <= 0.0:
			star_time = 0.0
			star_ended.emit()

	if shrink_time > 0.0:
		shrink_time -= delta
		if shrink_time <= 0.0:
			shrink_time = 0.0
			shrink_ended.emit()

	if ghost_time > 0.0:
		ghost_time -= delta
		if ghost_time <= 0.0:
			ghost_time = 0.0
			ghost_ended.emit()

	# --- spin out: no control, speed bleeds off
	if immunity_time > 0.0:
		immunity_time = maxf(immunity_time - delta, 0.0)
	if spin_time > 0.0:
		spin_time -= delta
		speed = move_toward(speed, 0.0, friction * 3.0 * delta)
		if spin_time <= 0.0:
			spin_time = 0.0
			immunity_time = hit_immunity_time
			spin_ended.emit()
		return 0.0

	# --- false start: tires spin, the kart does not move or turn
	if stall_time > 0.0:
		stall_time -= delta
		speed = 0.0
		if stall_time <= 0.0:
			stall_time = 0.0
			stall_ended.emit()
		return 0.0

	# --- drift state machine
	if drift_held and not drifting and speed >= min_drift_speed and absf(steer) > 0.3:
		_start_drift(steer)
	elif drifting and (not drift_held or speed < min_drift_speed * 0.5):
		_end_drift()

	# --- speed
	var top := current_max_speed()
	if throttle > 0.0:
		var a := boost_acceleration if is_boosting() or is_draft_boosting() else acceleration
		speed = minf(speed + a * throttle * delta, top) if speed < top else maxf(speed - friction * delta, top)
	elif brake > 0.0:
		if speed > 0.0:
			speed = maxf(speed - brake_force * brake * delta, 0.0)
		else:
			speed = maxf(speed - acceleration * brake * delta, -reverse_max_speed)
	else:
		speed = move_toward(speed, 0.0, friction * delta)
	if speed > top:
		speed = maxf(speed - friction * delta, top)

	# --- steering
	var yaw := 0.0
	var speed_factor := clampf(absf(speed) / 4.0, 0.0, 1.0)
	if throttle > 0.0 or brake > 0.0:
		speed_factor = maxf(speed_factor, 0.45)   # can still pivot off a wall while pinned against it
	var dir_sign := signf(speed) if speed != 0.0 else 1.0
	if drifting:
		# Steering widens/tightens the arc but cannot reverse the drift direction.
		var arc := 0.9 + 0.5 * steer * drift_direction   # 0.4 .. 1.4
		yaw = -drift_direction * turn_rate * arc * delta   # right drift -> negative yaw (clockwise)
		# MK64 mini-turbo: push the stick against the slide, then back into it, to charge a stage.
		var inward := steer * drift_direction
		if inward < -TOGGLE_STEER:
			drift_outward = true
		elif inward > TOGGLE_STEER and drift_outward:
			drift_outward = false
			if drift_charge < drift_charge_thresholds[-1]:
				drift_charge += 1.0
				_update_level()
	else:
		var grip := lerpf(1.0, high_speed_turn_scale, clampf(absf(speed) / max_speed, 0.0, 1.0))
		yaw = -steer * turn_rate * grip * speed_factor * dir_sign * delta
	return yaw
