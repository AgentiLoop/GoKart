extends RefCounted
## Title screen attract demo (Mario Kart 64 title: the logo over karts racing): the SubViewport
## world, the grid, the chase camera and the menu's title / select screen switch.

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
