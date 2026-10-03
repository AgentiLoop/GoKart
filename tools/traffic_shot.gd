extends SceneTree
## Windowed: godot --path . -s tools/traffic_shot.gd
## -> /tmp/gokart_traffic_lanes.png (the player behind a bus and a truck in the two lanes of
## Sunset Speedway, headlights on) and /tmp/gokart_traffic_hit.png (thrown into the air by a truck).
var f := 0
var main
func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 1
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
	var tr = main.traffic
	if f == 260:
		# the bus in the right lane and the truck just ahead of it in the left lane, the player behind both
		var bus := 0
		var truck := 0
		for i in tr.vehicles.size():
			if tr.vehicles[i].kind == "bus":
				bus = i
			if tr.vehicles[i].kind == "truck":
				truck = i
		tr.vehicles[truck].s = fposmod(tr.vehicles[bus].s + 6.0, data.length)
		var pose: Dictionary = tr.road_pose(tr.vehicles[bus].s - 16.0, 0.0)
		_place(pose.pos, data.nearest_index(pose.pos))
		for i in range(1, main.karts.size()):
			main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.karts[i].frozen = true
	elif f == 300:
		_shot("traffic_lanes")
		var truck := 0
		for i in tr.vehicles.size():
			if tr.vehicles[i].kind == "truck":
				truck = i
		var p: Dictionary = tr.vehicle_pose(truck)
		_place(p.pos, data.nearest_index(p.pos))
	elif f == 318:
		_shot("traffic_hit")
		quit(0)
	return false
