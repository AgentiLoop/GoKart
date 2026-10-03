extends CanvasLayer
## Race HUD: lap counter, lap/race timers, speed, boost/drift indicator, finish banner.

const Items := preload("res://scripts/items.gd")
const RaceRanking := preload("res://scripts/race_ranking.gd")
const Minimap := preload("res://scripts/minimap.gd")

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
var cup_label: Label
var minimap: Minimap

static func format_time(t: float) -> String:
	var total_ms := int(round(t * 1000.0))
	return "%d:%02d.%03d" % [total_ms / 60000, (total_ms / 1000) % 60, total_ms % 1000]

## Held item label; triple items show the charges left ("x3"), a fired golden mushroom
## its remaining seconds.
static func item_text(item: int, charges := 0, golden_left := 0.0) -> String:
	if item == Items.Type.NONE:
		return ""
	var extra := ""
	if Items.is_triple(item) and charges > 0:
		extra = " x%d" % charges
	elif item == Items.Type.GOLDEN_MUSHROOM and golden_left > 0.0:
		extra = " %.1fs" % golden_left
	return "[ %s%s ]" % [Items.name_of(item), extra]

## Tells the player how to release a held item (empty when nothing is held).
static func item_hint_text(item: int) -> String:
	return "" if item == Items.Type.NONE else "Press E / Enter / Ctrl to use"

static func place_text(rank: int, total: int) -> String:
	return "" if total <= 1 else "%s / %d" % [RaceRanking.ordinal(rank), total]

static func lap_text(lap: int, total: int) -> String:
	return "LAP %d/%d" % [clampi(lap, 1, total), total]

func _ready() -> void:
	# Drawn above the speed-effect overlay (layer 5) so speed lines / blur never touch the UI.
	layer = 10
	# Every label spans the whole viewport and is aligned/inset inside it, so the HUD
	# follows the window edges at any size or aspect ratio.
	lap_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 16), 36)
	time_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 64), 22)
	cup_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 128), 22)
	cup_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	speed_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, Vector2(24, 24), 36)
	state_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM, Vector2(24, 24), 28)
	item_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP, Vector2(0, 16), 32)
	hint_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP, Vector2(0, 56), 22)
	place_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 16), 48)
	countdown_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, Vector2(0, -110), 160)
	banner_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, Vector2(0, -30), 72)
	results_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_CENTER, Vector2(0, -20), 24)
	# a block sized to its text and centred on screen (lines stay left-aligned in the monospace table);
	# 24 px keeps an 8-racer results table plus the cup standings inside a 720 px window
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
	return f

func _make_label(h_align: HorizontalAlignment, v_align: VerticalAlignment, inset: Vector2, font_size: int) -> Label:
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
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l

## Corner minimap of the track centerline; call update_minimap each frame with kart positions/colours.
func setup_minimap(points: PackedVector3Array) -> void:
	minimap = Minimap.new()
	add_child(minimap)
	minimap.setup(points, Vector2(220, 220))
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

## Grand Prix progress line under the timers ("RACE 2 / 3"); empty hides it.
func show_cup(text: String) -> void:
	cup_label.text = text

## Big centre text for the start countdown ("3", "2", "1", "GO!"); empty hides it.
func show_countdown(text: String) -> void:
	countdown_label.text = text

func update_hud(tracker, speed: float, boosting: bool, drift_level: int, item := 0, place := "", star := false, shrunk := false, charges := 0, golden_left := 0.0) -> void:
	place_label.text = place
	item_label.text = item_text(item, charges, golden_left)
	hint_label.text = item_hint_text(item)
	lap_label.text = lap_text(tracker.lap, tracker.total_laps) if tracker.lap > 0 else "READY"
	time_label.text = "TIME %s\nLAP  %s" % [format_time(tracker.race_time), format_time(tracker.lap_time)]
	speed_label.text = "%d km/h" % int(round(absf(speed) * 3.6))
	var s := ""
	if star:
		s = "STAR!"
	elif boosting:
		s = "BOOST!"
	elif shrunk:
		s = "SHRUNK!"
	elif drift_level > 0:
		s = ["", "MINI-TURBO", "SUPER MINI-TURBO", "ULTRA MINI-TURBO"][drift_level]
	state_label.text = s
	banner_label.text = "FINISH!" if tracker.is_finished else ""
