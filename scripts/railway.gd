extends Node3D
## Mario Kart 64 Kalimari Desert railway, built from a TrackData rail and driven by a Train model:
## rails and sleepers along the loop, a crossbuck signal with two alternating red lamps before each
## level crossing, and the steam trains themselves (locomotive with a smoking chimney, tender and
## coaches) moved along the rail every frame.

const Train := preload("res://scripts/train.gd")

const RAIL_HALF_GAUGE := 0.75
const SIGNAL_SIDE := 2.2       # the signal post stands this far beyond the road edge (behind the wall)
const SIGNAL_SAMPLES := 4      # road samples before the crossing centre
const LAMP_COLOR := Color(1.0, 0.1, 0.1)

var data                       # TrackData
var train                      # Train model
var cars: Array = []           # cars[t][c] -> Node3D
var lamps: Array = []          # lamps[ci] -> [MeshInstance3D, MeshInstance3D]
var smoke: Array[GPUParticles3D] = []

func _init(track_data, train_model) -> void:
	data = track_data
	train = train_model

func _ready() -> void:
	_build_rails()
	_build_signals()
	_build_trains()
	update_train(0.0)

## Advances the trains and moves every car and the signal lamps. Called every physics frame.
func update_train(delta: float) -> void:
	train.step(delta)
	for t in cars.size():
		for c in cars[t].size():
			var p: Dictionary = train.car_pose(t, c)
			var car: Node3D = cars[t][c]
			car.position = p.pos
			car.rotation.y = atan2(-p.dir.x, -p.dir.z)
	var phase: int = train.lamp_phase()
	for ci in lamps.size():
		var on: bool = train.blocked(ci)
		for i in 2:
			var m := lamps[ci][i].material_override as StandardMaterial3D
			var lit: bool = on and i == phase
			m.emission_enabled = lit
			m.albedo_color = LAMP_COLOR if lit else LAMP_COLOR.darkened(0.7)

func _build_rails() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = data.rail.size()
	var steel := Color(0.4, 0.4, 0.42)
	var wood := Color(0.42, 0.28, 0.15)
	for i in n:
		var a: Vector3 = data.rail[i]
		var b: Vector3 = data.rail[(i + 1) % n]
		var dir := (b - a).normalized()
		var r := Vector3(-dir.z, 0, dir.x)
		# sleeper across the rail at every sample
		var sa := a - dir * 0.25
		var sb := a + dir * 0.25
		_quad(st, sa - r * 1.2, sb - r * 1.2, sb + r * 1.2, sa + r * 1.2, 0.035, wood)
		# two rails
		for side in [-1.0, 1.0]:
			var o: Vector3 = r * (RAIL_HALF_GAUGE * side)
			_quad(st, a + o - r * 0.06, b + o - r * 0.06, b + o + r * 0.06, a + o + r * 0.06, 0.06, steel)
	var mi := MeshInstance3D.new()
	mi.name = "Rails"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.6
	mat.metallic = 0.3
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, y: float, col: Color) -> void:
	var up := Vector3(0, y, 0)
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(v + up)

## One crossbuck signal per crossing on the right of the road a few samples before it.
func _build_signals() -> void:
	for ci in data.crossings.size():
		var c: Dictionary = data.crossings[ci]
		var idx: int = posmod(c.road - SIGNAL_SAMPLES, data.count)
		var post := Node3D.new()
		post.name = "Signal%d" % ci
		post.position = data.points[idx] + data.right_of(idx) * (data.width * 0.5 + SIGNAL_SIDE)
		post.rotation.y = data.heading_at(idx)
		add_child(post)
		_box(post, Vector3(0.16, 3.4, 0.16), Vector3(0, 1.7, 0), Color(0.75, 0.75, 0.75))
		for rz in [PI / 4.0, -PI / 4.0]:
			var arm := _box(post, Vector3(1.7, 0.24, 0.08), Vector3(0, 3.0, 0.1), Color(1, 1, 1))
			arm.rotation.z = rz
		_box(post, Vector3(1.1, 0.5, 0.1), Vector3(0, 2.1, 0.08), Color(0.12, 0.12, 0.14))
		var pair: Array = []
		for x in [-0.35, 0.35]:
			var lamp := _sphere(post, 0.16, Vector3(x, 2.1, 0.18), LAMP_COLOR.darkened(0.7))
			(lamp.material_override as StandardMaterial3D).emission = LAMP_COLOR * 2.5
			pair.append(lamp)
		lamps.append(pair)

