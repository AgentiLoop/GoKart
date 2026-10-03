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

func test_mk64_rank_out_retries_the_race() -> void:
	## MK64: 5th or worse scores nothing and the race is run again (unlimited tries).
	runner.check(GrandPrix.QUALIFY_RANK == 4)
	runner.check(GrandPrix.qualifies(1) and GrandPrix.qualifies(4))
	runner.check(not GrandPrix.qualifies(5) and not GrandPrix.qualifies(8) and not GrandPrix.qualifies(0))
	GrandPrix.start([0, 1, 2], 8)
	runner.check(not GrandPrix.retry and GrandPrix.retries == 0)
	var rows := _rows([1, 2, 3, 4, 5, 0, 6, 7])      # player 6th
	runner.check(GrandPrix.rank_in(rows, 0) == 6 and GrandPrix.rank_in(rows, 1) == 1 and GrandPrix.rank_in(rows, 9) == 0)
	runner.check(not GrandPrix.add_race(rows, 0), "6th does not count")
	runner.check(GrandPrix.retry and GrandPrix.last_rank == 6)
	runner.check(GrandPrix.totals == [0, 0, 0, 0, 0, 0, 0, 0], "no points for anyone: %s" % str(GrandPrix.totals))
	runner.check(GrandPrix.grid.is_empty(), "the grid is unchanged by a race that did not count")
	runner.check(GrandPrix.race_index == 0 and GrandPrix.race_label() == "RACE 1 / 3")
	var names := ["YOU", "BLUE", "GREEN", "PURPLE", "YELLOW", "ORANGE", "PINK", "TEAL"]
	var txt := GrandPrix.standings_text(names, 0)
	runner.check("RANK OUT!  6th - finish 4th or better" in txt, txt)
	runner.check("retry the race" in txt and not "next race" in txt and not "TROPHY" in txt, txt)
	# Enter: the same race again, flagged on the HUD label
	GrandPrix.begin_retry()
	runner.check(not GrandPrix.retry and GrandPrix.retries == 1 and GrandPrix.race_index == 0)
	runner.check(GrandPrix.race_label() == "RACE 1 / 3  RETRY", GrandPrix.race_label())
	runner.check("RACE 1 / 3  RETRY" in GrandPrix.standings_text(names, 0))
	# a second failure on the same race
	runner.check(not GrandPrix.add_race(_rows([1, 2, 3, 4, 0, 5, 6, 7]), 0) and GrandPrix.retry and GrandPrix.last_rank == 5)
	GrandPrix.begin_retry()
	runner.check(GrandPrix.retries == 2)
	# 4th is enough: points count and the cup moves on
	runner.check(GrandPrix.add_race(_rows([1, 2, 3, 0, 4, 5, 6, 7]), 0), "4th counts")
	runner.check(not GrandPrix.retry and GrandPrix.last_rank == 4)
	runner.check(GrandPrix.totals == [1, 9, 6, 3, 0, 0, 0, 0], str(GrandPrix.totals))
	runner.check("next race" in GrandPrix.standings_text(names, 0))
	runner.check(GrandPrix.advance() and GrandPrix.retries == 0 and GrandPrix.race_label() == "RACE 2 / 3")
	# a rank-out on the last race blocks the trophy
	GrandPrix.race_index = 2
	runner.check(not GrandPrix.add_race(_rows([1, 2, 3, 4, 5, 6, 7, 0]), 0))
	var last := GrandPrix.standings_text(names, 0)
	runner.check("RANK OUT!  8th" in last and "retry" in last and not "TROPHY" in last, last)
	GrandPrix.stop()
	runner.check(not GrandPrix.retry and GrandPrix.retries == 0 and GrandPrix.last_rank == 0 and GrandPrix.grid.is_empty())

