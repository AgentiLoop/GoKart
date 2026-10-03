extends Node3D
## Procedural kart model: tapered chassis, nose cone, spoiler, seat, driver, exhausts, four wheels.
## Forward is -Z. Front wheels steer, all wheels spin with ground speed.

const WHEEL_RADIUS := 0.3
const MAX_FRONT_STEER := 0.45
const STEER_RATE := 12.0

var color := Color(0.9, 0.1, 0.1)
var front_pivots: Array[Node3D] = []   # yaw (steering) nodes, front wheels
var wheel_spins: Array[Node3D] = []    # roll nodes, all wheels
var steering_wheel: Node3D
var driver_head: Node3D
var materials: Array[StandardMaterial3D] = []   # every material on the model, for set_opacity

## Wheel roll rate in rad/s for a ground speed.
static func wheel_roll_rate(speed: float) -> float:
	return speed / WHEEL_RADIUS

## Front wheel yaw for a steer input in [-1, 1] (steer right = turn right = negative yaw).
static func front_steer_angle(steer: float) -> float:
	return -clampf(steer, -1.0, 1.0) * MAX_FRONT_STEER

func build(body_color: Color) -> void:
	color = body_color
	var dark := Color(0.12, 0.12, 0.14)
	var trim := Color(0.95, 0.85, 0.2)
	# chassis: wide floor pan, narrower upper tub, nose cone, side pods
	_box(Vector3(1.3, 0.25, 2.2), Vector3(0, 0.38, 0), color)
	_box(Vector3(0.9, 0.25, 1.2), Vector3(0, 0.6, 0.25), color)
	_cone(0.4, 0.9, Vector3(0, 0.42, -1.5), color)
	_box(Vector3(1.7, 0.08, 0.3), Vector3(0, 0.22, -1.7), trim)      # front wing
	for x in [-0.75, 0.75]:
		_box(Vector3(0.22, 0.3, 1.0), Vector3(x, 0.5, 0.1), trim)    # side pods
	# rear spoiler: two struts and a wing
	for x in [-0.45, 0.45]:
		_box(Vector3(0.08, 0.5, 0.08), Vector3(x, 0.8, 1.05), dark)
	_box(Vector3(1.4, 0.08, 0.35), Vector3(0, 1.06, 1.05), trim)
	# exhausts
	for x in [-0.3, 0.3]:
		_cyl(0.07, 0.07, 0.35, Vector3(x, 0.5, 1.2), dark, Vector3(PI / 2.0, 0, 0))
	# seat, steering column + wheel
	_box(Vector3(0.6, 0.4, 0.15), Vector3(0, 0.95, 0.55), dark)
	steering_wheel = Node3D.new()
	steering_wheel.position = Vector3(0, 0.95, -0.3)
	steering_wheel.rotation.x = -0.9
	add_child(steering_wheel)
	_cyl(0.2, 0.2, 0.05, Vector3.ZERO, dark, Vector3(PI / 2.0, 0, 0), steering_wheel)
	# driver: torso, head, helmet
	_box(Vector3(0.45, 0.45, 0.3), Vector3(0, 0.95, 0.2), Color(0.2, 0.3, 0.9))
	driver_head = Node3D.new()
	driver_head.position = Vector3(0, 1.4, 0.2)
	add_child(driver_head)
	_sphere(0.22, Vector3.ZERO, Color(0.95, 0.75, 0.6), driver_head)
	_sphere(0.25, Vector3(0, 0.05, 0.03), color, driver_head, true)   # helmet (dome)
	# wheels
	for x in [-0.85, 0.85]:
		for z in [-0.8, 0.85]:
			_wheel(Vector3(x, WHEEL_RADIUS, z), z < 0.0, dark)

func _wheel(pos: Vector3, front: bool, tire_color: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var spin := Node3D.new()
	pivot.add_child(spin)
	var w := 0.32 if front else 0.4
	_cyl(WHEEL_RADIUS, WHEEL_RADIUS, w, Vector3.ZERO, tire_color, Vector3(0, 0, PI / 2.0), spin)
	# hub cap: lighter disc on the outer face plus a bolt-ish marker so spin is visible
	var side := signf(pos.x)
	_cyl(0.16, 0.16, 0.04, Vector3(side * (w / 2.0 + 0.005), 0, 0), Color(0.8, 0.8, 0.85), Vector3(0, 0, PI / 2.0), spin)
	_box(Vector3(0.05, 0.05, 0.22), Vector3(side * (w / 2.0 + 0.03), 0.0, 0.0), Color(0.9, 0.1, 0.1), spin)
	wheel_spins.append(spin)
	if front:
		front_pivots.append(pivot)

## Spin the wheels by ground speed and turn the front wheels / steering wheel toward the steer input.
func update_wheels(delta: float, speed: float, steer: float) -> void:
	for s in wheel_spins:
		s.rotation.x -= wheel_roll_rate(speed) * delta
		s.rotation.x = fmod(s.rotation.x, TAU)
	var target := front_steer_angle(steer)
	for p in front_pivots:
		p.rotation.y = lerpf(p.rotation.y, target, clampf(STEER_RATE * delta, 0.0, 1.0))
	steering_wheel.rotation.z = lerpf(steering_wheel.rotation.z, -steer * 1.2, clampf(STEER_RATE * delta, 0.0, 1.0))
	driver_head.rotation.y = lerpf(driver_head.rotation.y, -steer * 0.5, clampf(6.0 * delta, 0.0, 1.0))

## Fade the whole kart (Boo ghost): alpha < 1 turns on alpha blending, 1 restores opaque rendering.
func set_opacity(alpha: float) -> void:
	for m in materials:
		m.albedo_color.a = alpha
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if alpha >= 1.0 else BaseMaterial3D.TRANSPARENCY_ALPHA

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	materials.append(m)
	return m

func _add(mi: MeshInstance3D, pos: Vector3, c: Color, rot: Vector3, parent: Node3D) -> void:
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation = rot
	(parent if parent != null else self).add_child(mi)

func _box(size: Vector3, pos: Vector3, c: Color, parent: Node3D = null) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	_add(mi, pos, c, Vector3.ZERO, parent)

func _cyl(top: float, bottom: float, height: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 16
	mi.mesh = m
	_add(mi, pos, c, rot, parent)

## Nose cone pointing forward (-Z): radius at the rear, narrowing toward the front.
func _cone(radius: float, length: float, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.12
	m.bottom_radius = radius
	m.height = length
	m.radial_segments = 12
	mi.mesh = m
	# cylinder axis is Y (top = +Y); rotate so top points to -Z
	_add(mi, pos, c, Vector3(-PI / 2.0, 0, 0), null)

func _sphere(radius: float, pos: Vector3, c: Color, parent: Node3D, dome: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * (1.0 if dome else 2.0)
	mi.mesh = m
	_add(mi, pos, c, Vector3.ZERO, parent)
