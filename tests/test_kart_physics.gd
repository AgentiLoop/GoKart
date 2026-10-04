extends RefCounted

const KartPhysics := preload("res://scripts/kart_physics.gd")
var runner

func _run(k, secs: float, throttle: float, brake: float, steer: float, drift: bool) -> float:
	var yaw := 0.0
	var dt := 1.0 / 60.0
	for i in int(secs / dt):
		yaw += k.step(dt, throttle, brake, steer, drift)
	return yaw

func test_accelerates_to_max_speed() -> void:
	var k = KartPhysics.new()
	_run(k, 5.0, 1.0, 0.0, 0.0, false)
	runner.check(is_equal_approx(k.speed, k.max_speed), "speed=%f" % k.speed)

func test_friction_stops_kart() -> void:
	var k = KartPhysics.new()
	k.speed = 20.0
	_run(k, 5.0, 0.0, 0.0, 0.0, false)
	runner.check(k.speed == 0.0, "speed=%f" % k.speed)

func test_brake_then_reverse_is_capped() -> void:
	var k = KartPhysics.new()
	k.speed = 10.0
	_run(k, 10.0, 0.0, 1.0, 0.0, false)
	runner.check(is_equal_approx(k.speed, -k.reverse_max_speed), "speed=%f" % k.speed)

func test_no_steer_when_stationary() -> void:
	var k = KartPhysics.new()
	var yaw := _run(k, 1.0, 0.0, 0.0, 1.0, false)
	runner.check(yaw == 0.0)

func test_steer_direction() -> void:
	var k = KartPhysics.new()
	k.speed = 20.0
	var left := _run(k, 0.5, 1.0, 0.0, -1.0, false)
	k.speed = 20.0
	var right := _run(k, 0.5, 1.0, 0.0, 1.0, false)
	runner.check(left > 0.0 and right < 0.0, "left=%f right=%f" % [left, right])

func test_drift_requires_speed_and_steer() -> void:
	var k = KartPhysics.new()
	k.speed = 3.0
	k.step(0.016, 1.0, 0.0, 1.0, true)
	runner.check(not k.drifting, "slow")
	k.speed = 20.0
	k.step(0.016, 1.0, 0.0, 0.0, true)
	runner.check(not k.drifting, "no steer")
	k.step(0.016, 1.0, 0.0, 1.0, true)
	runner.check(k.drifting and k.drift_direction == 1, "should drift right")

## One MK64 mini-turbo toggle: steer against the drift for a moment, then back into it.
func _toggle(k, dir: int, secs := 0.1) -> void:
	_run(k, secs, 1.0, 0.0, -dir, true)
	_run(k, secs, 1.0, 0.0, dir, true)

func test_drift_charges_levels_and_boosts_on_release() -> void:
	var k = KartPhysics.new()
	k.speed = 25.0
	_run(k, 3.0, 1.0, 0.0, 1.0, true)   # a steady slide never charges (MK64: you have to toggle the stick)
	runner.check(k.drifting and k.drift_level == 0, "level=%d charge=%f" % [k.drift_level, k.drift_charge])
	_toggle(k, 1)
	runner.check(k.drift_level == 1 and k.drift_charge == 1.0, "yellow after one toggle: level=%d" % k.drift_level)
	_toggle(k, 1)
	runner.check(k.drift_level == 2, "red after two: level=%d" % k.drift_level)
	_toggle(k, 1)
	runner.check(k.drift_level == 2 and k.drift_charge == 2.0, "red is the last stage: level=%d" % k.drift_level)
	k.step(0.016, 1.0, 0.0, 1.0, false)
	runner.check(not k.drifting and k.is_boosting() and k.boost_level == 2 and k.boost_from_drift, "boost after release")
	runner.check(k.boost_time > 1.0, "boost_time=%f" % k.boost_time)

func test_yellow_smoke_gives_no_boost() -> void:
	var k = KartPhysics.new()
	k.speed = 25.0
	_run(k, 0.3, 1.0, 0.0, -1.0, true)
	_toggle(k, -1)
	runner.check(k.drifting and k.drift_level == 1)
	k.step(0.016, 1.0, 0.0, -1.0, false)
	runner.check(not k.drifting and not k.is_boosting(), "MK64: releasing on yellow smoke is no mini-turbo")
	runner.check(k.drift_level == 0 and k.drift_charge == 0.0)

