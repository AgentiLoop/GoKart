extends RefCounted
## Grand Prix cup: MK64 points, order of races, standings and trophies.

const GrandPrix := preload("res://scripts/grand_prix.gd")
const RaceResults := preload("res://scripts/race_results.gd")
const Menu := preload("res://scripts/menu.gd")
var runner

func _rows(order: Array) -> Array:
	## finishing order given as racer ids first..last
	var out: Array = []
	for r in order.size():
		out.append({"rank": r + 1, "id": order[r]})
	return out

func test_mk64_points() -> void:
	runner.check(GrandPrix.points_for(1) == 9 and GrandPrix.points_for(2) == 6)
	runner.check(GrandPrix.points_for(3) == 3 and GrandPrix.points_for(4) == 1)
	runner.check(GrandPrix.points_for(5) == 0 and GrandPrix.points_for(0) == 0)
	runner.check(RaceResults.POINTS == GrandPrix.POINTS, "single race and cup share the MK64 table")

func test_start_and_stop() -> void:
	GrandPrix.start([2, 0, 1], 4)
	runner.check(GrandPrix.active and GrandPrix.race_index == 0)
	runner.check(GrandPrix.current_track() == 2)
	runner.check(GrandPrix.totals == [0, 0, 0, 0])
	runner.check(not GrandPrix.is_last_race())
	runner.check(GrandPrix.race_label() == "RACE 1 / 3", GrandPrix.race_label())
	GrandPrix.stop()
	runner.check(not GrandPrix.active and GrandPrix.current_track() == -1 and GrandPrix.totals.is_empty())

func test_points_accumulate_and_advance() -> void:
	GrandPrix.start([0, 1, 2], 4)
	GrandPrix.add_race(_rows([1, 0, 3, 2]))      # BLUE wins, player 2nd
	runner.check(GrandPrix.totals == [6, 9, 1, 3], str(GrandPrix.totals))
	runner.check(GrandPrix.advance() and GrandPrix.race_index == 1 and GrandPrix.current_track() == 1)
	GrandPrix.add_race(_rows([0, 1, 2, 3]))      # player wins
	runner.check(GrandPrix.totals == [15, 15, 4, 4], str(GrandPrix.totals))
	runner.check(GrandPrix.advance() and GrandPrix.is_last_race())
	GrandPrix.add_race(_rows([0, 2, 1, 3]))
	runner.check(GrandPrix.totals == [24, 18, 10, 5], str(GrandPrix.totals))
	runner.check(not GrandPrix.advance(), "no race after the last one")
	runner.check(GrandPrix.race_index == 2)
	GrandPrix.stop()

func test_standings_and_trophy() -> void:
	GrandPrix.start([0, 1, 2], 4)
	GrandPrix.totals = [15, 15, 4, 20]
	runner.check(GrandPrix.standings() == [3, 0, 1, 2], str(GrandPrix.standings()))
	runner.check(GrandPrix.cup_rank(0) == 2, "player wins the tie on points")
	runner.check(GrandPrix.cup_rank(3) == 1 and GrandPrix.cup_rank(2) == 4)
	runner.check(GrandPrix.trophy_text(1) == "GOLD TROPHY" and GrandPrix.trophy_text(3) == "BRONZE TROPHY")
	runner.check(GrandPrix.trophy_text(4) == "NO TROPHY")
	GrandPrix.stop()

func test_standings_text() -> void:
	var names := ["YOU", "BLUE", "GREEN", "PURPLE"]
	GrandPrix.start([0, 1, 2], 4)
	GrandPrix.totals = [9, 6, 3, 1]
	var txt := GrandPrix.standings_text(names, 0)
	var lines := txt.split("\n")
	runner.check(lines[0].begins_with("CUP STANDINGS") and "RACE 1 / 3" in lines[0], lines[0])
	runner.check(lines[1].begins_with(">") and "YOU" in lines[1] and "9 pts" in lines[1], lines[1])
	runner.check(lines[4].begins_with(" ") and "PURPLE" in lines[4] and "1 pts" in lines[4], lines[4])
	runner.check("next race" in lines[lines.size() - 1], lines[lines.size() - 1])
	GrandPrix.race_index = 2
	var last := GrandPrix.standings_text(names, 0).split("\n")
	runner.check("GOLD TROPHY" in last[last.size() - 1] and "menu" in last[last.size() - 1], last[last.size() - 1])
	# the results table takes the standings block as its footer
	var rows := RaceResults.rows(names, [10.0, 9.0, 8.0, 7.0], [50.0, 51.0, -1.0, -1.0])
	var table := RaceResults.table_text(rows, 0, GrandPrix.standings_text(names, 0))
	runner.check(table.begins_with("RESULTS") and "CUP STANDINGS" in table)
	runner.check(not "race again" in table)
	GrandPrix.stop()

func test_menu_mode_keys_and_cup_order() -> void:
	runner.check(Menu.is_mode_key(KEY_G) and Menu.is_mode_key(KEY_TAB))
	runner.check(not Menu.is_mode_key(KEY_ENTER) and not Menu.is_mode_key(KEY_A))
	runner.check(Menu.cup_order(0, 3) == [0, 1, 2])
	runner.check(Menu.cup_order(2, 3) == [2, 0, 1], str(Menu.cup_order(2, 3)))
	runner.check("GRAND PRIX" in Menu.mode_text(Menu.MODE_GP, 3) and "3 races" in Menu.mode_text(Menu.MODE_GP, 3))
	runner.check("Single" in Menu.mode_text(Menu.MODE_SINGLE, 3))
	var m = Menu.new()
	for prop in ["laps_label", "difficulty_label", "engine_label", "weight_label", "mode_label", "name_label", "blurb_label", "index_label"]:
		m.set(prop, Label.new())
	m.bg = ColorRect.new()
	m.preview = load("res://scripts/minimap.gd").new()
	runner.check(m.mode == Menu.MODE_SINGLE and m.mode_label.text == "")
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_GP and m.mode_label.text == Menu.mode_text(Menu.MODE_GP, load("res://scripts/track_library.gd").count()))
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_TT)
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_SINGLE)
	for n in [m.laps_label, m.difficulty_label, m.engine_label, m.weight_label, m.mode_label, m.name_label, m.blurb_label, m.index_label, m.bg, m.preview, m]:
		n.free()
