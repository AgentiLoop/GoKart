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

## MK64's course map is one light colour, see-through, with no box and no black rim: the route is
## cream over a navy drop shadow, the start line a gold tick across the route, the player ringed gold.
func test_mk64_map_look_no_black_box_or_rim() -> void:
	var UiStyle := load("res://scripts/ui_style.gd")
	for c: Color in [Minimap.ROAD_COLOR, Minimap.SHADOW_COLOR, Minimap.START_COLOR, Minimap.PLAYER_RING, Minimap.RAIL_COLOR]:
		runner.check(c.r + c.g + c.b > 0.1, "no black in the map's palette: %s" % c)
	runner.check(Minimap.ROAD_COLOR.a < 1.0, "the route is see-through")
	runner.check(Color(Minimap.ROAD_COLOR, 1.0) == UiStyle.CREAM, "route in the HUD's cream")
	runner.check(Minimap.START_COLOR == UiStyle.GOLD and Minimap.PLAYER_RING == UiStyle.GOLD, "start tick and player ring in gold")
	runner.check(Minimap.SHADOW_OFFSET.x > 0 and Minimap.SHADOW_OFFSET.y > 0 and Minimap.SHADOW_COLOR.a < 0.7, "a soft drop shadow down-right, not a rim")
	var src: String = FileAccess.get_file_as_string("res://scripts/minimap.gd")
	runner.check(not src.contains("BG_COLOR") and not src.contains("OUTLINE_COLOR") and not src.contains("draw_rect"), "no background box and no outline pass")

func test_start_tick_crosses_the_route_at_the_line() -> void:
	var pts := PackedVector2Array([Vector2(10, 50), Vector2(30, 50), Vector2(30, 70)])
	var tick := Minimap.start_tick(pts, 12.0)
	runner.check(tick.size() == 2, "two ends")
	runner.check(((tick[0] + tick[1]) * 0.5).is_equal_approx(pts[0]), "centred on the first point: %s" % str(tick))
	runner.check(is_equal_approx(tick[0].distance_to(tick[1]), 12.0), "as long as asked")
	runner.check(is_zero_approx((tick[1] - tick[0]).dot(pts[1] - pts[0])), "across the first segment, not along it")
	runner.check(Minimap.start_tick(PackedVector2Array([Vector2.ZERO]), 12.0).is_empty(), "no segment, no tick")
	runner.check(Minimap.start_tick(PackedVector2Array([Vector2.ONE, Vector2.ONE]), 12.0).is_empty(), "a zero-length segment gives no tick")
	var td := TrackData.new()
	var mm := Minimap.new()
	mm.setup(td.points, Vector2(220, 220))
	var t := Minimap.start_tick(mm.map_points, Minimap.START_LENGTH)
	runner.check(t.size() == 2 and ((t[0] + t[1]) * 0.5).is_equal_approx(mm.map_points[0]), "the tick sits on the start sample of a real course")
	mm.free()
