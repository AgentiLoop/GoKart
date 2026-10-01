extends CharacterBody3D
## Scene-side kart: reads input, drives KartPhysics, moves the body.

const KartPhysics := preload("res://scripts/kart_physics.gd")
const KartEffects := preload("res://scripts/kart_effects.gd")

var model := KartPhysics.new()
var gravity := 30.0
var heading := 0.0   # yaw in radians
var drift_slide := 0.0   # visual slide angle while drifting
var body_mesh: Node3D
var effects: Node3D

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 0.6, 2.2)
	col.shape = shape
	col.position.y = 0.3
	add_child(col)
	body_mesh = Node3D.new()
	add_child(body_mesh)
	_add_box(body_mesh, Vector3(1.4, 0.4, 2.2), Vector3(0, 0.4, 0), Color(0.9, 0.1, 0.1))
	_add_box(body_mesh, Vector3(0.7, 0.4, 0.8), Vector3(0, 0.8, -0.1), Color(0.95, 0.85, 0.2))
	for x in [-0.8, 0.8]:
		for z in [-0.8, 0.8]:
			_add_box(body_mesh, Vector3(0.3, 0.5, 0.5), Vector3(x, 0.25, z), Color(0.1, 0.1, 0.1))
	effects = KartEffects.new()
	add_child(effects)
	effects.setup(model, [Vector3(-0.8, 0, -0.8), Vector3(0.8, 0, -0.8), Vector3(-0.8, 0, 0.8), Vector3(0.8, 0, 0.8)])

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _physics_process(delta: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var brake := Input.get_action_strength("brake")
	var steer := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	heading += model.step(delta, throttle, brake, steer, Input.is_action_pressed("drift"))
	var target_slide := -model.drift_direction * 0.45 if model.drifting else 0.0
	drift_slide = lerpf(drift_slide, target_slide, clampf(10.0 * delta, 0.0, 1.0))
	rotation.y = heading
	body_mesh.rotation.y = drift_slide
	var forward := Vector3(-sin(heading), 0, -cos(heading))
	velocity.x = forward.x * model.speed
	velocity.z = forward.z * model.speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if absf(n.y) < 0.5:   # wall hit: lose the speed that went into the wall
			model.speed = minf(model.speed, maxf(velocity.dot(forward), 0.0))
	effects.update_fx(delta, is_on_floor())
