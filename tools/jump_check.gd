extends SceneTree
## Headless check of the MK64 Wario Stadium style jump ramp on Dusty Canyon: godot --headless --path . -s tools/jump_check.gd
## Loads the race scene on Dusty Canyon directly (no menu). The course has one jump: the track built a
## solid wedge across the road and taller walls along the ramp and the landing. After GO the player, sent
## at the ramp at speed, rides up it (nose pitched up), flies off the lip (airborne, no traction: the speed
## is kept, a whoosh), comes down nose first on the road past the lip with a thump and dust (landed) and
## drives on. A hop into a powerslide on the flat is not a jump. An AI kart sent at the ramp flies too,
## lands on the road and keeps racing, never rescued.

var main: Node
var stage := 0
var frames := 0
var ok := true
var phys0 := 0
var last_pf := -1   # _process runs more than once per physics frame: count / check each frame once
var peak_y := 0.0
var air_frames := 0
var take_off_speed := 0.0
var min_air_speed := INF
var max_pitch := -INF
var min_pitch := INF
var landings := 0
var hop_seen := false
var watched = null   # the kart whose landings are counted

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.selected = 3
	lib.engine_class = 2
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _park(k, pos: Vector3, heading: float, idx: int, speed: float) -> void:
	k.global_position = pos + Vector3(0, 0.1, 0)
	k.heading = heading
	k.rotation.y = heading
	k.track_index = idx
	k.model.speed = speed
	k.velocity = Vector3.ZERO
	k.push = Vector3.ZERO
	k.jumps = 0

func _reset_flight() -> void:
	peak_y = 0.0
	air_frames = 0
	take_off_speed = 0.0
	min_air_speed = INF
	max_pitch = -INF
	min_pitch = INF
	landings = 0

func _watch(k) -> void:
	peak_y = maxf(peak_y, k.global_position.y)
	max_pitch = maxf(max_pitch, k.pitch)
	min_pitch = minf(min_pitch, k.pitch)
	if k.airborne:
		air_frames += 1
		if take_off_speed == 0.0:
			take_off_speed = k.model.speed
		min_air_speed = minf(min_air_speed, k.model.speed)

