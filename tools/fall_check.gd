extends SceneTree
## Headless check: godot --headless --path . -s tools/fall_check.gd
## A kart pushed through the ground (seen online when another player's kart lands on top of yours)
## used to fall forever. After GO the player is put 2 m under the road: it falls, and once it is
## below FELL_THROUGH_Y Lakitu fishes it out and sets it back on the road.

var frames := 0
var stage := 0
var phys0 := 0
var lowest := 0.0
var ok := true

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	ok = ok and cond

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	change_scene_to_file("res://scenes/main.tscn")

func _process(_d: float) -> bool:
	frames += 1
	var cs := current_scene
	if cs == null or frames < 5 or cs.get("race_start") == null:
		return false
	if stage == 0 and cs.race_start.started:
		cs.kart.global_position += Vector3(0, -2.0, 0)
		stage = 1
		phys0 = Engine.get_physics_frames()
	elif stage == 1:
		lowest = minf(lowest, cs.kart.global_position.y)
		var pf := Engine.get_physics_frames() - phys0
		if cs.kart.rescues > 0 and not cs.kart.is_rescued():
			_check(lowest < cs.FELL_THROUGH_Y and lowest > cs.FELL_THROUGH_Y - 5.0, "fell to %.1f m before the rescue" % lowest)
			_check(cs.kart.rescues == 1, "rescued once (%d)" % cs.kart.rescues)
			_check(absf(cs.kart.global_position.y) < 1.0, "back on the road: y %.2f" % cs.kart.global_position.y)
			stage = 2
		elif pf > 900:
			_check(false, "never rescued: y %.1f" % cs.kart.global_position.y)
			stage = 2
	if stage == 2:
		print("FALL CHECK: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
