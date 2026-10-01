extends RefCounted

const AiDriver := preload("res://scripts/ai_driver.gd")
const RaceRanking := preload("res://scripts/race_ranking.gd")
const ItemManager := preload("res://scripts/item_manager.gd")
const Items := preload("res://scripts/items.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const TrackData := preload("res://scripts/track_data.gd")
const LapTracker := preload("res://scripts/lap_tracker.gd")
const Hud := preload("res://scripts/hud.gd")
var runner

const DT := 1.0 / 60.0

func test_driver_steers_toward_the_road() -> void:
	var t := TrackData.new()
	var d := AiDriver.new(t, 0.0)
	var i := 10   # on the first straight
	var heading := t.heading_at(i)
	var right := t.right_of(i)
	# displaced to the right of the centerline, facing along it: must steer left (negative)
	var out := d.decide(DT, t.points[i] + right * 5.0, heading, 20.0)
	runner.check(out.steer < -0.1, "steer=%f" % out.steer)
	runner.check(out.throttle == 1.0 and out.brake == 0.0)
	# displaced left: steer right
	var d2 := AiDriver.new(t, 0.0)
	var out2 := d2.decide(DT, t.points[i] - right * 5.0, heading, 20.0)
	runner.check(out2.steer > 0.1, "steer=%f" % out2.steer)
	# on the centerline, aligned: roughly straight
	var d3 := AiDriver.new(t, 0.0)
	var out3 := d3.decide(DT, t.points[i], heading, 20.0)
	runner.check(absf(out3.steer) < 0.5, "steer=%f" % out3.steer)

func test_driver_lane_offset_shifts_aim() -> void:
	var t := TrackData.new()
	var i := 20
	var a := AiDriver.new(t, -4.0).decide(DT, t.points[i], t.heading_at(i), 20.0)
	var b := AiDriver.new(t, 4.0).decide(DT, t.points[i], t.heading_at(i), 20.0)
	runner.check(a.steer != b.steer)

func test_driver_reverses_when_stuck_then_recovers() -> void:
	var t := TrackData.new()
	var d := AiDriver.new(t, 0.0)
	var i := 40
	var saw_reverse := false
	var out := {}
	for f in int(2.5 / DT):
		out = d.decide(DT, t.points[i], t.heading_at(i), 0.0)
		if out.brake > 0.0 and out.throttle == 0.0:
			saw_reverse = true
	runner.check(saw_reverse, "never reversed when stuck")
	# once moving again it drives forward
	out = d.decide(DT, t.points[i], t.heading_at(i), 20.0)
	runner.check(out.throttle == 1.0)

func test_driver_not_stuck_while_spinning() -> void:
	var t := TrackData.new()
	var d := AiDriver.new(t, 0.0)
	var i := 40
	for f in 300:
		var out := d.decide(DT, t.points[i], t.heading_at(i), 0.0, false)
		runner.check(out.throttle == 1.0, "reversed while uncontrollable")
		if out.throttle != 1.0:
			return

func test_driver_item_policy() -> void:
	var d := AiDriver.new(null, 0.0, 1.0)
	runner.check(not d.wants_use(DT, Items.Type.NONE, 10.0, 10.0))
	runner.check(not d.wants_use(0.5, Items.Type.MUSHROOM, INF, INF), "before delay")
	runner.check(d.wants_use(0.6, Items.Type.MUSHROOM, INF, INF), "mushroom after delay")
	# shell only with a rival ahead (or after a long hold)
	runner.check(not d.wants_use(1.5, Items.Type.SHELL, INF, INF))
	runner.check(d.wants_use(DT, Items.Type.SHELL, 30.0, INF))
	runner.check(not d.wants_use(1.5, Items.Type.SHELL, 80.0, INF), "rival too far")
	# banana only with a rival close behind
	runner.check(not d.wants_use(1.5, Items.Type.BANANA, 10.0, INF))
	runner.check(d.wants_use(DT, Items.Type.BANANA, INF, 12.0))
	# stuck holding for ages: use it anyway
	var d2 := AiDriver.new(null, 0.0, 1.0)
	var used := false
	for f in int(11.0 / DT):
		if d2.wants_use(DT, Items.Type.SHELL, INF, INF):
			used = true
	runner.check(used, "should dump a shell eventually")

func test_rival_gaps() -> void:
	# racer 0 at origin facing -z (heading 0)
	var pos := [Vector3(0, 0, 0), Vector3(1, 0, -20), Vector3(-2, 0, 10), Vector3(15, 0, -5), Vector3(0, 0, -40)]
	var heads := [0.0, 0.0, 0.0, 0.0, 0.0]
	var g := ItemManager.rival_gaps(0, pos, heads)
	runner.check(is_equal_approx(g.x, 20.0), "ahead=%f" % g.x)   # racer 3 is too far to the side
	runner.check(is_equal_approx(g.y, 10.0), "behind=%f" % g.y)
	var alone := ItemManager.rival_gaps(0, [Vector3.ZERO], [0.0])
	runner.check(alone.x == INF and alone.y == INF)

func test_ranking_order() -> void:
	var prog := [100.0, 150.0, 120.0]
	var fin := [-1.0, -1.0, -1.0]
	runner.check(RaceRanking.order(prog, fin) == [1, 2, 0])
	runner.check(RaceRanking.rank_of(0, prog, fin) == 3)
	runner.check(RaceRanking.rank_of(1, prog, fin) == 1)
	# finished racers beat unfinished ones, earlier finish wins
	fin = [-1.0, -1.0, 70.0]
	runner.check(RaceRanking.order(prog, fin) == [2, 1, 0])
	fin = [65.0, -1.0, 70.0]
	runner.check(RaceRanking.order(prog, fin) == [0, 2, 1])

func test_progress_is_monotonic_across_the_line() -> void:
	var count := 200
	var last := -1.0
	var lap := 0
	var tracker := LapTracker.new(count, 8, 3)
	# drive the index forward through the start line and over a full lap
	for step in count + 40:
		var idx := (count - 10 + step) % count
		tracker.update(DT, idx)
		var p := RaceRanking.progress(tracker.lap, idx, count)
		runner.check(p > last, "progress went backwards at step %d: %f -> %f" % [step, last, p])
		last = p

func test_ordinals_and_place_text() -> void:
	runner.check(RaceRanking.ordinal(1) == "1st")
	runner.check(RaceRanking.ordinal(2) == "2nd")
	runner.check(RaceRanking.ordinal(3) == "3rd")
	runner.check(RaceRanking.ordinal(4) == "4th")
	runner.check(RaceRanking.ordinal(11) == "11th")
	runner.check(RaceRanking.ordinal(22) == "22nd")
	runner.check(Hud.place_text(2, 4) == "2nd / 4")
	runner.check(Hud.place_text(1, 1) == "")

func test_ai_field_finishes_race_on_track() -> void:
	## Three AI drivers in their own lanes and skill levels all complete 3 laps.
	var t := TrackData.new()
	var lanes := [-3.0, 3.0, 0.0]
	var skills := [0.97, 0.94, 0.91]
	var starts := [t.count - 4, t.count - 4, t.count - 7]
	var phys: Array = []
	var drv: Array = []
	var lt: Array = []
	var pos: Array = []
	var head: Array = []
	for n in 3:
		var k := KartPhysics.new()
		k.max_speed *= skills[n]
		phys.append(k)
		drv.append(AiDriver.new(t, lanes[n], 1.0))
		lt.append(LapTracker.new(t.count, 8, 3))
		pos.append(t.points[starts[n]] + t.right_of(starts[n]) * lanes[n])
		head.append(t.heading_at(starts[n]))
	var idx := [-1, -1, -1]
	var off_road := 0
	var time := 0.0
	while time < 400.0:
		var all_done := true
		for n in 3:
			if lt[n].is_finished:
				continue
			all_done = false
			idx[n] = t.nearest_index(pos[n], idx[n] if idx[n] >= 0 else -1)
			var out: Dictionary = drv[n].decide(DT, pos[n], head[n], phys[n].speed)
			phys[n].surface_scale = 1.0 if t.is_on_road(pos[n], idx[n]) else 0.5
			if phys[n].surface_scale < 1.0:
				off_road += 1
			head[n] += phys[n].step(DT, out.throttle, out.brake, out.steer, out.drift)
			pos[n] += Vector3(-sin(head[n]), 0, -cos(head[n])) * phys[n].speed * DT
			lt[n].update(DT, idx[n])
		if all_done:
			break
		time += DT
	for n in 3:
		runner.check(lt[n].is_finished, "AI %d did not finish (lap %d, cp %d)" % [n, lt[n].lap, lt[n].next_cp])
	runner.check(lt[0].race_time < lt[2].race_time, "faster AI should finish first")
	runner.check(off_road < 900, "AI off-road frames=%d" % off_road)
	print("ai: finish times %s %s %s, offroad frames %d" % [Hud.format_time(lt[0].race_time), Hud.format_time(lt[1].race_time), Hud.format_time(lt[2].race_time), off_road])
