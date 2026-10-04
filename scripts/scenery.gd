extends RefCounted
## Mario Kart 64 style roadside scenery (pure, no scene nodes): where the props of a course stand
## and what they are built from. MK64's courses are dressed to their theme — Moo Moo Farm has trees,
## cows and barns beside the road, Toad's Turnpike runs between buildings under street lamps and
## billboards, Frappe Snowland has fir trees, igloos and snowy mountains, Kalimari Desert cacti,
## rocks and mesas. A course picks a set (layout "scenery"); every set is a list of rules, each
## scattering one kind of prop along the road at a stride of samples, a random distance beyond the
## wall and a random size. Props keep off the road (also where the course folds back on itself), out
## of the water, off the railway and apart from each other. The layout is deterministic (seeded by
## the set) and a mirrored course gets the exact mirror image. SceneryProps renders it.

const TrackData := preload("res://scripts/track_data.gd")

## Outer face of the wall beyond the road edge (Track.wall_offset + half its thickness).
const WALL := 3.1
## Clearance between the wall's outer face and the nearest edge of a prop.
const WALL_GAP := 0.6
## Clearance between the edges of two props.
const PROP_GAP := 0.6
## Samples on each side of a near prop that must have their wall (so nothing stands on the bank of
## the water or in the gap the rails pass through).
const WALL_SPAN := 4
## Props further out than this from the road edge are past the water (WATER_EDGE + WATER_WIDTH)
## and need no wall beside them.
const FAR := 22.0
## Clearance between a prop and the rails.
const RAIL_GAP := 3.0
## Random shift along the road, in metres, so props are not lined up like fence posts.
const ALONG_JITTER := 1.5

## A rule: kind, every (sample stride), sides ([-1], [1] or both), near / far (m beyond the wall's
## face), size (min / max uniform scale), optional tall (min / max extra vertical scale) and
## face ("road" = turned to the road, "along" = looking down the road, "any" = random); "overlap":
## true lets props of this kind run into each other (a mountain range, a line of mesas).
const SETS := {
	"farm": [
		{"kind": "tree", "every": 3, "sides": [-1, 1], "near": 1.5, "far": 10.0, "size": [0.8, 1.3], "face": "any"},
		{"kind": "cow", "every": 17, "sides": [-1, 1], "near": 2.5, "far": 9.0, "size": [0.9, 1.1], "face": "any"},
		{"kind": "barn", "every": 53, "sides": [1, -1], "near": 24.0, "far": 36.0, "size": [0.9, 1.1], "face": "along"},
	],
	"highway": [
		{"kind": "building", "every": 4, "sides": [-1, 1], "near": 6.0, "far": 22.0, "size": [0.8, 1.3], "tall": [0.6, 2.6], "face": "along"},
		{"kind": "lamp", "every": 6, "sides": [-1, 1], "near": 0.3, "far": 0.6, "size": [1.0, 1.0], "face": "road"},
		{"kind": "billboard", "every": 37, "sides": [1, -1], "near": 3.0, "far": 5.0, "size": [1.0, 1.0], "face": "along"},
	],
	"snow": [
		{"kind": "fir", "every": 3, "sides": [-1, 1], "near": 1.0, "far": 14.0, "size": [0.7, 1.4], "face": "any"},
		{"kind": "igloo", "every": 41, "sides": [-1, 1], "near": 4.0, "far": 9.0, "size": [0.9, 1.2], "face": "road"},
		{"kind": "mountain", "every": 11, "sides": [-1, 1], "near": 30.0, "far": 70.0, "size": [0.5, 1.1], "face": "any", "overlap": true},
	],
	"desert": [
		{"kind": "cactus", "every": 3, "sides": [-1, 1], "near": 1.0, "far": 12.0, "size": [0.7, 1.3], "face": "any"},
		{"kind": "rock", "every": 5, "sides": [-1, 1], "near": 0.8, "far": 10.0, "size": [0.5, 1.4], "face": "any"},
		{"kind": "mesa", "every": 13, "sides": [-1, 1], "near": 45.0, "far": 95.0, "size": [0.7, 1.4], "face": "any", "overlap": true},
	],
}

