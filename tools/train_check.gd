extends SceneTree
## Headless check of the MK64 Kalimari Desert railway: godot --headless --path . -s tools/train_check.gd
## Menu -> Enter on Dusty Canyon: the railway, signals, two trains and the minimap rail are built.
## After GO an AI kart parked before the second crossing waits while a train is made to approach
## and pass (signal lamps flash, the crossing bell rings for the nearby player), then pulls away.
## The player is then set on the crossing under a passing locomotive: thrown into the air, spun out,
## crash sound, lands again. Esc returns to the menu.

var stage := 0
var frames := 0
var ok := true
var phys0 := 0
var crossing := {}
var peak_y := 0.0
var lamp_seen := false
var checked := false   # the one-off checks of a stage were done

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

## Esc now brings up the MK64 pause screen; its third line, COURSE CHANGE, is what goes back to the menu.
func _course_change() -> void:
	_key(KEY_ESCAPE)
	_key(KEY_S)
	_key(KEY_S)
	_key(KEY_ENTER)

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 3
	change_scene_to_file("res://scenes/menu.tscn")

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _lit(cs) -> bool:
	for lamp in cs.railway.lamps[1]:
		if (lamp.material_override as StandardMaterial3D).emission_enabled:
			return true
	return false

func _park(k, data, idx: int, lateral: float) -> void:
	k.global_position = data.points[idx] + data.right_of(idx) * lateral + Vector3(0, 0.1, 0)
	k.heading = data.heading_at(idx)
	k.rotation.y = k.heading
	k.track_index = idx
	k.model.speed = 0.0
	k.velocity = Vector3.ZERO
	k.push = Vector3.ZERO

func _process(_d: float) -> bool:
	frames += 1
	var cs := current_scene
	if cs == null or frames < 5:
		return false
	var Train = load("res://scripts/train.gd")
	if stage == 0:
		_check(cs.name == "Menu", "menu scene loaded")
		_key(KEY_ENTER)   # leaves the title screen
		_key(KEY_ENTER)   # starts the race
		stage = 1
		frames = 0
	elif stage == 1 and frames > 10:
		_check(cs.name == "Main", "race scene loaded: " + cs.name)
		var data = cs.track.data
		_check(data.crossings.size() == 2 and data.rail.size() > 100, "Dusty Canyon has a rail loop with two crossings")
		_check(cs.train != null and cs.train.active() and cs.railway != null, "train model and railway node built")
		_check(cs.railway.get_node_or_null("Rails") != null, "rail mesh")
		_check(cs.railway.lamps.size() == 2 and cs.railway.cars.size() == 2 and cs.railway.cars[0].size() == Train.CARS, "two signals, two trains of %d cars" % Train.CARS)
		_check(cs.hud.minimap.rail_points.size() == data.rail.size() + 1, "minimap shows the railway")
		var walls = cs.track.get_node("Walls")
		_check(walls.get_child_count() < 2 * data.count - 2 * 2 * (2 * data.CROSSING_HALF_GAP + 1) + 1, "walls open at the crossings (%d pieces)" % walls.get_child_count())
		crossing = data.crossings[1]
		stage = 2
	elif stage == 2:
		if cs.race_start.started:
			var data = cs.track.data
			# AI kart 1 parked 6 samples before the second crossing, the player 12 samples back
			_park(cs.karts[1], data, posmod(crossing.road - 6, data.count), 0.0)
			_park(cs.kart, data, posmod(crossing.road - 12, data.count), -3.0)
			Input.action_release("accelerate")
			var L: float = data.rail_length
			cs.train.heads[0] = fposmod(crossing.s - Train.WARN_DISTANCE + 1.0, L)
			cs.train.heads[1] = fposmod(cs.train.heads[0] + L * 0.5, L)
			_check(cs.train.blocked(1), "train approaching: crossing blocked")
			_check(not cs.audio.played.has("bell"), "no bell yet")
			stage = 3
			phys0 = Engine.get_physics_frames()
	elif stage == 3:
		var pf := Engine.get_physics_frames() - phys0
		if _lit(cs):
			lamp_seen = true
		if pf >= 60 and not checked:
			checked = true
			var k1 = cs.karts[1]
			_check(k1.driver.wait, "AI kart waits at the blocked crossing")
			_check(k1.model.speed < 3.0, "...standing still (%.1f m/s)" % k1.model.speed)
			_check(cs.train.blocked(1), "still blocked a second later")
			_check(lamp_seen, "signal lamps flashing")
			_check(cs.audio.played.has("bell"), "crossing bell rings for the nearby player")
		elif pf > 60 and not cs.train.blocked(1):
			_check(pf < 600, "train passed the crossing after %d frames" % pf)
			stage = 4
			phys0 = Engine.get_physics_frames()
		elif pf > 600:
			_check(false, "crossing never cleared")
			stage = 4
			phys0 = Engine.get_physics_frames()
	elif stage == 4:
		if Engine.get_physics_frames() - phys0 > 90:
			var k1 = cs.karts[1]
			_check(not k1.driver.wait, "crossing open: no more waiting")
			_check(k1.model.speed > 5.0, "AI kart pulls away (%.1f m/s)" % k1.model.speed)
			_check(k1.launches == 0, "the waiting kart was never hit")
			# now the player sits on the crossing with the locomotive over it
			var data = cs.track.data
			_park(cs.kart, data, crossing.road, 0.0)
			cs.train.heads[0] = fposmod(crossing.s + Train.CAR_LENGTH * 0.5, data.rail_length)
			cs.train.heads[1] = fposmod(cs.train.heads[0] + data.rail_length * 0.5, data.rail_length)
			_check(cs.train.hit_dir(cs.kart.global_position) != Vector3.ZERO, "locomotive over the player")
			peak_y = 0.0
			checked = false
			stage = 5
			phys0 = Engine.get_physics_frames()
	elif stage == 5:
		var pf := Engine.get_physics_frames() - phys0
		peak_y = maxf(peak_y, cs.kart.global_position.y)
		if pf >= 10 and not checked:
			checked = true
			_check(cs.kart.launches == 1, "player thrown by the train (launches %d)" % cs.kart.launches)
			_check(cs.kart.model.is_spinning(), "spinning out")
			_check(cs.audio.played.has("crash"), "crash sound")
			_check(cs.audio.played.has("hit"), "hit sound")
		elif pf > 150:
			_check(peak_y > 1.0, "thrown into the air: peak y %.2f" % peak_y)
			_check(cs.kart.global_position.y < 0.6, "landed again (y %.2f)" % cs.kart.global_position.y)
			_check(cs.kart.launches == 1, "hit once only (%d)" % cs.kart.launches)
			_course_change()
			stage = 6
			frames = 0
	elif stage == 6 and frames > 10:
		_check(cs.name == "Menu", "Escape returns to menu")
		print("TRAIN CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
