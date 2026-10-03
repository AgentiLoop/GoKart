extends Node3D
## Mario Kart 64 battle gear on a kart: up to three balloons in the kart's colour bobbing on
## strings above the driver, swapped for a Mini Bomb Kart body (black bomb with a lit fuse) once
## every balloon is gone. Built in _init so it works without a scene tree.

const BALLOON_RADIUS := 0.42
const STRING_LENGTH := 1.1
const BASE_HEIGHT := 1.9
const SPREAD := 0.5

var count := 3
var bomb := false
var time := 0.0
var _balloons: Array[Node3D] = []
var _bomb: Node3D
var _fuse_spark: MeshInstance3D

func _init(color := Color(0.9, 0.1, 0.1), n := 3) -> void:
	count = n
	for i in n:
		var root := Node3D.new()
		var a := TAU * i / n
		root.position = Vector3(cos(a) * SPREAD, BASE_HEIGHT + STRING_LENGTH, sin(a) * SPREAD)
		add_child(root)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = BALLOON_RADIUS
		sm.height = BALLOON_RADIUS * 2.3
		ball.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.lightened(0.15)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.35
		ball.material_override = mat
		root.add_child(ball)
		var string := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.015
		cm.bottom_radius = 0.015
		cm.height = STRING_LENGTH
		string.mesh = cm
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.9, 0.9, 0.9)
		string.material_override = smat
		string.position = Vector3(-cos(a) * SPREAD * 0.5, -STRING_LENGTH * 0.5 - BALLOON_RADIUS * 0.6, -sin(a) * SPREAD * 0.5)
		string.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
		root.add_child(string)
		_balloons.append(root)
	_bomb = Node3D.new()
	_bomb.visible = false
	add_child(_bomb)
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.75
	bm.height = 1.5
	body.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.08, 0.08, 0.1)
	bmat.metallic = 0.4
	bmat.roughness = 0.35
	body.material_override = bmat
	body.position.y = 0.85
	_bomb.add_child(body)
	var cap := MeshInstance3D.new()
	var capm := CylinderMesh.new()
	capm.top_radius = 0.18
	capm.bottom_radius = 0.18
	capm.height = 0.2
	cap.mesh = capm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.75, 0.75, 0.8)
	cap.material_override = cmat
	cap.position.y = 1.65
	_bomb.add_child(cap)
	var fuse := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.04
	fm.bottom_radius = 0.04
	fm.height = 0.4
	fuse.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.8, 0.7, 0.4)
	fuse.material_override = fmat
	fuse.position = Vector3(0.1, 1.9, 0)
	fuse.rotation.z = -0.4
	_bomb.add_child(fuse)
	_fuse_spark = MeshInstance3D.new()
	var spm := SphereMesh.new()
	spm.radius = 0.12
	spm.height = 0.24
	_fuse_spark.mesh = spm
	var spmat := StandardMaterial3D.new()
	spmat.albedo_color = Color(1.0, 0.8, 0.2)
	spmat.emission_enabled = true
	spmat.emission = Color(1.0, 0.6, 0.1)
	spmat.emission_energy_multiplier = 3.0
	_fuse_spark.material_override = spmat
	_fuse_spark.position = Vector3(0.25, 2.07, 0)
	_bomb.add_child(_fuse_spark)
	# wheels so the bomb still looks like a kart
	for x in [-0.6, 0.6]:
		for z in [-0.5, 0.5]:
			var w := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.28
			wm.bottom_radius = 0.28
			wm.height = 0.3
			w.mesh = wm
			var wmat := StandardMaterial3D.new()
			wmat.albedo_color = Color(0.12, 0.12, 0.14)
			w.material_override = wmat
			w.position = Vector3(x, 0.28, z)
			w.rotation.z = PI / 2.0
			_bomb.add_child(w)
	set_count(n)

## Show `n` balloons (the rest are popped away).
func set_count(n: int) -> void:
	count = clampi(n, 0, _balloons.size())
	for i in _balloons.size():
		_balloons[i].visible = i < count and not bomb

## Switch the kart into (or out of) its Mini Bomb Kart look.
func set_bomb(on: bool) -> void:
	bomb = on
	_bomb.visible = on
	set_count(count)

func visible_balloons() -> int:
	var n := 0
	for b in _balloons:
		if b.visible:
			n += 1
	return n

func _process(delta: float) -> void:
	time += delta
	for i in _balloons.size():
		var a := TAU * i / _balloons.size()
		_balloons[i].position.y = BASE_HEIGHT + STRING_LENGTH + 0.12 * sin(time * 2.2 + a)
		_balloons[i].rotation.z = 0.08 * sin(time * 1.7 + a)
	if bomb:
		_fuse_spark.scale = Vector3.ONE * (0.7 + 0.5 * absf(sin(time * 14.0)))
