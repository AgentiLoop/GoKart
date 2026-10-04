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
## Water beside the road (Mario Kart 64 style hazard): [start fraction, end fraction, side (+1 = right)].
## The wall is missing along the span on that side; a kart that drives off the edge there falls in
## and Lakitu fishes it out.
const DEFAULT_WATER := [[0.13, 0.21, -1], [0.62, 0.69, -1]]
## Lateral distance beyond the road edge where the water starts (where the wall would stand).
const WATER_EDGE := 3.1
## How far the water stretches out from the road edge.
const WATER_WIDTH := 18.0
## Railway level crossing: road samples on each side of the crossing centre whose walls are left
## open so the rails (and the train) pass through.
const CROSSING_HALF_GAP := 2

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
var water_specs: Array = DEFAULT_WATER
var pads: Array = []
var item_box_positions: Array[Vector3] = []
var hazard_positions: Array[Vector3] = []
## Water spans as sample ranges: {"start": first sample, "end": last sample (inclusive), "side": +-1}
var water: Array = []
## Mario Kart 64 "Extra" (mirror) mode: the whole course is flipped left-to-right.
var mirrored := false
## Railway (layout "rail": control points of a closed loop, empty = no railway on this course):
## the rail samples, the loop length and the level crossings (see _build_rail).
var rail_control: Array[Vector2] = []
var rail := PackedVector3Array()
var rail_length := 0.0
var crossings: Array = []
## Traffic (layout "traffic", Mario Kart 64 Toad's Turnpike): [fraction of lap, lane in metres right
## of the centreline, kind] per vehicle (see scripts/traffic.gd); empty = no traffic on this course.
var traffic_specs: Array = []
## Monty Mole holes (layout "moles", Mario Kart 64 Moo Moo Farm): [fraction of lap, lateral offset]
## per hole (see scripts/moles.gd); empty = no moles on this course.
var mole_specs: Array = []
## Snowmen (layout "snowmen", Mario Kart 64 Frappe Snowland): [fraction of lap, lateral offset] per
## snowman (see scripts/snowmen.gd); empty = no snowmen on this course.
var snowman_specs: Array = []
## Roadside scenery set (layout "scenery", Mario Kart 64 course dressing: "farm" / "highway" / "snow" /
## "desert", see scripts/scenery.gd); "" = a bare course.
var scenery := ""
## Icy road (layout "ice", Mario Kart 64 Sherbet Land): [start fraction, end fraction] per stretch of
## road that is sheet ice across its whole width — the tires bite less there, the kart slides on;
## empty = no ice on this course. The same stretches on a mirrored course.
var ice_specs: Array = []
## Ice stretches as sample ranges: {"start": first sample, "end": last sample (inclusive)}
var ice: Array = []

## layout (optional) may override "pads", "box_rows", "hazards" and "water" (same formats as the
## DEFAULT_ constants), add a "rail" loop (Array of Vector2 control points), "traffic" vehicles,
## "moles", "snowmen" or "ice", name a "scenery" set and set "mirror": true to flip the course left-to-right (MK64 Extra mode).
func _init(ctrl: Array[Vector2] = DEFAULT_CONTROL, road_width := 16.0, layout := {}) -> void:
	control = ctrl
	width = road_width
	pad_specs = layout.get("pads", DEFAULT_PADS)
	box_rows = layout.get("box_rows", DEFAULT_BOX_ROWS)
	hazard_specs = layout.get("hazards", DEFAULT_HAZARDS)
	water_specs = layout.get("water", DEFAULT_WATER)
	traffic_specs = layout.get("traffic", [])
	mole_specs = layout.get("moles", [])
	snowman_specs = layout.get("snowmen", [])
	ice_specs = layout.get("ice", [])
	scenery = layout.get("scenery", "")
	for v in layout.get("rail", []):
		rail_control.append(v)
	mirrored = layout.get("mirror", false)
	if mirrored:
		control = mirror_control(ctrl)
		pad_specs = mirror_specs(pad_specs)
		hazard_specs = mirror_specs(hazard_specs)
		water_specs = mirror_water(water_specs)
		rail_control = mirror_control(rail_control)
		traffic_specs = mirror_specs(traffic_specs)
		mole_specs = mirror_specs(mole_specs)
		snowman_specs = mirror_specs(snowman_specs)
	_build()

