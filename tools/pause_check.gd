extends SceneTree
## Headless check of the Mario Kart 64 style pause screen: godot --headless --path . -s tools/pause_check.gd
## Title -> select screen -> race; Esc freezes the race under the pause panel (tree paused, the kart
## stays put, the HUD's clock stops), Up / Down move the cursor with a tick, Esc resumes, CONTINUE
## resumes, RETRY restarts the race (with its intro), COURSE CHANGE goes back to the select screen,
## QUIT to the title screen; the battle scene pauses the same way; Esc on the results board still
## goes straight back to the menu (battle_check covers that path).

const CourseIntro := preload("res://scripts/course_intro.gd")

var stage := 0
var frames := 0
var ok := true
var pos0 := Vector3.ZERO
var time0 := 0.0
var t0 := 0

## Headless frames run far faster than real time: waits that depend on the clock (the pop, the
## kart moving on) count milliseconds instead of frames.
func _ms() -> int:
	return Time.get_ticks_msec() - t0

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.selected = 0
	load("res://scripts/menu.gd").title_seen = false
	change_scene_to_file("res://scenes/menu.tscn")

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _finish() -> void:
	print("PAUSE CHECK: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)

func _process(_d: float) -> bool:
	frames += 1
	var cs := current_scene
	if cs == null or frames < 5:
		return false
	if stage == 0:
		_check(cs.name == "Menu" and cs.title_shown, "title screen first")
		_key(KEY_ENTER)
		stage = 1
		frames = 0
	elif stage == 1 and frames > 3:
		_check(not cs.title_shown and cs.select_box.visible, "select screen")
		_key(KEY_ENTER)
		stage = 2
		frames = 0
	elif stage == 2 and frames > 10:
		_check(cs.name == "Main", "race scene loaded")
		cs._end_intro()
		_check(cs.pause != null and not cs.pause.visible and not cs.pause.shown and not paused, "pause panel hidden, tree running")
		_check(cs.pause.layer > cs.hud.layer and cs.pause.process_mode == Node.PROCESS_MODE_ALWAYS, "pause layer over the HUD and runs while paused")
		Input.action_press("accelerate")
		stage = 3
		frames = 0
	elif stage == 3 and cs.race_start.started and cs.kart.model.speed > 5.0:
		_check(true, "racing at %.1f m/s" % cs.kart.model.speed)
		pos0 = cs.kart.global_position
		time0 = cs.race_start.since_go
		_key(KEY_ESCAPE)
		stage = 4
		t0 = Time.get_ticks_msec()
	elif stage == 4 and _ms() > 500:
		_check(paused and cs.pause.shown and cs.pause.visible, "Esc pauses the tree under the panel")
		_check(cs.name == "Main", "still the race scene (no quit): " + cs.name)
		_check(cs.kart.global_position.distance_to(pos0) < 0.5, "the kart stays put while paused (%.2f m)" % cs.kart.global_position.distance_to(pos0))
		_check(is_equal_approx(cs.race_start.since_go, time0), "the race clock stops: %.3f" % cs.race_start.since_go)
		_check(cs.pause.cursor == cs.pause.CONTINUE and cs.pause.played == ["pause"], "cursor on CONTINUE, pause sound: %s" % str(cs.pause.played))
		_check(cs.pause.rows[0].text == "CONTINUE" and cs.pause.rows[3].text == "QUIT" and cs.pause.title.text == "PAUSE", "panel lines")
		_check(cs.pause.rows[0].get_theme_color("font_color") == cs.pause.UiStyle.GOLD and cs.pause.rows[1].get_theme_color("font_color") == cs.pause.UiStyle.CREAM, "picked line gold, the rest cream")
		_check(cs.pause.rows[0].get_theme_constant("outline_size") == 0 and cs.pause.hint.get_theme_constant("outline_size") == 0, "no outlines on the lines / hint")
		_check(is_equal_approx(cs.pause.panel.scale.x, 1.0) and is_equal_approx(cs.pause.panel.modulate.a, 1.0), "panel landed (scale %.2f)" % cs.pause.panel.scale.x)
		_check(not cs.audio.music.playing or cs.audio.music.stream_paused, "course music paused with the race")
		_key(KEY_S)
		stage = 5
		frames = 0
	elif stage == 5 and frames > 3:
		_check(cs.pause.cursor == cs.pause.RETRY and cs.pause.played[-1] == "cursor", "Down moves the cursor to RETRY with a tick")
		_check(cs.pause.bar.position.y > cs.pause.rows[0].position.y + 10.0, "the lit bar followed the cursor")
		_key(KEY_W)
		_key(KEY_W)
		stage = 6
		frames = 0
	elif stage == 6 and frames > 3:
		_check(cs.pause.cursor == cs.pause.QUIT, "Up twice wraps round to QUIT")
		_key(KEY_ESCAPE)
		stage = 7
		t0 = Time.get_ticks_msec()
	elif stage == 7 and _ms() > 500:
		_check(not paused and not cs.pause.shown and not cs.pause.visible, "Esc again resumes")
		_check(cs.pause.played[-1] == "resume", "resume sound: %s" % str(cs.pause.played))
		_check(cs.kart.global_position.distance_to(pos0) > 1.0 and cs.race_start.since_go > time0, "the race goes on where it stopped (moved %.2f m, clock %.3f -> %.3f)" % [cs.kart.global_position.distance_to(pos0), time0, cs.race_start.since_go])
		_key(KEY_ESCAPE)
		stage = 8
		frames = 0
	elif stage == 8 and frames > 3:
		_check(paused and cs.pause.cursor == cs.pause.CONTINUE, "paused again, cursor back on CONTINUE")
		_key(KEY_ENTER)
		stage = 9
		frames = 0
	elif stage == 9 and frames > 3:
		_check(not paused and cs.pause.picked == cs.pause.CONTINUE, "Enter on CONTINUE resumes")
		Input.action_release("accelerate")   # a held throttle would skip the retry's intro
		_key(KEY_ESCAPE)
		_key(KEY_S)
		_key(KEY_ENTER)
		stage = 10
		frames = 0
	elif stage == 10 and frames > 10:
		_check(cs.name == "Main" and not paused, "RETRY: the race scene again, running")
		_check(cs.intro_t >= 0.0 and cs.hud.intro_box.visible, "...from its course intro")
		_check(cs.pause.played.is_empty() and not cs.pause.shown, "a fresh pause panel")
		cs._end_intro()
		_key(KEY_ESCAPE)
		_key(KEY_S)
		_key(KEY_S)
		_key(KEY_ENTER)
		stage = 11
		frames = 0
	elif stage == 11 and frames > 10:
		_check(cs.name == "Menu" and not paused, "COURSE CHANGE: back to the menu, running")
		_check(not cs.title_shown and cs.select_box.visible, "...on the select screen")
		_check(get_nodes_in_group("menu_audio_out").size() >= 0 and root.get_child_count() >= 2, "the chime's voice was handed to the root")
		_key(KEY_ENTER)
		stage = 12
		frames = 0
	elif stage == 12 and frames > 10:
		_check(cs.name == "Main", "race scene loaded again")
		cs._end_intro()
		_key(KEY_ESCAPE)
		_key(KEY_S)
		_key(KEY_S)
		_key(KEY_S)
		_key(KEY_ENTER)
		stage = 13
		frames = 0
	elif stage == 13 and frames > 10:
		_check(cs.name == "Menu" and not paused, "QUIT: back to the menu, running")
		_check(cs.title_shown and not cs.select_box.visible, "...on the title screen")
		_key(KEY_ENTER)
		stage = 14
		frames = 0
	elif stage == 14 and frames > 3:
		_key(KEY_G)
		_key(KEY_G)
		_key(KEY_G)
		stage = 15
		frames = 0
	elif stage == 15 and frames > 3:
		_check(cs.mode == cs.MODE_BATTLE, "G x3: battle mode")
		_key(KEY_ENTER)
		stage = 16
		frames = 0
	elif stage == 16 and frames > 10:
		_check(cs.name == "BattleMain" and cs.pause != null, "battle scene with a pause panel: " + cs.name)
		_key(KEY_ESCAPE)
		stage = 17
		frames = 0
	elif stage == 17 and frames > 5:
		_check(paused and cs.pause.shown, "Esc pauses the battle")
		_key(KEY_S)
		_key(KEY_S)
		_key(KEY_ENTER)
		stage = 18
		frames = 0
	elif stage == 18 and frames > 10:
		_check(cs.name == "Menu" and not paused and cs.mode == cs.MODE_BATTLE, "COURSE CHANGE from the battle: the select screen in battle mode")
		_finish()
	return false
