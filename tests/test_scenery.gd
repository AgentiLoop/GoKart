extends RefCounted
## Mario Kart 64 style roadside scenery: every course names a set, the props stand beyond the walls
## (also where the course folds back on itself), out of the water, off the railway and apart, the
## layout is deterministic, a mirrored course gets the mirror image, every kind has parts and the
## node batches them.

const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const Scenery := preload("res://scripts/scenery.gd")
const SceneryProps := preload("res://scripts/scenery_props.gd")
var runner

func test_every_course_names_a_set() -> void:
	var seen: Array = []
	for t in TrackLibrary.count():
		var info := TrackLibrary.info(t)
		runner.check(info.has("scenery") and Scenery.has_set(info.scenery), "%s names a scenery set" % info.name)
		runner.check(not seen.has(info.scenery), "%s: its own set (%s)" % [info.name, info.scenery])
		seen.append(info.scenery)
		var d := TrackLibrary.make_data(t)
		runner.check(d.scenery == info.scenery, "TrackData carries the set")
	runner.check(Scenery.set_names().size() == 4 and not Scenery.has_set("moon"), "four sets, unknown names are not sets")
	var bare := TrackData.new()
	runner.check(bare.scenery == "" and Scenery.props(bare).is_empty(), "a bare course has no props")
	runner.check(Scenery.props(null).is_empty(), "no track: no props")

func test_props_stand_clear() -> void:
	for t in TrackLibrary.count():
		for mirror in [false, true]:
			var d := TrackLibrary.make_data(t, mirror)
			var tag := "%s %s" % [TrackLibrary.info(t).name, "mirrored" if mirror else "plain"]
			var props := Scenery.props(d)
			runner.check(props.size() >= 60, "%s: dressed with %d props" % [tag, props.size()])
			var kinds := {}
			var edge: float = d.width * 0.5 + Scenery.WALL
			var overlaps := {}
			for rule in Scenery.SETS[d.scenery]:
				if rule.get("overlap", false):
					overlaps[rule.kind] = true
			var on_road := 0
			var wet := 0
			var odd := 0
			var no_wall := 0
			var crowded := 0
			var on_rails := 0
			for i in props.size():
				var p: Dictionary = props[i]
				kinds[p.kind] = true
				if d.distance_to_center(p.pos) - p.radius < edge + Scenery.WALL_GAP - 0.02:
					on_road += 1
				if d.in_water(p.pos, d.nearest_index(p.pos)):
					wet += 1
				if p.pos.y != 0.0 or p.scale.x <= 0.0 or p.scale.y <= 0.0 or absf(p.radius - Scenery.RADIUS[p.kind] * p.scale.x) > 0.001:
					odd += 1
				var lateral: float = absf((p.pos - d.points[p.idx]).dot(d.right_of(p.idx)))
				if lateral - p.radius < edge + Scenery.FAR:
					for o in range(-Scenery.WALL_SPAN, Scenery.WALL_SPAN + 1):
						if not d.has_wall(p.idx + o, p.side):
							no_wall += 1
				for r in d.rail:
					if Vector2(r.x - p.pos.x, r.z - p.pos.z).length() < p.radius + Scenery.RAIL_GAP - 0.01:
						on_rails += 1
				for j in range(i + 1, props.size()):
					var q: Dictionary = props[j]
					if Vector2(q.pos.x - p.pos.x, q.pos.z - p.pos.z).length() < p.radius + q.radius + Scenery.PROP_GAP - 0.01 and not (p.kind == q.kind and overlaps.has(p.kind)):
						crowded += 1
			runner.check(on_road == 0, "%s: %d props on or against the road (anywhere on the loop)" % [tag, on_road])
			runner.check(wet == 0, "%s: %d props in the water" % [tag, wet])
			runner.check(odd == 0, "%s: %d props off the ground or missized" % [tag, odd])
			runner.check(no_wall == 0, "%s: %d near props without the wall beside them" % [tag, no_wall])
			runner.check(on_rails == 0, "%s: %d props on the rails" % [tag, on_rails])
			runner.check(crowded == 0, "%s: %d pairs of props too close" % [tag, crowded])
			for rule in Scenery.SETS[d.scenery]:
				runner.check(kinds.has(rule.kind), "%s: at least one %s" % [tag, rule.kind])

