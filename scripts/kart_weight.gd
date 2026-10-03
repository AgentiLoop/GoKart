extends RefCounted
## Mario Kart 64 weight classes (pure data + maths, unit tested).
## MK64 drivers come in three weights: light (Toad, Peach, Yoshi) accelerate fastest but are
## shoved around, medium (Mario, Luigi) are balanced, heavy (Bowser, DK, Wario) have the highest
## top speed, the slowest pick-up and bump lighter karts aside. The player picks a weight on the
## title menu (X / V); the AI field mixes all three.

const LIGHT := 0
const MEDIUM := 1
const HEAVY := 2

## speed / accel multiply the kart's top speed and acceleration on top of the engine class;
## mass drives kart-to-kart bumps; size scales the visible body.
const CLASSES := [
	{"name": "Light", "blurb": "quick off the line, bumped easily", "speed": 0.97, "accel": 1.18, "mass": 0.8, "size": 0.9},
	{"name": "Medium", "blurb": "balanced", "speed": 1.0, "accel": 1.0, "mass": 1.0, "size": 1.0},
	{"name": "Heavy", "blurb": "top speed, shoves others aside", "speed": 1.03, "accel": 0.85, "mass": 1.3, "size": 1.1},
]

## The player's weight class, chosen on the title menu (survives scene changes).
static var selected := MEDIUM

## Sideways shove (m/s) a kart gets at a bump before mass is taken into account, plus a share of
## the closing speed so a hard hit throws further than a nudge.
const BUMP_BASE := 3.0
const BUMP_CLOSING_SHARE := 0.3
const BUMP_MAX := 14.0
## Seconds between bumps for a kart pair (one shove per contact, not one per physics frame).
const BUMP_COOLDOWN := 0.35
## How fast a shove dies off (m/s per second).
const PUSH_DECAY := 14.0

static func count() -> int:
	return CLASSES.size()

static func info(i: int) -> Dictionary:
	return CLASSES[posmod(i, CLASSES.size())]

## Next/previous class (wraps around).
static func step(current: int, dir: int) -> int:
	return posmod(current + dir, CLASSES.size())

## Sideways speed a kart of my_mass is thrown with when it bumps a kart of other_mass while they
## close at closing_speed (m/s, >= 0). Scales with the squared mass ratio: a heavy kart hitting
## a light one barely moves, the light kart flies. Equal masses push each other apart gently.
static func shove(my_mass: float, other_mass: float, closing_speed: float) -> float:
	var base := BUMP_BASE + BUMP_CLOSING_SHARE * maxf(closing_speed, 0.0)
	var ratio := other_mass / maxf(my_mass, 0.01)
	return minf(base * ratio * ratio, BUMP_MAX)

## Fraction of forward speed a kart of my_mass keeps when it bumps a kart of other_mass:
## the heavier kart keeps everything, equal karts lose a little, the lighter one is slowed hard.
static func speed_keep(my_mass: float, other_mass: float) -> float:
	return clampf(0.85 * my_mass / maxf(other_mass, 0.01), 0.6, 1.0)
