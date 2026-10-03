extends RefCounted
## Item types and the weighted item-box roll (pure, unit tested).

enum Type { NONE, MUSHROOM, BANANA, SHELL, RED_SHELL, STAR, LIGHTNING, TRIPLE_SHELL, BLUE_SHELL, TRIPLE_MUSHROOM, GOLDEN_MUSHROOM, FAKE_ITEM_BOX, BANANA_BUNCH }

const WEIGHTS := {Type.MUSHROOM: 5.0, Type.BANANA: 3.0, Type.SHELL: 3.0, Type.RED_SHELL: 2.5, Type.STAR: 1.5, Type.LIGHTNING: 1.0, Type.TRIPLE_SHELL: 2.0, Type.BLUE_SHELL: 1.0, Type.TRIPLE_MUSHROOM: 2.0, Type.GOLDEN_MUSHROOM: 1.0, Type.FAKE_ITEM_BOX: 2.0, Type.BANANA_BUNCH: 1.5}

## Shells / mushrooms granted by one TRIPLE_SHELL / TRIPLE_MUSHROOM pickup.
const TRIPLE_CHARGES := 3

## Bananas in one BANANA_BUNCH pickup (Mario Kart 64: five bananas trailing the kart).
const BUNCH_CHARGES := 5

## Seconds a golden mushroom stays usable once its first boost is fired (Mario Kart 64:
## unlimited boosts for a short while, then the item is gone).
const GOLDEN_DURATION := 7.5

## Number of real items (excludes NONE); the HUD roulette cycles through them.
static func count() -> int:
	return Type.size() - 1

static func name_of(t: int) -> String:
	return ["", "MUSHROOM", "BANANA", "GREEN SHELL", "RED SHELL", "STAR", "LIGHTNING", "TRIPLE SHELLS", "BLUE SHELL", "TRIPLE MUSHROOMS", "GOLDEN MUSHROOM", "FAKE ITEM BOX", "BANANA BUNCH"][t]

## Every item that gives the user a speed boost when fired.
static func is_mushroom(t: int) -> bool:
	return t == Type.MUSHROOM or t == Type.TRIPLE_MUSHROOM or t == Type.GOLDEN_MUSHROOM

## Items that hold several charges and are fired one at a time.
static func is_triple(t: int) -> bool:
	return t == Type.TRIPLE_SHELL or t == Type.TRIPLE_MUSHROOM

## Uses granted by one pickup of a multi-use item (0 for single-use items).
static func charges_for(t: int) -> int:
	if is_triple(t):
		return TRIPLE_CHARGES
	if t == Type.BANANA_BUNCH:
		return BUNCH_CHARGES
	return 0

## Hazards dropped behind the kart that sit still until a kart drives into them.
static func is_dropped(t: int) -> bool:
	return t == Type.BANANA or t == Type.FAKE_ITEM_BOX

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
		Type.TRIPLE_MUSHROOM: 0.4 + 1.2 * f,
		Type.GOLDEN_MUSHROOM: 0.0 if rank == 1 else 2.5 * f,
		Type.FAKE_ITEM_BOX: 2.2 - 2.0 * f,
		Type.BANANA_BUNCH: 1.6 - 1.2 * f,
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
