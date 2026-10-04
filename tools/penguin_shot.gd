extends SceneTree
## Windowed: godot --path . -s tools/penguin_shot.gd
## -> /tmp/gokart_penguins.png (the player 12 m before the icy sweeper's first penguin as it slides
## across the road on its belly, the second penguin waddling at the far edge behind it) and
## /tmp/gokart_penguin_hit.png (spun round by the penguin).
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
	var pg = main.penguins
	if f == 260:
		# the player 12 m before the sweeper's first run; that penguin slides through the centre in
		# half a second, the next one is just setting out from its edge
		var p: Dictionary = pg.penguins[1]
		var idx: int = posmod(p.idx - 4, data.count)
		_place(data.points[idx], idx)
		for i in range(1, main.karts.size()):
			main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.karts[i].frozen = true
		pg.penguins[1].t += pg.time_until_centre(1) - 1.0
		pg.penguins[2].t += pg.time_until_centre(2) + 1.25 - 1.0
	elif f == 316:
		main.rookery.visible = false   # the same view without the penguins, to pixel-diff against
	elif f == 318:
		_shot("penguins_none")
		main.rookery.visible = true
	elif f == 320:
		_shot("penguins")
		var p: Dictionary = pg.penguins[1]
		main.kart.frozen = false
		_place(data.points[p.idx], p.idx)
		pg.penguins[1].t += pg.time_until_centre(1) - 0.3
	elif f == 360:
		_shot("penguin_hit")
		quit(0)
	return false