## Footprint radius (m, unit scale) of every kind: the room a prop needs on the ground.
const RADIUS := {
	"tree": 1.7, "cow": 1.0, "barn": 5.5,
	"building": 5.8, "lamp": 0.4, "billboard": 3.2,
	"fir": 1.5, "igloo": 2.4, "mountain": 42.0,
	"cactus": 1.0, "rock": 1.0, "mesa": 19.0,
}

## The set names, in a fixed order (for tests and tools).
static func set_names() -> Array:
	return ["farm", "highway", "snow", "desert"]

## True when `name` is a known scenery set.
static func has_set(name: String) -> bool:
	return SETS.has(name)

## The props of a course: [{kind, pos, yaw, scale (Vector3), radius, idx, side}] for the set the
## track data names (empty when it names none).
static func props(data: TrackData) -> Array:
	if data == null or not SETS.has(data.scenery):
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(data.scenery)
	var out: Array = []
	var edge: float = data.width * 0.5 + WALL
	for rule in SETS[data.scenery]:
		var every: int = rule.every
		var sides: Array = rule.sides
		var k := 0
		for i in range(every / 2, data.count, every):
			# a mirrored course's right is the mirror image of the plain course's left: flip the side so
			# the same draws land every prop on its mirror-image spot
			var side: int = sides[k % sides.size()] * (-1 if data.mirrored else 1)
			k += 1
			# draw first, so a skipped spot never shifts the rest of the layout
			var out_dist: float = rng.randf_range(rule.near, rule.far)
			var along: float = rng.randf_range(-ALONG_JITTER, ALONG_JITTER)
			var size: float = rng.randf_range(rule.size[0], rule.size[1])
			var tall: float = rng.randf_range(rule.tall[0], rule.tall[1]) if rule.has("tall") else 1.0
			var spin: float = rng.randf_range(0.0, TAU)
			var radius: float = RADIUS[rule.kind] * size
			var dist: float = edge + WALL_GAP + radius + out_dist
			var pos: Vector3 = data.points[i] + data.right_of(i) * (side * dist) + data.tangents[i] * along
			if not fits(data, pos, radius, i, side, out, rule.kind if rule.get("overlap", false) else ""):
				continue
			var yaw: float = data.heading_at(i)
			if rule.face == "road":
				var to_road: Vector3 = data.right_of(i) * float(-side)
				yaw = atan2(to_road.x, to_road.z)
			elif rule.face == "any":
				yaw = spin
			out.append({
				"kind": rule.kind, "pos": pos, "yaw": yaw, "scale": Vector3(size, size * tall, size),
				"radius": radius, "idx": i, "side": side,
			})
	return out

## Whether a prop of `radius` at pos (beside sample i on `side`) stands clear: off every part of the
## road (plus the wall and a gap), out of the water, with a wall between it and the road when it is
## near, clear of the rails and of the props already placed (except those of `overlap_kind`, which
## may run into each other).
static func fits(data: TrackData, pos: Vector3, radius: float, i: int, side: int, placed: Array, overlap_kind := "") -> bool:
	var edge: float = data.width * 0.5 + WALL
	if data.distance_to_center(pos) < edge + WALL_GAP + radius - 0.01:
		return false
	var nearest := data.nearest_index(pos)
	if data.in_water(pos, nearest):
		return false
	var lateral: float = absf((pos - data.points[i]).dot(data.right_of(i)))
	if lateral - radius < edge + FAR:
		for o in range(-WALL_SPAN, WALL_SPAN + 1):
			if not data.has_wall(i + o, side):
				return false
	if not data.rail.is_empty():
		for r in data.rail:
			if Vector2(r.x - pos.x, r.z - pos.z).length() < radius + RAIL_GAP:
				return false
	for p in placed:
		if p.kind == overlap_kind:
			continue
		if Vector2(p.pos.x - pos.x, p.pos.z - pos.z).length() < radius + p.radius + PROP_GAP:
			return false
	return true

