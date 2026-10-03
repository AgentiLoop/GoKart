extends CharacterBody3D
## Scene-side kart: reads input, drives KartPhysics, moves the body.

const KartPhysics := preload("res://scripts/kart_physics.gd")
const KartEffects := preload("res://scripts/kart_effects.gd")
const KartModel := preload("res://scripts/kart_model.gd")
const KartWeight := preload("res://scripts/kart_weight.gd")
const Lakitu := preload("res://scripts/lakitu.gd")

const SHRUNK_SCALE := 0.5
const GHOST_ALPHA := 0.35   # how see-through a Boo makes the kart

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
var steer_input := 0.0   # smoothed steering actually applied (-1..1)
var frozen := false      # true during the start countdown: no input, no driving
## MK64 weight class: mass decides who gets shoved in a kart-to-kart bump, size_scale the body size.
var weight_class := KartWeight.MEDIUM
var mass := 1.0
var size_scale := 1.0
var push := Vector3.ZERO      # sideways shove from a bump, decays over a few tenths of a second
var bump_cooldown := 0.0
var bumps := 0                # number of kart-to-kart bumps taken (for checks/tests)
## Lakitu rescue (fell in the water): seconds into the rescue (-1 = not being rescued), where it
## started, where it ends and the heading the kart is set down with.
var rescue_time := -1.0
var rescue_from := Vector3.ZERO
var rescue_to := Vector3.ZERO
var rescue_heading := 0.0
var rescues := 0              # number of times Lakitu fished this kart out

func is_rescued() -> bool:
	return rescue_time >= 0.0

## Lakitu hooks the kart: it stops dead, is lifted, carried over `to` and set down facing `to_heading`.
func start_rescue(to: Vector3, to_heading: float) -> void:
	if is_rescued():
		return
	rescue_time = 0.0
	rescue_from = position
	rescue_to = to
	rescue_heading = to_heading
	rescues += 1
	model.stop()
	push = Vector3.ZERO
	velocity = Vector3.ZERO

## Advances a rescue in progress; returns true while the kart hangs from the line (no driving).
func _update_rescue(delta: float) -> bool:
	if not is_rescued():
		return false
	rescue_time += delta
	if rescue_time >= Lakitu.RESCUE_TIME:
		position = rescue_to
		heading = rescue_heading
		rotation.y = heading
		rescue_time = -1.0
		return true
	position = Lakitu.rescue_pose(rescue_time, rescue_from, rescue_to)
	if rescue_time > Lakitu.LIFT_TIME:
		heading = lerp_angle(heading, rescue_heading, clampf(4.0 * delta, 0.0, 1.0))
	rotation.y = heading
	velocity = Vector3.ZERO
	return true

## Applies a KartWeight class: speed/accel on the model, mass and body size on the node.
## Call once after creation (after the engine class).
func apply_weight_class(i: int) -> void:
	var w: Dictionary = KartWeight.info(i)
	weight_class = posmod(i, KartWeight.count())
	mass = w.mass
	size_scale = w.size
	model.apply_weight_class(w.speed, w.accel)

func _ready() -> void:
	# karts live on layer 2 and collide with the world (layer 1) and with each other (layer 2)
	collision_layer = 2
	collision_mask = 3
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
	model.ghost_started.connect(func(): body_mesh.set_opacity(GHOST_ALPHA))
	model.ghost_ended.connect(func(): body_mesh.set_opacity(1.0))

func _physics_process(delta: float) -> void:
	if _update_rescue(delta):
		body_mesh.update_wheels(delta, 0.0, 0.0)
		effects.update_fx(delta, false)
		return
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
	if driver == null:
		steer = KartPhysics.smooth_steer(steer_input, steer, delta)
	steer_input = steer
	heading += model.step(delta, throttle, brake, steer, drift_held)
	var target_slide := -model.drift_direction * 0.45 if model.drifting else 0.0
	drift_slide = lerpf(drift_slide, target_slide, clampf(10.0 * delta, 0.0, 1.0))
	rotation.y = heading
	body_mesh.rotation.y = drift_slide + model.spin_progress() * TAU * 2.0
	body_scale = move_toward(body_scale, SHRUNK_SCALE if model.is_shrunk() else 1.0, 3.0 * delta)
	body_mesh.scale = Vector3.ONE * body_scale * size_scale
	body_mesh.visible = model.is_spinning() or model.immunity_time <= 0.0 or fmod(model.immunity_time, 0.2) < 0.1
	var forward := Vector3(-sin(heading), 0, -cos(heading))
	bump_cooldown = maxf(bump_cooldown - delta, 0.0)
	push = push.move_toward(Vector3.ZERO, KartWeight.PUSH_DECAY * delta)
	velocity.x = forward.x * model.speed + push.x
	velocity.z = forward.z * model.speed + push.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	var kart_hit := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other = c.get_collider()
		if absf(c.get_normal().y) < 0.5 and other is CharacterBody3D and other.get("mass") != null:
			_bump(other, c.get_normal(), forward)
			kart_hit = true
	if not kart_hit:
		for i in get_slide_collision_count():
			var n := get_slide_collision(i).get_normal()
			if absf(n.y) < 0.5:   # wall hit: lose the speed that went into the wall
				model.speed = minf(model.speed, maxf(velocity.dot(forward), 0.0))
	body_mesh.update_wheels(delta, model.speed, steer)
	effects.update_fx(delta, is_on_floor())

## Kart-to-kart contact (MK64 weight classes): both karts are thrown apart along the contact
## normal, the lighter one much further; the heavier kart keeps its speed, the lighter one is
## slowed towards the speed the contact left it with. n points from the other kart towards this
## one. One shove per contact (cooldown on both).
func _bump(other, n: Vector3, forward: Vector3) -> void:
	if bump_cooldown > 0.0 or other.bump_cooldown > 0.0:
		return
	var side := Vector3(n.x, 0, n.z).normalized()
	var closing: float = maxf((forward * model.speed - other.velocity).dot(-side), 0.0)
	push += side * KartWeight.shove(mass, other.mass, closing)
	other.push -= side * KartWeight.shove(other.mass, mass, closing)
	var blocked := minf(model.speed, maxf(velocity.dot(forward), 0.0))
	model.speed = lerpf(blocked, model.speed, KartWeight.speed_keep(mass, other.mass))
	other.model.speed *= KartWeight.speed_keep(other.mass, mass)
	bump_cooldown = KartWeight.BUMP_COOLDOWN
	other.bump_cooldown = KartWeight.BUMP_COOLDOWN
	bumps += 1
	other.bumps += 1
