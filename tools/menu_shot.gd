extends SceneTree
## Windowed: godot --path . -s tools/menu_shot.gd -> /tmp/gokart_menu0.png, _menu1.png, _race_track1.png
var f := 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/menu.tscn")
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/gokart_%s.png" % n)
func _process(_d: float) -> bool:
	f += 1
	if f == 20:
		_shot("menu0")
		current_scene.move(1)
	elif f == 40:
		_shot("menu1")
		current_scene.start_race()
	elif f == 400:
		_shot("race_track1")
		quit(0)
	return false
