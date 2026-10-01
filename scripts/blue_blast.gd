extends Node3D
## Blue shell explosion visual: a glowing sphere that expands and fades over LIFETIME
## seconds. build() places it, tick() returns false once it is done.

const LIFETIME := 0.6
const START_RADIUS := 0.5

var age := 0.0
var end_radius := 7.0
var material: StandardMaterial3D
var mesh: SphereMesh

## Radius of the blast sphere after `age` seconds (ease-out growth).
static func radius_at(age_s: float, final_radius: float) -> float:
	var t := clampf(age_s / LIFETIME, 0.0, 1.0)
	return lerpf(START_RADIUS, final_radius, 1.0 - (1.0 - t) * (1.0 - t))

func build(at: Vector3, final_radius := 7.0) -> void:
	end_radius = final_radius
	position = at
	mesh = SphereMesh.new()
	mesh.radius = START_RADIUS
	mesh.height = START_RADIUS * 2.0
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.3, 0.6, 1.0, 0.9)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.5, 1.0)
	material.emission_energy_multiplier = 4.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)

## Advance the blast; false when it has finished.
func tick(delta: float) -> bool:
	age += delta
	var r := radius_at(age, end_radius)
	mesh.radius = r
	mesh.height = r * 2.0
	material.albedo_color.a = clampf(1.0 - age / LIFETIME, 0.0, 1.0) * 0.9
	return age < LIFETIME
