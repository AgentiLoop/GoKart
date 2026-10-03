extends Control
## Title screen: pick a track with Left/Right (A/D) and press Enter/Space to race.
## Selection is stored in TrackLibrary.selected; Esc during a race comes back here.
## G / Tab cycles the mode: Single Race -> Grand Prix (every track in turn, MK64-style cup points)
## -> Time Trial (solo, 100cc, triple mushroom, race the ghost of your best run) -> Battle (four
## karts, three balloons each, in an arena picked with Left/Right).
## Z / C step the MK64 engine class (50cc / 100cc / 150cc / Extra = 150cc on mirrored courses).
## X / V step the MK64 weight class of the player's kart (Light / Medium / Heavy).

const TrackLibrary := preload("res://scripts/track_library.gd")
const GrandPrix := preload("res://scripts/grand_prix.gd")
const TimeTrial := preload("res://scripts/time_trial.gd")
const Battle := preload("res://scripts/battle.gd")
const ArenaData := preload("res://scripts/arena_data.gd")
const RaceMain := preload("res://scripts/main.gd")
const Minimap := preload("res://scripts/minimap.gd")
const KartWeight := preload("res://scripts/kart_weight.gd")
const RACE_SCENE := "res://scenes/main.tscn"
const BATTLE_SCENE := "res://scenes/battle.tscn"

const MODE_SINGLE := 0
const MODE_GP := 1
const MODE_TT := 2
const MODE_BATTLE := 3
const MODE_COUNT := 4

var selected := 0
var arena_selected := 0
var sub_label: Label
var name_label: Label
var blurb_label: Label
var index_label: Label
var laps_label: Label
var laps := 3
var difficulty_label: Label
var difficulty := 1
var engine_label: Label
var engine_class := 2
var weight_label: Label
var weight_class := KartWeight.MEDIUM
var mode_label: Label
var mode := MODE_SINGLE
var stage: Control   # fixed 1280x720 layout area, kept centred when the window is wider/taller
var preview: Minimap
var bg: ColorRect

## Key -> step direction (-1 / +1) or 0 when the key does not change the track.
static func direction_for_key(keycode: int) -> int:
	match keycode:
		KEY_LEFT, KEY_A:
			return -1
		KEY_RIGHT, KEY_D:
			return 1
	return 0

## Key -> lap option step (-1 / +1), 0 for anything else.
static func lap_direction_for_key(keycode: int) -> int:
	match keycode:
		KEY_UP, KEY_W:
			return 1
		KEY_DOWN, KEY_S:
			return -1
	return 0

## Key -> AI difficulty step (-1 / +1), 0 for anything else.
static func difficulty_direction_for_key(keycode: int) -> int:
	match keycode:
		KEY_Q:
			return -1
		KEY_E:
			return 1
	return 0

static func difficulty_text(i: int) -> String:
	return "AI: %s  (Q / E)" % TrackLibrary.difficulty_info(i).name

## Key -> engine class step (-1 / +1), 0 for anything else.
static func engine_direction_for_key(keycode: int) -> int:
	match keycode:
		KEY_Z:
			return -1
		KEY_C:
			return 1
	return 0

static func engine_text(i: int) -> String:
	return "Class: %s  (Z / C)" % TrackLibrary.engine_info(i).name

## Key -> weight class step (-1 / +1), 0 for anything else.
static func weight_direction_for_key(keycode: int) -> int:
	match keycode:
		KEY_X:
			return -1
		KEY_V:
			return 1
	return 0

static func weight_text(i: int) -> String:
	var w: Dictionary = KartWeight.info(i)
	return "Kart: %s - %s  (X / V)" % [w.name, w.blurb]

## Track blurb, tagged when the Extra class flips the course.
static func blurb_text(blurb: String, mirror: bool) -> String:
	return blurb + "  -  MIRRORED (Extra)" if mirror else blurb

static func laps_text(n: int) -> String:
	return "Laps: %d  (W / S)" % n

## True for the keys that cycle Single Race / Grand Prix / Time Trial.
static func is_mode_key(keycode: int) -> bool:
	return keycode == KEY_G or keycode == KEY_TAB

