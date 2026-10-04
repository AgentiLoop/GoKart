extends RefCounted
## Select-screen option rows (Mario Kart 64's Select Mode idiom: every choice listed, the picked
## one lit): the pill rows for laps / CPU / engine / kart, the mode tabs, the locked cells in a
## time trial / battle, the kart blurb fitting its cell and the prompt under the checkered band.

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

## Labels inside a row: [text, colour] for each, in slot order.
func _pills(row: Control) -> Array:
	var out: Array = []
	for c in row.get_children():
		if c is Label:
			out.append([c.text, c.get_theme_color("font_color")])
	return out

func _bars(row: Control) -> int:
	var n := 0
	for c in row.get_children():
		if c is Panel:
			n += 1
	return n

## True when the value label sits inside the row's rect (over the lit slot).
func _inside(l: Label, row: Control) -> bool:
	return Rect2(row.position, row.size).encloses(Rect2(l.position, l.size))

func test_choice_lists() -> void:
	runner.check(Menu.lap_names() == ["1", "2", "3", "5", "7"], "lap options as text: %s" % [Menu.lap_names()])
	runner.check(Menu.names_of(TrackLibrary.ENGINE_CLASSES) == ["50cc", "100cc", "150cc", "Extra"], "engine classes")
	runner.check(Menu.names_of(KartWeight.CLASSES) == ["Light", "Medium", "Heavy"], "weight classes")
	runner.check(Menu.MODE_NAMES.size() == Menu.MODE_COUNT, "a tab per mode")
	for m in Menu.MODE_COUNT:
		runner.check(Menu.mode_text(m, 4).begins_with(Menu.MODE_NAMES[m]), "mode text starts with the tab name: " + Menu.mode_text(m, 4))
	for slot in 4:
		var r := Menu.row_rect(slot)
		runner.check(r.position.x >= 80.0 + Menu.CELL_W * slot and r.end.x <= 80.0 + Menu.CELL_W * (slot + 1), "row %d inside its cell" % slot)
	var tabs := Menu.row_rect(4)
	runner.check(tabs.end.x <= Menu.MODE_BLURB_X, "mode tabs end before the mode blurb")

func test_rows_light_the_picked_choice() -> void:
	var m = _menu()
	runner.check(m.option_rows.size() == 5 and m.option_rows.all(func(r): return r != null), "five rows built")
	# laps: 1 2 3 5 7 with the cell's own label on the lit slot
	var laps_row: Control = m.option_rows[0]
	runner.check(_bars(laps_row) == 1, "one lit bar in the laps row")
	runner.check(_pills(laps_row).size() == TrackLibrary.LAP_OPTIONS.size() - 1, "the other lap choices are pills: %d" % _pills(laps_row).size())
	runner.check(m.laps_label.text == "3" and m.laps_label.get_theme_color("font_color") == UiStyle.GOLD and _inside(m.laps_label, laps_row), "laps value gold over the lit slot")
	var w: float = laps_row.size.x / TrackLibrary.LAP_OPTIONS.size()
	runner.check(is_equal_approx(m.laps_label.position.x, laps_row.position.x + w * 2), "lit slot is the third (3 laps)")
	m.move_laps(1)
	runner.check(m.laps == 5 and m.option_rows[0] != laps_row and is_equal_approx(m.laps_label.position.x, m.option_rows[0].position.x + w * 3), "W moves the lit slot to 5 laps (row rebuilt)")
	for p in _pills(m.option_rows[0]):
		runner.check(p[1] == Menu.UNLIT and p[0] != "5", "unpicked lap choices are dim: %s" % p[0])
	# engine: 50cc 100cc 150cc Extra, 150cc lit by default
	var eng: Control = m.option_rows[2]
	runner.check(_pills(eng).size() == 3 and _bars(eng) == 1 and m.engine_label.text == "150cc" and _inside(m.engine_label, eng), "engine row: 3 dim pills + the lit 150cc")
	# kart: Light Medium Heavy as pills (the lit one gold), the blurb underneath
	var kart: Control = m.option_rows[3]
	var kp := _pills(kart)
	runner.check(kp.size() == 3 and kp[1][0] == "Medium" and kp[1][1] == UiStyle.GOLD and kp[0][1] == Menu.UNLIT, "kart row: Medium lit")
	runner.check(m.weight_label.text == Menu.weight_text(KartWeight.MEDIUM) and m.weight_label.position.y >= kart.position.y + kart.size.y, "weight blurb under the pills")
	m.move_weight(1)
	runner.check(_pills(m.option_rows[3])[2][1] == UiStyle.GOLD and m.weight_label.text.begins_with("Heavy"), "V lights Heavy")
	# the longest blurb fits its cell at the blurb size
	for i in KartWeight.count():
		var wd: float = m.font.get_string_size(Menu.weight_text(i), HORIZONTAL_ALIGNMENT_CENTER, -1, Menu.BLURB_FONT).x
		runner.check(wd <= m.weight_label.size.x, "weight blurb %d fits: %.0f <= %.0f" % [i, wd, m.weight_label.size.x])
	# mode tabs: SINGLE RACE lit, the blurb to the right of the strip
	var tabs: Control = m.option_rows[4]
	var tp := _pills(tabs)
	runner.check(tp.size() == 4 and tp[0][0] == "SINGLE RACE" and tp[0][1] == UiStyle.GOLD and tp[1][1] == Menu.UNLIT, "mode tabs: SINGLE RACE lit")
	runner.check(m.mode_label.position.x >= tabs.position.x + tabs.size.x and m.mode_label.text == "SINGLE RACE", "mode blurb beside the tabs")
	m.toggle_mode()
	runner.check(_pills(m.option_rows[4])[1][1] == UiStyle.GOLD and m.mode_label.text.begins_with("GRAND PRIX"), "G lights GRAND PRIX")
	m.free()

