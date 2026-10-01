extends RefCounted

const Minimap := preload("res://scripts/minimap.gd")
const TrackData := preload("res://scripts/track_data.gd")
var runner

func test_fit_keeps_points_inside_area() -> void:
	var td := TrackData.new()
	var area := Vector2(220, 220)
	var f := Minimap.fit(td.points, area, 14.0)
	for p in td.points:
		var m := Minimap.to_map(p, f["scale"], f["offset"])
		runner.check(m.x >= 13.99 and m.x <= area.x - 13.99, "x=%f" % m.x)
		runner.check(m.y >= 13.99 and m.y <= area.y - 13.99, "y=%f" % m.y)

func test_fit_touches_margin_on_limiting_axis() -> void:
	var pts := PackedVector3Array([Vector3(0, 0, 0), Vector3(100, 0, 0), Vector3(100, 0, 50), Vector3(0, 0, 50)])
	var f := Minimap.fit(pts, Vector2(220, 220), 10.0)
	runner.check(is_equal_approx(f["scale"], 2.0), "scale=%f" % f["scale"])
	var a := Minimap.to_map(pts[0], f["scale"], f["offset"])
	var b := Minimap.to_map(pts[1], f["scale"], f["offset"])
	runner.check(a.is_equal_approx(Vector2(10, 60)), str(a))
	runner.check(b.is_equal_approx(Vector2(210, 60)), str(b))

func test_fit_empty_is_safe() -> void:
	var f := Minimap.fit(PackedVector3Array(), Vector2(100, 100), 5.0)
	runner.check(f["offset"] == Vector2(50, 50))

func test_setup_closes_loop_and_markers() -> void:
	var td := TrackData.new()
	var mm := Minimap.new()
	mm.setup(td.points, Vector2(220, 220))
	runner.check(mm.map_points.size() == td.count + 1)
	runner.check(mm.map_points[0] == mm.map_points[mm.map_points.size() - 1])
	mm.set_markers([td.points[0], td.points[10]], [Color.RED, Color.BLUE])
	runner.check(mm.marker_positions.size() == 2 and mm.marker_colors.size() == 2)
	runner.check(mm.marker_positions[0].is_equal_approx(mm.map_points[0]))
	mm.free()
