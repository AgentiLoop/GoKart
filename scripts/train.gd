extends RefCounted
## Mario Kart 64 Kalimari Desert trains (pure model, no scene nodes, unit tested): steam trains
## circle the railway loop of a TrackData, the level-crossing signals warn while one is close, a kart
## that meets a car is thrown into the air, and CPU karts wait at a blocked crossing like MK64's do.

const SPEED := 16.0           # m/s along the rail
const TRAIN_COUNT := 2        # MK64: two trains circle the loop, half a loop apart
const CARS := 5               # locomotive, tender and three coaches
const CAR_LENGTH := 4.6
const CAR_GAP := 0.7
const HALF_WIDTH := 1.5       # half the width of a car: the strike zone either side of the rail
const WARN_DISTANCE := 45.0   # a crossing is "blocked" once a train's front is this close (m of rail)
const CLEAR_MARGIN := 3.0     # ... until its last car is this far past the crossing
const STOP_SAMPLES := 9       # AI karts stop for a blocked crossing from this many road samples before it
const BELL_SAMPLES := 20      # the crossing bell is heard this many road samples either side of it
const FLASH_PERIOD := 0.8     # the two red lamps alternate at this period
const LAUNCH_SPEED := 12.0    # upward m/s a struck kart is thrown with
const SHOVE := 10.0           # m/s a struck kart is shoved along the train's direction

var track                     # TrackData (its rail may be empty: no railway on this course)
var heads: Array[float] = []  # distance along the rail of each train's front
var time := 0.0

static func train_length() -> float:
	return CARS * CAR_LENGTH + (CARS - 1) * CAR_GAP

## offset: where along the rail the first train's front starts; the others are spaced evenly.
func _init(track_data, offset := 0.0) -> void:
	track = track_data
	if active():
		for i in TRAIN_COUNT:
			heads.append(fposmod(offset + track.rail_length * i / TRAIN_COUNT, track.rail_length))

func active() -> bool:
	return track != null and track.rail.size() > 1

func step(delta: float) -> void:
	time += delta
	for i in heads.size():
		heads[i] = fposmod(heads[i] + SPEED * delta, track.rail_length)

## Point on the rail `s` metres from its start: {"pos": Vector3, "dir": unit direction of travel}.
func rail_pose(s: float) -> Dictionary:
	var n: int = track.rail.size()
	var per: float = track.rail_length / n
	var f := fposmod(s, track.rail_length) / per
	var i := int(floor(f)) % n
	var a: Vector3 = track.rail[i]
	var b: Vector3 = track.rail[(i + 1) % n]
	return {"pos": a.lerp(b, f - floor(f)), "dir": (b - a).normalized()}

## Centre pose of car c (0 = the locomotive) of train t.
func car_pose(t: int, c: int) -> Dictionary:
	return rail_pose(heads[t] - c * (CAR_LENGTH + CAR_GAP) - CAR_LENGTH * 0.5)

## Direction of travel of the car `pos` is inside (XZ box, gaps between cars count), ZERO when clear.
func hit_dir(pos: Vector3) -> Vector3:
	for t in heads.size():
		for c in CARS:
			var p := car_pose(t, c)
			var rel: Vector3 = pos - p.pos
			var dir: Vector3 = p.dir
			var along := rel.dot(dir)
			var across := rel.dot(Vector3(-dir.z, 0, dir.x))
			if absf(along) <= (CAR_LENGTH + CAR_GAP) * 0.5 and absf(across) <= HALF_WIDTH:
				return dir
	return Vector3.ZERO

## Crossing ci (index into track.crossings) is blocked: a train's front is within WARN_DISTANCE of
## it, or a train is over it until its last car is CLEAR_MARGIN past.
func blocked(ci: int) -> bool:
	var s: float = track.crossings[ci].s
	for h in heads:
		if fposmod(s - h, track.rail_length) < WARN_DISTANCE:
			return true
		if fposmod(h - s, track.rail_length) <= train_length() + CLEAR_MARGIN:
			return true
	return false

## Which of the two red lamps is lit this instant (0 / 1); they alternate while a crossing is blocked.
func lamp_phase() -> int:
	return 0 if fmod(time, FLASH_PERIOD) < FLASH_PERIOD * 0.5 else 1

## The crossing a kart at road sample idx is about to reach (2..STOP_SAMPLES samples ahead), or -1.
func crossing_ahead(idx: int) -> int:
	for ci in track.crossings.size():
		var gap: int = posmod(track.crossings[ci].road - idx, track.count)
		if gap >= 2 and gap <= STOP_SAMPLES:
			return ci
	return -1

## MK64: CPU drivers always stop at a level crossing while a train is there (or about to be).
func must_wait(idx: int) -> bool:
	var ci := crossing_ahead(idx)
	return ci >= 0 and blocked(ci)

## True when a blocked crossing is within BELL_SAMPLES road samples of idx (the bell is heard).
func bell_near(idx: int) -> bool:
	for ci in track.crossings.size():
		var road: int = track.crossings[ci].road
		var gap: int = mini(posmod(road - idx, track.count), posmod(idx - road, track.count))
		if gap <= BELL_SAMPLES and blocked(ci):
			return true
	return false
