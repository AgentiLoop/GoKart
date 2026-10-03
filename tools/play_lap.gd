extends SceneTree
## Windowed one-lap playthrough using only player inputs (Input.action_press = key presses):
##   godot --path . -s tools/play_lap.gd  -> /tmp/lap_*.png and a console log.
## Holds the throttle at GO, steers/brakes by looking ahead, presses use_item when holding one,
## and screenshots every ~2s plus whenever the held item changes.

const AiDriver := preload("res://scripts/ai_driver.gd")
var main: Node
var helper
var last_item := -99
var shots := 0
var use_frames := 0
var last_shot := 0

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.laps = 1
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		lib.selected = int(args[0])
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _shot(tag: String) -> void:
	shots += 1
	root.get_texture().get_image().save_png("/tmp/lap_%02d_%s.png" % [shots, tag])

func _process(_d: float) -> bool:
	var f := Engine.get_physics_frames()
	var k = main.kart
	var t = main.track.data
	if helper == null:
		helper = AiDriver.new(t, 0.0, 1.0)
	if main.race_start.started or main.race_start.remaining <= 0.5:
		Input.action_press("accelerate")   # rocket start, not a false start
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
	var held: int = main.items.holders[0].held
	if held != last_item:
		print("f=%d player holds item %d" % [f, held])
		last_item = held
		_shot("held%d" % held)
	if held != 0 and use_frames == 0 and f % 240 == 0 and held != 3:
		pass
	if held != 0 and f % 300 == 0 and use_frames == 0:
		Input.action_press("use_item")
		use_frames = 3
	if use_frames > 0:
		use_frames -= 1
		if use_frames == 0:
			Input.action_release("use_item")
	if f - last_shot >= 120 and main.tracker.lap > 0:
		last_shot = f
		_shot("race")
		var line := "f=%d lap=%d idx=%d v=%.1f place=%s time=%.1f" % [f, main.tracker.lap, main.kart_index, k.model.speed, main.hud.place_label.text, main.tracker.race_time]
		print(line)
	if main.tracker.is_finished:
		print("LAP DONE time=%.2f place=%s" % [main.tracker.race_time, main.hud.place_label.text])
		_shot("finish")
		return true
	if f > 7200:
		print("TIMEOUT lap=", main.tracker.lap, " idx=", main.kart_index)
		return true
	return false
