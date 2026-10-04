extends SceneTree
## Windowed visual check: godot --path . -s tools/screenshot.gd  -> /tmp/gokart_*.png
## A pursuit bot drives the kart round the track; it hops into a drift on the first
## long right-hand bend (steering out of the drift for the widest arc), toggles the stick left / right
## until the smoke is red (MK64 mini-turbo), then releases for the boost.
## Saves screenshots of the drift, the charged drift and the boost.

var main: Node
var stage := 0
var drift_start := 0

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

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
	if main.race_start.started or main.race_start.remaining <= 0.5:
		if stage in [1, 11, 2]:
			Input.action_release("accelerate")   # coast through the slide so the bend fits the drift radius
		else:
			Input.action_press("accelerate")   # rocket start, not a false start
	if stage == 0 or (stage >= 3 and stage != 11 and stage != 8 and stage != 9 and stage != 10):
		_steer()
	if stage == 0 and k.global_position.z < -42.0:
		# start the slide from the left side of the road at 16 m/s so the right-hand drift has room
		var t = main.track.data
		var i: int = (main.kart_index + 2) % t.count
		var h: float = t.heading_at(i)
		k.global_position = t.points[i] + Vector3(-cos(h), 0, sin(h)) * 5.0
		k.heading = h
		k.rotation.y = h
		k.velocity = Vector3.ZERO
		k.model.speed = 16.0
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
	elif stage == 2 and k.model.drift_level < 2 and k.model.drifting:
		# MK64 mini-turbo: toggle the stick against the slide and back every 8 frames until the smoke is red
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		if (f - drift_start) / 8 % 2 == 0:
			Input.action_press("steer_right", 0.6)
		else:
			Input.action_press("steer_left", 1.0)
	elif stage == 2:
		Input.action_release("steer_left")
		Input.action_press("steer_right", 1.0)
		_shot("drift_charged")
		Input.action_release("drift")
		stage = 3
		drift_start = f
	elif stage == 3 and f >= drift_start + 12:
		_shot("boost")
		stage = 4
	elif stage == 4 and f >= drift_start + 30:
		# --- items: shell fired ahead, banana dropped behind, mushroom boost, item box, banana hit
		main.items.holder.held = 3
		main.items.use_item()
		drift_start = f
		stage = 5
	elif stage == 5 and f >= drift_start + 8:
		_shot("shell")
		main.items.holder.held = 2
		main.items.use_item()
		drift_start = f
		stage = 6
	elif stage == 6 and f >= drift_start + 8:
		_shot("banana")
		k.model.boost_time = 0.0
		main.items.holder.held = 1
		main.items.use_item()
		drift_start = f
		stage = 7
	elif stage == 7 and f >= drift_start + 15:
		_shot("mushroom")
		var t = main.track.data
		var bi: int = int(t.DEFAULT_BOX_ROWS[1] * t.count) % t.count
		var from: int = (bi - 5 + t.count) % t.count
		k.position = t.points[from] + Vector3(0, 0.1, 0)
		k.heading = t.heading_at(from)
		k.model.speed = 12.0
		main.kart_index = from
		drift_start = f
		stage = 8
	elif stage == 8 and f >= drift_start + 20:
		_shot("item_box")
		var fwd := Vector3(-sin(k.heading), 0, -cos(k.heading))
		main.items._add_projectile(main.items.ItemProjectile.make_banana(k.position + fwd * 4.0 + Vector3(0, 0.3, 0)))
		drift_start = f
		stage = 9
	elif stage == 9 and k.model.is_spinning():
		drift_start = f
		stage = 10
	elif stage == 10 and f >= drift_start + 30:
		_shot("hit")
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
