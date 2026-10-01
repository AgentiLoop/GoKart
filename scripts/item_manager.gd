extends Node3D
## Owns everything item related for a race: item boxes, the kart's item holder,
## thrown/dropped projectiles (with their visuals) and hit resolution.

const Items := preload("res://scripts/items.gd")
const ItemHolder := preload("res://scripts/item_holder.gd")
const ItemProjectile := preload("res://scripts/item_projectile.gd")
const ItemBox := preload("res://scripts/item_box.gd")

const MUSHROOM_BOOST_TIME := 1.5
const KART_RADIUS := 1.1

signal kart_hit(kind: int, id: int)

var track
var karts: Array = []     # index in this array == kart_id; karts[0] is the player
var holders: Array = []   # one ItemHolder per kart
var kart               # the player kart (karts[0])
var holder             # the player's holder (holders[0])
var boxes: Array = []
var projectiles: Array = []
var nodes := {}   # projectile -> Node3D
var time := 0.0

func setup(track_data, all_karts, seed_value := 0) -> void:
	track = track_data
	karts = all_karts if all_karts is Array else [all_karts]
	kart = karts[0]
	for i in karts.size():
		holders.append(ItemHolder.new(seed_value + i if seed_value != 0 else 0))
	holder = holders[0]
	for p in track.item_box_positions:
		var b := ItemBox.new()
		b.position = p
		add_child(b)
		boxes.append(b)
	for p in track.hazard_positions:
		_add_projectile(ItemProjectile.make_banana(p + Vector3(0, 0.3, 0)))

## Distances (ahead, behind) from racer i to the nearest rival roughly in its lane.
## positions/headings are per racer. INF when nobody qualifies.
static func rival_gaps(i: int, positions: Array, headings: Array) -> Vector2:
	var ahead := INF
	var behind := INF
	var h: float = headings[i]
	var fwd := Vector3(-sin(h), 0, -cos(h))
	var right := Vector3(-fwd.z, 0, fwd.x)
	for j in positions.size():
		if j == i:
			continue
		var d: Vector3 = positions[j] - positions[i]
		var f := d.dot(fwd)
		var l := absf(d.dot(right))
		if f > 0.0 and l < 6.0:
			ahead = minf(ahead, f)
		elif f < 0.0 and l < 4.0:
			behind = minf(behind, -f)
	return Vector2(ahead, behind)

func use_item(id := 0) -> int:
	var k = karts[id]
	if k.model.is_spinning():
		return Items.Type.NONE
	var t: int = holders[id].use()
	var pos: Vector3 = k.global_position
	var fwd := Vector3(-sin(k.heading), 0, -cos(k.heading))
	match t:
		Items.Type.MUSHROOM:
			k.model.apply_boost(MUSHROOM_BOOST_TIME, 2)
		Items.Type.BANANA:
			_add_projectile(ItemProjectile.make_banana(pos - fwd * 2.4 + Vector3(0, 0.3, 0), id))
		Items.Type.SHELL:
			_add_projectile(ItemProjectile.make_shell(pos + fwd * 2.4 + Vector3(0, 0.6, 0), k.heading, id))
	return t

func _add_projectile(p) -> void:
	projectiles.append(p)
	var n := Node3D.new()
	if p.kind == Items.Type.SHELL:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 0.8
		mi.mesh = sm
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/shell.gdshader") as Shader
		mi.material_override = mat
		n.add_child(mi)
	else:
		for k in 2:
			var mi := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.16
			cm.height = 0.9
			mi.mesh = cm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.9, 0.1)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.8, 0.0)
			mat.emission_energy_multiplier = 0.4
			mi.material_override = mat
			mi.rotation_degrees = Vector3(0, 0, 70 + 40 * k)
			mi.position = Vector3(0.12 * k - 0.06, 0.25, 0)
			n.add_child(mi)
	n.position = p.position
	add_child(n)
	nodes[p] = n

func _remove_projectile(p) -> void:
	projectiles.erase(p)
	if nodes.has(p):
		nodes[p].queue_free()
		nodes.erase(p)

func _physics_process(delta: float) -> void:
	time += delta
	var positions: Array = []
	var headings: Array = []
	for k in karts:
		positions.append(k.global_position)
		headings.append(k.heading)
	for id in karts.size():
		holders[id].update(delta)
	for b in boxes:
		b.tick(delta)
		for id in karts.size():
			if b.try_take(positions[id]):
				holders[id].pickup()
	if Input.is_action_just_pressed("use_item") and not karts[0].frozen:
		use_item(0)
	for id in range(1, karts.size()):
		var drv = karts[id].driver
		if drv != null:
			var gaps := rival_gaps(id, positions, headings)
			if drv.wants_use(delta, holders[id].held, gaps.x, gaps.y):
				use_item(id)
	for p in projectiles.duplicate():
		p.step(delta, track)
		for id in karts.size():
			if p.hits(positions[id], KART_RADIUS, id) and karts[id].model.spin_out():
				p.alive = false
				kart_hit.emit(p.kind, id)
				break
		if not p.alive:
			_remove_projectile(p)
		else:
			var n: Node3D = nodes[p]
			n.position = p.position
			n.rotation.y += (12.0 if p.kind == Items.Type.SHELL else 0.0) * delta
