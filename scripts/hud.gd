extends CanvasLayer
## Race HUD: lap counter, lap/race timers, speed, boost/drift indicator, finish banner.

const Items := preload("res://scripts/items.gd")

var lap_label: Label
var time_label: Label
var speed_label: Label
var state_label: Label
var banner_label: Label
var item_label: Label

static func format_time(t: float) -> String:
	var total_ms := int(round(t * 1000.0))
	return "%d:%02d.%03d" % [total_ms / 60000, (total_ms / 1000) % 60, total_ms % 1000]

static func item_text(item: int) -> String:
	return "" if item == Items.Type.NONE else "[ %s ]" % Items.name_of(item)

static func lap_text(lap: int, total: int) -> String:
	return "LAP %d/%d" % [clampi(lap, 1, total), total]

func _ready() -> void:
	lap_label = _make_label(Vector2(24, 16), 36, HORIZONTAL_ALIGNMENT_LEFT)
	time_label = _make_label(Vector2(24, 64), 22, HORIZONTAL_ALIGNMENT_LEFT)
	speed_label = _make_label(Vector2(1056, 650), 36, HORIZONTAL_ALIGNMENT_RIGHT)
	speed_label.custom_minimum_size = Vector2(200, 0)
	state_label = _make_label(Vector2(24, 660), 28, HORIZONTAL_ALIGNMENT_LEFT)
	item_label = _make_label(Vector2(440, 16), 32, HORIZONTAL_ALIGNMENT_CENTER)
	item_label.size = Vector2(400, 40)
	banner_label = _make_label(Vector2(340, 280), 72, HORIZONTAL_ALIGNMENT_CENTER)
	banner_label.size = Vector2(600, 100)

func _make_label(pos: Vector2, font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l

func update_hud(tracker, speed: float, boosting: bool, drift_level: int, item := 0) -> void:
	item_label.text = item_text(item)
	lap_label.text = lap_text(tracker.lap, tracker.total_laps) if tracker.lap > 0 else "READY"
	time_label.text = "TIME %s\nLAP  %s" % [format_time(tracker.race_time), format_time(tracker.lap_time)]
	speed_label.text = "%d km/h" % int(round(absf(speed) * 3.6))
	var s := ""
	if boosting:
		s = "BOOST!"
	elif drift_level > 0:
		s = ["", "MINI-TURBO", "SUPER MINI-TURBO", "ULTRA MINI-TURBO"][drift_level]
	state_label.text = s
	banner_label.text = "FINISH!" if tracker.is_finished else ""
