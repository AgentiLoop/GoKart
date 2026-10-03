extends SceneTree
## Windowed: godot --path . -s tools/mirror_shot.gd
## -> /tmp/gokart_mirror_menu.png (Extra class, mirrored preview) and /tmp/gokart_mirror_race.png
var f := 0
func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 1
	change_scene_to_file("res://scenes/menu.tscn")
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/gokart_%s.png" % n)
func _process(_d: float) -> bool:
	f += 1
	if f == 20:
		current_scene.move_engine(1)   # 150cc -> Extra
	elif f == 40:
		_shot("mirror_menu")
		current_scene.start_race()
	elif f == 400:
		Input.action_press("accelerate")
	elif f == 520:
		_shot("mirror_race")
		load("res://scripts/track_library.gd").engine_class = 2
		quit(0)
	return false
