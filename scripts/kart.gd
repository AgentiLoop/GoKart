extends CharacterBody3D
## Scene-side kart: reads input, drives KartPhysics, moves the body.

const KartPhysics := preload("res://scripts/kart_physics.gd")
const KartEffects := preload("res://scripts/kart_effects.gd")
const KartModel := preload("res://scripts/kart_model.gd")

const SHRUNK_SCALE := 0.5

var model := KartPhysics.new()
var gravity := 30.0
var heading := 0.0   # yaw in radians
var drift_slide := 0.0   # visual slide angle while drifting
var body_mesh: Node3D
var effects: Node3D
var body_color := Color(0.9, 0.1, 0.1)
var driver = null        # AiDriver for computer karts; null = keyboard player
var kart_id := 0
var track_index := 0
var tracker = null       # LapTracker
var body_scale := 1.0    # visual size: shrinks while hit by lightning
var frozen := false      # true during the start countdown: no input, no driving

func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 0.6, 2.2)
	col.shape = shape
	col.position.y = 0.3
	add_child(col)
	var kart_model := KartModel.new()
	body_mesh = kart_model
	add_child(kart_model)
	kart_model.build(body_color)
	effects = KartEffects.new()
	add_child(effects)
	effects.setup(model, [Vector3(-0.8, 0, -0.8), Vector3(0.8, 0, -0.8), Vector3(-0.8, 0, 0.8), Vector3(0.8, 0, 0.8)])
	effects.setup_star(body_mesh)

func _physics_process(delta: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var brake := Input.get_action_strength("brake")
	var steer := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	var drift_held := Input.is_action_pressed("drift")
	if driver != null and not frozen:
		var d: Dictionary = driver.decide(delta, global_position, heading, model.speed, not model.is_spinning())
		throttle = d.throttle
		brake = d.brake
		steer = d.steer
		drift_held = d.drift
	if frozen:
		throttle = 0.0
		brake = 0.0
		steer = 0.0
		drift_held = false
	heading += model.step(delta, throttle, brake, steer, drift_held)
	var target_slide := -model.drift_direction * 0.45 if model.drifting else 0.0
	drift_slide = lerpf(drift_slide, target_slide, clampf(10.0 * delta, 0.0, 1.0))
	rotation.y = heading
	body_mesh.rotation.y = drift_slide + model.spin_progress() * TAU * 2.0
	body_scale = move_toward(body_scale, SHRUNK_SCALE if model.is_shrunk() else 1.0, 3.0 * delta)
	body_mesh.scale = Vector3.ONE * body_scale
	body_mesh.visible = model.is_spinning() or model.immunity_time <= 0.0 or fmod(model.immunity_time, 0.2) < 0.1
	var forward := Vector3(-sin(heading), 0, -cos(heading))
	velocity.x = forward.x * model.speed
	velocity.z = forward.z * model.speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if absf(n.y) < 0.5:   # wall hit: lose the speed that went into the wall
			model.speed = minf(model.speed, maxf(velocity.dot(forward), 0.0))
	body_mesh.update_wheels(delta, model.speed, steer)
	effects.update_fx(delta, is_on_floor())
