extends RefCounted
## Mario Kart 64 Sherbet Land penguins on Frosty Peaks: the layout (plain and mirrored, on the ice,
## clear of everything else), the sweep across the road, the strike zone, bowling penguins over, the
## AI keeping to the edges and the rookery node.

const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const Penguins := preload("res://scripts/penguins.gd")
const Rookery := preload("res://scripts/rookery.gd")
var runner

const DT := 1.0 / 60.0
const FROSTY := 2

func test_courses_without_penguins_have_none() -> void:
	for t in TrackLibrary.count():
		if t == FROSTY:
			continue
		var d := TrackLibrary.make_data(t)
		runner.check(d.penguin_specs.is_empty(), "%s has no penguins" % TrackLibrary.info(t).name)
		var pg := Penguins.new(d)
		runner.check(not pg.active() and pg.penguins.is_empty(), "inactive penguin model")
		pg.step(DT)
		runner.check(pg.penguin_at(d.points[10]) == -1 and pg.knock_at(d.points[10]) == -1 and pg.clear_lane(10, 2.4) == 2.4, "nothing happens")
	var none := Penguins.new(null)
	runner.check(not none.active(), "no track at all: inactive")

func test_frosty_peaks_penguin_layout() -> void:
	var info := TrackLibrary.info(FROSTY)
	runner.check(info.has("penguins") and info.penguins.size() >= 3, "Frosty Peaks has penguins")
	for spec in info.penguins:
		runner.check(spec.size() == 2, "spec [fraction, start lateral]: %s" % str(spec))
	for mirror in [false, true]:
		var d := TrackLibrary.make_data(FROSTY, mirror)
		var tag := "mirrored" if mirror else "plain"
		runner.check(d.penguin_specs.size() == info.penguins.size(), "%s: every spec kept" % tag)
		var pg := Penguins.new(d)
		runner.check(pg.active() and pg.penguins.size() == info.penguins.size(), "%s: a penguin per spec" % tag)
		for i in pg.penguins.size():
			var p: Dictionary = pg.penguins[i]
			runner.check(d.ice_at(p.idx) != null, "%s: penguin %d runs on the ice (sample %d)" % [tag, i, p.idx])
			runner.check(absf(p.start) + Penguins.HIT_RADIUS < d.width * 0.5, "%s: penguin %d turns round on the road" % [tag, i])
			var reach: float = absf(p.start) + Penguins.HIT_RADIUS + Penguins.DODGE_MARGIN
			runner.check(reach <= d.width * 0.5 - Penguins.EDGE_MARGIN, "%s: penguin %d leaves an AI lane at the edge (reach %.1f)" % [tag, i, reach])
			var centre: Vector3 = d.points[p.idx]
			for pad in d.pads:
				runner.check(centre.distance_to(pad.center) > 8.0, "%s: penguin %d clear of a boost pad" % [tag, i])
			for b in d.item_box_positions:
				runner.check(centre.distance_to(b) > 8.0, "%s: penguin %d clear of an item box" % [tag, i])
			for h in d.hazard_positions:
				runner.check(centre.distance_to(h) > 8.0, "%s: penguin %d clear of a banana" % [tag, i])
			for s in d.snowman_specs:
				var si: int = int(s[0] * d.count) % d.count
				runner.check(centre.distance_to(d.points[si]) > 8.0, "%s: penguin %d clear of a snowman" % [tag, i])
			for j in pg.penguins.size():
				if j != i:
					runner.check(centre.distance_to(d.points[pg.penguins[j].idx]) > 8.0, "%s: penguins %d and %d apart" % [tag, i, j])
			runner.check(pg.penguins[i].phase != pg.penguins[(i + 1) % pg.penguins.size()].phase, "%s: neighbours out of step" % tag)
	var plain := TrackLibrary.make_data(FROSTY)
	var mir := TrackLibrary.make_data(FROSTY, true)
	for i in plain.penguin_specs.size():
		runner.check(is_equal_approx(plain.penguin_specs[i][1], -mir.penguin_specs[i][1]) and plain.penguin_specs[i][0] == mir.penguin_specs[i][0], "mirrored spec %d sets out from the other side" % i)

