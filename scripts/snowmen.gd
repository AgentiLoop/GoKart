extends RefCounted
## Mario Kart 64 Frappe Snowland snowmen (pure model, no scene nodes, unit tested): snowmen stand
## about the road in rows. A kart that runs into one is thrown into the air and spins out, and the
## snowman bursts into a puff of snow (a Star drives straight through and bursts it); a green or red
## shell smashes a snowman too. A smashed snowman grows back out of the snow a few seconds later.
## CPU karts weave through the rows ahead of them.

const HIT_RADIUS := 1.2     # m (XZ) round a standing snowman that strikes a kart
const STAND_HEIGHT := 0.6   # a snowman grown back this far (fraction of its full height) can be hit
const REBUILD_TIME := 5.0   # s a smashed snowman stays down before it is whole again
const GROW_TIME := 0.8      # s at the end of REBUILD_TIME it spends growing back
const LOOK_AHEAD := 40.0    # m of road an AI kart looks ahead for snowmen to steer round
const ROW_DEPTH := 6.0      # m along the road: snowmen this close behind the nearest one form its row
const DODGE_MARGIN := 1.6   # m of clearance an AI kart keeps from a snowman's strike radius
const EDGE_MARGIN := 1.6    # an AI kart will not dodge closer than this to the road edge
const LATER_WEIGHT := 1.1   # lateral moves between the rows behind count this much more than a move now
const LAUNCH_SPEED := 8.0   # upward m/s a struck kart is thrown with
const SHOVE := 6.0          # m/s a struck kart is shoved away from the snowman

var track                   # TrackData (its snowman_specs may be empty: no snowmen on this course)
## {pos (y 0), idx (road sample), lateral (m right of the centreline), s (metres along the road),
## down (s left before the snowman is whole again after a smash; 0 = standing)}
var snowmen: Array = []
var smashes := 0            # snowmen smashed so far (for checks/tests)

func _init(track_data) -> void:
	track = track_data
	if track == null:
		return
	for spec in track.snowman_specs:
		var idx: int = int(spec[0] * track.count) % track.count
		snowmen.append({
			"pos": track.points[idx] + track.right_of(idx) * spec[1],
			"idx": idx,
			"lateral": spec[1],
			"s": track.length * idx / track.count,
			"down": 0.0,
		})

func active() -> bool:
	return not snowmen.is_empty()

func step(delta: float) -> void:
	for sm in snowmen:
		sm.down = maxf(sm.down - delta, 0.0)

## How much of snowman i stands: 1 = whole, 0 = smashed flat, in between while growing back.
func height(i: int) -> float:
	var down: float = snowmen[i].down
	if down <= 0.0:
		return 1.0
	if down >= GROW_TIME:
		return 0.0
	return 1.0 - down / GROW_TIME

## True when snowman i stands far enough to be hit (or to hit a kart).
func is_standing(i: int) -> bool:
	return height(i) >= STAND_HEIGHT

## Index of the standing snowman within `radius` (XZ) of pos, or -1 when clear of them all.
func snowman_at(pos: Vector3, radius := HIT_RADIUS) -> int:
	for i in snowmen.size():
		if not is_standing(i):
			continue
		var d: Vector3 = pos - snowmen[i].pos
		if Vector2(d.x, d.z).length() <= radius:
			return i
	return -1

## Direction a kart at pos is shoved when it hits snowman i: away from it (along the road when it
## sits right on top of it).
func shove_dir(i: int, pos: Vector3) -> Vector3:
	var d: Vector3 = pos - snowmen[i].pos
	d.y = 0.0
	if d.length() < 0.05:
		return track.tangents[snowmen[i].idx]
	return d.normalized()

## A kart, a shell or a Star hit snowman i: it bursts and stays down for REBUILD_TIME.
func smash(i: int) -> void:
	snowmen[i].down = REBUILD_TIME
	smashes += 1

## Smashes the standing snowman within `radius` of pos (a shell flying into it); returns its index,
## or -1 when there was none.
func smash_at(pos: Vector3, radius := HIT_RADIUS) -> int:
	var i := snowman_at(pos, radius)
	if i >= 0:
		smash(i)
	return i

## Metres along the road from `s_from` to snowman sm, in the racers' direction (positive = ahead of a
## kart there), in (-length / 2, length / 2].
func ahead_of(sm: Dictionary, s_from: float) -> float:
	var L: float = track.length
	return fposmod(sm.s - s_from + L * 0.5, L) - L * 0.5

