extends RefCounted
## Grand Prix cup state (pure, static so it survives scene changes), Mario Kart 64 style:
## every track in the library is raced in order, points are added up per racer after each
## race (9 / 6 / 3 / 1 for 1st..4th) and the cup ends with a trophy for the player.

const RaceRanking := preload("res://scripts/race_ranking.gd")

## Points per finishing place in a Grand Prix race (MK64 table).
const POINTS := [9, 6, 3, 1, 0, 0, 0, 0]
const TROPHIES := ["GOLD TROPHY", "SILVER TROPHY", "BRONZE TROPHY"]

## True while a cup is being raced (set from the title menu, cleared by finishing or Esc).
static var active := false
## Track indices raced in order.
static var order: Array = []
## Index into `order` of the race currently being run.
static var race_index := 0
## Cumulative points per racer id (racer 0 is the player).
static var totals: Array = []

static func points_for(rank: int) -> int:
	if rank < 1 or rank > POINTS.size():
		return 0
	return POINTS[rank - 1]

## Begin a cup over the given track indices.
static func start(track_order: Array, racer_count: int) -> void:
	active = true
	order = track_order.duplicate()
	race_index = 0
	totals = []
	for i in racer_count:
		totals.append(0)

static func stop() -> void:
	active = false
	order = []
	race_index = 0
	totals = []

## Track index of the race being run (or -1 when no cup is active).
static func current_track() -> int:
	if not active or race_index >= order.size():
		return -1
	return order[race_index]

static func is_last_race() -> bool:
	return race_index >= order.size() - 1

## Add this race's finishing order (RaceResults.rows: [{rank, id, ...}]) to the totals.
static func add_race(rows: Array) -> void:
	for row in rows:
		var id: int = row.id
		while totals.size() <= id:
			totals.append(0)
		totals[id] += points_for(row.rank)

## Move on to the next race; returns false when the cup is over.
static func advance() -> bool:
	if is_last_race():
		return false
	race_index += 1
	return true

## Racer ids ordered by points (ties keep the lower id first, i.e. the player wins ties).
static func standings() -> Array:
	var ids: Array = []
	for i in totals.size():
		ids.append(i)
	ids.sort_custom(func(a, b):
		if totals[a] == totals[b]:
			return a < b
		return totals[a] > totals[b])
	return ids

## 1-based cup position of a racer.
static func cup_rank(id: int) -> int:
	return standings().find(id) + 1

static func trophy_text(rank: int) -> String:
	if rank < 1 or rank > TROPHIES.size():
		return "NO TROPHY"
	return TROPHIES[rank - 1]

## "RACE 2 / 3" style label for the HUD and menu.
static func race_label() -> String:
	return "RACE %d / %d" % [race_index + 1, order.size()]

## Cup standings block shown under the race results; the player's row is marked with ">".
static func standings_text(names: Array, player_id := 0) -> String:
	var lines: Array = ["CUP STANDINGS  (%s)" % race_label()]
	var ids := standings()
	for r in ids.size():
		var id: int = ids[r]
		lines.append("%s %-4s %-8s %3d pts" % [">" if id == player_id else " ", RaceRanking.ordinal(r + 1), names[id], totals[id]])
	if is_last_race():
		lines.append("")
		lines.append("%s!  Press ENTER for the menu" % trophy_text(cup_rank(player_id)))
	else:
		lines.append("")
		lines.append("Press ENTER for the next race")
	return "\n".join(lines)
