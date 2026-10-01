extends Node3D
## Bootstrap scene: ground, light, kart and chase camera.

const Kart := preload("res://scripts/kart.gd")
const SpeedFx := preload("res://scripts/speed_fx.gd")
var kart: CharacterBody3D
var cam: Camera3D
var speed_fx

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.glow_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := StaticBody3D.new()
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(400, 1, 400)
	gcol.shape = gshape
	ground.add_child(gcol)
	var gmesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(400, 1, 400)
	gmesh.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.25, 0.6, 0.25)
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	ground.position.y = -0.5
	add_child(ground)

	kart = Kart.new()
	kart.position = Vector3(0, 0.1, 0)
	add_child(kart)
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	add_child(cam)
	speed_fx = SpeedFx.new()
	add_child(speed_fx)

func _process(delta: float) -> void:
	var back := Vector3(sin(kart.heading), 0, cos(kart.heading))
	var target := kart.global_position + back * 6.0 + Vector3(0, 3.0, 0)
	cam.global_position = cam.global_position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	cam.look_at(kart.global_position + Vector3(0, 1.0, 0))
	var ratio: float = absf(kart.model.speed) / kart.model.max_speed
	speed_fx.update_fx(delta, ratio, kart.model.is_boosting())
	cam.fov = lerpf(cam.fov, 70.0 + 10.0 * speed_fx.speed_amount + 12.0 * speed_fx.boost_amount, clampf(5.0 * delta, 0.0, 1.0))
