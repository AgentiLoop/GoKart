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
	for l in [hud.lap_label, hud.time_label, hud.speed_label, hud.state_label, hud.item_label, hud.hint_label, hud.place_label, hud.cup_label]:
		runner.check(l.get_theme_constant("outline_size") == 0, "%s has no outline" % l)
		runner.check(l.get_theme_constant("shadow_offset_x") >= 2 and l.get_theme_color("font_shadow_color").a > 0.0, "drop shadow")
	runner.check(hud.lap_label.get_theme_color("font_color") == UiStyle.GOLD and hud.time_label.get_theme_color("font_color") == UiStyle.CREAM, "gold / cream palette")
	runner.check(hud.lap_label.get_theme_font("font") == hud.font and hud.font.get_font_name() != "", "rounded menu font: " + hud.font.get_font_name())
	hud.free()

func test_signs_have_a_coloured_rim_not_black() -> void:
	var hud = Hud.new()
	hud._ready()
	for l in [hud.countdown_label, hud.banner_label, hud.results_title]:
		var rim: Color = l.get_theme_color("font_outline_color")
		runner.check(l.get_theme_constant("outline_size") > 0 and rim != Color.BLACK and rim == UiStyle.SIGN_RIM, "sign rim")
		runner.check(l.get_theme_color("font_color") == UiStyle.GOLD, "gold sign text")
	runner.check(hud.countdown_label.get_theme_constant("outline_size") == 10 and hud.banner_label.get_theme_constant("outline_size") == 4, "rim scales with the text size")
	hud.free()

## Every results text the game produces breaks into typed board items.
func test_parse_results_rows() -> void:
	var rows := RaceResults.rows(["YOU", "BLUE", "GREEN", "PURPLE"], [10.0, 5.0, 4.0, 3.0], [92.4, 93.1, -1.0, -1.0])
	var items: Array = Hud.parse_results(RaceResults.table_text(rows, 0))
	runner.check(items[0].kind == "title" and items[0].text == "RESULTS", "title line")
	var r0: Dictionary = items[1]
	runner.check(r0.kind == "rank" and r0.player and r0.ordinal == "1st" and r0.name == "YOU" and r0.value == "1:32.400" and r0.points == "+9", "player row: %s" % r0)
	var r2: Dictionary = items[3]
	runner.check(r2.kind == "rank" and not r2.player and r2.ordinal == "3rd" and r2.name == "GREEN" and r2.value == "--:--.---" and r2.points == "+3", "unfinished row: %s" % r2)
	runner.check(items[5].kind == "gap" and items[6].kind == "prompt" and items[6].text.begins_with("Press ENTER"), "gap then the prompt")
	# Grand Prix standings block: a caption, "N pts" rows, a trophy sign split off the prompt
	var gp := Hud.parse_results("RESULTS\n> 1st  YOU      1:32.400  +9\n\nCUP STANDINGS  (RACE 4 / 4)\n> 1st  YOU         27 pts\n  2nd  BLUE       18 pts\n\nGOLD TROPHY!  Press ENTER for the menu")
	runner.check(gp[3].kind == "section" and gp[3].text.begins_with("CUP STANDINGS"), "standings caption: %s" % gp[3])
	runner.check(gp[4].kind == "rank" and gp[4].points == "27 pts" and gp[4].value == "" and gp[5].name == "BLUE" and gp[5].points == "18 pts", "points rows: %s" % gp[4])
	runner.check(gp[7].kind == "sign" and gp[7].text == "GOLD TROPHY!" and gp[8].kind == "prompt" and gp[8].text == "Press ENTER for the menu", "trophy sign + prompt")
	var out := Hud.parse_results("RESULTS\n\nRANK OUT!  6th - finish 4th or better to go on\nPress ENTER to retry the race")
	runner.check(out[2].kind == "sign" and out[2].text == "RANK OUT!" and out[3].kind == "text" and out[3].text.begins_with("6th - finish"), "rank-out sign + line")
	# Time trial: key / value lines, an extra flag, a records list without names
	var tt := Hud.parse_results("TIME TRIAL - Green Hills\nTIME      1:02.500   NEW RECORD!\nLAP 1     0:21.000\nBEST LAP  0:20.100   NEW!\n\nRECORDS\n> 1st  1:02.500\n  2nd  1:05.000\n\nPress ENTER to race your ghost")
	runner.check(tt[1].kind == "kv" and tt[1].key == "TIME" and tt[1].value == "1:02.500" and tt[1].extra == "NEW RECORD!", "time line: %s" % tt[1])
	runner.check(tt[2].kind == "kv" and tt[2].key == "LAP 1" and tt[2].value == "0:21.000" and tt[2].extra == "", "lap line")
	runner.check(tt[5].kind == "section" and tt[5].text == "RECORDS", "records caption")
	runner.check(tt[6].kind == "rank" and tt[6].player and tt[6].name == "" and tt[6].value == "1:02.500" and tt[6].points == "", "record row without a name: %s" % tt[6])
	# Battle: the verdict is a sign, rows carry the balloon state, the clock is plain text
	var b := Hud.parse_results("BATTLE - Block Fort\nYOU WIN!\n\n> 1st  YOU      2 balloons\n  2nd  GREEN    bomb kart\n  4th  BLUE     exploded\n\nBattle time 1:02.3\nPress ENTER to battle again")
	runner.check(b[1].kind == "sign" and b[1].text == "YOU WIN!", "verdict sign")
	runner.check(b[3].kind == "rank" and b[3].value == "2 balloons" and b[4].value == "bomb kart" and b[5].value == "exploded" and b[5].ordinal == "4th", "battle rows")
	runner.check(b[7].kind == "text" and b[7].text == "Battle time 1:02.3" and b[8].kind == "prompt", "clock + prompt")
	runner.check(Hud.parse_results("BATTLE - X\nBLUE WINS")[1].kind == "sign", "rival verdict is a sign")
	runner.check(Hud.ordinal_color("1st") == UiStyle.GOLD and Hud.ordinal_color("2nd") == Hud.SILVER and Hud.ordinal_color("3rd") == Hud.BRONZE and Hud.ordinal_color("4th") == UiStyle.CREAM, "podium colours")

