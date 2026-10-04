extends SceneTree
## Windowed: godot --path . -s tools/snowman_shot.gd
## -> /tmp/gokart_snowmen.png (the player at the entrance of the snowman field on Frosty Peaks) and
## /tmp/gokart_snowman_hit.png (thrown into the air by a snowman as it bursts).
var f := 0
var main
func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 2
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/gokart_%s.png" % n)
func _place(pos: Vector3, idx: int) -> void:
	main.kart.global_position = pos + Vector3(0, 0.1, 0)
	main.kart.heading = main.track.data.heading_at(idx)
	main.kart.rotation.y = main.kart.heading
	main.kart.track_index = idx
	main.cam.global_position = main.kart.global_position + Vector3(sin(main.kart.heading), 0, cos(main.kart.heading)) * 6.0 + Vector3(0, 3, 0)
func _process(_d: float) -> bool:
	f += 1
	var data = main.track.data
	var sn = main.snowmen
	if f == 260:
		# the player 15 m before the field's first row, the five rows ahead
		var sm: Dictionary = sn.snowmen[2]
		var idx: int = posmod(sm.idx - 5, data.count)
		_place(data.points[idx], idx)
		for i in range(1, main.karts.size()):
			main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.karts[i].frozen = true
	elif f == 300:
		_shot("snowmen")
		var sm: Dictionary = sn.snowmen[3]
		_place(sm.pos - data.tangents[sm.idx] * 0.6, sm.idx)
	elif f == 312:
		_shot("snowman_hit")
		quit(0)
	return false
