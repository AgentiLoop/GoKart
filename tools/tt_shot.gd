extends SceneTree
## Windowed: godot --path . -s tools/tt_shot.gd -> /tmp/gokart_tt_menu.png, /tmp/gokart_tt_ghost.png
## Starts a Time Trial on track 0 against a synthetic ghost that drives the centre line (the
## real records are stashed and restored), so the see-through ghost kart renders in the scene.
var f := 0
var backup_records := {}
var backup_ghosts := {}
var had_file := false

func _initialize() -> void:
	var tt = load("res://scripts/time_trial.gd")
	var lib = load("res://scripts/track_library.gd")
	had_file = FileAccess.file_exists(tt.SAVE_PATH)
	tt.load_records()
	backup_records = tt.records
	backup_ghosts = tt.ghosts
	tt.reset()
	tt.loaded = true
	lib.selected = 0
	# synthetic ghost: the centre line at 20 m/s, sampled every 1/30 s
	var data = lib.make_data(0)
	var g = load("res://scripts/ghost_recording.gd").new()
	var dist := 0.0
	var start: int = data.count - 1
	while dist < 400.0:
		var idx: int = posmod(start + int(dist / data.spacing), data.count)
		g.positions.append(data.points[idx] + Vector3(0, 0.1, 0))
		g.headings.append(data.heading_at(idx))
		dist += 20.0 * g.interval
	tt.submit("Green Hills", 61.0, 20.0, g)
	tt.active = true
	change_scene_to_file("res://scenes/menu.tscn")

func _restore() -> void:
	var tt = load("res://scripts/time_trial.gd")
	tt.records = backup_records
	tt.ghosts = backup_ghosts
	if had_file:
		tt.save()
	tt.active = false

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/gokart_%s.png" % n)

func _process(_d: float) -> bool:
	f += 1
	var cs := current_scene
	if f == 20:
		_shot("tt_menu")
		cs.start_race()
	elif f == 60 and cs != null and cs.name == "Main":
		print("ghost on course: ", cs.ghost != null, "  HUD: ", cs.hud.cup_label.text)
	elif f == 420 and cs != null and cs.name == "Main":
		print("ghost t=%.2f pos=%s done=%s  player v=%.1f" % [cs.ghost.time, str(cs.ghost.position), str(cs.ghost.done), cs.kart.model.speed])
		_shot("tt_ghost")
		_restore()
		quit(0)
	return false
