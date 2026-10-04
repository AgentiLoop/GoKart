extends SceneTree
## Headless check of the Mario Kart 64 Battle mode flow: godot --headless --path . -s tools/battle_check.gd
## Menu -> G G G (Battle) -> D (Block Fort) -> Enter -> four karts with three balloons in the arena;
## after GO a rival is hit three times (balloons -> bomb kart), the bomb kart is parked beside the
## player and must explode (player loses a balloon, bomb kart out), then the last two rivals are
## knocked out so the player wins and the results panel appears; Esc -> menu remembers Battle.

var stage := 0
var frames := 0
var pf := 0
var ok := true
var t0 := 0

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _initialize() -> void:
	load("res://scripts/battle.gd").active = false
	load("res://scripts/battle.gd").arena = 0
	change_scene_to_file("res://scenes/menu.tscn")

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _finish(code: int) -> void:
	load("res://scripts/battle.gd").active = false
	print("BATTLE CHECK: ", "OK" if ok else "FAILED")
	quit(code)

func _process(_d: float) -> bool:
	frames += 1
	var battle = load("res://scripts/battle.gd")
	var items = load("res://scripts/items.gd")
	var cs := current_scene
	if cs == null or frames < 5:
		return false
	if stage == 0:
		_check(cs.name == "Menu", "menu scene loaded")
		_key(KEY_G)
		_key(KEY_G)
		_key(KEY_G)
		stage = 1
		frames = 0
	elif stage == 1 and frames > 3:
		_check(cs.mode == cs.MODE_BATTLE and "BATTLE" in cs.mode_label.text, "G G G selects Battle: " + cs.mode_label.text)
		_check(cs.sub_label.text == "SELECT ARENA" and cs.name_label.text == "Big Donut", "arena picker: " + cs.name_label.text)
		_check(cs.laps_label.text == "3" and cs.laps_caption.text == "BALLOONS", "balloons replace laps: " + cs.laps_label.text)
		_key(KEY_D)
		stage = 2
		frames = 0
	elif stage == 2 and frames > 3:
		_check(cs.arena_selected == 1 and cs.name_label.text == "Block Fort", "D picks Block Fort")
		_key(KEY_ENTER)
		stage = 3
		frames = 0
	elif stage == 3 and frames > 10:
		_check(cs.name == "BattleMain" and battle.active and battle.arena == 1, "battle scene loaded on Block Fort")
		_check(cs.karts.size() == 4, "four karts: %d" % cs.karts.size())
		var all3 := true
		for g in cs.gear:
			if g.visible_balloons() != 3 or g.bomb:
				all3 = false
		_check(all3 and cs.battle.balloons == [3, 3, 3, 3], "three balloons each")
		_check(cs.items.boxes.size() == cs.data.item_box_positions.size() and cs.items.boxes.size() >= 6, "%d item boxes" % cs.items.boxes.size())
		_check(cs.items.projectiles.is_empty(), "no pre-placed bananas")
		var battle_rolls := true
		for h in cs.items.holders:
			if not h.battle:
				battle_rolls = false
		_check(battle_rolls, "holders roll battle items only")
		_check(cs.hud.lap_label.text == "BALLOONS OOO" and cs.hud.cup_label.text == "BATTLE - Block Fort", "HUD: %s / %s" % [cs.hud.lap_label.text, cs.hud.cup_label.text])
		_check(cs.hud.place_label.text == "1st / 4", "place: " + cs.hud.place_label.text)
		_check(cs.lakitu.visible and cs.lakitu.mode == cs.lakitu.Mode.START, "Lakitu holds the start signal")
		_check(cs.arena.wall_count == 4 and cs.arena.block_count == 4, "walls and forts built")
		var ai_ok := true
		for i in range(1, 4):
			if cs.karts[i].driver == null or cs.karts[i].driver.get("arena") == null:
				ai_ok = false
		_check(ai_ok, "AI karts use the battle driver")
		var on_pads := true
		for i in 4:
			if cs.karts[i].position.distance_to(cs.data.spawns[i].position) > 0.5:
				on_pads = false
		_check(on_pads, "karts on their start pads")
		t0 = Time.get_ticks_msec()
		stage = 4
	elif stage == 4 and (cs.race_start.started or Time.get_ticks_msec() - t0 > 8000):
		_check(cs.race_start.started, "GO")
		pf = Engine.get_physics_frames()
		stage = 5
	elif stage == 5 and Engine.get_physics_frames() - pf > 60:
		var moved := 0
		for i in range(1, 4):
			if cs.karts[i].position.distance_to(cs.data.spawns[i].position) > 2.0:
				moved += 1
		_check(moved == 3, "AI karts drive after GO: %d/3" % moved)
		cs.items.kart_hit.emit(items.Type.SHELL, 1)
		_check(cs.battle.balloons[1] == 2 and cs.gear[1].visible_balloons() == 2, "a shell pops one of BLUE's balloons")
		_check(cs.audio.played.has("pop"), "pop sound")
		cs.items.kart_hit.emit(items.Type.BANANA, 1)
		cs.items.kart_hit.emit(items.Type.STAR, 1)
		_check(cs.battle.is_bomb(1) and cs.gear[1].bomb and cs.gear[1].visible_balloons() == 0, "third hit: BLUE is a Mini Bomb Kart")
		_check(cs.items.holders[1].locked and cs.items.holders[1].held == items.Type.NONE, "bomb karts hold no items")
		_check(cs.karts[1].body_mesh.materials[0].albedo_color.a == 0.0, "kart body hidden under the bomb")
		_check(cs.hud.place_label.text == "1st / 4" and cs.battle.rank_of(1) == 4, "standings updated")
		# park the bomb kart beside the player
		cs.karts[1].position = cs.kart.position + Vector3(1.0, 0, 0)
		pf = Engine.get_physics_frames()
		stage = 6
	elif stage == 6 and Engine.get_physics_frames() - pf > 10:
		_check(cs.battle.is_out(1) and not cs.karts[1].visible, "bomb kart exploded on the player and is out")
		_check(cs.battle.balloons[0] == 2 and cs.gear[0].visible_balloons() == 2, "player lost a balloon: %d" % cs.battle.balloons[0])
		_check(cs.hud.lap_label.text == "BALLOONS OO", "HUD: " + cs.hud.lap_label.text)
		_check(cs.audio.played.has("explosion") and not cs.blasts.is_empty(), "explosion sound + blast visual")
		_check(cs.hud.update_minimap != null and cs.hud.minimap.marker_positions.size() == 3, "minimap drops the exploded kart: %d markers" % cs.hud.minimap.marker_positions.size())
		for id in [2, 3]:
			for i in 3:
				cs.items.kart_hit.emit(items.Type.SHELL, id)
		_check(cs.battle.over and cs.battle.winner == 0, "last balloon kart standing: the player wins")
		t0 = Time.get_ticks_msec()
		frames = 0
		stage = 7
	elif stage == 7 and frames > 3:
		# before the results board the centre banner says YOU WIN!; the board then owns the centre
		_check(cs.hud.banner_label.text == "YOU WIN!" and not cs.results_shown, "banner before the results: " + cs.hud.banner_label.text)
		stage = 8
	elif stage == 8 and (cs.results_shown or Time.get_ticks_msec() - t0 > 8000):
		_check(cs.results_shown, "results shown after the delay")
		var txt: String = cs.hud.results_text
		_check(txt.begins_with("BATTLE - Block Fort\nYOU WIN!"), "panel: " + txt.split("\n")[1])
		_check("> 1st  YOU      2 balloons" in txt and "  4th  BLUE     exploded" in txt, txt)
		_check(cs.hud.banner_label.text == "", "the results board owns the centre: no banner")
		_check(cs.audio.played.has("finish"), "finish jingle")
		_key(KEY_ESCAPE)
		stage = 9
		frames = 0
	elif stage == 9 and frames > 10:
		_check(cs.name == "Menu" and cs.mode == cs.MODE_BATTLE and cs.arena_selected == 1, "Escape returns to the menu with Battle / Block Fort still selected")
		_finish(0 if ok else 1)
	return false
