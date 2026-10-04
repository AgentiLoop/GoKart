extends RefCounted
## Mario Kart 64 Frappe Snowland snowmen on Frosty Peaks: the layout (plain and mirrored), smashing
## and growing back, the strike zone, the AI weaving through the rows and the snowfield node.

const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const Snowmen := preload("res://scripts/snowmen.gd")
const Snowfield := preload("res://scripts/snowfield.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
var runner

const DT := 1.0 / 60.0
const PEAKS := 2

func test_courses_without_snowmen_have_none() -> void:
	for t in TrackLibrary.count():
		if t == PEAKS:
			continue
		var d := TrackLibrary.make_data(t)
		runner.check(d.snowman_specs.is_empty(), "%s has no snowmen" % TrackLibrary.info(t).name)
		var sn := Snowmen.new(d)
		runner.check(not sn.active() and sn.snowmen.is_empty(), "inactive snowman model")
		sn.step(DT)
		runner.check(sn.snowman_at(d.points[10]) == -1 and sn.smash_at(d.points[10]) == -1 and sn.clear_lane(10, 2.4) == 2.4, "nothing happens")
	var none := Snowmen.new(null)
	runner.check(not none.active(), "no track at all: inactive")

func test_frosty_peaks_snowman_layout() -> void:
	var info := TrackLibrary.info(PEAKS)
	runner.check(info.has("snowmen") and info.snowmen.size() >= 10, "Frosty Peaks has a field of snowmen")
	for spec in info.snowmen:
		runner.check(spec.size() == 2, "spec [fraction, lateral]: %s" % str(spec))
		runner.check(spec[0] > 0.05 and spec[0] < 0.93, "no snowman on the grid or the line (%.3f)" % spec[0])
	for mirror in [false, true]:
		var d := TrackLibrary.make_data(PEAKS, mirror)
		var tag := "mirrored" if mirror else "plain"
		runner.check(d.snowman_specs.size() == info.snowmen.size(), "%s: every spec kept" % tag)
		var sn := Snowmen.new(d)
		runner.check(sn.active() and sn.snowmen.size() == info.snowmen.size(), "%s: a snowman per spec" % tag)
		for i in sn.snowmen.size():
			var sm: Dictionary = sn.snowmen[i]
			runner.check(d.is_on_road(sm.pos), "%s: snowman %d on the road" % [tag, i])
			runner.check(absf(d.distance_to_center(sm.pos) - absf(sm.lateral)) < 0.3, "%s: snowman %d %.1f m off the centreline" % [tag, i, d.distance_to_center(sm.pos)])
			runner.check(absf(sm.lateral) + Snowmen.HIT_RADIUS < d.width * 0.5 - 1.5, "room to pass on the outside")
			for p in d.pads:
				runner.check(sm.pos.distance_to(p.center) > 6.0, "%s: snowman %d clear of a boost pad" % [tag, i])
			for b in d.item_box_positions:
				runner.check(sm.pos.distance_to(b) > 6.0, "%s: snowman %d clear of an item box" % [tag, i])
			for h in d.hazard_positions:
				runner.check(sm.pos.distance_to(h) > 6.0, "%s: snowman %d clear of a banana" % [tag, i])
			runner.check(not d.in_water(sm.pos, sm.idx) and d.has_wall(sm.idx, -1) and d.has_wall(sm.idx, 1), "%s: snowman %d not by the water" % [tag, i])
			for j in sn.snowmen.size():
				if j != i:
					runner.check(sm.pos.distance_to(sn.snowmen[j].pos) > 2.0 * Snowmen.HIT_RADIUS + 2.0, "%s: snowmen %d and %d apart" % [tag, i, j])
		# every row leaves a way through: from both lanes, at every second sample, clear_lane finds a
		# spot on the road that clears the nearest row of snowmen
		for idx in range(0, d.count, 2):
			for lane in [-2.4, 2.4]:
				var l: float = sn.clear_lane(idx, lane)
				runner.check(absf(l) <= d.width * 0.5 - Snowmen.EDGE_MARGIN, "%s: sample %d lane %.1f: aim %.1f on the road" % [tag, idx, lane, l])
				var s_k: float = d.length * idx / d.count
				var nearest := INF
				for sm in sn.snowmen:
					var rel := sn.ahead_of(sm, s_k)
					if rel > -Snowmen.HIT_RADIUS and rel < Snowmen.LOOK_AHEAD:
						nearest = minf(nearest, rel)
				for sm in sn.snowmen:
					var rel := sn.ahead_of(sm, s_k)
					if nearest < INF and rel > -Snowmen.HIT_RADIUS and rel <= nearest + Snowmen.ROW_DEPTH:
						runner.check(absf(l - sm.lateral) >= Snowmen.HIT_RADIUS + Snowmen.DODGE_MARGIN - 0.01, "%s: sample %d lane %.1f: aim %.1f clears the snowman at %.1f" % [tag, idx, lane, l, sm.lateral])
	var plain := TrackLibrary.make_data(PEAKS)
	var mir := TrackLibrary.make_data(PEAKS, true)
	for i in plain.snowman_specs.size():
		runner.check(is_equal_approx(plain.snowman_specs[i][1], -mir.snowman_specs[i][1]) and plain.snowman_specs[i][0] == mir.snowman_specs[i][0], "mirrored spec %d" % i)

func test_smashed_snowmen_grow_back() -> void:
	var sn := Snowmen.new(TrackLibrary.make_data(PEAKS))
	runner.check(is_equal_approx(sn.height(0), 1.0) and sn.is_standing(0), "whole to begin with")
	sn.step(1.0)
	runner.check(is_equal_approx(sn.height(0), 1.0), "...and stays whole")
	sn.smash(0)
	runner.check(sn.smashes == 1 and sn.height(0) == 0.0 and not sn.is_standing(0), "smashed: flat")
	sn.step(Snowmen.REBUILD_TIME - Snowmen.GROW_TIME - 0.1)
	runner.check(sn.height(0) == 0.0, "still flat before it starts to grow")
	sn.step(0.1 + Snowmen.GROW_TIME * 0.5)
	runner.check(absf(sn.height(0) - 0.5) < 0.01, "half grown (%.2f)" % sn.height(0))
	runner.check(not sn.is_standing(0), "...not yet in the way")
	sn.step(Snowmen.GROW_TIME * 0.5)
	runner.check(is_equal_approx(sn.height(0), 1.0) and sn.is_standing(0), "whole again after REBUILD_TIME")
	runner.check(Snowmen.STAND_HEIGHT > 0.0 and Snowmen.STAND_HEIGHT < 1.0 and Snowmen.GROW_TIME < Snowmen.REBUILD_TIME, "constants make sense")
	runner.check(sn.height(1) == 1.0, "the others were untouched")

func test_strike_zone_and_shove() -> void:
	var d := TrackLibrary.make_data(PEAKS)
	var sn := Snowmen.new(d)
	var i := 1
	var sm: Dictionary = sn.snowmen[i]
	var right: Vector3 = d.right_of(sm.idx)
	runner.check(sn.snowman_at(sm.pos) == i, "on the snowman: hit")
	runner.check(sn.snowman_at(sm.pos + right * (Snowmen.HIT_RADIUS - 0.1)) == i, "inside the radius")
	runner.check(sn.snowman_at(sm.pos + right * (Snowmen.HIT_RADIUS + 0.2)) == -1, "beside it: clear")
	runner.check(sn.snowman_at(sm.pos + Vector3(0, 2.0, 0)) == i, "height is ignored")
	runner.check(sn.shove_dir(i, sm.pos + right * 0.5).is_equal_approx(right), "shoved away from the snowman")
	runner.check(sn.shove_dir(i, sm.pos).is_equal_approx(d.tangents[sm.idx]), "right on top: shoved along the road")
	runner.check(is_equal_approx(sn.shove_dir(i, sm.pos - right * 0.3 + Vector3(0, 1, 0)).length(), 1.0) and sn.shove_dir(i, sm.pos - right * 0.3).y == 0.0, "unit, flat")
	# the centreline is clear beside the snowmen by the edges (rows without one near the middle)
	var checked := 0
	for j in sn.snowmen.size():
		var middle := false
		for k in sn.snowmen:
			if k.idx == sn.snowmen[j].idx and absf(k.lateral) <= Snowmen.HIT_RADIUS + 0.1:
				middle = true
		if not middle:
			checked += 1
			runner.check(sn.snowman_at(d.points[sn.snowmen[j].idx]) == -1, "centreline clear beside snowman %d" % j)
	runner.check(checked >= 6, "most rows leave the middle free (%d)" % checked)
	# a shell flying into it smashes it
	runner.check(sn.smash_at(sm.pos + right * 0.5, 1.9) == i and sn.smashes == 1, "smashed by a shell")
	runner.check(sn.snowman_at(sm.pos) == -1, "...and gone")
	runner.check(sn.smash_at(sm.pos) == -1 and sn.smashes == 1, "a second shell finds nothing")
	runner.check(Snowmen.LAUNCH_SPEED > 7.0 and Snowmen.LAUNCH_SPEED < 10.0, "thrown harder than by a mole, less than by the traffic")

func test_ai_weaves_through_the_rows() -> void:
	var d := TrackLibrary.make_data(PEAKS)
	var sn := Snowmen.new(d)
	sn.snowmen.clear()
	var per: float = d.length / d.count
	runner.check(sn.clear_lane(50, -2.4) == -2.4 and sn.clear_lane(50, 2.4) == 2.4, "no snowmen: own lane")
	var add := func(idx: int, lateral: float) -> Dictionary:
		var sm: Dictionary = {"pos": d.points[idx] + d.right_of(idx) * lateral, "idx": idx, "lateral": lateral, "s": idx * per, "down": 0.0}
		sn.snowmen.append(sm)
		return sm
	var one: Dictionary = add.call(58, -3.0)
	var lo: float = one.lateral - Snowmen.HIT_RADIUS - Snowmen.DODGE_MARGIN
	var hi: float = one.lateral + Snowmen.HIT_RADIUS + Snowmen.DODGE_MARGIN
	runner.check(sn.clear_lane(50, 2.4) == 2.4, "right lane unaffected")
	var dodge := sn.clear_lane(50, -2.4)
	runner.check(dodge != -2.4 and (dodge <= lo or dodge >= hi), "left lane blocked: dodges to %.1f" % dodge)
	runner.check(is_equal_approx(dodge, hi), "...to the snowman's inner edge (nearest free spot)")
	runner.check(absf(dodge) <= d.width * 0.5 - Snowmen.EDGE_MARGIN, "still well on the road")
	runner.check(sn.clear_lane(50, -2.4, dodge) == dodge, "keeps the dodge it is on")
	runner.check(sn.clear_lane(50, -2.4, 0.0) == 0.0, "a free current aim is kept too")
	runner.check(sn.clear_lane(50, -2.4, 7.5) != 7.5, "but not past the edge margin")
	one.down = Snowmen.REBUILD_TIME
	runner.check(sn.clear_lane(50, -2.4) == dodge, "a smashed snowman still counts: it grows back as the kart arrives")
	one.down = 0.0
	one.s = 50 * per + Snowmen.LOOK_AHEAD + 3.0
	runner.check(sn.clear_lane(50, -2.4) == -2.4, "a snowman beyond LOOK_AHEAD is ignored")
	one.s = 50 * per - 4.0
	runner.check(sn.clear_lane(50, -2.4) == -2.4, "a snowman behind is ignored")
	one.s = 50 * per - 0.5
	runner.check(sn.clear_lane(50, -2.4) != -2.4, "a snowman alongside still counts")
	# two rows: the kart picks the spot that clears the nearest row with the least movement in all,
	# so it ends up (almost) clear of the row behind as well
	one.s = 58 * per
	add.call(62, 2.4)   # 12 m behind the first, right in the right lane
	var through := sn.clear_lane(50, -2.4)
	runner.check(through >= hi and absf(through - 2.4) >= Snowmen.HIT_RADIUS + Snowmen.DODGE_MARGIN - 0.5, "clears the first row and nearly the second at %.1f" % through)
	runner.check(sn.clear_lane(50, 2.4) != 2.4, "the right lane moves early for the second row")
	# a row the kart cannot pass at all: it still clears the nearest row, taking the nearest spot
	sn.snowmen.clear()
	add.call(58, -3.0)
	add.call(60, 4.0)    # same row (6 m behind): gap at the centre
	add.call(66, 0.0)    # next row blocks the gap
	var pick := sn.clear_lane(50, -2.4)
	runner.check(absf(pick + 3.0) >= Snowmen.HIT_RADIUS + Snowmen.DODGE_MARGIN - 0.01 and absf(pick - 4.0) >= Snowmen.HIT_RADIUS + Snowmen.DODGE_MARGIN - 0.01, "clears the nearest row (%.1f)" % pick)
	# a row with no way through at all: the kart keeps its lane
	sn.snowmen.clear()
	for lat in [-5.0, -1.5, 2.0, 5.5]:
		add.call(58, lat)
	runner.check(sn.clear_lane(50, -2.4) == -2.4, "nothing free: own lane")
	# the driver aims at the dodge lane while dodging
	var drv := AiDriver.new(d, -2.4, 1.0)
	var pos: Vector3 = d.points[50] + d.right_of(50) * -2.4
	var head: float = d.heading_at(50)
	var straight: Dictionary = drv.decide(DT, pos, head, 20.0)
	drv.dodging = true
	drv.dodge_lane = hi
	var away: Dictionary = drv.decide(DT, pos, head, 20.0)
	runner.check(away.steer > straight.steer + 0.1, "steers right towards the dodge lane (%.2f vs %.2f)" % [away.steer, straight.steer])

func test_snowfield_node_builds_and_bursts_the_snowmen() -> void:
	var d := TrackLibrary.make_data(PEAKS)
	var sn := Snowmen.new(d)
	var sf = Snowfield.new(sn)
	sf._ready()   # not in a tree during _initialize
	runner.check(sf.bodies.size() == sn.snowmen.size() and sf.puffs.size() == sn.snowmen.size() and sf.get_child_count() == sn.snowmen.size(), "a spot per snowman")
	for i in sn.snowmen.size():
		var spot: Node3D = sf.get_child(i)
		var body: Node3D = sf.bodies[i]
		runner.check(spot.name == "Spot%d" % i and body.name == "Snowman%d" % i and body.get_parent() == spot, "named per index")
		runner.check(spot.position.is_equal_approx(sn.snowmen[i].pos), "snowman %d on its spot" % i)
		var meshes := 0
		var top := 0.0
		for ch in body.get_children():
			if ch is MeshInstance3D:
				meshes += 1
				top = maxf(top, ch.position.y)
		runner.check(meshes >= 10, "snowballs, eyes, buttons, nose, scarf, hat and arms (%d meshes)" % meshes)
		runner.check(top > Snowfield.HEIGHT and top < Snowfield.HEIGHT + 0.5, "the hat sits on top (%.2f)" % top)
		runner.check(body.scale.is_equal_approx(Vector3.ONE) and body.visible, "whole: full size")
		runner.check(not sf.puffs[i].visible and sf.puffs[i].get_child_count() == Snowfield.PUFF_COUNT, "no puff showing")
		var fwd: Vector3 = -d.tangents[sn.snowmen[i].idx]
		runner.check(is_equal_approx(spot.rotation.y, atan2(-fwd.x, -fwd.z)), "faces the oncoming racers")
	var i := 0
	sn.smash(i)
	sf.update_snowmen(0.0)
	runner.check(not sf.bodies[i].visible and sf.bodies[i].scale.x < 0.01, "smashed: gone")
	runner.check(sf.puffs[i].visible, "...in a puff of snow")
	var first: Vector3 = sf.puffs[i].get_child(0).position
	sf.update_snowmen(Snowfield.PUFF_TIME * 0.5)
	var later: Vector3 = sf.puffs[i].get_child(0).position
	runner.check(sf.puffs[i].visible and Vector2(later.x, later.z).length() > Vector2(first.x, first.z).length(), "the snowballs fly outwards")
	runner.check(sf.puffs[i].get_child(0).scale.x < 0.6, "...and shrink")
	sf.update_snowmen(Snowfield.PUFF_TIME * 0.5 + 0.01)
	runner.check(not sf.puffs[i].visible, "puff over")
	runner.check(not sf.puffs[1].visible and sf.bodies[1].visible, "the next snowman is untouched")
	var elapsed: float = Snowfield.PUFF_TIME + 0.01   # model time the puff steps above used up
	sf.update_snowmen(Snowmen.REBUILD_TIME - Snowmen.GROW_TIME * 0.5 - elapsed)
	runner.check(sf.bodies[i].visible and sf.bodies[i].scale.x > 0.3 and sf.bodies[i].scale.x < 0.7, "growing back (%.2f)" % sf.bodies[i].scale.x)
	sf.update_snowmen(Snowmen.GROW_TIME)
	runner.check(sf.bodies[i].scale.is_equal_approx(Vector3.ONE) and not sf.puffs[i].visible, "whole again, no second puff")
	sf.free()
