extends CanvasLayer
## Race HUD: lap counter, lap/race timers, speed, boost/drift indicator, finish banner.
## Styled like the title menu (UiStyle): rounded bold font, gold / cream text with drop shadows,
## no black outlines; only the countdown and the centre banner are "signs" with a dark red rim,
## and the results table sits on a navy panel with a gold rim.

const Items := preload("res://scripts/items.gd")
const RaceRanking := preload("res://scripts/race_ranking.gd")
const Minimap := preload("res://scripts/minimap.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

const RESULTS_PAD := Vector2(36, 26)

var font: Font
var lap_label: Label
var time_label: Label
var speed_label: Label
var state_label: Label
var banner_label: Label
var item_label: Label
var hint_label: Label
var place_label: Label
var countdown_label: Label
var results_label: Label
var results_panel: Panel
var cup_label: Label
var minimap: Minimap

static func format_time(t: float) -> String:
	var total_ms := int(round(t * 1000.0))
	return "%d:%02d.%03d" % [total_ms / 60000, (total_ms / 1000) % 60, total_ms % 1000]

## Held item label; multi-use items show the charges left ("x3"), a fired golden mushroom
## its remaining seconds.
static func item_text(item: int, charges := 0, golden_left := 0.0) -> String:
	if item == Items.Type.NONE:
		return ""
	var extra := ""
	if Items.charges_for(item) > 0 and charges > 0:
		extra = " x%d" % charges
	elif item == Items.Type.GOLDEN_MUSHROOM and golden_left > 0.0:
		extra = " %.1fs" % golden_left
	return "[ %s%s ]" % [Items.name_of(item), extra]

## Tells the player how to release a held item (empty when nothing is held).
static func item_hint_text(item: int) -> String:
	return "" if item == Items.Type.NONE else "Press E / Enter / Ctrl to use"

## Bottom-left status word: star beats a Boo ghost beats a boost beats shrunk beats the mini-turbo level.
static func state_text(boosting: bool, drift_level: int, star := false, shrunk := false, ghost := false) -> String:
	if star:
		return "STAR!"
	if ghost:
		return "BOO!"
	if boosting:
		return "BOOST!"
	if shrunk:
		return "SHRUNK!"
	if drift_level > 0:
		return ["", "MINI-TURBO", "SUPER MINI-TURBO", "ULTRA MINI-TURBO"][drift_level]
	return ""

static func place_text(rank: int, total: int) -> String:
	return "" if total <= 1 else "%s / %d" % [RaceRanking.ordinal(rank), total]

static func lap_text(lap: int, total: int) -> String:
	return "LAP %d/%d" % [clampi(lap, 1, total), total]

func _ready() -> void:
	# Drawn above the speed-effect overlay (layer 5) so speed lines / blur never touch the UI.
	layer = 10
	font = UiStyle.make_font()
	# Every label spans the whole viewport and is aligned/inset inside it, so the HUD
	# follows the window edges at any size or aspect ratio.
	lap_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 16), 36, UiStyle.GOLD)
	time_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 64), 22, UiStyle.CREAM)
	cup_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 128), 22, UiStyle.SKY_BLUE)
	speed_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, Vector2(24, 24), 36, UiStyle.CREAM)
	state_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM, Vector2(24, 24), 28, UiStyle.GOLD)
	item_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP, Vector2(0, 16), 32, UiStyle.CREAM)
	hint_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP, Vector2(0, 56), 22, UiStyle.GREY)
	place_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 16), 48, UiStyle.GOLD)
	# the countdown and the centre banner are big "signs": gold with a dark red rim like the logo
	countdown_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, Vector2(0, -110), 160, UiStyle.GOLD)
	UiStyle.style_sign(countdown_label, font, 160)
	banner_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, Vector2(0, -30), 72, UiStyle.GOLD)
	UiStyle.style_sign(banner_label, font, 72)
	# results: a navy panel with a gold rim behind a monospace table block, both centred on screen
	# (lines stay left-aligned so the columns line up); 24 px keeps an 8-racer table plus the cup
	# standings inside a 720 px window
	results_panel = Panel.new()
	results_panel.set_anchors_preset(Control.PRESET_CENTER)
	results_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.PANEL_FILL, UiStyle.PANEL_RIM, 18))
	results_panel.visible = false
	add_child(results_panel)
	results_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, Vector2(0, -20), 24, UiStyle.CREAM)
	results_label.set_anchors_preset(Control.PRESET_CENTER)
	results_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	results_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	results_label.offset_left = 0.0
	results_label.offset_right = 0.0
	results_label.offset_top = -20.0
	results_label.offset_bottom = -20.0
	results_label.add_theme_font_override("font", _mono_font())
	results_label.visible = false

