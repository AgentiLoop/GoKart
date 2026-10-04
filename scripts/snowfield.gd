extends Node3D
## Mario Kart 64 Frappe Snowland snowmen node, driven by a Snowmen model: a procedural snowman per
## entry (three snowballs, coal eyes, carrot nose, red scarf, black top hat, stick arms) facing the
## oncoming racers. A smashed snowman bursts into a puff of snowballs and grows back out of the snow
## as the model says.

const Snowmen := preload("res://scripts/snowmen.gd")

const HEIGHT := 2.1                   # m a whole snowman stands tall (for the puff and the tests)
const PUFF_TIME := 0.7                # s the burst of snow lasts
const PUFF_COUNT := 8
const SNOW := Color(0.97, 0.97, 1.0)
const COAL := Color(0.05, 0.05, 0.06)
const CARROT := Color(0.95, 0.5, 0.1)
const SCARF := Color(0.85, 0.1, 0.12)
const STICK := Color(0.4, 0.26, 0.12)

var snowmen                 # Snowmen model
var bodies: Array = []      # Node3D per snowman (scaled with its height), in snowmen.snowmen order
var puffs: Array = []       # Node3D per snowman holding the burst snowballs
var puff_time: Array = []   # s since the burst started per snowman (>= PUFF_TIME: no puff showing)
var standing: Array = []    # whether each snowman stood last frame (a drop means it was smashed)

func _init(model) -> void:
	snowmen = model

func _ready() -> void:
	for i in snowmen.snowmen.size():
		var sm: Dictionary = snowmen.snowmen[i]
		var spot := Node3D.new()
		spot.name = "Spot%d" % i
		spot.position = sm.pos
		var fwd: Vector3 = -snowmen.track.tangents[sm.idx]   # looks back down the road at the racers
		spot.rotation.y = atan2(-fwd.x, -fwd.z)
		add_child(spot)
		var body := Node3D.new()
		body.name = "Snowman%d" % i
		spot.add_child(body)
		_build_snowman(body)
		bodies.append(body)
		var puff := Node3D.new()
		puff.name = "Puff%d" % i
		spot.add_child(puff)
		for p in PUFF_COUNT:
			_sphere(puff, 0.22, Vector3.ZERO, SNOW)
		puff.visible = false
		puffs.append(puff)
		puff_time.append(PUFF_TIME)
		standing.append(snowmen.is_standing(i))
	update_snowmen(0.0)

## Advances the model, grows the snowmen and plays the bursts. Called every physics frame.
func update_snowmen(delta: float) -> void:
	snowmen.step(delta)
	for i in bodies.size():
		var h: float = snowmen.height(i)
		var body: Node3D = bodies[i]
		body.scale = Vector3.ONE * maxf(h, 0.001)
		body.visible = h > 0.0
		var up: bool = snowmen.is_standing(i)
		if standing[i] and not up:
			puff_time[i] = 0.0
		standing[i] = up
		_update_puff(i, delta)

## The burst: snowballs fly out and up from the smashed snowman, falling and shrinking away.
func _update_puff(i: int, delta: float) -> void:
	var puff: Node3D = puffs[i]
	puff_time[i] += delta
	if puff_time[i] >= PUFF_TIME:
		puff.visible = false
		return
	puff.visible = true
	var t: float = puff_time[i] / PUFF_TIME
	for p in puff.get_child_count():
		var ball: Node3D = puff.get_child(p)
		var ang: float = TAU * p / puff.get_child_count()
		var r: float = 0.6 + 2.2 * t
		ball.position = Vector3(cos(ang) * r, HEIGHT * 0.5 + 2.0 * t - 3.0 * t * t, sin(ang) * r)
		ball.scale = Vector3.ONE * (1.0 - t)

## Snowman: three snowballs, coal eyes and buttons, a carrot nose, a red scarf, a black top hat and
## two stick arms. Forward is -Z (its face). Stands HEIGHT tall.
func _build_snowman(body: Node3D) -> void:
	_sphere(body, 0.75, Vector3(0, 0.6, 0), SNOW)                     # base
	_sphere(body, 0.55, Vector3(0, 1.45, 0), SNOW)                    # middle
	_sphere(body, 0.4, Vector3(0, 2.1 - 0.4, 0), SNOW)                # head (top at HEIGHT)
	for sx in [-0.14, 0.14]:
		_sphere(body, 0.06, Vector3(sx, 1.8, -0.36), COAL)            # eyes
	for y in [1.35, 1.55]:
		_sphere(body, 0.05, Vector3(0, y, -0.53), COAL)               # buttons
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.4
	cone.radial_segments = 8
	nose.mesh = cone
	nose.material_override = _mat(CARROT)
	nose.position = Vector3(0, 1.68, -0.55)
	nose.rotation.x = -PI * 0.5                                       # points forward
	body.add_child(nose)
	_cylinder(body, 0.42, 0.14, Vector3(0, 1.98 - 0.06, 0), SCARF)    # scarf round the neck
	_cylinder(body, 0.45, 0.05, Vector3(0, 2.1 - 0.02, 0), COAL)      # hat brim
	_cylinder(body, 0.3, 0.42, Vector3(0, 2.1 + 0.21, 0), COAL)       # hat crown
	for sx in [-1, 1]:
		var arm := _cylinder(body, 0.035, 0.9, Vector3(sx * 0.8, 1.6, 0), STICK)
		arm.rotation.z = sx * -1.2                                     # sticks out and up

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

static func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi
