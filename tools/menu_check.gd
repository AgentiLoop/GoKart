extends SceneTree
## Headless check of the title menu flow: godot --headless --path . -s tools/menu_check.gd
## Loads the menu, presses D, then Enter via real key events, and expects the race scene on track 1,
## then Escape pauses the race and COURSE CHANGE returns to the menu. Also follows the menu audio: title theme on the title screen,
## select theme + ticks on the select screen, the hand-over to the scene root when the race starts.

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
		_check(cs.title_shown and not cs.select_box.visible and cs.title_prompt.visible, "title screen first: logo over the demo, panels hidden")
		_check(cs.attract.course == 0 and cs.attract.karts.size() == cs.attract.KART_COUNT and cs.attract.viewport.own_world_3d, "attract demo: %d karts on track 0 in their own world" % cs.attract.karts.size())
		_check(cs.audio.title.playing and cs.audio.title.volume_db == cs.audio.MUSIC_DB and not cs.audio.menu.playing, "title theme plays on the title screen (select theme silent)")
		_key(KEY_ENTER)   # Enter leaves the title screen (nothing else does)
		_key(KEY_D)
		stage = 1
		frames = 0
	elif stage == 1 and frames > 3:
		_check(cs.name_label.text == lib.info(1).name, "D selects track 1: " + cs.name_label.text)
		_check(not cs.title_shown and cs.select_box.visible and not cs.title_prompt.visible, "Enter brought up the select screen")
		_check(cs.attract.course == 1 and cs.attract.track.data.count == lib.make_data(1).count, "demo switches to track 1")
		_check(cs.sub_label.text == "SELECT COURSE" and cs.list_box.get_child_count() == lib.count() + 1, "course list: %d rows + lit bar" % lib.count())
		_check(cs.font.get_font_name() != "" and cs.laps_label.get_theme_constant("outline_size") == 0, "menu text has no black outline (font %s)" % cs.font.get_font_name())
		_check(cs.audio.menu.playing and cs.audio.played == ["confirm", "cursor"], "select theme starts, chime + cursor tick: %s" % str(cs.audio.played))
		_key(KEY_W)
		stage = 15
		frames = 0
	elif stage == 15 and frames > 3:
		_check(lib.step_laps(3, 1) == 5 and cs.laps == 5, "W raises laps to 5: %d" % cs.laps)
		var moving := 0
		for k in cs.attract.karts:
			if k.model.speed > 0.5:
				moving += 1
		_check(moving == cs.attract.karts.size(), "demo karts are driving: %d / %d" % [moving, cs.attract.karts.size()])
		_check(cs.audio.played[-1] == "option", "an option key ticks: %s" % str(cs.audio.played))
		_key(KEY_Z)
		stage = 16
		frames = 0
	elif stage == 16 and frames > 3:
		_check(cs.engine_class == 1 and cs.engine_label.text.contains("100cc"), "Z drops the engine class to 100cc: " + cs.engine_label.text)
		_key(KEY_ENTER)
		stage = 2
		frames = 0
	elif stage == 2 and frames > 10:
		_check(cs.name == "Main", "race scene loaded: " + cs.name)
		_check(lib.selected == 1, "selected track stored")
		_check(lib.laps == 5 and cs.tracker.total_laps == 5, "race uses 5 laps")
		_check(cs.track.data.count == lib.make_data(1).count, "race uses track 1 geometry")
		_check(lib.engine_class == 1 and is_equal_approx(cs.kart.model.max_speed, 30.0 * lib.engine_info(1).speed), "100cc scales the player's top speed: %f" % cs.kart.model.max_speed)
		_check(cs.karts[1].model.max_speed < 30.0 * lib.engine_info(1).speed, "100cc scales the AI karts too: %f" % cs.karts[1].model.max_speed)
		_check(load("res://scripts/menu_audio.gd").leaves == 1, "Enter handed the menu tune + chime to the scene root")
		_key(KEY_ESCAPE)
		stage = 25
		frames = 0
	elif stage == 25 and frames > 3:
		# MK64: Start freezes the race under the pause screen; COURSE CHANGE goes back to the menu
		_check(cs.name == "Main" and paused and cs.pause.shown and cs.pause.visible, "Escape pauses the race under the pause panel")
		_check(cs.pause.cursor == cs.pause.CONTINUE and cs.pause.rows[2].text == "COURSE CHANGE", "cursor on CONTINUE, COURSE CHANGE third")
		_key(KEY_S)
		_key(KEY_S)
		_key(KEY_ENTER)
		stage = 3
		frames = 0
	elif stage == 3 and frames > 10:
		_check(cs.name == "Menu" and not paused, "COURSE CHANGE returns to menu, tree running")
		_check(not cs.title_shown and cs.select_box.visible, "Escape comes back to the select screen, not the title")
		_check(cs.name_label.text == lib.info(1).name, "menu remembers track 1")
		_check(cs.laps == 5, "menu remembers laps")
		_check(cs.engine_class == 1, "menu remembers the engine class")
		_check(cs.audio.menu.playing and not cs.audio.title.playing, "back from the race: select theme, no title theme")
		print("MENU CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
