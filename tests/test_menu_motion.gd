extends RefCounted
## Menu screen motion like Mario Kart 64's: the logo flies in from the distance and bounces to a
## stop on the title screen (PRESS ENTER fades in once it has landed), and leaving the title the
## logo glides up to its select-screen spot while the demo dims and the panels rise into place.
## Covers the pure curves / poses and the menu driving them from _process (in the tree) or
## snapping to the final pose (outside the tree, back from a race).

const Menu := preload("res://scripts/menu.gd")
var runner

func _root() -> Node:
	return Engine.get_main_loop().root

func _menu() -> Node:
	var m = Menu.new()
	_root().add_child(m)
	if m.select_box == null:
		m._ready()   # the runner's root is not ready yet during _initialize
	return m

func _run(m: Node, seconds: float, step := 1.0 / 60.0) -> void:
	var t := 0.0
	while t < seconds:
		m._process(step)
		t += step

func test_curves() -> void:
	runner.check(is_zero_approx(Menu.ease_out_back(0.0)) and is_equal_approx(Menu.ease_out_back(1.0), 1.0), "back curve runs 0 -> 1")
	var peak := 0.0
	var monotone_tail := true
	var prev := Menu.ease_out_back(0.6)
	for i in range(61, 101):
		var v := Menu.ease_out_back(i / 100.0)
		peak = maxf(peak, v)
		if v > prev + 1e-6:
			monotone_tail = false
		prev = v
	runner.check(peak > 1.05 and peak < 1.15, "overshoots ~10 %%: %.3f" % peak)
	runner.check(monotone_tail, "settles back down after the peak")
	runner.check(is_zero_approx(Menu.ease_out_cubic(0.0)) and is_equal_approx(Menu.ease_out_cubic(1.0), 1.0) and Menu.ease_out_cubic(0.5) > 0.8, "cubic ease-out: fast start, soft landing")

func test_intro_pose() -> void:
	var start: Dictionary = Menu.intro_pose(0.0)
	runner.check(is_equal_approx(start.scale, Menu.INTRO_FROM * Menu.TITLE_LOGO_SCALE) and is_zero_approx(start.alpha) and is_zero_approx(start.prompt), "starts small, invisible, prompt off")
	var mid: Dictionary = Menu.intro_pose(Menu.INTRO_TIME * 0.6)
	runner.check(mid.scale > Menu.TITLE_LOGO_SCALE and is_equal_approx(mid.alpha, 1.0) and is_zero_approx(mid.prompt), "overshoots its size on the way, fully visible, prompt still off")
	var landed: Dictionary = Menu.intro_pose(Menu.INTRO_TIME)
	runner.check(is_equal_approx(landed.scale, Menu.TITLE_LOGO_SCALE) and is_zero_approx(landed.prompt), "lands at the title size, prompt about to fade in")
	var after: Dictionary = Menu.intro_pose(Menu.INTRO_TIME + Menu.PROMPT_IN * 0.5)
	runner.check(is_equal_approx(after.scale, Menu.TITLE_LOGO_SCALE) and is_equal_approx(after.prompt, 0.5), "prompt half way in")
	var done: Dictionary = Menu.intro_pose(Menu.MOTION_DONE)
	runner.check(is_equal_approx(done.scale, Menu.TITLE_LOGO_SCALE) and is_equal_approx(done.alpha, 1.0) and is_equal_approx(done.prompt, 1.0), "finished: title pose, prompt blinking")

func test_leave_pose() -> void:
	var start: Dictionary = Menu.leave_pose(0.0)
	runner.check(start.logo_pos == Menu.TITLE_LOGO_POS and is_equal_approx(start.scale, Menu.TITLE_LOGO_SCALE) and is_zero_approx(start.dim), "starts from the title pose, demo in full view")
	runner.check(is_equal_approx(start.slide, Menu.LEAVE_SLIDE) and is_zero_approx(start.alpha), "panels start low and invisible")
	var mid: Dictionary = Menu.leave_pose(Menu.LEAVE_TIME * 0.5)
	runner.check(mid.logo_pos.y < Menu.TITLE_LOGO_POS.y and mid.logo_pos.y > Menu.MENU_LOGO_POS.y and mid.logo_pos.x == Menu.TITLE_LOGO_POS.x, "logo on its way up")
	runner.check(mid.scale < Menu.TITLE_LOGO_SCALE and mid.scale > 1.0 and mid.dim > 0.5 and mid.dim < 1.0, "shrinking, demo dimming")
	runner.check(mid.slide > 0.0 and mid.slide < Menu.LEAVE_SLIDE * 0.5 and mid.alpha > 0.5, "panels most of the way up")
	var done: Dictionary = Menu.leave_pose(Menu.LEAVE_TIME)
	runner.check(done.logo_pos == Menu.MENU_LOGO_POS and is_equal_approx(done.scale, 1.0) and is_equal_approx(done.dim, 1.0) and is_zero_approx(done.slide) and is_equal_approx(done.alpha, 1.0), "ends at the select-screen pose")

