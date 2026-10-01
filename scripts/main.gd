extends Node3D
## Race scene: sky, ground, track, kart, chase camera, laps, boost pads and HUD.

const Kart := preload("res://scripts/kart.gd")
const SpeedFx := preload("res://scripts/speed_fx.gd")
const Track := preload("res://scripts/track.gd")
const TrackData := preload("res://scripts/track_data.gd")
const LapTracker := preload("res://scripts/lap_tracker.gd")
const Hud := preload("res://scripts/hud.gd")
const ItemManager := preload("res://scripts/item_manager.gd")

const OFFROAD_SCALE := 0.5
const PAD_BOOST_TIME := 1.2

var kart: CharacterBody3D
var cam: Camera3D
var speed_fx
var track
var tracker
var hud
var items
var kart_index := 0

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.glow_enabled = true
	e.glow_hdr_threshold = 1.0
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
	gshape.size = Vector3(800, 1, 800)
	gcol.shape = gshape
	ground.add_child(gcol)
	var gmesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(800, 1, 800)
	gmesh.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.25, 0.6, 0.25)
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	ground.position = Vector3(60, -0.5, 20)
	add_child(ground)

	track = Track.new()
	add_child(track)
	var data: TrackData = track.data
	tracker = LapTracker.new(data.count, 8, 3)

	kart = Kart.new()
	# start just behind the line, facing along the track
	var start_idx := data.count - 4
	var start_pos: Vector3 = data.points[start_idx] + Vector3(0, 0.1, 0)
	kart.position = start_pos
	kart.heading = data.heading_at(start_idx)
	add_child(kart)
	kart_index = start_idx

	items = ItemManager.new()
	add_child(items)
	items.setup(data, kart)

	cam = Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	add_child(cam)
	cam.global_position = start_pos + _back() * 6.0 + Vector3(0, 3.0, 0)
	speed_fx = SpeedFx.new()
	add_child(speed_fx)
	hud = Hud.new()
	add_child(hud)

func _back() -> Vector3:
	return Vector3(sin(kart.heading), 0, cos(kart.heading))

func _physics_process(delta: float) -> void:
	var data: TrackData = track.data
	var pos := kart.global_position
	kart_index = data.nearest_index(pos, kart_index)
	kart.model.surface_scale = 1.0 if data.is_on_road(pos, kart_index) else OFFROAD_SCALE
	tracker.update(delta, kart_index)
	if data.pad_at(pos) != null:
		kart.model.apply_boost(PAD_BOOST_TIME, 1)
	hud.update_hud(tracker, kart.model.speed, kart.model.is_boosting(), kart.model.drift_level, items.holder.display_item(items.time))

func _process(delta: float) -> void:
	var target := kart.global_position + _back() * 6.0 + Vector3(0, 3.0, 0)
	cam.global_position = cam.global_position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	cam.look_at(kart.global_position + Vector3(0, 1.0, 0))
	var ratio: float = absf(kart.model.speed) / kart.model.max_speed
	speed_fx.update_fx(delta, ratio, kart.model.is_boosting())
	cam.fov = lerpf(cam.fov, 70.0 + 10.0 * speed_fx.speed_amount + 12.0 * speed_fx.boost_amount, clampf(5.0 * delta, 0.0, 1.0))
