extends SceneTree
## Headless check of the Mario Kart 64 rocket start / false start:
##   perl -e 'alarm 90; exec @ARGV' godot --headless --path . -s tools/start_check.gd
## Run A: the throttle is held through the whole countdown -> at GO the kart stalls (burnout: speed 0,
## tire smoke, "burnout" sound, engine revving) for STALL_TIME, then drives off.
## Run B: the throttle is pressed inside the boost window -> rocket start, no stall.
## Run C: battle scene, greedy throttle -> the same stall.

var main
var stage := 0
var frames := 0
var ok := true
var go_frame := -1
var stall_frames := 0
var run := "A"

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + "[%s] %s" % [run, msg])
	if not cond:
		ok = false

func _start(scene: String) -> void:
	load("res://scripts/track_library.gd").selected = 0
	if main != null:
		root.remove_child(main)
		main.free()
	main = load(scene).instantiate()
	root.add_child(main)
	stage = 0
	frames = 0
	go_frame = -1
	stall_frames = 0

func _initialize() -> void:
	Input.action_release("accelerate")
	_start("res://scenes/main.tscn")

func _physics_process(_d: float) -> bool:
	frames += 1
	var k = main.kart
	var rs = main.race_start
	if run == "A" or run == "C":
		Input.action_press("accelerate")   # greedy: held from the first frame
	else:
		if rs.remaining <= 0.4 and not rs.started:
			Input.action_press("accelerate")
	if stage == 0 and rs.started:
		go_frame = frames
		stage = 1
		if run == "B":
			_check(not rs.false_start(), "press in the window is not a false start")
			_check(k.model.is_boosting() and not k.model.is_stalled(), "rocket start boost at GO")
		else:
			_check(rs.false_start(), "throttle held all countdown -> false start")
			_check(k.model.is_stalled(), "kart stalled at GO")
			_check(not k.model.is_boosting(), "no start boost")
			_check("burnout" in main.audio.played, "burnout sound played")
	elif stage == 1:
		if k.model.is_stalled():
			stall_frames += 1
			if stall_frames == 10:
				_check(k.model.speed == 0.0 and k.velocity.length() < 0.01, "kart does not move while stalled")
				_check(k.effects.smoke[0].emitting, "tire smoke while stalled")
				_check(main.audio.engine.pitch_scale > 2.0, "engine revs flat out: %.2f" % main.audio.engine.pitch_scale)
		elif frames - go_frame > stall_frames + 25:
			stage = 2
			if run == "B":
				_check(stall_frames == 0, "never stalled")
			else:
				var expected: int = int(round(k.model.stall_duration * 60.0))
				_check(absi(stall_frames - expected) <= 2, "stalled %d frames (expected ~%d)" % [stall_frames, expected])
				_check(not k.effects.smoke[0].emitting, "smoke stops after the stall")
			_check(k.model.speed > 3.0, "drives off afterwards: %.1f m/s" % k.model.speed)
	elif stage == 2:
		Input.action_release("accelerate")
		if run == "A":
			run = "B"
			_start("res://scenes/main.tscn")
		elif run == "B":
			run = "C"
			load("res://scripts/battle.gd").arena = 1
			_start("res://scenes/battle.tscn")
		else:
			print("start_check: " + ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	if frames > 1200:
		print("FAIL [%s] timed out at stage %d" % [run, stage])
		quit(1)
		return true
	return false
