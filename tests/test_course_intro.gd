extends RefCounted
## Mario Kart 64 style course intro: the fly-over camera cuts, the name card's pose, the caption
## and the HUD card (a sign over the picture, the race HUD away until the intro ends).

const CourseIntro := preload("res://scripts/course_intro.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const Hud := preload("res://scripts/hud.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const Items := preload("res://scripts/items.gd")
var runner

## Three cuts, each running forward along the road, the last one ending over the grid.
func test_fly_over_cuts_end_over_the_grid() -> void:
	var data = TrackLibrary.make_data(0)
	var n: int = data.count
	runner.check(CourseIntro.cut_index(0.0) == 0 and CourseIntro.cut_index(CourseIntro.CUT_TIME + 0.01) == 1 and CourseIntro.cut_index(CourseIntro.TIME + 5.0) == CourseIntro.CUTS - 1, "cut index follows the clock and clamps")
	var end_s := CourseIntro.fly_s(CourseIntro.TIME, n, data.spacing)
	runner.check(is_equal_approx(end_s, float(n) - CourseIntro.GRID_BACK), "the last cut ends GRID_BACK samples before the line: %.1f" % end_s)
	for i in CourseIntro.CUTS:
		var t0 := i * CourseIntro.CUT_TIME
		var a := CourseIntro.fly_s(t0 + 0.01, n, data.spacing)
		var b := CourseIntro.fly_s(t0 + CourseIntro.CUT_TIME - 0.01, n, data.spacing)
		runner.check(b > a and is_equal_approx(b - a, (CourseIntro.CUT_TIME - 0.02) * CourseIntro.FLY_SPEED / data.spacing), "cut %d runs forward at FLY_SPEED" % i)
		var expect_end := float(n) * (i + 1) / CourseIntro.CUTS - CourseIntro.GRID_BACK
		runner.check(absf(CourseIntro.fly_s(t0 + CourseIntro.CUT_TIME - 0.001, n, data.spacing) - expect_end) < 0.02, "cut %d ends at its share of the loop" % i)
	# the camera sits FLY_UP over the road, FLY_SIDE to its right, and looks down the road
	var pose := CourseIntro.cam_pose(CourseIntro.TIME, data.points, data.spacing)
	var road: Vector3 = data.points[n - CourseIntro.GRID_BACK]
	runner.check(is_equal_approx(pose.pos.y, road.y + CourseIntro.FLY_UP), "camera FLY_UP over the road")
	var flat := Vector2(pose.pos.x - road.x, pose.pos.z - road.z).length()
	runner.check(absf(flat - CourseIntro.FLY_SIDE) < 0.01, "camera FLY_SIDE off the centre line: %.2f" % flat)
	var ahead: Vector3 = data.points[(n - CourseIntro.GRID_BACK + CourseIntro.FLY_AHEAD) % n]
	runner.check(pose.look.distance_to(ahead + Vector3(0, CourseIntro.FLY_LOOK_UP, 0)) < 0.01, "looks FLY_AHEAD samples down the road")
	var mid := CourseIntro.cam_pose(CourseIntro.TIME * 0.5, data.points, data.spacing)
	runner.check(mid.pos.distance_to(pose.pos) > 50.0, "the middle cut shows another part of the course")

## The name card fades in while rising, holds, and fades out at the end.
func test_card_fades_in_rises_and_fades_out() -> void:
	var start := CourseIntro.card_pose(0.0)
	runner.check(is_zero_approx(start.alpha) and is_equal_approx(start.y, CourseIntro.CARD_RISE), "hidden and low at the start")
	var half := CourseIntro.card_pose(CourseIntro.CARD_IN * 0.5)
	runner.check(half.alpha > 0.4 and half.alpha < 0.6 and half.y > 0.0 and half.y < CourseIntro.CARD_RISE, "half way in: part faded, part risen")
	var up := CourseIntro.card_pose(CourseIntro.TIME * 0.5)
	runner.check(is_equal_approx(up.alpha, 1.0) and is_zero_approx(up.y), "fully up in the middle")
	var going := CourseIntro.card_pose(CourseIntro.TIME - CourseIntro.CARD_OUT * 0.5)
	runner.check(going.alpha > 0.4 and going.alpha < 0.6 and is_zero_approx(going.y), "fading out at the end without moving")
	runner.check(is_zero_approx(CourseIntro.card_pose(CourseIntro.TIME).alpha), "gone when the intro ends")
	runner.check(not CourseIntro.finished(1.0, false) and CourseIntro.finished(CourseIntro.TIME, false) and CourseIntro.finished(0.1, true), "ends on time or on a skip")

func test_caption_names_the_mode_and_class() -> void:
	runner.check(CourseIntro.caption("RACE 2 / 4", false, "150cc", 3) == "GRAND PRIX  ·  RACE 2 / 4  ·  150cc", "grand prix caption")
	runner.check(CourseIntro.caption("", true, "100cc", 3) == "TIME TRIAL  ·  100cc", "time trial caption")
	runner.check(CourseIntro.caption("", false, "50cc", 3) == "50cc  ·  3 LAPS", "single race caption")
	runner.check(CourseIntro.caption("", false, "Extra", 1) == "Extra  ·  1 LAP", "one lap")

## The HUD card: the course name as a gold sign (dark red rim, no black), the caption a cream body
## line, the race HUD hidden while it shows and back once the intro ends.
func test_hud_intro_card() -> void:
	var hud = Hud.new()
	hud._ready()
	runner.check(not hud.intro_box.visible, "no card before the intro")
	hud.show_intro("Green Hills", "150cc  ·  3 LAPS")
	runner.check(hud.intro_box.visible and hud.intro_name.text == "GREEN HILLS" and hud.intro_caption.text == "150cc  ·  3 LAPS", "card up with the name in caps")
	runner.check(hud.intro_name.get_theme_color("font_color") == UiStyle.GOLD and hud.intro_name.get_theme_color("font_outline_color") == UiStyle.SIGN_RIM and hud.intro_name.get_theme_constant("outline_size") == Hud.INTRO_NAME_SIZE / 16, "the name is a gold sign with the dark red rim")
	runner.check(hud.intro_caption.get_theme_constant("outline_size") == 0 and hud.intro_caption.get_theme_color("font_color") == UiStyle.CREAM, "the caption is cream body text, no outline")
	runner.check(hud.intro_rule.color == UiStyle.GOLD and hud.intro_rule.size.x == hud.intro_name.size.x, "a gold rule as wide as the card")
	runner.check(hud.intro_box.offset_left == Hud.INTRO_INSET.x and hud.intro_box.anchor_top == 1.0 and hud.intro_box.offset_bottom == -Hud.INTRO_INSET.y, "bottom left, INTRO_INSET from the corner")
	for c in hud.race_controls:
		runner.check(not c.visible, "%s hidden during the intro" % c)
	hud.show_item(Items.Type.TRIPLE_MUSHROOM, 3)
	runner.check(not hud.item_window.visible, "no item window over the intro")
	hud.intro_pose(0.5, 12.0)
	runner.check(is_equal_approx(hud.intro_box.modulate.a, 0.5) and is_equal_approx(hud.intro_box.offset_top, hud.intro_base_y + 12.0) and is_equal_approx(hud.intro_box.offset_bottom - hud.intro_box.offset_top, -hud.intro_base_y - Hud.INTRO_INSET.y), "pose moves the whole card")
	hud.end_intro()
	runner.check(not hud.intro_box.visible, "card gone")
	for c in hud.race_controls:
		runner.check(c.visible, "%s back after the intro" % c)
	hud.show_item(Items.Type.TRIPLE_MUSHROOM, 3)
	runner.check(hud.item_window.visible, "item window back")
	hud.free()
