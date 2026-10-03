extends RefCounted
## Mario Kart 64 Moo Moo Farm Monty Moles (pure model, no scene nodes, unit tested): moles hop in
## and out of holes in the road in a staggered rhythm. A kart that runs into a mole that is out is
## thrown into the air and spins out (a Star drives straight through and bowls the mole over); a
## green or red shell knocks a mole away, and a knocked mole stays down for a while. CPU karts steer
## round the holes ahead of them.

const CYCLE := 3.2          # s from one pop to the next for a hole
const RISE_TIME := 0.25     # s a mole takes to come up (and to go down again)
const UP_TIME := 1.4        # s a mole stays out
const HIT_HEIGHT := 0.35    # a mole this far out (fraction of its full height) can be hit
const HIT_RADIUS := 1.1     # m (XZ) round the hole where a mole that is out strikes a kart
const KNOCK_TIME := 6.0     # s a mole hit by a shell or a Star kart stays underground
const PHASE_STEP := 1.1     # s between the pops of neighbouring holes (staggers a group)
const LOOK_AHEAD := 40.0    # m of road an AI kart looks ahead for holes to steer round
const DODGE_MARGIN := 1.6   # m of clearance an AI kart keeps from a mole's strike radius
const EDGE_MARGIN := 1.6    # an AI kart will not dodge closer than this to the road edge
const LAUNCH_SPEED := 7.0   # upward m/s a struck kart is thrown with
const SHOVE := 5.0          # m/s a struck kart is shoved away from the mole

var track                   # TrackData (its mole_specs may be empty: no moles on this course)
## {pos (hole centre, y 0), idx (road sample), lateral (m right of the centreline), s (metres along
## the road), phase (s offset into the cycle), knocked (s left underground after a hit)}
var moles: Array = []
var time := 0.0
var knocks := 0             # moles knocked away so far (for checks/tests)

func _init(track_data) -> void:
	track = track_data
	if track == null:
		return
	for i in track.mole_specs.size():
		var spec: Array = track.mole_specs[i]
		var idx: int = int(spec[0] * track.count) % track.count
		moles.append({
			"pos": track.points[idx] + track.right_of(idx) * spec[1],
			"idx": idx,
			"lateral": spec[1],
			"s": track.length * idx / track.count,
			"phase": fposmod(i * PHASE_STEP, CYCLE),
			"knocked": 0.0,
		})

func active() -> bool:
	return not moles.is_empty()

func step(delta: float) -> void:
	time += delta
	for m in moles:
		m.knocked = maxf(m.knocked - delta, 0.0)

## How far mole i is out of its hole: 0 = underground, 1 = fully out.
func height(i: int) -> float:
	var m: Dictionary = moles[i]
	if m.knocked > 0.0:
		return 0.0
	var t: float = fposmod(time + m.phase, CYCLE)
	if t < RISE_TIME:
		return t / RISE_TIME
	if t < RISE_TIME + UP_TIME:
		return 1.0
	if t < 2.0 * RISE_TIME + UP_TIME:
		return 1.0 - (t - RISE_TIME - UP_TIME) / RISE_TIME
	return 0.0

## True when mole i is far enough out of its hole to be hit (or to hit a kart).
func is_up(i: int) -> bool:
	return height(i) >= HIT_HEIGHT

## Seconds the model has to advance so that mole i is fully out (for tools and tests).
func time_until_up(i: int) -> float:
	var m: Dictionary = moles[i]
	var t: float = fposmod(time + m.phase, CYCLE)
	return fposmod(RISE_TIME - t, CYCLE) + m.knocked

## Index of the mole that is out and within `radius` (XZ) of pos, or -1 when clear of them all.
func mole_at(pos: Vector3, radius := HIT_RADIUS) -> int:
	for i in moles.size():
		if not is_up(i):
			continue
		var d: Vector3 = pos - moles[i].pos
		if Vector2(d.x, d.z).length() <= radius:
			return i
	return -1

## Direction a kart at pos is shoved when it hits mole i: away from the hole (along the road when
## it sits right on top of it).
func shove_dir(i: int, pos: Vector3) -> Vector3:
	var d: Vector3 = pos - moles[i].pos
	d.y = 0.0
	if d.length() < 0.05:
		return track.tangents[moles[i].idx]
	return d.normalized()

## A shell or a Star kart hit mole i: it is knocked away and stays underground for KNOCK_TIME.
func knock(i: int) -> void:
	moles[i].knocked = KNOCK_TIME
	knocks += 1

## Knocks away the mole that is out within `radius` of pos (a shell flying over a hole); returns its
## index, or -1 when there was none.
func knock_at(pos: Vector3, radius := HIT_RADIUS) -> int:
	var i := mole_at(pos, radius)
	if i >= 0:
		knock(i)
	return i

## Metres along the road from `s_from` to mole m, in the racers' direction (positive = ahead of a
## kart there), in (-length / 2, length / 2].
func ahead_of(m: Dictionary, s_from: float) -> float:
	var L: float = track.length
	return fposmod(m.s - s_from + L * 0.5, L) - L * 0.5

## Lateral offset an AI kart at road sample idx should aim for to clear the holes ahead of it (a mole
## may pop out of any of them as it arrives): its own `lane` when that is free; otherwise `current`
## (what it is aiming for now) if that is still free, so a dodge is not changed halfway; otherwise
## the nearest free spot on the road to `current` — or `lane` when nothing is free.
func clear_lane(idx: int, lane: float, current: float = NAN) -> float:
	var s_k: float = track.length * posmod(idx, track.count) / track.count
	var blocked: Array = []
	for m in moles:
		var rel := ahead_of(m, s_k)
		if rel > -HIT_RADIUS and rel < LOOK_AHEAD:
			blocked.append([m.lateral - HIT_RADIUS - DODGE_MARGIN, m.lateral + HIT_RADIUS + DODGE_MARGIN])
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
