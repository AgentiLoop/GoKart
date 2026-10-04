extends SceneTree
## Headless check of the Mario Kart 64 powerslide mini-turbo:
##   perl -e 'alarm 120; exec @ARGV' godot --headless --path . -s tools/drift_check.gd
## After GO the player is set on the left side of the Green Hills road at 16 m/s (throttle off) and hops
## into a right-hand slide (the kart leaves the ground), holds it steady (white smoke, no charge), toggles
## the stick left / right once (yellow smoke, HUD "MINI-TURBO...") and releases: no boost. A second slide
## is toggled twice (red smoke, "MINI-TURBO!") and released: a mini-turbo boost with the red flash.

var main
var frames := 0
var ok := true
var stage := 0
var mark := 0
var slide := 1            # 1 = the yellow slide, 2 = the red slide
var toggles := 0
var hop_y := 0.0
var left_ground := false
var released_frame := 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _steer() -> void:
	var k = main.kart
	var t = main.track.data
	var target: Vector3 = t.points[(main.kart_index + 8) % t.count]
	var d: Vector3 = target - k.global_position
	var want := atan2(-d.x, -d.z)
	var err := wrapf(want - k.heading, -PI, PI)
	var s := clampf(-err * 2.5, -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if s > 0.0:
		Input.action_press("steer_right", s)
	else:
		Input.action_press("steer_left", -s)

func _press(right: bool, strength := 1.0) -> void:
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_press("steer_right" if right else "steer_left", strength)

## Sets the kart on the left side of the road 2 samples ahead, rolling at 16 m/s, and hops into a right slide.
func _place_and_slide() -> void:
	var k = main.kart
	var t = main.track.data
	var i: int = (main.kart_index + 2) % t.count
	var h: float = t.heading_at(i)
	k.global_position = t.points[i] + Vector3(-cos(h), 0, sin(h)) * 5.0
	k.heading = h
	k.rotation.y = h
	k.velocity = Vector3.ZERO
	k.model.speed = 16.0
	Input.action_release("accelerate")
	_press(true)
	Input.action_press("drift")
	hop_y = 0.0
	mark = frames

func _finish() -> void:
	Input.action_release("accelerate")
	Input.action_release("drift")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	print("DRIFT CHECK: " + ("OK" if ok else "FAILED"))
	quit(0 if ok else 1)

func _physics_process(_d: float) -> bool:
	frames += 1
	if frames > 2400:
		_check(false, "timed out at stage %d" % stage)
		_finish()
		return true
	var k = main.kart
	var m = k.model
	var fx = k.effects
	if stage == 0 or stage == 4:
		if main.race_start.started and frames > mark + 10:
			Input.action_press("accelerate")   # after GO: no rocket start boost to confuse the checks
	if stage == 0:
		_steer()
		if main.race_start.started and mark == 0:
			mark = frames
		if main.race_start.started and frames > mark + 30 and not m.is_boosting():
			_check(main.hud.state_label.text == "", "no HUD state before the slide")
			_place_and_slide()
			stage = 1
	elif stage == 1:
		# the eased steering takes a few frames to pass the drift threshold
		if not m.drifting:
			if frames > mark + 15:
				_check(false, "slide never started")
				_finish()
				return true
			return false
		if hop_y == 0.0:
			hop_y = k.global_position.y
			_press(false)   # steer out of the slide for the widest arc (the bend is gentle)
		if k.global_position.y > hop_y + 0.1:
			left_ground = true
		if frames == mark + 24:
			_check(m.drift_direction == 1, "slide started to the right")
			_check(left_ground, "the kart hopped into the slide (left the ground)")
			_check(k.is_on_floor(), "and landed again")
			_check(m.drift_level == 0 and m.drift_charge == 0.0, "a steady slide stays white: level %d" % m.drift_level)
			_check((fx.sparks[0].process_material as ParticleProcessMaterial).color == fx.SPARK_COLORS[0], "white smoke")
			toggles = 0
			stage = 2
			mark = frames
	elif stage == 2:
		# toggle: 8 frames against the slide, 8 frames back in (the eased steering needs ~7 frames to swing)
		var t := frames - mark
		if t % 16 < 8:
			_press(false)
		else:
			_press(true, 0.6)   # back in, not too tight
		if t % 16 == 3 and toggles > 0:
			var lvl := mini(toggles, 2)
			_check(main.hud.state_label.text == ["", "MINI-TURBO...", "MINI-TURBO!"][lvl], "HUD says '%s' at level %d" % [main.hud.state_label.text, lvl])
		if t % 16 == 15:
			toggles += 1
			var want_level := mini(toggles, 2)
			_check(m.drifting and m.drift_level == want_level, "toggle %d -> level %d (got %d)" % [toggles, want_level, m.drift_level])
			_check((fx.sparks[0].process_material as ParticleProcessMaterial).color == fx.SPARK_COLORS[want_level], "smoke colour of level %d" % want_level)
			if toggles == slide:
				_press(false)
				Input.action_release("drift")
				released_frame = frames
				stage = 3
	elif stage == 3 and frames == released_frame + 2:
		_check(not m.drifting, "slide released")
		if slide == 1:
			_check(not m.is_boosting(), "yellow smoke: no mini-turbo (MK64)")
			_check(fx.flash_amount == 0.0, "no flash")
			_check(not fx.flames[0].emitting, "no flames")
			slide = 2
			stage = 4
			mark = frames
		else:
			_check(m.is_boosting() and m.boost_from_drift and m.boost_level == 2, "red smoke: mini-turbo boost")
			_check(fx.flames[0].emitting and (fx.flames[0].process_material as ParticleProcessMaterial).color == fx.FLAME_COLORS[2], "red flames")
			_check(fx.flash_amount > 0.5 and fx.flash_color == fx.SPARK_COLORS[2], "red flash")
			_check("boost" in main.audio.played and "mini_turbo" in main.audio.played and "drift_start" in main.audio.played, "hop, mini-turbo and boost sounds")
			_finish()
			return true
	elif stage == 4:
		_steer()
		if frames >= mark + 30:
			_place_and_slide()
			stage = 5
	elif stage == 5:
		if m.drifting and hop_y == 0.0:
			hop_y = k.global_position.y
			_press(false)
		if frames == mark + 10:
			_check(m.drifting and m.drift_level == 0, "second slide starts white")
			_check(k.global_position.y > 0.05, "second hop: y %.2f" % k.global_position.y)
			toggles = 0
			stage = 2
			mark = frames
	return false
