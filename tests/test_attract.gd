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

## The arena demo (battle mode's select screen): the picked arena with its item boxes and four
## balloon karts on the pads, patrolling the box ring under the battle driver, the picture camera
## circling the arena; a course afterwards tears it down.
func test_arena_demo_helpers() -> void:
	var ring := Attract.ring_waypoints([Vector3(0, 0, 10), Vector3(10, 0, 0), Vector3(-10, 0, 0), Vector3(0, 0, -10)])
	runner.check(ring == [Vector3(0, 0, -10), Vector3(10, 0, 0), Vector3(0, 0, 10), Vector3(-10, 0, 0)], "ring sorted by angle round the centre: %s" % [ring])
	runner.check(Attract.patrol_dir(0) == 1 and Attract.patrol_dir(1) == -1 and Attract.patrol_dir(2) == 1, "even karts one way, odd karts the other")
	runner.check(Attract.first_waypoint(0, Vector3(9, 0, 1), ring) == 2 and Attract.first_waypoint(1, Vector3(9, 0, 1), ring) == 0, "first waypoint: the one after the nearest, in the kart's direction")
	runner.check(Attract.first_waypoint(1, Vector3(0, 0, -9), ring) == 3 and Attract.first_waypoint(0, Vector3(-9, 0, 0), ring) == 0, "... wrapping both ways")
	runner.check(Attract.first_waypoint(0, Vector3.ZERO, []) == 0, "empty ring")
	runner.check(Attract.next_waypoint(0, 2, Vector3(10, 0, 30), ring) == 2, "far from the waypoint: the goal stays")
	runner.check(Attract.next_waypoint(0, 2, ring[2] + Vector3(Attract.WAYPOINT_REACH - 0.5, 0, 0), ring) == 3, "within reach: the next one")
	runner.check(Attract.next_waypoint(1, 0, ring[0] + Vector3(1, 0, 0), ring) == 3 and Attract.next_waypoint(0, 3, ring[3] + Vector3(0, 0, 1), ring) == 0, "wraps both ways")
	var p0 := Attract.orbit_pose(0.0, 40.0)
	runner.check(p0.pos.is_equal_approx(Vector3(40.0 * Attract.ORBIT_RADIUS, 40.0 * Attract.ORBIT_UP, 0)) and p0.look == Vector3.ZERO, "orbit starts on +x, ORBIT_RADIUS halves out and ORBIT_UP halves up, looking at the centre: %s" % p0.pos)
	var pq := Attract.orbit_pose(Attract.ORBIT_TIME * 0.25, 40.0)
	runner.check(is_zero_approx(pq.pos.x) and is_equal_approx(pq.pos.z, 40.0 * Attract.ORBIT_RADIUS) and is_equal_approx(pq.pos.y, p0.pos.y), "a quarter turn later it is on +z at the same height")
	runner.check(Attract.orbit_pose(Attract.ORBIT_TIME, 40.0).pos.is_equal_approx(p0.pos), "a full turn comes back round")