func test_penguins_sweep_across_the_road_and_back() -> void:
	var d := TrackLibrary.make_data(FROSTY)
	var pg := Penguins.new(d)
	var p: Dictionary = pg.penguins[0]
	p.phase = 0.0
	var start: float = p.start
	runner.check(is_equal_approx(pg.lateral(0), start), "t 0: at its start edge (%.1f)" % pg.lateral(0))
	runner.check(absf(pg.across_speed(0)) < 0.01, "...standing still there")
	runner.check(not pg.is_sliding(0), "...on its feet")
	var pos := pg.position(0)
	runner.check(d.is_on_road(pos) and absf(d.distance_to_center(pos) - absf(start)) < 0.3, "on the road %.1f m off the centreline" % d.distance_to_center(pos))
	var peak := 0.0
	var slid := false
	var frames := int(Penguins.PERIOD * 0.5 / DT)
	for f in frames:
		pg.step(DT)
		peak = maxf(peak, absf(pg.lateral(0)))
		if pg.is_sliding(0):
			slid = true
			runner.check(absf(pg.lateral(0)) < Penguins.SLIDE_FRAC * absf(start) + 0.01, "slides only through the middle")
		if f < frames / 2:
			runner.check(signf(pg.across_speed(0)) == -signf(start), "heads for the other side")
	runner.check(slid, "flopped onto its belly on the way")
	runner.check(absf(pg.lateral(0) + start) < 0.05, "half a period later: at the other edge (%.2f)" % pg.lateral(0))
	runner.check(peak <= absf(start) + 0.01, "never beyond its run (%.2f)" % peak)
	runner.check(not pg.is_sliding(0), "back on its feet at the edge")
	for f in frames:
		pg.step(DT)
	runner.check(absf(pg.lateral(0) - start) < 0.05, "a full period later: back where it set out (%.2f)" % pg.lateral(0))
	runner.check(pg.time_until_centre(0) > 0.0 and pg.time_until_centre(0) <= Penguins.PERIOD * 0.5, "time until it crosses the centre %.2f s" % pg.time_until_centre(0))
	pg.step(pg.time_until_centre(0))
	runner.check(absf(pg.lateral(0)) < 0.05, "...and it is on the centreline then (%.2f)" % pg.lateral(0))
	runner.check(absf(pg.across_speed(0)) > 4.0, "...sliding fast (%.1f m/s)" % absf(pg.across_speed(0)))

func test_strike_zone_shove_and_bowling_over() -> void:
	var d := TrackLibrary.make_data(FROSTY)
	var pg := Penguins.new(d)
	pg.step(pg.time_until_centre(1))
	var pos := pg.position(1)
	var right := d.right_of(pg.penguins[1].idx)
	runner.check(pg.penguin_at(pos) == 1, "a kart on the penguin is struck")
	runner.check(pg.penguin_at(pos + right * (Penguins.HIT_RADIUS - 0.1)) == 1, "...and just inside the strike radius")
	runner.check(pg.penguin_at(pos + right * (Penguins.HIT_RADIUS + 0.2)) == -1, "...but not just outside it")
	var shove := pg.shove_dir(1, pos + right * 0.5)
	runner.check(shove.is_equal_approx(right), "shoved away from the penguin")
	var on_top := pg.shove_dir(1, pos)
	runner.check(on_top.is_equal_approx(d.tangents[pg.penguins[1].idx]), "on top of it: shoved along the road")
	runner.check(is_zero_approx(shove.y) and is_zero_approx(on_top.y), "shoves are flat")
	var t_before: float = pg.penguins[1].t
	runner.check(pg.knock_at(pos + right * 20.0) == -1 and pg.knocks == 0, "a shell wide of it bowls nothing over")
	runner.check(pg.knock_at(pos) == 1 and pg.knocks == 1, "a shell into it bowls it over")
	runner.check(pg.is_down(1) and not pg.is_sliding(1), "...it lies on its back")
	runner.check(pg.penguin_at(pos) == -1, "...and strikes nobody while down")
	runner.check(pg.knock_at(pos) == -1 and pg.knocks == 1, "...nor can it be bowled over again")
	pg.step(Penguins.KNOCK_TIME * 0.5)
	runner.check(pg.is_down(1) and is_equal_approx(pg.penguins[1].t, t_before) and pg.position(1).is_equal_approx(pos), "half way through: still down, where it fell")
	pg.step(Penguins.KNOCK_TIME * 0.5 + DT)
	runner.check(not pg.is_down(1), "up again after KNOCK_TIME")
	runner.check(pg.penguins[1].t > t_before and pg.penguins[1].t < t_before + 3.0 * DT, "...and its sweep carries on from where it stopped")
	runner.check(pg.penguin_at(pg.position(1)) == 1, "...striking again")
	runner.check(is_equal_approx(Penguins.LAUNCH_SPEED, 3.0) and Penguins.SHOVE > 0.0, "a bump, not a launch (MK64: pushed away and spun)")