func test_layout_is_deterministic_and_mirrors() -> void:
	for t in TrackLibrary.count():
		var name: String = TrackLibrary.info(t).name
		var a := Scenery.props(TrackLibrary.make_data(t))
		var b := Scenery.props(TrackLibrary.make_data(t))
		runner.check(a.size() == b.size(), "%s: same count twice" % name)
		var differ := 0
		for i in a.size():
			if a[i].kind != b[i].kind or a[i].pos != b[i].pos or a[i].yaw != b[i].yaw or a[i].scale != b[i].scale:
				differ += 1
		runner.check(differ == 0, "%s: %d props differ on a second build" % [name, differ])
		var m := Scenery.props(TrackLibrary.make_data(t, true))
		runner.check(m.size() == a.size(), "%s: the mirrored course has the same %d props (got %d)" % [name, a.size(), m.size()])
		var unmirrored := 0
		for i in mini(a.size(), m.size()):
			if a[i].kind != m[i].kind or absf(a[i].pos.x + m[i].pos.x) > 0.05 or absf(a[i].pos.z - m[i].pos.z) > 0.05 or a[i].scale != m[i].scale or a[i].side != -m[i].side:
				unmirrored += 1
		runner.check(unmirrored == 0, "%s: %d props not at their mirror-image spot (same size, other side)" % [name, unmirrored])

func test_facing() -> void:
	var d := TrackLibrary.make_data(1)   # Sunset Speedway: lamps face the road, billboards look down it
	for p in Scenery.props(d):
		var fwd := Vector3(sin(p.yaw), 0, cos(p.yaw))   # the prop's +z in the world
		if p.kind == "lamp":
			var to_road: Vector3 = d.right_of(p.idx) * float(-p.side)
			runner.check(fwd.dot(to_road) > 0.99, "lamp at %d reaches over the road" % p.idx)
		elif p.kind == "billboard" or p.kind == "building":
			runner.check(absf(fwd.dot(d.tangents[p.idx])) > 0.99, "%s at %d stands along the road" % [p.kind, p.idx])

func test_parts_and_node() -> void:
	var kinds := Scenery.kinds()
	runner.check(kinds.size() == 12, "twelve kinds of prop, got %d" % kinds.size())
	for kind in kinds:
		var parts := Scenery.parts(kind)
		runner.check(parts.size() >= 2, "%s is built from parts" % kind)
		runner.check(Scenery.RADIUS.has(kind), "%s has a footprint" % kind)
		for part in parts:
			runner.check(["box", "sphere", "cylinder", "cone"].has(part.shape), "%s: known shape %s" % [kind, part.shape])
			runner.check(part.size.x > 0.0 and part.size.y > 0.0 and part.at.y >= 0.0, "%s: sized, above the ground" % kind)
			runner.check(part.color.v > 0.05, "%s: no black parts" % kind)
			var mesh := SceneryProps.make_mesh(part)
			runner.check(mesh != null and not (part.shape != "box" and mesh is BoxMesh), "%s: %s mesh" % [kind, part.shape])
	runner.check(Scenery.parts("spaceship").is_empty(), "unknown kind: no parts")
	var p := {"kind": "tree", "pos": Vector3(10, 0, -4), "yaw": PI * 0.5, "scale": Vector3(2, 2, 2), "radius": 3.4, "idx": 0, "side": 1}
	var xf := SceneryProps.prop_transform(p, {"at": Vector3(0, 1.5, 0)})
	runner.check(xf.origin.is_equal_approx(Vector3(10, 3, -4)), "the part's offset is scaled by the prop's size")
	var tall := SceneryProps.prop_transform({"pos": Vector3.ZERO, "yaw": 0.0, "scale": Vector3(1, 3, 1)}, {"at": Vector3(0, 5, 0)})
	runner.check(tall.origin.is_equal_approx(Vector3(0, 15, 0)) and tall.basis.get_scale().is_equal_approx(Vector3(1, 3, 1)), "a tall prop stretches its parts upward")
	var ahead := SceneryProps.prop_transform({"pos": Vector3.ZERO, "yaw": PI * 0.5, "scale": Vector3.ONE}, {"at": Vector3(0, 0, 2)})
	runner.check(ahead.origin.is_equal_approx(Vector3(2, 0, 0)), "yaw turns the prop's +z (facing) about y")
	var d := TrackLibrary.make_data(3)
	var layout := Scenery.props(d)
	var node := SceneryProps.new(layout)
	node._ready()
	var expected := 0
	var per_kind := {}
	for q in layout:
		per_kind[q.kind] = per_kind.get(q.kind, 0) + 1
	for kind in per_kind:
		expected += Scenery.parts(kind).size()
	runner.check(node.batches.size() == expected and node.get_child_count() == expected, "one batch per kind and part: %d" % expected)
	var instances := {}
	for b in node.batches:
		runner.check(b is MultiMeshInstance3D and b.multimesh.instance_count > 0 and b.material_override is StandardMaterial3D, "a filled MultiMesh batch")
		instances[b.name] = b.multimesh.instance_count
	for kind in per_kind:
		runner.check(instances.get("%s0" % kind.capitalize(), 0) == per_kind[kind], "%s batch holds %d instances" % [kind, per_kind[kind]])
	runner.check(node.prop_count() == layout.size(), "prop_count")
	node.free()
