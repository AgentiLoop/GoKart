extends SceneTree
## Temporary: godot --path . -s tools/overview_shot_tmp.gd -- 3
## Overview shots of a course: a free camera high above the track, HUD hidden, after the field has
## launched. Saves /tmp/gokart_overview_NN.png for a set of heights / angles.

var main: Node
var cam: Camera3D
var shots := 0
var center := Vector3.ZERO
var extent := 0.0
# [yaw degrees, distance factor, height factor, fov]
var poses := [
	[270.0, 0.45, 0.4, 65.0],
	[270.0, 0.4, 0.45, 65.0],
	[270.0, 0.35, 0.5, 65.0],
	[90.0, 0.45, 0.4, 65.0],
	[90.0, 0.4, 0.45, 65.0],
	[90.0, 0.35, 0.5, 65.0],
	[300.0, 0.45, 0.42, 65.0],
	[240.0, 0.45, 0.42, 65.0],
	[60.0, 0.45, 0.42, 65.0],
	[120.0, 0.45, 0.42, 65.0],
	[270.0, 0.3, 0.3, 70.0],
	[90.0, 0.3, 0.3, 70.0],
	[285.0, 0.4, 0.35, 65.0],
	[255.0, 0.4, 0.35, 65.0],
	[270.0, 0.05, 0.6, 65.0],
	[0.0, 0.05, 0.6, 65.0],
]

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.laps = 3
	var args := OS.get_cmdline_user_args()
	lib.selected = int(args[0]) if args.size() > 0 else 3
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	var f := Engine.get_physics_frames()
	if cam == null:
		var t = main.track.data
		var mn := Vector3(INF, 0, INF)
		var mx := Vector3(-INF, 0, -INF)
		for p in t.points:
			mn.x = minf(mn.x, p.x); mn.z = minf(mn.z, p.z)
			mx.x = maxf(mx.x, p.x); mx.z = maxf(mx.z, p.z)
		center = (mn + mx) * 0.5
		extent = maxf(mx.x - mn.x, mx.z - mn.z)
		cam = Camera3D.new()
		cam.far = 4000.0
		main.add_child(cam)
		main._end_intro()
		main.hud.visible = false
		print("center ", center, " extent ", extent)
	if main.race_start.started and main.race_start.since_go > 0.1:
		Input.action_press("accelerate")
	if f >= 420 and (f - 420) % 10 == 0 and shots < poses.size() and not FileAccess.file_exists("/tmp/gokart_overview_%02d.png" % (shots + 1)) and (shots == 0 or FileAccess.file_exists("/tmp/gokart_overview_%02d.png" % shots)):
		var p: Array = poses[shots]
		var yaw: float = deg_to_rad(p[0])
		var dist: float = extent * p[1]
		var h: float = extent * p[2]
		var pos := center + Vector3(sin(yaw) * dist, h, cos(yaw) * dist)
		cam.fov = p[3]
		cam.current = true
		cam.look_at_from_position(pos, center)
		shots += 1
	elif f >= 425 and (f - 425) % 10 == 0 and shots >= 1 and shots <= poses.size():
		var path := "/tmp/gokart_overview_%02d.png" % shots
		if not FileAccess.file_exists(path):
			root.get_texture().get_image().save_png(path)
			var vp := root.get_visible_rect().size
			var inside := 0
			var bb := Rect2()
			var first := true
			for p in main.track.data.points:
				var sp: Vector2 = cam.unproject_position(p)
				if not cam.is_position_behind(p):
					bb = Rect2(sp, Vector2.ZERO) if first else bb.expand(sp)
					first = false
					if sp.x >= 0 and sp.y >= 0 and sp.x < vp.x and sp.y < vp.y:
						inside += 1
			print("saved ", path, " pose ", poses[shots - 1], " inside %d/%d bbox %.0f%%x %.0f%%y" % [inside, main.track.data.count, 100.0 * bb.size.x / vp.x, 100.0 * bb.size.y / vp.y])
			if shots == poses.size():
				print("done")
				return true
	if f > 1200:
		print("timeout")
		return true
	return false
