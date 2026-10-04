extends SceneTree
## Headless check of the MK64 Sherbet Land style ice on Frosty Peaks: godot --headless --path . -s tools/ice_check.gd
## Loads the race scene on Frosty Peaks directly (no menu). The course has two icy stretches and the
## track built a glossy ice ribbon over them. After GO the player, sent onto the long icy sweeper at
## speed with the wheel turned, slides: the model's grip drops to ICE_GRIP, a slide builds and the kart
## travels sideways of its nose; the same on the opening straight (tarmac) gives no slide at all. An AI
## kart sent at the first icy bend is told about the ice ahead (driver grip), slides through it and
## comes out the other side on the road, still racing.

var main: Node
var stage := 0
var frames := 0
var ok := true
var phys0 := 0
var checked := false
var slide_peak := 0.0
var travel_peak := 0.0
var ai_grip_seen := false
var ai_slide_peak := 0.0
var ai_ice_frames := 0
var last_pf := -1   # _process runs more than once per physics frame: count / check each frame once

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.selected = 2
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
	k.model.slide = 0.0
	k.velocity = Vector3.ZERO
	k.push = Vector3.ZERO

## Angle between the way the kart is actually moving and the way its nose points.
func _travel_angle(k) -> float:
	var v := Vector2(k.velocity.x, k.velocity.z)
	if v.length() < 1.0:
		return 0.0
	var moving := atan2(-v.x, -v.y)
	return absf(wrapf(moving - k.heading, -PI, PI))

