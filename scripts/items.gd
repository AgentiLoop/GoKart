extends RefCounted
## Item types and the weighted item-box roll (pure, unit tested).

enum Type { NONE, MUSHROOM, BANANA, SHELL, RED_SHELL, STAR }

const WEIGHTS := {Type.MUSHROOM: 5.0, Type.BANANA: 3.0, Type.SHELL: 3.0, Type.RED_SHELL: 2.5, Type.STAR: 1.5}

## Number of real items (excludes NONE); the HUD roulette cycles through them.
static func count() -> int:
	return Type.size() - 1

static func name_of(t: int) -> String:
	return ["", "MUSHROOM", "BANANA", "GREEN SHELL", "RED SHELL", "STAR"][t]

## Map r in [0,1) to an item using WEIGHTS.
static func roll(r: float) -> int:
	var total := 0.0
	for w in WEIGHTS.values():
		total += w
	var acc := 0.0
	for t in WEIGHTS:
		acc += WEIGHTS[t] / total
		if r < acc:
			return t
	return Type.MUSHROOM