func test_menu_motion_from_process() -> void:
	# the runner's root is outside the tree during _initialize, so set_title snaps (checked below);
	# start_motion is what set_title calls for a live menu — drive it from _process by hand
	Menu.title_seen = false
	var m = _menu()
	runner.check(m.title_shown and is_equal_approx(m.anim_t, Menu.MOTION_DONE), "a menu outside the tree snaps to the title pose")
	m.start_motion()
	runner.check(is_zero_approx(m.anim_t), "title screen motion starts")
	runner.check(m.title_box.position == Menu.TITLE_LOGO_POS and is_equal_approx(m.title_box.scale.x, Menu.INTRO_FROM * Menu.TITLE_LOGO_SCALE) and is_zero_approx(m.title_box.modulate.a), "logo small and invisible on the first frame")
	runner.check(m.title_prompt.visible and is_zero_approx(m.prompt_fade), "prompt visible but faded out until the logo lands")
	runner.check(m.title_footer.visible and m.title_footer.text == Menu.TITLE_FOOTER and m.title_footer.position == Menu.TITLE_FOOTER_POS and m.title_footer.get_theme_constant("outline_size") == 0, "the footer line sits under the band, no outline")
	m._process(1.0 / 60.0)
	runner.check(is_zero_approx(m.title_prompt.modulate.a), "the blink is scaled by the fade")
	runner.check(is_zero_approx(m.title_footer.modulate.a), "the footer fades in with the prompt")
	_run(m, Menu.INTRO_TIME * 0.55)
	runner.check(m.title_box.scale.x > Menu.TITLE_LOGO_SCALE and is_equal_approx(m.title_box.modulate.a, 1.0) and is_zero_approx(m.prompt_fade), "mid-way: overshooting, visible, prompt off")
	runner.check(not m.audio.played.has("land"), "no landing thud before the logo lands")
	_run(m, Menu.INTRO_TIME + Menu.PROMPT_IN)
	runner.check(is_equal_approx(m.title_box.scale.x, Menu.TITLE_LOGO_SCALE) and is_equal_approx(m.prompt_fade, 1.0) and is_zero_approx(m.backdrop.dim), "landed: title pose, prompt blinking, demo in full view")
	runner.check(m.audio.played.count("land") == 1, "the landing thud plays once as the logo lands: %s" % str(m.audio.played))
	m._process(1.0 / 60.0)
	runner.check(m.title_prompt.modulate.a > 0.15, "the prompt blinks")
	runner.check(is_equal_approx(m.title_footer.modulate.a, 1.0), "the footer is up, steady (no blink)")
	var settled: float = m.anim_t
	m._process(1.0)
	runner.check(is_equal_approx(m.anim_t, settled), "a finished motion is left alone")
	runner.check(m.audio.played.count("land") == 1, "no second thud")
	# any key: the glide to the select screen
	m.dismiss_title()
	runner.check(not m.title_shown and m.select_box.visible and is_equal_approx(m.anim_t, Menu.MOTION_DONE), "select screen up (snapped outside the tree)")
	runner.check(not m.title_footer.visible, "the footer leaves with the title screen")
	m.start_motion()
	runner.check(m.title_box.position == Menu.TITLE_LOGO_POS and is_equal_approx(m.select_box.position.y, Menu.LEAVE_SLIDE) and is_zero_approx(m.select_box.modulate.a) and is_zero_approx(m.backdrop.dim), "first frame of the glide: logo still large, panels low and invisible")
	_run(m, Menu.LEAVE_TIME * 0.4)
	runner.check(m.title_box.position.y < Menu.TITLE_LOGO_POS.y and m.title_box.position.y > Menu.MENU_LOGO_POS.y and m.select_box.position.y > 0.0 and m.select_box.modulate.a > 0.3 and m.backdrop.dim > 0.3, "mid-glide")
	_run(m, Menu.LEAVE_TIME)
	runner.check(m.title_box.position == Menu.MENU_LOGO_POS and is_equal_approx(m.title_box.scale.x, 1.0) and is_equal_approx(m.title_box.modulate.a, 1.0), "logo at its select-screen spot")
	runner.check(m.select_box.position == Vector2.ZERO and is_equal_approx(m.select_box.modulate.a, 1.0) and is_equal_approx(m.backdrop.dim, 1.0), "panels in place, demo dimmed")
	m.free()
	# back from a race (the title was already seen): no glide, the select screen is simply there
	var again = _menu()
	runner.check(not again.title_shown and is_equal_approx(again.anim_t, Menu.MOTION_DONE), "no motion when the select screen does not come from the title")
	runner.check(again.title_box.position == Menu.MENU_LOGO_POS and again.select_box.position == Vector2.ZERO and is_equal_approx(again.select_box.modulate.a, 1.0) and is_equal_approx(again.backdrop.dim, 1.0), "snapped to the select pose")
	again.free()

