extends RefCounted
## Mario Kart 64 Kalimari Desert railway: rail loop + level crossings on Dusty Canyon, the trains,
## the strike zone, blocked-crossing warnings, AI waiting, the kart launch and the railway node.

const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const Train := preload("res://scripts/train.gd")
const Railway := preload("res://scripts/railway.gd")
const Kart := preload("res://scripts/kart.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
const SoundSynth := preload("res://scripts/sound_synth.gd")
const Minimap := preload("res://scripts/minimap.gd")
var runner

const DT := 1.0 / 60.0
const DESERT := 3

func test_resample_loop_builds_the_road() -> void:
	var d := TrackData.new()
	var loop := TrackData.resample_loop(TrackData.DEFAULT_CONTROL, d.spacing)
	runner.check(loop.points.size() == d.count and is_equal_approx(loop.length, d.length), "same sample count and length")
	runner.check(loop.points[7].is_equal_approx(d.points[7]) and loop.points[d.count - 1].is_equal_approx(d.points[d.count - 1]), "same samples")

func test_courses_without_a_rail_have_no_trains() -> void:
	for t in TrackLibrary.count():
		if t == DESERT:
			continue
		var d := TrackLibrary.make_data(t)
		runner.check(d.rail.is_empty() and d.crossings.is_empty() and d.rail_length == 0.0, "%s has no railway" % TrackLibrary.info(t).name)
		runner.check(d.crossing_at(10) == null, "no crossing anywhere")
		var tr := Train.new(d)
		runner.check(not tr.active() and tr.heads.is_empty(), "inactive train model")
		runner.check(not tr.must_wait(10) and tr.hit_dir(d.points[10]) == Vector3.ZERO and not tr.bell_near(10), "nothing happens")
		tr.step(DT)
		# walls: only the water spans are open
		var open := 0
		for i in d.count:
			for s in [-1, 1]:
				if not d.has_wall(i, s):
					open += 1
		var expected := 0
		for w in d.water:
			expected += w.end - w.start + 1
		runner.check(open == expected, "%s open wall segments %d vs water %d" % [TrackLibrary.info(t).name, open, expected])

func _index_gap(a: int, b: int, n: int) -> int:
	return mini(posmod(a - b, n), posmod(b - a, n))

func test_dusty_canyon_railway_crosses_the_road_twice() -> void:
	var plain := TrackLibrary.make_data(DESERT)
	var mirror := TrackLibrary.make_data(DESERT, true)
	runner.check(TrackLibrary.info(DESERT).has("rail") and TrackLibrary.info(DESERT).rail.size() >= 8, "the desert course has a rail loop")
	for d in [plain, mirror]:
		var tag := "mirrored" if d.mirrored else "plain"
		runner.check(d.rail.size() > 100 and d.rail_length > 500.0 and d.rail_length < 900.0, "%s rail loop %d samples, %.0f m" % [tag, d.rail.size(), d.rail_length])
		runner.check(d.crossings.size() == 2, "%s: two level crossings (%d)" % [tag, d.crossings.size()])
		for c in d.crossings:
			runner.check(d.is_on_road(c.pos), "crossing centre on the road")
			runner.check(d.distance_to_center(c.pos) < d.spacing, "crossing centre near the centreline (%.1f m)" % d.distance_to_center(c.pos))
			runner.check(absf(c.dir.dot(d.tangents[c.road])) < 0.3, "rail meets the road square on (dot %.2f)" % c.dir.dot(d.tangents[c.road]))
			runner.check(c.road_start == posmod(c.road - TrackData.CROSSING_HALF_GAP, d.count) and c.road_end == posmod(c.road + TrackData.CROSSING_HALF_GAP, d.count))
			runner.check(d.crossing_at(c.road) == c and d.crossing_at(c.road - 2) == c and d.crossing_at(c.road + 2) == c, "the open stretch spans the crossing")
			runner.check(d.crossing_at(c.road - 3) == null and d.crossing_at(c.road + 3) == null, "...and no further")
			for i in range(c.road - 2, c.road + 3):
				runner.check(not d.has_wall(i, -1) and not d.has_wall(i, 1), "no wall on either side at the crossing")
			runner.check(d.has_wall(c.road - 3, 1) and d.has_wall(c.road + 3, -1), "walls resume beside the crossing")
			runner.check(d.water_at(c.road, 1) == null and d.water_at(c.road, -1) == null, "no water at the crossing")
			# clear of the grid (the 12 samples before the line) and the line itself
			runner.check(c.road > 6 and c.road < d.count - 18, "crossing %d clear of the start line and grid" % c.road)
			for p in d.pads:
				runner.check(_index_gap(p.index, c.road, d.count) > 5, "boost pad %d clear of the crossing %d" % [p.index, c.road])
			for f in d.box_rows:
				runner.check(_index_gap(int(f * d.count) % d.count, c.road, d.count) > 5, "item boxes clear of the crossing")
			for h in d.hazard_specs:
				runner.check(_index_gap(int(h[0] * d.count) % d.count, c.road, d.count) > 5, "hazard clear of the crossing")
			# the rail metres match the sample
			runner.check(is_equal_approx(c.s, d.rail_length * c.rail / d.rail.size()))
		# away from the crossings the rail keeps well clear of the road
		var nearest := INF
		for i in d.rail.size():
			var near := false
			for c in d.crossings:
				if _index_gap(i, c.rail, d.rail.size()) <= 10:
					near = true
			if not near:
				nearest = minf(nearest, d.distance_to_center(d.rail[i]))
		runner.check(nearest >= 20.0, "%s rail stays %.1f m from the centreline between crossings" % [tag, nearest])
	# the mirrored course has the same crossings at the mirror-image spots
	for i in 2:
		runner.check(plain.crossings[i].road == mirror.crossings[i].road, "mirrored crossing %d at the same road sample" % i)
		runner.check(is_equal_approx(plain.crossings[i].pos.x, -mirror.crossings[i].pos.x) and is_equal_approx(plain.crossings[i].pos.z, mirror.crossings[i].pos.z), "mirror-image position")

func test_trains_run_the_loop() -> void:
	var d := TrackLibrary.make_data(DESERT)
	var tr := Train.new(d)
	runner.check(tr.active() and tr.heads.size() == Train.TRAIN_COUNT and Train.TRAIN_COUNT == 2, "two trains")
	runner.check(is_equal_approx(tr.heads[1] - tr.heads[0], d.rail_length * 0.5), "half a loop apart")
	runner.check(is_equal_approx(Train.train_length(), 5 * 4.6 + 4 * 0.7), "loco, tender and three coaches")
	var p0 := tr.rail_pose(0.0)
	runner.check(p0.pos.is_equal_approx(d.rail[0]) and p0.dir.is_equal_approx((d.rail[1] - d.rail[0]).normalized()), "rail start")
	var mid := tr.rail_pose(d.rail_length * 0.37)
	var best := INF
	for r in d.rail:
		best = minf(best, Vector2(r.x - mid.pos.x, r.z - mid.pos.z).length())
	runner.check(best <= d.spacing * 0.5 + 0.01 and is_equal_approx(mid.dir.length(), 1.0), "a pose part way round lies on the rail")
	runner.check(tr.rail_pose(d.rail_length + 3.0).pos.is_equal_approx(tr.rail_pose(3.0).pos) and tr.rail_pose(-3.0).pos.is_equal_approx(tr.rail_pose(d.rail_length - 3.0).pos), "wraps both ways")
	tr.step(1.0)
	runner.check(is_equal_approx(tr.heads[0], Train.SPEED) and is_equal_approx(tr.time, 1.0), "moves SPEED metres per second")
	var offset := Train.new(d, 100.0)
	runner.check(is_equal_approx(offset.heads[0], 100.0), "starting offset")
	tr.heads[0] = d.rail_length - 1.0
	tr.step(1.0)
	runner.check(tr.heads[0] < Train.SPEED and tr.heads[0] >= 0.0, "wraps at the loop end: %f" % tr.heads[0])
	# cars trail the front, each one car length and a gap further back
	tr.heads[0] = 200.0
	var loco := tr.car_pose(0, 0)
	var expect := tr.rail_pose(200.0 - Train.CAR_LENGTH * 0.5)
	runner.check(loco.pos.is_equal_approx(expect.pos), "locomotive centred half a car behind the front")
	var last := tr.car_pose(0, Train.CARS - 1)
	var back := tr.rail_pose(200.0 - Train.train_length() + Train.CAR_LENGTH * 0.5)
	runner.check(last.pos.is_equal_approx(back.pos), "last coach at the back of the train")

func test_strike_zone_is_the_cars() -> void:
	var d := TrackLibrary.make_data(DESERT)
	var tr := Train.new(d)
	tr.heads[0] = 150.0
	tr.heads[1] = 150.0 + d.rail_length * 0.5
	var loco := tr.car_pose(0, 0)
	var dir: Vector3 = loco.dir
	var right := Vector3(-dir.z, 0, dir.x)
	runner.check(tr.hit_dir(loco.pos).is_equal_approx(dir), "inside the locomotive: hit, along its direction")
	runner.check(tr.hit_dir(loco.pos + right * 1.4) != Vector3.ZERO and tr.hit_dir(loco.pos - right * 1.4) != Vector3.ZERO, "across the car")
	runner.check(tr.hit_dir(loco.pos + right * 1.7) == Vector3.ZERO, "beside the car: clear")
	runner.check(tr.hit_dir(loco.pos + dir * 3.2) == Vector3.ZERO, "ahead of the locomotive: clear")
	runner.check(tr.hit_dir(loco.pos - dir * 3.0) != Vector3.ZERO, "the gap between cars counts (no slipping between coaches)")
	var tail := tr.car_pose(0, Train.CARS - 1)
	runner.check(tr.hit_dir(tail.pos) != Vector3.ZERO and tr.hit_dir(tail.pos - tail.dir * 3.2) == Vector3.ZERO, "last coach hits, behind it is clear")
	var other := tr.car_pose(1, 2)
	runner.check(tr.hit_dir(other.pos) != Vector3.ZERO, "the second train hits too")
	runner.check(tr.hit_dir(loco.pos + Vector3(0, 4.0, 0)) != Vector3.ZERO, "height is ignored (a kart in the air over the rail is still struck)")
	runner.check(tr.hit_dir(d.points[0]) == Vector3.ZERO, "the start line is clear")

func test_blocked_crossing_warning_and_waiting() -> void:
	var d := TrackLibrary.make_data(DESERT)
	var tr := Train.new(d)
	var c: Dictionary = d.crossings[0]
	var L: float = d.rail_length
	tr.heads[1] = fposmod(c.s + L * 0.5, L)   # the other train is far away
	tr.heads[0] = fposmod(c.s - Train.WARN_DISTANCE - 1.0, L)
	runner.check(not tr.blocked(0), "train still far: open")
	tr.heads[0] = fposmod(c.s - Train.WARN_DISTANCE + 1.0, L)
	runner.check(tr.blocked(0), "train inside the warning distance: blocked")
	tr.heads[0] = fposmod(c.s - 1.0, L)
	runner.check(tr.blocked(0), "front about to reach the crossing")
	tr.heads[0] = fposmod(c.s + 5.0, L)
	runner.check(tr.blocked(0), "train over the crossing")
	tr.heads[0] = fposmod(c.s + Train.train_length() + Train.CLEAR_MARGIN - 1.0, L)
	runner.check(tr.blocked(0), "last car still clearing")
	tr.heads[0] = fposmod(c.s + Train.train_length() + Train.CLEAR_MARGIN + 1.0, L)
	runner.check(not tr.blocked(0), "train gone: open again")
	# AI waiting: only for a blocked crossing a few samples ahead, never once at it
	tr.heads[0] = fposmod(c.s + 5.0, L)
	var n: int = d.count
	runner.check(tr.crossing_ahead(posmod(c.road - 5, n)) == 0, "crossing 0 is ahead of a kart 5 samples back")
	runner.check(tr.must_wait(posmod(c.road - 5, n)), "wait 5 samples before a blocked crossing")
	runner.check(tr.must_wait(posmod(c.road - Train.STOP_SAMPLES, n)), "wait from STOP_SAMPLES out")
	runner.check(not tr.must_wait(posmod(c.road - Train.STOP_SAMPLES - 1, n)), "too far away to stop yet")
	runner.check(not tr.must_wait(posmod(c.road - 1, n)) and not tr.must_wait(c.road), "already on the crossing: keep going")
	runner.check(not tr.must_wait(posmod(c.road + 2, n)), "past the crossing: go")
	tr.heads[0] = fposmod(c.s + Train.train_length() + Train.CLEAR_MARGIN + 1.0, L)
	runner.check(not tr.must_wait(posmod(c.road - 5, n)), "open crossing: no waiting")
	# the bell rings near a blocked crossing, before and after it
	tr.heads[0] = fposmod(c.s - 10.0, L)
	runner.check(tr.bell_near(posmod(c.road - 15, n)) and tr.bell_near(posmod(c.road + 15, n)), "bell within BELL_SAMPLES")
	runner.check(not tr.bell_near(posmod(c.road - Train.BELL_SAMPLES - 1, n)), "quiet further away")
	tr.heads[0] = fposmod(c.s - 200.0, L)
	runner.check(not tr.bell_near(c.road), "quiet while the crossing is open")
	# lamps alternate
	tr.time = 0.0
	runner.check(tr.lamp_phase() == 0)
	tr.time = Train.FLASH_PERIOD * 0.5 + 0.01
	runner.check(tr.lamp_phase() == 1)
	tr.time = Train.FLASH_PERIOD + 0.01
	runner.check(tr.lamp_phase() == 0)

func test_kart_is_thrown_into_the_air() -> void:
	var k = Kart.new()
	k.model.speed = 24.0
	k.model.apply_boost(1.0, 1)
	runner.check(k.launch(Train.LAUNCH_SPEED, Vector3(1, 0, 0) * Train.SHOVE), "struck")
	runner.check(k.model.is_spinning() and not k.model.is_boosting(), "spins out, boost gone")
	runner.check(is_equal_approx(k.hop, Train.LAUNCH_SPEED) and k.push.is_equal_approx(Vector3(Train.SHOVE, 0, 0)) and k.launches == 1, "hop and shove queued")
	runner.check(is_equal_approx(k.model.speed, 12.0), "half the speed left (spin-out)")
	runner.check(not k.launch(Train.LAUNCH_SPEED, Vector3.ZERO) and k.launches == 1, "no second hit while spinning")
	k.free()
	var star = Kart.new()
	star.model.apply_star()
	runner.check(not star.launch(Train.LAUNCH_SPEED, Vector3(0, 0, 1)) and star.hop == 0.0, "a Star goes straight through the train")
	star.free()
	var boo = Kart.new()
	boo.model.apply_ghost()
	runner.check(not boo.launch(Train.LAUNCH_SPEED, Vector3(0, 0, 1)), "a Boo ghost is untouchable")
	boo.free()

func test_ai_waits_at_a_blocked_crossing() -> void:
	var d := TrackLibrary.make_data(DESERT)
	var drv := AiDriver.new(d, 0.0, 1.0)
	var pos: Vector3 = d.points[20]
	var head: float = d.heading_at(20)
	var go: Dictionary = drv.decide(DT, pos, head, 20.0)
	runner.check(go.throttle == 1.0 and go.brake == 0.0, "drives normally")
	drv.wait = true
	var stop: Dictionary = drv.decide(DT, pos, head, 20.0)
	runner.check(stop.throttle == 0.0 and stop.brake == 1.0 and not stop.drift, "brakes for the train")
	var still: Dictionary = drv.decide(DT, pos, head, 0.0)
	runner.check(still.throttle == 0.0 and still.brake == 0.0, "sits still without backing up")
	for i in int(AiDriver.STUCK_TIME / DT) + 30:
		drv.decide(DT, pos, head, 0.0)
	runner.check(drv.stuck_time == 0.0 and drv.reverse_time == 0.0, "waiting is not being stuck: no reverse manoeuvre")
	drv.wait = false
	var again: Dictionary = drv.decide(DT, pos, head, 0.0)
	runner.check(again.throttle == 1.0, "pulls away once the crossing is clear")

func test_crossing_sounds_exist() -> void:
	var lib := SoundSynth.effect_library()
	runner.check(lib.has("bell") and SoundSynth.peak(lib["bell"]) > 0.1, "crossing bell")
	runner.check(lib.has("crash") and SoundSynth.peak(lib["crash"]) > 0.1, "train crash")

func test_minimap_draws_the_rail() -> void:
	var d := TrackLibrary.make_data(DESERT)
	var m := Minimap.new()
	m.setup(d.points, Vector2(220, 220), d.rail)
	runner.check(m.rail_points.size() == d.rail.size() + 1 and m.map_points.size() == d.count + 1, "rail polyline closed like the road")
	for p in m.rail_points:
		runner.check(p.x >= 0.0 and p.x <= 220.0 and p.y >= 0.0 and p.y <= 220.0, "rail inside the map: %s" % p)
	m.setup(d.points, Vector2(220, 220))
	runner.check(m.rail_points.is_empty(), "no rail, nothing drawn")
	m.free()

func test_railway_node_builds_and_moves_the_trains() -> void:
	var d := TrackLibrary.make_data(DESERT)
	var tr := Train.new(d)
	var rw = Railway.new(d, tr)
	rw._ready()   # not in a tree during _initialize
	var rails = rw.get_node_or_null("Rails")
	runner.check(rails != null and rails is MeshInstance3D and rails.mesh != null, "rail mesh built")
	runner.check(rails.mesh.get_faces().size() / 3 == d.rail.size() * 3 * 2, "a sleeper and two rail quads per sample")
	var signals := 0
	for ch in rw.get_children():
		if String(ch.name).begins_with("Signal"):
			signals += 1
	runner.check(signals == 2 and rw.lamps.size() == 2, "a signal per crossing")
	runner.check(rw.cars.size() == 2 and rw.cars[0].size() == Train.CARS and rw.smoke.size() == 2, "two trains of %d cars, a smoking chimney each" % Train.CARS)
	var before: Vector3 = rw.cars[0][0].position
	runner.check(before.is_equal_approx(tr.car_pose(0, 0).pos), "locomotive placed on the rail")
	rw.update_train(1.0)
	var after: Vector3 = rw.cars[0][0].position
	runner.check(after.distance_to(before) > Train.SPEED * 0.8 and after.distance_to(before) < Train.SPEED * 1.2, "moved about SPEED metres in a second (%.1f)" % after.distance_to(before))
	runner.check(rw.cars[0][1].position.distance_to(after) > Train.CAR_LENGTH * 0.9, "tender trails the locomotive")
	# signal lamps: dark while open, one lit at a time while blocked
	var c: Dictionary = d.crossings[0]
	tr.heads[0] = fposmod(c.s - 200.0, d.rail_length)
	tr.heads[1] = fposmod(c.s + d.rail_length * 0.5, d.rail_length)
	rw.update_train(0.0)
	runner.check(not (rw.lamps[0][0].material_override as StandardMaterial3D).emission_enabled and not (rw.lamps[0][1].material_override as StandardMaterial3D).emission_enabled, "lamps dark")
	tr.heads[0] = fposmod(c.s - 10.0, d.rail_length)
	tr.time = 0.0
	rw.update_train(0.0)
	var a0 := (rw.lamps[0][0].material_override as StandardMaterial3D).emission_enabled
	var a1 := (rw.lamps[0][1].material_override as StandardMaterial3D).emission_enabled
	runner.check(a0 and not a1, "first lamp lit")
	tr.time = Train.FLASH_PERIOD * 0.5 + 0.01
	tr.heads[0] = fposmod(c.s - 10.0, d.rail_length)
	rw.update_train(0.0)
	runner.check(not (rw.lamps[0][0].material_override as StandardMaterial3D).emission_enabled and (rw.lamps[0][1].material_override as StandardMaterial3D).emission_enabled, "then the other")
	rw.free()
