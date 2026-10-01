extends SceneTree
## Windowed visual check: godot --path . -s tools/screenshot.gd  -> /tmp/gokart_*.png
## Drives the kart (accelerate, drift-right, release for boost) and saves screenshots.

var frame := 0
var main: Node

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	frame += 1
	if frame == 1:
		Input.action_press("accelerate")
	if frame == 150:
		Input.action_press("steer_right")
		Input.action_press("drift")
	if frame == 160:
		_shot("drift")
	if frame == 330:
		Input.action_release("drift")
	if frame == 345:
		_shot("boost")
	if frame == 360:
		return true
	return false

func _shot(n: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("/tmp/gokart_%s.png" % n)
	print("saved ", n, " boosting=", main.kart.model.is_boosting(), " drift=", main.kart.model.drifting, " lvl=", main.kart.model.drift_level)