func _process(_d: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var KartPhysics = load("res://scripts/kart_physics.gd")
	var AiDriver = load("res://scripts/ai_driver.gd")
	var data = main.track.data
	if stage == 0:
		_check(data.ice.size() == 2, "Frosty Peaks has %d icy stretches" % data.ice.size())
		var ribbon = main.track.get_node_or_null("Ice")
		_check(ribbon != null and ribbon.mesh != null and ribbon.mesh.get_surface_count() == 1, "the track built the ice ribbon")
		if ribbon != null:
			var s: Dictionary = data.ice[1]
			var mid: int = (s.start + s.end) / 2
			var aabb: AABB = ribbon.get_aabb()
			_check(aabb.has_point(Vector3(data.points[mid].x, aabb.position.y, data.points[mid].z)), "...over the icy road")
			_check(not aabb.has_point(Vector3(data.points[10].x, aabb.position.y, data.points[10].z)), "...and not over the opening straight")
		_check(main.kart.model.grip == 1.0 and main.kart.model.slide == 0.0, "the player starts with full grip on the grid")
		stage = 1
	elif stage == 1:
		if main.race_start.started:
			Input.action_press("accelerate")
			stage = 2
			phys0 = Engine.get_physics_frames()
		else:
			Input.action_release("accelerate")
	elif stage == 2:
		if Engine.get_physics_frames() - phys0 >= 20:
			# freeze the field out of the way, send the player onto the icy sweeper with the wheel turned
			for i in range(1, main.karts.size()):
				main.karts[i].frozen = true
				main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			var s: Dictionary = data.ice[1]
			var idx: int = s.start + 2
			_park(main.kart, data.points[idx], data.heading_at(idx), idx, 28.0)
			Input.action_press("steer_right")
			slide_peak = 0.0
			travel_peak = 0.0
			checked = false
			stage = 3
			phys0 = Engine.get_physics_frames()
	elif stage == 3:
		var pf := Engine.get_physics_frames() - phys0
		var k = main.kart
		slide_peak = maxf(slide_peak, absf(k.model.slide))
		travel_peak = maxf(travel_peak, _travel_angle(k))
		if pf >= 2 and not checked:
			checked = true
			_check(data.on_ice(k.global_position, k.track_index), "the player is on the ice")
			_check(is_equal_approx(k.model.grip, KartPhysics.ICE_GRIP), "...with ICE_GRIP (%.2f)" % k.model.grip)
		elif pf >= 20:
			_check(slide_peak > 0.1, "a slide built up on the ice (peak %.2f rad)" % slide_peak)
			_check(travel_peak > 0.08, "the kart travels sideways of its nose (peak %.2f rad)" % travel_peak)
			_check(k.model.speed > 20.0, "still rolling (%.1f m/s)" % k.model.speed)
			# now the same on the tarmac of the opening straight
			Input.action_release("steer_right")
			_park(k, data.points[10], data.heading_at(10), 10, 28.0)
			Input.action_press("steer_right")
			slide_peak = 0.0
			travel_peak = 0.0
			checked = false
			stage = 4
			phys0 = Engine.get_physics_frames()
	elif stage == 4:
		var pf := Engine.get_physics_frames() - phys0
		var k = main.kart
		if pf >= 2:
			slide_peak = maxf(slide_peak, absf(k.model.slide))
			travel_peak = maxf(travel_peak, _travel_angle(k))
		if pf >= 2 and not checked:
			checked = true
			_check(not data.on_ice(k.global_position, k.track_index) and k.model.grip == 1.0, "tarmac: full grip")
		elif pf >= 20:
			_check(slide_peak == 0.0, "no slide on tarmac")
			_check(travel_peak < 0.02, "the kart goes where its nose points (%.3f rad)" % travel_peak)
			Input.action_release("steer_right")
			Input.action_release("accelerate")
			main.kart.frozen = true
			main.kart.global_position = Vector3(400, 0.1, 380)
			# an AI kart at the first icy bend: it is told about the ice ahead and gets through
			var s: Dictionary = data.ice[0]
			var idx: int = posmod(s.start - AiDriver.ICE_LOOKAHEAD - 6, data.count)
			var k1 = main.karts[1]
			k1.frozen = false
			_park(k1, data.points[idx], data.heading_at(idx), idx, 25.0)
			k1.driver.lane_offset = 0.0
			k1.driver.idx = idx
			k1.rescues = 0
			ai_grip_seen = false
			ai_slide_peak = 0.0
			ai_ice_frames = 0
			checked = false
			last_pf = -1
			stage = 5
			phys0 = Engine.get_physics_frames()
	elif stage == 5:
		var pf := Engine.get_physics_frames() - phys0
		var k1 = main.karts[1]
		var s: Dictionary = data.ice[0]
		if pf == last_pf:
			return false
		last_pf = pf
		if pf == 2:
			_check(k1.driver.grip == 1.0, "AI kart: full grip while the ice is still far off")
		if is_equal_approx(k1.driver.grip, KartPhysics.ICE_GRIP):
			ai_grip_seen = true
			if not checked:
				checked = true
				_check(k1.track_index < s.start and data.ice_ahead(k1.track_index, AiDriver.ICE_LOOKAHEAD), "...told about the ice %d samples before it" % (s.start - k1.track_index))
		if k1.model.grip < 1.0:
			ai_ice_frames += 1
			ai_slide_peak = maxf(ai_slide_peak, absf(k1.model.slide))
		var past: int = posmod(k1.track_index - s.end, data.count)
		if (pf >= 240 and past > 0 and past < 80) or pf >= 600:
			_check(ai_grip_seen, "the AI driver saw the ice")
			_check(ai_ice_frames > 30, "the AI kart crossed the ice (%d frames on it)" % ai_ice_frames)
			_check(ai_slide_peak > 0.02, "...sliding (peak %.2f rad)" % ai_slide_peak)
			_check(past > 0 and past < 80, "...and is past it (%d samples beyond)" % past)
			_check(data.is_on_road(k1.global_position), "on the road")
			_check(k1.model.speed > 10.0, "still racing (%.1f m/s)" % k1.model.speed)
			_check(k1.rescues == 0, "never rescued")
			print("ICE CHECK: ", "OK" if ok else "FAILED")
			quit(0 if ok else 1)
			return true
	return false
