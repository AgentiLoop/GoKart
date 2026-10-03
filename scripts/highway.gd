extends Node3D
## Mario Kart 64 Toad's Turnpike traffic node, driven by a Traffic model: one procedural vehicle per
## entry (white car, yellow bus, red box truck or cyan tanker) with lit headlights and taillights,
## moved along the road every frame. Forward is -Z like the karts.

const Traffic := preload("res://scripts/traffic.gd")

const HEADLIGHT := Color(1.0, 0.95, 0.7)
const TAILLIGHT := Color(1.0, 0.1, 0.05)

var traffic                 # Traffic model
var cars: Array = []        # Node3D per vehicle, in traffic.vehicles order

func _init(model) -> void:
	traffic = model

func _ready() -> void:
	for i in traffic.vehicles.size():
		var v: Dictionary = traffic.vehicles[i]
		var car := Node3D.new()
		car.name = "Vehicle%d" % i
		add_child(car)
		match v.kind:
			"bus":
				_build_bus(car)
			"truck":
				_build_truck(car)
			"tanker":
				_build_tanker(car)
			_:
				_build_car(car)
		cars.append(car)
	update_traffic(0.0)

## Advances the traffic and moves every vehicle. Called every physics frame once the race is on.
func update_traffic(delta: float) -> void:
	traffic.step(delta)
	for i in cars.size():
		var p: Dictionary = traffic.vehicle_pose(i)
		var car: Node3D = cars[i]
		car.position = p.pos
		car.rotation.y = atan2(-p.dir.x, -p.dir.z)

## White saloon car.
func _build_car(car: Node3D) -> void:
	var white := Color(0.92, 0.92, 0.9)
	_wheels(car, 0.9, [-1.3, 1.3], 0.34)
	_box(car, Vector3(1.9, 0.6, 4.2), Vector3(0, 0.65, 0), white)                 # body
	_box(car, Vector3(1.7, 0.55, 2.0), Vector3(0, 1.2, 0.1), white)               # cabin
	_box(car, Vector3(1.72, 0.4, 2.02), Vector3(0, 1.17, 0.1), Color(0.3, 0.45, 0.65))   # windows
	_lights(car, 0.65, 0.7, 2.1)

## Yellow school bus with a row of windows (MK64's buses are yellow).
func _build_bus(car: Node3D) -> void:
	var yellow := Color(0.95, 0.75, 0.1)
	_wheels(car, 1.1, [-3.0, 0.0, 3.0], 0.5)
	_box(car, Vector3(2.5, 2.2, 9.0), Vector3(0, 1.7, 0), yellow)                 # body
	_box(car, Vector3(2.6, 0.12, 9.1), Vector3(0, 2.85, 0), Color(0.3, 0.3, 0.3))   # roof
	_box(car, Vector3(2.52, 0.14, 9.02), Vector3(0, 1.1, 0), Color(0.15, 0.15, 0.15))   # stripe
	for x in [-1.26, 1.26]:
		for z in [-3.3, -2.0, -0.7, 0.6, 1.9, 3.2]:
			_box(car, Vector3(0.04, 0.8, 1.0), Vector3(x, 2.1, z), Color(0.3, 0.45, 0.65))
	_box(car, Vector3(2.3, 0.9, 0.05), Vector3(0, 2.1, -4.51), Color(0.3, 0.45, 0.65))    # windscreen
	_lights(car, 0.9, 1.0, 4.5)

## Red box truck: cab in front, a tall cargo box behind.
func _build_truck(car: Node3D) -> void:
	var red := Color(0.8, 0.1, 0.1)
	_wheels(car, 1.1, [-2.6, 1.4, 2.6], 0.5)
	_box(car, Vector3(2.4, 0.5, 8.0), Vector3(0, 0.7, 0), Color(0.15, 0.15, 0.17))   # chassis
	_box(car, Vector3(2.4, 2.0, 2.2), Vector3(0, 1.9, -2.9), red)                 # cab
	_box(car, Vector3(2.2, 0.8, 0.05), Vector3(0, 2.3, -4.01), Color(0.3, 0.45, 0.65))    # windscreen
	_box(car, Vector3(2.5, 2.6, 5.4), Vector3(0, 2.25, 1.3), Color(0.9, 0.88, 0.85))   # box
	_box(car, Vector3(2.52, 0.6, 5.42), Vector3(0, 2.3, 1.3), red)                # box stripe
	_lights(car, 0.85, 0.9, 4.0)

## Cyan tanker: cab and a long cylindrical tank.
func _build_tanker(car: Node3D) -> void:
	var cyan := Color(0.2, 0.75, 0.8)
	_wheels(car, 1.1, [-3.0, 1.2, 3.0], 0.5)
	_box(car, Vector3(2.4, 0.5, 9.0), Vector3(0, 0.7, 0), Color(0.15, 0.15, 0.17))   # chassis
	_box(car, Vector3(2.4, 2.0, 2.2), Vector3(0, 1.9, -3.4), cyan)                # cab
	_box(car, Vector3(2.2, 0.8, 0.05), Vector3(0, 2.3, -4.51), Color(0.3, 0.45, 0.65))    # windscreen
	var tank := _cyl(car, 1.1, 5.8, Vector3(0, 1.85, 0.9), cyan.lightened(0.2))
	tank.rotation.x = PI / 2.0
	_lights(car, 0.85, 0.9, 4.5)

## Four (or six) wheels: `zs` are the axle positions, `half` the half track width.
func _wheels(car: Node3D, half: float, zs: Array, radius: float) -> void:
	for x in [-half, half]:
		for z in zs:
			var w := _cyl(car, radius, 0.3, Vector3(x, radius, z), Color(0.08, 0.08, 0.09))
			w.rotation.z = PI / 2.0

## Two glowing headlights at the front (-Z) and two red taillights at the back.
func _lights(car: Node3D, x: float, y: float, half_length: float) -> void:
	for sx in [-x, x]:
		_lamp(car, Vector3(sx, y, -half_length - 0.02), HEADLIGHT, 0.14)
		_lamp(car, Vector3(sx, y, half_length + 0.02), TAILLIGHT, 0.1)

func _lamp(car: Node3D, pos: Vector3, color: Color, radius: float) -> void:
	var lamp := _sphere(car, radius, pos, color)
	var m := lamp.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = color * 2.5

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 14
	mi.mesh = c
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 10
	s.rings = 5
	mi.mesh = s
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi
