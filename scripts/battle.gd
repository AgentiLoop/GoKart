extends RefCounted
## Mario Kart 64 Battle mode rules (pure, unit tested). Four karts, three balloons each. A hit by
## any item, a fall into the pit / off the edge, a star kart's touch or a hard shove by a heavier
## kart pops one balloon. With no balloons left the kart turns into a Mini Bomb Kart: it can still
## drive and be hit, but it can't use items and it explodes on the first balloon kart it touches
## (which loses a balloon) - then it is out for good. The last kart with balloons wins.
## `active` / `arena` are static so the title menu's choice survives the scene change.

const RaceRanking := preload("res://scripts/race_ranking.gd")

const BALLOONS := 3
const PLAYERS := 4
## Closing speed (m/s) above which a heavier kart's shove pops a lighter kart's balloon.
const SHOVE_POP_SPEED := 12.0
## A bomb kart this close to a balloon kart goes off.
const BOMB_RADIUS := 2.4
## Seconds after the battle is decided before the results panel appears.
const RESULTS_DELAY := 2.5

static var active := false
static var arena := 0

var balloons: Array = []     # per kart
var exploded: Array = []     # bomb kart has gone off (out of the battle for good)
var pops: Array = []         # balloons lost per kart (for checks/tests)
var lost_order: Array = []   # kart ids in the order they lost their last balloon
var time := 0.0
var over := false
var winner := -1

func _init(n := PLAYERS) -> void:
	balloons.resize(n)
	balloons.fill(BALLOONS)
	exploded.resize(n)
	exploded.fill(false)
	pops.resize(n)
	pops.fill(0)

func count() -> int:
	return balloons.size()

## Still has balloons: can win, can be hit.
func has_balloons(id: int) -> bool:
	return balloons[id] > 0

## Lost every balloon but hasn't gone off yet: drives around as a Mini Bomb Kart.
func is_bomb(id: int) -> bool:
	return balloons[id] == 0 and not exploded[id]

## Out of the battle: exploded bomb kart.
func is_out(id: int) -> bool:
	return exploded[id]

## Kart `id` takes a hit: loses a balloon. Returns true when that was its last one (now a bomb).
## Nothing happens to a kart without balloons or once the battle is over.
func hit(id: int) -> bool:
	if over or balloons[id] <= 0:
		return false
	balloons[id] -= 1
	pops[id] += 1
	if balloons[id] == 0:
		lost_order.append(id)
		_check_over()
		return true
	return false

## Bomb kart `bomb` rammed balloon kart `victim`: the victim loses a balloon and the bomb is spent.
## Returns false when nothing happened (not a bomb, victim has no balloons, battle over).
func bomb_hit(bomb: int, victim: int) -> bool:
	if over or not is_bomb(bomb) or not has_balloons(victim):
		return false
	exploded[bomb] = true
	hit(victim)
	return true

## Karts that still hold balloons.
func survivors() -> Array:
	var out: Array = []
	for i in count():
		if has_balloons(i):
			out.append(i)
	return out

func _check_over() -> void:
	var s := survivors()
	if s.size() <= 1:
		over = true
		winner = s[0] if s.size() == 1 else -1

func update(delta: float) -> void:
	if not over:
		time += delta

## Final standings: survivors by balloons left (ties by fewer pops), then the eliminated karts in
## reverse order of elimination (the last to lose its balloons placed highest). Returns kart ids.
func placings() -> Array:
	var s := survivors()
	s.sort_custom(func(a, b): return balloons[a] > balloons[b] or (balloons[a] == balloons[b] and pops[a] < pops[b]))
	var out := s.duplicate()
	for i in range(lost_order.size() - 1, -1, -1):
		out.append(lost_order[i])
	return out

## 1-based place of kart `id`.
func rank_of(id: int) -> int:
	return placings().find(id) + 1

## HUD line: one dot per balloon, or the bomb warning.
static func balloon_text(n: int, is_out_now := false) -> String:
	if is_out_now:
		return "OUT"
	if n <= 0:
		return "BOMB KART!"
	return "BALLOONS " + "O".repeat(n)

static func time_text(t: float) -> String:
	var total_ms := int(round(t * 1000.0))
	return "%d:%02d.%d" % [total_ms / 60000, (total_ms / 1000) % 60, (total_ms % 1000) / 100]

## Results panel text: placings with balloons left, the player's row marked with ">".
func results_text(names: Array, arena_name: String, player := 0) -> String:
	var lines: Array = ["BATTLE - %s" % arena_name]
	lines.append(("YOU WIN!" if winner == player else ("%s WINS" % names[winner])) if winner >= 0 else "NO SURVIVORS")
	lines.append("")
	var order := placings()
	for r in order.size():
		var id: int = order[r]
		var state := "%d balloon%s" % [balloons[id], "" if balloons[id] == 1 else "s"] if has_balloons(id) else ("bomb kart" if is_bomb(id) else "exploded")
		lines.append("%s %-4s %-8s %s" % [">" if id == player else " ", RaceRanking.ordinal(r + 1), names[id], state])
	lines.append("")
	lines.append("Battle time %s" % time_text(time))
	lines.append("Press ENTER to battle again")
	return "\n".join(lines)
