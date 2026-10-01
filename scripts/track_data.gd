extends RefCounted
## Pure track geometry (no scene nodes): closed centerline from control points,
## resampled to uniform spacing, plus road queries. Unit tested.

const BoostPad := preload("res://scripts/boost_pad.gd")

const DEFAULT_CONTROL: Array[Vector2] = [
	Vector2(0, 40), Vector2(0, -40), Vector2(30, -90), Vector2(80, -100),
	Vector2(120, -70), Vector2(110, -20), Vector2(70, 10), Vector2(80, 50),
	Vector2(120, 80), Vector2(100, 130), Vector2(40, 130), Vector2(0, 100),
]
## [fraction of lap, lateral offset in metres (+ = right)]
const DEFAULT_PADS := [[0.2, 0.0], [0.45, -3.0], [0.7, 3.0], [0.9, 0.0]]
## Item box rows: fraction of lap. Each row spans the road at ITEM_BOX_OFFSETS.
const DEFAULT_BOX_ROWS := [0.1, 0.33, 0.58, 0.8]
const ITEM_BOX_OFFSETS := [-4.5, -1.5, 1.5, 4.5]
## Pre-placed banana hazards: [fraction of lap, lateral offset]
const DEFAULT_HAZARDS := [[0.27, 2.0], [0.52, -2.5]]

var width := 16.0
var spacing := 3.0
var control: Array[Vector2] = DEFAULT_CONTROL
var points := PackedVector3Array()
var tangents := PackedVector3Array()
var count := 0
var length := 0.0
var pad_specs: Array = DEFAULT_PADS
var box_rows: Array = DEFAULT_BOX_ROWS
var hazard_specs: Array = DEFAULT_HAZARDS
var pads: Array = []
var item_box_positions: Array[Vector3] = []
var hazard_positions: Array[Vector3] = []

## layout (optional) may override "pads", "box_rows" and "hazards" (same formats as the DEFAULT_ constants).
func _init(ctrl: Array[Vector2] = DEFAULT_CONTROL, road_width := 16.0, layout := {}) -> void:
	control = ctrl
	width = road_width
	pad_specs = layout.get("pads", DEFAULT_PADS)
	box_rows = layout.get("box_rows", DEFAULT_BOX_ROWS)
	hazard_specs = layout.get("hazards", DEFAULT_HAZARDS)
	_build()

static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _build() -> void:
	# dense Catmull-Rom spline through the control points
	var dense: Array[Vector2] = []
	var n := control.size()
	for i in n:
		for s in 40:
			dense.append(_catmull(control[(i - 1 + n) % n], control[i], control[(i + 1) % n], control[(i + 2) % n], s / 40.0))
	# resample at uniform arc length
	var cum := [0.0]
	for i in dense.size():
		cum.append(cum[i] + dense[i].distance_to(dense[(i + 1) % dense.size()]))
	length = cum[dense.size()]
	count = int(round(length / spacing))
	points.resize(count)
	var j := 0
	for k in count:
		var target := length * k / count
		while cum[j + 1] < target:
			j += 1
		var seg: float = cum[j + 1] - cum[j]
		var f: float = (target - cum[j]) / seg if seg > 0.0 else 0.0
		var p: Vector2 = dense[j].lerp(dense[(j + 1) % dense.size()], f)
		points[k] = Vector3(p.x, 0, p.y)
	tangents.resize(count)
	for k in count:
		tangents[k] = (points[(k + 1) % count] - points[(k - 1 + count) % count]).normalized()
	pads.clear()
	for spec in pad_specs:
		var idx: int = int(spec[0] * count) % count
		var pad := BoostPad.new()
		pad.forward = tangents[idx]
		pad.center = points[idx] + right_of(idx) * spec[1]
		pad.index = idx
		pads.append(pad)
	item_box_positions.clear()
	for f in box_rows:
		var bi: int = int(f * count) % count
		for off in ITEM_BOX_OFFSETS:
			item_box_positions.append(points[bi] + right_of(bi) * off)
	hazard_positions.clear()
	for spec in hazard_specs:
		var hi: int = int(spec[0] * count) % count
		hazard_positions.append(points[hi] + right_of(hi) * spec[1])

## Unit vector to the right of travel direction at sample i.
func right_of(i: int) -> Vector3:
	var t := tangents[posmod(i, count)]
	return Vector3(-t.z, 0, t.x)

func heading_at(i: int) -> float:
	var t := tangents[posmod(i, count)]
	return atan2(-t.x, -t.z)

## Closest sample index to pos. Searches +-window around hint, falling back to a
## full search when there is no hint or the windowed result is far off the road.
func nearest_index(pos: Vector3, hint := -1, window := 15) -> int:
	if hint >= 0:
		var best := -1
		var best_d := INF
		for o in range(-window, window + 1):
			var i := posmod(hint + o, count)
			var d := _dist_xz(points[i], pos)
			if d < best_d:
				best_d = d
				best = i
		if best_d <= width:
			return best
	var best_i := 0
	var best_dist := INF
	for i in count:
		var d := _dist_xz(points[i], pos)
		if d < best_dist:
			best_dist = d
			best_i = i
	return best_i

static func _dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Closest point on the centerline polyline to pos.
func closest_point(pos: Vector3, hint := -1) -> Vector3:
	var idx := nearest_index(pos, hint)
	var best := INF
	var best_pt := points[idx]
	var p := Vector2(pos.x, pos.z)
	for o in [-1, 0]:
		var a3 := points[posmod(idx + o, count)]
		var b3 := points[posmod(idx + o + 1, count)]
		var a := Vector2(a3.x, a3.z)
		var b := Vector2(b3.x, b3.z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			best_pt = a3.lerp(b3, t)
	return best_pt

## Distance from pos to the centerline polyline.
func distance_to_center(pos: Vector3, hint := -1) -> float:
	return _dist_xz(closest_point(pos, hint), pos)

func is_on_road(pos: Vector3, hint := -1) -> bool:
	return distance_to_center(pos, hint) <= width * 0.5

## Smallest distance between two samples that are far apart along the track
## (detects the track overlapping itself).
func min_separation() -> float:
	var best := INF
	var gap := count / 8
	for i in count:
		for j in range(i + gap, count):
			if count - (j - i) < gap:
				continue
			best = minf(best, _dist_xz(points[i], points[j]))
	return best

func pad_at(pos: Vector3):
	for p in pads:
		if p.contains(pos):
			return p
	return null
