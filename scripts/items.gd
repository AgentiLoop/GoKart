extends RefCounted
## Item types and the weighted item-box roll (pure, unit tested).

enum Type { NONE, MUSHROOM, BANANA, SHELL, RED_SHELL, STAR, LIGHTNING, TRIPLE_SHELL, BLUE_SHELL }

const WEIGHTS := {Type.MUSHROOM: 5.0, Type.BANANA: 3.0, Type.SHELL: 3.0, Type.RED_SHELL: 2.5, Type.STAR: 1.5, Type.LIGHTNING: 1.0, Type.TRIPLE_SHELL: 2.0, Type.BLUE_SHELL: 1.0}

## Shells granted by one TRIPLE_SHELL pickup.
const TRIPLE_CHARGES := 3

## Number of real items (excludes NONE); the HUD roulette cycles through them.
static func count() -> int:
	return Type.size() - 1

static func name_of(t: int) -> String:
	return ["", "MUSHROOM", "BANANA", "GREEN SHELL", "RED SHELL", "STAR", "LIGHTNING", "TRIPLE SHELLS", "BLUE SHELL"][t]

## Weights adjusted for race position (rubber banding): rank 1 = leader, racers = field size.
## The leader mostly gets defensive items; the back of the pack gets star, lightning and
## blue shell. Blue shell and lightning are never rolled for the leader. rank <= 0 or a
## field of one means "no adjustment" (the plain WEIGHTS).
static func weights_for(rank := 0, racers := 0) -> Dictionary:
	if rank <= 0 or racers < 2:
		return WEIGHTS.duplicate()
	var f := clampf(float(rank - 1) / float(racers - 1), 0.0, 1.0)   # 0 = leader, 1 = last
	var mult := {
		Type.MUSHROOM: 0.6 + 0.8 * f,
		Type.BANANA: 2.0 - 1.6 * f,
		Type.SHELL: 2.0 - 1.4 * f,
		Type.TRIPLE_SHELL: 1.6 - 0.8 * f,
		Type.RED_SHELL: 0.6 + 1.0 * f,
		Type.STAR: 0.2 + 2.0 * f,
		Type.LIGHTNING: 0.0 if rank == 1 else 2.0 * f,
		Type.BLUE_SHELL: 0.0 if rank == 1 else 2.5 * f,
	}
	var out := {}
	for t in WEIGHTS:
		out[t] = WEIGHTS[t] * mult[t]
	return out

## Map r in [0,1) to an item using WEIGHTS, or the rank-adjusted weights when rank > 0.
static func roll(r: float, rank := 0, racers := 0) -> int:
	var w := weights_for(rank, racers)
	var total := 0.0
	for v in w.values():
		total += v
	var acc := 0.0
	var last: int = Type.MUSHROOM
	for t in w:
		if w[t] <= 0.0:
			continue
		last = t
		acc += w[t] / total
		if r < acc:
			return t
	return last
