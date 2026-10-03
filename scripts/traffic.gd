extends RefCounted
## Mario Kart 64 Toad's Turnpike traffic (pure model, no scene nodes, unit tested): cars, buses,
## box trucks and tankers drive round the course in two lanes — the same way as the racers, or
## against them in the Extra class like MK64's mirror mode — slowly in 50cc and fast in 150cc.
## A kart that touches a vehicle is thrown into the air (a Star drives straight through), items fly
## through the traffic, and CPU karts steer round the vehicles ahead of them.

const SPEED_150 := 13.0            # m/s at 150cc (and in Extra); scaled by the engine class speed factor
const SLOW_LANE := 0.75            # vehicles in their own right-hand lane cruise at this fraction of it
const LOOK_AHEAD := 50.0           # m of road an AI kart looks ahead for vehicles to steer round
const LOOK_AHEAD_ONCOMING := 75.0  # ... when the traffic comes towards it (Extra)
const DODGE_MARGIN := 1.8          # m of clearance an AI kart keeps from a vehicle's side
const EDGE_MARGIN := 1.6           # an AI kart will not dodge closer than this to the road edge
const LAUNCH_SPEED := 10.0         # upward m/s a struck kart is thrown with
const SHOVE := 8.0                 # m/s a struck kart is shoved along the vehicle's direction

## Vehicle kinds (MK64: white cars, yellow buses, red box trucks and cyan tankers).
const KINDS := {
	"car": {"length": 4.2, "half_width": 1.0, "height": 1.5},
	"bus": {"length": 9.0, "half_width": 1.3, "height": 3.0},
	"truck": {"length": 8.0, "half_width": 1.3, "height": 3.2},
	"tanker": {"length": 9.0, "half_width": 1.3, "height": 2.8},
}

var track                 # TrackData (its traffic_specs may be empty: no traffic on this course)
var dir := 1              # +1 drives with the racers, -1 against them (mirrored course / Extra)
var speed := SPEED_150    # fast-lane speed for this engine class
## {kind, lane (m right of the centreline), s (metres along the road), length, half_width, height, speed}
var vehicles: Array = []
var time := 0.0

## engine_speed: the engine class speed factor (MK64: traffic crawls in 50cc, races in 150cc).
func _init(track_data, engine_speed := 1.0) -> void:
	track = track_data
	if track == null:
		return
	dir = -1 if track.mirrored else 1
	speed = SPEED_150 * engine_speed
	for spec in track.traffic_specs:
		var k: Dictionary = KINDS[spec[2]]
		var lane: float = spec[1]
		vehicles.append({
			"kind": spec[2],
			"lane": lane,
			"s": fposmod(spec[0] * track.length, track.length),
			"length": k.length,
			"half_width": k.half_width,
			"height": k.height,
			# the lane on the vehicle's own right is the slow lane
			"speed": speed * (SLOW_LANE if lane * dir > 0.0 else 1.0),
		})

func active() -> bool:
	return not vehicles.is_empty()

func step(delta: float) -> void:
	time += delta
	for v in vehicles:
		v.s = fposmod(v.s + v.speed * dir * delta, track.length)

## Pose on the road `s` metres past the line and `lateral` metres right of the centreline:
## {"pos": Vector3, "dir": unit direction the traffic travels in there}.
func road_pose(s: float, lateral: float) -> Dictionary:
	var per: float = track.length / track.count
	var f: float = fposmod(s, track.length) / per
	var i: int = int(floor(f)) % track.count
	var j: int = (i + 1) % track.count
	var t: float = f - floor(f)
	var a: Vector3 = track.points[i] + track.right_of(i) * lateral
	var b: Vector3 = track.points[j] + track.right_of(j) * lateral
	var fwd: Vector3 = track.tangents[i].lerp(track.tangents[j], t).normalized()
	return {"pos": a.lerp(b, t), "dir": fwd * dir}

func vehicle_pose(i: int) -> Dictionary:
	return road_pose(vehicles[i].s, vehicles[i].lane)

## Direction of travel of the vehicle `pos` is inside (XZ box), ZERO when clear of them all.
func hit_dir(pos: Vector3) -> Vector3:
	for i in vehicles.size():
		var v: Dictionary = vehicles[i]
		var p := vehicle_pose(i)
		var rel: Vector3 = pos - p.pos
		var along := rel.dot(p.dir)
		var across := rel.dot(Vector3(-p.dir.z, 0, p.dir.x))
		if absf(along) <= v.length * 0.5 and absf(across) <= v.half_width:
			return p.dir
	return Vector3.ZERO

## Metres along the road from `s_from` to the centre of vehicle v, in the racers' direction
## (positive = ahead of a kart there), in (-length / 2, length / 2].
func ahead_of(v: Dictionary, s_from: float) -> float:
	var L: float = track.length
	return fposmod(v.s - s_from + L * 0.5, L) - L * 0.5

## Lateral offset an AI kart at road sample idx should aim for to clear the traffic ahead of it:
## its own `lane` when that is free; otherwise `current` (what it is aiming for now) if that is still
## free, so a dodge is not changed halfway; otherwise the nearest free spot on the road to `current`
## (the gap between the lanes, the other lane, the edge of a vehicle) — or `lane` when nothing is free.
func clear_lane(idx: int, lane: float, current: float = NAN) -> float:
	var s_k: float = track.length * posmod(idx, track.count) / track.count
	var look := LOOK_AHEAD if dir > 0 else LOOK_AHEAD_ONCOMING
	var blocked: Array = []
	for v in vehicles:
		var rel := ahead_of(v, s_k)
		if rel + v.length * 0.5 > -1.0 and rel - v.length * 0.5 < look:
			blocked.append([v.lane - v.half_width - DODGE_MARGIN, v.lane + v.half_width + DODGE_MARGIN])
	if not _in_any(lane, blocked):
		return lane
	var limit: float = track.width * 0.5 - EDGE_MARGIN
	var from := lane if is_nan(current) else current
	if not _in_any(from, blocked) and absf(from) <= limit:
		return from
	var candidates: Array = [0.0]
	for b in blocked:
		candidates.append(b[0])
		candidates.append(b[1])
	var best := lane
	var best_d := INF
	for c in candidates:
		if absf(c) > limit or _in_any(c, blocked):
			continue
		if absf(c - from) < best_d:
			best_d = absf(c - from)
			best = c
	return best

## True when x lies strictly inside one of the [lo, hi] spans (the edges themselves are free).
static func _in_any(x: float, spans: Array) -> bool:
	for s in spans:
		if x > s[0] and x < s[1]:
			return true
	return false