func test_ai_keeps_to_the_edges_past_a_penguin() -> void:
	var d := TrackLibrary.make_data(FROSTY)
	var pg := Penguins.new(d)
	var p: Dictionary = pg.penguins[0]
	var reach: float = absf(p.start) + Penguins.HIT_RADIUS + Penguins.DODGE_MARGIN
	var behind: int = posmod(p.idx - 6, d.count)   # 18 m before the run
	var lane := pg.clear_lane(behind, 0.0)
	runner.check(absf(lane) >= reach - 0.01 and absf(lane) <= d.width * 0.5 - Penguins.EDGE_MARGIN, "a kart down the middle is sent to the edge (%.1f)" % lane)
	runner.check(pg.clear_lane(behind, 2.0) == reach, "from the right: the right edge (%.1f)" % reach)
	runner.check(pg.clear_lane(behind, -2.0) == -reach, "from the left: the left edge")
	runner.check(pg.clear_lane(behind, reach) == reach, "already at the edge: no change")
	runner.check(pg.clear_lane(behind, 2.0, -reach) == -reach, "a dodge under way is kept")
	runner.check(pg.clear_lane(behind, 2.0, 1.0) == reach, "...unless its lane is in the run too")
	var far: int = posmod(p.idx - int(Penguins.LOOK_AHEAD / d.spacing) - 3, d.count)
	runner.check(pg.clear_lane(far, 0.0) == 0.0, "too far back to care")
	var past: int = posmod(p.idx + 2, d.count)
	runner.check(pg.clear_lane(past, 0.0) == 0.0, "past the run: own lane again")
	var any_lane := 0.0
	for i in d.count:
		if pg.clear_lane(i, 1.5, 1.5) != 1.5:
			any_lane += 1
	runner.check(any_lane > 0 and any_lane < d.count * 0.3, "dodging only near the runs (%d samples)" % any_lane)

func test_rookery_node_builds_and_poses_the_penguins() -> void:
	var d := TrackLibrary.make_data(FROSTY)
	var pg := Penguins.new(d)
	var rk := Rookery.new(pg)
	rk._ready()
	runner.check(rk.spots.size() == pg.penguins.size() and rk.bodies.size() == pg.penguins.size(), "a spot and a body per penguin")
	runner.check(rk.get_node_or_null("Spot0") != null and rk.get_node_or_null("Spot0/Penguin0") != null, "named nodes")
	var meshes := 0
	for c in rk.bodies[0].get_children():
		if c is MeshInstance3D:
			meshes += 1
	runner.check(meshes >= 8, "body, front, eyes, beak, flippers and feet (%d meshes)" % meshes)
	pg.penguins[0].phase = 0.0
	pg.penguins[0].t = 0.0
	rk.update_penguins(0.0)
	runner.check(rk.spots[0].position.is_equal_approx(pg.position(0)), "spot follows the model")
	runner.check(is_zero_approx(rk.bodies[0].rotation.x) and is_zero_approx(rk.bodies[0].position.y), "standing at the edge")
	pg.penguins[0].t = pg.time_until_centre(0) - 0.2
	for f in 12:
		rk.update_penguins(DT)
	runner.check(pg.is_sliding(0), "sliding through the middle now")
	runner.check(rk.bodies[0].rotation.x < -1.4 and absf(rk.bodies[0].position.y - Rookery.BELLY_LIFT) < 0.01, "...on its belly (pitch %.2f)" % rk.bodies[0].rotation.x)
	var fwd: Vector3 = -rk.spots[0].transform.basis.z
	var want: Vector3 = d.right_of(pg.penguins[0].idx) * signf(pg.across_speed(0))
	runner.check(fwd.dot(want) > 0.99, "faces the way it slides")
	pg.knock(0)
	rk.update_penguins(DT)
	runner.check(absf(rk.bodies[0].rotation.x - PI * 0.5) < 0.01 and absf(rk.bodies[0].position.y - Rookery.BELLY_LIFT) < 0.01, "bowled over: on its back")
	rk.free()
