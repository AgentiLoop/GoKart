extends SceneTree
## Windowed: godot --path . -s tools/ice_shot.gd
## -> /tmp/gokart_ice.png (the player a few metres into the icy sweeper on Frosty Peaks, the ice ribbon
## under and ahead of it) and /tmp/gokart_ice_slide.png (sliding through it with the wheel turned). Samples the road
## ahead in both the ice shot and a tarmac shot (/tmp/gokart_ice_tarmac.png) and prints the colours:
## the ice reads pale blue-white, the tarmac dark grey.
var f := 0
var main
var ice_col := Color.BLACK
var road_col := Color.BLACK
func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 2
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _shot(n: String) -> Image:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/gokart_%s.png" % n)
	return img
## Average colour of a patch of road beside the kart (bottom left of the frame, clear of the HUD).
func _road_sample(img: Image) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var sum := Color.BLACK
	var n := 0
	for y in range(int(h * 0.80), int(h * 0.95)):
		for x in range(int(w * 0.05), int(w * 0.20)):
			sum += img.get_pixel(x, y)
			n += 1
	return sum / n
func _place(pos: Vector3, idx: int, speed: float) -> void:
	main.kart.global_position = pos + Vector3(0, 0.1, 0)
	main.kart.heading = main.track.data.heading_at(idx)
	main.kart.rotation.y = main.kart.heading
	main.kart.track_index = idx
	main.kart.model.speed = speed
	main.kart.model.slide = 0.0
	main.cam.global_position = main.kart.global_position + Vector3(sin(main.kart.heading), 0, cos(main.kart.heading)) * 6.0 + Vector3(0, 3, 0)
func _process(_d: float) -> bool:
	var data = main.track.data
	if not main.race_start.started:
		return false
	f += 1
	if f == 90:
		for i in range(1, main.karts.size()):
			main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.karts[i].frozen = true
		main.kart.frozen = true
		# the opening straight: plain tarmac ahead
		_place(data.points[10], 10, 0.0)
	elif f == 130:
		road_col = _road_sample(_shot("ice_tarmac"))
		var s: Dictionary = data.ice[1]
		_place(data.points[s.start + 3], s.start + 3, 0.0)
	elif f == 170:
		ice_col = _road_sample(_shot("ice"))
		print("road ahead: tarmac (%.2f %.2f %.2f) ice (%.2f %.2f %.2f)" % [road_col.r, road_col.g, road_col.b, ice_col.r, ice_col.g, ice_col.b])
		print("ICE SHOT: ", "OK" if ice_col.b > road_col.b + 0.3 and ice_col.b >= ice_col.r else "FAILED")
		# slide through it: unfrozen, at speed, wheel turned
		var s: Dictionary = data.ice[1]
		main.kart.frozen = false
		_place(data.points[s.start + 2], s.start + 2, 28.0)
		Input.action_press("accelerate")
		Input.action_press("steer_right")
	elif f == 188:
		_shot("ice_slide")
		print("slide %.2f rad" % main.kart.model.slide)
		Input.action_release("steer_right")
		Input.action_release("accelerate")
		quit(0)
	return false
