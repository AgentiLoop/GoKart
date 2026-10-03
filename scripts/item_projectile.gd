extends RefCounted
## A thrown/dropped item in the world (pure logic). Green shells fly straight and
## ricochet off the road walls; bananas and fake item boxes sit where they were dropped.
## All are consumed when they hit a kart.

const Items := preload("res://scripts/items.gd")

const SHELL_SPEED := 55.0
const SHELL_LIFE := 10.0
const SHELL_MAX_BOUNCES := 6
const RED_SHELL_SPEED := 50.0
const RED_TURN_RATE := 3.5        # rad/s the homing shell can turn
const RED_LOCK_RANGE := 28.0      # closer than this it aims straight at its target, else it follows the road
const RED_LOOKAHEAD := 5          # track samples ahead it aims for while following the road
const BLUE_SPEED := 75.0
const BLUE_LIFE := 30.0
const BLUE_TURN_RATE := 6.0       # rad/s; sharp enough to hug the road at speed
const BLUE_LOCK_RANGE := 40.0     # closer than this it dives straight at the leader
const BLUE_LOOKAHEAD := 8
const BLUE_BLAST_RADIUS := 7.0    # karts this close to the impact are also spun out
const BLUE_HEIGHT := 1.6          # it hovers above the road
const OWNER_GRACE := 0.6   # seconds before the thrower can be hit by their own item

var kind := Items.Type.BANANA
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var radius := 0.8
var age := 0.0
var owner_id := -1
var bounces := 0
var alive := true
var hint := -1   # track index hint
var target_id := -1   # kart a blue shell is locked on to (the race leader when fired)
var target_pos = null   # Vector3 of the kart a red shell homes on (set by the item manager), or null

static func make_shell(pos: Vector3, heading: float, owner := -1) -> Object:
	var p = load("res://scripts/item_projectile.gd").new()
	p.kind = Items.Type.SHELL
	p.position = pos
	p.velocity = Vector3(-sin(heading), 0, -cos(heading)) * SHELL_SPEED
	p.owner_id = owner
	return p

static func make_red_shell(pos: Vector3, heading: float, owner := -1) -> Object:
	var p = load("res://scripts/item_projectile.gd").new()
	p.kind = Items.Type.RED_SHELL
	p.position = pos
	p.velocity = Vector3(-sin(heading), 0, -cos(heading)) * RED_SHELL_SPEED
	p.owner_id = owner
	return p

static func make_blue_shell(pos: Vector3, heading: float, owner := -1, target := -1) -> Object:
	var p = load("res://scripts/item_projectile.gd").new()
	p.kind = Items.Type.BLUE_SHELL
	p.position = pos
	p.velocity = Vector3(-sin(heading), 0, -cos(heading)) * BLUE_SPEED
	p.owner_id = owner
	p.target_id = target
	return p

func is_shell() -> bool:
	return kind == Items.Type.SHELL or kind == Items.Type.RED_SHELL or kind == Items.Type.BLUE_SHELL

## The race leader other than `exclude`, or -1. Higher progress = further ahead.
static func pick_leader(progresses: Array, exclude := -1) -> int:
	var best := -1
	for j in progresses.size():
		if j != exclude and (best < 0 or progresses[j] > progresses[best]):
			best = j
	return best

## Nearest candidate roughly ahead of `from` along `dir`; returns its index or -1.
## Candidates flagged false in `valid` (e.g. invincible karts) and `skip` are ignored.
static func pick_target(from: Vector3, dir: Vector3, positions: Array, skip: int, valid: Array, max_range := 120.0) -> int:
	var best := -1
	var best_f := INF
	for j in positions.size():
		if j == skip or not valid[j]:
			continue
		var d: Vector3 = positions[j] - from
		d.y = 0.0
		var f := d.dot(dir)
		if f > 0.0 and f < max_range and f < best_f:
			best_f = f
			best = j
	return best

## Turn the velocity toward the desired point, limited by RED_TURN_RATE.
func _home(delta: float, track, turn_rate := RED_TURN_RATE, lock_range := RED_LOCK_RANGE, lookahead := RED_LOOKAHEAD) -> void:
	var aim: Vector3
	if track.get("arena") == true:
		# battle arena: no road to follow, go straight at the target (or keep going)
		if target_pos == null:
			return
		aim = target_pos
	else:
		hint = track.nearest_index(position, hint)
		aim = track.points[(hint + lookahead) % track.count]
		if target_pos != null:
			var to_t: Vector3 = target_pos - position
			if Vector2(to_t.x, to_t.z).length() < lock_range:
				aim = target_pos
	var cur := Vector2(velocity.x, velocity.z)
	var want := Vector2(aim.x - position.x, aim.z - position.z)
	if want.length_squared() < 0.0001:
		return
	var ang := clampf(cur.angle_to(want), -turn_rate * delta, turn_rate * delta)
	var nv := cur.rotated(ang)
	velocity = Vector3(nv.x, 0.0, nv.y)

static func make_banana(pos: Vector3, owner := -1) -> Object:
	var p = load("res://scripts/item_projectile.gd").new()
	p.kind = Items.Type.BANANA
	p.position = pos
	p.owner_id = owner
	return p

## Mario Kart 64 fake item box: sits on the road like a banana, looks like a real box.
static func make_fake_box(pos: Vector3, owner := -1) -> Object:
	var p = load("res://scripts/item_projectile.gd").new()
	p.kind = Items.Type.FAKE_ITEM_BOX
	p.position = pos
	p.radius = 1.0
	p.owner_id = owner
	return p

## Advance one tick; track (TrackData) is used for wall ricochets.
func step(delta: float, track) -> void:
	if not alive:
		return
	age += delta
	if not is_shell():
		return
	if kind == Items.Type.BLUE_SHELL:
		_home(delta, track, BLUE_TURN_RATE, BLUE_LOCK_RANGE, BLUE_LOOKAHEAD)
		position += velocity * delta
		position.y = BLUE_HEIGHT
		if age >= BLUE_LIFE:
			alive = false
		return   # flies over the walls: no ricochets
	if kind == Items.Type.RED_SHELL:
		_home(delta, track)
	position += velocity * delta
	if age >= SHELL_LIFE:
		alive = false
		return
	if track.get("arena") == true:
		# battle arena: ricochet off the outer walls and the forts
		var hit: Dictionary = track.collide_circle(position, radius)
		if not hit.is_empty():
			var an: Vector3 = hit.normal
			if velocity.dot(an) < 0.0:
				velocity = velocity - 2.0 * velocity.dot(an) * an
			position = Vector3(hit.position.x, position.y, hit.position.z)
			bounces += 1
			if bounces > SHELL_MAX_BOUNCES:
				alive = false
		return
	var limit: float = track.width * 0.5 - radius
	var c: Vector3 = track.closest_point(position, hint)
	hint = track.nearest_index(position, hint)
	var off := Vector3(position.x - c.x, 0, position.z - c.z)
	if off.length() > limit:
		var n := off.normalized()   # outward wall normal
		if velocity.dot(n) > 0.0:
			velocity = velocity - 2.0 * velocity.dot(n) * n
		position = Vector3(c.x, position.y, c.z) + n * limit
		bounces += 1
		if bounces > SHELL_MAX_BOUNCES:
			alive = false

func hits(pos: Vector3, kart_radius: float, kart_id: int) -> bool:
	if not alive:
		return false
	if kind == Items.Type.BLUE_SHELL and kart_id != target_id:
		return false   # a blue shell only has eyes for the leader
	if kart_id == owner_id and age < OWNER_GRACE:
		return false
	return Vector2(pos.x - position.x, pos.z - position.z).length() <= radius + kart_radius
