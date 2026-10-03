extends SceneTree
## Headless check of the Grand Prix flow: godot --headless --path . -s tools/gp_check.gd
## Menu -> G (Grand Prix) -> Enter -> race 1; the player is forced over the line, the results
## panel must show the cup standings; Enter -> race 2 on the next track with points carried;
## Esc -> menu with the cup cleared.

var stage := 0
var frames := 0
var ok := true
var t0 := 0

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.selected = 0
	change_scene_to_file("res://scenes/menu.tscn")

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _process(_d: float) -> bool:
	frames += 1
	var lib = load("res://scripts/track_library.gd")
	var gp = load("res://scripts/grand_prix.gd")
	var cs := current_scene
	if cs == null or frames < 5:
		return false
	if stage == 0:
		_check(cs.name == "Menu", "menu scene loaded")
		_check(cs.mode == cs.MODE_SINGLE, "single race by default")
		_key(KEY_G)
		stage = 1
		frames = 0
	elif stage == 1 and frames > 3:
		_check(cs.mode == cs.MODE_GP and "GRAND PRIX" in cs.mode_label.text, "G enables Grand Prix: " + cs.mode_label.text)
		_key(KEY_ENTER)
		stage = 2
		frames = 0
	elif stage == 2 and frames > 10:
		_check(cs.name == "Main", "race scene loaded: " + cs.name)
		_check(gp.active and gp.race_index == 0 and gp.order == [0, 1, 2], "cup started on track 0: %s" % str(gp.order))
		_check(cs.hud.cup_label.text == "RACE 1 / 3", "HUD cup label: " + cs.hud.cup_label.text)
		# force the player over the line in 1st
		cs.tracker.is_finished = true
		cs.tracker.race_time = 50.0
		t0 = Time.get_ticks_msec()
		stage = 3
		frames = 0
	elif stage == 3 and (cs.results_shown or Time.get_ticks_msec() - t0 > 6000):
		_check(cs.results_shown, "results shown after the delay")
		var txt: String = cs.hud.results_label.text
		_check("CUP STANDINGS" in txt and "RACE 1 / 3" in txt, "results carry the cup standings")
		_check("next race" in txt, "prompt for the next race")
		_check(gp.totals[0] == 9, "player got 9 points: %s" % str(gp.totals))
		_key(KEY_ENTER)
		stage = 4
		frames = 0
	elif stage == 4 and frames > 10:
		_check(cs.name == "Main", "race 2 scene loaded: " + cs.name)
		_check(gp.active and gp.race_index == 1 and lib.selected == 1, "cup moved to track 1 (race_index %d, selected %d)" % [gp.race_index, lib.selected])
		_check(cs.track.data.count == lib.make_data(1).count, "race 2 uses track 1 geometry")
		_check(gp.totals[0] == 9, "points carried over: %s" % str(gp.totals))
		_check(cs.hud.cup_label.text == "RACE 2 / 3", "HUD cup label: " + cs.hud.cup_label.text)
		_key(KEY_ESCAPE)
		stage = 5
		frames = 0
	elif stage == 5 and frames > 10:
		_check(cs.name == "Menu", "Escape returns to menu")
		_check(not gp.active and gp.totals.is_empty(), "Escape clears the cup")
		print("GP CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
