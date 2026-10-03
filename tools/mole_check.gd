extends SceneTree
## Headless check of the MK64 Moo Moo Farm moles: godot --headless --path . -s tools/mole_check.gd
## Loads the race scene on Green Hills directly (no menu). The mole model and molehills node are
## built and the moles pop in and out through the countdown. After GO an AI kart sent down the lane
## of a mole hole steers round it (never hit); the player parked on a hole as the mole comes out is
## thrown into the air, spun out, crash sound, lands again; a green shell fired over a hole knocks
## the mole away (shell spent, pop sound) and the mole stays down.

var main: Node
var stage := 0
var frames := 0
var ok := true
var phys0 := 0
var peak_y := 0.0
var dodged := false
var checked := false
var hole := 0
var heights: Array = []

func _initialize() -> void:
	var lib = load("res://scripts/track_library.gd")
	lib.selected = 0
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
	var Moles = load("res://scripts/moles.gd")
	var Items = load("res://scripts/items.gd")
	var mo = main.moles
	var data = main.track.data
	if stage == 0:
		_check(mo != null and mo.active() and main.molehills != null, "mole model and molehills node built")
		_check(mo.moles.size() == data.mole_specs.size() and mo.moles.size() >= 6, "%d holes" % mo.moles.size())
		_check(main.molehills.bodies.size() == mo.moles.size() and main.molehills.get_node_or_null("Hole0") != null, "a node per hole")
		for i in mo.moles.size():
			heights.append(mo.height(i))
		stage = 1
	elif stage == 1:
		if main.race_start.started:
			var changed := 0
			for i in mo.moles.size():
				if not is_equal_approx(mo.height(i), heights[i]):
					changed += 1
			_check(changed > 0, "the moles pop in and out through the countdown (%d moved)" % changed)
			_check(main.molehills.bodies[0].position.y <= 0.0 and main.molehills.bodies[0].position.y >= -main.molehills.RISE, "molehills node follows the model")
			Input.action_press("accelerate")
			stage = 2
			phys0 = Engine.get_physics_frames()
		else:
			Input.action_release("accelerate")
	elif stage == 2:
		if Engine.get_physics_frames() - phys0 >= 30:
			# freeze the field out of the way, then send AI kart 1 down the lane of the first hole
			for i in range(2, main.karts.size()):
				main.karts[i].frozen = true
				main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.kart.frozen = true
			main.kart.global_position = Vector3(400, 0.1, 380)
			Input.action_release("accelerate")
			hole = 0
			var m: Dictionary = mo.moles[hole]
			var idx: int = posmod(m.idx - 9, data.count)   # 27 m before the hole
			var k1 = main.karts[1]
			_park(k1, data.points[idx] + data.right_of(idx) * m.lateral, data.heading_at(idx), idx)
			k1.model.speed = 20.0
			k1.driver.lane_offset = m.lateral
			k1.driver.dodging = false
			k1.driver.idx = idx
			k1.launches = 0
			# make sure the mole is out as the kart gets there (~1.3 s)
			mo.time += mo.time_until_up(hole) - 1.0
			dodged = false
			checked = false
			stage = 3
			phys0 = Engine.get_physics_frames()
	elif stage == 3:
		var pf := Engine.get_physics_frames() - phys0
		var k1 = main.karts[1]
		var m: Dictionary = mo.moles[hole]
		if k1.driver.dodging:
			dodged = true
		if pf >= 5 and not checked:
			checked = true
			_check(k1.driver.dodging and absf(k1.driver.dodge_lane - m.lateral) >= Moles.HIT_RADIUS, "AI kart sees the hole ahead and aims for %.1f m instead of %.1f" % [k1.driver.dodge_lane, m.lateral])
		elif pf >= 240:
			var lateral: float = (k1.global_position - data.points[k1.track_index]).dot(data.right_of(k1.track_index))
			_check(dodged, "the AI kart dodged")
			_check(k1.launches == 0, "...and was never hit (launches %d)" % k1.launches)
			_check(data.is_on_road(k1.global_position), "stayed on the road (lateral %.1f m)" % lateral)
			_check(k1.model.speed > 10.0, "still racing (%.1f m/s)" % k1.model.speed)
			_check(mo.ahead_of(m, data.length * k1.track_index / data.count) < 0.0, "...and is past the hole")
			# now the player sits on a hole as the mole comes out
			k1.frozen = true
			k1.global_position = Vector3(400, 0.1, 420)
			hole = 4
			var h: Dictionary = mo.moles[hole]
			main.kart.frozen = false
			_park(main.kart, h.pos, data.heading_at(h.idx), h.idx)
			main.kart.launches = 0
			mo.time += mo.time_until_up(hole)
			_check(mo.is_up(hole) and mo.mole_at(main.kart.global_position) == hole, "player on hole %d, mole out" % hole)
			peak_y = 0.0
			checked = false
			stage = 4
			phys0 = Engine.get_physics_frames()
	elif stage == 4:
		var pf := Engine.get_physics_frames() - phys0
		peak_y = maxf(peak_y, main.kart.global_position.y)
		if pf >= 10 and not checked:
			checked = true
			_check(main.kart.launches == 1, "player thrown by the mole (launches %d)" % main.kart.launches)
			_check(main.kart.model.is_spinning(), "spinning out")
			_check(main.audio.played.has("crash"), "crash sound")
			_check(is_equal_approx(Moles.LAUNCH_SPEED, 7.0), "launch speed constant")
		elif pf > 140:
			_check(peak_y > 0.5, "thrown into the air: peak y %.2f" % peak_y)
			_check(main.kart.global_position.y < 0.6, "landed again (y %.2f)" % main.kart.global_position.y)
			_check(main.kart.launches == 1, "hit once only (%d)" % main.kart.launches)
			# a green shell fired over a hole knocks the mole away
			hole = 7
			var h: Dictionary = mo.moles[hole]
			var idx: int = posmod(h.idx - 3, data.count)   # 9 m before the hole
			_park(main.kart, data.points[idx] + data.right_of(idx) * h.lateral, data.heading_at(idx), idx)
			main.kart.model.immunity_time = 0.0
			main.items.holder.receive(Items.Type.SHELL, 1)
			mo.time += mo.time_until_up(hole)
			var knocks_before: int = mo.knocks
			main.items.use_item(0)
			_check(_player_shells() == 1, "green shell fired towards hole %d" % hole)
			_check(mo.knocks == knocks_before and mo.is_up(hole), "mole out, not knocked yet")
			main.audio.played.clear()
			checked = false
			stage = 5
			phys0 = Engine.get_physics_frames()
	elif stage == 5:
		var pf := Engine.get_physics_frames() - phys0
		if pf >= 30 and not checked:
			checked = true
			_check(mo.knocks == 1, "the shell knocked the mole away (knocks %d)" % mo.knocks)
			_check(_player_shells() == 0, "the shell was spent on it")
			_check(main.audio.played.has("pop"), "pop sound")
			_check(not mo.is_up(hole) and mo.moles[hole].knocked > Moles.KNOCK_TIME - 1.0, "the mole stays down (%.1f s left)" % mo.moles[hole].knocked)
			_check(not main.molehills.bodies[hole].visible, "...and its body is hidden")
			_check(main.kart.launches == 1, "the player was not hit by it")
		elif pf > 40:
			print("MOLE CHECK: ", "OK" if ok else "FAILED")
			quit(0 if ok else 1)
			return true
	return false
