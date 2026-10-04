extends SceneTree
## Windowed: godot --path . -s tools/scenery_shot.gd [-- <course index>]
## -> /tmp/gokart_scenery_<course>.png: the player on the grid of the course looking down the opening
## straight, the roadside scenery (trees / buildings / firs / cacti...) standing beyond the walls, and
## /tmp/gokart_scenery_<course>_bare.png, the same frame with the scenery removed. Pixel-compares the
## two: the scenery must change a good part of the frame (and none of the road right in front of the
## kart), or the tool prints FAIL.
var f := 0
var main
var course := 0
var dressed: Image
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		course = int(args[0])
	load("res://scripts/track_library.gd").selected = course
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _process(_d: float) -> bool:
	f += 1
	if f == 200:
		for i in range(1, main.karts.size()):
			main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.karts[i].frozen = true
	elif f == 230:
		dressed = root.get_viewport().get_texture().get_image()
		dressed.save_png("/tmp/gokart_scenery_%d.png" % course)
		var scenery = main.track.get_node_or_null("Scenery")
		var name: String = load("res://scripts/track_library.gd").info(course).name
		print("%s: Scenery node with %d batches, %d props" % [name, scenery.get_child_count() if scenery != null else 0, scenery.prop_count() if scenery != null else 0])
		if scenery != null:
			main.track.remove_child(scenery)
			scenery.free()
	elif f == 240:
		var bare := root.get_viewport().get_texture().get_image()
		bare.save_png("/tmp/gokart_scenery_%d_bare.png" % course)
		var w := dressed.get_width()
		var h := dressed.get_height()
		var changed := 0
		var road_changed := 0
		var top := h
		for y in range(0, h, 2):
			for x in range(0, w, 2):
				var a := dressed.get_pixel(x, y)
				var b := bare.get_pixel(x, y)
				if absf(a.r - b.r) > 0.1 or absf(a.g - b.g) > 0.1 or absf(a.b - b.b) > 0.1:
					changed += 1
					top = mini(top, y)
					# the road just ahead of the kart: the lower middle of the frame
					if y > h * 0.7 and x > w * 0.35 and x < w * 0.65:
						road_changed += 1
		var total := (w / 2) * (h / 2)
		print("scenery changes %d of %d sampled pixels (%.1f %%), topmost row %d of %d, %d on the road ahead" % [changed, total, 100.0 * changed / total, top, h, road_changed])
		print("SCENERY SHOT: %s" % ("OK" if changed > total * 0.03 and road_changed == 0 else "FAIL"))
		quit(0)
	return false
