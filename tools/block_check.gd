extends SceneTree
## Headless check of Mario Kart 64 shell blocking in a real race scene:
##   perl -e 'alarm 90; exec @ARGV' godot --headless --path . -s tools/block_check.gd
## After GO every kart is parked. Run A: the player dangles a banana, an AI kart behind fires a red
## shell -> the banana takes the hit (block sound, white puff, no spin-out, slot empty).
## Run B: the player fires a green shell at a banana lying on the road -> both vanish.
## Run C: the player holds triple shells, an AI green shell is stopped by the orbit -> 2 charges left.
## Run D: the player holds triple red shells (red orbit, HUD "xN") and fires one at the AI kart
## ahead -> it homes in and spins the kart out, 2 red shells keep orbiting.

const Items := preload("res://scripts/items.gd")
const ItemProjectile := preload("res://scripts/item_projectile.gd")

var main
var stage := 0
var frames := 0
var wait := 0
var ok := true
var run := "A"
var blocked: Array = []
var hits: Array = []

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + "[%s] %s" % [run, msg])
	if not cond:
		ok = false

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

## Park kart i on track sample idx facing along the road.
func _park(i: int, idx: int) -> void:
	var k = main.karts[i]
	var t = main.items.track
	k.frozen = true
	k.model.stop()
	k.global_position = t.points[idx] + Vector3(0, 0.1, 0)
	k.heading = t.heading_at(idx)
	k.rotation.y = k.heading

func _setup_run() -> void:
	blocked.clear()
	hits.clear()
	wait = 0
	for i in main.karts.size():
		_park(i, 40 + i * 4)
		main.items.holders[i].clear()
	var items = main.items
	for p in items.projectiles.duplicate():
		items._remove_projectile(p)
	_park(0, 20)
	_park(1, 14)
	match run:
		"A":
			items.holders[0].held = Items.Type.BANANA
			items.holders[1].held = Items.Type.RED_SHELL
			items._physics_process(1.0 / 60.0)   # hang the banana behind the kart
			_check(items.trails.has(0), "banana dangles behind the player")
			_check(items.use_item(1) == Items.Type.RED_SHELL, "AI fires a red shell from behind")
		"B":
			var k = main.karts[0]
			var fwd := Vector3(-sin(k.heading), 0, -cos(k.heading))
			items._add_projectile(ItemProjectile.make_banana(k.global_position + fwd * 10.0 + Vector3(0, 0.3, 0), 1))
			items.holders[0].held = Items.Type.SHELL
			_check(items.use_item(0) == Items.Type.SHELL, "player fires a green shell at the banana")
		"C":
			items.holders[0].held = Items.Type.TRIPLE_SHELL
			items.holders[0].charges = 3
			items.holders[1].held = Items.Type.SHELL
			items._physics_process(1.0 / 60.0)
			_check(items.orbits.has(0) and items.orbits[0].get_child_count() == 3, "three shells orbit the player")
			_check(items.use_item(1) == Items.Type.SHELL, "AI fires a green shell from behind")
		"D":
			_park(1, 28)   # AI kart ahead of the player this time
			items.holders[0].held = Items.Type.TRIPLE_RED_SHELL
			items.holders[0].charges = 3
			items._physics_process(1.0 / 60.0)
			_check(items.orbits.has(0) and items.orbits[0].get_child_count() == 3, "three red shells orbit the player")
			var col: Color = items.orbits[0].get_child(0).material_override.get_shader_parameter("shell_color")
			_check(col.r > 0.8 and col.g < 0.3, "orbiting shells are red (%s)" % col)
			_check(items.use_item(0) == Items.Type.TRIPLE_RED_SHELL, "player fires one red shell")
			_check(items.projectiles[-1].kind == Items.Type.RED_SHELL, "a homing red shell is in the air")

func _finish_run() -> void:
	var items = main.items
	var k = main.karts[0]
	match run:
		"A":
			_check(blocked == [[Items.Type.RED_SHELL, 0, Items.Type.BANANA]], "red shell stopped by the banana: %s" % [blocked])
			_check(hits.is_empty() and not k.model.is_spinning(), "player never hit")
			_check(items.holders[0].held == Items.Type.NONE, "banana used up")
			_check(not items.trails.has(0), "dangling banana gone")
			_check("block" in main.audio.played, "block sound played")
			_check(items.blasts.size() >= 1 and items.blasts[0].end_radius == items.BLOCK_PUFF_RADIUS, "white puff at the impact")
			_check(items.projectiles.filter(func(p): return p.is_shell()).is_empty(), "shell consumed")
		"B":
			_check(blocked == [[Items.Type.SHELL, -1, Items.Type.BANANA]], "green shell destroyed the road banana: %s" % [blocked])
			_check(items.projectiles.is_empty(), "shell and banana both gone (%d left)" % items.projectiles.size())
			_check(items.nodes.is_empty(), "visuals removed")
		"C":
			_check(blocked == [[Items.Type.SHELL, 0, Items.Type.TRIPLE_SHELL]], "green shell stopped by the orbiting shells: %s" % [blocked])
			_check(items.holders[0].held == Items.Type.TRIPLE_SHELL and items.holders[0].charges == 2, "two charges left")
			_check(items.orbits.has(0) and items.orbits[0].get_child_count() == 2, "two shells still orbit")
			_check(hits.is_empty() and not k.model.is_spinning(), "player never hit")
		"D":
			_check(hits == [[Items.Type.RED_SHELL, 1]], "red shell homed in on the AI kart: %s" % [hits])
			_check(main.karts[1].model.is_spinning(), "AI kart spun out")
			_check(blocked.is_empty(), "nothing blocked it")
			_check(items.holders[0].held == Items.Type.TRIPLE_RED_SHELL and items.holders[0].charges == 2, "two red shells left")
			_check(items.orbits.has(0) and items.orbits[0].get_child_count() == 2, "two red shells still orbit")
			_check(main.hud.item_label.text.begins_with("[ TRIPLE RED SHELLS x"), "HUD shows the count: %s" % main.hud.item_label.text)
			_check("throw" in main.audio.played, "throw sound played")

func _physics_process(_d: float) -> bool:
	frames += 1
	var rs = main.race_start
	if stage == 0:
		if rs.remaining <= 0.4 and not rs.started:
			Input.action_press("accelerate")
		if rs.started:
			Input.action_release("accelerate")
			stage = 1
			main.items.shell_blocked.connect(func(s, id, item): blocked.append([s, id, item]))
			main.items.kart_hit.connect(func(kind, id): hits.append([kind, id]))
			_setup_run()
	elif stage == 1:
		wait += 1
		if not blocked.is_empty() or not hits.is_empty() or wait > 240:
			# one more tick so trails / orbits catch up with the holder
			main.items._physics_process(1.0 / 60.0)
			_finish_run()
			if run == "A":
				run = "B"
				_setup_run()
			elif run == "B":
				run = "C"
				_setup_run()
			elif run == "C":
				run = "D"
				_setup_run()
			else:
				print("block_check: " + ("OK" if ok else "FAILED"))
				quit(0 if ok else 1)
				return true
	if frames > 1500:
		print("FAIL [%s] timed out at stage %d" % [run, stage])
		quit(1)
		return true
	return false
