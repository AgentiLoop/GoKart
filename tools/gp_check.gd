extends SceneTree
## Headless check of the Grand Prix flow: godot --headless --path . -s tools/gp_check.gd
## Menu -> G (Grand Prix) -> Enter -> race 1 (player 8th on the grid); the player is forced over
## the line in 1st, the results panel must show the cup standings; Enter -> race 2 on the next
## track with points carried and the player on pole (MK64 grid rule); five AI karts beat the
## player there -> 6th -> RANK OUT, no points, Enter re-runs the same race (MK64 retry rule);
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
		_check(gp.active and gp.race_index == 0 and gp.order == [0, 1, 2, 3], "cup started on track 0: %s" % str(gp.order))
		_check(cs.hud.cup_label.text == "RACE 1 / 4", "HUD cup label: " + cs.hud.cup_label.text)
		var back_idx: int = cs.track.data.count - 10
		_check(cs.kart.track_index == back_idx and cs.karts[1].track_index == back_idx + 9, "first race: player on the back row (8th), BLUE on pole")
		# force the player over the line in 1st
		cs.tracker.is_finished = true
		cs.tracker.race_time = 50.0
		t0 = Time.get_ticks_msec()
		stage = 3
		frames = 0
	elif stage == 3 and (cs.results_shown or Time.get_ticks_msec() - t0 > 6000):
		_check(cs.results_shown, "results shown after the delay")
		var txt: String = cs.hud.results_text
		_check("CUP STANDINGS" in txt and "RACE 1 / 4" in txt, "results carry the cup standings")
		_check("next race" in txt, "prompt for the next race")
		_check(gp.totals[0] == 9, "player got 9 points: %s" % str(gp.totals))
		_check(gp.grid.size() == 8 and gp.grid[0] == 0 and not gp.retry, "the winner takes pole in the next grid: %s" % str(gp.grid))
		_key(KEY_ENTER)
		stage = 4
		frames = 0
	elif stage == 4 and frames > 10:
		_check(cs.name == "Main", "race 2 scene loaded: " + cs.name)
		_check(gp.active and gp.race_index == 1 and lib.selected == 1, "cup moved to track 1 (race_index %d, selected %d)" % [gp.race_index, lib.selected])
		_check(cs.track.data.count == lib.make_data(1).count, "race 2 uses track 1 geometry")
		_check(gp.totals[0] == 9, "points carried over: %s" % str(gp.totals))
		_check(cs.hud.cup_label.text == "RACE 2 / 4", "HUD cup label: " + cs.hud.cup_label.text)
		# MK64 grid rule: the player won race 1, so it starts race 2 from pole
		var data = cs.track.data
		var back_idx: int = data.count - 10
		var pole: Vector3 = data.points[back_idx + 9] + data.right_of(back_idx + 9) * -cs.GRID_LANE
		var off: float = Vector2(cs.kart.position.x - pole.x, cs.kart.position.z - pole.z).length()
		_check(cs.kart.track_index == back_idx + 9 and off < 0.05, "player starts race 2 on pole (idx %d, %.2f m off)" % [cs.kart.track_index, off])
		var last_id: int = gp.grid[7]
		_check(cs.karts[last_id].track_index == back_idx, "%s (8th) starts on the back row" % cs.RACER_NAMES[last_id])
		var slots := {}
		var overlap := false
		for k in cs.karts:
			for o in slots.values():
				if k.position.distance_to(o) < 3.5:
					overlap = true
			slots[k.kart_id] = k.position
		_check(not overlap and slots.size() == 8, "no two karts share a grid slot")
		# MK64 rank-out: five AI karts finish ahead of the player -> 6th -> no points, retry
		for i in range(1, 6):
			cs.karts[i].tracker.is_finished = true
			cs.karts[i].tracker.race_time = 40.0 + i
		cs.tracker.is_finished = true
		cs.tracker.race_time = 50.0
		t0 = Time.get_ticks_msec()
		stage = 5
		frames = 0
	elif stage == 5 and (cs.results_shown or Time.get_ticks_msec() - t0 > 6000):
		_check(cs.results_shown, "results shown after the delay")
		var txt: String = cs.hud.results_text
		_check("RANK OUT!  6th - finish 4th or better" in txt, "rank-out message: " + txt.replace("\n", " | "))
		_check("retry the race" in txt and not "next race" in txt, "retry prompt")
		_check(gp.retry and gp.last_rank == 6 and gp.race_index == 1, "cup flagged for a retry")
		_check(gp.totals == [9, 6, 3, 1, 0, 0, 0, 0], "nothing scored for the ranked-out race: %s" % str(gp.totals))
		_key(KEY_ENTER)
		stage = 6
		frames = 0
	elif stage == 6 and frames > 10:
		_check(cs.name == "Main", "retry scene loaded: " + cs.name)
		_check(gp.active and gp.race_index == 1 and lib.selected == 1 and not gp.retry and gp.retries == 1, "same race again (race_index %d, retries %d)" % [gp.race_index, gp.retries])
		_check(cs.hud.cup_label.text == "RACE 2 / 4  RETRY", "HUD cup label: " + cs.hud.cup_label.text)
		_check(gp.totals[0] == 9, "points untouched: %s" % str(gp.totals))
		_check(cs.kart.track_index == cs.track.data.count - 10 + 9, "retry keeps the grid of the race that counted (player on pole)")
		_key(KEY_ESCAPE)
		stage = 7
		frames = 0
	elif stage == 7 and frames > 10:
		_check(cs.name == "Menu", "Escape returns to menu")
		_check(not gp.active and gp.totals.is_empty() and gp.grid.is_empty() and gp.retries == 0, "Escape clears the cup")
		print("GP CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
