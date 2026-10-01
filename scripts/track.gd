extends Node3D
## Builds the visible/solid track from TrackData: road ribbon, striped walls with
## collision, start gate and animated boost pads.

const TrackData := preload("res://scripts/track_data.gd")

var data: TrackData
var wall_height := 1.4
var wall_offset := 0.8   # wall centre distance beyond the road edge

func _init(track_data: TrackData = null) -> void:
	data = track_data if track_data != null else TrackData.new()

func _ready() -> void:
	_build_road()
	_build_walls()
	_build_start_gate()
	_build_pads()

func _build_road() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := data.width * 0.5
	for i in data.count:
		var j := (i + 1) % data.count
		var a := data.points[i]
		var b := data.points[j]
		var ra := data.right_of(i) * hw
		var rb := data.right_of(j) * hw
		var shade := 0.30 if (i / 3) % 2 == 0 else 0.33
		var col := Color(shade, shade, shade + 0.02)
		var quad := [a - ra, a + ra, b + rb, b - rb]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[idx] + Vector3(0, 0.02, 0))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.9
	mi.material_override = mat
	mi.name = "Road"
	add_child(mi)

func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "Walls"
	add_child(body)
	var xforms: Array[Transform3D] = []
	var offset := data.width * 0.5 + wall_offset
	for side in [-1.0, 1.0]:
		for i in data.count:
			var j := (i + 1) % data.count
			var a: Vector3 = data.points[i] + data.right_of(i) * offset * side
			var b: Vector3 = data.points[j] + data.right_of(j) * offset * side
			var dir := b - a
			var seg_len := dir.length() + 0.15
			var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
			var t := Transform3D(basis, (a + b) * 0.5 + Vector3(0, wall_height * 0.5, 0))
			xforms.append(t)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.8, wall_height, seg_len)
			cs.shape = bs
			cs.transform = t
			body.add_child(cs)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3(0.8, wall_height, 1.0)
	mm.mesh = box
	mm.instance_count = xforms.size()
	for k in xforms.size():
		var t := xforms[k]
		var seg_len := data.spacing + 0.15
		t.basis = t.basis * Basis.from_scale(Vector3(1, 1, seg_len))
		mm.set_instance_transform(k, t)
		mm.set_instance_color(k, Color(0.9, 0.1, 0.1) if (k / 2) % 2 == 0 else Color(0.95, 0.95, 0.95))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	add_child(mmi)

func _build_start_gate() -> void:
	var p: Vector3 = data.points[0]
	var r := data.right_of(0)
	var heading := data.heading_at(0)
	var gate := Node3D.new()
	gate.name = "StartGate"
	gate.position = p
	gate.rotation.y = heading
	add_child(gate)
	var hw := data.width * 0.5
	for s in [-1.0, 1.0]:
		_box(gate, Vector3(0.6, 6.0, 0.6), Vector3(s * (hw + 0.5), 3.0, 0), Color(0.15, 0.15, 0.15))
	_box(gate, Vector3(data.width + 2.0, 1.2, 0.6), Vector3(0, 6.0, 0), Color(1, 1, 1))
	# checkered start line on the road
	var cols := 8
	var cell := data.width / cols
	for cx in cols:
		for cz in 2:
			if (cx + cz) % 2 == 0:
				_box(gate, Vector3(cell, 0.03, 1.0), Vector3(-hw + cell * (cx + 0.5), 0.045, -0.5 + cz), Color(0.05, 0.05, 0.05))
			else:
				_box(gate, Vector3(cell, 0.03, 1.0), Vector3(-hw + cell * (cx + 0.5), 0.045, -0.5 + cz), Color(0.95, 0.95, 0.95))

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

func _build_pads() -> void:
	var shader := load("res://shaders/boost_pad.gdshader") as Shader
	for pad in data.pads:
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(pad.width, pad.length)
		mi.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mi.material_override = mat
		mi.position = pad.center + Vector3(0, 0.05, 0)
		mi.rotation.y = atan2(-pad.forward.x, -pad.forward.z)
		mi.name = "BoostPad"
		add_child(mi)