## Control points flipped left-to-right (x negated); the start line stays on x = 0.
static func mirror_control(ctrl: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for v in ctrl:
		out.append(Vector2(-v.x, v.y))
	return out

## [fraction, lateral offset] specs with the lateral side swapped, so a pad that sat on the
## right of the road ends up at the mirror-image spot (the left) on the flipped course. Any further
## elements (the traffic kind) are kept.
static func mirror_specs(specs: Array) -> Array:
	var out: Array = []
	for s in specs:
		var m: Array = s.duplicate()
		m[1] = -m[1]
		out.append(m)
	return out

## [start, end, side] water specs with the side swapped (mirrored course).
static func mirror_water(specs: Array) -> Array:
	var out: Array = []
	for s in specs:
		out.append([s[0], s[1], -s[2]])
	return out

static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## Closed Catmull-Rom loop through ctrl, resampled at (about) uniform arc length `step`.
## Returns {"points": PackedVector3Array (y = 0), "length": float}.
static func resample_loop(ctrl: Array[Vector2], step: float) -> Dictionary:
	var dense: Array[Vector2] = []
	var n := ctrl.size()
	for i in n:
		for s in 40:
			dense.append(_catmull(ctrl[(i - 1 + n) % n], ctrl[i], ctrl[(i + 1) % n], ctrl[(i + 2) % n], s / 40.0))
	var cum := [0.0]
	for i in dense.size():
		cum.append(cum[i] + dense[i].distance_to(dense[(i + 1) % dense.size()]))
	var total: float = cum[dense.size()]
	var cnt := int(round(total / step))
	var pts := PackedVector3Array()
	pts.resize(cnt)
	var j := 0
	for k in cnt:
		var target := total * k / cnt
		while cum[j + 1] < target:
			j += 1
		var seg: float = cum[j + 1] - cum[j]
		var f: float = (target - cum[j]) / seg if seg > 0.0 else 0.0
		var p: Vector2 = dense[j].lerp(dense[(j + 1) % dense.size()], f)
		pts[k] = Vector3(p.x, 0, p.y)
	return {"points": pts, "length": total}

func _build() -> void:
	# dense Catmull-Rom spline through the control points, resampled at uniform arc length
	var loop := resample_loop(control, spacing)
	points = loop.points
	length = loop.length
	count = points.size()
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
	water.clear()
	for spec in water_specs:
		water.append({"start": int(spec[0] * count) % count, "end": int(spec[1] * count) % count, "side": signi(spec[2])})
	ice.clear()
	for spec in ice_specs:
		ice.append({"start": int(spec[0] * count) % count, "end": int(spec[1] * count) % count})
	_build_rail()

## The ice stretch (dict) that road sample i lies in, or null.
func ice_at(i: int):
	var k := posmod(i, count)
	for s in ice:
		if k >= s.start and k <= s.end:
			return s
	return null

## True when pos is on the road beside sample idx (nearest sample) and that sample is iced over.
func on_ice(pos: Vector3, idx: int) -> bool:
	return ice_at(idx) != null and is_on_road(pos, idx)

## True when any of the n samples from i on (inclusive) is iced over: the AI slows for a bend it
## will take on ice before it gets there.
func ice_ahead(i: int, n: int) -> bool:
	for o in n + 1:
		if ice_at(i + o) != null:
			return true
	return false

## Railway (Mario Kart 64 Kalimari Desert): the rail loop is resampled like the road and every
## stretch where it runs over the road becomes a level crossing. A crossing records the road sample
## at its centre, the road samples whose walls are left open for the rails, and where along the rail
## (sample index and metres) the centreline is met.
func _build_rail() -> void:
	rail = PackedVector3Array()
	rail_length = 0.0
	crossings.clear()
	if rail_control.is_empty():
		return
	var loop := resample_loop(rail_control, spacing)
	rail = loop.points
	rail_length = loop.length
	var n := rail.size()
	var on_road: Array[bool] = []
	for i in n:
		on_road.append(is_on_road(rail[i]))
	# start scanning from a rail sample off the road so a run is never split at the wrap-around
	var first := 0
	while first < n and on_road[first]:
		first += 1
	if first >= n:
		return
	var i := 0
	while i < n:
		var k := (first + i) % n
		if not on_road[k]:
			i += 1
			continue
		var run: Array[int] = []
		while i < n and on_road[(first + i) % n]:
			run.append((first + i) % n)
			i += 1
		var centre: int = run[0]
		var best := INF
		for r in run:
			var d := distance_to_center(rail[r])
			if d < best:
				best = d
				centre = r
		var road_idx := nearest_index(rail[centre])
		var dir: Vector3 = (rail[(centre + 1) % n] - rail[(centre - 1 + n) % n]).normalized()
		crossings.append({
			"road": road_idx,
			"road_start": posmod(road_idx - CROSSING_HALF_GAP, count),
			"road_end": posmod(road_idx + CROSSING_HALF_GAP, count),
			"rail": centre,
			"s": rail_length * centre / n,
			"pos": rail[centre],
			"dir": dir,
		})

## The level crossing whose open stretch of wall contains road sample i, or null.
func crossing_at(i: int):
	var k := posmod(i, count)
	for c in crossings:
		if posmod(k - c.road_start, count) <= 2 * CROSSING_HALF_GAP:
			return c
	return null

## The water span (dict) that sample i lies in on `side` (+1 right / -1 left), or null.
func water_at(i: int, side: int):
	var k := posmod(i, count)
	for w in water:
		if w.side == side and k >= w.start and k <= w.end:
			return w
	return null

## True when the segment from sample i to i + 1 has a wall on `side`; false along a water span
## and on both sides where a railway crosses the road.
func has_wall(i: int, side: int) -> bool:
	return water_at(i, side) == null and crossing_at(i) == null

## True when pos lies in the water beside sample idx (nearest sample): past the road edge where the
## wall is missing, within the span's stretch.
func in_water(pos: Vector3, idx: int) -> bool:
	var k := posmod(idx, count)
	var lateral: float = (pos - points[k]).dot(right_of(k))
	var side := 1 if lateral > 0.0 else -1
	if water_at(k, side) == null:
		return false
	var edge := width * 0.5 + WATER_EDGE
	return absf(lateral) > edge and absf(lateral) < edge + WATER_WIDTH

## Where Lakitu drops a kart fished out beside sample idx: on the centerline, facing along the track.
func rescue_point(idx: int) -> Vector3:
	return points[posmod(idx, count)] + Vector3(0, 0.1, 0)

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
