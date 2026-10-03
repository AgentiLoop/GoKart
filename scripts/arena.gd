extends Node3D
## Builds the visible / solid battle arena from ArenaData: the floor, striped outer walls with
## collision (when walled), the solid forts, the lava pit and the four start pads.

const ArenaData := preload("res://scripts/arena_data.gd")

const WALL_HEIGHT := 1.6
const WALL_THICKNESS := 0.8
const BLOCK_HEIGHT := 5.0
const LAVA_COLORS := [Color(1.0, 0.35, 0.05), Color(1.0, 0.6, 0.1)]

var data
var wall_count := 0
var block_count := 0

func _init(arena_data = null) -> void:
	data = arena_data if arena_data != null else ArenaData.make(0)

func _ready() -> void:
	_build_floor()
	if data.walled:
		_build_walls()
	_build_blocks()
	if data.pit_radius > 0.0:
		_build_pit()
	_build_pads()

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)

func _vertex_mesh(st: SurfaceTool, mesh_name: String, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.85
	if not shadows:
		mat.disable_receive_shadows = true
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = mat
	add_child(mi)
	return mi

## Chequered floor tiles across the arena (slightly above the world ground plane).
func _build_floor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile := 6.0
	var n := int(ceil(data.half * 2.0 / tile))
	for ix in n:
		for iz in n:
			var x0: float = -data.half + ix * tile
			var z0: float = -data.half + iz * tile
			var shade := 0.34 if (ix + iz) % 2 == 0 else 0.4
			var col := Color(shade, shade, shade + 0.03)
			_quad(st, Vector3(x0, 0.02, z0), Vector3(x0 + tile, 0.02, z0), Vector3(x0 + tile, 0.02, z0 + tile), Vector3(x0, 0.02, z0 + tile), Vector3.UP, col)
	_vertex_mesh(st, "Floor")

## Red / white striped walls around the square, one convex collider per side.
func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := Vector3(0, WALL_HEIGHT, 0)
	var half: float = data.half
	var t := WALL_THICKNESS
	var seg := 4.0
	# four sides: (start corner, direction along the side, outward normal)
	var sides := [
		[Vector3(-half, 0, -half), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(half, 0, -half), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(half, 0, half), Vector3(-1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(-half, 0, half), Vector3(0, 0, -1), Vector3(-1, 0, 0)],
	]
	for s in sides:
		var start: Vector3 = s[0]
		var dir: Vector3 = s[1]
		var out: Vector3 = s[2]
		var n := int(half * 2.0 / seg)
		for i in n:
			var a: Vector3 = start + dir * (i * seg)
			var b: Vector3 = start + dir * ((i + 1) * seg)
			var col := Color(0.85, 0.02, 0.02) if i % 2 == 0 else Color(1, 1, 1)
			_quad(st, a - out * t, b - out * t, b - out * t + h, a - out * t + h, -out, col)
			_quad(st, b + out * t, a + out * t, a + out * t + h, b + out * t + h, out, col)
			_quad(st, a - out * t + h, b - out * t + h, b + out * t + h, a + out * t + h, Vector3.UP, col)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var length := half * 2.0 + t * 2.0
		shape.size = Vector3(length if dir.x != 0.0 else t * 2.0, WALL_HEIGHT, length if dir.z != 0.0 else t * 2.0)
		cs.shape = shape
		cs.position = start + dir * half + Vector3(0, WALL_HEIGHT * 0.5, 0)
		body.add_child(cs)
		wall_count += 1
	_vertex_mesh(st, "WallMesh", false)

## Solid forts: tall boxes with a box collider each.
func _build_blocks() -> void:
	for b in data.blocks:
		var body := StaticBody3D.new()
		body.name = "Block"
		var size := Vector3(b.size.x, BLOCK_HEIGHT, b.size.y)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = size
		mi.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.3, 0.2)
		mi.material_override = mat
		body.add_child(mi)
		# a lighter roof slab
		var roof := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(size.x + 0.6, 0.4, size.z + 0.6)
		roof.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.75, 0.5, 0.35)
		roof.material_override = rmat
		roof.position.y = size.y * 0.5 + 0.2
		body.add_child(roof)
		body.position = Vector3(b.get_center().x, size.y * 0.5, b.get_center().y)
		add_child(body)
		block_count += 1

## Glowing lava disc sunk into the centre (no collider: karts drive in and get fished out).
func _build_pit() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r: float = data.pit_radius
	var n := 32
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var col: Color = LAVA_COLORS[i % 2]
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(0, -0.3, 0))
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a1) * r, -0.3, sin(a1) * r))
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a0) * r, -0.3, sin(a0) * r))
		# dark rim wall down to the lava
		_quad(st, Vector3(cos(a0) * r, 0.03, sin(a0) * r), Vector3(cos(a1) * r, 0.03, sin(a1) * r), Vector3(cos(a1) * r, -0.3, sin(a1) * r), Vector3(cos(a0) * r, -0.3, sin(a0) * r), Vector3(-cos(a0), 0, -sin(a0)), Color(0.2, 0.08, 0.05))
	var mi := _vertex_mesh(st, "Lava", false)
	var mat: StandardMaterial3D = mi.material_override
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 1.5

## Start pads: a coloured ring on the floor at each spawn.
func _build_pads() -> void:
	for s in data.spawns:
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 2.2
		m.bottom_radius = 2.2
		m.height = 0.04
		mi.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.85, 0.3)
		mi.material_override = mat
		mi.position = Vector3(s.position.x, 0.04, s.position.z)
		mi.name = "StartPad"
		add_child(mi)
