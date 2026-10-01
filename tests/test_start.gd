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
	var none := RaceStart.new()
	_run_until_go(none, -1.0)
	runner.check(none.start_boost() == 0.0)

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
