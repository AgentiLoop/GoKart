extends RefCounted
## Mario Kart 64 Toad's Turnpike traffic on Sunset Speedway: the vehicle layout (plain and
## mirrored), their movement and speed by engine class, the strike zone, the AI dodging and the
## highway node.

const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const Traffic := preload("res://scripts/traffic.gd")
const Highway := preload("res://scripts/highway.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
var runner

const DT := 1.0 / 60.0
const SPEEDWAY := 1

func test_courses_without_traffic_have_no_vehicles() -> void:
	for t in TrackLibrary.count():
		if t == SPEEDWAY:
			continue
		var d := TrackLibrary.make_data(t)
		runner.check(d.traffic_specs.is_empty(), "%s has no traffic" % TrackLibrary.info(t).name)
		var tr := Traffic.new(d)
		runner.check(not tr.active() and tr.vehicles.is_empty(), "inactive traffic model")
		tr.step(DT)
		runner.check(tr.hit_dir(d.points[10]) == Vector3.ZERO and tr.clear_lane(10, 2.4) == 2.4, "nothing happens")
	var none := Traffic.new(null)
	runner.check(not none.active(), "no track at all: inactive")

func test_sunset_speedway_traffic_layout() -> void:
	var info := TrackLibrary.info(SPEEDWAY)
	runner.check(info.has("traffic") and info.traffic.size() >= 8, "the speedway has traffic")
	for spec in info.traffic:
		runner.check(spec.size() == 3 and Traffic.KINDS.has(spec[2]), "spec [fraction, lane, kind]: %s" % str(spec))
		runner.check(spec[0] > 0.03 and spec[0] < 0.9, "no vehicle starts on the grid or the line (%.2f)" % spec[0])
	var kinds := {}
	for spec in info.traffic:
		kinds[spec[2]] = true
	runner.check(kinds.size() == 4, "cars, buses, trucks and tankers all appear")
	for mirror in [false, true]:
		var d := TrackLibrary.make_data(SPEEDWAY, mirror)
		var tag := "mirrored" if mirror else "plain"
		runner.check(d.traffic_specs.size() == info.traffic.size(), "%s: every spec kept" % tag)
		var tr := Traffic.new(d)
		runner.check(tr.active() and tr.vehicles.size() == info.traffic.size(), "%s: a vehicle per spec" % tag)
		runner.check(tr.dir == (-1 if mirror else 1), "%s: traffic drives %s the racers" % [tag, "against" if mirror else "with"])
		var lanes := {}
		for i in tr.vehicles.size():
			var v: Dictionary = tr.vehicles[i]
			var p := tr.vehicle_pose(i)
			runner.check(d.is_on_road(p.pos), "%s: vehicle %d on the road" % [tag, i])
			runner.check(absf(absf(d.distance_to_center(p.pos)) - absf(v.lane)) < 0.3, "%s: vehicle %d in its lane (%.1f m)" % [tag, i, d.distance_to_center(p.pos)])
			runner.check(absf(v.lane) + v.half_width < d.width * 0.5 - 1.5, "room to pass on the outside")
			runner.check(is_equal_approx(v.length, Traffic.KINDS[v.kind].length), "size from the kind")
			runner.check(p.dir.dot(d.tangents[d.nearest_index(p.pos)] * tr.dir) > 0.95, "faces along its direction of travel")
			lanes[v.lane] = lanes.get(v.lane, []) + [v]
		runner.check(lanes.size() == 2, "%s: two lanes" % tag)
		for lane in lanes:
			var vs: Array = lanes[lane]
			# same speed in a lane, so vehicles never catch each other; spaced further apart than they are long
			for v in vs:
				runner.check(is_equal_approx(v.speed, vs[0].speed), "%s: lane %.1f shares one speed" % [tag, lane])
			for a in vs:
				for b in vs:
					if a != b:
						var gap := absf(tr.ahead_of(a, b.s))
						runner.check(gap > (a.length + b.length) * 0.5 + 10.0, "%s: vehicles %.0f m apart in lane %.1f" % [tag, gap, lane])
		# the slow lane is the one on the vehicles' own right
		for v in tr.vehicles:
			var slow: bool = v.lane * tr.dir > 0.0
			runner.check(is_equal_approx(v.speed, tr.speed * (Traffic.SLOW_LANE if slow else 1.0)), "%s: lane %.1f is the %s lane" % [tag, v.lane, "slow" if slow else "fast"])
	# mirrored lanes are the mirror image, kinds kept
	var plain := TrackLibrary.make_data(SPEEDWAY)
	var mir := TrackLibrary.make_data(SPEEDWAY, true)
	for i in plain.traffic_specs.size():
		runner.check(is_equal_approx(plain.traffic_specs[i][1], -mir.traffic_specs[i][1]) and plain.traffic_specs[i][2] == mir.traffic_specs[i][2] and plain.traffic_specs[i][0] == mir.traffic_specs[i][0], "mirrored spec %d" % i)
	runner.check(TrackData.mirror_specs([[0.2, 3.0, "bus"]]) == [[0.2, -3.0, "bus"]] and TrackData.mirror_specs([[0.2, 3.0]]) == [[0.2, -3.0]], "mirror_specs keeps extra elements")

func test_traffic_moves_with_the_engine_class() -> void:
	var d := TrackLibrary.make_data(SPEEDWAY)
	for e in TrackLibrary.ENGINE_CLASSES.size():
		var info: Dictionary = TrackLibrary.engine_info(e)
		var data := TrackLibrary.make_data(SPEEDWAY, info.mirror)
		var tr := Traffic.new(data, info.speed)
		runner.check(is_equal_approx(tr.speed, Traffic.SPEED_150 * info.speed), "%s: fast lane %.1f m/s" % [info.name, tr.speed])
		var s0: float = tr.vehicles[0].s
		tr.step(1.0)
		var moved: float = tr.ahead_of(tr.vehicles[0], s0)
		runner.check(is_equal_approx(moved, tr.vehicles[0].speed * tr.dir), "%s: moved %.1f m in a second (%s)" % [info.name, moved, "against" if tr.dir < 0 else "with"])
		runner.check(is_equal_approx(tr.time, 1.0))
	var tr50 := Traffic.new(d, TrackLibrary.engine_info(0).speed)
	var tr150 := Traffic.new(d, TrackLibrary.engine_info(2).speed)
	var extra := Traffic.new(TrackLibrary.make_data(SPEEDWAY, true), TrackLibrary.engine_info(3).speed)
	runner.check(tr50.speed < tr150.speed, "slower in 50cc")
	runner.check(is_equal_approx(extra.speed, tr150.speed) and extra.dir == -1, "Extra: 150cc speed, oncoming")
	# wraps round the lap
	var tr := Traffic.new(d)
	tr.vehicles[0].s = d.length - 1.0
	tr.step(1.0)
	runner.check(tr.vehicles[0].s >= 0.0 and tr.vehicles[0].s < tr.vehicles[0].speed, "wraps at the line: %.1f" % tr.vehicles[0].s)
	# road poses follow the centreline
	var p0 := tr.road_pose(0.0, 0.0)
	runner.check(p0.pos.is_equal_approx(d.points[0]) and p0.dir.is_equal_approx(d.tangents[0]), "pose at the line")
	var mid := tr.road_pose(d.length * 0.4, 3.0)
	runner.check(absf(d.distance_to_center(mid.pos) - 3.0) < 0.2 and is_equal_approx(mid.dir.length(), 1.0), "pose part way round, 3 m right")
	runner.check(tr.road_pose(d.length + 5.0, 0.0).pos.is_equal_approx(tr.road_pose(5.0, 0.0).pos), "metres wrap")

func test_strike_zone_is_the_vehicle() -> void:
	var d := TrackLibrary.make_data(SPEEDWAY)
	var tr := Traffic.new(d)
	var i := 0
	for k in tr.vehicles.size():
		if tr.vehicles[k].kind == "bus":
			i = k
	var v: Dictionary = tr.vehicles[i]
	var p := tr.vehicle_pose(i)
	var dir: Vector3 = p.dir
	var right := Vector3(-dir.z, 0, dir.x)
	runner.check(tr.hit_dir(p.pos).is_equal_approx(dir), "inside the bus: hit, along its direction")
	runner.check(tr.hit_dir(p.pos + right * (v.half_width - 0.1)) != Vector3.ZERO and tr.hit_dir(p.pos - right * (v.half_width - 0.1)) != Vector3.ZERO, "across the bus")
	runner.check(tr.hit_dir(p.pos + right * (v.half_width + 0.3)) == Vector3.ZERO, "beside it: clear")
	runner.check(tr.hit_dir(p.pos + dir * (v.length * 0.5 - 0.2)) != Vector3.ZERO, "the bumper")
	runner.check(tr.hit_dir(p.pos + dir * (v.length * 0.5 + 0.3)) == Vector3.ZERO, "ahead of it: clear")
	runner.check(tr.hit_dir(p.pos + Vector3(0, 3.0, 0)) != Vector3.ZERO, "height is ignored")
	# the centre of the road between the lanes is clear of every vehicle
	for s in 20:
		var c := tr.road_pose(d.length * s / 20.0, 0.0)
		runner.check(tr.hit_dir(c.pos) == Vector3.ZERO, "centreline clear at %d/20" % s)
	# mirrored: struck along the oncoming direction
	var mir := Traffic.new(TrackLibrary.make_data(SPEEDWAY, true))
	var mp := mir.vehicle_pose(0)
	runner.check(mir.hit_dir(mp.pos).is_equal_approx(mp.dir) and mp.dir.dot(mir.track.tangents[mir.track.nearest_index(mp.pos)]) < -0.9, "oncoming vehicle shoves backwards")

func test_ai_steers_round_the_traffic() -> void:
	var d := TrackLibrary.make_data(SPEEDWAY)
	var tr := Traffic.new(d)
	tr.vehicles.clear()
	var per: float = d.length / d.count
	runner.check(tr.clear_lane(50, -2.4) == -2.4 and tr.clear_lane(50, 2.4) == 2.4, "empty road: own lane")
	# a bus 25 m ahead in the left lane
	var bus: Dictionary = {"kind": "bus", "lane": -4.4, "s": 50 * per + 25.0, "length": 9.0, "half_width": 1.3, "height": 3.0, "speed": 10.0}
	tr.vehicles.append(bus)
	var lo: float = bus.lane - bus.half_width - Traffic.DODGE_MARGIN
	var hi: float = bus.lane + bus.half_width + Traffic.DODGE_MARGIN
	runner.check(tr.clear_lane(50, 2.4) == 2.4, "right lane unaffected")
	var dodge := tr.clear_lane(50, -2.4)
	runner.check(dodge != -2.4 and (dodge <= lo or dodge >= hi), "left lane blocked: dodges to %.1f" % dodge)
	runner.check(is_equal_approx(dodge, hi), "...to the bus's inner edge (nearest free spot)")
	runner.check(absf(dodge) <= d.width * 0.5 - Traffic.EDGE_MARGIN, "still well on the road")
	runner.check(tr.clear_lane(50, -2.4, dodge) == dodge, "keeps the dodge it is on")
	runner.check(tr.clear_lane(50, -2.4, 0.0) == 0.0, "a free current aim is kept too")
	runner.check(tr.clear_lane(50, -2.4, 5.0) == 5.0, "the other lane is fine as well")
	runner.check(tr.clear_lane(50, -2.4, 7.5) != 7.5, "but not past the edge margin")
	# too far ahead / behind: ignored
	bus.s = 50 * per + Traffic.LOOK_AHEAD + 6.0
	runner.check(tr.clear_lane(50, -2.4) == -2.4, "a bus beyond LOOK_AHEAD is ignored")
	bus.s = 50 * per - 8.0
	runner.check(tr.clear_lane(50, -2.4) == -2.4, "a bus behind is ignored")
	bus.s = 50 * per - 3.0
	runner.check(tr.clear_lane(50, -2.4) != -2.4, "a bus alongside still counts")
	# two vehicles side by side: thread the gap between them
	bus.s = 50 * per + 20.0
	var car: Dictionary = {"kind": "car", "lane": 4.4, "s": 50 * per + 22.0, "length": 4.2, "half_width": 1.0, "height": 1.5, "speed": 10.0}
	tr.vehicles.append(car)
	var gap := tr.clear_lane(50, -2.4)
	runner.check(gap > hi - 0.01 and gap < car.lane - car.half_width - Traffic.DODGE_MARGIN + 0.01, "threads the gap at %.1f" % gap)
	runner.check(tr.clear_lane(50, 2.4) > lo and tr.clear_lane(50, 2.4) < car.lane - car.half_width - Traffic.DODGE_MARGIN + 0.01, "from the right lane too")
	# oncoming traffic is seen from further away
	var mir := Traffic.new(TrackLibrary.make_data(SPEEDWAY, true))
	mir.vehicles.clear()
	var mper: float = mir.track.length / mir.track.count
	mir.vehicles.append({"kind": "bus", "lane": 4.4, "s": 50 * mper + Traffic.LOOK_AHEAD + 10.0, "length": 9.0, "half_width": 1.3, "height": 3.0, "speed": 10.0})
	runner.check(mir.clear_lane(50, 2.4) != 2.4, "Extra: an oncoming bus %d m out already matters" % int(Traffic.LOOK_AHEAD + 10.0))
	# the driver aims at the dodge lane while dodging
	var drv := AiDriver.new(d, -2.4, 1.0)
	var pos: Vector3 = d.points[50] + d.right_of(50) * -2.4
	var head: float = d.heading_at(50)
	var straight: Dictionary = drv.decide(DT, pos, head, 20.0)
	drv.dodging = true
	drv.dodge_lane = 4.0
	var away: Dictionary = drv.decide(DT, pos, head, 20.0)
	runner.check(away.steer > straight.steer + 0.1, "steers right towards the dodge lane (%.2f vs %.2f)" % [away.steer, straight.steer])
	runner.check(away.throttle == 1.0, "keeps driving")
	drv.dodging = false
	var back: Dictionary = drv.decide(DT, pos, head, 20.0)
	runner.check(is_equal_approx(back.steer, straight.steer), "back to its own lane when not dodging")

func test_highway_node_builds_and_moves_the_vehicles() -> void:
	var d := TrackLibrary.make_data(SPEEDWAY)
	var tr := Traffic.new(d)
	var hw = Highway.new(tr)
	hw._ready()   # not in a tree during _initialize
	runner.check(hw.cars.size() == tr.vehicles.size() and hw.get_child_count() == tr.vehicles.size(), "a node per vehicle")
	for i in tr.vehicles.size():
		var car: Node3D = hw.cars[i]
		runner.check(car.name == "Vehicle%d" % i, "named per index")
		runner.check(car.position.is_equal_approx(tr.vehicle_pose(i).pos), "vehicle %d placed in its lane" % i)
		var meshes := 0
		var lit := 0
		for ch in car.get_children():
			if ch is MeshInstance3D:
				meshes += 1
				var m := ch.material_override as StandardMaterial3D
				if m != null and m.emission_enabled:
					lit += 1
		runner.check(meshes >= 8, "%s: body, wheels and lights (%d meshes)" % [tr.vehicles[i].kind, meshes])
		runner.check(lit == 4, "two headlights and two taillights (%d)" % lit)
	var before: Vector3 = hw.cars[0].position
	hw.update_traffic(1.0)
	var moved: float = hw.cars[0].position.distance_to(before)
	runner.check(moved > tr.vehicles[0].speed * 0.8 and moved < tr.vehicles[0].speed * 1.2, "moved about its speed in a second (%.1f)" % moved)
	var p := tr.vehicle_pose(0)
	runner.check(is_equal_approx(hw.cars[0].rotation.y, atan2(-p.dir.x, -p.dir.z)), "faces its direction of travel")
	hw.free()
