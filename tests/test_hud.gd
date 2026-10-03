extends RefCounted
## Race HUD styling: Mario Kart 64 look shared with the menu (UiStyle) — rounded bold font,
## drop shadows instead of black outlines, signs with a coloured rim, results on a navy panel.

const Hud := preload("res://scripts/hud.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const RaceResults := preload("res://scripts/race_results.gd")
var runner

func test_body_labels_have_shadows_not_outlines() -> void:
	var hud = Hud.new()
	hud._ready()
	for l in [hud.lap_label, hud.time_label, hud.speed_label, hud.state_label, hud.item_label, hud.hint_label, hud.place_label, hud.cup_label, hud.results_label]:
		runner.check(l.get_theme_constant("outline_size") == 0, "%s has no outline" % l)
		runner.check(l.get_theme_constant("shadow_offset_x") >= 2 and l.get_theme_color("font_shadow_color").a > 0.0, "drop shadow")
	runner.check(hud.lap_label.get_theme_color("font_color") == UiStyle.GOLD and hud.time_label.get_theme_color("font_color") == UiStyle.CREAM, "gold / cream palette")
	runner.check(hud.lap_label.get_theme_font("font") == hud.font and hud.font.get_font_name() != "", "rounded menu font: " + hud.font.get_font_name())
	hud.free()

func test_signs_have_a_coloured_rim_not_black() -> void:
	var hud = Hud.new()
	hud._ready()
	for l in [hud.countdown_label, hud.banner_label]:
		var rim: Color = l.get_theme_color("font_outline_color")
		runner.check(l.get_theme_constant("outline_size") > 0 and rim != Color.BLACK and rim == UiStyle.SIGN_RIM, "sign rim")
		runner.check(l.get_theme_color("font_color") == UiStyle.GOLD, "gold sign text")
	runner.check(hud.countdown_label.get_theme_constant("outline_size") == 10 and hud.banner_label.get_theme_constant("outline_size") == 4, "rim scales with the text size")
	hud.free()

func test_results_panel_wraps_the_table() -> void:
	var hud = Hud.new()
	hud._ready()
	runner.check(not hud.results_panel.visible and not hud.results_label.visible, "hidden at start")
	var rows := RaceResults.rows(["YOU", "BLU", "GRN", "PUR"], [10.0, 5.0, 4.0, 3.0], [60.0, 61.0, -1.0, -1.0])
	hud.show_results(RaceResults.table_text(rows, 0))
	runner.check(hud.results_panel.visible and hud.results_label.visible, "shown with the table")
	var min_size: Vector2 = hud.results_label.get_minimum_size()
	var w: float = hud.results_panel.offset_right - hud.results_panel.offset_left
	var h: float = hud.results_panel.offset_bottom - hud.results_panel.offset_top
	runner.check(is_equal_approx(w, min_size.x + 2.0 * Hud.RESULTS_PAD.x) and is_equal_approx(h, min_size.y + 2.0 * Hud.RESULTS_PAD.y), "panel = table + padding: %s vs %s" % [Vector2(w, h), min_size])
	runner.check(is_equal_approx(hud.results_panel.offset_left, -hud.results_panel.offset_right), "centred horizontally")
	runner.check(hud.results_panel.get_index() < hud.results_label.get_index(), "panel drawn under the table")
	var sb := hud.results_panel.get_theme_stylebox("panel") as StyleBoxFlat
	runner.check(sb != null and sb.border_color == UiStyle.PANEL_RIM and sb.bg_color == UiStyle.PANEL_FILL, "navy panel with a gold rim")
	hud.show_results("")
	runner.check(not hud.results_panel.visible and not hud.results_label.visible, "hidden again")
	hud.free()

func test_style_helpers() -> void:
	runner.check(UiStyle.shadow_offset(14) == 2 and UiStyle.shadow_offset(30) == 3 and UiStyle.shadow_offset(72) == 5)
	var l := Label.new()
	UiStyle.style_sign(l, UiStyle.make_font(), 32)
	runner.check(l.get_theme_constant("outline_size") == 3, "small signs keep a 3 px rim")
	l.free()
