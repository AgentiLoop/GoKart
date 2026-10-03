extends RefCounted

const RaceResults := preload("res://scripts/race_results.gd")
var runner

func test_points() -> void:
	runner.check(RaceResults.points_for(1) == 9)
	runner.check(RaceResults.points_for(4) == 1)
	runner.check(RaceResults.points_for(5) == 0, "MK64: nothing below 4th")
	runner.check(RaceResults.points_for(0) == 0)
	runner.check(RaceResults.points_for(99) == 0)

func test_time_text() -> void:
	runner.check(RaceResults.time_text(65.4321) == "1:05.432", RaceResults.time_text(65.4321))
	runner.check(RaceResults.time_text(0.0) == "0:00.000")

func test_rows_finished_by_time_then_progress() -> void:
	var names := ["YOU", "BLU", "GRN", "PUR"]
	var progs := [600.0, 590.0, 450.0, 520.0]
	var fins := [100.0, 95.0, -1.0, -1.0]
	var rows := RaceResults.rows(names, progs, fins)
	runner.check(rows.size() == 4)
	runner.check(rows[0].id == 1 and rows[0].rank == 1 and rows[0].finished)
	runner.check(rows[1].id == 0 and rows[1].time == "1:40.000", str(rows[1]))
	runner.check(rows[2].id == 3 and not rows[2].finished and rows[2].time == "--:--.---", str(rows[2]))
	runner.check(rows[3].id == 2)
	runner.check(rows[0].points == 9 and rows[3].points == 1)

func test_table_text_marks_player() -> void:
	var rows := RaceResults.rows(["YOU", "BLU"], [10.0, 5.0], [-1.0, -1.0])
	var txt := RaceResults.table_text(rows, 0)
	var lines := txt.split("\n")
	runner.check(lines[0] == "RESULTS")
	runner.check(lines[1].begins_with(">") and "YOU" in lines[1], lines[1])
	runner.check(lines[2].begins_with(" ") and "BLU" in lines[2], lines[2])
	runner.check("ENTER" in lines[lines.size() - 1])
