extends SceneTree
## Headless check of the Mario Kart 64 style course intro:
##   godot --headless --path . -s tools/intro_check.gd
## Menu -> Enter (title) -> Enter (race): the race opens with the fly-over — the countdown waits,
## the HUD is away and the name card is up with the course name — the camera moves along the road
## and cuts, then the intro ends on its own: the HUD is back, the camera is behind the player and
## the countdown runs. Esc -> menu -> Enter -> Enter again: the throttle skips the intro at once.
## A race scene loaded directly (as the other tools do) gets no intro.

const CourseIntro := preload("res://scripts/course_intro.gd")

var stage := 0
var frames := 0
var ok := true
var phys0 := 0
var cam_start := Vector3.ZERO
var cam_mid := Vector3.ZERO
var moved := 0.0
var mid_done := false

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	change_scene_to_file("res://scenes/menu.tscn")

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _process(_d: float) -> bool:
	frames += 1
	var cs := current_scene
	if cs == null or frames < 5:
		return false
	if stage == 0:
		_check(cs.name == "Menu", "menu scene loaded")
		_key(KEY_ENTER)   # leaves the title screen
		_key(KEY_ENTER)   # starts the race
		stage = 1
		frames = 0
	elif stage == 1 and frames > 10:
		_check(cs.name == "Main", "race scene loaded: " + cs.name)
		_check(cs.intro_t >= 0.0, "the intro is running (t=%.2f)" % cs.intro_t)
		_check(not CourseIntro.pending, "the flag was consumed")
		_check(cs.hud.intro_box.visible and cs.hud.intro_name.text == "GREEN HILLS", "name card up: " + cs.hud.intro_name.text)
		_check(cs.hud.intro_caption.text == "150cc  ·  3 LAPS", "caption: " + cs.hud.intro_caption.text)
		_check(not cs.hud.lap_label.visible and not cs.hud.minimap.visible and not cs.hud.place_label.visible, "race HUD away during the intro")
		_check(cs.hud.countdown_label.text == "", "no countdown yet")
		_check(not cs.race_start.started and is_equal_approx(cs.race_start.remaining, cs.race_start.COUNT_TIME), "the countdown has not begun (remaining %.2f)" % cs.race_start.remaining)
		_check(cs.kart.frozen, "karts frozen on the grid")
		var chase: Vector3 = cs.kart.global_position + cs._back() * 6.0 + Vector3(0, 3.0, 0)
		_check(cs.cam.global_position.distance_to(chase) > 20.0, "camera away from the chase spot (%.1f m)" % cs.cam.global_position.distance_to(chase))
		_check(absf(cs.cam.global_position.y - CourseIntro.FLY_UP) < 1.0, "camera FLY_UP over the road (y %.1f)" % cs.cam.global_position.y)
		cam_start = cs.cam.global_position
		stage = 2
		phys0 = Engine.get_physics_frames()
	elif stage == 2:
		var pf := Engine.get_physics_frames() - phys0
		if pf >= 30 and not mid_done:
			mid_done = true
			moved = cs.cam.global_position.distance_to(cam_start)
			_check(moved > 5.0 and moved < 20.0, "camera flew %.1f m along the road in half a second" % moved)
			_check(cs.hud.intro_box.modulate.a > 0.99, "card fully up")
			cam_mid = cs.cam.global_position
		if cs.intro_t > CourseIntro.CUT_TIME + 0.1 and cs.intro_t < CourseIntro.CUT_TIME + 0.3 and stage == 2:
			_check(cs.cam.global_position.distance_to(cam_mid) > 40.0, "second cut shows another stretch (%.0f m away)" % cs.cam.global_position.distance_to(cam_mid))
			stage = 3
	elif stage == 3:
		if cs.intro_t < 0.0:
			_check(not cs.hud.intro_box.visible, "card gone when the intro ends")
			_check(cs.hud.lap_label.visible and cs.hud.minimap.visible, "race HUD back")
			var chase: Vector3 = cs.kart.global_position + cs._back() * 6.0 + Vector3(0, 3.0, 0)
			_check(cs.cam.global_position.distance_to(chase) < 0.5, "camera cut to the chase spot (%.2f m off)" % cs.cam.global_position.distance_to(chase))
			stage = 4
			phys0 = Engine.get_physics_frames()
		elif Engine.get_physics_frames() - phys0 > 60 * (CourseIntro.TIME + 2.0):
			_check(false, "intro never ended")
			stage = 4
			phys0 = Engine.get_physics_frames()
	elif stage == 4 and Engine.get_physics_frames() - phys0 > 30:
		_check(cs.race_start.remaining < cs.race_start.COUNT_TIME - 0.3 and cs.hud.countdown_label.text != "", "countdown running: %s (%.2f left)" % [cs.hud.countdown_label.text, cs.race_start.remaining])
		_key(KEY_ESCAPE)
		stage = 5
		frames = 0
	elif stage == 5 and frames > 10:
		_check(cs.name == "Menu", "Escape returns to the menu")
		_key(KEY_ENTER)
		Input.action_press("accelerate")
		stage = 6
		frames = 0
	elif stage == 6 and frames > 10:
		_check(cs.name == "Main", "race scene loaded again")
		_check(cs.intro_t < 0.0 and not cs.hud.intro_box.visible and cs.hud.lap_label.visible, "the throttle skipped the intro at once")
		Input.action_release("accelerate")
		_check(cs.race_start.remaining < cs.race_start.COUNT_TIME, "countdown running after the skip")
		_key(KEY_ESCAPE)
		stage = 7
		frames = 0
	elif stage == 7 and frames > 10:
		_check(cs.name == "Menu", "back on the menu")
		# a race scene loaded directly (the way the other tools do it) opens on the countdown
		change_scene_to_file("res://scenes/main.tscn")
		stage = 8
		frames = 0
	elif stage == 8 and frames > 10:
		_check(cs.name == "Main" and cs.intro_t < 0.0 and not cs.hud.intro_box.visible, "no intro when the race scene is loaded directly")
		print("INTRO CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
