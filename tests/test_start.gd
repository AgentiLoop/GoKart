extends RefCounted

const RaceStart := preload("res://scripts/race_start.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
var runner

const DT := 1.0 / 60.0

func _run_until_go(rs, hold_from: float) -> void:
	# hold the throttle once remaining <= hold_from (-1 = never)
	while not rs.started:
		rs.update(DT, hold_from >= 0.0 and rs.remaining <= hold_from)

func test_countdown_labels_and_go() -> void:
	var rs := RaceStart.new()
	runner.check(rs.label() == "3", rs.label())
	rs.update(1.0, false)
	runner.check(rs.label() == "2", rs.label())
	rs.update(1.0, false)
	runner.check(rs.label() == "1", rs.label())
	runner.check(rs.is_counting() and not rs.started)
	rs.update(1.0, false)
	runner.check(rs.started and not rs.is_counting())
	runner.check(rs.label() == "GO!", rs.label())
	rs.update(1.5, false)
	runner.check(rs.label() == "", rs.label())

func test_go_signal_fires_once() -> void:
	var rs := RaceStart.new()
	var count := [0]
	rs.go.connect(func(): count[0] += 1)
	for i in 400:
		rs.update(DT, false)
	runner.check(count[0] == 1, "count=%d" % count[0])

func test_boost_curve() -> void:
	runner.check(RaceStart.boost_for_press(-1.0) == 0.0)
	runner.check(RaceStart.boost_for_press(2.0) == 0.0)
	runner.check(RaceStart.boost_for_press(RaceStart.BOOST_WINDOW + 0.01) == 0.0)
	runner.check(is_equal_approx(RaceStart.boost_for_press(0.0), RaceStart.MAX_BOOST))
	runner.check(is_equal_approx(RaceStart.boost_for_press(RaceStart.BOOST_WINDOW), RaceStart.MIN_BOOST))
	runner.check(RaceStart.boost_for_press(0.1) > RaceStart.boost_for_press(0.5))

func test_perfect_press_gives_boost() -> void:
	var rs := RaceStart.new()
	_run_until_go(rs, 0.3)
	var b := rs.start_boost()
	runner.check(b > RaceStart.MIN_BOOST and b <= RaceStart.MAX_BOOST, "b=%f" % b)

func test_early_hold_and_no_press_give_nothing() -> void:
	var early := RaceStart.new()
	_run_until_go(early, 2.0)
	runner.check(early.start_boost() == 0.0, "early=%f" % early.start_boost())
	runner.check(early.false_start(), "holding from 2.0 s out is a false start")
	var none := RaceStart.new()
	_run_until_go(none, -1.0)
	runner.check(none.start_boost() == 0.0)
	runner.check(not none.false_start(), "never pressing is not a false start")

func test_false_start_rules() -> void:
	# pure helper: only a throttle still held at GO after an early press stalls
	runner.check(RaceStart.stalls_for_press(2.0, true))
	runner.check(RaceStart.stalls_for_press(RaceStart.BOOST_WINDOW + 0.01, true))
	runner.check(not RaceStart.stalls_for_press(RaceStart.BOOST_WINDOW, true), "window edge boosts")
	runner.check(not RaceStart.stalls_for_press(0.3, true), "window press boosts")
	runner.check(not RaceStart.stalls_for_press(2.0, false), "released before GO: no stall")
	runner.check(not RaceStart.stalls_for_press(-1.0, false))
	runner.check(RaceStart.STALL_TIME > 0.0)
	# a perfect press is never a false start
	var good := RaceStart.new()
	_run_until_go(good, 0.3)
	runner.check(not good.false_start() and good.start_boost() > 0.0)
	# held the whole countdown (3 s) -> false start, no boost
	var greedy := RaceStart.new()
	_run_until_go(greedy, 99.0)
	runner.check(greedy.false_start() and greedy.start_boost() == 0.0)
	# early press, let go before GO -> neither
	var released := RaceStart.new()
	released.update(1.0, true)
	released.update(1.0, true)
	released.update(0.5, false)
	released.update(0.6, false)
	runner.check(released.started and not released.false_start() and released.start_boost() == 0.0)

func test_stall_holds_the_kart_still_then_releases_it() -> void:
	var m := KartPhysics.new()
	var started := [0]
	var ended := [0]
	m.stall_started.connect(func(): started[0] += 1)
	m.stall_ended.connect(func(): ended[0] += 1)
	m.stall(RaceStart.STALL_TIME)
	runner.check(m.is_stalled() and started[0] == 1)
	m.stall(RaceStart.STALL_TIME)   # again: no second signal, time not reduced
	runner.check(started[0] == 1 and is_equal_approx(m.stall_time, RaceStart.STALL_TIME))
	var heading := 0.0
	for i in int(RaceStart.STALL_TIME / DT) - 1:
		heading += m.step(DT, 1.0, 0.0, 1.0, false)
	runner.check(m.is_stalled() and m.speed == 0.0 and heading == 0.0, "still at speed %f yaw %f" % [m.speed, heading])
	runner.check(ended[0] == 0)
	for i in 3:
		m.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(not m.is_stalled() and ended[0] == 1, "stall over")
	for i in 60:
		m.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(m.speed > 5.0, "drives off afterwards: %f" % m.speed)
	# a stalled kart is well behind a plain one after the same time
	var plain := KartPhysics.new()
	var stalled := KartPhysics.new()
	stalled.stall(RaceStart.STALL_TIME)
	for i in 120:
		plain.step(DT, 1.0, 0.0, 0.0, false)
		stalled.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(stalled.speed < plain.speed, "%f vs %f" % [stalled.speed, plain.speed])

func test_release_and_repress_counts_latest_press() -> void:
	var rs := RaceStart.new()
	rs.update(1.0, true)    # pressed way too early
	rs.update(1.0, false)   # released
	rs.update(0.9, false)
	rs.update(0.05, true)   # re-pressed at remaining 0.1
	rs.update(0.1, true)
	runner.check(rs.started)
	runner.check(rs.start_boost() > 1.0, "b=%f" % rs.start_boost())

func test_start_boost_speeds_kart_up() -> void:
	var boosted := KartPhysics.new()
	var plain := KartPhysics.new()
	boosted.apply_boost(RaceStart.MAX_BOOST, 1)
	for i in 60:
		boosted.step(DT, 1.0, 0.0, 0.0, false)
		plain.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(boosted.speed > plain.speed, "%f vs %f" % [boosted.speed, plain.speed])
