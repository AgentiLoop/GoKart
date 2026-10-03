extends Control
## Top-down track minimap: the road outline plus a dot per kart (player drawn larger, with a ring).

const ROAD_COLOR := Color(1, 1, 1, 0.85)
const OUTLINE_COLOR := Color(0, 0, 0, 0.6)
const BG_COLOR := Color(0, 0, 0, 0.35)
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
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	if rail_points.size() > 1:
		draw_polyline(rail_points, RAIL_COLOR, 2.0, true)
	if map_points.size() > 1:
		draw_polyline(map_points, OUTLINE_COLOR, 8.0, true)
		draw_polyline(map_points, ROAD_COLOR, 4.0, true)
	# AI first so the player (index 0) is drawn on top
	for i in range(marker_positions.size() - 1, -1, -1):
		var is_player := i == 0
		var r := 6.0 if is_player else 4.5
		if is_player:
			draw_circle(marker_positions[i], r + 2.0, Color.WHITE)
		draw_circle(marker_positions[i], r, marker_colors[i])
