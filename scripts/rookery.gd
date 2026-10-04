extends Node3D
## Mario Kart 64 Sherbet Land penguins node, driven by a Penguins model: a procedural penguin per
## entry (black back, white front, orange beak and feet, flippers) that waddles across the road
## where the model puts it, flops onto its belly to slide through the middle and gets up at the
## edges; a bowled-over penguin lies on its back until the model stands it up again.

const Penguins := preload("res://scripts/penguins.gd")

const HEIGHT := 1.7                   # m a penguin stands tall (for the tests)
const BELLY_LIFT := 0.6               # m the body pivot sits above the ice while sliding / lying
const POSE_RATE := 6.0                # per s the pose eases between standing and sliding
const WADDLE_RATE := 9.0              # rad/s of the waddle sway
const WADDLE_ROLL := 0.14             # rad of side-to-side sway while waddling
const BACK := Color(0.08, 0.08, 0.1)
const FRONT := Color(0.96, 0.96, 0.98)
const BEAK := Color(0.95, 0.6, 0.15)
const EYE := Color(0.98, 0.98, 1.0)
const PUPIL := Color(0.05, 0.05, 0.06)

var penguins                # Penguins model
var spots: Array = []       # Node3D per penguin (on the road, turned the way it goes)
var bodies: Array = []      # Node3D per penguin (the posed body), in penguins.penguins order
var slide_pose: Array = []  # 0 = standing, 1 = on its belly, per penguin
var facing: Array = []      # +1 = moving right of the centreline, -1 = left, per penguin
var waddle_t := 0.0

func _init(model) -> void:
	penguins = model

func _ready() -> void:
	for i in penguins.penguins.size():
		var spot := Node3D.new()
		spot.name = "Spot%d" % i
		add_child(spot)
		spots.append(spot)
		var body := Node3D.new()
		body.name = "Penguin%d" % i
		spot.add_child(body)
		_build_penguin(body)
		bodies.append(body)
		slide_pose.append(1.0 if penguins.is_sliding(i) else 0.0)
		facing.append(1 if penguins.across_speed(i) >= 0.0 else -1)
	update_penguins(0.0)

## Advances the model and moves and poses every penguin. Called every physics frame.
func update_penguins(delta: float) -> void:
	penguins.step(delta)
	waddle_t += delta
	for i in bodies.size():
		var p: Dictionary = penguins.penguins[i]
		var spot: Node3D = spots[i]
		var body: Node3D = bodies[i]
		spot.position = penguins.position(i)
		var v: float = penguins.across_speed(i)
		if absf(v) > 0.05:
			facing[i] = 1 if v > 0.0 else -1
		var fwd: Vector3 = penguins.track.right_of(p.idx) * facing[i]
		spot.rotation.y = atan2(-fwd.x, -fwd.z)
		var down: bool = penguins.is_down(i)
		var target: float = 1.0 if penguins.is_sliding(i) else 0.0
		slide_pose[i] = move_toward(slide_pose[i], target, POSE_RATE * delta)
		if down:
			# on its back, feet in the air
			body.rotation.x = PI * 0.5
			body.rotation.z = 0.0
			body.position.y = BELLY_LIFT
		else:
			var s: float = slide_pose[i]
			body.rotation.x = -PI * 0.5 * s
			body.rotation.z = WADDLE_ROLL * sin(waddle_t * WADDLE_RATE + i) * (1.0 - s)
			body.position.y = BELLY_LIFT * s

## Penguin: egg-shaped black body with a white front, two eyes, an orange beak pointing forward
## (-Z), flippers out to the sides and flat orange feet.
func _build_penguin(body: Node3D) -> void:
	var back := _sphere(body, 0.6, Vector3(0, 0.85, 0), BACK)
	back.scale = Vector3(1.0, 1.4, 0.95)
	var front := _sphere(body, 0.48, Vector3(0, 0.72, -0.22), FRONT)
	front.scale = Vector3(0.85, 1.25, 0.7)
	for sx in [-0.17, 0.17]:
		_sphere(body, 0.1, Vector3(sx, 1.38, -0.47), EYE)
		_sphere(body, 0.05, Vector3(sx, 1.38, -0.55), PUPIL)
	var beak := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.3, 0.38, 0.22)
	beak.mesh = prism
	beak.material_override = _mat(BEAK)
	beak.position = Vector3(0, 1.2, -0.72)
	beak.rotation.x = -PI * 0.5          # the prism's point goes forward
	body.add_child(beak)
	for sx in [-1.0, 1.0]:
		var flipper := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.12, 0.7, 0.32)
		flipper.mesh = fb
		flipper.material_override = _mat(BACK)
		flipper.position = Vector3(sx * 0.66, 0.78, 0.0)
		flipper.rotation.z = -sx * 0.35
		body.add_child(flipper)
		var foot := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.28, 0.08, 0.5)
		foot.mesh = fm
		foot.material_override = _mat(BEAK)
		foot.position = Vector3(sx * 0.22, 0.04, -0.12)
		body.add_child(foot)

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