## How a kind is built: parts in unit scale, {shape ("box" / "sphere" / "cylinder" / "cone"), size
## (box: extents; sphere: x = radius; cylinder / cone: x = bottom radius, y = height), at (centre
## offset) and color}. The prop's +z looks the way its yaw says (a cow's head is at +z).
static func parts(kind: String) -> Array:
	var bark := Color(0.42, 0.27, 0.13)
	var leaf := Color(0.2, 0.55, 0.22)
	var snow := Color(0.95, 0.96, 1.0)
	var cactus := Color(0.22, 0.52, 0.26)
	var rock := Color(0.72, 0.42, 0.26)
	match kind:
		"tree":
			return [
				{"shape": "cylinder", "size": Vector3(0.28, 1.8, 0.28), "at": Vector3(0, 0.9, 0), "color": bark},
				{"shape": "sphere", "size": Vector3(1.7, 1.7, 1.7), "at": Vector3(0, 2.9, 0), "color": leaf},
				{"shape": "sphere", "size": Vector3(1.1, 1.1, 1.1), "at": Vector3(0.6, 3.7, 0.4), "color": Color(0.26, 0.62, 0.26)},
			]
		"cow":
			var hide := Color(0.96, 0.95, 0.9)
			var patch := Color(0.1, 0.09, 0.09)
			return [
				{"shape": "box", "size": Vector3(0.8, 0.9, 1.6), "at": Vector3(0, 0.95, 0), "color": hide},
				{"shape": "box", "size": Vector3(0.82, 0.5, 0.7), "at": Vector3(0, 1.1, -0.2), "color": patch},
				{"shape": "box", "size": Vector3(0.5, 0.5, 0.55), "at": Vector3(0, 1.25, 0.95), "color": hide},
				{"shape": "box", "size": Vector3(0.4, 0.22, 0.2), "at": Vector3(0, 1.05, 1.15), "color": Color(0.95, 0.7, 0.72)},
				{"shape": "cylinder", "size": Vector3(0.09, 0.5, 0.09), "at": Vector3(0.28, 0.25, 0.55), "color": patch},
				{"shape": "cylinder", "size": Vector3(0.09, 0.5, 0.09), "at": Vector3(-0.28, 0.25, 0.55), "color": patch},
				{"shape": "cylinder", "size": Vector3(0.09, 0.5, 0.09), "at": Vector3(0.28, 0.25, -0.55), "color": patch},
				{"shape": "cylinder", "size": Vector3(0.09, 0.5, 0.09), "at": Vector3(-0.28, 0.25, -0.55), "color": patch},
			]
		"barn":
			var red := Color(0.7, 0.12, 0.1)
			return [
				{"shape": "box", "size": Vector3(8.0, 5.0, 10.0), "at": Vector3(0, 2.5, 0), "color": red},
				{"shape": "box", "size": Vector3(8.8, 0.4, 10.8), "at": Vector3(0, 5.2, 0), "color": Color(0.35, 0.35, 0.38)},
				{"shape": "box", "size": Vector3(5.6, 2.0, 10.0), "at": Vector3(0, 6.4, 0), "color": red},
				{"shape": "box", "size": Vector3(2.4, 2.4, 10.4), "at": Vector3(0, 7.6, 0), "color": Color(0.35, 0.35, 0.38)},
				{"shape": "box", "size": Vector3(3.0, 3.4, 0.2), "at": Vector3(0, 1.7, 5.0), "color": Color(0.95, 0.95, 0.92)},
			]
		"building":
			return [
				{"shape": "box", "size": Vector3(9.0, 10.0, 9.0), "at": Vector3(0, 5.0, 0), "color": Color(0.5, 0.52, 0.6)},
				{"shape": "box", "size": Vector3(9.2, 0.6, 9.2), "at": Vector3(0, 10.0, 0), "color": Color(0.28, 0.28, 0.32)},
				{"shape": "box", "size": Vector3(9.3, 8.0, 7.0), "at": Vector3(0, 5.0, 0), "color": Color(0.95, 0.85, 0.5)},
				{"shape": "box", "size": Vector3(7.0, 8.0, 9.3), "at": Vector3(0, 5.0, 0), "color": Color(0.95, 0.85, 0.5)},
			]
		"lamp":
			return [
				{"shape": "cylinder", "size": Vector3(0.09, 5.2, 0.09), "at": Vector3(0, 2.6, 0), "color": Color(0.3, 0.32, 0.36)},
				{"shape": "box", "size": Vector3(0.1, 0.1, 1.8), "at": Vector3(0, 5.15, 0.9), "color": Color(0.3, 0.32, 0.36)},
				{"shape": "box", "size": Vector3(0.36, 0.2, 0.6), "at": Vector3(0, 5.0, 1.6), "color": Color(1.0, 0.95, 0.75)},
			]
		"billboard":
			var post := Color(0.3, 0.32, 0.36)
			return [
				{"shape": "cylinder", "size": Vector3(0.15, 4.0, 0.15), "at": Vector3(-2.4, 2.0, 0), "color": post},
				{"shape": "cylinder", "size": Vector3(0.15, 4.0, 0.15), "at": Vector3(2.4, 2.0, 0), "color": post},
				{"shape": "box", "size": Vector3(6.4, 3.2, 0.25), "at": Vector3(0, 5.4, 0), "color": Color(1.0, 0.85, 0.15)},
				{"shape": "box", "size": Vector3(4.4, 1.2, 0.3), "at": Vector3(0, 5.6, 0), "color": Color(0.85, 0.05, 0.05)},
			]
		"fir":
			var needles := Color(0.1, 0.4, 0.22)
			return [
				{"shape": "cylinder", "size": Vector3(0.22, 1.2, 0.22), "at": Vector3(0, 0.6, 0), "color": bark},
				{"shape": "cone", "size": Vector3(1.5, 2.4, 1.5), "at": Vector3(0, 2.2, 0), "color": needles},
				{"shape": "cone", "size": Vector3(1.15, 2.2, 1.15), "at": Vector3(0, 3.5, 0), "color": needles},
				{"shape": "cone", "size": Vector3(0.8, 2.0, 0.8), "at": Vector3(0, 4.8, 0), "color": needles},
				{"shape": "cone", "size": Vector3(0.45, 0.9, 0.45), "at": Vector3(0, 5.9, 0), "color": snow},
			]
		"igloo":
			return [
				{"shape": "sphere", "size": Vector3(2.3, 2.3, 2.3), "at": Vector3(0, 0.2, 0), "color": snow},
				{"shape": "box", "size": Vector3(1.5, 1.2, 1.8), "at": Vector3(0, 0.6, 2.0), "color": snow},
				{"shape": "box", "size": Vector3(0.9, 0.8, 0.3), "at": Vector3(0, 0.4, 2.8), "color": Color(0.2, 0.25, 0.4)},
			]
		"mountain":
			return [
				{"shape": "cone", "size": Vector3(42.0, 60.0, 42.0), "at": Vector3(0, 30.0, 0), "color": Color(0.55, 0.6, 0.7)},
				{"shape": "cone", "size": Vector3(16.0, 24.0, 16.0), "at": Vector3(0, 48.0, 0), "color": snow},
			]
		"cactus":
			return [
				{"shape": "cylinder", "size": Vector3(0.38, 3.2, 0.38), "at": Vector3(0, 1.6, 0), "color": cactus},
				{"shape": "box", "size": Vector3(1.1, 0.5, 0.5), "at": Vector3(0.65, 1.5, 0), "color": cactus},
				{"shape": "box", "size": Vector3(0.5, 1.5, 0.5), "at": Vector3(0.95, 2.15, 0), "color": cactus},
				{"shape": "box", "size": Vector3(1.0, 0.5, 0.5), "at": Vector3(-0.6, 1.0, 0), "color": cactus},
				{"shape": "box", "size": Vector3(0.5, 1.2, 0.5), "at": Vector3(-0.85, 1.5, 0), "color": cactus},
			]
		"rock":
			return [
				{"shape": "sphere", "size": Vector3(1.0, 1.0, 1.0), "at": Vector3(0, 0.15, 0), "color": rock},
				{"shape": "sphere", "size": Vector3(0.6, 0.6, 0.6), "at": Vector3(0.7, 0.05, 0.3), "color": Color(0.62, 0.36, 0.22)},
			]
		"mesa":
			return [
				{"shape": "box", "size": Vector3(32.0, 16.0, 24.0), "at": Vector3(0, 8.0, 0), "color": rock},
				{"shape": "box", "size": Vector3(26.0, 5.0, 19.0), "at": Vector3(0, 18.5, 0), "color": Color(0.8, 0.5, 0.3)},
				{"shape": "box", "size": Vector3(14.0, 3.0, 10.0), "at": Vector3(2.0, 22.5, -1.0), "color": Color(0.86, 0.58, 0.36)},
			]
	return []

## Every kind any set uses, each once.
static func kinds() -> Array:
	var out: Array = []
	for name in set_names():
		for rule in SETS[name]:
			if not out.has(rule.kind):
				out.append(rule.kind)
	return out
