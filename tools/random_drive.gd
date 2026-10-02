extends SceneTree
## Windowed random drive: godot --path . -s tools/random_drive.gd [-- track_index]
## A bot follows the road but wanders: random lane offsets, random drift bursts and
## random item use. Saves 3 screenshots at random moments to /tmp/gokart_random_*.png.

var main: Node
var rng := RandomNumberGenerator.new()
var lane := 0.0          # lateral offset from the centre line (m)
var lane_timer := 0
var drift_timer := 0
var shots := 0
var next_shot := 0
var use_frames := 0

func _initialize() -> void:
	rng.randomize()
	var lib = load("res://scripts/track_library.gd")
	lib.laps = 3
	var args := OS.get_cmdline_user_args()
	lib.selected = int(args[0]) if args.size() > 0 else rng.randi_range(0, lib.TRACKS.size() - 1)
	print("random drive on track ", lib.selected, " seed ", rng.seed)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	next_shot = 260 + rng.randi_range(0, 240)

func _process(_d: float) -> bool:
	var f := Engine.get_physics_frames()
	var k = main.kart
	var t = main.track.data
	Input.action_press("accelerate")
	# wander: pick a new lane offset every 1-3 s
	if f >= lane_timer:
		lane = rng.randf_range(-3.0, 3.0)
		lane_timer = f + rng.randi_range(60, 180)
	var idx: int = (main.kart_index + rng.randi_range(5, 9)) % t.count
	var tangent: Vector3 = t.tangents[idx]
	var side := Vector3(tangent.z, 0, -tangent.x)
	var target: Vector3 = t.points[idx] + side * lane
	var d: Vector3 = target - k.global_position
	var err := wrapf(atan2(-d.x, -d.z) - k.heading, -PI, PI)
	var s := clampf(-err * 2.5 + rng.randf_range(-0.15, 0.15), -1.0, 1.0)
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	Input.action_press("steer_right" if s > 0.0 else "steer_left", absf(s))
	# random drift bursts of 0.5-1.5 s when going fast enough
	if drift_timer == 0 and k.model.speed > 12.0 and rng.randf() < 0.01:
		Input.action_press("drift")
		drift_timer = f + rng.randi_range(30, 90)
	elif drift_timer > 0 and f >= drift_timer:
		Input.action_release("drift")
		drift_timer = 0
	# use whatever we hold, at a random moment
	if main.items.holders[0].held != 0 and use_frames == 0 and rng.randf() < 0.02:
		Input.action_press("use_item")
		use_frames = 3
	if use_frames > 0:
		use_frames -= 1
		if use_frames == 0:
			Input.action_release("use_item")
	if shots < 3 and f >= next_shot:
		shots += 1
		root.get_texture().get_image().save_png("/tmp/gokart_random_%d.png" % shots)
		print("shot %d f=%d lap=%d v=%.1f drift=%s item=%d place=%s" % [shots, f, main.tracker.lap, k.model.speed, k.model.drifting, main.items.holders[0].held, main.hud.place_label.text])
		next_shot = f + rng.randi_range(240, 600)
	if shots >= 3 or f > 4000:
		return true
	return false
