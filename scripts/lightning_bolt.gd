extends Node3D
## Lightning bolt visual: a jagged chain of glowing thin boxes from the sky down to a kart,
## fading out over LIFETIME seconds. build() makes it, tick() returns false once it is done.

const LIFETIME := 0.5
const HEIGHT := 40.0
const SEGMENTS := 10
const JITTER := 1.6

var age := 0.0
var points: PackedVector3Array = PackedVector3Array()
var materials: Array[StandardMaterial3D] = []

## Jagged top-to-bottom polyline ending exactly at `ground`. Deterministic per seed.
static func make_points(ground: Vector3, seed_value := 1) -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector3Array()
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var p := ground + Vector3(0, HEIGHT * (1.0 - t), 0)
		if i > 0 and i < SEGMENTS:
			p += Vector3(rng.randf_range(-JITTER, JITTER), 0, rng.randf_range(-JITTER, JITTER))
		pts.append(p)
	return pts

func build(ground: Vector3, seed_value := 0) -> void:
	points = make_points(ground, seed_value if seed_value != 0 else int(ground.x * 31.0 + ground.z * 17.0) + 1)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, a.distance_to(b), 0.35)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 1.0, 0.7, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.95, 0.5)
		mat.emission_energy_multiplier = 4.0
		mi.material_override = mat
		materials.append(mat)
		add_child(mi)
		mi.position = (a + b) * 0.5
		var dir := (b - a).normalized()
		var axis := Vector3.UP.cross(dir)
		if axis.length() > 0.0001:
			mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))

## Advance the fade; false when the bolt has finished.
func tick(delta: float) -> bool:
	age += delta
	var a := clampf(1.0 - age / LIFETIME, 0.0, 1.0)
	for m in materials:
		m.albedo_color.a = a
	return age < LIFETIME
