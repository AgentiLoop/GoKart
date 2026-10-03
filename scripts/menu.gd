extends Control
## Title screen laid out like Mario Kart 64's select screens: a big slanted two-tone logo, a
## "SELECT COURSE" banner, a course list on the left with a highlighted row, the map and the
## course blurb in a framed panel on the right and a row of option cells underneath.
## Text uses drop shadows instead of thick black outlines (only the logo has a gold rim).
## Left/Right (A/D) pick the track and Enter/Space races it; selection is stored in
## TrackLibrary.selected and Esc during a race comes back here.
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

# MK64 palette: gold highlights, cream body text, navy panels with a gold rim, a red logo
const GOLD := Color(1.0, 0.82, 0.22)
const GOLD_DIM := Color(0.95, 0.78, 0.35, 0.85)
const CREAM := Color(0.98, 0.97, 0.92)
const GREY := Color(0.72, 0.76, 0.86)
const LOGO_RED := Color(0.9, 0.14, 0.1)
const LOGO_RIM := Color(1.0, 0.86, 0.3)
const PANEL_FILL := Color(0.05, 0.07, 0.2, 0.84)
const PANEL_RIM := Color(1.0, 0.8, 0.25, 0.95)
const SHADOW := Color(0, 0, 0, 0.55)
const PREVIEW_AREA := Vector2(300, 186)   # map window inside the right panel
## Rounded fonts in MK64's spirit; Godot falls back to its default font when none is installed.
const FONT_NAMES := ["Arial Rounded MT Bold", "Avenir Next", "Verdana"]

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
var backdrop: Backdrop
var font: Font
var list_box: Control          # course / arena list (left panel)
var list_caption: Label
var laps_caption: Label
var laps_keys: Label
var difficulty_keys: Label
var engine_keys: Label
var prompt: Label              # blinking PRESS ENTER
var title_box: Control
var blink := 0.0

## Sky gradient, faint diagonal stripes and a checkered-flag band, drawn under the panels.
class Backdrop extends Control:
	var top := Color(0.1, 0.2, 0.5)
	var bottom := Color(0.02, 0.03, 0.1)
	var band_y := 650.0   # stage coordinates (1280x720 layout)
	func set_sky(sky: Color) -> void:
		top = sky.darkened(0.15)
		bottom = sky.darkened(0.78)
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([top, top, bottom, bottom]))
		var stripe := Color(1, 1, 1, 0.035)
		var x := -h
		while x < w:
			draw_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + 56, h), Vector2(x + h + 56, 0), Vector2(x + h, 0)]),
				PackedColorArray([stripe, stripe, stripe, stripe]))
			x += 150.0
		# checkered band across the whole window, lined up with the stage
		var y0 := h * 0.5 + (band_y - 360.0)
		var sq := 9.0
		var cols := int(ceil(w / sq))
		for r in 2:
			for c in cols:
				var col := Color(0.95, 0.95, 0.95, 0.9) if (c + r) % 2 == 0 else Color(0.05, 0.05, 0.08, 0.9)
				draw_rect(Rect2(c * sq, y0 + r * sq, sq, sq), col)

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

## Value shown in the CPU cell (the key hint lives in its own caption).
static func difficulty_text(i: int) -> String:
	return TrackLibrary.difficulty_info(i).name

## Key -> engine class step (-1 / +1), 0 for anything else.
static func engine_direction_for_key(keycode: int) -> int:
	match keycode:
		KEY_Z:
			return -1
		KEY_C:
			return 1
	return 0

static func engine_text(i: int) -> String:
	return TrackLibrary.engine_info(i).name

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
	return "%s - %s" % [w.name, w.blurb]

## Track blurb, tagged when the Extra class flips the course.
static func blurb_text(blurb: String, mirror: bool) -> String:
	return blurb + "  -  MIRRORED (Extra)" if mirror else blurb

static func laps_text(n: int) -> String:
	return "%d" % n

## True for the keys that cycle Single Race / Grand Prix / Time Trial / Battle.
static func is_mode_key(keycode: int) -> bool:
	return keycode == KEY_G or keycode == KEY_TAB

static func mode_text(m: int, track_count: int) -> String:
	match m:
		MODE_GP:
			return "GRAND PRIX  -  %d races, cup points" % track_count
		MODE_TT:
			return "TIME TRIAL  -  solo, 100cc, triple mushroom, race your ghost"
		MODE_BATTLE:
			return "BATTLE  -  %d karts, %d balloons each, last one standing" % [Battle.PLAYERS, Battle.BALLOONS]
	return "SINGLE RACE"

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

