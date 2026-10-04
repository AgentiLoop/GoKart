extends SceneTree
## Headless: godot --headless --path . -s tools/scenery_check.gd
## Roadside scenery check: every course's race scene builds a Scenery node under the track with one
## MultiMesh batch per kind and part and an instance per prop; the Extra class (mirrored course) puts
## every prop at its mirror-image spot; the attract demo's track is dressed too.
const TrackLibrary := preload("res://scripts/track_library.gd")
const Scenery := preload("res://scripts/scenery.gd")
var fails := 0
var f := 0
var stage := 0
var main
func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1
func _load(course: int, engine: int) -> void:
	if main != null:
		root.remove_child(main)
		main.free()
	TrackLibrary.selected = course
	TrackLibrary.engine_class = engine
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
func _initialize() -> void:
	_load(0, 2)
func _process(_d: float) -> bool:
	f += 1
	if f < 5:
		return false
	f = 0
	if stage < 4:
		var course := stage
		var name: String = TrackLibrary.info(course).name
		var node = main.track.get_node_or_null("Scenery")
		_check(node != null, "%s: a Scenery node under the track" % name)
		if node != null:
			var layout := Scenery.props(main.track.data)
			_check(node.prop_count() == layout.size() and layout.size() >= 60, "%s: %d props" % [name, node.prop_count()])
			var kinds := {}
			for p in layout:
				kinds[p.kind] = true
			var batches := 0
			var instances := 0
			for kind in kinds:
				batches += Scenery.parts(kind).size()
			for b in node.get_children():
				instances += b.multimesh.instance_count
			_check(node.get_child_count() == batches, "%s: %d MultiMesh batches (one per kind and part)" % [name, node.get_child_count()])
			_check(instances > layout.size(), "%s: %d part instances drawn" % [name, instances])
			var set_kinds: Array = []
			for rule in Scenery.SETS[main.track.data.scenery]:
				set_kinds.append(rule.kind)
			_check(kinds.keys().size() == set_kinds.size(), "%s: every kind of the %s set stands on the course %s" % [name, main.track.data.scenery, kinds.keys()])
		stage += 1
		if stage < 4:
			_load(stage, 2)
		else:
			_load(2, 3)   # Frosty Peaks in the Extra class: mirrored
		return false
	if stage == 4:
		var plain := Scenery.props(TrackLibrary.make_data(2, false))
		var node = main.track.get_node_or_null("Scenery")
		_check(main.track.data.mirrored and node != null and node.prop_count() == plain.size(), "Extra class: the mirrored course is dressed with the same %d props" % plain.size())
		var flipped := 0
		for i in node.props.size():
			if absf(node.props[i].pos.x + plain[i].pos.x) < 0.05 and absf(node.props[i].pos.z - plain[i].pos.z) < 0.05:
				flipped += 1
		_check(flipped == plain.size(), "Extra class: %d of %d props at their mirror-image spot" % [flipped, plain.size()])
		TrackLibrary.engine_class = 2
		root.remove_child(main)
		main.free()
		main = null
		var Attract = load("res://scripts/attract.gd")
		main = Attract.new()
		root.add_child(main)
		main.show_course(0)
		stage = 5
		return false
	if stage == 5:
		var node = main.track.get_node_or_null("Scenery") if main.track != null else null
		_check(node != null and node.prop_count() >= 60, "the attract demo's course is dressed (%d props)" % (node.prop_count() if node != null else 0))
		print("SCENERY CHECK: %s" % ("OK" if fails == 0 else "FAILED (%d)" % fails))
		quit(1 if fails > 0 else 0)
	return false
