extends Control
## Title screen like Mario Kart 64's: on launch the logo sits over a live attract demo — four CPU
## karts lapping the highlighted course in a 3D viewport behind the menu — with a blinking PRESS
## ENTER. Any key brings up the select screen, laid out like MK64's: a "SELECT COURSE" banner, a
## course list on the left with a highlighted row, the map and the course blurb in a framed panel
## on the right and a row of option cells underneath, the demo still running dimmed behind it.
## Text uses drop shadows instead of thick black outlines; only the logo's letters — set on an arch,
## shaded yellow to red, standing out of a navy extrusion like MK64's 3D block letters — have a rim.
## Left/Right (A/D) pick the track and Enter/Space races it; selection is stored in
## TrackLibrary.selected and Esc during a race comes back here (to the select screen).
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
const Attract := preload("res://scripts/attract.gd")
const RACE_SCENE := "res://scenes/main.tscn"
const BATTLE_SCENE := "res://scenes/battle.tscn"

const MODE_SINGLE := 0
const MODE_GP := 1
const MODE_TT := 2
const MODE_BATTLE := 3
const MODE_COUNT := 4

# MK64 palette (shared with the race HUD in UiStyle): gold highlights, cream body text, navy
# panels with a gold rim, a red logo
const UiStyle := preload("res://scripts/ui_style.gd")
const GOLD := UiStyle.GOLD
const GOLD_DIM := UiStyle.GOLD_DIM
const CREAM := UiStyle.CREAM
const GREY := UiStyle.GREY
const LOGO_RED := UiStyle.LOGO_RED
const PANEL_FILL := UiStyle.PANEL_FILL
const PANEL_RIM := UiStyle.PANEL_RIM
const SHADOW := UiStyle.SHADOW
const PREVIEW_AREA := Vector2(300, 186)   # map window inside the right panel
## Rounded fonts in MK64's spirit; Godot falls back to its default font when none is installed.
const FONT_NAMES := UiStyle.FONT_NAMES

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
## Option rows (MK64 Select Mode idiom): every choice of a cell in a row of pills, the picked one
## gold on a lit bar. Rebuilt on every refresh; index 0-3 = the cells, 4 = the mode tabs.
var option_rows: Array = [null, null, null, null, null]
const CELL_W := 280.0
const CELL_PAD := 16.0
const PILL_Y := 530.0
const PILL_H := 32.0
const PILL_FONT := 19
const BLURB_Y := 566.0
const BLURB_FONT := 12
const MODE_X := 200.0          # mode tabs start here, 4 x MODE_TAB_W, the mode blurb to the right
const MODE_TAB_W := 150.0
const MODE_BLURB_X := 816.0
const MODE_Y := 598.0
const MODE_H := 32.0
const MODE_NAMES := ["SINGLE RACE", "GRAND PRIX", "TIME TRIAL", "BATTLE"]
const LOCKED := Color(0.72, 0.76, 0.86, 0.8)     # a fixed value (time trial laps / engine, battle balloons)
const UNLIT := Color(0.98, 0.97, 0.92, 0.55)     # a choice that is not picked
## Title screen: the logo over the attract demo. Shown once per launch; Esc from a race comes back
## to the select screen instead.
var attract = null             # Attract (SubViewportContainer) under everything but bg
var select_box: Control        # every select-screen panel and label (hidden on the title screen)
var title_prompt: Label        # PRESS ENTER on the title screen
var title_shown := false
static var title_seen := false
const TITLE_LOGO_POS := Vector2(240, 150)   # logo position on the title screen (upper half)
const MENU_LOGO_POS := Vector2(240, 4)      # logo position on the select screen (clears the banner at 162)
const TITLE_LOGO_SCALE := 1.3
## The logo: "GOKART" set on an arch like MK64's logo, each letter a stack of layers — a soft
## shadow, LOGO_DEPTH navy extrusion layers, a dark red rim and a yellow -> orange -> red gradient
## fill painted by shaders/logo_gradient.gdshader.
const LogoShader := preload("res://shaders/logo_gradient.gdshader")
const LOGO_TEXT := "GOKART"
const LOGO_FONT := 112
const LOGO_BOX := Vector2(800, 156)
const LOGO_GAP := 2.0                        # extra space between letters
const LOGO_CROWN_Y := 0.0                    # the middle letters' top edge inside the box
const LOGO_ARC_RADIUS := 900.0               # edge letters sit ~26 px lower, tilted ~14 degrees
const LOGO_CAP_HEIGHT := 0.72                # cap height / font size, for the gradient span
const LOGO_DEPTH := 8                        # extrusion layers
const LOGO_DEPTH_STEP := Vector2(1.25, 1.5)  # offset per extrusion layer
const LOGO_EXTRUDE := Color(0.08, 0.1, 0.3)  # deep navy block sides (MK64 uses black; no black here)
const LOGO_SHADOW := Color(0.02, 0.03, 0.1, 0.45)
const LOGO_SHADOW_OFF := Vector2(5, 7)
const LOGO_TOP := Color(1.0, 0.95, 0.55)     # gradient: light yellow at the top ...
const LOGO_MID := Color(1.0, 0.55, 0.12)     # ... orange in the middle, LOGO_RED at the baseline