func test_results_board_wraps_the_rows() -> void:
	var hud = Hud.new()
	hud._ready()
	runner.check(not hud.results_panel.visible and hud.results_text == "", "hidden at start")
	hud.update_minimap([Vector3.ZERO], [Color(0.2, 0.9, 0.3)])
	var rows := RaceResults.rows(["YOU", "BLUE", "GREEN", "PURPLE"], [10.0, 5.0, 4.0, 3.0], [60.0, 61.0, -1.0, -1.0])
	var text := RaceResults.table_text(rows, 0)
	hud.show_results(text)
	runner.check(hud.results_panel.visible and hud.results_text == text, "shown with the table text kept")
	runner.check(hud.results_title.text == "RESULTS" and hud.results_title_panel.position.y < 0.0, "title in a pill over the top edge")
	var labels: Array = []
	var panels: Array = []
	runner.check(hud.results_box.get_children().all(func(r): return r is Control and r.name.begins_with("Row")), "one row Control per board item")
	for c in _cells(hud):
		if c is Label:
			labels.append(c)
		elif c is Panel:
			panels.append(c)
	var texts: Array = labels.map(func(l): return l.text)
	runner.check("1st" in texts and "YOU" in texts and "1:00.000" in texts and "+9" in texts and "4th" in texts and "PURPLE" in texts, "one label per cell: %s" % str(texts))
	runner.check(not texts.any(func(t): return ">" in t), "no '>' marker on the board (the player's row is a lit bar instead)")
	runner.check(panels.size() == 5, "a lit bar for the player + 4 colour swatches: %d" % panels.size())
	var bar: Panel = panels[0]
	var bar_sb := bar.get_theme_stylebox("panel") as StyleBoxFlat
	runner.check(bar_sb.border_color == UiStyle.GOLD and bar.size.x > 500.0, "player bar is gold and spans the board")
	var you_dot := panels[1].get_theme_stylebox("panel") as StyleBoxFlat
	runner.check(you_dot.bg_color == Color(0.2, 0.9, 0.3), "the player's swatch takes the kart colour from the minimap markers")
	runner.check((panels[2].get_theme_stylebox("panel") as StyleBoxFlat).bg_color == Color.BLUE, "BLUE's swatch is blue")
	for l in labels:
		runner.check(l.get_theme_constant("outline_size") == 0 and l.get_theme_font("font") == hud.font, "board text: rounded font, no outline")
	runner.check(hud.results_prompts.size() == 1 and hud.results_prompts[0].text.begins_with("Press ENTER"), "blinking prompt")
	var h: float = hud.results_panel.offset_bottom - hud.results_panel.offset_top
	var expected: float = 2.0 * Hud.BOARD_PAD.y + Hud.BOARD_TITLE_H * 0.5 + 4.0 * Hud.ROW_H + Hud.GAP_H + Hud.PROMPT_H
	runner.check(is_equal_approx(h, expected) and is_equal_approx(hud.results_panel.offset_right - hud.results_panel.offset_left, Hud.BOARD_W), "panel = rows + padding: %s" % h)
	runner.check(is_equal_approx(hud.results_panel.offset_left, -hud.results_panel.offset_right), "centred horizontally")
	var sb := hud.results_panel.get_theme_stylebox("panel") as StyleBoxFlat
	runner.check(sb != null and sb.border_color == UiStyle.PANEL_RIM and sb.bg_color == UiStyle.PANEL_FILL, "navy panel with a gold rim")
	# an 8-racer Grand Prix board (results + standings) still fits a 720 px window
	var names := ["YOU", "BLUE", "GREEN", "PURPLE", "YELLOW", "ORANGE", "PINK", "TEAL"]
	var gp_rows := RaceResults.rows(names, [8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0], [90.0, 91.0, 92.0, 93.0, -1.0, -1.0, -1.0, -1.0])
	var standings := "CUP STANDINGS  (RACE 2 / 4)\n"
	for i in 8:
		standings += "%s %-4s %-8s %3d pts\n" % [">" if i == 0 else " ", "%dth" % (i + 1), names[i], 10 - i]
	standings += "\nPress ENTER for the next race"
	hud.show_results(RaceResults.table_text(gp_rows, 0, standings))
	var gp_h: float = hud.results_panel.offset_bottom - hud.results_panel.offset_top
	runner.check(gp_h + Hud.BOARD_TITLE_H * 0.5 <= 720.0, "GP board height %s fits 720 px" % gp_h)
	runner.check(is_equal_approx(hud.results_panel.offset_right - hud.results_panel.offset_left, Hud.BOARD_W_WIDE), "results and cup standings side by side (wide board)")
	var parts: Array = Hud.split_columns(Hud.parse_results(hud.results_text))
	runner.check(parts[0].size() == 9 and parts[1].size() == 9 and parts[1][0].kind == "section" and parts[2].size() == 2 and parts[2][1].kind == "prompt", "columns: results | standings, prompt below: %d %d %d" % [parts[0].size(), parts[1].size(), parts[2].size()])
	runner.check(Hud.split_columns(Hud.parse_results(text))[1].is_empty(), "a plain race result stays a single column")
	_check_no_clipping(hud, "grand prix")
	hud.show_results(RaceResults.table_text(gp_rows, 0, "CUP STANDINGS  (RACE 4 / 4)\n" + standings.split("\n", false)[1] + "\n\nRANK OUT!  6th - finish 4th or better to go on\nPress ENTER to retry the race"))
	_check_no_clipping(hud, "rank out")
	hud.show_results("TIME TRIAL - Sunset Speedway\nTIME      1:02.500   NEW RECORD!\nLAP 1     0:21.000\nLAP 2     0:20.100\nLAP 3     0:21.400\nBEST LAP  0:20.100   NEW!\n\nRECORDS\n> 1st  1:02.500\n  2nd  1:05.000\n  3rd  1:07.250\n\nPress ENTER to race your ghost")
	runner.check(is_equal_approx(hud.results_panel.offset_right - hud.results_panel.offset_left, Hud.BOARD_W_WIDE), "time trial: laps | records side by side")
	_check_no_clipping(hud, "time trial")
	hud.show_results("BATTLE - Block Fort\nYOU WIN!\n\n> 1st  YOU      2 balloons\n  2nd  GREEN    bomb kart\n  3rd  PURPLE   exploded\n  4th  BLUE     exploded\n\nBattle time 1:02.3\nPress ENTER to battle again")
	_check_no_clipping(hud, "battle")
	hud.show_results("")
	runner.check(not hud.results_panel.visible and hud.results_box.get_child_count() == 0 and hud.results_text == "", "hidden again, rows cleared")
	hud.free()

