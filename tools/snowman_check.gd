extends SceneTree
## Headless check of the MK64 Frappe Snowland snowmen: godot --headless --path . -s tools/snowman_check.gd
## Loads the race scene on Frosty Peaks directly (no menu). The snowman model and snowfield node are
## built and every snowman stands through the countdown. After GO an AI kart sent down the lane of the
## first snowman of the field weaves through all five rows (never hit); the player parked against a
## snowman is thrown into the air, spun out, crash sound, lands again and the snowman bursts (puff,
## body gone); a green shell fired at a snowman smashes it (shell spent, pop sound) and it grows back
## a few seconds later.

var main: Node
var stage := 0
var frames := 0
var ok := true
var phys0 := 0
var peak_y := 0.0
var dodged := false
var checked := false
var target := 0

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.selected = 2
	lib.engine_class = 2
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		ok = false

## Live projectiles the player threw (the frozen AI karts may have thrown some of their own).
func _player_shells() -> int:
	var n := 0
	for p in main.items.projectiles:
		if p.owner_id == 0 and p.is_shell():
			n += 1
	return n

func _park(k, pos: Vector3, heading: float, idx: int) -> void:
	k.global_position = pos + Vector3(0, 0.1, 0)
	k.heading = heading
	k.rotation.y = heading
	k.track_index = idx
	k.model.speed = 0.0
	k.velocity = Vector3.ZERO
	k.push = Vector3.ZERO