## Drawn over the attract demo and under the panels: a translucent sky-tinted shade (light on the
## title screen so the race shows through, heavier behind the select screen), faint diagonal
## stripes and a checkered-flag band above the key hints.
class Backdrop extends Control:
	var top := Color(0.1, 0.2, 0.5)
	var bottom := Color(0.02, 0.03, 0.1)
	var dim := 1.0        # 0 = title screen (race in full view), 1 = select screen
	var band_y := 650.0   # stage coordinates (1280x720 layout)
	func set_sky(sky: Color) -> void:
		top = sky.darkened(0.15)
		bottom = sky.darkened(0.78)
		queue_redraw()
	func set_dim(d: float) -> void:
		dim = d
		queue_redraw()
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var t := Color(top, lerpf(0.0, 0.55, dim))
		var b := Color(bottom, lerpf(0.45, 0.9, dim))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([t, t, b, b]))
		var stripe := Color(1, 1, 1, 0.035 * dim)
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
	return UiStyle.make_font()

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
	# the live race behind everything (MK64 title screen), then the shade, then the 2D layout
	attract = Attract.new()
	add_child(attract)
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
	select_box = Control.new()
	select_box.size = Vector2(1280, 720)
	stage.add_child(select_box)
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
	select_box.add_child(list_box)
	var arrows := _label(Vector2(80, 468), 13, 420, GREY)
	arrows.text = "<  A / D  or  Left / Right  >"
	# right panel: map + name + blurb
	_panel(Rect2(520, 220, 680, 278), PANEL_FILL, PANEL_RIM, 16)
	_panel(Rect2(538, 240, 316, 202), Color(0, 0, 0, 0.25), Color(1, 1, 1, 0.35), 8)
	preview = Minimap.new()
	preview.position = Vector2(546, 248)
	select_box.add_child(preview)
	name_label = _label(Vector2(870, 244), 34, 316, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	blurb_label = _label(Vector2(870, 296), 19, 316, CREAM, HORIZONTAL_ALIGNMENT_LEFT)
	blurb_label.size.y = 130
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	index_label = _label(Vector2(870, 452), 17, 316, GREY, HORIZONTAL_ALIGNMENT_LEFT)
	# option cells: MK64 lists every choice and lights the picked one (Select Mode screen), so each
	# cell shows all its options as a row of pills with the chosen one gold on a lit bar
	_panel(Rect2(80, 500, 1120, 142), PANEL_FILL, PANEL_RIM, 16)
	var captions := ["LAPS", "CPU", "ENGINE", "KART"]
	var keys := ["W / S", "Q / E", "Z / C", "X / V"]
	var values: Array[Label] = []
	var key_labels: Array[Label] = []
	for i in 4:
		var x := 80.0 + 280.0 * i
		var cap := _label(Vector2(x + CELL_PAD, 508), 14, 140, GOLD_DIM, HORIZONTAL_ALIGNMENT_LEFT)
		cap.text = captions[i]
		if i == 0:
			laps_caption = cap
		var k := _label(Vector2(x + CELL_PAD, 510), 12, CELL_W - 2 * CELL_PAD, GREY, HORIZONTAL_ALIGNMENT_RIGHT)
		k.text = keys[i]
		key_labels.append(k)
		var v := _label(Vector2(x + CELL_PAD, PILL_Y), PILL_FONT, CELL_W - 2 * CELL_PAD, CREAM)
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		values.append(v)
		if i > 0:
			var sep := ColorRect.new()
			sep.position = Vector2(x, 512)
			sep.size = Vector2(1, 70)
			sep.color = Color(1, 1, 1, 0.14)
			select_box.add_child(sep)
	laps_label = values[0]
	difficulty_label = values[1]
	engine_label = values[2]
	laps_keys = key_labels[0]
	difficulty_keys = key_labels[1]
	engine_keys = key_labels[2]
	# the kart cell lights a weight name and explains it underneath
	weight_label = values[3]
	weight_label.position = Vector2(80.0 + 280.0 * 3, BLURB_Y)
	weight_label.size = Vector2(CELL_W, 18)
	UiStyle.style_label(weight_label, font, BLURB_FONT, GREY)
	var rule := ColorRect.new()
	rule.position = Vector2(96, 590)
	rule.size = Vector2(1088, 1)
	rule.color = Color(1, 1, 1, 0.14)
	select_box.add_child(rule)
	var mode_cap := _label(Vector2(96, 606), 14, 100, GOLD_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	mode_cap.text = "MODE  (G)"
	mode_label = _label(Vector2(MODE_BLURB_X, MODE_Y), 14, 1184 - MODE_BLURB_X, GREY, HORIZONTAL_ALIGNMENT_LEFT)
	mode_label.size.y = MODE_H
	mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# blinking PRESS ENTER under the checkered band, like the title screen's
	prompt = _label(Vector2(340, 674), 24, 600, GOLD)
	prompt.text = "PRESS ENTER"
	# the logo sits above the panels; the title prompt only shows on the title screen
	_build_title()
	title_prompt = Label.new()
	title_prompt.position = Vector2(340, 560)
	title_prompt.size = Vector2(600, 60)
	title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_prompt.text = "PRESS ENTER"
	UiStyle.style_sign(title_prompt, font, 40)
	stage.add_child(title_prompt)
	_refresh()
	set_title(not title_seen)

## Title screen on (logo large over the race, PRESS ENTER, no panels) or the select screen.
func set_title(on: bool) -> void:
	title_shown = on
	if on:
		title_seen = true
	if select_box != null:
		select_box.visible = not on
	if title_prompt != null:
		title_prompt.visible = on
	if title_box != null:
		title_box.position = TITLE_LOGO_POS if on else MENU_LOGO_POS
		title_box.scale = Vector2.ONE * (TITLE_LOGO_SCALE if on else 1.0)
	if backdrop != null:
		backdrop.set_dim(0.0 if on else 1.0)

## Leave the title screen for the select screen (any key).
func dismiss_title() -> void:
	if title_shown:
		set_title(false)

## Where a logo letter whose centre is `centre_x` from the word's middle sits on the arch: how far
## it drops below the crown and the tilt that follows the arc (negative = leaning left). Pure.
static func logo_letter_pose(centre_x: float, radius: float) -> Dictionary:
	var dx := clampf(centre_x, -radius, radius)
	return {"drop": radius - sqrt(radius * radius - dx * dx), "angle": asin(dx / radius)}

## "GOKART" like the MK64 logo: chunky letters set on an arch, each shaded from light yellow through
## orange to red with a dark red rim, standing out of a deep navy extrusion (MK64's letters are 3D
## blocks with a bold shadow — here in navy rather than black) over a soft shadow.
func _build_title() -> void:
	title_box = Control.new()
	title_box.position = MENU_LOGO_POS
	title_box.size = LOGO_BOX
	title_box.pivot_offset = title_box.size * 0.5
	stage.add_child(title_box)
	var widths: Array[float] = []
	var total := -LOGO_GAP
	for ch in LOGO_TEXT:
		var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, LOGO_FONT).x
		widths.append(w)
		total += w + LOGO_GAP
	var ascent := font.get_ascent(LOGO_FONT)
	var line_h := font.get_height(LOGO_FONT)
	var x := (LOGO_BOX.x - total) * 0.5
	for i in LOGO_TEXT.length():
		var ch := LOGO_TEXT[i]
		var w: float = widths[i]
		var pose := logo_letter_pose(x + w * 0.5 - LOGO_BOX.x * 0.5, LOGO_ARC_RADIUS)
		var letter := Control.new()
		letter.name = "Letter%d" % i
		letter.size = Vector2(w, line_h)
		letter.position = Vector2(x, LOGO_CROWN_Y + pose.drop)
		letter.pivot_offset = Vector2(w * 0.5, ascent)   # turn about the middle of the baseline
		letter.rotation = pose.angle
		title_box.add_child(letter)
		var depth := LOGO_DEPTH_STEP * LOGO_DEPTH
		letter.add_child(_logo_glyph(ch, depth + LOGO_SHADOW_OFF, LOGO_SHADOW, LOGO_SHADOW))
		for d in range(LOGO_DEPTH, 0, -1):
			letter.add_child(_logo_glyph(ch, LOGO_DEPTH_STEP * d, LOGO_EXTRUDE, LOGO_EXTRUDE))
		letter.add_child(_logo_glyph(ch, Vector2.ZERO, UiStyle.SIGN_RIM, UiStyle.SIGN_RIM))
		var fill := _logo_glyph(ch, Vector2.ZERO, LOGO_RED, Color.TRANSPARENT, false)
		var mat := ShaderMaterial.new()
		mat.shader = LogoShader
		mat.set_shader_parameter("top_color", LOGO_TOP)
		mat.set_shader_parameter("mid_color", LOGO_MID)
		mat.set_shader_parameter("bottom_color", LOGO_RED)
		mat.set_shader_parameter("top_y", ascent - LOGO_FONT * LOGO_CAP_HEIGHT)
		mat.set_shader_parameter("bottom_y", ascent)
		fill.material = mat
		letter.add_child(fill)
		x += w + LOGO_GAP

## One layer of a logo letter: the glyph in `col` with a rim (outline) in `rim` — the extrusion and
## shadow layers are solid, the rim layer gives the fill its edge — or, without a rim, the fill
## layer the gradient shader paints. No drop shadow of its own (the extrusion is the shadow).
func _logo_glyph(ch: String, offset: Vector2, col: Color, rim: Color, outlined := true) -> Label:
	var l := Label.new()
	l.text = ch
	l.position = offset
	l.size = Vector2(font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, LOGO_FONT).x, font.get_height(LOGO_FONT))
	if outlined:
		UiStyle.style_sign(l, font, LOGO_FONT, col, rim)
	else:
		UiStyle.style_label(l, font, LOGO_FONT, col)
	l.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	return l

