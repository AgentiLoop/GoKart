extends SceneTree
## Windowed: godot --path . -s tools/menu_shot.gd
## -> /tmp/gokart_title.png (title screen: logo over the attract demo), /tmp/gokart_menu0.png and
##    _menu1.png (select screen on tracks 0 / 1), /tmp/gokart_race_track1.png
var f := 0
func _initialize() -> void:
	change_scene_to_file("res://scenes/menu.tscn")
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/gokart_%s.png" % n)
func _process(_d: float) -> bool:
	f += 1
	if f == 300:
		# five seconds in: the demo karts are up to speed and the chase camera has settled
		_shot("title")
		current_scene.dismiss_title()
	elif f == 320:
		_shot("menu0")
		current_scene.move(1)
	elif f == 420:
		_shot("menu1")
		current_scene.start_race()
	elif f == 780:
		_shot("race_track1")
		quit(0)
	return false
