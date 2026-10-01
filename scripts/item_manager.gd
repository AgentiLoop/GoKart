extends Node3D
## Owns everything item related for a race: item boxes, the kart's item holder,
## thrown/dropped projectiles (with their visuals) and hit resolution.

const Items := preload("res://scripts/items.gd")
const ItemHolder := preload("res://scripts/item_holder.gd")
const ItemProjectile := preload("res://scripts/item_projectile.gd")
const ItemBox := preload("res://scripts/item_box.gd")

const MUSHROOM_BOOST_TIME := 1.5
const KART_RADIUS := 1.1

signal kart_hit(kind: int)

var track
var kart
var kart_id := 0
var holder
var boxes: Array = []
var projectiles: Array = []
var nodes := {}   # projectile -> Node3D
var time := 0.0

func setup(track_data, player_kart, seed_value := 0) -> void:
	track = track_data
	kart = player_kart
	holder = ItemHolder.new(seed_value)
	for p in track.item_box_positions:
		var b := ItemBox.new()
		b.position = p
		add_child(b)
		boxes.append(b)
	for p in track.hazard_positions:
		_add_projectile(ItemProjectile.make_banana(p + Vector3(0, 0.3, 0)))

func use_item() -> int:
	if kart.model.is_spinning():
		return Items.Type.NONE
	var t: int = holder.use()
	var pos: Vector3 = kart.global_position
	var fwd := Vector3(-sin(kart.heading), 0, -cos(kart.heading))
	match t:
		Items.Type.MUSHROOM:
			kart.model.apply_boost(MUSHROOM_BOOST_TIME, 2)
		Items.Type.BANANA:
			_add_projectile(ItemProjectile.make_banana(pos - fwd * 2.4 + Vector3(0, 0.3, 0), kart_id))
		Items.Type.SHELL:
			_add_projectile(ItemProjectile.make_shell(pos + fwd * 2.4 + Vector3(0, 0.6, 0), kart.heading, kart_id))
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
	holder.update(delta)
	var kpos: Vector3 = kart.global_position
	for b in boxes:
		b.tick(delta)
		if b.try_take(kpos):
			holder.pickup()
	if Input.is_action_just_pressed("use_item"):
		use_item()
	for p in projectiles.duplicate():
		p.step(delta, track)
		if p.hits(kpos, KART_RADIUS, kart_id) and kart.model.spin_out():
			p.alive = false
			kart_hit.emit(p.kind)
		if not p.alive:
			_remove_projectile(p)
		else:
			var n: Node3D = nodes[p]
			n.position = p.position
			n.rotation.y += (12.0 if p.kind == Items.Type.SHELL else 0.0) * delta
