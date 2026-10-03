extends Control
## Title screen: pick a track with Left/Right (A/D) and press Enter/Space to race.
## Selection is stored in TrackLibrary.selected; Esc during a race comes back here.
## G / Tab toggles Single Race vs Grand Prix (every track in turn, MK64-style cup points).

const TrackLibrary := preload("res://scripts/track_library.gd")
const GrandPrix := preload("res://scripts/grand_prix.gd")
const RaceMain := preload("res://scripts/main.gd")
const Minimap := preload("res://scripts/minimap.gd")
const RACE_SCENE := "res://scenes/main.tscn"

var selected := 0
var name_label: Label
var blurb_label: Label
var index_label: Label
var laps_label: Label
var laps := 3
var difficulty_label: Label
var difficulty := 1
var mode_label: Label
var grand_prix := false
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

static func laps_text(n: int) -> String:
	return "Laps: %d  (W / S)" % n

## True for the keys that toggle Single Race / Grand Prix.
static func is_mode_key(keycode: int) -> bool:
	return keycode == KEY_G or keycode == KEY_TAB

static func mode_text(gp: bool, track_count: int) -> String:
	if gp:
		return "Mode: GRAND PRIX - %d races, cup points  (G)" % track_count
	return "Mode: Single Race  (G)"

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
	name_label = _label(Vector2(240, 226), 56, 800, Color(1, 1, 1))
	blurb_label = _label(Vector2(240, 298), 24, 800, Color(0.9, 0.9, 0.9))
	index_label = _label(Vector2(240, 336), 30, 800, Color(1, 1, 1))
	laps_label = _label(Vector2(240, 374), 28, 400, Color(1.0, 0.85, 0.15))
	difficulty_label = _label(Vector2(640, 374), 28, 400, Color(1.0, 0.85, 0.15))
	mode_label = _label(Vector2(240, 412), 28, 800, Color(0.55, 0.9, 1.0))
	preview = Minimap.new()
	preview.position = Vector2(500, 452)
	stage.add_child(preview)
	var hint := _label(Vector2(90, 662), 22, 1100, Color(1, 1, 1))
	hint.text = "Arrows / A D: track     Up Down / W S: laps     Q E: AI level     G: mode     Enter: race"
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
	var info := TrackLibrary.info(selected)
	name_label.text = info.name
	blurb_label.text = info.blurb
	index_label.text = counter_text(selected, TrackLibrary.count())
	laps_label.text = laps_text(laps)
	difficulty_label.text = difficulty_text(difficulty)
	mode_label.text = mode_text(grand_prix, TrackLibrary.count())
	bg.color = info.sky_top.darkened(0.45)
	preview.setup(TrackLibrary.make_data(selected).points, Vector2(280, 195))

## Change the highlighted track (wraps around).
func move(dir: int) -> void:
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

## Flip between a single race and a Grand Prix cup.
func toggle_mode() -> void:
	grand_prix = not grand_prix
	_refresh()

func start_race() -> void:
	TrackLibrary.selected = selected
	TrackLibrary.difficulty = difficulty
	TrackLibrary.laps = laps
	if grand_prix:
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
	if is_mode_key(event.physical_keycode):
		toggle_mode()
	elif dd != 0:
		move_difficulty(dd)
	elif d != 0:
		move(d)
	elif ld != 0:
		move_laps(ld)
	elif is_confirm_key(event.physical_keycode):
		start_race()
