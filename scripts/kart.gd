extends CharacterBody3D
## Scene-side kart: reads input, drives KartPhysics, moves the body.

const KartPhysics := preload("res://scripts/kart_physics.gd")
const KartEffects := preload("res://scripts/kart_effects.gd")
const KartModel := preload("res://scripts/kart_model.gd")
const KartWeight := preload("res://scripts/kart_weight.gd")
const Lakitu := preload("res://scripts/lakitu.gd")
const TrackData := preload("res://scripts/track_data.gd")
const OnlineRace := preload("res://scripts/online_race.gd")

const SHRUNK_SCALE := 0.5
const GHOST_ALPHA := 0.35   # how see-through a Boo makes the kart
const STALL_WHEEL_SPEED := 24.0   # m/s the wheels appear to spin at during a false-start burnout
const DRIFT_HOP := 4.0            # m/s: the MK64 hop that starts a powerslide (light karts hop higher)
const AIR_PITCH := 0.6            # MK64 jump: how much of the flight angle the body pitches (nose up, then down)
const PITCH_RATE := 8.0           # 1/s the body pitch eases towards its target

## A kart-to-kart bump happened (other kart, closing speed in m/s); battle mode pops balloons on hard shoves.
signal bumped(other, closing: float)
## The kart flew off a jump ramp's lip / came back down on the ground after a jump.
signal jumped
signal landed

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
## Upward speed applied on the next physics frame (hit by the train); 0 = none pending.
var hop := 0.0
var launches := 0             # number of times this kart was thrown into the air (for checks/tests)
## MK64 jump ramp: the height of the ramp surface under the kart, set each frame by the scene
## (TrackData.ramp_height; 0 off every ramp) — the kart rides the slope at that height, and the frame
## it drops to 0 past the lip the kart takes off along the slope and flies (airborne: no traction until
## it lands). jumps counts the take-offs (for checks/tests).
var ramp_lift := 0.0
var on_ramp := false
var airborne := false
var jumps := 0
var pitch := 0.0              # body pitch in radians (nose up on a ramp and on the way up, down on the way down)
## Online: another player's kart. Its pose comes from their packets (OnlineRace.Puppet) instead of
## input and physics; null for every kart driven on this machine.
var puppet = null
## Online puppet: the item the other player holds and its charges, from their packets.
var net_held := 0
var net_charges := 0

## Body pitch to aim for: up the ramp's slope while on one, following the flight path in the air
## (scaled by AIR_PITCH), level otherwise. vy is the vertical speed, speed the speed over the ground.
static func pitch_for(riding: bool, slope: float, vy: float, speed: float, flying: bool) -> float:
	if riding:
		return atan(slope)
	if flying:
		return atan2(vy, maxf(speed, 1.0)) * AIR_PITCH
	return 0.0

func is_rescued() -> bool:
	return rescue_time >= 0.0

## Run over by the train (MK64 Kalimari Desert): the kart spins out, is thrown `up` m/s into the air
## and shoved along `shove`. Returns false (nothing happens) when the kart is already spinning,
## still immune, a star or a Boo ghost — a Star drives straight through the train like in MK64.
func launch(up: float, shove: Vector3) -> bool:
	if not model.spin_out():
		return false
	hop = up
	push += shove
	launches += 1
	return true

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
	model.drift_started.connect(func(_d): if absf(velocity.y) < 0.5: hop = DRIFT_HOP / sqrt(mass))   # MK64: the slide starts with a hop

