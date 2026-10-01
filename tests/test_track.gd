extends RefCounted

const TrackData := preload("res://scripts/track_data.gd")
const LapTracker := preload("res://scripts/lap_tracker.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const BoostPad := preload("res://scripts/boost_pad.gd")
const Hud := preload("res://scripts/hud.gd")
var runner

func test_track_is_closed_and_uniform() -> void:
	var t := TrackData.new()
	runner.check(t.count > 100, "count=%d" % t.count)
	var worst_gap := 0.0
	var best_gap := INF
	for i in t.count:
		var d := t.points[i].distance_to(t.points[(i + 1) % t.count])
		worst_gap = maxf(worst_gap, d)
		best_gap = minf(best_gap, d)
	runner.check(worst_gap < t.spacing * 1.3, "max gap=%f" % worst_gap)
	runner.check(best_gap > t.spacing * 0.5, "min gap=%f" % best_gap)

func test_track_does_not_overlap_itself() -> void:
	var t := TrackData.new()
	var sep := t.min_separation()
	runner.check(sep > t.width * 1.5, "min separation=%f" % sep)

func test_tangent_and_heading() -> void:
	var t := TrackData.new()
	# first control segment runs from (0,40) to (0,-40): travelling -Z, so heading ~ 0
	runner.check(t.tangents[0].z < -0.9, "tangent=%s" % t.tangents[0])
	runner.check(absf(t.heading_at(0)) < 0.3, "heading=%f" % t.heading_at(0))
	var r := t.right_of(0)
	runner.check(r.x > 0.9, "right=%s" % r)

func test_on_road_queries() -> void:
	var t := TrackData.new()
	runner.check(t.is_on_road(t.points[10]))
	runner.check(t.is_on_road(t.points[10] + t.right_of(10) * (t.width * 0.4)))
	runner.check(not t.is_on_road(t.points[10] + t.right_of(10) * (t.width * 0.6)))
	runner.check(not t.is_on_road(Vector3(-300, 0, 300)))

func test_nearest_index_hint_matches_global() -> void:
	var t := TrackData.new()
	var p := t.points[40] + Vector3(1, 0, 1)
	runner.check(t.nearest_index(p) == t.nearest_index(p, 35), "hinted != global")
	# a bad hint far away falls back to the global search
	runner.check(absf(t.nearest_index(p, 120) - 40) <= 1)

func test_boost_pad_contains() -> void:
	var pad := BoostPad.new()
	pad.center = Vector3(10, 0, 10)
	pad.forward = Vector3(0, 0, -1)
	pad.length = 6.0
	pad.width = 4.0
	runner.check(pad.contains(Vector3(10, 0, 10)))
	runner.check(pad.contains(Vector3(11.9, 0, 12.9)))
	runner.check(not pad.contains(Vector3(12.5, 0, 10)))
	runner.check(not pad.contains(Vector3(10, 0, 13.5)))

func test_pads_sit_on_road() -> void:
	var t := TrackData.new()
	runner.check(t.pads.size() == 4)
	for p in t.pads:
		runner.check(t.is_on_road(p.center), "pad off road at %s" % p.center)
		runner.check(t.pad_at(p.center) != null)
	runner.check(t.pad_at(Vector3(-300, 0, 300)) == null)

func test_lap_tracker_counts_laps_in_order() -> void:
	var lt := LapTracker.new(200, 8, 3)
	var dt := 0.1
	# before the line: nothing counted
	lt.update(dt, 195)
	runner.check(lt.lap == 0 and lt.race_time == 0.0)
	var idx := 195
	var guard := 0
	while not lt.is_finished and guard < 5000:
		idx = (idx + 1) % 200
		lt.update(dt, idx)
		guard += 1
	runner.check(lt.is_finished, "never finished")
	runner.check(lt.lap == 3, "lap=%d" % lt.lap)
	runner.check(lt.lap_times.size() == 3, "lap_times=%d" % lt.lap_times.size())
	runner.check(is_equal_approx(lt.lap_times[0], 20.0), "lap0=%f" % lt.lap_times[0])
	runner.check(lt.best_lap() > 0.0)

func test_lap_tracker_skipping_checkpoints_does_not_count() -> void:
	var lt := LapTracker.new(200, 8, 3)
	lt.update(0.1, 0)    # start line -> lap 1
	runner.check(lt.lap == 1)
	lt.update(0.1, 190)  # jump near the line without passing cps 1..7
	lt.update(0.1, 0)
	runner.check(lt.lap == 1 and lt.lap_times.is_empty(), "shortcut counted")

func test_lap_tracker_wrong_way_does_not_count() -> void:
	var lt := LapTracker.new(200, 8, 3)
	lt.update(0.1, 0)
	for i in range(199, 0, -1):
		lt.update(0.1, i)
	runner.check(lt.lap == 1 and lt.lap_times.is_empty(), "reverse lap counted")

func test_lap_signals() -> void:
	var lt := LapTracker.new(80, 4, 1)
	var laps := []
	lt.lap_completed.connect(func(l, t): laps.append(l))
	var fin := [false]
	lt.finished.connect(func(): fin[0] = true)
	for i in 300:
		lt.update(0.1, i % 80)
	runner.check(laps == [1], "laps=%s" % [laps])
	runner.check(fin[0])

func test_offroad_slows_top_speed() -> void:
	var k := KartPhysics.new()
	k.surface_scale = 0.5
	for i in 600:
		k.step(1.0 / 60.0, 1.0, 0.0, 0.0, false)
	runner.check(is_equal_approx(k.speed, k.max_speed * 0.5), "speed=%f" % k.speed)
	k.apply_boost(1.0, 1)
	for i in 30:
		k.step(1.0 / 60.0, 1.0, 0.0, 0.0, false)
	runner.check(k.speed > k.max_speed * 0.5, "boost should override surface slowdown")

func test_bot_completes_race_on_track() -> void:
	## End to end: a simple pursuit bot drives KartPhysics around the real track.
	var t := TrackData.new()
	var lt := LapTracker.new(t.count, 8, 3)
	var k := KartPhysics.new()
	var start := t.count - 4
	var pos := t.points[start]
	var heading := t.heading_at(start)
	var idx := start
	var dt := 1.0 / 60.0
	var time := 0.0
	var off_road_frames := 0
	while not lt.is_finished and time < 400.0:
		idx = t.nearest_index(pos, idx)
		var target := t.points[(idx + 10) % t.count]
		var want := atan2(-(target.x - pos.x), -(target.z - pos.z))
		var err := wrapf(want - heading, -PI, PI)
		var steer := clampf(-err * 2.5, -1.0, 1.0)
		k.surface_scale = 1.0 if t.is_on_road(pos, idx) else 0.5
		if k.surface_scale < 1.0:
			off_road_frames += 1
		heading += k.step(dt, 1.0, 0.0, steer, false)
		pos += Vector3(-sin(heading), 0, -cos(heading)) * k.speed * dt
		lt.update(dt, idx)
		time += dt
	runner.check(lt.is_finished, "bot did not finish; lap=%d cp=%d t=%f" % [lt.lap, lt.next_cp, time])
	runner.check(lt.lap_times.size() == 3)
	runner.check(off_road_frames < 600, "off-road frames=%d" % off_road_frames)
	print("bot: total %s best lap %s offroad frames %d" % [Hud.format_time(lt.race_time), Hud.format_time(lt.best_lap()), off_road_frames])

func test_hud_formatting() -> void:
	runner.check(Hud.format_time(0.0) == "0:00.000", Hud.format_time(0.0))
	runner.check(Hud.format_time(65.432) == "1:05.432", Hud.format_time(65.432))
	runner.check(Hud.lap_text(2, 3) == "LAP 2/3")
	runner.check(Hud.lap_text(9, 3) == "LAP 3/3")
