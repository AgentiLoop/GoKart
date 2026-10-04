extends RefCounted
## Title screen attract demo (Mario Kart 64 title: the logo over karts racing): the SubViewport
## world, the grid, the chase camera, the course picture's fly-over viewport and the menu's title /
## select screen switch.

const Attract := preload("res://scripts/attract.gd")
const Menu := preload("res://scripts/menu.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
var runner

func _root() -> Node:
	return Engine.get_main_loop().root

func test_grid_and_camera_helpers() -> void:
	runner.check(Attract.grid_slot(0) == [0, -Attract.LANE] and Attract.grid_slot(1) == [0, Attract.LANE], "front row, two lanes")
	runner.check(Attract.grid_slot(2)[0] == Attract.ROW_GAP and Attract.grid_slot(3)[0] == Attract.ROW_GAP, "second row ROW_GAP samples back")
	var pose := Attract.chase_pose(Vector3(10, 0, 5), 0.0)
	runner.check(pose.is_equal_approx(Vector3(10, Attract.CAM_UP, 5 + Attract.CAM_BACK)), "camera behind (+z at heading 0) and above: %s" % pose)
	var side := Attract.chase_pose(Vector3.ZERO, PI * 0.5)
	runner.check(is_equal_approx(side.x, Attract.CAM_BACK) and absf(side.z) < 0.001, "camera follows the heading")
	runner.check(Attract.next_target(0, 4) == 1 and Attract.next_target(3, 4) == 0 and Attract.next_target(0, 0) == 0, "target cycles and wraps")

## The course picture's fly-over: a point along the closed loop and the camera pose beside the road.
func test_fly_over_helpers() -> void:
	var loop := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -10), Vector3(10, 0, -10), Vector3(10, 0, 0)])
	runner.check(Attract.loop_sample(loop, 1.0).is_equal_approx(Vector3(0, 0, -10)), "whole samples hit the points")
	runner.check(Attract.loop_sample(loop, 0.5).is_equal_approx(Vector3(0, 0, -5)), "fractions interpolate")
	runner.check(Attract.loop_sample(loop, 3.5).is_equal_approx(Vector3(5, 0, 0)), "the last segment closes the loop")
	runner.check(Attract.loop_sample(loop, 4.25).is_equal_approx(Vector3(0, 0, -2.5)) and Attract.loop_sample(loop, -0.5).is_equal_approx(Vector3(5, 0, 0)), "wraps both ways")
	runner.check(Attract.loop_sample(PackedVector3Array(), 3.0) == Vector3.ZERO, "empty loop")
	var pose := Attract.fly_pose(Vector3(0, 0, 0), Vector3(0, 0, -30))
	runner.check(pose.pos.is_equal_approx(Vector3(Attract.FLY_SIDE, Attract.FLY_UP, 0)), "camera to the right of the road (+x when heading -z) and above it: %s" % pose.pos)
	runner.check(pose.look.is_equal_approx(Vector3(0, Attract.FLY_LOOK_UP, -30)), "aimed just above the road ahead")
	var turned := Attract.fly_pose(Vector3(4, 0, 4), Vector3(34, 0, 4))
	runner.check(turned.pos.is_equal_approx(Vector3(4, Attract.FLY_UP, 4 + Attract.FLY_SIDE)), "heading +x: the right-hand side is +z")
	var still := Attract.fly_pose(Vector3(1, 0, 1), Vector3(1, 0, 1))
	runner.check(still.pos.is_finite() and still.pos.y == Attract.FLY_UP, "no direction: still a finite pose")

