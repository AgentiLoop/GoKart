extends SceneTree
## Headless check of the MK64 Toad's Turnpike traffic: godot --headless --path . -s tools/traffic_check.gd [-- engine_class]
## Loads the race scene on Sunset Speedway directly (no menu). The traffic model, highway node and
## vehicles are built and stand still through the countdown, then set off at GO. An AI kart parked
## behind a vehicle in its own lane dodges it (never hit); the player set inside a vehicle is thrown
## into the air, spun out, crash sound, lands again. Pass 3 for the Extra class (oncoming traffic).

var main: Node
var stage := 0
var frames := 0
var ok := true
var phys0 := 0
var peak_y := 0.0
var dodged := false
var checked := false
var victim := 0        # index of the vehicle the AI kart is parked behind
var before: Array = []

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.selected = 1
	var args := OS.get_cmdline_user_args()
	lib.engine_class = int(args[0]) if args.size() > 0 else 2
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _park(k, pos: Vector3, heading: float, idx: int) -> void:
	k.global_position = pos + Vector3(0, 0.1, 0)
	k.heading = heading
	k.rotation.y = heading
	k.track_index = idx
	k.model.speed = 0.0
	k.velocity = Vector3.ZERO
	k.push = Vector3.ZERO

func _process(_d: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var Traffic = load("res://scripts/traffic.gd")
	var tr = main.traffic
	var data = main.track.data
	if stage == 0:
		_check(main.traffic != null and tr.active() and main.highway != null, "traffic model and highway node built")
		_check(tr.vehicles.size() == data.traffic_specs.size() and tr.vehicles.size() >= 8, "%d vehicles" % tr.vehicles.size())
		_check(main.highway.cars.size() == tr.vehicles.size() and main.highway.get_node_or_null("Vehicle0") != null, "a node per vehicle")
		_check(tr.dir == (-1 if data.mirrored else 1), "traffic drives %s the racers" % ("against" if tr.dir < 0 else "with"))
		for i in tr.vehicles.size():
			before.append(tr.vehicles[i].s)
		stage = 1
	elif stage == 1:
		if main.race_start.started:
			_check(not dodged, "traffic stood still through the countdown")
			dodged = false
			Input.action_press("accelerate")
			stage = 2
			phys0 = Engine.get_physics_frames()
		else:
			for i in tr.vehicles.size():
				if tr.vehicles[i].s != before[i]:
					dodged = true   # (reused flag) something moved before GO
			Input.action_release("accelerate")
	elif stage == 2:
		if Engine.get_physics_frames() - phys0 >= 60:
			var moved := 0
			for i in tr.vehicles.size():
				if absf(tr.ahead_of(tr.vehicles[i], before[i])) > 5.0:
					moved += 1
			_check(moved == tr.vehicles.size(), "every vehicle set off at GO (%d moved)" % moved)
			_check(main.highway.cars[0].position.is_equal_approx(tr.vehicle_pose(0).pos), "highway node follows the model")
			# freeze the field out of the way, then park AI kart 1 behind a vehicle in its own lane
			for i in range(2, main.karts.size()):
				main.karts[i].frozen = true
				main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.kart.frozen = true
			main.kart.global_position = Vector3(400, 0.1, 380)
			Input.action_release("accelerate")
			victim = 0
			for i in tr.vehicles.size():
				if tr.vehicles[i].kind == "bus":
					victim = i
			var v: Dictionary = tr.vehicles[victim]
			# the vehicle is ahead of the kart along the road either way; an oncoming one gets more room
			var s_k: float = fposmod(v.s - (18.0 if tr.dir > 0 else 60.0), data.length)
			var pose: Dictionary = tr.road_pose(s_k, v.lane)
			var idx: int = data.nearest_index(pose.pos)
			var k1 = main.karts[1]
			_park(k1, pose.pos, data.heading_at(idx), idx)
			k1.model.speed = 20.0   # rolling, not from a standstill
			k1.driver.lane_offset = v.lane
			k1.driver.dodging = false
			k1.driver.idx = idx
			k1.launches = 0
			dodged = false
			checked = false
			stage = 3
			phys0 = Engine.get_physics_frames()
	elif stage == 3:
		var pf := Engine.get_physics_frames() - phys0
		var k1 = main.karts[1]
		var v: Dictionary = tr.vehicles[victim]
		if k1.driver.dodging:
			dodged = true
		if pf >= 5 and not checked:
			checked = true
			_check(k1.driver.dodging and k1.driver.dodge_lane != v.lane, "AI kart sees the %s ahead and aims for %.1f m instead of %.1f" % [v.kind, k1.driver.dodge_lane, v.lane])
		elif pf >= 240:
			var lateral: float = (k1.global_position - data.points[k1.track_index]).dot(data.right_of(k1.track_index))
			_check(dodged, "the AI kart dodged")
			_check(k1.launches == 0, "...and was never hit (launches %d)" % k1.launches)
			_check(data.is_on_road(k1.global_position), "stayed on the road (lateral %.1f m)" % lateral)
			_check(k1.model.speed > 10.0, "still racing (%.1f m/s)" % k1.model.speed)
			# now the player sits inside a vehicle
			k1.frozen = true
			k1.global_position = Vector3(400, 0.1, 420)
			var hit := 0
			for i in tr.vehicles.size():
				if tr.vehicles[i].kind == "truck":
					hit = i
			var p: Dictionary = tr.vehicle_pose(hit)
			main.kart.frozen = false
			_park(main.kart, p.pos, data.heading_at(data.nearest_index(p.pos)), data.nearest_index(p.pos))
			main.kart.launches = 0
			_check(tr.hit_dir(main.kart.global_position) != Vector3.ZERO, "player inside the %s" % tr.vehicles[hit].kind)
			peak_y = 0.0
			checked = false
			stage = 4
			phys0 = Engine.get_physics_frames()
	elif stage == 4:
		var pf := Engine.get_physics_frames() - phys0
		peak_y = maxf(peak_y, main.kart.global_position.y)
		if pf >= 10 and not checked:
			checked = true
			_check(main.kart.launches == 1, "player thrown by the vehicle (launches %d)" % main.kart.launches)
			_check(main.kart.model.is_spinning(), "spinning out")
			_check(main.audio.played.has("crash"), "crash sound")
			_check(is_equal_approx(Traffic.LAUNCH_SPEED, 10.0), "launch speed constant")
		elif pf > 150:
			_check(peak_y > 1.0, "thrown into the air: peak y %.2f" % peak_y)
			_check(main.kart.global_position.y < 0.6, "landed again (y %.2f)" % main.kart.global_position.y)
			_check(main.kart.launches == 1, "hit once only (%d)" % main.kart.launches)
			print("TRAFFIC CHECK: ", "OK" if ok else "FAILED")
			quit(0 if ok else 1)
			return true
	return false