func _physics_process(delta: float) -> void:
	if puppet != null:
		_play_puppet(delta)
		return
	if _update_rescue(delta):
		body_mesh.update_wheels(delta, 0.0, 0.0)
		effects.update_fx(delta, false)
		return
	var throttle := Input.get_action_strength("accelerate")
	var brake := Input.get_action_strength("brake")
	var steer := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	var drift_held := Input.is_action_pressed("drift")
	if driver != null and not frozen:
		# the driver steers the direction of travel (on ice the nose points inside of it, as a driver would)
		var d: Dictionary = driver.decide(delta, global_position, heading + model.travel_offset(), model.speed, not model.is_spinning())
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
	pitch = lerpf(pitch, pitch_for(on_ramp, TrackData.jump_slope(), velocity.y, model.speed, airborne), clampf(PITCH_RATE * delta, 0.0, 1.0))
	body_mesh.rotation.x = pitch
	body_scale = move_toward(body_scale, SHRUNK_SCALE if model.is_shrunk() else 1.0, 3.0 * delta)
	body_mesh.scale = Vector3.ONE * body_scale * size_scale
	body_mesh.visible = model.is_spinning() or model.immunity_time <= 0.0 or fmod(model.immunity_time, 0.2) < 0.1
	# MK64 ice: on ice the kart travels sideways of its nose (the slide the model keeps); 0 on tarmac
	var travel := heading + model.travel_offset()
	var forward := Vector3(-sin(travel), 0, -cos(travel))
	bump_cooldown = maxf(bump_cooldown - delta, 0.0)
	push = push.move_toward(Vector3.ZERO, KartWeight.PUSH_DECAY * delta)
	velocity.x = forward.x * model.speed + push.x
	velocity.z = forward.z * model.speed + push.z
	# MK64 jump ramp: ride the slope (the body is held at the ramp's height), take off along it at the lip
	var was_riding := on_ramp
	on_ramp = ramp_lift > 0.0
	if on_ramp:
		velocity.y = (ramp_lift - position.y) / delta
		hop = 0.0
	elif was_riding and model.speed > 0.0:
		velocity.y = model.speed * TrackData.jump_slope()
		airborne = true
		model.airborne = true
		jumps += 1
		jumped.emit()
	elif hop > 0.0:
		velocity.y = hop
		hop = 0.0
	else:
		velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	if airborne and (is_on_floor() or on_ramp):
		airborne = false
		model.airborne = false
		effects.land()
		landed.emit()
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
	body_mesh.update_wheels(delta, STALL_WHEEL_SPEED if model.is_stalled() else model.speed, steer)
	effects.update_fx(delta, is_on_floor() or on_ramp)

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
	bumped.emit(other, closing)

## Online: this kart's pose for a state packet (OnlineRace.pack_state); t is the sender's clock in ms.
func net_state(t: int) -> Dictionary:
	var flags := 0
	if body_mesh.visible:
		flags |= OnlineRace.F_VISIBLE
	if is_on_floor() or on_ramp:
		flags |= OnlineRace.F_ON_FLOOR
	if model.drifting:
		flags |= OnlineRace.F_DRIFTING
	if model.is_boosting():
		flags |= OnlineRace.F_BOOSTING
	if model.drift_direction > 0:
		flags |= OnlineRace.F_DRIFT_RIGHT
	if model.is_star():
		flags |= OnlineRace.F_STAR
	if model.is_ghost():
		flags |= OnlineRace.F_GHOST
	return {"t": t, "pos": global_position, "heading": heading, "speed": model.speed, "yaw": body_mesh.rotation.y,
		"pitch": body_mesh.rotation.x, "scale": body_mesh.scale.x, "flags": flags, "drift_level": model.drift_level,
		"weight": weight_class}

## Online: shows another player's kart where their packets say it is (no input, no physics of its own).
func _play_puppet(delta: float) -> void:
	var s: Dictionary = puppet.sample(delta)
	if s.is_empty():
		return
	if int(s.weight) != weight_class:
		apply_weight_class(int(s.weight))
	var moved: Vector3 = s.pos - global_position
	global_position = s.pos
	velocity = moved / delta if moved.length() < 20.0 else Vector3.ZERO   # what a bump into it sees
	heading = s.heading
	rotation.y = heading
	model.speed = s.speed
	model.drifting = int(s.flags) & OnlineRace.F_DRIFTING != 0
	model.drift_direction = (1 if int(s.flags) & OnlineRace.F_DRIFT_RIGHT != 0 else -1) if model.drifting else 0
	model.drift_level = s.drift_level
	# a star or Boo ghost shields them from items here too (their machine runs the timers)
	model.star_time = 1.0 if int(s.flags) & OnlineRace.F_STAR != 0 else 0.0
	var ghost := int(s.flags) & OnlineRace.F_GHOST != 0
	if ghost != model.is_ghost():
		body_mesh.set_opacity(GHOST_ALPHA if ghost else 1.0)
	model.ghost_time = 1.0 if ghost else 0.0
	net_held = int(s.get("held", 0))
	net_charges = int(s.get("charges", 0))
	body_mesh.rotation.y = s.yaw
	body_mesh.rotation.x = s.pitch
	body_mesh.scale = Vector3.ONE * float(s.scale)
	body_mesh.visible = int(s.flags) & OnlineRace.F_VISIBLE != 0
	body_mesh.update_wheels(delta, model.speed, 0.0)
	effects.update_fx(delta, int(s.flags) & OnlineRace.F_ON_FLOOR != 0)
