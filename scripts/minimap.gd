extends Control
## Top-down track minimap: the road outline plus a dot per kart (player drawn larger, with a ring).
## Styled like Mario Kart 64's course map: the route in one light colour, see-through, laid straight
## over the scene — no box behind it and no black rim round it. The route gets the HUD's drop
## shadow (a navy copy offset down-right, as the text has) to lift it off the scenery, the start
## line is a short gold tick across the route and the player's dot wears a gold ring.

const UiStyle := preload("res://scripts/ui_style.gd")

const ROAD_COLOR := Color(UiStyle.CREAM, 0.9)
const SHADOW_COLOR := Color(UiStyle.PANEL_FILL, 0.5)   # navy, not black — the HUD's drop shadow for the route
const SHADOW_OFFSET := Vector2(2, 2)
const ROAD_WIDTH := 5.0
const START_COLOR := UiStyle.GOLD
const START_LENGTH := 12.0                            # the start tick, across the route at sample 0
const START_WIDTH := 3.0
const PLAYER_RING := UiStyle.GOLD
const RAIL_COLOR := Color(0.55, 0.55, 0.6, 0.9)   # MK64 shows the railway on the Kalimari Desert map

var map_points := PackedVector2Array()
var rail_points := PackedVector2Array()
var map_scale := 1.0
var map_offset := Vector2.ZERO
var marker_positions := PackedVector2Array()
var marker_colors: Array[Color] = []

## Fit the XZ footprint of `points` inside `area` (with `pad` margin), keeping aspect ratio and centred.
## Returns {"scale": float, "offset": Vector2}; map = Vector2(p.x, p.z) * scale + offset.
static func fit(points: PackedVector3Array, area: Vector2, pad: float) -> Dictionary:
	if points.is_empty():
		return {"scale": 1.0, "offset": area * 0.5}
	var lo := Vector2(points[0].x, points[0].z)
	var hi := lo
	for p in points:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var span := hi - lo
	var avail := area - Vector2(pad, pad) * 2.0
	var s := minf(avail.x / maxf(span.x, 0.001), avail.y / maxf(span.y, 0.001))
	var offset := area * 0.5 - (lo + span * 0.5) * s
	return {"scale": s, "offset": offset}

static func to_map(p: Vector3, map_scale_: float, offset: Vector2) -> Vector2:
	return Vector2(p.x, p.z) * map_scale_ + offset

## The start-line tick: the two ends of a line `length` long across the route at its first point
## (perpendicular to the first segment). Empty when there is no segment to cross.
static func start_tick(points: PackedVector2Array, length: float) -> PackedVector2Array:
	if points.size() < 2:
		return PackedVector2Array()
	var dir := points[1] - points[0]
	if dir.length_squared() < 0.000001:
		return PackedVector2Array()
	var across := dir.normalized().orthogonal() * length * 0.5
	return PackedVector2Array([points[0] - across, points[0] + across])

## rail (optional): the railway loop, drawn under the road; the map is fitted around both.
func setup(points: PackedVector3Array, area: Vector2, rail := PackedVector3Array()) -> void:
	custom_minimum_size = area
	size = area
	var f := fit(points + rail, area, 14.0)
	map_scale = f["scale"]
	map_offset = f["offset"]
	map_points.clear()
	for p in points:
		map_points.append(to_map(p, map_scale, map_offset))
	if not map_points.is_empty():
		map_points.append(map_points[0])
	rail_points.clear()
	for p in rail:
		rail_points.append(to_map(p, map_scale, map_offset))
	if not rail_points.is_empty():
		rail_points.append(rail_points[0])
	queue_redraw()

## positions: world positions (player first); colors: matching marker colours.
func set_markers(positions: Array, colors: Array) -> void:
	marker_positions.clear()
	marker_colors.clear()
	for i in positions.size():
		marker_positions.append(to_map(positions[i], map_scale, map_offset))
		marker_colors.append(colors[i])
	queue_redraw()

func _draw() -> void:
	if rail_points.size() > 1:
		draw_polyline(rail_points, RAIL_COLOR, 2.0, true)
	if map_points.size() > 1:
		var shadow := PackedVector2Array()
		for p in map_points:
			shadow.append(p + SHADOW_OFFSET)
		draw_polyline(shadow, SHADOW_COLOR, ROAD_WIDTH, true)
		draw_polyline(map_points, ROAD_COLOR, ROAD_WIDTH, true)
		var tick := start_tick(map_points, START_LENGTH)
		if tick.size() == 2:
			draw_line(tick[0], tick[1], START_COLOR, START_WIDTH, true)
	# AI first so the player (index 0) is drawn on top
	for i in range(marker_positions.size() - 1, -1, -1):
		var is_player := i == 0
		var r := 6.0 if is_player else 4.5
		draw_circle(marker_positions[i] + SHADOW_OFFSET, r, SHADOW_COLOR)
		if is_player:
			draw_circle(marker_positions[i], r + 2.0, PLAYER_RING)
		draw_circle(marker_positions[i], r, marker_colors[i])
