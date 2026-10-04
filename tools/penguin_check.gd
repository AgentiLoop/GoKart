extends SceneTree
## Headless check of the MK64 Sherbet Land penguins: godot --headless --path . -s tools/penguin_check.gd
## Loads the race scene on Frosty Peaks directly (no menu). The penguin model and rookery node are
## built and the penguins slide back and forth through the countdown. After GO an AI kart sent down
## the middle towards a penguin run keeps to the edge of the road (never hit); the player parked on
## the centreline as a penguin slides through is pushed away, spun out, crash sound; a green shell
## fired into a penguin bowls it over (shell spent, pop sound) and it lies on its back.

var main: Node
var stage := 0
var frames := 0
var ok := true
var phys0 := 0
var dodged := false
var checked := false
var run := 0
var laterals: Array = []
var min_edge := INF
var smashes := 0

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

func _lateral(k, data) -> float:
	return (k.global_position - data.points[k.track_index]).dot(data.right_of(k.track_index))

func _process(_d: float) -> bool:
	frames += 1
	if frames < 5:
		return false
	var Penguins = load("res://scripts/penguins.gd")
	var Items = load("res://scripts/items.gd")
	var pg = main.penguins
	var data = main.track.data
	if stage == 0:
		_check(pg != null and pg.active() and main.rookery != null, "penguin model and rookery node built")
		_check(pg.penguins.size() == data.penguin_specs.size() and pg.penguins.size() >= 3, "%d penguins" % pg.penguins.size())
		_check(main.rookery.bodies.size() == pg.penguins.size() and main.rookery.get_node_or_null("Spot0/Penguin0") != null, "a node per penguin")
		for i in pg.penguins.size():
			_check(data.ice_at(pg.penguins[i].idx) != null, "penguin %d runs on the ice" % i)
			laterals.append(0.0)
		stage = 1
	elif stage == 1:
		for i in pg.penguins.size():
			laterals[i] = maxf(laterals[i], absf(pg.across_speed(i)))
		if main.race_start.started:
			var moved := 0
			for i in pg.penguins.size():
				if laterals[i] > 3.0:
					moved += 1
			_check(moved == pg.penguins.size(), "the penguins slide about through the countdown (%d moved)" % moved)
			_check(main.rookery.spots[0].position.is_equal_approx(pg.position(0)), "rookery node follows the model")
			Input.action_press("accelerate")
			stage = 2
			phys0 = Engine.get_physics_frames()
		else:
			Input.action_release("accelerate")
	elif stage == 2:
		if Engine.get_physics_frames() - phys0 >= 30:
			# freeze the field out of the way, then send AI kart 1 down the middle towards the first run
			for i in range(2, main.karts.size()):
				main.karts[i].frozen = true
				main.karts[i].global_position = Vector3(400 + 5 * i, 0.1, 400)
			main.kart.frozen = true
			main.kart.global_position = Vector3(400, 0.1, 380)
			Input.action_release("accelerate")
			run = 0
			var p: Dictionary = pg.penguins[run]
			var idx: int = posmod(p.idx - 12, data.count)   # 36 m before the run
			var k1 = main.karts[1]
			_park(k1, data.points[idx], data.heading_at(idx), idx)
			k1.model.speed = 18.0
			k1.driver.lane_offset = 0.0
			k1.driver.dodging = false
			k1.driver.idx = idx
			k1.launches = 0
			# the penguin crosses the centre as the kart gets there (~2 s)
			pg.penguins[run].t += pg.time_until_centre(run) - 2.0
			dodged = false
			checked = false
			min_edge = INF
			stage = 3
			phys0 = Engine.get_physics_frames()
	elif stage == 3:
		var pf := Engine.get_physics_frames() - phys0
		var k1 = main.karts[1]
		var p: Dictionary = pg.penguins[run]
		if k1.driver.dodging:
			dodged = true
		var rel: float = pg.ahead_of(p, data.length * k1.track_index / data.count)
		if absf(rel) < 6.0:
			min_edge = minf(min_edge, absf(_lateral(k1, data)))
		if pf >= 5 and not checked:
			checked = true
			var reach: float = absf(p.start) + Penguins.HIT_RADIUS + Penguins.DODGE_MARGIN
			_check(k1.driver.dodging and absf(k1.driver.dodge_lane) >= reach - 0.01, "AI kart sees the run ahead and aims for the edge (%.1f m)" % k1.driver.dodge_lane)
		elif pf >= 240:
			_check(dodged, "the AI kart dodged")
			_check(k1.launches == 0, "...and was never hit (launches %d)" % k1.launches)
			_check(min_edge > absf(p.start) + Penguins.HIT_RADIUS - 0.5, "passed the run out by the edge (closest to the centre %.1f m)" % min_edge)
			_check(data.is_on_road(k1.global_position), "stayed on the road (lateral %.1f m)" % _lateral(k1, data))
			_check(k1.model.speed > 8.0, "still racing (%.1f m/s)" % k1.model.speed)
			_check(rel < 0.0, "...and is past the run")
			# now the player sits on the centreline as a penguin slides through
			k1.frozen = true
			k1.global_position = Vector3(400, 0.1, 420)
			run = 1
			var q: Dictionary = pg.penguins[run]
			main.kart.frozen = false
			_park(main.kart, data.points[q.idx], data.heading_at(q.idx), q.idx)
			main.kart.launches = 0
			main.audio.played.clear()
			pg.penguins[run].t += pg.time_until_centre(run) - 0.35
			_check(pg.penguin_at(main.kart.global_position) == -1, "player on the centreline, penguin %d still sliding in" % run)
			checked = false
			stage = 4
			phys0 = Engine.get_physics_frames()
	elif stage == 4:
		var pf := Engine.get_physics_frames() - phys0
		if pf >= 40 and not checked:
			checked = true
			_check(main.kart.launches == 1, "player bumped by the penguin (launches %d)" % main.kart.launches)
			_check(main.kart.model.is_spinning(), "spinning out")
			_check(main.audio.played.has("crash"), "crash sound")
			_check(pg.knocks == 0 and not pg.is_down(run), "the penguin slides on, unbothered")
		elif pf > 140:
			_check(main.kart.launches == 1, "hit once only (%d)" % main.kart.launches)
			_check(main.kart.global_position.y < 0.6, "back on the ice (y %.2f)" % main.kart.global_position.y)
			# a green shell fired into a penguin bowls it over
			run = 2
			var q: Dictionary = pg.penguins[run]
			var idx: int = posmod(q.idx - 3, data.count)   # 9 m before the run
			pg.penguins[run].t += pg.time_until_centre(run)
			_park(main.kart, data.points[idx], data.heading_at(idx), idx)
			main.kart.model.immunity_time = 0.0
			main.kart.model.spin_time = 0.0
			main.items.holder.receive(Items.Type.SHELL, 1)
			var knocks_before: int = pg.knocks
			main.items.use_item(0)
			_check(_player_shells() == 1, "green shell fired towards penguin %d" % run)
			_check(pg.knocks == knocks_before and absf(pg.lateral(run)) < 0.1, "penguin on the centreline, not bowled over yet")
			main.audio.played.clear()
			checked = false
			stage = 5
			phys0 = Engine.get_physics_frames()
	elif stage == 5:
		var pf := Engine.get_physics_frames() - phys0
		if pf >= 30 and not checked:
			checked = true
			_check(pg.knocks == 1, "the shell bowled the penguin over (knocks %d)" % pg.knocks)
			_check(_player_shells() == 0, "the shell was spent on it")
			_check(main.audio.played.has("pop"), "pop sound")
			_check(pg.is_down(run) and pg.penguins[run].knocked > Penguins.KNOCK_TIME - 1.0, "it lies on its back (%.1f s left)" % pg.penguins[run].knocked)
			_check(absf(main.rookery.bodies[run].rotation.x - PI * 0.5) < 0.01, "...and its body is flipped over")
			_check(main.kart.launches == 1, "the player was not hit by it")
		elif pf > 40:
			# last: an AI kart down the middle through the sweeper's second run and on through the
			# snowman gate just past it (the two dodges must chain, not fight)
			main.kart.frozen = true
			main.kart.global_position = Vector3(400, 0.1, 380)
			run = 2
			var q: Dictionary = pg.penguins[run]
			var idx: int = posmod(q.idx - 12, data.count)
			var k1 = main.karts[1]
			k1.frozen = false
			_park(k1, data.points[idx], data.heading_at(idx), idx)
			k1.model.speed = 18.0
			k1.driver.lane_offset = 0.0
			k1.driver.dodging = false
			k1.driver.idx = idx
			k1.launches = 0
			pg.penguins[run].knocked = 0.0
			pg.penguins[run].t += pg.time_until_centre(run) - 2.0
			smashes = main.snowmen.smashes
			min_edge = INF
			stage = 6
			phys0 = Engine.get_physics_frames()
	elif stage == 6:
		var pf := Engine.get_physics_frames() - phys0
		var k1 = main.karts[1]
		var q: Dictionary = pg.penguins[run]
		var rel: float = pg.ahead_of(q, data.length * k1.track_index / data.count)
		if absf(rel) < 6.0:
			min_edge = minf(min_edge, absf(_lateral(k1, data)))
		if pf >= 420:
			var gate: int = int(0.915 * data.count)
			_check(min_edge > absf(q.start) + Penguins.HIT_RADIUS - 0.5, "AI kart passed the last run out by the edge (closest to the centre %.1f m)" % min_edge)
			_check(posmod(k1.track_index - gate, data.count) < 40, "...and went on through the snowman gate (sample %d, gate %d)" % [k1.track_index, gate])
			_check(k1.launches == 0, "...never hit by a penguin or a snowman (launches %d)" % k1.launches)
			_check(main.snowmen.smashes == smashes, "...no snowman smashed (%d)" % (main.snowmen.smashes - smashes))
			_check(data.is_on_road(k1.global_position) and k1.model.speed > 8.0, "still racing on the road (%.1f m/s)" % k1.model.speed)
			print("PENGUIN CHECK: ", "OK" if ok else "FAILED")
			quit(0 if ok else 1)
			return true
	return false