func _process(_d: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var Snowmen = load("res://scripts/snowmen.gd")
	var Items = load("res://scripts/items.gd")
	var sn = main.snowmen
	var data = main.track.data
	if stage == 0:
		_check(sn != null and sn.active() and main.snowfield != null, "snowman model and snowfield node built")
		_check(sn.snowmen.size() == data.snowman_specs.size() and sn.snowmen.size() >= 10, "%d snowmen" % sn.snowmen.size())
		_check(main.snowfield.bodies.size() == sn.snowmen.size() and main.snowfield.get_node_or_null("Spot0") != null, "a node per snowman")
		stage = 1
	elif stage == 1:
		if main.race_start.started:
			var standing := 0
			for i in sn.snowmen.size():
				if sn.is_standing(i) and main.snowfield.bodies[i].visible:
					standing += 1
			_check(standing == sn.snowmen.size(), "every snowman stands through the countdown (%d)" % standing)
			_check(sn.smashes == 0, "none smashed yet")
			Input.action_press("accelerate")
			stage = 2
			phys0 = Engine.get_physics_frames()
		else:
			Input.action_release("accelerate")
	elif stage == 2:
		if Engine.get_physics_frames() - phys0 >= 30:
			# freeze the field out of the way, then send AI kart 1 down the lane of the field's first snowman
			for i in range(2, main.karts.size()):
				main.karts[i].frozen = true
				main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.kart.frozen = true
			main.kart.global_position = Vector3(400, 0.1, 380)
			Input.action_release("accelerate")
			target = 2
			var sm: Dictionary = sn.snowmen[target]
			var idx: int = posmod(sm.idx - 9, data.count)   # 27 m before the snowman
			var k1 = main.karts[1]
			_park(k1, data.points[idx] + data.right_of(idx) * sm.lateral, data.heading_at(idx), idx)
			k1.model.speed = 20.0
			k1.driver.lane_offset = sm.lateral
			k1.driver.dodging = false
			k1.driver.idx = idx
			k1.launches = 0
			dodged = false
			checked = false
			stage = 3
			phys0 = Engine.get_physics_frames()
	elif stage == 3:
		var pf := Engine.get_physics_frames() - phys0
		var k1 = main.karts[1]
		var sm: Dictionary = sn.snowmen[target]
		if k1.driver.dodging:
			dodged = true
		if pf >= 5 and not checked:
			checked = true
			_check(k1.driver.dodging and absf(k1.driver.dodge_lane - sm.lateral) >= Snowmen.HIT_RADIUS, "AI kart sees the snowman ahead and aims for %.1f m instead of %.1f" % [k1.driver.dodge_lane, sm.lateral])
		elif pf >= 300:
			var lateral: float = (k1.global_position - data.points[k1.track_index]).dot(data.right_of(k1.track_index))
			var last: Dictionary = sn.snowmen[8]   # the field's last row
			_check(dodged, "the AI kart dodged")
			_check(k1.launches == 0, "...and was never hit (launches %d)" % k1.launches)
			_check(sn.smashes == 0, "no snowman smashed (%d)" % sn.smashes)
			_check(data.is_on_road(k1.global_position), "stayed on the road (lateral %.1f m)" % lateral)
			_check(k1.model.speed > 10.0, "still racing (%.1f m/s)" % k1.model.speed)
			_check(sn.ahead_of(last, data.length * k1.track_index / data.count) < 0.0, "...and is through the whole field")
			# now the player drives into a snowman by the edge
			k1.frozen = true
			k1.global_position = Vector3(400, 0.1, 420)
			target = 0
			var h: Dictionary = sn.snowmen[target]
			main.kart.frozen = false
			_park(main.kart, h.pos, data.heading_at(h.idx), h.idx)
			main.kart.launches = 0
			_check(sn.is_standing(target) and sn.snowman_at(main.kart.global_position) == target, "player against snowman %d" % target)
			peak_y = 0.0
			checked = false
			stage = 4
			phys0 = Engine.get_physics_frames()
	elif stage == 4:
		var pf := Engine.get_physics_frames() - phys0
		peak_y = maxf(peak_y, main.kart.global_position.y)
		if pf >= 10 and not checked:
			checked = true
			_check(main.kart.launches == 1, "player thrown by the snowman (launches %d)" % main.kart.launches)
			_check(main.kart.model.is_spinning(), "spinning out")
			_check(main.audio.played.has("crash"), "crash sound")
			_check(sn.smashes == 1 and not sn.is_standing(target), "the snowman burst (smashes %d)" % sn.smashes)
			_check(not main.snowfield.bodies[target].visible, "...its body is gone")
			_check(main.snowfield.puffs[target].visible, "...in a puff of snow")
			_check(is_equal_approx(Snowmen.LAUNCH_SPEED, 8.0), "launch speed constant")
		elif pf > 140:
			_check(peak_y > 0.5, "thrown into the air: peak y %.2f" % peak_y)
			_check(main.kart.global_position.y < 0.6, "landed again (y %.2f)" % main.kart.global_position.y)
			_check(main.kart.launches == 1, "hit once only (%d)" % main.kart.launches)
			_check(not main.snowfield.puffs[target].visible, "puff over")
			# a green shell fired at a snowman smashes it
			target = 9
			var h: Dictionary = sn.snowmen[target]
			var idx: int = posmod(h.idx - 3, data.count)   # 9 m before the snowman
			_park(main.kart, data.points[idx] + data.right_of(idx) * h.lateral, data.heading_at(idx), idx)
			main.kart.model.immunity_time = 0.0
			main.items.holder.receive(Items.Type.SHELL, 1)
			var before: int = sn.smashes
			main.items.use_item(0)
			_check(_player_shells() == 1, "green shell fired towards snowman %d" % target)
			_check(sn.smashes == before and sn.is_standing(target), "snowman standing, not smashed yet")
			main.audio.played.clear()
			checked = false
			stage = 5
			phys0 = Engine.get_physics_frames()
	elif stage == 5:
		var pf := Engine.get_physics_frames() - phys0
		if pf >= 30 and not checked:
			checked = true
			_check(sn.smashes == 2, "the shell smashed the snowman (smashes %d)" % sn.smashes)
			_check(_player_shells() == 0, "the shell was spent on it")
			_check(main.audio.played.has("pop"), "pop sound")
			_check(not sn.is_standing(target) and sn.snowmen[target].down > Snowmen.REBUILD_TIME - 1.0, "the snowman is down (%.1f s left)" % sn.snowmen[target].down)
			_check(not main.snowfield.bodies[target].visible, "...and its body is gone")
			_check(main.kart.launches == 1, "the player was not hit by it")
		elif pf > 30 + int(Snowmen.REBUILD_TIME * 60.0) + 10:
			_check(sn.is_standing(target) and sn.height(target) == 1.0, "the snowman grew back after REBUILD_TIME")
			_check(main.snowfield.bodies[target].visible and main.snowfield.bodies[target].scale.is_equal_approx(Vector3.ONE), "...full size again")
			print("SNOWMAN CHECK: ", "OK" if ok else "FAILED")
			quit(0 if ok else 1)
			return true
	return false
