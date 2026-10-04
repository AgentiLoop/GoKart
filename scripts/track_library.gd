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

## Engine class chosen on the title menu (index into ENGINE_CLASSES; 150cc by default).
static var engine_class := 2

## Mario Kart 64 engine classes. speed / accel multiply EVERY kart's top speed and acceleration
## (player and AI alike), so 50cc is a gentle cruise and 150cc the full-speed race.
## "Extra" is MK64's mirror mode: 150cc speed on every course flipped left-to-right.
const ENGINE_CLASSES := [
	{"name": "50cc", "speed": 0.75, "accel": 0.8, "mirror": false},
	{"name": "100cc", "speed": 0.88, "accel": 0.9, "mirror": false},
	{"name": "150cc", "speed": 1.0, "accel": 1.0, "mirror": false},
	{"name": "Extra", "speed": 1.0, "accel": 1.0, "mirror": true},
]

static func engine_info(i: int) -> Dictionary:
	return ENGINE_CLASSES[posmod(i, ENGINE_CLASSES.size())]

## True when engine class i races the mirrored courses (MK64 Extra mode).
static func is_mirrored(i: int) -> bool:
	return engine_info(i).mirror

## Next/previous engine class (wraps around).
static func step_engine(current: int, dir: int) -> int:
	return posmod(current + dir, ENGINE_CLASSES.size())

const TRACKS := [
	{
		"name": "Green Hills",
		"blurb": "Flowing bends and wide curves",
		"control": TrackData.DEFAULT_CONTROL,
		"width": 16.0,
		"water": TrackData.DEFAULT_WATER,
		# Moo Moo Farm style Monty Moles: [fraction of lap, lateral offset] per hole — three groups of
		# three holes, staggered left / right / left about 10 m apart so there is always a way through
		# (see scripts/moles.gd); clear of the grid, the pads and the item box rows
		"moles": [
			[0.36, -3.0], [0.375, 3.0], [0.39, -3.0],
			[0.61, 3.0], [0.625, -3.0], [0.64, 3.0],
			[0.74, -3.0], [0.755, 3.0], [0.77, -3.0],
		],
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
		"water": [[0.18, 0.26, -1], [0.62, 0.69, 1]],
		# Toad's Turnpike style traffic: [fraction of lap, lane (m right of the centreline), kind]. The
		# fast lane is on the left, the slow lane on the right; vehicles in one lane all run at the same
		# speed so they never catch each other; nothing starts on the grid (see scripts/traffic.gd)
		"traffic": [
			[0.06, -4.4, "car"], [0.1, 4.4, "truck"], [0.17, 4.4, "bus"], [0.24, -4.4, "car"],
			[0.31, 4.4, "tanker"], [0.4, -4.4, "bus"], [0.47, 4.4, "car"], [0.55, -4.4, "truck"],
			[0.63, 4.4, "truck"], [0.71, -4.4, "car"], [0.78, 4.4, "bus"], [0.86, -4.4, "tanker"],
		],
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
		"water": [[0.15, 0.22, 1], [0.62, 0.69, -1]],
		# Frappe Snowland style snowmen: [fraction of lap, lateral offset] per snowman — two by the
		# edges after the esses, a field of five staggered rows (singles, a pair and a gate, ~14 m
		# apart) on the run after the long sweeper, a left / right pair before the last pad and a
		# gate near the end (see scripts/snowmen.gd); every row leaves a way through, clear of the
		# grid, the pads, the item box rows and the bananas
		"snowmen": [
			[0.39, -4.5], [0.41, 4.5],
			[0.52, -4.5], [0.52, 2.6], [0.536, 4.0], [0.552, -1.0],
			[0.568, -4.5], [0.568, 4.5], [0.584, 2.0],
			[0.78, 3.0], [0.795, -3.0],
			[0.9, -5.0], [0.915, 5.0],
		],
		"ground": Color(0.9, 0.93, 0.98),
		"sky_top": Color(0.12, 0.15, 0.32),
		"sky_horizon": Color(0.6, 0.72, 0.9),
	},
	{
		"name": "Dusty Canyon",
		"blurb": "Sun-baked desert sweepers, a hairpin and an oasis",
		"control": [
			Vector2(0, 70), Vector2(0, -70), Vector2(-30, -130), Vector2(-90, -150),
			Vector2(-150, -130), Vector2(-180, -80), Vector2(-160, -30), Vector2(-110, -10),
			Vector2(-80, 30), Vector2(-110, 80), Vector2(-170, 100), Vector2(-200, 150),
			Vector2(-170, 200), Vector2(-110, 205), Vector2(-60, 180), Vector2(-20, 150),
			Vector2(0, 125),
		],
		"width": 16.0,
		"pads": [[0.14, 0.0], [0.4, 3.0], [0.58, -3.0], [0.8, 0.0]],
		"box_rows": [0.05, 0.3, 0.52, 0.76],
		"hazards": [[0.17, -2.5], [0.46, 2.0], [0.7, -2.0]],
		"water": [[0.21, 0.28, 1], [0.5, 0.56, -1]],
		# Kalimari Desert style railway: a loop that crosses the road twice (the opening straight
		# and the run back to the line); two steam trains circle it (see scripts/train.gd)
		"rail": [
			Vector2(-30, -40), Vector2(0, -40), Vector2(50, -50), Vector2(95, 0), Vector2(105, 80),
			Vector2(80, 150), Vector2(30, 200), Vector2(-10, 205), Vector2(-40, 165), Vector2(-70, 125),
			Vector2(-65, 70), Vector2(-50, 10),
		],
		"ground": Color(0.86, 0.7, 0.44),
		"sky_top": Color(0.4, 0.58, 0.9),
		"sky_horizon": Color(0.98, 0.86, 0.62),
	},
]

static func count() -> int:
	return TRACKS.size()

static func info(i: int) -> Dictionary:
	return TRACKS[posmod(i, TRACKS.size())]

## mirror = true builds the course flipped left-to-right (MK64 Extra mode).
static func make_data(i: int, mirror := false) -> TrackData:
	var d := info(i)
	var ctrl: Array[Vector2] = []
	for v in d.control:
		ctrl.append(v)
	var layout := d.duplicate()
	layout["mirror"] = mirror
	return TrackData.new(ctrl, d.width, layout)

## Wraps around: step(1, +1) == 0 when there are only 2 tracks.
static func step(i: int, dir: int) -> int:
	return posmod(i + dir, TRACKS.size())

## Next/previous lap option (wraps around). Unknown values fall back to the default of 3 laps first.
static func step_laps(current: int, dir: int) -> int:
	var i := LAP_OPTIONS.find(current)
	if i < 0:
		i = LAP_OPTIONS.find(3)
	return LAP_OPTIONS[posmod(i + dir, LAP_OPTIONS.size())]