## The board's cells (labels, bars, swatches, rules) across all its rows.
static func _cells(hud) -> Array:
	var out: Array = []
	for r in hud.results_box.get_children():
		out.append_array(r.get_children())
	return out

## MK64 style reveal: the rows slide in from the left one after another (results, then standings,
## then the trophy sign and the prompt), a tick per ranking row, and settle in place.
func test_results_rows_slide_in_one_after_another() -> void:
	var p0 := Hud.reveal_pose(0.0, 0)
	runner.check(is_equal_approx(p0.x, -Hud.REVEAL_SLIDE) and p0.alpha == 0.0, "a row starts off to the left, invisible")
	var p_end := Hud.reveal_pose(Hud.REVEAL_TIME, 0)
	runner.check(is_equal_approx(p_end.x, 0.0) and is_equal_approx(p_end.alpha, 1.0), "and has arrived after REVEAL_TIME")
	var mid := Hud.reveal_pose(Hud.REVEAL_TIME * 0.5, 0)
	runner.check(mid.x > -Hud.REVEAL_SLIDE and mid.x < 0.0 and mid.alpha > 0.5, "ease-out: past halfway at half time (%s)" % mid)
	runner.check(Hud.reveal_pose(Hud.REVEAL_STAGGER * 3, 3).alpha == 0.0 and Hud.reveal_pose(Hud.REVEAL_STAGGER * 3, 2).alpha > 0.0, "row 3 waits its turn while row 2 is on its way")
	runner.check(is_equal_approx(Hud.reveal_length(5), 4 * Hud.REVEAL_STAGGER + Hud.REVEAL_TIME) and Hud.reveal_length(0) == 0.0, "reveal length")
	var hud = Hud.new()
	hud._ready()
	var names := ["YOU", "BLUE", "GREEN", "PURPLE", "YELLOW", "ORANGE", "PINK", "TEAL"]
	var gp_rows := RaceResults.rows(names, [8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0], [90.0, 91.0, 92.0, 93.0, -1.0, -1.0, -1.0, -1.0])
	var standings := "CUP STANDINGS  (RACE 4 / 4)\n"
	for i in names.size():
		standings += "%s %-4s %-8s %2d pts\n" % [">" if i == 0 else " ", "%dth" % (i + 1), names[i], 27 - 3 * i]
	hud.show_results(RaceResults.table_text(gp_rows, 0, standings + "\nGOLD TROPHY!  Press ENTER for the menu"))
	var rows: Array = hud.reveal_rows
	runner.check(rows.size() == 8 + 9 + 2 and hud.reveal_t == 0.0 and hud.ticks == 0, "8 result rows, the standings caption + 8 rows, the sign and the prompt: %d" % rows.size())
	runner.check(rows.all(func(r): return r.modulate.a == 0.0 and is_equal_approx(r.position.x, r.get_meta("base_x") - Hud.REVEAL_SLIDE)), "every row starts off to the left, invisible")
	runner.check(rows[8].get_meta("base_x") > rows[7].get_meta("base_x") and rows[17].get_meta("base_x") == 0.0, "results rows, then the standings column, then the full-width tail")
	runner.check(rows.slice(0, 8).all(func(r): return r.get_meta("tick")) and not rows[8].get_meta("tick") and not rows[17].get_meta("tick"), "ranking rows tick, captions / signs / prompts do not")
	hud._process(1.0 / 60.0)
	runner.check(rows[0].modulate.a > 0.0 and rows[0].position.x > rows[0].get_meta("base_x") - Hud.REVEAL_SLIDE and rows[1].modulate.a == 0.0, "a frame in: the first row is on its way, the second still waits")
	runner.check(hud.ticks == 1, "the first row ticked")
	for i in int(Hud.REVEAL_STAGGER * 8 * 60):
		hud._process(1.0 / 60.0)
	runner.check(rows[7].modulate.a > 0.0 and rows[9].modulate.a == 0.0, "the last result row is in before the first standings row starts")
	runner.check(hud.ticks == 8, "one tick per result row so far: %d" % hud.ticks)
	for i in 120:
		hud._process(1.0 / 60.0)
	runner.check(hud.reveal_t < 0.0 and rows.all(func(r): return r.modulate.a == 1.0 and is_equal_approx(r.position.x, r.get_meta("base_x"))), "settled: every row in place, the reveal over")
	runner.check(hud.ticks == 16, "16 ranking rows ticked, nothing else: %d" % hud.ticks)
	var blink_before: float = hud.results_prompts[0].modulate.a
	hud._process(1.0 / 60.0)
	runner.check(hud.results_prompts[0].modulate.a != blink_before and rows[18].modulate.a == 1.0, "the prompt still blinks on its own after the reveal")
	hud.show_results("")
	runner.check(hud.reveal_rows.is_empty() and hud.reveal_t < 0.0, "hidden: no rows, no reveal")
	hud.free()

## Every cell's text fits the width it was given (no clipped names, times or prompts).
func _check_no_clipping(hud, what: String) -> void:
	var inner_w: float = hud.results_box.size.x
	for c in _cells(hud):
		if c is Label:
			var x: float = c.get_parent().get_meta("base_x") + c.position.x
			runner.check(c.get_minimum_size().x <= c.size.x + 0.5, "%s board: '%s' needs %.0f px, has %.0f" % [what, c.text, c.get_minimum_size().x, c.size.x])
			runner.check(x >= 0.0 and x + c.size.x <= inner_w + 0.5, "%s board: '%s' inside the panel" % [what, c.text])
	runner.check(hud.results_title.get_minimum_size().x <= hud.results_title.size.x, "%s board: title fits its pill" % what)

func test_style_helpers() -> void:
	runner.check(UiStyle.shadow_offset(14) == 2 and UiStyle.shadow_offset(30) == 3 and UiStyle.shadow_offset(72) == 5)
	var l := Label.new()
	UiStyle.style_sign(l, UiStyle.make_font(), 32)
	runner.check(l.get_theme_constant("outline_size") == 3, "small signs keep a 3 px rim")
	l.free()
