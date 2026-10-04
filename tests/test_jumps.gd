extends RefCounted
## Mario Kart 64 Wario Stadium / Royal Raceway style jump ramps: TrackData ramps, the ramp height a kart
## rides, the KartPhysics flight and the Kart body pitch.

const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const Kart := preload("res://scripts/kart.gd")
var runner

const DT := 1.0 / 60.0

func test_ramp_samples_and_height() -> void:
	var t := TrackData.new(TrackData.DEFAULT_CONTROL, 16.0, {"jumps": [0.25]})
	runner.check(t.jumps.size() == 1, "one jump")
	var j: Dictionary = t.jumps[0]
	runner.check(j.lip == int(0.25 * t.count) and j.start == j.lip - t.ramp_samples(), "foot and lip %s" % [j])
	runner.check(t.ramp_samples() == 4 and t.ramp_samples() * t.spacing == TrackData.JUMP_LENGTH, "the ramp spans whole samples")
	runner.check(is_equal_approx(TrackData.jump_slope(), TrackData.JUMP_HEIGHT / TrackData.JUMP_LENGTH), "slope = rise / run")
	runner.check(t.jump_at(j.start) == j and t.jump_at(j.lip) == j and t.jump_at(j.start - 1) == null and t.jump_at(j.lip + 1) == null, "jump_at bounds")
	runner.check(t.jump_at(j.lip + t.count) == j, "jump_at wraps")
	var foot: Vector3 = t.points[j.start]
	var fwd: Vector3 = t.tangents[j.start]
	runner.check(t.ramp_height(foot - fwd * 0.5, j.start) == 0.0, "flat before the foot")
	runner.check(is_equal_approx(t.ramp_height(foot + fwd * 6.0, j.start + 2), TrackData.JUMP_HEIGHT * 0.5), "half way up at half the length")
	runner.check(is_equal_approx(t.ramp_height(foot + fwd * TrackData.JUMP_LENGTH, j.lip), TrackData.JUMP_HEIGHT), "full height at the lip")
	runner.check(t.ramp_height(foot + fwd * (TrackData.JUMP_LENGTH + 0.3), j.lip) == 0.0, "nothing under the kart past the lip: it flies")
	runner.check(t.ramp_height(t.points[j.lip + 6], j.lip + 6) == 0.0, "flat on the landing")
	var bare := TrackData.new()
	runner.check(bare.jumps.is_empty() and bare.jump_at(5) == null and bare.ramp_height(bare.points[5], 5) == 0.0, "no ramps by default")
	var m := TrackData.new(TrackData.DEFAULT_CONTROL, 16.0, {"jumps": [0.25], "mirror": true})
	runner.check(m.jumps == t.jumps, "mirror keeps the ramp %s" % [m.jumps])

func test_dusty_canyon_has_the_ramp_the_others_none() -> void:
	for i in TrackLibrary.count():
		var d := TrackLibrary.make_data(i)
		var ramped: bool = TrackLibrary.info(i).name == "Dusty Canyon"
		runner.check(d.jumps.is_empty() != ramped, "%s jumps %s" % [TrackLibrary.info(i).name, d.jumps])
		if not ramped:
			continue
		runner.check(d.jumps.size() == 1, "one ramp")
		var j: Dictionary = d.jumps[0]
		# nothing stands on the ramp itself; the landing (JUMP_LENGTH past the lip at racing speed) keeps
		# clear of the boost pads and the level crossings (item boxes right after the lip are fair game:
		# a flying kart can snatch one, as on Royal Raceway)
		var landing: int = j.lip + 2 * d.ramp_samples()
		for f in d.box_rows:
			var bi: int = int(f * d.count) % d.count
			runner.check(bi < j.start - 2 or bi > j.lip, "item boxes %d off the ramp %s" % [bi, j])
		for p in d.pads:
			runner.check(p.index < j.start - 2 or p.index > landing, "pad %d off the ramp %s" % [p.index, j])
		for c in d.crossings:
			runner.check(c.road < j.start - 4 or c.road > landing + 4, "crossing %d off the ramp %s" % [c.road, j])
		# the ramp sits on a straight: the heading barely turns from foot to landing
		var turn: float = absf(wrapf(d.heading_at(landing) - d.heading_at(j.start), -PI, PI))
		runner.check(turn < 0.15, "ramp on a straight (turn %.2f rad)" % turn)
	runner.check(TrackLibrary.make_data(3, true).jumps == TrackLibrary.make_data(3).jumps, "mirror: same ramp")

func test_airborne_physics() -> void:
	# in the air the throttle and brake do nothing, friction does not bite, the stick only nudges the nose
	var k := KartPhysics.new()
	k.speed = 20.0
	k.airborne = true
	for i in 30:
		k.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(is_equal_approx(k.speed, 20.0), "throttle in the air does nothing (%.2f)" % k.speed)
	for i in 30:
		k.step(DT, 0.0, 1.0, 0.0, false)
	runner.check(is_equal_approx(k.speed, 20.0), "brake in the air does nothing (%.2f)" % k.speed)
	for i in 30:
		k.step(DT, 0.0, 0.0, 0.0, false)
	runner.check(is_equal_approx(k.speed, 20.0), "no friction in the air (%.2f)" % k.speed)
	var air_yaw: float = k.step(DT, 0.0, 0.0, 1.0, false)
	var g := KartPhysics.new()
	g.speed = 20.0
	var ground_yaw: float = g.step(DT, 0.0, 0.0, 1.0, false)
	# (1e-4: g loses a frame of friction before it steers)
	runner.check(air_yaw != 0.0 and absf(air_yaw - ground_yaw * KartPhysics.AIR_STEER) < 1e-4, "air steer %.4f = %.2f x ground %.4f" % [air_yaw, KartPhysics.AIR_STEER, ground_yaw])
	# back on the ground everything bites again
	k.airborne = false
	for i in 30:
		k.step(DT, 0.0, 0.0, 0.0, false)
	runner.check(k.speed < 20.0, "friction back on the ground (%.2f)" % k.speed)

func test_body_pitch() -> void:
	var slope := TrackData.jump_slope()
	runner.check(is_equal_approx(Kart.pitch_for(true, slope, 0.0, 30.0, false), atan(slope)), "nose up the ramp's slope while riding it")
	var up := Kart.pitch_for(false, slope, 6.0, 30.0, true)
	var down := Kart.pitch_for(false, slope, -6.0, 30.0, true)
	runner.check(up > 0.0 and is_equal_approx(up, atan2(6.0, 30.0) * Kart.AIR_PITCH), "nose up on the way up (%.2f)" % up)
	runner.check(is_equal_approx(down, -up), "nose down on the way down (%.2f)" % down)
	runner.check(Kart.pitch_for(false, slope, -3.0, 30.0, false) == 0.0, "level on the ground (a hop is not a flight)")
	runner.check(Kart.pitch_for(false, slope, 6.0, 0.0, true) == atan2(6.0, 1.0) * Kart.AIR_PITCH, "speed floor keeps atan2 sane at a standstill")