static func mode_text(m: int, track_count: int) -> String:
	match m:
		MODE_GP:
			return "Mode: GRAND PRIX - %d races, cup points  (G)" % track_count
		MODE_TT:
			return "Mode: TIME TRIAL - solo, 100cc, triple mushroom, race your ghost  (G)"
		MODE_BATTLE:
			return "Mode: BATTLE - %d karts, %d balloons each, last one standing  (G)" % [Battle.PLAYERS, Battle.BALLOONS]
	return "Mode: Single Race  (G)"

## Next mode in the G / Tab cycle (wraps around).
static func next_mode(m: int) -> int:
	return posmod(m + 1, MODE_COUNT)

## Cup order for a Grand Prix: every track once, starting from the highlighted one.
static func cup_order(first: int, track_count: int) -> Array:
	var out: Array = []
	for i in track_count:
		out.append(posmod(first + i, track_count))
	return out

static func is_confirm_key(keycode: int) -> bool:
	return keycode == KEY_ENTER or keycode == KEY_KP_ENTER or keycode == KEY_SPACE

static func counter_text(i: int, total: int) -> String:
	return "< %d / %d >" % [i + 1, total]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	selected = TrackLibrary.selected
	laps = TrackLibrary.laps
	difficulty = TrackLibrary.difficulty
	engine_class = TrackLibrary.engine_class
	weight_class = KartWeight.selected
	mode = MODE_BATTLE if Battle.active else (MODE_TT if TimeTrial.active else MODE_SINGLE)
	arena_selected = Battle.arena
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -640.0
	stage.offset_top = -360.0
	stage.offset_right = 640.0
	stage.offset_bottom = 360.0
	add_child(stage)
	var title := _label(Vector2(240, 30), 120, 800, Color(1.0, 0.85, 0.15))
	title.text = "GOKART"
	var sub := _label(Vector2(240, 168), 26, 800, Color(1, 1, 1))
	sub.text = "Select a track"
	sub_label = sub
	name_label = _label(Vector2(240, 226), 56, 800, Color(1, 1, 1))
	blurb_label = _label(Vector2(240, 298), 24, 800, Color(0.9, 0.9, 0.9))
	index_label = _label(Vector2(240, 336), 30, 800, Color(1, 1, 1))
	laps_label = _label(Vector2(240, 374), 26, 266, Color(1.0, 0.85, 0.15))
	difficulty_label = _label(Vector2(506, 374), 26, 266, Color(1.0, 0.85, 0.15))
	engine_label = _label(Vector2(772, 374), 26, 266, Color(1.0, 0.85, 0.15))
	weight_label = _label(Vector2(240, 412), 26, 800, Color(1.0, 0.85, 0.15))
	mode_label = _label(Vector2(240, 450), 28, 800, Color(0.55, 0.9, 1.0))
	preview = Minimap.new()
	preview.position = Vector2(500, 494)
	stage.add_child(preview)
	var hint := _label(Vector2(40, 662), 20, 1200, Color(1, 1, 1))
	hint.text = "Arrows / A D: track or arena     Up Down / W S: laps     Q E: AI level     Z C: engine class     X V: kart weight     G: mode     Enter: go"
	_refresh()

