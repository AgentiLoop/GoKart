extends SceneTree
## Windowed render check of the false-start burnout (tire smoke, spinning wheels):
##   perl -e 'alarm 60; exec @ARGV' godot --path . -s tools/start_shot.gd
## Holds the throttle through the countdown and saves /tmp/gokart_false_start.png mid-stall.

var main
var shot := false

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	Input.action_press("accelerate")
	var k = main.kart
	if k.model.is_stalled() and k.model.stall_time < k.model.stall_duration * 0.5 and not shot:
		shot = true
		root.get_texture().get_image().save_png("/tmp/gokart_false_start.png")
		print("saved /tmp/gokart_false_start.png (smoke emitting: %s, wheel spin visible: %s)" % [k.effects.smoke[0].emitting, k.body_mesh.wheel_spins[0].rotation.x != 0.0])
	if shot and not k.model.is_stalled():
		print("start_shot: done, speed %.1f" % k.model.speed)
		quit(0)
		return true
	if Engine.get_physics_frames() > 900:
		print("start_shot: timed out")
		quit(1)
		return true
	return false
