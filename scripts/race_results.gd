extends RefCounted
## Final standings table (pure). Finished racers are ordered by finish time, the rest by
## race progress (RaceRanking); each row carries the rank, display name, time text and points.

const RaceRanking := preload("res://scripts/race_ranking.gd")

## Mario Kart 64 points table: 9 / 6 / 3 / 1 for 1st..4th, nothing below.
const POINTS := [9, 6, 3, 1, 0, 0, 0, 0]

static func points_for(rank: int) -> int:
	if rank < 1 or rank > POINTS.size():
		return 0
	return POINTS[rank - 1]

static func time_text(t: float) -> String:
	var total_ms := int(round(t * 1000.0))
	return "%d:%02d.%03d" % [total_ms / 60000, (total_ms / 1000) % 60, total_ms % 1000]

## names[i], progresses[i], finish_times[i] (< 0 = not finished) per racer index.
## Returns [{rank, id, name, finished, time, points}] first to last.
static func rows(names: Array, progresses: Array, finish_times: Array) -> Array:
	var out: Array = []
	var ord := RaceRanking.order(progresses, finish_times)
	for r in ord.size():
		var id: int = ord[r]
		var fin: bool = finish_times[id] >= 0.0
		out.append({
			"rank": r + 1,
			"id": id,
			"name": names[id],
			"finished": fin,
			"time": time_text(finish_times[id]) if fin else "--:--.---",
			"points": points_for(r + 1),
		})
	return out

## Multi-line text for the results panel; the player's row is marked with ">".
## `footer` replaces the default "race again" prompt (e.g. the Grand Prix standings block).
static func table_text(result_rows: Array, player_id := 0, footer := "Press ENTER to race again") -> String:
	var lines: Array = ["RESULTS"]
	for row in result_rows:
		lines.append("%s %-4s %-8s %s  +%d" % [">" if row.id == player_id else " ", RaceRanking.ordinal(row.rank), row.name, row.time, row.points])
	lines.append("")
	lines.append(footer)
	return "\n".join(lines)