func test_menu_outside_the_tree_snaps() -> void:
	var m = Menu.new()
	m.title_box = Control.new()
	m.select_box = Control.new()
	m.title_prompt = Label.new()
	m.backdrop = Menu.Backdrop.new()
	m.set_title(true)
	runner.check(is_equal_approx(m.anim_t, Menu.MOTION_DONE) and is_equal_approx(m.title_box.scale.x, Menu.TITLE_LOGO_SCALE) and is_equal_approx(m.title_box.modulate.a, 1.0) and is_equal_approx(m.prompt_fade, 1.0), "title pose at once")
	m.dismiss_title()
	runner.check(m.title_box.position == Menu.MENU_LOGO_POS and m.select_box.position == Vector2.ZERO and is_equal_approx(m.select_box.modulate.a, 1.0) and is_equal_approx(m.backdrop.dim, 1.0), "select pose at once")
	for n in [m.title_box, m.select_box, m.title_prompt, m.backdrop, m]:
		n.free()

func test_tour_veil() -> void:
	runner.check(is_zero_approx(Menu.tour_veil(0.0)) and is_zero_approx(Menu.tour_veil(Menu.TOUR_HOLD * 0.5)) and is_zero_approx(Menu.tour_veil(Menu.TOUR_HOLD)), "clear while the course shows")
	runner.check(is_equal_approx(Menu.tour_veil(Menu.TOUR_HOLD + Menu.TOUR_FADE * 0.5), 0.5), "half way up half way through the dip")
	runner.check(is_equal_approx(Menu.tour_veil(Menu.tour_switch_time()), 1.0) and is_equal_approx(Menu.tour_switch_time(), Menu.TOUR_HOLD + Menu.TOUR_FADE), "fully up at the switch")
	runner.check(is_equal_approx(Menu.tour_veil(-Menu.TOUR_FADE), 1.0) and is_equal_approx(Menu.tour_veil(-Menu.TOUR_FADE * 0.25), 0.25), "falling again after the switch")

func test_title_demo_tour() -> void:
	Menu.title_seen = false
	var m = _menu()
	var first: int = m.selected
	runner.check(m.title_shown and m.tour_runs() and is_zero_approx(m.tour_t) and is_zero_approx(m.veil.color.a), "the tour runs on the title screen once the logo has landed, veil clear")
	_run(m, Menu.TOUR_HOLD + Menu.TOUR_FADE * 0.5)
	runner.check(m.selected == first and m.veil.color.a > 0.3 and m.veil.color.a < 0.7, "dipping to navy before the switch, still on the first course")
	runner.check(m.veil.color.r == Menu.TOUR_VEIL.r and m.veil.color.b == Menu.TOUR_VEIL.b, "the dip is the panels' navy")
	_run(m, Menu.TOUR_FADE * 0.5 + 2.0 / 60.0)
	var second: int = m.selected
	runner.check(second == Menu.TrackLibrary.step(first, 1) and m.attract.course == second and m.name_label.text == Menu.TrackLibrary.info(second).name, "the demo moves to the next course and the highlight follows")
	runner.check(m.tour_t < 0.0 and m.veil.color.a > 0.85, "veil still up right after the switch")
	_run(m, Menu.TOUR_FADE)
	runner.check(is_zero_approx(m.veil.color.a), "back in view")
	_run(m, Menu.TOUR_HOLD * 0.5)
	runner.check(m.selected == second, "stays on the course for its turn")
	# any key: the select screen opens on the course being watched, no more touring
	m.dismiss_title()
	runner.check(not m.title_shown and m.selected == second and not m.tour_runs() and is_zero_approx(m.veil.color.a), "select screen on the watched course, veil cleared")
	_run(m, Menu.tour_switch_time() + 1.0)
	runner.check(m.selected == second and is_zero_approx(m.veil.color.a), "the select screen never tours")
	# battle mode on the title: no tour (the demo shows no arena)
	m.set_title(true)
	m.mode = Menu.MODE_BATTLE
	runner.check(not m.tour_runs(), "no tour in battle mode")
	m.free()