func _label(pos: Vector2, font_size: int, w: float, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(w, font_size * 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	stage.add_child(l)
	return l

func _refresh() -> void:
	if mode == MODE_BATTLE:
		_refresh_battle()
		return
	if sub_label != null:
		sub_label.text = "Select a track"
	var info := TrackLibrary.info(selected)
	name_label.text = info.name
	index_label.text = counter_text(selected, TrackLibrary.count())
	# MK64 Extra class races every course flipped left-to-right (never in a time trial: 100cc)
	var mirror: bool = mode != MODE_TT and TrackLibrary.is_mirrored(engine_class)
	blurb_label.text = blurb_text(info.blurb, mirror)
	if mode == MODE_TT:
		# MK64 time trials: always 3 laps, no AI, 100cc
		laps_label.text = "Laps: %d  (Time Trial)" % TimeTrial.LAPS
		difficulty_label.text = "AI: none  (Time Trial)"
		engine_label.text = "Class: %s  (Time Trial)" % TrackLibrary.engine_info(TimeTrial.ENGINE_CLASS).name
	else:
		laps_label.text = laps_text(laps)
		difficulty_label.text = difficulty_text(difficulty)
		engine_label.text = engine_text(engine_class)
	mode_label.text = mode_text(mode, TrackLibrary.count())
	weight_label.text = weight_text(weight_class)
	bg.color = info.sky_top.darkened(0.45)
	preview.setup(TrackLibrary.make_data(selected, mirror).points, Vector2(280, 160))

## Battle mode: Left/Right pick the arena instead of a track; balloons replace laps.
func _refresh_battle() -> void:
	if sub_label != null:
		sub_label.text = "Select an arena"
	var info := ArenaData.info(arena_selected)
	name_label.text = info.name
	index_label.text = counter_text(arena_selected, ArenaData.arena_count())
	blurb_label.text = info.blurb
	laps_label.text = "Balloons: %d  (Battle)" % Battle.BALLOONS
	difficulty_label.text = difficulty_text(difficulty)
	engine_label.text = engine_text(engine_class)
	mode_label.text = mode_text(mode, TrackLibrary.count())
	weight_label.text = weight_text(weight_class)
	bg.color = info.sky_top.darkened(0.45)
	preview.setup(ArenaData.make(arena_selected).outline(), Vector2(280, 160))

## Change the highlighted track (wraps around); the arena in battle mode.
func move(dir: int) -> void:
	if mode == MODE_BATTLE:
		arena_selected = ArenaData.step(arena_selected, dir)
	else:
		selected = TrackLibrary.step(selected, dir)
	_refresh()

## Change the lap count (wraps around the available options).
func move_laps(dir: int) -> void:
	laps = TrackLibrary.step_laps(laps, dir)
	_refresh()

## Change the AI difficulty (wraps around Easy / Medium / Hard).
func move_difficulty(dir: int) -> void:
	difficulty = TrackLibrary.step_difficulty(difficulty, dir)
	_refresh()

## Step the mode: Single Race -> Grand Prix -> Time Trial -> Single Race.
func toggle_mode() -> void:
	mode = next_mode(mode)
	_refresh()

## Change the engine class (wraps around 50cc / 100cc / 150cc / Extra).
func move_engine(dir: int) -> void:
	engine_class = TrackLibrary.step_engine(engine_class, dir)
	_refresh()

## Change the kart weight class (wraps around Light / Medium / Heavy).
func move_weight(dir: int) -> void:
	weight_class = KartWeight.step(weight_class, dir)
	_refresh()

func start_race() -> void:
	TrackLibrary.selected = selected
	TrackLibrary.difficulty = difficulty
	TrackLibrary.engine_class = engine_class
	TrackLibrary.laps = laps
	KartWeight.selected = weight_class
	TimeTrial.active = mode == MODE_TT
	Battle.active = mode == MODE_BATTLE
	if mode == MODE_BATTLE:
		Battle.arena = arena_selected
		GrandPrix.stop()
		get_tree().change_scene_to_file(BATTLE_SCENE)
		return
	if mode == MODE_GP:
		GrandPrix.start(cup_order(selected, TrackLibrary.count()), RaceMain.RACER_COUNT)
	else:
		GrandPrix.stop()
	get_tree().change_scene_to_file(RACE_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var d := direction_for_key(event.physical_keycode)
	var ld := lap_direction_for_key(event.physical_keycode)
	var dd := difficulty_direction_for_key(event.physical_keycode)
	var ed := engine_direction_for_key(event.physical_keycode)
	var wd := weight_direction_for_key(event.physical_keycode)
	if is_mode_key(event.physical_keycode):
		toggle_mode()
	elif dd != 0:
		move_difficulty(dd)
	elif ed != 0:
		move_engine(ed)
	elif wd != 0:
		move_weight(wd)
	elif d != 0:
		move(d)
	elif ld != 0:
		move_laps(ld)
	elif is_confirm_key(event.physical_keycode):
		start_race()
