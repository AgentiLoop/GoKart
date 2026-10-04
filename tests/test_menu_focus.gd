extends RefCounted
## The select screen's cursor (Mario Kart 64 menus: one stick, one button): Up / Down move a gold
## frame across the rows — course list, laps, CPU, engine, kart, mode — skipping the rows a mode
## locks, Left / Right change the row the frame is on, only the focused row's lit bar glows and the
## dedicated keys still work as shortcuts without moving the frame.

const Menu := preload("res://scripts/menu.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const KartWeight := preload("res://scripts/kart_weight.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
var runner

func _root() -> Node:
	return Engine.get_main_loop().root

func _menu() -> Node:
	var m = Menu.new()
	_root().add_child(m)
	if m.select_box == null:
		m._ready()   # the runner's root is not ready yet during _initialize
	m.dismiss_title()
	return m

## The lit bar Panel of an option row (null when the row is locked).
func _bar(row: Control) -> Panel:
	for c in row.get_children():
		if c is Panel:
			return c
	return null

## The course list's lit bar (the only Panel directly under list_box).
func _list_bar(m) -> Panel:
	for c in m.list_box.get_children():
		if c is Panel:
			return c
	return null

func _glows(bar: Panel) -> bool:
	var sb: StyleBoxFlat = bar.get_theme_stylebox("panel")
	return sb.border_color == UiStyle.GOLD and sb.bg_color.a > 0.15

func _frame_rect(m) -> Rect2:
	return Rect2(m.focus_frame.position, m.focus_frame.size)

func test_focus_helpers() -> void:
	runner.check(Menu.focus_direction_for_key(KEY_UP) == -1 and Menu.focus_direction_for_key(KEY_DOWN) == 1, "arrows move the cursor")
	runner.check(Menu.focus_direction_for_key(KEY_W) == 0 and Menu.focus_direction_for_key(KEY_LEFT) == 0 and Menu.focus_direction_for_key(KEY_ENTER) == 0, "other keys do not")
	runner.check(Menu.locked_rows(Menu.MODE_SINGLE).is_empty() and Menu.locked_rows(Menu.MODE_GP).is_empty(), "nothing locked in a race / cup")
	runner.check(Menu.locked_rows(Menu.MODE_TT) == [Menu.FOCUS_LAPS, Menu.FOCUS_CPU, Menu.FOCUS_ENGINE], "time trial locks laps / CPU / engine")
	runner.check(Menu.locked_rows(Menu.MODE_BATTLE) == [Menu.FOCUS_LAPS], "battle locks the balloons")
	# stepping: down the rows, wrapping, skipping the locked ones, and up again
	runner.check(Menu.next_focus(Menu.FOCUS_LIST, 1, []) == Menu.FOCUS_LAPS and Menu.next_focus(Menu.FOCUS_MODE, 1, []) == Menu.FOCUS_LIST, "down, wrapping")
	runner.check(Menu.next_focus(Menu.FOCUS_LIST, -1, []) == Menu.FOCUS_MODE and Menu.next_focus(Menu.FOCUS_LAPS, -1, []) == Menu.FOCUS_LIST, "up, wrapping")
	runner.check(Menu.next_focus(Menu.FOCUS_LIST, 1, Menu.locked_rows(Menu.MODE_TT)) == Menu.FOCUS_KART, "time trial: list -> kart")
	runner.check(Menu.next_focus(Menu.FOCUS_KART, -1, Menu.locked_rows(Menu.MODE_TT)) == Menu.FOCUS_LIST, "time trial: kart <- list")
	runner.check(Menu.next_focus(Menu.FOCUS_LIST, 1, Menu.locked_rows(Menu.MODE_BATTLE)) == Menu.FOCUS_CPU, "battle: list -> CPU")
	var all_rows: Array = []
	for f in Menu.FOCUS_COUNT:
		all_rows.append(f)
	runner.check(Menu.next_focus(Menu.FOCUS_LAPS, 1, all_rows) == Menu.FOCUS_LAPS, "everything locked: stays put")
	runner.check(Menu.step_mode(Menu.MODE_SINGLE, -1) == Menu.MODE_BATTLE and Menu.step_mode(Menu.MODE_BATTLE, 1) == Menu.MODE_SINGLE and Menu.next_mode(Menu.MODE_GP) == Menu.MODE_TT, "mode steps both ways")
	# frame rects: round the list rows inside the list panel, round each option row inside its cell
	var list_panel := Rect2(80, 220, 420, 278)
	runner.check(list_panel.encloses(Menu.focus_rect(Menu.FOCUS_LIST)), "list frame inside the list panel")
	var rows_rect := Rect2(80 + 16, 220 + Menu.LIST_ROW_Y, 388, Menu.LIST_ROW_STEP * 3 + Menu.LIST_BAR_H)
	runner.check(Menu.focus_rect(Menu.FOCUS_LIST).encloses(rows_rect), "list frame round all four rows' bars")
	for f in range(Menu.FOCUS_LAPS, Menu.FOCUS_COUNT):
		var r := Menu.focus_rect(f)
		var row := Menu.row_rect(f - 1)
		runner.check(r.encloses(row) and r.position.x < row.position.x and r.end.y > row.end.y, "frame %d round its row" % f)
		runner.check(Rect2(80, 500, 1120, 142).encloses(r), "frame %d inside the option panel" % f)


func test_cursor_moves_and_changes_the_focused_row() -> void:
	var m = _menu()
	runner.check(m.focus == Menu.FOCUS_LIST and m.focus_frame != null and m.focus_frame.get_parent() == m.select_box, "cursor starts on the course list")
	runner.check(_frame_rect(m) == Menu.focus_rect(Menu.FOCUS_LIST), "frame round the list")
	runner.check(m.select_box.get_child(-1) == m.focus_frame, "frame drawn over everything else")
	runner.check(_glows(_list_bar(m)) and not _glows(_bar(m.option_rows[0])) and not _glows(_bar(m.option_rows[4])), "only the list's bar glows")
	runner.check(m.list_caption.get_theme_color("font_color") == UiStyle.GOLD and m.cell_captions[0].get_theme_color("font_color") == UiStyle.GOLD_DIM, "list caption lit, LAPS dim")
	var sb: StyleBoxFlat = m.focus_frame.get_theme_stylebox("panel")
	runner.check(sb.bg_color.a == 0.0 and sb.border_color == Menu.FOCUS_RIM and sb.border_width_top == 3, "frame: gold rim, no fill")
	# Left / Right on the list pick the course
	var first: int = m.selected
	m.move_focused(1)
	runner.check(m.selected == TrackLibrary.step(first, 1) and m.focus == Menu.FOCUS_LIST, "Right picks the next course, cursor stays")
	m.move_focused(-1)
	# Down -> laps: the frame moves, the laps bar glows, the list bar dims
	m.move_focus(1)
	runner.check(m.focus == Menu.FOCUS_LAPS and _frame_rect(m) == Menu.focus_rect(Menu.FOCUS_LAPS), "Down: cursor on laps, frame round the laps row")
	runner.check(_glows(_bar(m.option_rows[0])) and not _glows(_list_bar(m)), "laps bar glows, list bar dim")
	runner.check(m.cell_captions[0].get_theme_color("font_color") == UiStyle.GOLD and m.list_caption.get_theme_color("font_color") == UiStyle.GOLD_DIM, "LAPS caption lit, list caption dim")
	runner.check(m.audio.played[-1] == "cursor", "the cursor ticks")
	var laps0: int = m.laps
	m.move_focused(1)
	runner.check(m.laps == TrackLibrary.step_laps(laps0, 1) and m.selected == first, "Right raises laps, not the course")
	# down the rest of the rows: CPU, engine, kart, mode, back to the list
	m.move_focus(1)
	var diff0: int = m.difficulty
	m.move_focused(-1)
	runner.check(m.focus == Menu.FOCUS_CPU and m.difficulty == TrackLibrary.step_difficulty(diff0, -1), "CPU row: Left steps the difficulty")
	m.move_focus(1)
	var eng0: int = m.engine_class
	m.move_focused(-1)
	runner.check(m.focus == Menu.FOCUS_ENGINE and m.engine_class == TrackLibrary.step_engine(eng0, -1), "engine row: Left steps the class")
	m.move_focus(1)
	m.move_focused(1)
	runner.check(m.focus == Menu.FOCUS_KART and m.weight_class == KartWeight.HEAVY, "kart row: Right picks Heavy")
	m.move_focus(1)
	runner.check(m.focus == Menu.FOCUS_MODE and _glows(_bar(m.option_rows[4])) and m.mode_caption.get_theme_color("font_color") == UiStyle.GOLD, "mode row: tabs' bar glows, MODE caption lit")
	m.move_focused(1)
	runner.check(m.mode == Menu.MODE_GP and m.mode_label.text.begins_with("GRAND PRIX"), "Right tabs to Grand Prix")
	m.move_focused(-1)
	runner.check(m.mode == Menu.MODE_SINGLE, "Left tabs back")
	m.move_focus(1)
	runner.check(m.focus == Menu.FOCUS_LIST and _glows(_list_bar(m)), "Down from the mode row wraps to the list")
	m.move_focus(-1)
	runner.check(m.focus == Menu.FOCUS_MODE, "Up from the list wraps to the mode row")
	# shortcuts leave the cursor alone
	m.move_laps(1)
	m.move_engine(1)
	m.move_weight(-1)
	m.toggle_mode()
	runner.check(m.focus == Menu.FOCUS_MODE and m.mode == Menu.MODE_GP, "W / Z / X / G change their option, the cursor stays")
	m.toggle_mode()
	m.toggle_mode()
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_SINGLE, "back to a single race")
	m.free()

func test_cursor_skips_locked_rows() -> void:
	var m = _menu()
	m.move_focus(1)
	runner.check(m.focus == Menu.FOCUS_LAPS, "cursor on laps")
	# a time trial locks the row under the cursor: it moves on to the kart row
	m.toggle_mode()
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_TT and m.focus == Menu.FOCUS_KART, "time trial: cursor leaves the locked laps row for the kart row")
	runner.check(_bar(m.option_rows[0]) == null and m.laps_note.text == "Time Trial" and m.difficulty_note.text == "Time Trial", "locked rows carry the note")
	m.move_focus(-1)
	runner.check(m.focus == Menu.FOCUS_LIST, "Up skips the three locked rows")
	m.move_focus(1)
	runner.check(m.focus == Menu.FOCUS_KART, "Down skips them too")
	# battle: only the balloons are locked
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_BATTLE and m.laps_note.text == "Battle" and m.difficulty_note.text == "", "battle: balloons locked, CPU live")
	m.focus = Menu.FOCUS_LIST
	m._refresh()
	m.move_focus(1)
	runner.check(m.focus == Menu.FOCUS_CPU, "Down from the list lands on CPU (balloons skipped)")
	m.focus = Menu.FOCUS_LIST
	m._refresh()
	var arena0: int = m.arena_selected
	m.move_focused(1)
	runner.check(m.arena_selected != arena0 and m.name_label.text != "", "Right on the list picks the next arena")
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_SINGLE and m.laps_note.text == "" and m.engine_note.text == "", "single race: no notes")
	# no key-hint labels left on the option cells: every grey 12 px label there is an empty note
	var hints := 0
	for c in m.select_box.get_children():
		if c is Label and c.get_theme_font_size("font_size") == 12 and c.text != "":
			hints += 1
	runner.check(hints == 1 and m.weight_label.get_theme_font_size("font_size") == 12, "only the kart blurb is 12 px text (no W / S, Q / E ... hints): %d" % hints)
	m.free()