func test_locked_cells_show_the_fixed_value_alone() -> void:
	var m = _menu()
	m.toggle_mode()
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_TT, "time trial")
	for slot in 3:
		var row: Control = m.option_rows[slot]
		runner.check(row.get_child_count() == 0, "locked row %d has no pills" % slot)
	runner.check(m.laps_label.text == "3" and m.laps_label.get_theme_color("font_color") == Menu.LOCKED and is_equal_approx(m.laps_label.size.x, m.option_rows[0].size.x), "laps value alone across the row in grey")
	runner.check(m.difficulty_label.text == "None" and m.engine_label.text == "100cc", "fixed CPU / engine")
	runner.check(_pills(m.option_rows[3]).size() == 3 and _pills(m.option_rows[4]).size() == 4, "kart and mode rows still live")
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_BATTLE and m.option_rows[0].get_child_count() == 0 and m.laps_caption.text == "BALLOONS", "battle: balloons locked")
	runner.check(_pills(m.option_rows[1]).size() == 2 and _pills(m.option_rows[2]).size() == 3, "battle keeps the CPU / engine choices")
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_SINGLE and _pills(m.option_rows[0]).size() == 4 and m.laps_label.get_theme_color("font_color") == UiStyle.GOLD, "single race: lap choices back")
	m.free()

func test_layout_and_no_outlines() -> void:
	var m = _menu()
	runner.check(m.prompt.position.y > m.backdrop.band_y + 18.0 and m.prompt.text == "PRESS ENTER", "prompt under the checkered band")
	var panel_bottom := 642.0
	for slot in 5:
		var row: Control = m.option_rows[slot]
		runner.check(row.position.y + row.size.y <= panel_bottom, "row %d inside the option panel" % slot)
	runner.check(m.weight_label.position.y + m.weight_label.size.y <= panel_bottom and m.mode_label.position.y + m.mode_label.size.y <= panel_bottom, "blurbs inside the panel")
	var outlined := 0
	var stack: Array = [m.select_box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and n.get_theme_constant("outline_size") > 0:
			outlined += 1
		stack.append_array(n.get_children())
	runner.check(outlined == 0, "no outlined text on the select screen: %d" % outlined)
	m.free()
