extends Node3D
## Mario Kart 64 Moo Moo Farm mole holes node, driven by a Moles model: a dirt mound with a dark
## hole per entry and a procedural Monty Mole (brown body, tan snout, triangular sunglasses) that
## rises out of it and sinks back as the model says. The moles face the oncoming racers.

const Moles := preload("res://scripts/moles.gd")

const RISE := 1.3                     # m a mole travels between hidden and fully out
const FUR := Color(0.45, 0.28, 0.14)
const DIRT := Color(0.42, 0.27, 0.12)
const HOLE := Color(0.08, 0.05, 0.03)
const SNOUT := Color(0.85, 0.7, 0.5)

var moles                   # Moles model
var bodies: Array = []      # Node3D per mole (the part that moves), in moles.moles order

func _init(model) -> void:
	moles = model

func _ready() -> void:
	for i in moles.moles.size():
		var m: Dictionary = moles.moles[i]
		var hole := Node3D.new()
		hole.name = "Hole%d" % i
		hole.position = m.pos
		var fwd: Vector3 = -moles.track.tangents[m.idx]   # looks back down the road at the racers
		hole.rotation.y = atan2(-fwd.x, -fwd.z)
		add_child(hole)
		_build_mound(hole)
		var body := Node3D.new()
		body.name = "Mole%d" % i
		hole.add_child(body)
		_build_mole(body)
		bodies.append(body)
	update_moles(0.0)

## Advances the model and moves every mole up or down its hole. Called every physics frame.
func update_moles(delta: float) -> void:
	moles.step(delta)
	for i in bodies.size():
		var h: float = moles.height(i)
		var body: Node3D = bodies[i]
		body.position.y = -RISE + RISE * h
		body.visible = h > 0.0

## Flattened dirt mound with a dark hole in the top.
func _build_mound(hole: Node3D) -> void:
	var mound := _sphere(hole, 1.3, Vector3(0, 0.0, 0), DIRT)
	mound.scale = Vector3(1.0, 0.25, 1.0)
	var disc := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.7
	c.bottom_radius = 0.7
	c.height = 0.06
	c.radial_segments = 16
	disc.mesh = c
	disc.material_override = _mat(HOLE)
	disc.position = Vector3(0, 0.3, 0)
	hole.add_child(disc)

## Monty Mole: round brown body, tan snout with a pink nose, two triangular black sunglasses and a
## pair of paws. Forward is -Z (its face).
func _build_mole(body: Node3D) -> void:
	_sphere(body, 0.55, Vector3(0, 0.55, 0), FUR)                     # body
	_sphere(body, 0.24, Vector3(0, 0.5, -0.48), SNOUT)                # snout
	_sphere(body, 0.09, Vector3(0, 0.56, -0.7), Color(0.9, 0.35, 0.4))   # nose
	for sx in [-0.2, 0.2]:
		var lens := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.26, 0.2, 0.06)
		lens.mesh = p
		lens.material_override = _mat(Color(0.05, 0.05, 0.06))
		lens.position = Vector3(sx, 0.8, -0.46)
		lens.rotation.x = PI          # point down like MK64's triangular shades
		body.add_child(lens)
	for sx in [-0.45, 0.45]:
		_sphere(body, 0.16, Vector3(sx, 0.3, -0.3), FUR)              # paws

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi
