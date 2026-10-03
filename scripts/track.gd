extends Node3D
## Builds the visible/solid track from TrackData: road ribbon, striped walls with
## collision, start gate and animated boost pads.

const TrackData := preload("res://scripts/track_data.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

var data: TrackData
var wall_height := 1.4
var wall_offset := 0.8   # wall centre distance beyond the road edge
var banner_text := "START"
var _banner_labels: Array[Label3D] = []
var _banner_panel: MeshInstance3D

## Sets the start-gate banner text ("START", "CONTINUE" or "FINISH") and its colours.
func set_banner(text: String) -> void:
	banner_text = text
	var bg := Color(0.1, 0.25, 0.8)
	var fg := Color(1.0, 0.85, 0.1)
	if text == "START":
		bg = Color(0.05, 0.55, 0.15)
		fg = Color(1, 1, 1)
	elif text == "FINISH":
		bg = Color(0.75, 0.05, 0.05)
		fg = Color(1, 1, 1)
	for lbl in _banner_labels:
		lbl.text = text
		lbl.modulate = fg
		lbl.outline_modulate = UiStyle.board_rim(bg)
	if _banner_panel != null:
		(_banner_panel.material_override as StandardMaterial3D).albedo_color = bg

func _init(track_data: TrackData = null) -> void:
	data = track_data if track_data != null else TrackData.new()

func _ready() -> void:
	_build_road()
	_build_walls()
	_build_water()
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
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset := data.width * 0.5 + wall_offset
	var half := 0.4   # half wall thickness
	var h := Vector3(0, wall_height, 0)
	for side in [-1.0, 1.0]:
		# One cross-section per track sample, shared by both neighbouring segments, so the wall
		# is a single gap-free ribbon (no overlapping boxes) even on tight curves.
		var inner: Array[Vector3] = []
		var outer: Array[Vector3] = []
		for i in data.count:
			var c: Vector3 = data.points[i] + data.right_of(i) * offset * side
			var r: Vector3 = data.right_of(i)
			inner.append(c - r * half)
			outer.append(c + r * half)
		for i in data.count:
			var j := (i + 1) % data.count
			if not data.has_wall(i, int(side)):
				continue   # water span: no wall, the road edge is open
			var red := (i / 2) % 2 == 0
			var col := Color(0.85, 0.02, 0.02) if red else Color(1.0, 1.0, 1.0)
			var rn: Vector3 = data.right_of(i)
			_wall_quad(st, outer[i], outer[j], outer[j] + h, outer[i] + h, rn, col)
			_wall_quad(st, inner[j], inner[i], inner[i] + h, inner[j] + h, -rn, col)
			_wall_quad(st, inner[i] + h, outer[i] + h, outer[j] + h, inner[j] + h, Vector3.UP, col)
			# Convex prism per segment sharing its corner vertices with the neighbours: seamless collision.
			var cs := CollisionShape3D.new()
			var shape := ConvexPolygonShape3D.new()
			shape.points = PackedVector3Array([
				inner[i], outer[i], inner[j], outer[j],
				inner[i] + h, outer[i] + h, inner[j] + h, outer[j] + h])
			cs.shape = shape
			body.add_child(cs)
	var mmi := MeshInstance3D.new()
	mmi.name = "WallMesh"
	mmi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Steady walls: no shadow flicker/acne on the tops. No emission glow (it washed out the red).
	mat.disable_receive_shadows = true
	mat.roughness = 0.8
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _wall_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)

## Water beside the road along every water span (Mario Kart 64 hazard): a blue ribbon from the
## open road edge out to WATER_WIDTH, with a sandy bank strip where the wall would have stood.
func _build_water() -> void:
	if data.water.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var near := data.width * 0.5 + TrackData.WATER_EDGE
	var far := near + TrackData.WATER_WIDTH
	var bank := data.width * 0.5
	for w in data.water:
		for i in range(w.start, w.end + 1):
			var j := (i + 1) % data.count
			var ri: Vector3 = data.right_of(i) * w.side
			var rj: Vector3 = data.right_of(j) * w.side
			var a: Vector3 = data.points[i]
			var b: Vector3 = data.points[j]
			# bank
			_wall_quad(st, a + ri * bank, b + rj * bank, b + rj * near, a + ri * near, Vector3.UP, Color(0.85, 0.75, 0.45))
			# water (lighter near the shore)
			var shade := 0.75 if i % 2 == 0 else 0.7
			_wall_quad(st, a + ri * near, b + rj * near, b + rj * far, a + ri * far, Vector3.UP, Color(0.15, 0.45 * shade + 0.1, 0.9 * shade + 0.1))
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.15
	mat.metallic = 0.2
	mi.material_override = mat
	mi.position.y = 0.015
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

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
	# Mario Kart 64 style gate: candy-striped posts holding a banner with checkered edges.
	for s in [-1.0, 1.0]:
		for k in 8:
			var stripe := Color(0.9, 0.1, 0.1) if k % 2 == 0 else Color(1, 1, 1)
			_box(gate, Vector3(0.7, 0.95, 0.7), Vector3(s * (hw + 0.5), 0.475 + k * 0.95, 0), stripe)
	var banner_w := data.width + 2.0
	_banner_panel = _box(gate, Vector3(banner_w, 2.4, 0.4), Vector3(0, 6.2, 0), Color(0.1, 0.25, 0.8))
	var checks := int(banner_w / 0.6)
	var check_w := banner_w / checks
	for cx in checks:
		for row in 2:
			var c := Color(0.05, 0.05, 0.05) if (cx + row) % 2 == 0 else Color(1, 1, 1)
			var y := 6.2 + (1.2 + 0.15) if row == 0 else 6.2 - (1.2 + 0.15)
			_box(gate, Vector3(check_w, 0.3, 0.45), Vector3(-banner_w * 0.5 + check_w * (cx + 0.5), y, 0), c)
	for face in [1.0, -1.0]:
		var lbl := Label3D.new()
		lbl.pixel_size = 0.0125
		# rounded font with a thin rim in the banner's shade (set_banner) instead of a thick dark outline
		UiStyle.style_label3d(lbl, 128, Color(1.0, 0.85, 0.1), UiStyle.board_rim(Color(0.1, 0.25, 0.8)))
		lbl.position = Vector3(0, 6.2, face * 0.22)
		lbl.rotation.y = 0.0 if face > 0 else PI
		lbl.text = banner_text
		gate.add_child(lbl)
		_banner_labels.append(lbl)
	set_banner(banner_text)
	# checkered start line on the road
	var cols := 8
	var cell := data.width / cols
	for cx in cols:
		for cz in 2:
			if (cx + cz) % 2 == 0:
				_box(gate, Vector3(cell, 0.03, 1.0), Vector3(-hw + cell * (cx + 0.5), 0.045, -0.5 + cz), Color(0.05, 0.05, 0.05))
			else:
				_box(gate, Vector3(cell, 0.03, 1.0), Vector3(-hw + cell * (cx + 0.5), 0.045, -0.5 + cz), Color(0.95, 0.95, 0.95))

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

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