## The second viewport looks into the demo world through the fly-over camera; the menu puts it in
## the select screen's picture window with the map outline over its corner.
func test_course_picture_viewport() -> void:
	var a = Attract.new()
	_root().add_child(a)
	runner.check(a.picture != null and a.picture_box != null and a.picture.get_parent() == a.picture_box and a.picture_box.stretch, "picture viewport inside its own container")
	runner.check(a.picture.find_world_3d() == a.viewport.find_world_3d() and not a.picture.own_world_3d, "the picture shares the demo world")
	runner.check(a.picture_cam != null and a.picture_cam.get_parent() == a.picture and a.picture_cam.current, "fly-over camera is the picture's camera")
	a.show_course(0)
	var pts: PackedVector3Array = a.data.points
	var start := Attract.fly_pose(pts[0], pts[Attract.FLY_AHEAD])
	runner.check(is_zero_approx(a.fly_s) and a.picture_cam.position.is_equal_approx(start.pos), "starts above the start line: %s" % a.picture_cam.position)
	a._fly(1.0)
	runner.check(is_equal_approx(a.fly_s, Attract.FLY_SPEED / a.data.spacing), "a second on: FLY_SPEED m along the road (%f samples)" % a.fly_s)
	var pose := Attract.fly_pose(Attract.loop_sample(pts, a.fly_s), Attract.loop_sample(pts, a.fly_s + Attract.FLY_AHEAD))
	runner.check(a.picture_cam.position.is_equal_approx(pose.pos), "camera follows the road")
	runner.check((a.picture_cam.transform.basis.z * -1.0).dot((pose.look - pose.pos).normalized()) > 0.999, "looking at the road ahead")
	a.fly_s = a.data.count - 0.1
	a._fly(1.0)
	runner.check(a.fly_s < Attract.FLY_SPEED / a.data.spacing, "wraps round the loop")
	a.show_course(1)
	runner.check(is_zero_approx(a.fly_s) and a.picture.find_world_3d() == a.viewport.find_world_3d(), "a new course restarts the fly-over in the same shared world")
	a.free()
	var m = Menu.new()
	_root().add_child(m)
	if m.select_box == null:
		m._ready()
	var box = m.attract.picture_box
	runner.check(box.get_parent() == m.select_box and box.position == Menu.PICTURE_RECT.position and box.size == Menu.PICTURE_RECT.size, "picture window in the right panel: %s" % box.get_rect())
	var right_panel := Rect2(520, 220, 680, 278)
	runner.check(right_panel.encloses(Menu.PICTURE_RECT) and Menu.PICTURE_RECT.end.x < m.name_label.position.x, "inside the right panel, left of the name")
	var map := Rect2(m.preview.position, m.preview.size)
	runner.check(m.preview.size == Menu.PREVIEW_AREA and Menu.PICTURE_RECT.encloses(map) and map.end.x > Menu.PICTURE_RECT.get_center().x and map.end.y > Menu.PICTURE_RECT.get_center().y, "map outline over the picture's bottom-right corner: %s" % map)
	runner.check(m.preview.map_points.size() == TrackLibrary.make_data(m.selected).count + 1, "map outline closed")
	runner.check(m.select_box.get_children().find(box) < m.select_box.get_children().find(m.preview), "map drawn over the picture")
	m.set_title(true)
	runner.check(not box.is_visible_in_tree(), "no picture window on the title screen")
	m.free()

func test_demo_world_builds_the_course_and_karts() -> void:
	var a = Attract.new()
	_root().add_child(a)
	if a.viewport == null:
		a._ready()   # the runner's root is not ready yet during _initialize
	runner.check(a.viewport != null and a.viewport.own_world_3d and a.stretch, "own 3D world stretched to the container")
	runner.check(a.world == null and a.karts.is_empty(), "nothing until a course is shown")
	a.show_course(0)
	runner.check(a.course == 0 and a.world != null and a.track != null and a.track.data.count == TrackLibrary.make_data(0).count, "track 0 built")
	runner.check(a.karts.size() == Attract.KART_COUNT, "%d karts" % Attract.KART_COUNT)
	var seen := {}
	for k in a.karts:
		runner.check(k.driver != null and not k.frozen, "CPU driven, not frozen")
		runner.check(a.data.is_on_road(k.position, k.track_index), "starts on the road: %s" % k.position)
		seen[k.body_color] = true
	runner.check(seen.size() == Attract.KART_COUNT, "every kart has its own colour")
	runner.check(a.cam != null and a.cam.current and a.cam.get_parent() == a.world, "chase camera inside the demo world")
	runner.check(a.cam.position.is_equal_approx(Attract.chase_pose(a.karts[0].position, a.karts[0].heading)), "camera starts behind the first kart")
	var first_world = a.world
	a.show_course(0)
	runner.check(a.world == first_world, "same course: no rebuild")
	a.show_course(2, true)
	runner.check(a.world != first_world and a.course == 2 and a.mirrored and a.data.mirrored, "new course (mirrored) rebuilds the world")
	runner.check(first_world.get_parent() == null, "old world removed from the viewport")
	a.free()

func test_menu_title_screen_then_select_screen() -> void:
	var m = Menu.new()
	m.title_box = Control.new()
	m.select_box = Control.new()
	m.title_prompt = Label.new()
	m.backdrop = Menu.Backdrop.new()
	m.set_title(true)
	runner.check(m.title_shown and Menu.title_seen, "title shown once per launch")
	runner.check(not m.select_box.visible and m.title_prompt.visible, "panels hidden, PRESS ENTER up")
	runner.check(m.title_box.position == Menu.TITLE_LOGO_POS and is_equal_approx(m.title_box.scale.x, Menu.TITLE_LOGO_SCALE), "logo large in the upper half")
	runner.check(is_zero_approx(m.backdrop.dim), "race in full view")
	m.dismiss_title()
	runner.check(not m.title_shown and m.select_box.visible and not m.title_prompt.visible, "select screen")
	runner.check(m.title_box.position == Menu.MENU_LOGO_POS and is_equal_approx(m.title_box.scale.x, 1.0), "logo back to the top")
	runner.check(is_equal_approx(m.backdrop.dim, 1.0), "demo dimmed behind the panels")
	m.dismiss_title()
	runner.check(not m.title_shown, "dismiss is idempotent")
	for n in [m.title_box, m.select_box, m.title_prompt, m.backdrop, m]:
		n.free()
