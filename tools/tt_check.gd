extends SceneTree
## Headless check of the Time Trial flow: godot --headless --path . -s tools/tt_check.gd
## Menu -> G G (Time Trial) -> Enter -> solo race at 100cc with a triple mushroom and no item
## boxes; the player is forced over the line, the panel must show the record and the ghost
## prompt; Enter -> same track again with the ghost on the course; Esc -> menu remembers the mode.
## The player's real records are stashed and restored at the end.

var stage := 0
var frames := 0
var ok := true
var t0 := 0
var backup_records := {}
var backup_ghosts := {}
var had_file := false

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	var tt = load("res://scripts/time_trial.gd")
	lib.selected = 0
	had_file = FileAccess.file_exists(tt.SAVE_PATH)
	tt.load_records()
	backup_records = tt.records
	backup_ghosts = tt.ghosts
	tt.reset()
	tt.loaded = true   # start from a clean slate without touching the file yet
	change_scene_to_file("res://scenes/menu.tscn")

func _restore() -> void:
	var tt = load("res://scripts/time_trial.gd")
	tt.records = backup_records
	tt.ghosts = backup_ghosts
	if had_file:
		tt.save()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tt.SAVE_PATH))
	tt.active = false

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _finish(code: int) -> void:
	_restore()
	print("TT CHECK: ", "OK" if ok else "FAILED")
	quit(code)

func _process(_d: float) -> bool:
	frames += 1
	var tt = load("res://scripts/time_trial.gd")
	var items = load("res://scripts/items.gd")
	var cs := current_scene
	if cs == null or frames < 5:
		return false
	if stage == 0:
		_check(cs.name == "Menu", "menu scene loaded")
		_key(KEY_G)
		_key(KEY_G)
		stage = 1
		frames = 0
	elif stage == 1 and frames > 3:
		_check(cs.mode == cs.MODE_TT and "TIME TRIAL" in cs.mode_label.text, "G G selects Time Trial: " + cs.mode_label.text)
		_check(cs.laps_label.text == "3" and cs.laps_keys.text == "Time Trial" and "100cc" in cs.engine_label.text, "menu shows the fixed 3 laps / 100cc")
		_key(KEY_ENTER)
		stage = 2
		frames = 0
	elif stage == 2 and frames > 10:
		_check(cs.name == "Main" and tt.active, "race scene loaded in time-trial mode")
		_check(cs.karts.size() == 1, "solo: %d kart(s)" % cs.karts.size())
		_check(cs.items.boxes.is_empty() and cs.items.projectiles.is_empty(), "no item boxes or hazards on the course")
		_check(cs.items.holder.held == items.Type.TRIPLE_MUSHROOM and cs.items.holder.charges == 3, "starts with a triple mushroom")
		_check(cs.tracker.total_laps == 3, "3 laps")
		_check(is_equal_approx(cs.kart.model.max_speed, 30.0 * 0.88), "100cc top speed: %f" % cs.kart.model.max_speed)
		_check(cs.ghost == null and cs.recording != null, "no ghost on a fresh track, recording ready")
		_check(cs.hud.cup_label.text == "TIME TRIAL   no record yet", "HUD: " + cs.hud.cup_label.text)
		_check(cs.hud.place_label.text == "", "no place shown when racing alone")
		t0 = Time.get_ticks_msec()
		stage = 3
	elif stage == 3 and (cs.recording.count() > 5 or Time.get_ticks_msec() - t0 > 8000):
		_check(cs.race_start.started and cs.recording.count() > 5, "recording runs from GO: %d samples" % cs.recording.count())
		cs.tracker.is_finished = true
		cs.tracker.race_time = 50.0
		cs.tracker.lap_times.assign([16.0, 17.0, 17.0])
		t0 = Time.get_ticks_msec()
		stage = 4
	elif stage == 4 and (cs.results_shown or Time.get_ticks_msec() - t0 > 6000):
		_check(cs.results_shown, "results shown after the delay")
		var txt: String = cs.hud.results_label.text
		_check(txt.begins_with("TIME TRIAL - Green Hills"), "time trial results panel")
		_check("NEW RECORD!" in txt and "BEST LAP  0:16.000   NEW!" in txt, "new record + best lap flagged")
		_check("> 1st  0:50.000" in txt and "race your ghost" in txt, "record list and ghost prompt")
		_check(tt.best_time("Green Hills") == 50.0 and tt.ghost_for("Green Hills") != null, "record and ghost filed")
		_check(FileAccess.file_exists(tt.SAVE_PATH), "records saved to " + tt.SAVE_PATH)
		_check("vs GHOST" in cs.hud.cup_label.text, "HUD updated: " + cs.hud.cup_label.text)
		_key(KEY_ENTER)
		stage = 5
		frames = 0
	elif stage == 5 and frames > 10:
		_check(cs.name == "Main" and cs.karts.size() == 1, "race again, still solo")
		_check(cs.ghost != null and cs.ghost.recording == tt.ghost_for("Green Hills"), "ghost of the best run on the course")
		_check(cs.ghost.model.materials[0].albedo_color.a < 1.0, "ghost is see-through")
		_check(cs.hud.cup_label.text == "TIME TRIAL   BEST 0:50.000   vs GHOST", "HUD: " + cs.hud.cup_label.text)
		t0 = Time.get_ticks_msec()
		stage = 6
	elif stage == 6 and (cs.ghost.time > 0.1 or Time.get_ticks_msec() - t0 > 8000):
		_check(cs.race_start.started and cs.ghost.time > 0.1, "ghost replays from GO: t=%.2f" % cs.ghost.time)
		_key(KEY_ESCAPE)
		stage = 7
		frames = 0
	elif stage == 7 and frames > 10:
		_check(cs.name == "Menu" and cs.mode == cs.MODE_TT, "Escape returns to the menu with Time Trial still selected")
		_finish(0 if ok else 1)
	return false
