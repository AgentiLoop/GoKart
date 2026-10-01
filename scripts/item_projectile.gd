extends RefCounted
## A thrown/dropped item in the world (pure logic). Green shells fly straight and
## ricochet off the road walls; bananas sit where they were dropped. Both are
## consumed when they hit a kart.

const Items := preload("res://scripts/items.gd")

const SHELL_SPEED := 55.0
const SHELL_LIFE := 10.0
const SHELL_MAX_BOUNCES := 6
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

static func make_shell(pos: Vector3, heading: float, owner := -1) -> Object:
	var p = load("res://scripts/item_projectile.gd").new()
	p.kind = Items.Type.SHELL
	p.position = pos
	p.velocity = Vector3(-sin(heading), 0, -cos(heading)) * SHELL_SPEED
	p.owner_id = owner
	return p

static func make_banana(pos: Vector3, owner := -1) -> Object:
	var p = load("res://scripts/item_projectile.gd").new()
	p.kind = Items.Type.BANANA
	p.position = pos
	p.owner_id = owner
	return p

## Advance one tick; track (TrackData) is used for wall ricochets.
func step(delta: float, track) -> void:
	if not alive:
		return
	age += delta
	if kind != Items.Type.SHELL:
		return
	position += velocity * delta
	if age >= SHELL_LIFE:
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
	if kart_id == owner_id and age < OWNER_GRACE:
		return false
	return Vector2(pos.x - position.x, pos.z - position.z).length() <= radius + kart_radius
