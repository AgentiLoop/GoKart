extends RefCounted
## Mario Kart 64 battle arenas (pure geometry, unit tested). An arena is a flat square: optional
## striped outer walls, solid block obstacles (Block Fort's forts), an optional central pit
## (Big Donut's lava) and, without walls, open edges to fall off (Skyscraper). Item boxes and the
## four start pads are part of the layout. Falling in the pit / off the edge costs a balloon and
## Lakitu sets the kart back down beside where it fell.
## The read-only track-ish fields (points / tangents / count / spacing / nearest_index) let the
## item manager, the projectiles and Lakitu run unchanged on an arena.

const ARENAS := [
	{
		"name": "Big Donut",
		"blurb": "A ring of road around a lava pit - don't fall in",
		"half": 42.0,
		"walled": true,
		"pit": 14.0,
		"blocks": [],
		"sky_top": Color(0.35, 0.12, 0.1),
		"sky_horizon": Color(0.95, 0.45, 0.2),
		"ground": Color(0.42, 0.36, 0.3),
	},
	{
		"name": "Block Fort",
		"blurb": "Four forts to hide behind and shells bouncing everywhere",
		"half": 46.0,
		"walled": true,
		"pit": 0.0,
		"blocks": [Rect2(-30, -30, 16, 16), Rect2(14, -30, 16, 16), Rect2(-30, 14, 16, 16), Rect2(14, 14, 16, 16)],
		"sky_top": Color(0.12, 0.3, 0.7),
		"sky_horizon": Color(0.6, 0.8, 1.0),
		"ground": Color(0.3, 0.32, 0.36),
	},
	{
		"name": "Skyscraper",
		"blurb": "A rooftop with no railings - fall off and lose a balloon",
		"half": 32.0,
		"walled": false,
		"pit": 0.0,
		"blocks": [Rect2(-5, -5, 10, 10)],
		"sky_top": Color(0.1, 0.1, 0.3),
		"sky_horizon": Color(0.9, 0.6, 0.4),
		"ground": Color(0.5, 0.5, 0.55),
	},
]

const BOX_RING := 8          # item boxes around the arena (plus a box per block side on Block Fort)
const SPAWN_INSET := 10.0    # start pads this far inside the corners
const EDGE_FALL := 1.5       # metres past an open edge before the kart counts as fallen
const AVOID_MARGIN := 2.0    # how close to walls / blocks / the pit the AI is willing to go
const RESPAWN_GAP := 5.0     # set-down distance from the pit rim / the edge

static func arena_count() -> int:
	return ARENAS.size()

static func info(i: int) -> Dictionary:
	return ARENAS[posmod(i, ARENAS.size())]

static func step(current: int, dir: int) -> int:
	return posmod(current + dir, ARENAS.size())

static func make(i: int) -> Object:
	var a = load("res://scripts/arena_data.gd").new()
	a.build(info(i))
	return a

## Heading (yaw, forward = (-sin h, 0, -cos h)) that faces along `dir`.
static func heading_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

var arena := true            # tells the shared item / Lakitu code this is an arena, not a course
var name := ""
var half := 40.0             # half the side of the square
var walled := true
var pit_radius := 0.0        # > 0: lava pit of this radius in the centre
var blocks: Array = []       # Array[Rect2] in XZ (x = position.x, y = position.z)
var item_box_positions: Array = []
var hazard_positions: Array = []   # no pre-placed bananas in an arena
var spawns: Array = []       # [{position, heading}] x4
# track-compatible stand-ins: one sample at the centre with no direction
var points := PackedVector3Array([Vector3.ZERO])
var tangents := PackedVector3Array([Vector3.ZERO])
var count := 1
var spacing := 1.0
var width := 0.0

func build(spec: Dictionary) -> void:
	name = spec.name
	half = spec.half
	walled = spec.walled
	pit_radius = spec.pit
	blocks = spec.blocks.duplicate()
	width = half * 2.0
	# start pads: the four corners, facing the centre
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * (half - SPAWN_INSET), 0.1, sz * (half - SPAWN_INSET))
			spawns.append({"position": p, "heading": heading_for(-Vector3(p.x, 0, p.z).normalized())})
	# item boxes: a ring between the pit / centre block and the walls, nudged off any block
	var ring := (pit_radius + half) * 0.5 if pit_radius > 0.0 else half * 0.55
	for k in BOX_RING:
		var a := TAU * (k + 0.5) / BOX_RING
		var p := Vector3(cos(a) * ring, 0.0, sin(a) * ring)
		if not in_block(p, 2.0):
			item_box_positions.append(p)
	# one box at the middle of each block's outer sides, in the corridors
	for b in blocks:
		for p in [Vector3(b.position.x - 4.0, 0, b.get_center().y), Vector3(b.end.x + 4.0, 0, b.get_center().y),
				Vector3(b.get_center().x, 0, b.position.y - 4.0), Vector3(b.get_center().x, 0, b.end.y + 4.0)]:
			if absf(p.x) < half - 3.0 and absf(p.z) < half - 3.0 and not in_block(p, 1.0) and not in_pit(p):
				item_box_positions.append(p)

