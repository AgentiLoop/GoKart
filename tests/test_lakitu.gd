extends RefCounted
## Mario Kart 64 Lakitu: start signal, REVERSE sign, lap signs, checkered flag, water hazards and rescues.

const Lakitu := preload("res://scripts/lakitu.gd")
const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const Track := preload("res://scripts/track.gd")
const Kart := preload("res://scripts/kart.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const SoundSynth := preload("res://scripts/sound_synth.gd")
var runner

const DT := 1.0 / 60.0

func test_start_signal_lamps_red_red_blue() -> void:
	runner.check(Lakitu.lamps(3.0, false) == 0, "nothing lit at 3")
	runner.check(Lakitu.lamps(2.5, false) == 0)
	runner.check(Lakitu.lamps(2.0, false) == 1, "first red at 2")
	runner.check(Lakitu.lamps(1.2, false) == 1)
	runner.check(Lakitu.lamps(1.0, false) == 2, "second red at 1")
	runner.check(Lakitu.lamps(0.1, false) == 2)
	runner.check(Lakitu.lamps(0.0, true) == 3, "blue at GO")
	runner.check(Lakitu.LAMP_COLORS.size() == 3)
	runner.check(Lakitu.LAMP_COLORS[0].r > 0.8 and Lakitu.LAMP_COLORS[1].r > 0.8, "two red lamps")
	runner.check(Lakitu.LAMP_COLORS[2].b > 0.8 and Lakitu.LAMP_COLORS[2].r < 0.4, "the GO lamp is blue")

func test_wrong_way_and_lap_signs() -> void:
	var tangent := Vector3(0, 0, -1)
	runner.check(Lakitu.going_wrong(Vector3(0, 0, 1), tangent, 10.0), "driving against the track")
	runner.check(not Lakitu.going_wrong(Vector3(0, 0, -1), tangent, 10.0), "driving with the track")
	runner.check(not Lakitu.going_wrong(Vector3(1, 0, 0), tangent, 10.0), "sideways is not reverse")
	runner.check(not Lakitu.going_wrong(Vector3(0, 0, 1), tangent, 0.5), "standing still (or creeping) is not reverse")
	runner.check(not Lakitu.going_wrong(Vector3(0, 0, 1), tangent, -10.0), "backing up with the nose the wrong way moves the right way")
	runner.check(Lakitu.lap_sign(1, 3) == "" and Lakitu.lap_sign(0, 3) == "", "no sign on lap 1")
	runner.check(Lakitu.lap_sign(2, 3) == "LAP 2")
	runner.check(Lakitu.lap_sign(3, 3) == "FINAL LAP")
	runner.check(Lakitu.lap_sign(4, 7) == "LAP 4" and Lakitu.lap_sign(7, 7) == "FINAL LAP")
	runner.check(Lakitu.lap_sign(4, 3) == "", "past the end: nothing")
	runner.check(Lakitu.lap_sign(2, 2) == "FINAL LAP", "two-lap race: lap 2 is the final lap")

func test_rescue_pose_lifts_carries_and_drops() -> void:
	var from := Vector3(10, 0.1, 5)
	var to := Vector3(0, 0.1, 0)
	runner.check(Lakitu.rescue_pose(0.0, from, to).is_equal_approx(from), "starts where the kart fell")
	var mid_lift := Lakitu.rescue_pose(Lakitu.LIFT_TIME * 0.5, from, to)
	runner.check(is_equal_approx(mid_lift.x, from.x) and is_equal_approx(mid_lift.z, from.z) and mid_lift.y > from.y + 1.0, "lifted straight up: %s" % mid_lift)
	var top := Lakitu.rescue_pose(Lakitu.LIFT_TIME, from, to)
	runner.check(is_equal_approx(top.y, from.y + Lakitu.LIFT_HEIGHT), "full lift height")
	var carry := Lakitu.rescue_pose(Lakitu.LIFT_TIME + Lakitu.CARRY_TIME * 0.5, from, to)
	runner.check(is_equal_approx(carry.y, top.y) and carry.x < from.x and carry.x > to.x and carry.z < from.z and carry.z > to.z, "carried across at height: %s" % carry)
	var over := Lakitu.rescue_pose(Lakitu.LIFT_TIME + Lakitu.CARRY_TIME, from, to)
	runner.check(is_equal_approx(over.x, to.x) and is_equal_approx(over.z, to.z) and is_equal_approx(over.y, top.y), "above the drop point")
	var dropping := Lakitu.rescue_pose(Lakitu.LIFT_TIME + Lakitu.CARRY_TIME + Lakitu.DROP_TIME * 0.5, from, to)
	runner.check(dropping.y < top.y and dropping.y > to.y, "on the way down")
	runner.check(Lakitu.rescue_pose(Lakitu.RESCUE_TIME, from, to).is_equal_approx(to), "set down on the road")
	runner.check(Lakitu.rescue_pose(Lakitu.RESCUE_TIME + 5.0, from, to).is_equal_approx(to), "stays there")
	runner.check(is_equal_approx(Lakitu.RESCUE_TIME, Lakitu.LIFT_TIME + Lakitu.CARRY_TIME + Lakitu.DROP_TIME))
	runner.check(Lakitu.RESCUE_TIME >= 2.0 and Lakitu.RESCUE_TIME <= 4.0, "a few seconds lost, like MK64")

func test_water_spans_open_the_wall_on_one_side() -> void:
	var d := TrackData.new()
	runner.check(d.water.size() == TrackData.DEFAULT_WATER.size() and d.water.size() >= 1)
	var w: Dictionary = d.water[0]
	runner.check(w.start == int(0.13 * d.count) and w.end == int(0.21 * d.count) and w.side == -1, "span samples: %s" % str(w))
	runner.check(w.start > 0 and w.end < d.count - 1, "the start line keeps its walls")
	var mid: int = (w.start + w.end) / 2
	runner.check(not d.has_wall(mid, -1), "no wall on the water side")
	runner.check(d.has_wall(mid, 1), "wall on the other side")
	runner.check(d.has_wall(w.start - 1, -1) and d.has_wall(w.end + 1, -1), "walls resume outside the span")
	runner.check(d.has_wall(0, -1) and d.has_wall(0, 1), "walls at the start line")
	runner.check(d.water_at(mid, -1) == w and d.water_at(mid, 1) == null)
	# count the wall-less segments: exactly the spans' lengths
	var open := 0
	for i in d.count:
		for s in [-1, 1]:
			if not d.has_wall(i, s):
				open += 1
	var expected := 0
	for ww in d.water:
		expected += ww.end - ww.start + 1
	runner.check(open == expected, "open segments %d vs %d" % [open, expected])

func test_in_water_only_past_the_open_edge() -> void:
	var d := TrackData.new()
	var w: Dictionary = d.water[0]
	var mid: int = (w.start + w.end) / 2
	var c: Vector3 = d.points[mid]
	var r: Vector3 = d.right_of(mid) * w.side   # towards the water
	var edge: float = d.width * 0.5 + TrackData.WATER_EDGE
	runner.check(not d.in_water(c, mid), "centre of the road is dry")
	runner.check(not d.in_water(c + r * (d.width * 0.5 - 0.5), mid), "road edge is dry")
	runner.check(not d.in_water(c + r * (edge - 0.1), mid), "the bank is dry")
	runner.check(d.in_water(c + r * (edge + 0.5), mid), "just past the edge is water")
	runner.check(d.in_water(c + r * (edge + TrackData.WATER_WIDTH - 1.0), mid), "far out is still water")
	runner.check(not d.in_water(c + r * (edge + TrackData.WATER_WIDTH + 2.0), mid), "beyond the water is land")
	runner.check(not d.in_water(c - r * (edge + 0.5), mid), "the walled side has no water")
	var dry: int = w.end + 5
	runner.check(d.has_wall(dry, w.side) and not d.in_water(d.points[dry] + d.right_of(dry) * w.side * (edge + 0.5), dry), "outside the span: no water")
	runner.check(d.rescue_point(mid).is_equal_approx(c + Vector3(0, 0.1, 0)), "rescue drop on the centreline")
	runner.check(d.rescue_point(mid + d.count) == d.rescue_point(mid), "wraps")
	# the nearest-index query still finds the span from out in the water
	runner.check(absi(d.nearest_index(c + r * (edge + 3.0), mid) - mid) <= 1)

func test_every_course_has_water_and_mirroring_swaps_the_side() -> void:
	for t in TrackLibrary.count():
		var d := TrackLibrary.make_data(t)
		var m := TrackLibrary.make_data(t, true)
		runner.check(d.water.size() >= 1, "%s has water" % TrackLibrary.info(t).name)
		runner.check(m.water.size() == d.water.size())
		for i in d.water.size():
			runner.check(m.water[i].side == -d.water[i].side and m.water[i].start == d.water[i].start and m.water[i].end == d.water[i].end, "mirrored span %d of %s" % [i, TrackLibrary.info(t).name])
			var w: Dictionary = d.water[i]
			runner.check(w.start > 2 and w.end < d.count - 3 and w.end > w.start, "span inside the lap and away from the line")
			# water sits on the outside of the bend it lines (where a wide kart would go off)
			var turn := wrapf(d.heading_at(w.end) - d.heading_at(w.start), -PI, PI)
			runner.check((turn > 0.0 and w.side == 1) or (turn < 0.0 and w.side == -1), "%s span %d on the outside of the bend (turn %.2f, side %d)" % [TrackLibrary.info(t).name, i, turn, w.side])
			# no item box row or boost pad sits on the open stretch's road edge? boxes/pads are on the road, fine;
			# but a hazard banana must not be placed in the water
			for hp in d.hazard_positions:
				runner.check(not d.in_water(hp, d.nearest_index(hp)), "hazard on dry land")
	var specs := TrackData.mirror_water([[0.1, 0.2, 1], [0.5, 0.6, -1]])
	runner.check(specs == [[0.1, 0.2, -1], [0.5, 0.6, 1]], "mirror_water flips the side only")
	var no_water := TrackData.new(TrackData.DEFAULT_CONTROL, 16.0, {"water": []})
	runner.check(no_water.water.is_empty() and no_water.has_wall(10, -1) and not no_water.in_water(no_water.points[10] + no_water.right_of(10) * -12.0, 10), "a course without water is fully walled")

func test_track_node_leaves_gaps_and_draws_water() -> void:
	var d := TrackData.new()
	var track = Track.new(d)
	track._ready()   # the runner's root is not in the tree yet during _initialize, so build by hand
	var walls := track.get_node("Walls")
	var open := 0
	for w in d.water:
		open += w.end - w.start + 1
	runner.check(walls.get_child_count() == 2 * d.count - open, "wall pieces %d (expected %d)" % [walls.get_child_count(), 2 * d.count - open])
	var water := track.get_node_or_null("Water")
	runner.check(water != null and water is MeshInstance3D and water.mesh != null, "water mesh built")
	if water != null:
		var faces: int = water.mesh.get_faces().size() / 3
		runner.check(faces == open * 4, "two quads per open segment: %d faces" % faces)
	var dry := Track.new(TrackData.new(TrackData.DEFAULT_CONTROL, 16.0, {"water": []}))
	dry._ready()
	runner.check(dry.get_node("Walls").get_child_count() == 2 * d.count and dry.get_node_or_null("Water") == null, "no water: full walls, no mesh")
	track.free()
	dry.free()

func test_kart_node_rescue() -> void:
	var k = Kart.new()
	runner.check(not k.is_rescued() and k.rescues == 0)
	k.position = Vector3(20, 0.1, -30)
	k.heading = 1.0
	k.model.speed = 25.0
	k.model.apply_boost(1.0, 1)
	k.push = Vector3(3, 0, 0)
	k.start_rescue(Vector3(0, 0.1, -30), 0.5)
	runner.check(k.is_rescued() and k.rescues == 1, "rescue started")
	runner.check(k.model.speed == 0.0 and not k.model.is_boosting() and k.push == Vector3.ZERO, "stopped dead")
	runner.check(k._update_rescue(0.0), "hanging from the line")
	k.start_rescue(Vector3(5, 0.1, 5), 2.0)
	runner.check(k.rescues == 1 and k.rescue_to == Vector3(0, 0.1, -30), "a second hook while hanging is ignored")
	var t := 0.0
	var peak := 0.0
	while k.is_rescued():
		runner.check(k._update_rescue(DT), "no driving while rescued")
		t += DT
		peak = maxf(peak, k.position.y)
		runner.check(t < Lakitu.RESCUE_TIME + 1.0, "rescue ends")
	runner.check(peak > 4.0, "lifted high: %f" % peak)
	runner.check(k.position.is_equal_approx(Vector3(0, 0.1, -30)) and is_equal_approx(k.heading, 0.5), "set down at the drop point facing along the track: %s" % k.position)
	runner.check(is_equal_approx(k.rotation.y, 0.5))
	runner.check(not k._update_rescue(DT), "drives again")
	runner.check(t >= Lakitu.RESCUE_TIME - DT, "took the full rescue time: %f" % t)
	k.free()

func test_physics_stop() -> void:
	var m := KartPhysics.new()
	var ended := [0]
	m.boost_ended.connect(func(): ended[0] += 1)
	m.drift_level_changed.connect(func(l): if l == 0: ended[0] += 10)
	for i in 120:
		m.step(DT, 1.0, 0.0, 1.0, true)   # drive, then drift
	runner.check(m.drifting and m.speed > 5.0)
	m.apply_boost(1.0, 1)
	m.drift_charge = 2.0
	m._update_level()
	runner.check(m.drift_level > 0)
	m.stop()
	runner.check(m.speed == 0.0 and not m.drifting and m.drift_level == 0 and not m.is_boosting())
	runner.check(ended[0] == 11, "boost_ended and drift_level_changed(0) emitted once each: %d" % ended[0])
	m.stop()
	runner.check(ended[0] == 11, "no repeat signals")

func _kart_on(d: TrackData, idx: int):
	var k = Kart.new()
	k.position = d.points[idx] + Vector3(0, 0.1, 0)
	k.heading = d.heading_at(idx)
	k.track_index = idx
	return k

func test_lakitu_node_modes() -> void:
	var d := TrackData.new()
	var k = _kart_on(d, 5)
	var l = Lakitu.new()
	l.setup(k, d)
	runner.check(l.mode == Lakitu.Mode.HIDDEN and not l.visible)
	# countdown: the start signal, lamps lighting up
	l.update_lakitu(DT, 3.0, false, 0.0)
	runner.check(l.mode == Lakitu.Mode.START and l.visible and l._signal.visible and l.appearances == 1, "signal out during the countdown")
	runner.check(not (l._lamps[0].material_override as StandardMaterial3D).emission_enabled, "no lamp lit at 3")
	l.update_lakitu(DT, 1.5, false, 0.0)
	runner.check((l._lamps[0].material_override as StandardMaterial3D).emission_enabled and not (l._lamps[1].material_override as StandardMaterial3D).emission_enabled, "one red lamp at 1.5")
	l.update_lakitu(DT, 0.0, true, 0.2)
	runner.check((l._lamps[2].material_override as StandardMaterial3D).emission_enabled, "blue lamp at GO")
	runner.check(l._sign.visible == false and l._flag.visible == false and l._line.visible == false)
	# hovers ahead and to the right of the kart, facing back at it
	var fwd := Vector3(-sin(k.heading), 0, -cos(k.heading))
	var rel: Vector3 = l.position - k.position
	runner.check(rel.dot(fwd) > 2.0 and rel.y > 2.0, "ahead and above the kart: %s" % rel)
	runner.check(is_equal_approx(wrapf(l.rotation.y - k.heading - PI, -PI, PI), 0.0), "faces the camera")
	# after the signal is put away Lakitu leaves
	l.update_lakitu(DT, 0.0, true, Lakitu.SIGNAL_HOLD + 0.1)
	runner.check(l.mode == Lakitu.Mode.HIDDEN and not l.visible, "gone after GO")
	# REVERSE: drive against the track for a second
	k.heading = d.heading_at(5) + PI
	k.model.speed = 15.0
	var frames := 0
	while l.mode != Lakitu.Mode.REVERSE and frames < 200:
		l.update_lakitu(DT, 0.0, true, 5.0)
		frames += 1
	runner.check(l.mode == Lakitu.Mode.REVERSE, "REVERSE sign after driving the wrong way")
	runner.check(frames >= int(Lakitu.REVERSE_DELAY / DT) - 1 and frames <= int(Lakitu.REVERSE_DELAY / DT) + 2, "after about %.1f s (%d frames)" % [Lakitu.REVERSE_DELAY, frames])
	runner.check(l._sign_label.text == "REVERSE" and l.visible and l.appearances == 2)
	# the sign flashes
	var seen_on := false
	var seen_off := false
	for i in 40:
		l.update_lakitu(DT, 0.0, true, 5.0)
		if l._sign.visible:
			seen_on = true
		else:
			seen_off = true
	runner.check(seen_on and seen_off, "flashing red sign")
	# turn around: the sign goes away at once
	k.heading = d.heading_at(5)
	l.update_lakitu(DT, 0.0, true, 5.0)
	runner.check(l.mode == Lakitu.Mode.HIDDEN and l.wrong_time == 0.0, "sign away once the kart faces the right way")
	# reversing (negative speed, nose still forward) is not the wrong way; sideways drift is not either
	k.model.speed = -5.0
	for i in 90:
		l.update_lakitu(DT, 0.0, true, 5.0)
	runner.check(l.mode == Lakitu.Mode.HIDDEN, "backing up is not REVERSE")
	k.model.speed = 15.0
	# lap sign for a moment, FINAL LAP on the last one; flag at the finish beats the lap sign
	l.on_lap(2, 3)
	l.update_lakitu(DT, 0.0, true, 5.0)
	runner.check(l.mode == Lakitu.Mode.LAP_SIGN and l._sign_label.text == "LAP 2" and l._sign.visible, "LAP 2 sign")
	var shown := 0
	while l.mode == Lakitu.Mode.LAP_SIGN and shown < 400:
		l.update_lakitu(DT, 0.0, true, 5.0)
		shown += 1
	runner.check(shown >= int(Lakitu.SIGN_TIME / DT) - 2 and shown <= int(Lakitu.SIGN_TIME / DT) + 2, "sign held for %.1f s (%d frames)" % [Lakitu.SIGN_TIME, shown])
	l.on_lap(3, 3)
	l.update_lakitu(DT, 0.0, true, 5.0)
	runner.check(l._sign_label.text == "FINAL LAP")
	l.on_lap(1, 3)
	l.update_lakitu(DT, 0.0, true, 5.0)
	runner.check(l.mode == Lakitu.Mode.HIDDEN, "no sign for lap 1")
	l.on_lap(2, 3)
	l.on_finish()
	l.update_lakitu(DT, 0.0, true, 5.0)
	runner.check(l.mode == Lakitu.Mode.FLAG and l._flag.visible and not l._sign.visible, "checkered flag at the finish")
	var waved := 0
	while l.mode == Lakitu.Mode.FLAG and waved < 400:
		l.update_lakitu(DT, 0.0, true, 5.0)
		waved += 1
	runner.check(waved >= int(Lakitu.FLAG_TIME / DT) - 2 and waved <= int(Lakitu.FLAG_TIME / DT) + 2, "flag waved for %.1f s" % Lakitu.FLAG_TIME)
	# a rescue beats everything: Lakitu hangs above the kart with the line down
	l.on_finish()
	k.start_rescue(d.rescue_point(5), d.heading_at(5))
	l.update_lakitu(DT, 0.0, true, 5.0)
	runner.check(l.mode == Lakitu.Mode.RESCUE and l._line.visible and not l._flag.visible, "fishing line out during a rescue")
	for i in 30:
		l.update_lakitu(DT, 0.0, true, 5.0)
	runner.check(l.position.y > k.position.y + 3.0 and Vector2(l.position.x - k.position.x, l.position.z - k.position.z).length() < 2.0, "right above the kart: %s vs %s" % [l.position, k.position])
	while k.is_rescued():
		k._update_rescue(DT)
	l.update_lakitu(DT, 0.0, true, 5.0)
	runner.check(l.mode == Lakitu.Mode.FLAG, "back to the flag after the rescue")
	l.free()
	k.free()

func test_splash_sound_exists() -> void:
	var lib := SoundSynth.effect_library()
	runner.check(lib.has("splash") and SoundSynth.peak(lib["splash"]) > 0.1)
