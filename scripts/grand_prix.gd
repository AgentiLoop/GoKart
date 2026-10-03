extends RefCounted
## Grand Prix cup state (pure, static so it survives scene changes), Mario Kart 64 style:
## every track in the library is raced in order, points are added up per racer after each
## race (9 / 6 / 3 / 1 for 1st..4th) and the cup ends with a trophy for the player.
## MK64 rules: the player must finish 4th or better to go on — 5th or worse scores nothing and
## the race is run again (unlimited retries) — and from the second race on everyone starts the
## next race in the grid slot of their last finishing position.

const RaceRanking := preload("res://scripts/race_ranking.gd")

## Points per finishing place in a Grand Prix race (MK64 table).
const POINTS := [9, 6, 3, 1, 0, 0, 0, 0]
const TROPHIES := ["GOLD TROPHY", "SILVER TROPHY", "BRONZE TROPHY"]
## Worst finishing place that still moves the cup on (MK64: 4th).
const QUALIFY_RANK := 4

## True while a cup is being raced (set from the title menu, cleared by finishing or Esc).
static var active := false
## Track indices raced in order.
static var order: Array = []
## Index into `order` of the race currently being run.
static var race_index := 0
## Cumulative points per racer id (racer 0 is the player).
static var totals: Array = []
## True when the player ranked out of the last race and it has to be run again.
static var retry := false
## How many times the current race has been re-run.
static var retries := 0
## The player's place in the race that was just added.
static var last_rank := 0
## Racer ids in the finishing order of the last race that counted: the grid of the next race,
## pole first. Empty before the first race (everyone takes their default slot, the player 8th).
static var grid: Array = []

static func points_for(rank: int) -> int:
	if rank < 1 or rank > POINTS.size():
		return 0
	return POINTS[rank - 1]

## MK64: only the top four places score, and only they move the cup on.
static func qualifies(rank: int) -> bool:
	return rank >= 1 and rank <= QUALIFY_RANK

## Begin a cup over the given track indices.
static func start(track_order: Array, racer_count: int) -> void:
	active = true
	order = track_order.duplicate()
	race_index = 0
	totals = []
	for i in racer_count:
		totals.append(0)
	retry = false
	retries = 0
	last_rank = 0
	grid = []

static func stop() -> void:
	active = false
	order = []
	race_index = 0
	totals = []
	retry = false
	retries = 0
	last_rank = 0
	grid = []

## Track index of the race being run (or -1 when no cup is active).
static func current_track() -> int:
	if not active or race_index >= order.size():
		return -1
	return order[race_index]

static func is_last_race() -> bool:
	return race_index >= order.size() - 1

## Place of racer `id` in a finishing order (RaceResults.rows), 0 when absent.
static func rank_in(rows: Array, id: int) -> int:
	for row in rows:
		if row.id == id:
			return row.rank
	return 0

## Add this race's finishing order (RaceResults.rows: [{rank, id, ...}]) to the totals.
## Returns false — and counts nothing — when the player ranked out (5th or worse): the race
## must be retried. A race that counts also becomes the grid of the next one.
static func add_race(rows: Array, player_id := 0) -> bool:
	last_rank = rank_in(rows, player_id)
	if not qualifies(last_rank):
		retry = true
		return false
	retry = false
	grid = []
	for row in rows:
		var id: int = row.id
		while totals.size() <= id:
			totals.append(0)
		totals[id] += points_for(row.rank)
		grid.append(id)
	return true

## The ranked-out race is being run again.
static func begin_retry() -> void:
	retry = false
	retries += 1

## Grid slot (0 = pole) racer `id` starts the current race from: where it finished the last
## race that counted, or `default_slot` on the first race of the cup.
static func grid_slot_for(id: int, default_slot: int) -> int:
	var i := grid.find(id)
	return default_slot if i < 0 else i

## Move on to the next race; returns false when the cup is over.
static func advance() -> bool:
	if is_last_race():
		return false
	race_index += 1
	retries = 0
	retry = false
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

## "RACE 2 / 3" style label for the HUD and menu ("RACE 2 / 3  RETRY" while a race is re-run).
static func race_label() -> String:
	var label := "RACE %d / %d" % [race_index + 1, order.size()]
	return label + "  RETRY" if retries > 0 else label

## Cup standings block shown under the race results; the player's row is marked with ">".
## After a rank-out the block keeps the standings (nothing was added) and asks for a retry.
static func standings_text(names: Array, player_id := 0) -> String:
	var lines: Array = ["CUP STANDINGS  (%s)" % race_label()]
	var ids := standings()
	for r in ids.size():
		var id: int = ids[r]
		lines.append("%s %-4s %-8s %3d pts" % [">" if id == player_id else " ", RaceRanking.ordinal(r + 1), names[id], totals[id]])
	lines.append("")
	if retry:
		lines.append("RANK OUT!  %s - finish %s or better to go on" % [RaceRanking.ordinal(last_rank), RaceRanking.ordinal(QUALIFY_RANK)])
		lines.append("Press ENTER to retry the race")
	elif is_last_race():
		lines.append("%s!  Press ENTER for the menu" % trophy_text(cup_rank(player_id)))
	else:
		lines.append("Press ENTER for the next race")
	return "\n".join(lines)
