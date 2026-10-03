extends RefCounted
## The selectable tracks. Each entry is pure data; make_data() builds the TrackData for it.
## `selected` survives scene changes (static) so the title menu can hand the choice to the race.

const TrackData := preload("res://scripts/track_data.gd")

static var selected := 0
## Laps per race, chosen on the title menu; always one of LAP_OPTIONS.
static var laps := 3

const LAP_OPTIONS := [1, 2, 3, 5, 7]

## AI difficulty chosen on the title menu (index into DIFFICULTIES; Medium by default).
static var difficulty := 1

## speed: multiplier on every AI kart's top speed. start_boost: multiplier on the AI rocket-start boost.
## rubber_band: MK64-style catch-up strength (max fraction of top speed gained when far behind the
## player or lost when far ahead; see AiDriver.rubber_band).
const DIFFICULTIES := [
	{"name": "Easy", "speed": 0.72, "start_boost": 0.0, "rubber_band": 0.08},
	{"name": "Medium", "speed": 0.85, "start_boost": 0.5, "rubber_band": 0.14},
	{"name": "Hard", "speed": 1.0, "start_boost": 1.0, "rubber_band": 0.2},
]

static func difficulty_info(i: int) -> Dictionary:
	return DIFFICULTIES[posmod(i, DIFFICULTIES.size())]

## Next/previous difficulty (wraps around).
static func step_difficulty(current: int, dir: int) -> int:
	return posmod(current + dir, DIFFICULTIES.size())

const TRACKS := [
	{
		"name": "Green Hills",
		"blurb": "Flowing bends and wide curves",
		"control": TrackData.DEFAULT_CONTROL,
		"width": 16.0,
		"ground": Color(0.25, 0.6, 0.25),
		"sky_top": Color(0.38, 0.65, 0.92),
		"sky_horizon": Color(0.72, 0.84, 0.95),
	},
	{
		"name": "Sunset Speedway",
		"blurb": "Long straights, a hairpin and a chicane",
		"control": [
			Vector2(0, 60), Vector2(0, -60), Vector2(25, -115), Vector2(80, -130),
			Vector2(130, -110), Vector2(150, -60), Vector2(190, -40), Vector2(235, -55),
			Vector2(255, -10), Vector2(230, 35), Vector2(185, 30), Vector2(160, 70),
			Vector2(175, 120), Vector2(140, 165), Vector2(85, 165), Vector2(35, 150),
			Vector2(0, 115),
		],
		"width": 16.0,
		"pads": [[0.15, 0.0], [0.38, 3.0], [0.62, -3.0], [0.85, 0.0]],
		"box_rows": [0.08, 0.3, 0.55, 0.78],
		"hazards": [[0.22, -2.5], [0.47, 2.0], [0.7, 0.0]],
		"ground": Color(0.78, 0.6, 0.34),
		"sky_top": Color(0.35, 0.3, 0.6),
		"sky_horizon": Color(1.0, 0.62, 0.35),
	},
	{
		"name": "Frosty Peaks",
		"blurb": "Tight snowy esses and a long sweeper",
		"control": [
			Vector2(0, 60), Vector2(0, -50), Vector2(-20, -95), Vector2(-60, -115),
			Vector2(-100, -90), Vector2(-90, -45), Vector2(-120, -10), Vector2(-170, -15),
			Vector2(-200, 25), Vector2(-175, 70), Vector2(-130, 60), Vector2(-100, 95),
			Vector2(-115, 145), Vector2(-70, 175), Vector2(-25, 150), Vector2(-5, 110),
		],
		"width": 16.0,
		"pads": [[0.12, 0.0], [0.36, -3.0], [0.6, 3.0], [0.83, 0.0]],
		"box_rows": [0.06, 0.28, 0.5, 0.74],
		"hazards": [[0.2, 2.5], [0.45, -2.0], [0.68, 0.0]],
		"ground": Color(0.9, 0.93, 0.98),
		"sky_top": Color(0.12, 0.15, 0.32),
		"sky_horizon": Color(0.6, 0.72, 0.9),
	},
]

static func count() -> int:
	return TRACKS.size()

static func info(i: int) -> Dictionary:
	return TRACKS[posmod(i, TRACKS.size())]

static func make_data(i: int) -> TrackData:
	var d := info(i)
	var ctrl: Array[Vector2] = []
	for v in d.control:
		ctrl.append(v)
	return TrackData.new(ctrl, d.width, d)

## Wraps around: step(1, +1) == 0 when there are only 2 tracks.
static func step(i: int, dir: int) -> int:
	return posmod(i + dir, TRACKS.size())

## Next/previous lap option (wraps around). Unknown values fall back to the default of 3 laps first.
static func step_laps(current: int, dir: int) -> int:
	var i := LAP_OPTIONS.find(current)
	if i < 0:
		i = LAP_OPTIONS.find(3)
	return LAP_OPTIONS[posmod(i + dir, LAP_OPTIONS.size())]
