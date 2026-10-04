extends RefCounted
## Mario Kart 64 slipstream (drafting), the pure geometry: a kart that trails close behind another
## kart — inside its wake, a strip RANGE m long and 2 x WIDTH m wide straight behind it — with both
## karts rolling the same way at speed is "in the draft". KartPhysics counts the seconds spent there
## (update_draft) and fires a brief burst of speed after draft_charge_time, like MK64's draft boost
## (subtle: no lines while charging, grey wind during the burst). Nothing here touches the scene.

const RANGE := 12.0      # m: how far behind the kart ahead its wake reaches
const MIN_GAP := 1.0     # m: closer than this is a bump, not a draft
const WIDTH := 1.8       # m: half-width of the wake
const ALIGN := 0.9       # cos of the heading tolerance (~25 degrees) between the two karts
const MIN_SPEED := 12.0  # m/s: both karts must be rolling this fast

## True when the kart at `pos` heading `forward` at `speed` sits in the wake of the kart at
## `lead_pos` heading `lead_forward` at `lead_speed`.
static func in_wake(pos: Vector3, forward: Vector3, speed: float, lead_pos: Vector3, lead_forward: Vector3, lead_speed: float) -> bool:
	if speed < MIN_SPEED or lead_speed < MIN_SPEED:
		return false
	var f := Vector3(forward.x, 0, forward.z).normalized()
	var lf := Vector3(lead_forward.x, 0, lead_forward.z).normalized()
	if f.dot(lf) < ALIGN:
		return false
	var d := lead_pos - pos
	d.y = 0.0
	# the wake trails straight behind the leader: measure along and across ITS heading
	var ahead := d.dot(lf)
	if ahead < MIN_GAP or ahead > RANGE:
		return false
	var across := absf(d.dot(Vector3(lf.z, 0, -lf.x)))
	return across <= WIDTH

## Index of the nearest kart whose wake kart `idx` sits in, or -1 when it drafts nobody.
static func leader(idx: int, positions: Array, forwards: Array, speeds: Array) -> int:
	var best := -1
	var best_d := INF
	for j in positions.size():
		if j == idx:
			continue
		if not in_wake(positions[idx], forwards[idx], speeds[idx], positions[j], forwards[j], speeds[j]):
			continue
		var d: float = positions[idx].distance_squared_to(positions[j])
		if d < best_d:
			best_d = d
			best = j
	return best
