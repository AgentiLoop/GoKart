extends RefCounted
var runner

const OnlineRace := preload("res://scripts/online_race.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")

func _state(t: int, pos: Vector3, heading := 0.0) -> Dictionary:
	return {"t": t, "pos": pos, "heading": heading, "speed": 20.0, "yaw": 0.1, "pitch": -0.05, "scale": 1.2,
		"flags": OnlineRace.F_VISIBLE | OnlineRace.F_DRIFTING, "drift_level": 2, "weight": 1}

func test_state_round_trip() -> void:
	var s := _state(123456, Vector3(1.5, -2.0, 300.25), 2.5)
	var data := OnlineRace.pack_state(s)
	runner.check(OnlineRace.kind(data) == OnlineRace.Packet.STATE, "tagged as a state packet")
	var u := OnlineRace.unpack_state(data)
	runner.check(u.t == 123456 and u.pos.is_equal_approx(s.pos) and is_equal_approx(u.heading, 2.5), "pose survives: %s" % str(u))
	runner.check(is_equal_approx(u.scale, 1.2) and u.flags == s.flags and u.drift_level == 2 and u.weight == 1, "extras survive")
	runner.check(OnlineRace.unpack_state(data.slice(0, 10)).is_empty(), "short packet rejected")
	runner.check(OnlineRace.unpack_state(OnlineRace.pack_ready()).is_empty(), "other packet types rejected")
	runner.check(OnlineRace.kind(PackedByteArray()) == 0, "empty packet has no kind")

func test_course_and_grid() -> void:
	runner.check(OnlineRace.course_index({"course": TrackLibrary.info(2).name, "seed": 0}) == 2, "course by name")
	runner.check(OnlineRace.course_index({"course": "", "seed": TrackLibrary.count() + 1}) == 1, "course by seed")
	runner.check(OnlineRace.grid_order([7, 3, 5]) == [3, 5, 7], "lowest id on pole")
	runner.check(OnlineRace.COLORS.size() >= 4, "a colour for each of 4 players")

func test_puppet_interpolates() -> void:
	var p := OnlineRace.Puppet.new()
	runner.check(p.sample(0.016).is_empty(), "nothing before the first packet")
	p.push(_state(1000, Vector3.ZERO))
	p.push(_state(1100, Vector3(10, 0, 0)))
	p.push(_state(1050, Vector3(99, 0, 0)))
	runner.check(p.snaps.size() == 2, "late packet dropped")
	var s := p.sample(0.016)   # snaps to newest - INTERP_DELAY = 1000
	runner.check(s.pos.is_equal_approx(Vector3.ZERO), "plays 100 ms behind: %s" % s.pos)
	s = p.sample(0.05)
	runner.check(s.pos.x > 3.0 and s.pos.x < 7.0, "halfway between packets: %s" % s.pos)
	for i in 30:
		s = p.sample(0.016)
	runner.check(s.pos.is_equal_approx(Vector3(10, 0, 0)), "holds the last pose when packets stop: %s" % s.pos)
	p.push(_state(5000, Vector3(50, 0, 0)))
	s = p.sample(0.016)
	runner.check(s.pos.x > 45.0, "jumps after a long gap: %s" % s.pos)

func test_name_tag() -> void:
	var l := OnlineRace.make_tag("Alice", OnlineRace.COLORS[1])
	runner.check(l.text == "Alice" and l.billboard == BaseMaterial3D.BILLBOARD_ENABLED and l.position.y > 1.5, "billboard name over the kart")
	l.free()