func test_toggle_needs_out_then_in() -> void:
	var k = KartPhysics.new()
	k.speed = 25.0
	_run(k, 0.3, 1.0, 0.0, 1.0, true)
	_run(k, 0.5, 1.0, 0.0, -1.0, true)   # out only
	runner.check(k.drifting and k.drift_level == 0 and k.drift_outward, "steering out alone is half a toggle")
	_run(k, 0.5, 1.0, 0.0, 0.2, true)    # a weak push back does not count
	runner.check(k.drift_level == 0 and k.drift_outward)
	_run(k, 0.1, 1.0, 0.0, 1.0, true)
	runner.check(k.drift_level == 1 and not k.drift_outward, "back in completes it")
	_run(k, 1.0, 1.0, 0.0, 1.0, true)
	_run(k, 0.1, 1.0, 0.0, -1.0, true)
	_run(k, 0.1, 1.0, 0.0, 0.0, true)    # centre, then in: still a toggle
	_run(k, 0.1, 1.0, 0.0, 0.6, true)
	runner.check(k.drift_level == 2, "level=%d" % k.drift_level)
	# a new drift starts from white smoke again
	k.step(0.016, 1.0, 0.0, 1.0, false)
	k.speed = 25.0
	_run(k, 1.5, 1.0, 0.0, 0.0, false)   # let the boost run out
	k.step(0.016, 1.0, 0.0, -1.0, true)
	runner.check(k.drifting and k.drift_level == 0 and k.drift_charge == 0.0 and not k.drift_outward)

func test_short_drift_gives_no_boost() -> void:
	var k = KartPhysics.new()
	k.speed = 25.0
	_run(k, 0.3, 1.0, 0.0, 1.0, true)
	k.step(0.016, 1.0, 0.0, 1.0, false)
	runner.check(not k.is_boosting())

func test_drift_direction_locked() -> void:
	var k = KartPhysics.new()
	k.speed = 25.0
	var yaw := _run(k, 0.5, 1.0, 0.0, -1.0, true)   # start left drift
	var yaw2 := _run(k, 0.5, 1.0, 0.0, 1.0, true)   # countersteer
	runner.check(yaw > 0.0 and yaw2 > 0.0, "still turning left: %f %f" % [yaw, yaw2])

func test_boost_raises_top_speed_and_expires() -> void:
	var k = KartPhysics.new()
	k.apply_boost(1.0)
	_run(k, 0.9, 1.0, 0.0, 0.0, false)
	runner.check(k.speed > k.max_speed, "speed=%f" % k.speed)
	_run(k, 3.0, 1.0, 0.0, 0.0, false)
	runner.check(not k.is_boosting() and is_equal_approx(k.speed, k.max_speed), "speed=%f" % k.speed)

func test_boost_signals() -> void:
	var k = KartPhysics.new()
	var log := []
	k.boost_started.connect(func(l): log.append("start"))
	k.boost_ended.connect(func(): log.append("end"))
	k.apply_boost(0.1)
	_run(k, 0.3, 1.0, 0.0, 0.0, false)
	runner.check(log == ["start", "end"], str(log))

func test_steer_smoothing_ramps_and_recentres() -> void:
	var s := 0.0
	s = KartPhysics.smooth_steer(s, 1.0, 1.0 / 60.0)
	runner.check(s > 0.0 and s < 0.5, "digital input ramps, not instant: %f" % s)
	for i in 30:
		s = KartPhysics.smooth_steer(s, 1.0, 1.0 / 60.0)
	runner.check(is_equal_approx(s, 1.0), "reaches full lock: %f" % s)
	var before := s
	s = KartPhysics.smooth_steer(s, 0.0, 1.0 / 60.0)
	runner.check(s < before and s > 0.0, "recentres gradually")
	# counter-steer reverses faster than a plain ramp
	var a := KartPhysics.smooth_steer(1.0, -1.0, 1.0 / 60.0)
	var b := KartPhysics.smooth_steer(0.0, -1.0, 1.0 / 60.0)
	runner.check(1.0 - a > 0.0 - b, "counter-steer is quicker")
	runner.check(KartPhysics.smooth_steer(0.2, 0.2, 0.1) == 0.2, "no change when on target")

func test_turns_tighter_at_low_speed_than_top_speed() -> void:
	var slow := KartPhysics.new()
	slow.speed = 8.0
	var fast := KartPhysics.new()
	fast.speed = fast.max_speed
	var ys := absf(slow.step(0.1, 1.0, 0.0, 1.0, false))
	var yf := absf(fast.step(0.1, 1.0, 0.0, 1.0, false))
	runner.check(ys > 0.0 and yf > 0.0)
	runner.check(ys > yf, "more yaw per second at low speed (%f vs %f)" % [ys, yf])
	runner.check(yf >= slow.turn_rate * slow.high_speed_turn_scale * 0.1 * 0.99, "still turns at top speed")