static func _mono_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Menlo", "Courier New", "monospace"])
	f.font_weight = 700
	return f

func _make_label(h_align: HorizontalAlignment, v_align: VerticalAlignment, inset: Vector2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = inset.x
	l.offset_right = -inset.x
	if v_align == VERTICAL_ALIGNMENT_CENTER:
		l.offset_top = inset.y      # centred labels: inset.y shifts them up/down
		l.offset_bottom = inset.y
	else:
		l.offset_top = inset.y
		l.offset_bottom = -inset.y
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = h_align
	l.vertical_alignment = v_align
	UiStyle.style_label(l, font, font_size, col)
	add_child(l)
	return l

## Corner minimap of the track centerline (and the railway, if any); call update_minimap each frame
## with kart positions/colours.
func setup_minimap(points: PackedVector3Array, rail := PackedVector3Array()) -> void:
	minimap = Minimap.new()
	add_child(minimap)
	minimap.setup(points, Vector2(220, 220), rail)
	# pinned to the bottom-left corner, above the state text
	minimap.anchor_left = 0.0
	minimap.anchor_right = 0.0
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_left = 24.0
	minimap.offset_right = 244.0
	minimap.offset_top = -284.0
	minimap.offset_bottom = -64.0

func update_minimap(positions: Array, colors: Array) -> void:
	if minimap != null:
		minimap.set_markers(positions, colors)

## Final standings panel (text from RaceResults.table_text); empty hides it.
func show_results(text: String) -> void:
	results_label.text = text
	results_label.visible = text != ""
	results_panel.visible = results_label.visible
	if results_panel.visible:
		# the label grows both ways from the screen centre; wrap the panel around it with padding
		var half := results_label.get_minimum_size() * 0.5 + RESULTS_PAD
		results_panel.offset_left = -half.x
		results_panel.offset_right = half.x
		results_panel.offset_top = -20.0 - half.y
		results_panel.offset_bottom = -20.0 + half.y

## Grand Prix progress line under the timers ("RACE 2 / 3"); empty hides it.
func show_cup(text: String) -> void:
	cup_label.text = text

## Big centre text for the start countdown ("3", "2", "1", "GO!"); empty hides it.
func show_countdown(text: String) -> void:
	countdown_label.text = text

func update_hud(tracker, speed: float, boosting: bool, drift_level: int, item := 0, place := "", star := false, shrunk := false, charges := 0, golden_left := 0.0, ghost := false) -> void:
	place_label.text = place
	item_label.text = item_text(item, charges, golden_left)
	hint_label.text = item_hint_text(item)
	lap_label.text = lap_text(tracker.lap, tracker.total_laps) if tracker.lap > 0 else "READY"
	time_label.text = "TIME %s\nLAP  %s" % [format_time(tracker.race_time), format_time(tracker.lap_time)]
	speed_label.text = "%d km/h" % int(round(absf(speed) * 3.6))
	state_label.text = state_text(boosting, drift_level, star, shrunk, ghost)
	banner_label.text = "FINISH!" if tracker.is_finished else ""

## Battle mode HUD: balloons instead of laps, the battle clock instead of lap times, no finish banner
## (the centre banner shows `banner`: "BOMB KART!" / "YOU WIN!" / "OUT").
func update_battle(balloons_line: String, elapsed: float, speed: float, boosting: bool, drift_level: int, item := 0, place := "", star := false, shrunk := false, charges := 0, golden_left := 0.0, ghost := false, banner := "") -> void:
	place_label.text = place
	item_label.text = item_text(item, charges, golden_left)
	hint_label.text = item_hint_text(item)
	lap_label.text = balloons_line
	time_label.text = "TIME %s" % format_time(elapsed)
	speed_label.text = "%d km/h" % int(round(absf(speed) * 3.6))
	state_label.text = state_text(boosting, drift_level, star, shrunk, ghost)
	banner_label.text = banner
