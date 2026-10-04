extends RefCounted
## Mario Kart 64 Sherbet Land penguins (pure model, no scene nodes, unit tested): Little Penguin
## Sliders waddle from one edge of an icy stretch towards the other, flop onto their bellies and slide
## across the road, get up at the far edge, turn round and come back, without end. A kart that runs
## into a penguin is pushed away and spins out (a Star bowls the penguin over and drives on); a green
## or red shell bowls one over too, and a bowled penguin lies on its back for a while before it gets
## up. CPU karts keep to the edges of the road beyond a penguin's run.

const PERIOD := 5.0         # s for a penguin to cross the road and come back (one full sweep)
const SLIDE_FRAC := 0.55    # the penguin is on its belly while within this fraction of its run of the centre
const HIT_RADIUS := 1.0     # m (XZ) round a penguin that strikes a kart
const KNOCK_TIME := 4.0     # s a penguin bowled over by a shell or a Star kart lies on its back
const PHASE_STEP := 1.7     # s between the sweeps of neighbouring penguins (so they never move as one)
const LOOK_AHEAD := 40.0    # m of road an AI kart looks ahead for penguins to steer clear of
const DODGE_MARGIN := 1.0   # m of clearance an AI kart keeps from a penguin's run
const EDGE_MARGIN := 1.6    # an AI kart will not dodge closer than this to the road edge
const LAUNCH_SPEED := 3.0   # upward m/s a struck kart is bumped with (MK64: pushed away and spun, not thrown)
const SHOVE := 6.0          # m/s a struck kart is shoved away from the penguin

var track                   # TrackData (its penguin_specs may be empty: no penguins on this course)
## {idx (road sample of the run), s (metres along the road), start (m right of the centreline the
## penguin sets out from; its run is start -> -start -> start), phase (s offset into the sweep),
## t (s into its own sweeps, frozen while bowled over), knocked (s left lying on its back)}
var penguins: Array = []
var knocks := 0             # penguins bowled over so far (for checks/tests)

func _init(track_data) -> void:
	track = track_data
	if track == null:
		return
	for i in track.penguin_specs.size():
		var spec: Array = track.penguin_specs[i]
		var idx: int = int(spec[0] * track.count) % track.count
		penguins.append({
			"idx": idx,
			"s": track.length * idx / track.count,
			"start": spec[1],
			"phase": fposmod(i * PHASE_STEP, PERIOD),
			"t": 0.0,
			"knocked": 0.0,
		})

func active() -> bool:
	return not penguins.is_empty()

func step(delta: float) -> void:
	for p in penguins:
		if p.knocked > 0.0:
			p.knocked -= delta
			if p.knocked <= 0.0:
				# up again part way through the step: the rest of it goes into the sweep
				p.t -= p.knocked
				p.knocked = 0.0
		else:
			p.t += delta

## Metres right of the centreline penguin i is at: a sweep from `start` across to -start and back.
func lateral(i: int) -> float:
	var p: Dictionary = penguins[i]
	return p.start * cos(TAU * (p.t + p.phase) / PERIOD)

## Lateral speed of penguin i (m/s right of the centreline; 0 at the edges where it turns round).
func across_speed(i: int) -> float:
	var p: Dictionary = penguins[i]
	return -p.start * TAU / PERIOD * sin(TAU * (p.t + p.phase) / PERIOD)

## Where penguin i is now (y 0).
func position(i: int) -> Vector3:
	var p: Dictionary = penguins[i]
	return track.points[p.idx] + track.right_of(p.idx) * lateral(i)

## True while penguin i is on its belly sliding across the middle of the road (it waddles near the
## edges); false while it lies bowled over.
func is_sliding(i: int) -> bool:
	return not is_down(i) and absf(lateral(i)) < SLIDE_FRAC * absf(penguins[i].start)

## True while penguin i lies on its back after being bowled over.
func is_down(i: int) -> bool:
	return penguins[i].knocked > 0.0

## Seconds the model has to advance so that penguin i sits on the centreline, moving (for tools and
## tests; 0 when it lies bowled over there).
func time_until_centre(i: int) -> float:
	var p: Dictionary = penguins[i]
	var ph: float = fposmod(p.t + p.phase, PERIOD)
	# cos crosses 0 at PERIOD / 4 and 3 PERIOD / 4
	var q: float = PERIOD * 0.25
	return fposmod(q - ph, PERIOD * 0.5) + p.knocked

## Index of the penguin that is up (waddling or sliding) within `radius` (XZ) of pos, or -1 when
## clear of them all.
func penguin_at(pos: Vector3, radius := HIT_RADIUS) -> int:
	for i in penguins.size():
		if is_down(i):
			continue
		var d: Vector3 = pos - position(i)
		if Vector2(d.x, d.z).length() <= radius:
			return i
	return -1

## Direction a kart at pos is shoved when it hits penguin i: away from it (along the road when it
## sits right on top of it).
func shove_dir(i: int, pos: Vector3) -> Vector3:
	var d: Vector3 = pos - position(i)
	d.y = 0.0
	if d.length() < 0.05:
		return track.tangents[penguins[i].idx]
	return d.normalized()

## A shell or a Star kart bowled penguin i over: it lies on its back for KNOCK_TIME where it was.
func knock(i: int) -> void:
	penguins[i].knocked = KNOCK_TIME
	knocks += 1

## Bowls over the penguin within `radius` of pos (a shell flying into it); returns its index, or -1
## when there was none.
func knock_at(pos: Vector3, radius := HIT_RADIUS) -> int:
	var i := penguin_at(pos, radius)
	if i >= 0:
		knock(i)
	return i

## Metres along the road from `s_from` to penguin p's run, in the racers' direction (positive = ahead
## of a kart there), in (-length / 2, length / 2].
func ahead_of(p: Dictionary, s_from: float) -> float:
	var L: float = track.length
	return fposmod(p.s - s_from + L * 0.5, L) - L * 0.5

## Lateral offset an AI kart at road sample idx should aim for to keep out of the penguin runs ahead
## of it (a penguin may be anywhere on its run by the time the kart arrives, so the whole run is
## kept clear of): its own `lane` when that is free; otherwise `current` (what it is aiming for now)
## if that is still free, so a dodge is not changed halfway; otherwise the nearest free spot on the
## road to `current` — or `lane` when nothing is free.
func clear_lane(idx: int, lane: float, current: float = NAN) -> float:
	var s_k: float = track.length * posmod(idx, track.count) / track.count
	var blocked: Array = []
	for p in penguins:
		var rel := ahead_of(p, s_k)
		if rel > -HIT_RADIUS and rel < LOOK_AHEAD:
			var reach: float = absf(p.start) + HIT_RADIUS + DODGE_MARGIN
			blocked.append([-reach, reach])
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
