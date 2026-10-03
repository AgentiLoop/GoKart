extends SceneTree
## Headless battle smoke test: godot --headless --path . -s tools/battle_smoke.gd [-- arena]
## Loads the battle scene on the given arena (default 0) with the battle AI driving every kart
## (the player too) for 3600 physics frames. Prints balloons / items / distance per kart every 600
## frames and fails if a kart that is still in the battle barely moved or nobody ever used an item.

var main: Node
var last_report := 0
var last_pos: Array = []
var travelled: Array = []
var max_projectiles := 0
var items_seen := 0
const FRAMES := 3600

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var battle = load("res://scripts/battle.gd")
	battle.active = true
	battle.arena = int(args[0]) if args.size() > 0 else 0
	main = load("res://scenes/battle.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	var f := Engine.get_physics_frames()
	if last_pos.is_empty():
		if main.karts.is_empty():
			return false
		# the scene is ready: the player drives on the battle AI too
		main.kart.driver = load("res://scripts/battle_ai.gd").new(main.data, 1.0)
		for k in main.karts:
			last_pos.append(k.position)
			travelled.append(0.0)
	for i in main.karts.size():
		var k = main.karts[i]
		if main.battle.is_out(i) or k.is_rescued():
			last_pos[i] = k.position
			continue
		var step: float = k.position.distance_to(last_pos[i])
		if step < 5.0:   # ignore teleports (rescues, parking)
			travelled[i] += step
		last_pos[i] = k.position
		if main.items.holders[i].held != 0:
			items_seen += 1
	max_projectiles = maxi(max_projectiles, main.items.projectiles.size())
	if f - last_report >= 600:
		last_report = f
		var line := "f=%d t=%.1f" % [f, main.battle.time]
		for i in main.karts.size():
			var k = main.karts[i]
			line += " | k%d b=%d%s v=%.1f item=%d d=%.0f r=%d" % [i, main.battle.balloons[i], "x" if main.battle.is_out(i) else "", k.model.speed, main.items.holders[i].held, travelled[i], k.rescues]
		print(line, " | proj=", main.items.projectiles.size(), " over=", main.battle.over)
	if f >= FRAMES or main.results_shown:
		var moving := 0
		var live := 0
		for i in main.karts.size():
			if main.battle.is_out(i):
				continue
			live += 1
			if travelled[i] > 150.0 or main.battle.over:
				moving += 1
		var pops := 0
		for p in main.battle.pops:
			pops += p
		var used: bool = max_projectiles > 0 or pops > 0
		print("BATTLE SMOKE (%s): karts moving %d/%d, balloons popped %d, max projectiles %d, items held frames %d, over=%s winner=%d" % [main.data.name, moving, live, pops, max_projectiles, items_seen, main.battle.over, main.battle.winner])
		load("res://scripts/battle.gd").active = false
		quit(0 if moving == live and used else 1)
		return true
	return false