func test_mk64_grid_follows_the_last_finish() -> void:
	## MK64: from the second race on, everyone starts where they finished the last race.
	var Main := load("res://scripts/main.gd")
	runner.check(GrandPrix.grid_slot_for(0, 7) == 7 and GrandPrix.grid_slot_for(3, 2) == 2, "defaults with no cup")
	GrandPrix.start([0, 1, 2], 8)
	for id in 8:
		runner.check(GrandPrix.grid_slot_for(id, id) == id, "first race: default slots")
	GrandPrix.add_race(_rows([3, 0, 7, 1, 2, 4, 5, 6]), 0)
	runner.check(GrandPrix.grid == [3, 0, 7, 1, 2, 4, 5, 6], str(GrandPrix.grid))
	runner.check(GrandPrix.grid_slot_for(0, 7) == 1, "player 2nd -> second slot")
	runner.check(GrandPrix.grid_slot_for(3, 2) == 0, "PURPLE on pole")
	runner.check(GrandPrix.grid_slot_for(6, 5) == 7, "TEAL at the back")
	# the slots form the MK64 two-column grid: pole is the front row, the last slot the back row
	runner.check(Main.GRID_SLOTS[0][0] > Main.GRID_SLOTS[7][0] and Main.GRID_SLOTS[0][1] < 0.0 and Main.GRID_SLOTS[1][1] > 0.0)
	# a ranked-out retry keeps the grid of the race that counted
	GrandPrix.advance()
	GrandPrix.add_race(_rows([1, 2, 3, 4, 5, 6, 7, 0]), 0)
	runner.check(GrandPrix.grid == [3, 0, 7, 1, 2, 4, 5, 6], "unchanged after a rank-out")
	GrandPrix.add_race(_rows([0, 1, 2, 3, 4, 5, 6, 7]), 0)
	runner.check(GrandPrix.grid_slot_for(0, 7) == 0, "the winner takes pole")
	GrandPrix.stop()

func test_menu_mode_keys_and_cup_order() -> void:
	runner.check(Menu.is_mode_key(KEY_G) and Menu.is_mode_key(KEY_TAB))
	runner.check(not Menu.is_mode_key(KEY_ENTER) and not Menu.is_mode_key(KEY_A))
	runner.check(Menu.cup_order(0, 3) == [0, 1, 2])
	runner.check(Menu.cup_order(2, 3) == [2, 0, 1], str(Menu.cup_order(2, 3)))
	runner.check("GRAND PRIX" in Menu.mode_text(Menu.MODE_GP, 3) and "3 races" in Menu.mode_text(Menu.MODE_GP, 3))
	runner.check("SINGLE" in Menu.mode_text(Menu.MODE_SINGLE, 3))
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
	runner.check(m.mode == Menu.MODE_BATTLE)
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_SINGLE)
	for n in [m.laps_label, m.difficulty_label, m.engine_label, m.weight_label, m.mode_label, m.name_label, m.blurb_label, m.index_label, m.bg, m.preview, m]:
		n.free()

func test_mk64_cup_has_four_courses() -> void:
	## Mario Kart 64 cups are four courses long; the library's cup runs every course once.
	var L = load("res://scripts/track_library.gd")
	runner.check(L.count() == 4, "four courses: %d" % L.count())
	runner.check(L.info(3).name == "Dusty Canyon" and "desert" in L.info(3).blurb, L.info(3).name)
	var order: Array = Menu.cup_order(0, L.count())
	runner.check(order == [0, 1, 2, 3], str(order))
	runner.check(Menu.cup_order(3, L.count()) == [3, 0, 1, 2], "the cup starts on the selected course and wraps")
	runner.check("4 races" in Menu.mode_text(Menu.MODE_GP, L.count()))
	GrandPrix.start(order, 8)
	runner.check(GrandPrix.race_label() == "RACE 1 / 4", GrandPrix.race_label())
	for i in 3:
		runner.check(GrandPrix.advance(), "race %d -> %d" % [i + 1, i + 2])
	runner.check(GrandPrix.is_last_race() and GrandPrix.current_track() == 3 and GrandPrix.race_label() == "RACE 4 / 4")
	runner.check(not GrandPrix.advance(), "no fifth race")
	GrandPrix.stop()
	# the desert course is a distinct, drivable circuit with its own theme
	var d = L.make_data(3)
	runner.check(d.length > 900.0 and d.length < 1200.0, "lap length %.0f m" % d.length)
	runner.check(d.water.size() == 2, "an oasis on each side: %d spans" % d.water.size())
	runner.check(L.info(3).ground != L.info(1).ground and L.info(3).sky_horizon != L.info(1).sky_horizon, "its own desert palette")
	for i in 3:
		runner.check(L.info(i).control != L.info(3).control, "layout differs from course %d" % i)
