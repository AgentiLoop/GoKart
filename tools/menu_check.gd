extends SceneTree
## Headless check of the title menu flow: godot --headless --path . -s tools/menu_check.gd
## Loads the menu, presses D, then Enter via real key events, and expects the race scene on track 1,
## then Escape returns to the menu.

var stage := 0
var frames := 0
var ok := true

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
	var cs := current_scene
	if cs == null or frames < 5:
		return false
	if stage == 0:
		_check(cs.name == "Menu", "menu scene loaded")
		_check(cs.name_label.text == lib.info(0).name, "shows track 0: " + cs.name_label.text)
		_key(KEY_D)
		stage = 1
		frames = 0
	elif stage == 1 and frames > 3:
		_check(cs.name_label.text == lib.info(1).name, "D selects track 1: " + cs.name_label.text)
		_key(KEY_ENTER)
		stage = 2
		frames = 0
	elif stage == 2 and frames > 10:
		_check(cs.name == "Main", "race scene loaded: " + cs.name)
		_check(lib.selected == 1, "selected track stored")
		_check(cs.track.data.count == lib.make_data(1).count, "race uses track 1 geometry")
		_key(KEY_ESCAPE)
		stage = 3
		frames = 0
	elif stage == 3 and frames > 10:
		_check(cs.name == "Menu", "Escape returns to menu")
		_check(cs.name_label.text == lib.info(1).name, "menu remembers track 1")
		print("MENU CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
