extends SceneTree
## Headless check of Mario Kart 64 "the other way" item use (Q / Backspace) in a real race scene:
##   perl -e 'alarm 90; exec @ARGV' godot --headless --path . -s tools/throw_check.gd
## After GO every kart is parked. Run A: the player holds a green shell, an AI kart sits behind,
## Q -> the shell flies straight back and spins it out. Run B: the same with a red shell (it flies
## straight, no homing). Run C: the player holds a banana, an AI kart sits where a toss lands,
## Q -> the banana flies an arc ahead and hits it. Run D: triple shells with Q still fire forward.

const Items := preload("res://scripts/items.gd")
const ItemProjectile := preload("res://scripts/item_projectile.gd")

var main
var stage := 0
var frames := 0
var wait := 0
var ok := true
var run := "A"
var hits: Array = []
var pressed := false
var flew := false
var peak := 0.0
var target := 1   # the AI kart each run shoots at (a fresh one per run: a spinning kart is immune)

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
	k.rescue_time = -1.0   # a kart Lakitu is still carrying would be moved again
	k.push = Vector3.ZERO
	k.global_position = t.points[idx] + Vector3(0, 0.1, 0)
	k.track_index = idx   # the scene's nearest_index search starts from this hint: a stale one from
	                      # the kart's old spot misreads the lateral offset and Lakitu "rescues" it
	k.heading = t.heading_at(idx)
	k.rotation.y = k.heading

func _setup_run() -> void:
	hits.clear()
	wait = 0
	pressed = false
	flew = false
	peak = 0.0
	for i in main.karts.size():
		_park(i, 40 + i * 4)
		main.items.holders[i].clear()
	var items = main.items
	for p in items.projectiles.duplicate():
		items._remove_projectile(p)
	_park(0, 20)
	var k = main.karts[0]
	k.frozen = false   # the key path only fires for a live kart (it sits still without throttle)
	var fwd := Vector3(-sin(k.heading), 0, -cos(k.heading))
	target = {"A": 1, "B": 2, "C": 3, "D": 4}[run]
	match run:
		"A":
			_park(target, 14)
			main.karts[target].global_position = k.global_position - fwd * 18.0   # straight behind the muzzle
			items.holders[0].held = Items.Type.SHELL
		"B":
			_park(target, 12)   # not run A's spot: the physics space still holds kart 1's old body there this frame
			# 24 m, not 18: kart 1 still stood there last frame (the physics body lags a frame and would shove this one aside)
			main.karts[target].global_position = k.global_position - fwd * 24.0
			items.holders[0].held = Items.Type.RED_SHELL
		"C":
			_park(target, 20)
			main.karts[target].global_position = k.global_position + fwd * (1.5 + ItemProjectile.toss_lead())
			items.holders[0].held = Items.Type.BANANA
		"D":
			_park(target, 26)
			items.holders[0].held = Items.Type.TRIPLE_SHELL
			items.holders[0].charges = 3
	main.hud.show_item(items.holders[0].held, items.holders[0].charges)
	var hint: String = main.hud.hint_label.text
	match run:
		"A", "B":
			_check(hint.contains("Q") and hint.contains("behind"), "HUD hint offers the backward shot: %s" % hint)
		"C":
			_check(hint.contains("Q") and hint.contains("ahead"), "HUD hint offers the forward toss: %s" % hint)
		"D":
			_check(not hint.contains("Q"), "HUD hint has no other way for triple shells: %s" % hint)

func _finish_run() -> void:
	var items = main.items
	var k = main.karts[0]
	match run:
		"A":
			_check(hits == [[Items.Type.SHELL, target]], "green shell fired back hit the kart behind: %s" % [hits])
			_check(main.karts[target].model.is_spinning() and not k.model.is_spinning(), "the kart behind spun out, the player did not")
			_check(items.holders[0].held == Items.Type.NONE, "slot empty")
			_check("throw" in main.audio.played, "throw sound played")
		"B":
			_check(hits == [[Items.Type.RED_SHELL, target]], "red shell fired back hit the kart behind: %s" % [hits])
			_check(main.karts[target].model.is_spinning(), "the kart behind spun out")
		"C":
			_check(flew, "the banana was in the air")
			_check(peak > 1.0, "it flew an arc (peak %.2f m)" % peak)
			_check(hits == [[Items.Type.BANANA, target]], "the tossed banana hit the kart ahead: %s" % [hits])
			_check(main.karts[target].model.is_spinning() and not k.model.is_spinning(), "the kart ahead spun out, the player did not")
		"D":
			_check(hits == [[Items.Type.SHELL, target]], "triple shell still went forward and hit the kart ahead: %s" % [hits])
			_check(items.holders[0].held == Items.Type.TRIPLE_SHELL and items.holders[0].charges == 2, "two shells left")

func _physics_process(_d: float) -> bool:
	frames += 1
	var rs = main.race_start
	if stage == 0:
		if rs.remaining <= 0.4 and not rs.started:
			Input.action_press("accelerate")
		if rs.started:
			Input.action_release("accelerate")
			stage = 1
			main.items.kart_hit.connect(func(kind, id): hits.append([kind, id]))
			_setup_run()
	elif stage == 1:
		wait += 1
		if wait == 2:
			Input.action_press("use_item_alt")
			pressed = true
		elif wait == 3:
			Input.action_release("use_item_alt")   # the press is seen by the nodes this frame (they run after the tool)
		elif wait == 4:
			var n: int = main.items.projectiles.size()
			_check(n == 1, "Q fired the item (%d projectiles)" % n)
			if n == 1:
				var p = main.items.projectiles[0]
				var k = main.karts[0]
				var fwd := Vector3(-sin(k.heading), 0, -cos(k.heading))
				var along: float = p.velocity.normalized().dot(fwd)
				match run:
					"A", "B":
						_check(along < -0.99, "flies straight back (%.2f)" % along)
						_check(p.kind == Items.Type.RED_SHELL and not p.homing or p.kind == Items.Type.SHELL, "no homing backwards")
					"C":
						_check(p.in_flight() and along > 0.9, "flies ahead (%.2f)" % along)
					"D":
						_check(along > 0.99, "flies forward (%.2f)" % along)
		for p in main.items.projectiles:
			if p.in_flight():
				flew = true
				peak = maxf(peak, main.items.nodes[p].position.y)
		if (not hits.is_empty() and wait > 3) or wait > 240:
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
				print("THROW CHECK: " + ("OK" if ok else "FAILED"))
				quit(0 if ok else 1)
				return true
	if frames > 1500:
		print("FAIL [%s] timed out at stage %d" % [run, stage])
		quit(1)
		return true
	return false
