extends SceneTree
## Headless check of MK64 weight classes: godot --headless --path . -s tools/weight_check.gd
## Menu -> V (Medium -> Heavy) -> Enter: the player races a heavy kart (mass, size, top speed),
## the AI field mixes the three classes; after GO a light AI kart is parked in front of the player,
## who drives into it: the light kart is thrown aside, the heavy player keeps its speed.
## Esc returns to the menu, which still shows Heavy.

var stage := 0
var frames := 0
var ok := true
var victim = null
var max_victim_push := 0.0
var max_player_push := 0.0
var speed_before := 0.0
var phys0 := 0   # physics frame a stage started on (headless render frames outrun physics ticks)

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	load("res://scripts/kart_weight.gd").selected = 1
	change_scene_to_file("res://scenes/menu.tscn")

## Pursuit steering towards the sample 10 ahead (as tools/smoke.gd) so the player follows the road.
func _steer(main) -> void:
	var t = main.track.data
	var target: Vector3 = t.points[(main.kart_index + 10) % t.count]
	var d: Vector3 = target - main.kart.global_position
	var err := wrapf(atan2(-d.x, -d.z) - main.kart.heading, -PI, PI)
	var s := clampf(-err * 2.5, -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_press("steer_right" if s > 0.0 else "steer_left", absf(s))

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _process(_d: float) -> bool:
	frames += 1
	if stage >= 3 and current_scene != null and current_scene.name == "Main":
		_steer(current_scene)
	var W = load("res://scripts/kart_weight.gd")
	var cs := current_scene
	if cs == null or frames < 5:
		return false
	if stage == 0:
		_check(cs.name == "Menu", "menu scene loaded")
		_check(cs.weight_label.text.contains("Medium"), "Medium by default: " + cs.weight_label.text)
		_key(KEY_V)
		stage = 1
		frames = 0
	elif stage == 1 and frames > 3:
		_check(cs.weight_class == W.HEAVY and cs.weight_label.text.contains("Heavy"), "V steps Medium up to Heavy: " + cs.weight_label.text)
		_key(KEY_ENTER)
		stage = 2
		frames = 0
	elif stage == 2 and frames > 10:
		_check(cs.name == "Main", "race scene loaded: " + cs.name)
		_check(W.selected == W.HEAVY, "menu handed Heavy to the race")
		var heavy: Dictionary = W.info(W.HEAVY)
		_check(cs.kart.weight_class == W.HEAVY and is_equal_approx(cs.kart.mass, heavy.mass), "player kart is heavy (mass %f)" % cs.kart.mass)
		_check(is_equal_approx(cs.kart.model.max_speed, 30.0 * heavy.speed), "heavy top speed: %f" % cs.kart.model.max_speed)
		_check(is_equal_approx(cs.kart.size_scale, heavy.size), "heavy body size")
		var classes := {}
		for i in range(1, cs.karts.size()):
			var k = cs.karts[i]
			classes[k.weight_class] = true
			_check(is_equal_approx(k.mass, W.info(k.weight_class).mass), "AI kart %d mass matches its class" % i)
		_check(classes.size() == 3, "AI field mixes all three classes")
		Input.action_press("accelerate")
		stage = 3
		phys0 = Engine.get_physics_frames()
	elif stage == 3 and Engine.get_physics_frames() - phys0 > 420:
		# after GO: park the light GREEN kart (karts[2]) 7 m straight ahead of the player
		victim = cs.karts[2]
		_check(victim.weight_class == W.LIGHT, "GREEN is a light kart")
		victim.frozen = true
		victim.driver = null
		victim.model.speed = 0.0
		victim.push = Vector3.ZERO
		victim.velocity = Vector3.ZERO
		var fwd: Vector3 = Vector3(-sin(cs.kart.heading), 0, -cos(cs.kart.heading))
		victim.global_position = cs.kart.global_position + fwd * 7.0
		victim.heading = cs.kart.heading
		speed_before = cs.kart.model.speed
		_check(speed_before > 10.0, "player is up to speed before the bump: %f" % speed_before)
		stage = 4
		phys0 = Engine.get_physics_frames()
	elif stage == 4:
		max_victim_push = maxf(max_victim_push, victim.push.length())
		max_player_push = maxf(max_player_push, cs.kart.push.length())
		var pf := Engine.get_physics_frames() - phys0
		if (victim.bumps >= 1 and pf > 20) or pf > 180:
			_check(victim.bumps >= 1 and cs.kart.bumps >= 1, "the karts bumped (victim %d, player %d)" % [victim.bumps, cs.kart.bumps])
			_check(max_victim_push > max_player_push * 2.0, "the light kart is thrown much further: %f vs %f" % [max_victim_push, max_player_push])
			_check(cs.kart.model.speed > speed_before * 0.7, "the heavy player keeps its speed: %f (was %f)" % [cs.kart.model.speed, speed_before])
			Input.action_release("accelerate")
			_key(KEY_ESCAPE)
			stage = 5
			frames = 0
	elif stage == 5 and frames > 10:
		_check(cs.name == "Menu", "Escape returns to menu")
		_check(cs.weight_class == W.HEAVY and cs.weight_label.text.contains("Heavy"), "menu remembers Heavy")
		W.selected = W.MEDIUM
		print("WEIGHT CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
