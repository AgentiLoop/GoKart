extends SceneTree
## Windowed: godot --path . -s tools/battle_shot.gd [-- arena]
## -> /tmp/gokart_battle_menu.png (Battle mode on the title menu), /tmp/gokart_battle_start.png
## (start pads, balloons, Lakitu's signal) and /tmp/gokart_battle_bomb.png (a Mini Bomb Kart).
var f := 0
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var battle = load("res://scripts/battle.gd")
	battle.active = true
	battle.arena = int(args[0]) if args.size() > 0 else 1
	change_scene_to_file("res://scenes/menu.tscn")
func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/gokart_%s.png" % n)
func _process(_d: float) -> bool:
	f += 1
	if f == 30:
		_shot("battle_menu")
		current_scene.start_race()
	elif f == 120:
		_shot("battle_start")
	elif f == 300:
		Input.action_press("accelerate")
		var cs := current_scene
		for i in 3:
			cs.items.kart_hit.emit(3, 1)
		cs.karts[1].position = cs.kart.position + Vector3(-2.5, 0, -4.0)
		cs.karts[1].frozen = true
	elif f == 330:
		_shot("battle_bomb")
		load("res://scripts/battle.gd").active = false
		quit(0)
	return false
