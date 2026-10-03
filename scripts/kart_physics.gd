extends RefCounted
## Pure arcade kart model (no scene dependencies) so it can be unit tested.
## Handles speed, steering, Mario Kart style drifting and mini-turbo boosts.

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

var max_speed := 30.0
var reverse_max_speed := 10.0
var acceleration := 16.0
var brake_force := 40.0
var friction := 8.0
var turn_rate := 2.3            # rad/s at full steer (low speed)
var high_speed_turn_scale := 0.75   # fraction of turn_rate left at top speed (stability)
var min_drift_speed := 10.0
var drift_charge_thresholds := [0.8, 1.6, 2.6]   # seconds for blue / orange / purple
var boost_durations := [0.6, 1.0, 1.5]
var boost_speed_factor := 1.4
var boost_acceleration := 45.0
var surface_scale := 1.0        # <1 on grass/off-road: scales top speed (boost ignores it)

var speed := 0.0
var drifting := false
var drift_direction := 0
var drift_charge := 0.0
var drift_level := 0
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

func is_boosting() -> bool:
	return boost_time > 0.0

## Mario Kart 64 engine class: scales this kart's top speed and acceleration (50cc < 100cc < 150cc).
## Call once, right after creation.
func apply_engine_class(speed_scale: float, accel_scale: float) -> void:
	max_speed *= speed_scale
	reverse_max_speed *= speed_scale
	acceleration *= accel_scale
	boost_acceleration *= accel_scale

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

## Lightning strike: smaller and slower for shrink_duration. A star kart is immune (returns false).
func apply_shrink(duration := -1.0) -> bool:
	if is_star():
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
	if is_spinning() or immunity_time > 0.0 or is_star():
		return false
	spin_time = spin_duration
	boost_time = 0.0
	boost_level = 0
	boost_from_drift = false
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
	drift_started.emit(drift_direction)

func _end_drift() -> void:
	if drift_level > 0:
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

	# --- drift state machine
	if drift_held and not drifting and speed >= min_drift_speed and absf(steer) > 0.3:
		_start_drift(steer)
	elif drifting and (not drift_held or speed < min_drift_speed * 0.5):
		_end_drift()

	# --- speed
	var top := current_max_speed()
	if throttle > 0.0:
		var a := boost_acceleration if is_boosting() else acceleration
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
		drift_charge += delta * (1.0 + 0.4 * maxf(steer * drift_direction, 0.0))
		_update_level()
	else:
		var grip := lerpf(1.0, high_speed_turn_scale, clampf(absf(speed) / max_speed, 0.0, 1.0))
		yaw = -steer * turn_rate * grip * speed_factor * dir_sign * delta
	return yaw