## Select-screen panel (hidden with the rest of select_box on the title screen).
func _panel(rect: Rect2, fill: Color, rim: Color, radius: int) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", UiStyle.panel_style(fill, rim, radius))
	select_box.add_child(p)
	return p

func _label(pos: Vector2, font_size: int, w: float, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(w, font_size * 1.4)
	l.horizontal_alignment = align
	UiStyle.style_label(l, font, font_size, col)
	select_box.add_child(l)
	return l

func _process(delta: float) -> void:
	blink += delta
	var a := 0.6 + 0.4 * sin(blink * 5.0)
	if prompt != null:
		prompt.modulate.a = a
	if title_prompt != null:
		title_prompt.modulate.a = a

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
			bar.add_theme_stylebox_override("panel", UiStyle.lit_style(10))
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

## Choice lists for the option rows (pure data, shared with the tests).
static func lap_names() -> Array:
	var out: Array = []
	for n in TrackLibrary.LAP_OPTIONS:
		out.append(laps_text(n))
	return out

static func names_of(classes: Array) -> Array:
	var out: Array = []
	for c in classes:
		out.append(c.name)
	return out

## Where a row of choice pills sits: slots 0-3 inside the option cells, 4 = the mode tab strip.
static func row_rect(slot: int) -> Rect2:
	if slot == 4:
		return Rect2(MODE_X, MODE_Y, MODE_TAB_W * MODE_NAMES.size(), MODE_H)
	return Rect2(80.0 + CELL_W * slot + CELL_PAD, PILL_Y, CELL_W - 2 * CELL_PAD, PILL_H)

## Rebuild the five option rows for the current state. A locked cell (time trial laps / CPU /
## engine, battle balloons) shows its fixed value alone in grey instead of a row of choices.
func _refresh_options() -> void:
	if select_box == null:
		return
	var locked_laps := mode == MODE_TT or mode == MODE_BATTLE
	var locked_tt := mode == MODE_TT
	_option_row(0, [] if locked_laps else lap_names(), TrackLibrary.LAP_OPTIONS.find(laps), laps_label)
	_option_row(1, [] if locked_tt else names_of(TrackLibrary.DIFFICULTIES), difficulty, difficulty_label)
	_option_row(2, [] if locked_tt else names_of(TrackLibrary.ENGINE_CLASSES), engine_class, engine_label)
	_option_row(3, names_of(KartWeight.CLASSES), weight_class, null)
	_option_row(4, MODE_NAMES, mode, null)

## One row of choice pills: the picked choice gold on a lit bar — the cell's own value label when
## it has one, so the checks keep reading laps_label / difficulty_label / engine_label — and the
## others dim cream. An empty list parks the value label alone across the row in the locked colour.
func _option_row(slot: int, names: Array, active: int, value_label: Label) -> void:
	var old = option_rows[slot]
	if old != null:
		select_box.remove_child(old)
		old.queue_free()
	var rect := row_rect(slot)
	var row := Control.new()
	row.position = rect.position
	row.size = rect.size
	select_box.add_child(row)
	option_rows[slot] = row
	if value_label != null:
		value_label.position = rect.position
		value_label.size = rect.size
		value_label.add_theme_color_override("font_color", LOCKED)
		select_box.move_child(value_label, -1)
	var w := rect.size.x / maxi(names.size(), 1)
	for i in names.size():
		var slot_rect := Rect2(Vector2(w * i, 0), Vector2(w, rect.size.y))
		if i == active:
			var bar := Panel.new()
			bar.position = slot_rect.position + Vector2(2, 0)
			bar.size = slot_rect.size - Vector2(4, 0)
			bar.add_theme_stylebox_override("panel", UiStyle.lit_style(8))
			row.add_child(bar)
			if value_label != null:
				value_label.position = rect.position + slot_rect.position
				value_label.size = slot_rect.size
				value_label.add_theme_color_override("font_color", GOLD)
				continue
		var l := Label.new()
		l.position = slot_rect.position
		l.size = slot_rect.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text = names[i]
		UiStyle.style_label(l, font, PILL_FONT, GOLD if i == active else UNLIT)
		row.add_child(l)

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
	if attract != null:
		attract.show_course(selected, mirror)
	_refresh_options()

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
	_refresh_options()

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
	if title_shown:
		# MK64: Start leaves the title screen; an option key does the same and is applied as well
		dismiss_title()
		if is_confirm_key(event.physical_keycode):
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
