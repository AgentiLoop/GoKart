extends SceneTree
## Windowed: godot --path . -s tools/train_shot.gd
## -> /tmp/gokart_train_crossing.png (the player waiting at the first crossing as a train passes,
## signal flashing) and /tmp/gokart_train_hit.png (thrown into the air by the locomotive).
var f := 0
var main
func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 3
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/gokart_%s.png" % n)
func _process(_d: float) -> bool:
	f += 1
	var data = main.track.data
	var c: Dictionary = data.crossings[0]
	if f == 260:
		# park the player a few samples before the first crossing with a train about to cross
		var i: int = posmod(c.road - 5, data.count)
		main.kart.global_position = data.points[i] + data.right_of(i) * -2.0 + Vector3(0, 0.1, 0)
		main.kart.heading = data.heading_at(i)
		main.kart.track_index = i
		main.cam.global_position = main.kart.global_position + Vector3(sin(main.kart.heading), 0, cos(main.kart.heading)) * 6.0 + Vector3(0, 3, 0)
		main.train.heads[0] = fposmod(c.s - 8.0, data.rail_length)
		main.train.heads[1] = fposmod(main.train.heads[0] + data.rail_length * 0.5, data.rail_length)
	elif f == 300:
		_shot("train_crossing")
		main.kart.global_position = c.pos + Vector3(0, 0.1, 0)
		main.kart.track_index = c.road
		main.train.heads[0] = fposmod(c.s + 2.0, data.rail_length)
	elif f == 318:
		_shot("train_hit")
		quit(0)
	return false
