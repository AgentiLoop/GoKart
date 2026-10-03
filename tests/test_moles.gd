extends RefCounted
## Mario Kart 64 Moo Moo Farm Monty Moles on Green Hills: the hole layout (plain and mirrored),
## the pop rhythm, the strike zone, knocking moles away, the AI dodging and the molehills node.

const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const Moles := preload("res://scripts/moles.gd")
const Molehills := preload("res://scripts/molehills.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
var runner

const DT := 1.0 / 60.0
const HILLS := 0

func test_courses_without_moles_have_no_holes() -> void:
	for t in TrackLibrary.count():
		if t == HILLS:
			continue
		var d := TrackLibrary.make_data(t)
		runner.check(d.mole_specs.is_empty(), "%s has no moles" % TrackLibrary.info(t).name)
		var mo := Moles.new(d)
		runner.check(not mo.active() and mo.moles.is_empty(), "inactive mole model")
		mo.step(DT)
		runner.check(mo.mole_at(d.points[10]) == -1 and mo.knock_at(d.points[10]) == -1 and mo.clear_lane(10, 2.4) == 2.4, "nothing happens")
	var none := Moles.new(null)
	runner.check(not none.active(), "no track at all: inactive")

func test_green_hills_mole_layout() -> void:
	var info := TrackLibrary.info(HILLS)
	runner.check(info.has("moles") and info.moles.size() >= 6, "Green Hills has mole holes")
	for spec in info.moles:
		runner.check(spec.size() == 2, "spec [fraction, lateral]: %s" % str(spec))
		runner.check(spec[0] > 0.05 and spec[0] < 0.9, "no hole on the grid or the line (%.3f)" % spec[0])
	for mirror in [false, true]:
		var d := TrackLibrary.make_data(HILLS, mirror)
		var tag := "mirrored" if mirror else "plain"
		runner.check(d.mole_specs.size() == info.moles.size(), "%s: every spec kept" % tag)
		var mo := Moles.new(d)
		runner.check(mo.active() and mo.moles.size() == info.moles.size(), "%s: a mole per spec" % tag)
		for i in mo.moles.size():
			var m: Dictionary = mo.moles[i]
			runner.check(d.is_on_road(m.pos), "%s: hole %d on the road" % [tag, i])
			runner.check(absf(d.distance_to_center(m.pos) - absf(m.lateral)) < 0.3, "%s: hole %d %.1f m off the centreline" % [tag, i, d.distance_to_center(m.pos)])
			runner.check(absf(m.lateral) + Moles.HIT_RADIUS < d.width * 0.5 - 1.5, "room to pass on the outside")
			for p in d.pads:
				runner.check(m.pos.distance_to(p.center) > 6.0, "%s: hole %d clear of a boost pad" % [tag, i])
			for b in d.item_box_positions:
				runner.check(m.pos.distance_to(b) > 6.0, "%s: hole %d clear of an item box" % [tag, i])
			for h in d.hazard_positions:
				runner.check(m.pos.distance_to(h) > 6.0, "%s: hole %d clear of a banana" % [tag, i])
			for j in mo.moles.size():
				if j != i:
					runner.check(m.pos.distance_to(mo.moles[j].pos) > 8.0, "%s: holes %d and %d apart" % [tag, i, j])
		# a hole 10 m ahead of another sits on the other side of the road: there is always a way through
		for i in mo.moles.size():
			for j in mo.moles.size():
				var gap := mo.ahead_of(mo.moles[j], mo.moles[i].s)
				if j != i and gap > 0.0 and gap < 15.0:
					runner.check(mo.moles[i].lateral * mo.moles[j].lateral < 0.0, "%s: holes %d -> %d stagger left / right" % [tag, i, j])
	var plain := TrackLibrary.make_data(HILLS)
	var mir := TrackLibrary.make_data(HILLS, true)
	for i in plain.mole_specs.size():
		runner.check(is_equal_approx(plain.mole_specs[i][1], -mir.mole_specs[i][1]) and plain.mole_specs[i][0] == mir.mole_specs[i][0], "mirrored spec %d" % i)

func test_moles_pop_in_a_rhythm() -> void:
	var mo := Moles.new(TrackLibrary.make_data(HILLS))
	mo.moles[0].phase = 0.0
	runner.check(is_equal_approx(mo.height(0), 0.0) and not mo.is_up(0), "t 0: underground")
	mo.step(Moles.RISE_TIME * 0.5)
	runner.check(is_equal_approx(mo.height(0), 0.5), "half way up at %.2f" % mo.height(0))
	runner.check(mo.is_up(0), "...and already dangerous")
	mo.step(Moles.RISE_TIME * 0.5 + 0.1)
	runner.check(is_equal_approx(mo.height(0), 1.0), "fully out")
	mo.step(Moles.UP_TIME - 0.1)
	runner.check(is_equal_approx(mo.height(0), 1.0), "still out at the end of UP_TIME")
	mo.step(Moles.RISE_TIME * 0.5)
	runner.check(absf(mo.height(0) - 0.5) < 0.01, "half way down (%.2f)" % mo.height(0))
	mo.step(Moles.RISE_TIME * 0.5 + 0.01)
	runner.check(is_equal_approx(mo.height(0), 0.0) and not mo.is_up(0), "back underground")
	mo.step(Moles.CYCLE - (2.0 * Moles.RISE_TIME + Moles.UP_TIME) - 0.01 + Moles.RISE_TIME)
	runner.check(is_equal_approx(mo.height(0), 1.0), "out again a cycle later")
	runner.check(Moles.UP_TIME + 2.0 * Moles.RISE_TIME < Moles.CYCLE, "the mole spends part of every cycle underground")
	# neighbouring holes are staggered: never the whole group out at once
	var fresh := Moles.new(TrackLibrary.make_data(HILLS))
	var all_up := false
	var some_up := false
	for s in 200:
		fresh.step(Moles.CYCLE / 200.0)
		var up := 0
		for i in 3:
			if fresh.is_up(i):
				up += 1
		all_up = all_up or up == 3
		some_up = some_up or up > 0
	runner.check(some_up and not all_up, "the first group of three is never all out at once")
	runner.check(fresh.moles[1].phase != fresh.moles[0].phase and fresh.moles[2].phase != fresh.moles[1].phase, "phases differ")
	# time_until_up predicts the next pop
	var t := fresh.time_until_up(2)
	runner.check(t >= 0.0 and t <= Moles.CYCLE, "time until up within a cycle (%.2f)" % t)
	fresh.step(t)
	runner.check(is_equal_approx(fresh.height(2), 1.0), "fully out after waiting for it")
	# a knocked mole stays down and pops again later
	fresh.knock(2)
	runner.check(fresh.knocks == 1 and fresh.height(2) == 0.0 and not fresh.is_up(2), "knocked: underground")
	fresh.step(Moles.KNOCK_TIME - 0.1)
	runner.check(fresh.height(2) == 0.0, "still down just before KNOCK_TIME")
	runner.check(fresh.time_until_up(2) >= 0.1 - 0.001, "time until up includes the knock time")
	fresh.step(fresh.time_until_up(2))
	runner.check(is_equal_approx(fresh.height(2), 1.0), "pops up again")

func test_strike_zone_and_shove() -> void:
	var d := TrackLibrary.make_data(HILLS)
	var mo := Moles.new(d)
	var i := 1
	mo.step(mo.time_until_up(i))
	var m: Dictionary = mo.moles[i]
	var right: Vector3 = d.right_of(m.idx)
	runner.check(mo.mole_at(m.pos) == i, "on the hole: hit")
	runner.check(mo.mole_at(m.pos + right * (Moles.HIT_RADIUS - 0.1)) == i, "inside the radius")
	runner.check(mo.mole_at(m.pos + right * (Moles.HIT_RADIUS + 0.2)) == -1, "beside it: clear")
	runner.check(mo.mole_at(m.pos + Vector3(0, 2.0, 0)) == i, "height is ignored")
	runner.check(mo.shove_dir(i, m.pos + right * 0.5).is_equal_approx(right), "shoved away from the hole")
	runner.check(mo.shove_dir(i, m.pos).is_equal_approx(d.tangents[m.idx]), "right on top: shoved along the road")
	runner.check(is_equal_approx(mo.shove_dir(i, m.pos - right * 0.3 + Vector3(0, 1, 0)).length(), 1.0) and mo.shove_dir(i, m.pos - right * 0.3).y == 0.0, "unit, flat")
	# a mole that is underground does not strike
	var down := -1
	for j in mo.moles.size():
		if not mo.is_up(j):
			down = j
	runner.check(down >= 0 and mo.mole_at(mo.moles[down].pos) == -1, "a mole underground is harmless")
	# the centreline between the staggered holes is always clear
	for j in mo.moles.size():
		runner.check(mo.mole_at(d.points[mo.moles[j].idx]) == -1, "centreline clear beside hole %d" % j)
	# a shell flying over the hole knocks the mole away
	runner.check(mo.knock_at(m.pos + right * 0.5, 1.9) == i and mo.knocks == 1, "knocked by a shell")
	runner.check(mo.mole_at(m.pos) == -1, "...and gone")
	runner.check(mo.knock_at(m.pos) == -1 and mo.knocks == 1, "a second shell finds nothing")
	runner.check(is_equal_approx(Moles.LAUNCH_SPEED, 7.0) and Moles.LAUNCH_SPEED < 10.0, "a gentler launch than the traffic")

func test_ai_steers_round_the_holes() -> void:
	var d := TrackLibrary.make_data(HILLS)
	var mo := Moles.new(d)
	mo.moles.clear()
	var per: float = d.length / d.count
	runner.check(mo.clear_lane(50, -2.4) == -2.4 and mo.clear_lane(50, 2.4) == 2.4, "no holes: own lane")
	var hole: Dictionary = {"pos": d.points[58] + d.right_of(58) * -3.0, "idx": 58, "lateral": -3.0, "s": 58 * per, "phase": 0.0, "knocked": 0.0}
	mo.moles.append(hole)
	var lo: float = hole.lateral - Moles.HIT_RADIUS - Moles.DODGE_MARGIN
	var hi: float = hole.lateral + Moles.HIT_RADIUS + Moles.DODGE_MARGIN
	runner.check(mo.clear_lane(50, 2.4) == 2.4, "right lane unaffected")
	var dodge := mo.clear_lane(50, -2.4)
	runner.check(dodge != -2.4 and (dodge <= lo or dodge >= hi), "left lane blocked: dodges to %.1f" % dodge)
	runner.check(is_equal_approx(dodge, hi), "...to the hole's inner edge (nearest free spot)")
	runner.check(absf(dodge) <= d.width * 0.5 - Moles.EDGE_MARGIN, "still well on the road")
	runner.check(mo.clear_lane(50, -2.4, dodge) == dodge, "keeps the dodge it is on")
	runner.check(mo.clear_lane(50, -2.4, 0.0) == 0.0, "a free current aim is kept too")
	runner.check(mo.clear_lane(50, -2.4, 7.5) != 7.5, "but not past the edge margin")
	runner.check(mo.clear_lane(50, -2.4) == dodge, "a mole underground still counts: it may pop as the kart arrives")
	hole.s = 50 * per + Moles.LOOK_AHEAD + 3.0
	runner.check(mo.clear_lane(50, -2.4) == -2.4, "a hole beyond LOOK_AHEAD is ignored")
	hole.s = 50 * per - 4.0
	runner.check(mo.clear_lane(50, -2.4) == -2.4, "a hole behind is ignored")
	hole.s = 50 * per - 0.5
	runner.check(mo.clear_lane(50, -2.4) != -2.4, "a hole alongside still counts")
	# the real Green Hills layout: from either lane there is always somewhere to go
	var real := Moles.new(d)
	for idx in range(0, d.count, 2):
		for lane in [-2.4, 2.4]:
			var l: float = real.clear_lane(idx, lane)
			runner.check(absf(l) <= d.width * 0.5 - Moles.EDGE_MARGIN, "sample %d lane %.1f: aim %.1f on the road" % [idx, lane, l])
			for m in real.moles:
				var rel := real.ahead_of(m, d.length * idx / d.count)
				if rel > 0.0 and rel < Moles.LOOK_AHEAD:
					runner.check(absf(l - m.lateral) >= Moles.HIT_RADIUS + Moles.DODGE_MARGIN - 0.01, "sample %d lane %.1f: clears hole at %.1f" % [idx, lane, m.lateral])
	# the driver aims at the dodge lane while dodging
	var drv := AiDriver.new(d, -2.4, 1.0)
	var pos: Vector3 = d.points[50] + d.right_of(50) * -2.4
	var head: float = d.heading_at(50)
	var straight: Dictionary = drv.decide(DT, pos, head, 20.0)
	drv.dodging = true
	drv.dodge_lane = hi
	var away: Dictionary = drv.decide(DT, pos, head, 20.0)
	runner.check(away.steer > straight.steer + 0.1, "steers right towards the dodge lane (%.2f vs %.2f)" % [away.steer, straight.steer])

func test_molehills_node_builds_and_moves_the_moles() -> void:
	var d := TrackLibrary.make_data(HILLS)
	var mo := Moles.new(d)
	var mh = Molehills.new(mo)
	mh._ready()   # not in a tree during _initialize
	runner.check(mh.bodies.size() == mo.moles.size() and mh.get_child_count() == mo.moles.size(), "a hole per mole")
	for i in mo.moles.size():
		var hole: Node3D = mh.get_child(i)
		var body: Node3D = mh.bodies[i]
		runner.check(hole.name == "Hole%d" % i and body.name == "Mole%d" % i and body.get_parent() == hole, "named per index")
		runner.check(hole.position.is_equal_approx(mo.moles[i].pos), "hole %d on its spot" % i)
		var meshes := 0
		for ch in body.get_children():
			if ch is MeshInstance3D:
				meshes += 1
		runner.check(meshes >= 6, "body, snout, nose, shades and paws (%d meshes)" % meshes)
		var h: float = mo.height(i)
		runner.check(is_equal_approx(body.position.y, -Molehills.RISE + Molehills.RISE * h), "mole %d at its height" % i)
		runner.check(body.visible == (h > 0.0), "hidden while underground")
		var fwd: Vector3 = -d.tangents[mo.moles[i].idx]
		runner.check(is_equal_approx(hole.rotation.y, atan2(-fwd.x, -fwd.z)), "faces the oncoming racers")
	var i := 0
	mh.update_moles(mo.time_until_up(i))
	runner.check(is_equal_approx(mh.bodies[i].position.y, 0.0) and mh.bodies[i].visible, "fully out: body at ground level")
	mo.knock(i)
	mh.update_moles(0.0)
	runner.check(is_equal_approx(mh.bodies[i].position.y, -Molehills.RISE) and not mh.bodies[i].visible, "knocked: back down and hidden")
	mh.free()
