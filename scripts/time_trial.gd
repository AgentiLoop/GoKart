extends RefCounted
## Mario Kart 64 Time Trials (pure, static so it survives scene changes): the player races alone
## for three laps at 100cc with a triple mushroom and no item boxes. The five best times and the
## best lap of every track are kept in user://time_trials.cfg, and the fastest run is replayed as
## a see-through ghost the next time that track is raced.

const GhostRecording := preload("res://scripts/ghost_recording.gd")
const RaceRanking := preload("res://scripts/race_ranking.gd")
const RaceResults := preload("res://scripts/race_results.gd")

const ENGINE_CLASS := 1   # 100cc, as in MK64 time trials
const LAPS := 3
const RECORD_COUNT := 5
const SAVE_PATH := "user://time_trials.cfg"

## True while the mode is chosen on the title menu (menu toggles it, the race reads it).
static var active := false
## track name -> {"times": [race times, fastest first], "best_lap": float (-1 = none)}
static var records := {}
## track name -> GhostRecording of the fastest run
static var ghosts := {}
static var loaded := false

static func reset() -> void:
	records = {}
	ghosts = {}
	loaded = false

static func times_for(track: String) -> Array:
	return records[track].times if records.has(track) else []

## Fastest race time of a track (-1 when it has never been finished).
static func best_time(track: String) -> float:
	var t := times_for(track)
	return t[0] if not t.is_empty() else -1.0

static func best_lap(track: String) -> float:
	return records[track].best_lap if records.has(track) else -1.0

## Ghost of the fastest run, or null.
static func ghost_for(track: String):
	return ghosts.get(track)

## 1-based slot a time takes in the top RECORD_COUNT list (0 = not a record). Ties rank behind
## the existing time.
static func record_rank(times: Array, t: float) -> int:
	var r := 1
	for x in times:
		if t >= x:
			r += 1
	return r if r <= RECORD_COUNT else 0

## File a finished run. Returns {rank, new_best, new_best_lap}; the ghost is replaced only when
## the run is the new fastest time.
static func submit(track: String, race_time: float, lap_best: float, ghost) -> Dictionary:
	var rec: Dictionary = records.get(track, {"times": [], "best_lap": -1.0})
	var rank := record_rank(rec.times, race_time)
	var out := {"rank": rank, "new_best": rank == 1, "new_best_lap": false}
	if rank > 0:
		rec.times.insert(rank - 1, race_time)
		if rec.times.size() > RECORD_COUNT:
			rec.times.resize(RECORD_COUNT)
	if lap_best > 0.0 and (rec.best_lap < 0.0 or lap_best < rec.best_lap):
		rec.best_lap = lap_best
		out.new_best_lap = true
	records[track] = rec
	if rank == 1 and ghost != null and ghost.count() > 1:
		ghosts[track] = ghost
	return out

static func save(path := SAVE_PATH) -> int:
	var cf := ConfigFile.new()
	for track in records:
		cf.set_value(track, "times", records[track].times)
		cf.set_value(track, "best_lap", records[track].best_lap)
		if ghosts.has(track):
			cf.set_value(track, "ghost", ghosts[track].to_dict())
	return cf.save(path)

static func load_records(path := SAVE_PATH) -> void:
	records = {}
	ghosts = {}
	loaded = true
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for track in cf.get_sections():
		records[track] = {
			"times": Array(cf.get_value(track, "times", [])),
			"best_lap": float(cf.get_value(track, "best_lap", -1.0)),
		}
		if cf.has_section_key(track, "ghost"):
			ghosts[track] = GhostRecording.from_dict(cf.get_value(track, "ghost"))

static func ensure_loaded() -> void:
	if not loaded:
		load_records()

## HUD line under the timers: the track record and whether a ghost is on the course.
static func hud_text(track: String) -> String:
	var best := best_time(track)
	var line := "TIME TRIAL   " + ("BEST %s" % RaceResults.time_text(best) if best >= 0.0 else "no record yet")
	if ghosts.has(track):
		line += "   vs GHOST"
	return line

## Results panel for a finished time trial: the run, its laps, the record list and the prompt.
static func results_text(track: String, race_time: float, lap_times: Array, result: Dictionary) -> String:
	var lines: Array = ["TIME TRIAL - %s" % track]
	lines.append("TIME      %s%s" % [RaceResults.time_text(race_time), "   NEW RECORD!" if result.get("new_best", false) else ""])
	for i in lap_times.size():
		lines.append("LAP %d     %s" % [i + 1, RaceResults.time_text(lap_times[i])])
	var bl := best_lap(track)
	if bl >= 0.0:
		lines.append("BEST LAP  %s%s" % [RaceResults.time_text(bl), "   NEW!" if result.get("new_best_lap", false) else ""])
	lines.append("")
	lines.append("RECORDS")
	var times := times_for(track)
	for i in times.size():
		lines.append("%s %-4s %s" % [">" if i == int(result.get("rank", 0)) - 1 else " ", RaceRanking.ordinal(i + 1), RaceResults.time_text(times[i])])
	lines.append("")
	lines.append("Press ENTER to race your ghost" if ghosts.has(track) else "Press ENTER to race again")
	return "\n".join(lines)
