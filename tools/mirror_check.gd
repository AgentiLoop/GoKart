extends SceneTree
## Headless check of MK64 Extra (mirror) mode: godot --headless --path . -s tools/mirror_check.gd
## Menu -> C (150cc -> Extra) -> Enter: the race runs on the left-right flipped course with
## 8 karts on the grid; Esc returns to the menu, which still shows Extra.

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
	lib.selected = 1
	lib.engine_class = 2
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
		_check(not cs.blurb_label.text.contains("MIRRORED"), "150cc blurb is plain: " + cs.blurb_label.text)
		_key(KEY_C)
		stage = 1
		frames = 0
	elif stage == 1 and frames > 3:
		_check(cs.engine_class == 3 and cs.engine_label.text.contains("Extra"), "C steps 150cc up to Extra: " + cs.engine_label.text)
		_check(cs.blurb_label.text.contains("MIRRORED"), "blurb tagged: " + cs.blurb_label.text)
		_key(KEY_ENTER)
		stage = 2
		frames = 0
	elif stage == 2 and frames > 10:
		_check(cs.name == "Main", "race scene loaded: " + cs.name)
		var plain = lib.make_data(1)
		var data = cs.track.data
		_check(data.mirrored, "race track is mirrored")
		_check(data.count == plain.count, "same sample count")
		var err := 0.0
		for i in plain.count:
			err = maxf(err, (Vector3(-plain.points[i].x, 0, plain.points[i].z) - data.points[i]).length())
		_check(err < 0.01, "race course is the x-reflection of track 1 (err %f)" % err)
		_check(cs.karts.size() == 8, "8 karts on the mirrored grid: %d" % cs.karts.size())
		for k in cs.karts:
			_check(data.is_on_road(k.global_position), "kart %d starts on the mirrored road" % k.kart_id)
		_check(is_equal_approx(cs.kart.model.max_speed, 30.0), "Extra runs at 150cc speed: %f" % cs.kart.model.max_speed)
		_check(cs.track.get_node_or_null("Walls") != null and cs.track.get_node_or_null("StartGate") != null, "walls and gate built")
		_key(KEY_ESCAPE)
		stage = 3
		frames = 0
	elif stage == 3 and frames > 10:
		_check(cs.name == "Menu", "Escape returns to menu")
		_check(cs.engine_class == 3 and cs.blurb_label.text.contains("MIRRORED"), "menu remembers Extra")
		lib.engine_class = 2
		print("MIRROR CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