## Outline for the minimap / menu preview: the four corners.
func outline() -> PackedVector3Array:
	return PackedVector3Array([Vector3(-half, 0, -half), Vector3(half, 0, -half), Vector3(half, 0, half), Vector3(-half, 0, half)])

## Track-compatible stand-in: everything is "sample 0".
func nearest_index(_pos: Vector3, _hint := -1) -> int:
	return 0

func closest_point(_pos: Vector3, _hint := -1) -> Vector3:
	return Vector3.ZERO

func in_block(pos: Vector3, margin := 0.0) -> bool:
	for b in blocks:
		if b.grow(margin).has_point(Vector2(pos.x, pos.z)):
			return true
	return false

## Inside the lava pit / past an open edge: the kart has fallen.
func in_pit(pos: Vector3) -> bool:
	if pit_radius > 0.0 and Vector2(pos.x, pos.z).length() < pit_radius:
		return true
	if not walled and (absf(pos.x) > half + EDGE_FALL or absf(pos.z) > half + EDGE_FALL):
		return true
	return false

## Somewhere the AI should not drive: a wall, a block, the pit rim or the edge.
func obstacle_at(pos: Vector3, margin := AVOID_MARGIN) -> bool:
	if absf(pos.x) > half - margin or absf(pos.z) > half - margin:
		return true
	if pit_radius > 0.0 and Vector2(pos.x, pos.z).length() < pit_radius + margin:
		return true
	return in_block(pos, margin)

## Pushes a circle of `radius` at `pos` out of the walls and blocks. Returns {} when it is clear,
## else {"position": corrected position, "normal": outward surface normal}.
func collide_circle(pos: Vector3, radius: float) -> Dictionary:
	var p := pos
	var n := Vector3.ZERO
	if walled:
		var lim := half - radius
		if p.x > lim:
			p.x = lim
			n = Vector3(-1, 0, 0)
		elif p.x < -lim:
			p.x = -lim
			n = Vector3(1, 0, 0)
		if p.z > lim:
			p.z = lim
			n = Vector3(0, 0, -1)
		elif p.z < -lim:
			p.z = -lim
			n = Vector3(0, 0, 1)
	for b in blocks:
		var r: Rect2 = b.grow(radius)
		if not r.has_point(Vector2(p.x, p.z)):
			continue
		# leave through the nearest face
		var dl := p.x - r.position.x
		var dr := r.end.x - p.x
		var dt := p.z - r.position.y
		var db := r.end.y - p.z
		var m := minf(minf(dl, dr), minf(dt, db))
		if m == dl:
			p.x = r.position.x
			n = Vector3(-1, 0, 0)
		elif m == dr:
			p.x = r.end.x
			n = Vector3(1, 0, 0)
		elif m == dt:
			p.z = r.position.y
			n = Vector3(0, 0, -1)
		else:
			p.z = r.end.y
			n = Vector3(0, 0, 1)
	if n == Vector3.ZERO:
		return {}
	return {"position": p, "normal": n}

## Where Lakitu sets a fallen kart down: just outside the pit rim on the side it fell in, or
## just inside the edge it drove off.
func respawn_point(pos: Vector3) -> Vector3:
	var flat := Vector2(pos.x, pos.z)
	if pit_radius > 0.0 and flat.length() < pit_radius:
		var dir := flat.normalized() if flat.length() > 0.01 else Vector2(1, 0)
		var out := dir * (pit_radius + RESPAWN_GAP)
		return Vector3(out.x, 0.1, out.y)
	var lim := half - RESPAWN_GAP
	return Vector3(clampf(pos.x, -lim, lim), 0.1, clampf(pos.z, -lim, lim))

## Facing for a set-down kart: away from the pit, or back towards the centre from an edge.
func respawn_heading(pos: Vector3) -> float:
	var flat := Vector3(pos.x, 0, pos.z)
	if pit_radius > 0.0 and Vector2(pos.x, pos.z).length() < pit_radius:
		return heading_for(flat.normalized() if flat.length() > 0.01 else Vector3(1, 0, 0))
	return heading_for(-flat.normalized() if flat.length() > 0.01 else Vector3(0, 0, -1))
