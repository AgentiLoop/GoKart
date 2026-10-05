extends SceneTree
## Temporary: godot --path . -s tools/clean_shot_tmp.gd -- 1
## Centre-line pursuit bot; saves /tmp/gokart_clean_NN.png only when the kart is
## near the centre of the road, not drifting / spinning, going fast and in 2nd-4th.

const AiDriver := preload("res://scripts/ai_driver.gd")
var main: Node
var helper
var shots := 0
var last_shot := 0

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.laps = 3
	var args := OS.get_cmdline_user_args()
	lib.selected = int(args[0]) if args.size() > 0 else 1
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	var f := Engine.get_physics_frames()
	var k = main.kart
	var t = main.track.data
	if helper == null:
		helper = AiDriver.new(t, 0.0, 1.0)
	if main.race_start.started and main.race_start.since_go > 0.1:
		Input.action_press("accelerate")
	var look := 7
	var target: Vector3 = t.points[(main.kart_index + look) % t.count]
	var d: Vector3 = target - k.global_position
	var err := wrapf(atan2(-d.x, -d.z) - k.heading, -PI, PI)
	var s := clampf(-err * 2.5, -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_press("steer_right" if s > 0.0 else "steer_left", absf(s))
	var safe: float = helper.corner_speed(main.kart_index)
	if k.model.speed > safe + 4.0:
		Input.action_release("accelerate")
		Input.action_press("brake", 0.5)
	else:
		Input.action_release("brake")
	# lateral offset from the centre line
	var idx: int = main.kart_index % t.count
	var tangent: Vector3 = t.tangents[idx]
	var side := Vector3(tangent.z, 0, -tangent.x)
	var lat: float = (k.global_position - t.points[idx]).dot(side)
	var place: String = main.hud.place_label.text
	var ok: bool = f >= 60 and f - last_shot >= 30 and not k.model.is_boosting()
	if ok:
		shots += 1
		last_shot = f
		var path := "/tmp/gokart_clean_%02d.png" % shots
		root.get_texture().get_image().save_png(path)
		print("saved %s f=%d started=%s rem=%.1f idx=%d v=%.1f lat=%.1f place=%s" % [path, f, main.race_start.started, main.race_start.remaining, idx, k.model.speed, lat, place])
	if shots >= 20 or f > 3600 or main.tracker.is_finished:
		print("done shots=", shots)
		return true
	return false
