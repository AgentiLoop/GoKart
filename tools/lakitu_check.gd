extends SceneTree
## Headless check of MK64 Lakitu: godot --headless --path . -s tools/lakitu_check.gd
## Menu -> Enter: during the countdown Lakitu hovers ahead of the player holding the start signal
## (lamps red, red, blue at GO), then flies off. After GO the player is dropped into the water beside
## the first open stretch: splash, Lakitu fishes the kart out (line down, kart lifted, set down on the
## centreline facing along the track, speed zero), then the kart drives on. Turning the kart around
## brings out the flashing REVERSE sign; turning back hides it. Esc returns to the menu.

var stage := 0
var frames := 0
var ok := true
var phys0 := 0
var lamps_seen := {}
var lift_peak := 0.0
var line_seen := false
var fell_at := Vector3.ZERO
var fell_idx := 0

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	change_scene_to_file("res://scenes/menu.tscn")

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

func _lit(l) -> int:
	var n := 0
	for lamp in l._lamps:
		if (lamp.material_override as StandardMaterial3D).emission_enabled:
			n += 1
	return n

func _process(_d: float) -> bool:
	frames += 1
	var cs := current_scene
	if cs == null or frames < 5:
		return false
	var L = load("res://scripts/lakitu.gd")
	if stage == 0:
		_check(cs.name == "Menu", "menu scene loaded")
		_key(KEY_ENTER)   # leaves the title screen
		_key(KEY_ENTER)   # starts the race
		stage = 1
		frames = 0
	elif stage == 1 and frames > 10:
		_check(cs.name == "Main", "race scene loaded: " + cs.name)
		_check(cs.lakitu != null and cs.lakitu.visible and cs.lakitu.mode == L.Mode.START, "Lakitu out with the start signal during the countdown")
		_check(cs.track.get_node_or_null("Water") != null, "water built on the course")
		var data = cs.track.data
		_check(data.water.size() >= 1 and cs.track.get_node("Walls").get_child_count() < 2 * data.count, "walls have gaps along the water")
		stage = 2
		phys0 = Engine.get_physics_frames()
	elif stage == 2:
		if cs.lakitu.mode == L.Mode.START:
			lamps_seen[_lit(cs.lakitu)] = true
		if cs.race_start.started and cs.race_start.since_go > L.SIGNAL_HOLD + 0.3:
			_check(lamps_seen.has(0) and lamps_seen.has(1) and lamps_seen.has(2) and lamps_seen.has(3), "lamps lit one by one: %s" % str(lamps_seen.keys()))
			_check(cs.lakitu.mode == L.Mode.HIDDEN and not cs.lakitu.visible, "Lakitu leaves after GO")
			Input.action_press("accelerate")
			stage = 3
			phys0 = Engine.get_physics_frames()
	elif stage == 3:
		_steer(cs)
		if Engine.get_physics_frames() - phys0 > 120:
			# drop the player into the water beside the middle of the first open stretch
			var data = cs.track.data
			var w: Dictionary = data.water[0]
			fell_idx = (w.start + w.end) / 2
			var edge: float = data.width * 0.5 + data.WATER_EDGE
			fell_at = data.points[fell_idx] + data.right_of(fell_idx) * w.side * (edge + 3.0) + Vector3(0, 0.1, 0)
			cs.kart.global_position = fell_at
			cs.kart.track_index = fell_idx
			_check(cs.kart.model.speed > 5.0, "player was moving before the dunk: %f" % cs.kart.model.speed)
			_check(not cs.audio.played.has("splash"), "no splash yet")
			stage = 4
			phys0 = Engine.get_physics_frames()
	elif stage == 4:
		var pf := Engine.get_physics_frames() - phys0
		if cs.kart.is_rescued():
			lift_peak = maxf(lift_peak, cs.kart.global_position.y)
			if cs.lakitu.mode == L.Mode.RESCUE and cs.lakitu._line.visible:
				line_seen = true
		if pf > 5 and not cs.kart.is_rescued() and lift_peak > 0.0:
			var data = cs.track.data
			_check(cs.kart.rescues == 1, "Lakitu fished the player out once (%d)" % cs.kart.rescues)
			_check(cs.audio.played.has("splash"), "splash sound played")
			_check(line_seen, "Lakitu hung above the kart with the line down")
			_check(lift_peak > 3.0, "kart lifted out of the water: peak y %f" % lift_peak)
			var drop: Vector3 = data.rescue_point(fell_idx)
			var dist := Vector2(cs.kart.global_position.x - drop.x, cs.kart.global_position.z - drop.z).length()
			_check(dist < 3.0, "set down on the centreline (%.1f m from the drop point)" % dist)
			_check(absf(wrapf(cs.kart.heading - data.heading_at(fell_idx), -PI, PI)) < 0.2, "facing along the track")
			_check(cs.kart.model.speed < 8.0, "speed was zeroed by the dunk: %f" % cs.kart.model.speed)
			_check(cs.kart.global_position.y < 1.0, "back on the road")
			stage = 5
			phys0 = Engine.get_physics_frames()
		elif pf > 400:
			_check(false, "rescue never completed (rescued=%s peak=%f)" % [str(cs.kart.is_rescued()), lift_peak])
			stage = 5
			phys0 = Engine.get_physics_frames()
	elif stage == 5:
		_steer(cs)
		if Engine.get_physics_frames() - phys0 > 90:
			_check(cs.kart.model.speed > 10.0, "driving again after the rescue: %f" % cs.kart.model.speed)
			_check(cs.lakitu.mode == L.Mode.HIDDEN, "Lakitu gone again")
			# turn the kart around and keep driving: REVERSE
			Input.action_release("steer_left")
			Input.action_release("steer_right")
			cs.kart.heading += PI
			stage = 6
			phys0 = Engine.get_physics_frames()
	elif stage == 6:
		var pf := Engine.get_physics_frames() - phys0
		if cs.lakitu.mode == L.Mode.REVERSE:
			_check(pf >= 50, "REVERSE sign after about a second (%d physics frames)" % pf)
			_check(cs.lakitu.visible and cs.lakitu._sign_label.text == "REVERSE", "Lakitu holds the REVERSE sign")
			cs.kart.heading += PI
			stage = 7
			phys0 = Engine.get_physics_frames()
		elif pf > 300:
			_check(false, "REVERSE sign never shown (mode %d, speed %f)" % [cs.lakitu.mode, cs.kart.model.speed])
			stage = 7
			phys0 = Engine.get_physics_frames()
	elif stage == 7:
		_steer(cs)
		if Engine.get_physics_frames() - phys0 > 30:
			_check(cs.lakitu.mode == L.Mode.HIDDEN, "sign put away once the kart faces the right way")
			Input.action_release("accelerate")
			_key(KEY_ESCAPE)
			stage = 8
			frames = 0
	elif stage == 8 and frames > 10:
		_check(cs.name == "Menu", "Escape returns to menu")
		print("LAKITU CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