func _build_trains() -> void:
	for t in Train.TRAIN_COUNT:
		var row: Array = []
		for c in Train.CARS:
			var car := Node3D.new()
			car.name = "Train%dCar%d" % [t, c]
			add_child(car)
			if c == 0:
				_build_locomotive(car)
			elif c == 1:
				_build_tender(car)
			else:
				_build_coach(car, c)
			row.append(car)
		cars.append(row)

## Forward is -Z (like the karts). Black boiler and cab, red trim, a chimney puffing smoke, "64" plate.
func _build_locomotive(car: Node3D) -> void:
	var black := Color(0.1, 0.1, 0.11)
	var red := Color(0.8, 0.08, 0.08)
	_wheels(car, black)
	_box(car, Vector3(2.0, 0.4, 4.4), Vector3(0, 0.9, 0), black)                  # frame
	var boiler := _cyl(car, 0.8, 2.8, Vector3(0, 1.75, -0.6), black)
	boiler.rotation.x = PI / 2.0
	_box(car, Vector3(2.0, 1.9, 1.5), Vector3(0, 1.95, 1.4), red)                 # cab
	_box(car, Vector3(2.2, 0.15, 1.7), Vector3(0, 2.95, 1.4), black)              # cab roof
	_cyl(car, 0.26, 0.9, Vector3(0, 2.9, -1.5), black)                           # chimney
	_cyl(car, 0.3, 0.3, Vector3(0, 2.6, 0.2), red)                               # steam dome
	_box(car, Vector3(2.0, 0.6, 0.7), Vector3(0, 0.45, -2.25), red)              # cowcatcher
	_sphere(car, 0.2, Vector3(0, 2.0, -2.05), Color(1.0, 0.95, 0.6))             # headlamp
	var plate := Label3D.new()
	plate.text = "64"
	plate.font_size = 96
	plate.pixel_size = 0.006
	plate.outline_size = 16
	plate.modulate = Color(1.0, 0.85, 0.1)
	plate.position = Vector3(0, 1.3, -2.26)
	plate.rotation.y = PI
	car.add_child(plate)
	var puff := _make_smoke()
	puff.position = Vector3(0, 3.4, -1.5)
	car.add_child(puff)
	smoke.append(puff)

func _build_tender(car: Node3D) -> void:
	var black := Color(0.1, 0.1, 0.11)
	_wheels(car, black)
	_box(car, Vector3(2.0, 1.6, 4.2), Vector3(0, 1.3, 0), black)
	_box(car, Vector3(1.7, 0.4, 3.6), Vector3(0, 2.25, 0), Color(0.2, 0.17, 0.14))   # coal

func _build_coach(car: Node3D, c: int) -> void:
	var body := Color(0.2, 0.5, 0.25) if c % 2 == 0 else Color(0.85, 0.75, 0.45)
	_wheels(car, Color(0.1, 0.1, 0.11))
	_box(car, Vector3(2.0, 1.7, 4.4), Vector3(0, 1.45, 0), body)
	_box(car, Vector3(2.2, 0.2, 4.6), Vector3(0, 2.4, 0), Color(0.5, 0.1, 0.1))     # roof
	for x in [-1.01, 1.01]:
		for z in [-1.4, 0.0, 1.4]:
			_box(car, Vector3(0.04, 0.7, 0.8), Vector3(x, 1.65, z), Color(0.35, 0.6, 0.85))   # windows

func _wheels(car: Node3D, col: Color) -> void:
	for x in [-0.9, 0.9]:
		for z in [-1.4, 1.4]:
			var w := _cyl(car, 0.45, 0.25, Vector3(x, 0.45, z), col)
			w.rotation.z = PI / 2.0

func _make_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 1.8
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 16, 24))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.85, 0.85, 0.85, 0.9), Color(0.6, 0.6, 0.6, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var s := SphereMesh.new()
	s.radius = 0.4
	s.height = 0.8
	s.radial_segments = 8
	s.rings = 4
	var sm := StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material = sm
	p.draw_pass_1 = s
	return p

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
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi
