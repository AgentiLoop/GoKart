extends SceneTree
## Headless race smoke test: godot --headless --path . -s tools/smoke.gd
## The player holds the throttle and the pursuit bot steers; 3 AI karts race alongside.
## Prints each kart's lap/place periodically and errors out if an AI kart is stuck.

var main: Node
var last_report := 0
const FRAMES := 3600

func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	Input.action_press("accelerate")

func _process(_d: float) -> bool:
	var f := Engine.get_physics_frames()
	var k = main.kart
	var t = main.track.data
	var target: Vector3 = t.points[(main.kart_index + 10) % t.count]
	var d: Vector3 = target - k.global_position
	var err := wrapf(atan2(-d.x, -d.z) - k.heading, -PI, PI)
	var s := clampf(-err * 2.5, -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_press("steer_right" if s > 0.0 else "steer_left", absf(s))
	if f - last_report >= 600:
		last_report = f
		var line := "f=%d" % f
		for i in main.karts.size():
			var kk = main.karts[i]
			line += " | k%d lap=%d idx=%d v=%.1f" % [i, kk.tracker.lap, kk.track_index, kk.model.speed]
		print(line, " | place ", main.hud.place_label.text)
	if f >= FRAMES:
		var moving := 0
		for i in range(1, main.karts.size()):
			if main.karts[i].tracker.lap >= 1 and absf(main.karts[i].model.speed) > 5.0:
				moving += 1
		print("SMOKE: ai karts racing: %d/%d" % [moving, main.karts.size() - 1])
		quit(0 if moving == main.karts.size() - 1 else 1)
		return true
	return false
