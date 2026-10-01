extends SceneTree
## Windowed visual check: godot --path . -s tools/screenshot.gd  -> /tmp/gokart_*.png
## A pursuit bot drives the kart round the track; it starts a drift on the first
## long right-hand bend (steering out of the drift for the widest arc), holds it for a while, then releases for a mini-turbo boost.
## Saves screenshots of the drift, the charged drift and the boost.

var main: Node
var stage := 0
var drift_start := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Input.action_press("accelerate")

func _steer() -> void:
	var k = main.kart
	var t = main.track.data
	var target: Vector3 = t.points[(main.kart_index + 8) % t.count]
	var d: Vector3 = target - k.global_position
	var want := atan2(-d.x, -d.z)
	var err := wrapf(want - k.heading, -PI, PI)
	var s := clampf(-err * 2.5, -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if s > 0.0:
		Input.action_press("steer_right", s)
	else:
		Input.action_press("steer_left", -s)

func _process(_d: float) -> bool:
	var f := Engine.get_physics_frames()
	var k = main.kart
	if stage == 0 or (stage >= 3 and stage != 11):
		_steer()
	if stage == 0 and k.global_position.z < -42.0:
		Input.action_release("steer_left")
		Input.action_press("steer_right", 1.0)   # sets the drift direction
		Input.action_press("drift")
		drift_start = f
		stage = 1
	elif stage == 1 and f >= drift_start + 3:
		Input.action_release("steer_right")
		Input.action_press("steer_left", 1.0)   # steer out of the drift: widest arc
		stage = 11
	elif stage == 11 and f >= drift_start + 12:
		_shot("drift")
		stage = 2
	elif stage == 2 and k.model.drift_level >= 2:
		_shot("drift_charged")
		Input.action_release("drift")
		stage = 3
		drift_start = f
	elif stage == 3 and f >= drift_start + 12:
		_shot("boost")
		stage = 4
	elif stage == 4 and f >= drift_start + 60:
		return true
	if stage == 2 and f % 20 == 0:
		print("f=", f, " speed=", snappedf(k.model.speed, 0.1), " drift=", k.model.drifting, " charge=", snappedf(k.model.drift_charge, 0.01), " pos=", k.global_position)
	if f > 900:
		print("timeout stage=", stage)
		return true
	return false

func _shot(n: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("/tmp/gokart_%s.png" % n)
	var k = main.kart
	print("saved ", n, " frame=", Engine.get_physics_frames(), " speed=", snappedf(k.model.speed, 0.1), " boosting=", k.model.is_boosting(), " drift=", k.model.drifting, " lvl=", k.model.drift_level, " lap=", main.tracker.lap, " pos=", k.global_position)
