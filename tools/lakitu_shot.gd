extends SceneTree
## Windowed: godot --path . -s tools/lakitu_shot.gd
## -> /tmp/gokart_lakitu_start.png (Lakitu with the start signal), /tmp/gokart_lakitu_water.png
## (the open road edge and the water), /tmp/gokart_lakitu_rescue.png (kart on the line) and
## /tmp/gokart_lakitu_reverse.png (the REVERSE sign).
var f := 0
var main
func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/gokart_%s.png" % n)
func _process(_d: float) -> bool:
	f += 1
	var data = main.track.data
	if f == 90:
		_shot("lakitu_start")
	elif f == 260:
		# park the player at the start of the first open stretch, looking along it
		var w: Dictionary = data.water[0]
		var i: int = w.start + 2
		main.kart.global_position = data.points[i] + data.right_of(i) * w.side * 4.0 + Vector3(0, 0.1, 0)
		main.kart.heading = data.heading_at(i)
		main.kart.track_index = i
		main.cam.global_position = main.kart.global_position + Vector3(sin(main.kart.heading), 0, cos(main.kart.heading)) * 6.0 + Vector3(0, 3, 0)
		Input.action_press("accelerate")
	elif f == 320:
		_shot("lakitu_water")
		var w: Dictionary = data.water[0]
		var i: int = (w.start + w.end) / 2
		main.kart.global_position = data.points[i] + data.right_of(i) * w.side * (data.width * 0.5 + data.WATER_EDGE + 3.0) + Vector3(0, 0.1, 0)
		main.kart.track_index = i
	elif f == 400:
		_shot("lakitu_rescue")
	elif f == 560:
		main.kart.heading += PI
	elif f == 660:
		_shot("lakitu_reverse")
		quit(0)
	return false
