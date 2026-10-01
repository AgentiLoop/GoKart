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

func test_drift_charges_levels_and_boosts_on_release() -> void:
	var k = KartPhysics.new()
	k.speed = 25.0
	_run(k, 1.0, 1.0, 0.0, 1.0, true)
	runner.check(k.drift_level == 1, "level=%d charge=%f" % [k.drift_level, k.drift_charge])
	_run(k, 2.5, 1.0, 0.0, 1.0, true)
	runner.check(k.drift_level == 3, "level=%d" % k.drift_level)
	k.step(0.016, 1.0, 0.0, 1.0, false)
	runner.check(not k.drifting and k.is_boosting() and k.boost_level == 3, "boost after release")
	runner.check(is_equal_approx(k.boost_time, k.boost_durations[2] - 0.0) or k.boost_time > 1.4)

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