static func make_font() -> Font:
	var f := SystemFont.new()
	f.font_names = FONT_NAMES
	f.font_weight = 700
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	selected = TrackLibrary.selected
	laps = TrackLibrary.laps
	difficulty = TrackLibrary.difficulty
	engine_class = TrackLibrary.engine_class
	weight_class = KartWeight.selected
	mode = MODE_BATTLE if Battle.active else (MODE_TT if TimeTrial.active else MODE_SINGLE)
	arena_selected = Battle.arena
	font = make_font()
	bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	backdrop = Backdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -640.0
	stage.offset_top = -360.0
	stage.offset_right = 640.0
	stage.offset_bottom = 360.0
	add_child(stage)
	_build_title()
	# banner
	_panel(Rect2(460, 162, 360, 44), PANEL_FILL, PANEL_RIM, 22)
	sub_label = _label(Vector2(460, 162), 24, 360, GOLD)
	sub_label.size.y = 44
	sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# left panel: course list
	_panel(Rect2(80, 220, 420, 278), PANEL_FILL, PANEL_RIM, 16)
	list_caption = _label(Vector2(80, 230), 15, 420, GOLD_DIM)
	list_box = Control.new()
	list_box.position = Vector2(80, 220)
	list_box.size = Vector2(420, 278)
	stage.add_child(list_box)
	var arrows := _label(Vector2(80, 468), 13, 420, GREY)
	arrows.text = "<  A / D  or  Left / Right  >"
	# right panel: map + name + blurb
	_panel(Rect2(520, 220, 680, 278), PANEL_FILL, PANEL_RIM, 16)
	_panel(Rect2(538, 240, 316, 202), Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.35), 8)
	preview = Minimap.new()
	preview.position = Vector2(546, 248)
	stage.add_child(preview)
	name_label = _label(Vector2(870, 244), 34, 316, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	blurb_label = _label(Vector2(870, 296), 19, 316, CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	blurb_label.size.y = 130
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	index_label = _label(Vector2(870, 452), 17, 316, GREY, HORIZONTAL_ALIGNMENT_LEFT)
	# option cells
	_panel(Rect2(80, 512, 1120, 128), PANEL_FILL, PANEL_RIM, 16)
	var captions := ["LAPS", "CPU", "ENGINE", "KART"]
	var keys := ["W / S", "Q / E", "Z / C", "X / V"]
	var values: Array[Label] = []
	var key_labels: Array[Label] = []
	for i in 4:
		var x := 80.0 + 280.0 * i
		var cap := _label(Vector2(x, 520), 14, 280, GOLD_DIM)
		cap.text = captions[i]
		if i == 0:
			laps_caption = cap
		values.append(_label(Vector2(x, 540), 25, 280, CREAM))
		var k := _label(Vector2(x, 574), 12, 280, GREY)
		k.text = keys[i]
		key_labels.append(k)
		if i > 0:
			var sep := ColorRect.new()
			sep.position = Vector2(x, 524)
			sep.size = Vector2(1, 62)
			sep.color = Color(1, 1, 1, 0.14)
			stage.add_child(sep)
	laps_label = values[0]
	difficulty_label = values[1]
	engine_label = values[2]
	weight_label = values[3]
	laps_keys = key_labels[0]
	difficulty_keys = key_labels[1]
	engine_keys = key_labels[2]
	var rule := ColorRect.new()
	rule.position = Vector2(96, 596)
	rule.size = Vector2(1088, 1)
	rule.color = Color(1, 1, 1, 0.14)
	stage.add_child(rule)
	var mode_cap := _label(Vector2(96, 607), 14, 120, GOLD_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	mode_cap.text = "MODE  (G)"
	mode_label = _label(Vector2(216, 603), 21, 760, CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	prompt = _label(Vector2(960, 603), 21, 224, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	prompt.text = "PRESS ENTER"
	var hint := _label(Vector2(40, 676), 14, 1200, GREY)
	hint.text = "Left / Right: course     Up / Down: laps     Q / E: cpu     Z / C: engine     X / V: kart     G: mode     Enter: race"
	_refresh()

## "GOKART" like the MK64 logo: a slanted, chunky red word with a gold rim over a soft dark shadow.
func _build_title() -> void:
	title_box = Control.new()
	title_box.position = Vector2(240, 8)
	title_box.size = Vector2(800, 150)
	title_box.pivot_offset = title_box.size * 0.5
	title_box.rotation_degrees = -4.0
	stage.add_child(title_box)
	for layer in 2:
		var l := Label.new()
		l.text = "GOKART"
		l.size = title_box.size
		l.position = Vector2(8, 10) if layer == 0 else Vector2.ZERO
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 112)
		if layer == 0:
			l.add_theme_color_override("font_color", Color(0.02, 0.03, 0.1, 0.7))
		else:
			l.add_theme_color_override("font_color", LOGO_RED)
			l.add_theme_color_override("font_outline_color", LOGO_RIM)
			l.add_theme_constant_override("outline_size", 7)
		title_box.add_child(l)

func _panel(rect: Rect2, fill: Color, rim: Color, radius: int) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rim
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", sb)
	stage.add_child(p)
	return p

func _label(pos: Vector2, font_size: int, w: float, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(w, font_size * 1.4)
	l.horizontal_alignment = align
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	var off := 3 if font_size >= 30 else 2
	l.add_theme_constant_override("shadow_offset_x", off)
	l.add_theme_constant_override("shadow_offset_y", off)
	stage.add_child(l)
	return l

func _process(delta: float) -> void:
	blink += delta
	if prompt != null:
		prompt.modulate.a = 0.6 + 0.4 * sin(blink * 5.0)

## Rebuild the left-hand list: one row per course / arena, the highlighted one gold on a lit bar.
func _refresh_list(names: Array, sel: int) -> void:
	if list_box == null:
		return
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()
	for i in names.size():
		var y := 44.0 + 50.0 * i
		var is_sel := i == sel
		if is_sel:
			var bar := Panel.new()
			bar.position = Vector2(16, y)
			bar.size = Vector2(388, 44)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1.0, 0.82, 0.22, 0.22)
			sb.border_color = GOLD
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(10)
			bar.add_theme_stylebox_override("panel", sb)
			list_box.add_child(bar)
		var row := Label.new()
		row.position = Vector2(60, y + 5)
		row.size = Vector2(330, 34)
		row.text = names[i]
		row.add_theme_font_override("font", font)
		row.add_theme_font_size_override("font_size", 24)
		row.add_theme_color_override("font_color", GOLD if is_sel else CREAM)
		row.add_theme_color_override("font_shadow_color", SHADOW)
		row.add_theme_constant_override("shadow_offset_x", 2)
		row.add_theme_constant_override("shadow_offset_y", 2)
		list_box.add_child(row)
		if is_sel:
			var cursor := Label.new()
			cursor.position = Vector2(30, y + 5)
			cursor.size = Vector2(30, 34)
			cursor.text = ">"
			cursor.add_theme_font_override("font", font)
			cursor.add_theme_font_size_override("font_size", 24)
			cursor.add_theme_color_override("font_color", GOLD)
			list_box.add_child(cursor)

func _set_text(l: Label, text: String) -> void:
	if l != null:
		l.text = text

func _refresh() -> void:
	if mode == MODE_BATTLE:
		_refresh_battle()
		return
	_set_text(sub_label, "SELECT COURSE")
	_set_text(list_caption, "COURSES")
	_set_text(laps_caption, "LAPS")
	var info := TrackLibrary.info(selected)
	name_label.text = info.name
	index_label.text = counter_text(selected, TrackLibrary.count())
	# MK64 Extra class races every course flipped left-to-right (never in a time trial: 100cc)
	var mirror: bool = mode != MODE_TT and TrackLibrary.is_mirrored(engine_class)
	blurb_label.text = blurb_text(info.blurb, mirror)
	if mode == MODE_TT:
		# MK64 time trials: always 3 laps, no AI, 100cc
		laps_label.text = laps_text(TimeTrial.LAPS)
		difficulty_label.text = "None"
		engine_label.text = engine_text(TimeTrial.ENGINE_CLASS)
		for k in [laps_keys, difficulty_keys, engine_keys]:
			_set_text(k, "Time Trial")
	else:
		laps_label.text = laps_text(laps)
		difficulty_label.text = difficulty_text(difficulty)
		engine_label.text = engine_text(engine_class)
		_set_text(laps_keys, "W / S")
		_set_text(difficulty_keys, "Q / E")
		_set_text(engine_keys, "Z / C")
	mode_label.text = mode_text(mode, TrackLibrary.count())
	weight_label.text = weight_text(weight_class)
	bg.color = info.sky_top.darkened(0.45)
	if backdrop != null:
		backdrop.set_sky(info.sky_top)
	var names: Array = []
	for i in TrackLibrary.count():
		names.append(TrackLibrary.info(i).name)
	_refresh_list(names, selected)
	var data = TrackLibrary.make_data(selected, mirror)
	preview.setup(data.points, PREVIEW_AREA, data.rail)

## Battle mode: Left/Right pick the arena instead of a track; balloons replace laps.
func _refresh_battle() -> void:
	_set_text(sub_label, "SELECT ARENA")
	_set_text(list_caption, "ARENAS")
	_set_text(laps_caption, "BALLOONS")
	var info := ArenaData.info(arena_selected)
	name_label.text = info.name
	index_label.text = counter_text(arena_selected, ArenaData.arena_count())
	blurb_label.text = info.blurb
	laps_label.text = "%d" % Battle.BALLOONS
	_set_text(laps_keys, "Battle")
	difficulty_label.text = difficulty_text(difficulty)
	engine_label.text = engine_text(engine_class)
	_set_text(difficulty_keys, "Q / E")
	_set_text(engine_keys, "Z / C")
	mode_label.text = mode_text(mode, TrackLibrary.count())
	weight_label.text = weight_text(weight_class)
	bg.color = info.sky_top.darkened(0.45)
	if backdrop != null:
		backdrop.set_sky(info.sky_top)
	var names: Array = []
	for i in ArenaData.arena_count():
		names.append(ArenaData.info(i).name)
	_refresh_list(names, arena_selected)
	preview.setup(ArenaData.make(arena_selected).outline(), PREVIEW_AREA)

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

## Step the mode: Single Race -> Grand Prix -> Time Trial -> Battle -> Single Race.
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