## The snowmen alongside or ahead of road position s_k within LOOK_AHEAD, grouped into rows (every
## snowman within ROW_DEPTH of the first of its row), nearest row first; each row is the list of
## free lateral spans [lo, hi] a kart can pass through (clear of every snowman in the row by
## HIT_RADIUS + DODGE_MARGIN and inside the road edges by EDGE_MARGIN). A smashed snowman grows back
## by the time the kart arrives, so every snowman counts.
func rows_ahead(s_k: float) -> Array:
	var ahead: Array = []   # [rel, lateral]
	for sm in snowmen:
		var rel := ahead_of(sm, s_k)
		if rel > -HIT_RADIUS and rel < LOOK_AHEAD:
			ahead.append([rel, sm.lateral])
	ahead.sort_custom(func(a, b): return a[0] < b[0])
	var rows: Array = []
	var row_start := -INF
	var laterals: Array = []
	for a in ahead:
		if a[0] > row_start + ROW_DEPTH:
			if not laterals.is_empty():
				rows.append(_free_spans(laterals))
			laterals = []
			row_start = a[0]
		laterals.append(a[1])
	if not laterals.is_empty():
		rows.append(_free_spans(laterals))
	return rows

## Free lateral spans of a row of snowmen at `laterals`, inside the road edges.
func _free_spans(laterals: Array) -> Array:
	var limit: float = track.width * 0.5 - EDGE_MARGIN
	var sorted := laterals.duplicate()
	sorted.sort()
	var spans: Array = []
	var lo := -limit
	for x in sorted:
		var hi: float = x - HIT_RADIUS - DODGE_MARGIN
		if hi >= lo:
			spans.append([lo, hi])
		lo = maxf(lo, x + HIT_RADIUS + DODGE_MARGIN)
	if limit >= lo:
		spans.append([lo, limit])
	return spans

## True when x lies in one of the free [lo, hi] spans (the edges count as free).
static func _in_spans(x: float, spans: Array) -> bool:
	for s in spans:
		if x >= s[0] and x <= s[1]:
			return true
	return false

## The point of the free spans nearest to x (x itself when it is free); NAN when the row has none.
static func _nearest_free(x: float, spans: Array) -> float:
	var best := NAN
	var best_d := INF
	for s in spans:
		var p: float = clampf(x, s[0], s[1])
		if absf(p - x) < best_d:
			best_d = absf(p - x)
			best = p
	return best

## Lateral movement a kart aiming at x in the nearest row still has to make to weave through the
## rows behind it, always moving to the nearest free spot of the next row (rows with no way through
## are skipped — nothing can be done about them). Weighted by LATER_WEIGHT: there is less time for a
## move between two rows than for one now, so moving early is preferred.
static func _path_cost(x: float, later_rows: Array) -> float:
	var cost := 0.0
	for spans in later_rows:
		var p := _nearest_free(x, spans)
		if is_nan(p):
			continue
		cost += absf(p - x) * LATER_WEIGHT
		x = p
	return cost

## Lateral offset an AI kart at road sample idx should aim for to weave through the snowmen ahead:
## its own `lane` when that passes every row within LOOK_AHEAD; otherwise the spot that clears the
## nearest row and costs the least lateral movement in all — from `current` (what it is aiming for
## now, so a dodge is not changed without reason) to the spot and on through the rows behind, ties
## going to the spot nearer the middle of the road — or `lane` when the nearest row leaves no way
## through at all.
func clear_lane(idx: int, lane: float, current: float = NAN) -> float:
	var s_k: float = track.length * posmod(idx, track.count) / track.count
	var rows := rows_ahead(s_k)
	if rows.is_empty():
		return lane
	var from := lane if is_nan(current) else current
	var first: Array = rows[0]
	var later: Array = rows.slice(1)
	if _in_spans(lane, first) and _path_cost(lane, later) == 0.0:
		return lane
	var candidates: Array = [from, lane, 0.0]
	for s in first:
		candidates.append(s[0])
		candidates.append(s[1])
	var best := lane
	var best_cost := INF
	for c in candidates:
		if not _in_spans(c, first):
			continue
		# ties go to the spot nearer the middle of the road rather than an edge
		var cost: float = absf(c - from) + _path_cost(c, later) + absf(c) * 0.01
		if cost < best_cost:
			best_cost = cost
			best = c
	return best
