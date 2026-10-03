extends SceneTree
## Windowed: godot --path . -s tools/mole_shot.gd
## -> /tmp/gokart_moles.png (the player behind the first group of mole holes on Green Hills with the
## moles out) and /tmp/gokart_mole_hit.png (thrown into the air by a mole).
var f := 0
var main
func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
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
	var mo = main.moles
	if f == 260:
		# the player 12 m before the first hole, the whole first group popping out together
		var m: Dictionary = mo.moles[0]
		var idx: int = posmod(m.idx - 4, data.count)
		_place(data.points[idx], idx)
		for i in 3:
			mo.moles[i].phase = fposmod(mo.RISE_TIME - mo.time, mo.CYCLE)
		for i in range(1, main.karts.size()):
			main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.karts[i].frozen = true
	elif f == 300:
		_shot("moles")
		var m: Dictionary = mo.moles[1]
		mo.time += mo.time_until_up(1)
		_place(m.pos, m.idx)
	elif f == 318:
		_shot("mole_hit")
		quit(0)
	return false