func test_arena_demo_world() -> void:
	var ArenaData = load("res://scripts/arena_data.gd")
	var a = Attract.new()
	_root().add_child(a)
	a.show_course(0)
	var course_world = a.world
	a.show_arena(1)
	runner.check(a.arena_index == 1 and a.course == -1 and a.world != course_world and course_world.get_parent() == null, "Block Fort replaces the course world")
	runner.check(a.arena != null and a.arena.get_parent() == a.world and a.track == null and a.data.name == "Block Fort", "the Arena node in the world, no track")
	runner.check(a.arena.data == a.data, "the arena is built from the demo's data (walls / forts go up in _ready)")
	var boxes := 0
	for c in a.world.get_children():
		if c.get_script() == load("res://scripts/item_box.gd"):
			boxes += 1
	runner.check(boxes == a.data.item_box_positions.size() and boxes > 0, "an item box at every box position (%d)" % boxes)
	runner.check(a.karts.size() == Attract.KART_COUNT, "%d karts" % Attract.KART_COUNT)
	var seen := {}
	for k in a.karts.size():
		var kart = a.karts[k]
		var s: Dictionary = a.data.spawns[k]
		runner.check(kart.position == s.position and is_equal_approx(kart.heading, s.heading), "kart %d on its start pad" % k)
		runner.check(kart.driver != null and kart.driver.get("arena") == a.data and not kart.frozen, "kart %d has the battle driver" % k)
		var balloons = null
		for c in kart.get_children():
			if c.get_script() == load("res://scripts/balloons.gd"):
				balloons = c
		runner.check(balloons != null and balloons.count == load("res://scripts/battle.gd").BALLOONS, "kart %d carries its balloons" % k)
		seen[kart.body_color] = true
	runner.check(seen.size() == Attract.KART_COUNT, "every kart has its own colour")
	runner.check(a.waypoints.size() == a.data.item_box_positions.size() and a.goals.size() == Attract.KART_COUNT, "the box ring is the patrol route, a goal per kart")
	for k in a.karts.size():
		runner.check(a.goals[k] == Attract.first_waypoint(k, a.karts[k].position, a.waypoints), "kart %d starts for its first waypoint" % k)
	runner.check(a.cam != null and a.cam.current and a.cam.get_parent() == a.world and a.cam.position.is_equal_approx(Attract.chase_pose(a.karts[0].position, a.karts[0].heading)), "chase camera behind the first kart")
	var start := Attract.orbit_pose(0.0, a.data.half)
	runner.check(is_zero_approx(a.orbit_t) and a.picture_cam.position.is_equal_approx(start.pos), "picture camera starts its orbit: %s" % a.picture_cam.position)
	runner.check((a.picture_cam.transform.basis.z * -1.0).dot((start.look - start.pos).normalized()) > 0.999, "looking at the arena's centre")
	a._orbit(1.0)
	var pose := Attract.orbit_pose(1.0, a.data.half)
	runner.check(is_equal_approx(a.orbit_t, 1.0) and a.picture_cam.position.is_equal_approx(pose.pos), "a second on: further round the arena")
	# the physics tick hands each kart its waypoint and moves a kart that has reached one on
	a._physics_process(1.0 / 60.0)
	for k in a.karts.size():
		runner.check(a.karts[k].driver.goal == a.waypoints[a.goals[k]], "kart %d drives at its waypoint" % k)
	a.karts[0].position = a.waypoints[a.goals[0]]
	var before: int = a.goals[0]
	a._physics_process(1.0 / 60.0)
	runner.check(a.goals[0] == posmod(before + 1, a.waypoints.size()), "at the waypoint: on to the next")
	var same = a.world
	a.show_arena(1)
	runner.check(a.world == same, "same arena: no rebuild")
	a.show_arena(0)
	runner.check(a.arena_index == 0 and a.world != same and a.data.name == "Big Donut" and a.data.pit_radius > 0.0, "another arena rebuilds")
	# a kart in the lava is fished out
	a.karts[1].position = Vector3(1, 0, 1)
	a._physics_process(1.0 / 60.0)
	runner.check(a.karts[1].is_rescued() and a.karts[1].rescues == 1, "a kart in the pit is rescued")
	a.show_course(0)
	runner.check(a.arena == null and a.arena_index == -1 and a.course == 0 and a.track != null and a.data.count > 1, "back to a course: the arena is gone")
	a.free()

func test_menu_battle_mode_shows_the_arena() -> void:
	var m = Menu.new()
	_root().add_child(m)
	if m.select_box == null:
		m._ready()
	m.set_title(false)
	runner.check(m.attract.arena == null and m.attract.course == m.selected, "a course in the demo on the course select screen")
	while m.mode != Menu.MODE_BATTLE:
		m.toggle_mode()
	runner.check(m.attract.arena != null and m.attract.arena_index == m.arena_selected and m.attract.data.name == m.name_label.text, "battle mode: the demo and the picture show the picked arena (%s)" % m.name_label.text)
	m.move(1)
	runner.check(m.attract.arena_index == m.arena_selected and m.attract.data.name == m.name_label.text, "the arena follows the cursor (%s)" % m.name_label.text)
	m.toggle_mode()
	runner.check(m.attract.arena == null and m.attract.course == m.selected, "back to a course mode: the course again")
	m.free()