func _process(_d: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var TrackData = load("res://scripts/track_data.gd")
	var Track = load("res://scripts/track.gd")
	var data = main.track.data
	var pf := Engine.get_physics_frames() - phys0
	if pf == last_pf and stage >= 3:
		return false
	last_pf = pf
	if stage == 0:
		_check(data.jumps.size() == 1, "Dusty Canyon has %d jump" % data.jumps.size())
		var j: Dictionary = data.jumps[0]
		_check(j.lip - j.start == data.ramp_samples() and data.ramp_samples() == 4, "the ramp spans %d samples to the lip %s" % [data.ramp_samples(), j])
		_check(data.jump_at(j.start) == j and data.jump_at(j.lip) == j and data.jump_at(j.start - 1) == null and data.jump_at(j.lip + 1) == null, "jump_at bounds")
		var body = main.track.get_node_or_null("Jumps")
		_check(body != null and body is StaticBody3D and body.get_child_count() == 1 and body.get_child(0) is CollisionShape3D, "the track built the solid ramp")
		if body != null:
			var cs: CollisionShape3D = body.get_child(0)
			var lip: Vector3 = data.points[j.lip]
			_check(cs.shape is BoxShape3D and is_equal_approx(cs.shape.size.y, TrackData.JUMP_HEIGHT - Track.JUMP_DROP_CLEARANCE) and Vector2(cs.position.x - lip.x, cs.position.z - lip.z).length() < 3.0, "...only the drop behind the lip is solid (%.1f m tall, %.1f m from the lip)" % [cs.shape.size.y, Vector2(cs.position.x - lip.x, cs.position.z - lip.z).length()])
		var mesh = main.track.get_node_or_null("JumpMesh")
		_check(mesh != null and mesh.mesh != null and mesh.get_aabb().has_point(Vector3(data.points[j.lip].x, mesh.get_aabb().position.y + 0.1, data.points[j.lip].z)), "...with its mesh over the lip")
		_check(is_equal_approx(main.track.wall_height_at(j.start), Track.JUMP_WALL_HEIGHT) and is_equal_approx(main.track.wall_height_at(j.lip + Track.JUMP_WALL_SAMPLES), Track.JUMP_WALL_HEIGHT), "tall walls along the ramp and the landing")
		_check(is_equal_approx(main.track.wall_height_at(j.start - 1), main.track.wall_height) and is_equal_approx(main.track.wall_height_at(j.lip + Track.JUMP_WALL_SAMPLES + 1), main.track.wall_height), "...standard walls before and after")
		_check(not main.kart.airborne and main.kart.jumps == 0 and not main.kart.on_ramp, "the player starts on the flat")
		for k in main.karts:
			k.landed.connect(func(): if k == watched: landings += 1)
		stage = 1
	elif stage == 1:
		if main.race_start.started:
			Input.action_press("accelerate")
			stage = 2
			phys0 = Engine.get_physics_frames()
		else:
			Input.action_release("accelerate")
	elif stage == 2:
		if pf >= 20:
			# freeze the field out of the way, send the player at the ramp at speed
			for i in range(1, main.karts.size()):
				main.karts[i].frozen = true
				main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			var j: Dictionary = data.jumps[0]
			var idx: int = j.start - 8
			_park(main.kart, data.points[idx], data.heading_at(idx), idx, 30.0)
			_reset_flight()
			watched = main.kart
			stage = 3
			phys0 = Engine.get_physics_frames()
	elif stage == 3:
		var k = main.kart
		var j: Dictionary = data.jumps[0]
		_watch(k)
		if landings >= 1 or pf >= 400:
			_check(k.jumps == 1, "the player flew off the ramp (%d jumps)" % k.jumps)
			_check(landings == 1, "...and landed (%d landings)" % landings)
			_check(not k.airborne, "...back on the ground")
			_check(peak_y > TrackData.JUMP_HEIGHT + 0.4, "flew higher than the lip (peak %.2f m)" % peak_y)
			_check(air_frames >= 25, "in the air %d frames" % air_frames)
			_check(take_off_speed > 25.0 and min_air_speed > take_off_speed - 1.0, "the speed was kept in the air (%.1f -> %.1f m/s)" % [take_off_speed, min_air_speed])
			_check(max_pitch > 0.1, "nose up on the ramp / the way up (%.2f rad)" % max_pitch)
			_check(min_pitch < -0.05, "nose down on the way down (%.2f rad)" % min_pitch)
			var past: int = posmod(k.track_index - j.lip, data.count)
			_check(past >= 4 and past <= 16, "landed %d samples past the lip" % past)
			_check(data.is_on_road(k.global_position, k.track_index), "on the road")
			_check(k.model.speed > 20.0, "still rolling (%.1f m/s)" % k.model.speed)
			_check(main.audio.played.has("jump") and main.audio.played.has("thud"), "whoosh and thump played %s" % [main.audio.played.slice(-4)])
			_check(k.launches == 0 and not k.model.is_spinning(), "a jump is not a crash")
			# a hop into a powerslide on the flat (the straight before the second crossing) is not a jump
			_park(k, data.points[298], data.heading_at(298), 298, 24.0)
			Input.action_press("steer_right")
			Input.action_press("drift")
			hop_seen = false
			stage = 4
			phys0 = Engine.get_physics_frames()
	elif stage == 4:
		var k = main.kart
		if k.velocity.y > 1.0:
			hop_seen = true
		if pf >= 40:
			_check(hop_seen, "the slide started with a hop")
			_check(k.jumps == 0 and not k.airborne, "...which is not a jump")
			Input.action_release("steer_right")
			Input.action_release("drift")
			Input.action_release("accelerate")
			k.frozen = true
			k.global_position = Vector3(400, 0.1, 380)
			# an AI kart at the ramp: it flies, lands on the road and keeps racing
			var j: Dictionary = data.jumps[0]
			var idx: int = j.start - 12
			var k1 = main.karts[1]
			k1.frozen = false
			_park(k1, data.points[idx] + data.right_of(idx) * 2.0, data.heading_at(idx), idx, 26.0)
			k1.driver.lane_offset = 2.0
			k1.driver.idx = idx
			k1.rescues = 0
			k1.launches = 0
			_reset_flight()
			watched = k1
			stage = 5
			phys0 = Engine.get_physics_frames()
	elif stage == 5:
		var k1 = main.karts[1]
		var j: Dictionary = data.jumps[0]
		_watch(k1)
		var past: int = posmod(k1.track_index - j.lip, data.count)
		if (landings >= 1 and past >= 20) or pf >= 600:
			_check(k1.jumps == 1 and landings == 1, "the AI kart flew off the ramp and landed (%d jumps, %d landings)" % [k1.jumps, landings])
			_check(peak_y > TrackData.JUMP_HEIGHT + 0.4 and air_frames >= 20, "...a real flight (peak %.2f m, %d frames)" % [peak_y, air_frames])
			_check(past >= 20 and past < 80, "...and drove on (%d samples past the lip)" % past)
			_check(data.is_on_road(k1.global_position, k1.track_index), "on the road")
			_check(k1.model.speed > 15.0, "still racing (%.1f m/s)" % k1.model.speed)
			_check(k1.rescues == 0 and k1.launches == 0, "never rescued or crashed")
			print("JUMP CHECK: ", "OK" if ok else "FAILED")
			quit(0 if ok else 1)
			return true
	return false
