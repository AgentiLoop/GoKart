extends SubViewportContainer
## Attract-mode demo behind the title menu. Mario Kart 64's title screen shows the logo over
## karts racing round a course; here a SubViewport with its own 3D world (sky, ground, the
## highlighted course) has four CPU karts lapping it while a chase camera hops from kart to
## kart. No HUD, items, laps or sound — just the race rolling under the menu.

const Kart := preload("res://scripts/kart.gd")
const Track := preload("res://scripts/track.gd")
const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")

const KART_COUNT := 4
## Red (the player's colour), blue, green, yellow — the front of the MK64 field.
const KART_COLORS := [Color(0.9, 0.1, 0.1), Color(0.15, 0.3, 0.95), Color(0.15, 0.75, 0.25), Color(0.95, 0.85, 0.15)]
const LANE := 2.4            # half the lane spacing of the two-column grid
const ROW_GAP := 3           # samples (9 m) between grid rows
const BACK_ROW := 10         # samples before the line the back row starts at
const CAM_HOLD := 7.0        # seconds the camera stays on one kart
const CAM_BACK := 7.0
const CAM_UP := 3.0
const CAM_LERP := 3.0
const OFFROAD_SCALE := 0.5

var viewport: SubViewport
var world: Node3D = null
var track = null
var data: TrackData = null
var karts: Array = []
var cam: Camera3D = null
var cam_target := 0
var cam_timer := 0.0
var course := -1
var mirrored := false

## Grid slot of kart k: [samples ahead of the back row, lane offset] — two columns, rows ROW_GAP apart.
static func grid_slot(k: int) -> Array:
	return [(k / 2) * ROW_GAP, -LANE if k % 2 == 0 else LANE]

## Where the chase camera wants to be for a kart at `pos` facing `heading`: behind and above it.
static func chase_pose(pos: Vector3, heading: float) -> Vector3:
	return pos + Vector3(sin(heading), 0, cos(heading)) * CAM_BACK + Vector3(0, CAM_UP, 0)

## Kart the camera watches next (wraps around).
static func next_target(current: int, count: int) -> int:
	return posmod(current + 1, maxi(count, 1))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)

## Run the demo on course i (mirrored for the Extra class); rebuilds the world only on a change.
func show_course(i: int, mirror := false) -> void:
	if world != null and course == i and mirrored == mirror:
		return
	course = i
	mirrored = mirror
	if world != null:
		viewport.remove_child(world)
		world.queue_free()
	karts = []
	world = Node3D.new()
	viewport.add_child(world)
	var theme := TrackLibrary.info(i)
	_build_environment(theme)
	data = TrackLibrary.make_data(i, mirror)
	track = Track.new(data)
	world.add_child(track)
	var back_idx := data.count - BACK_ROW
	for k in KART_COUNT:
		var kart := Kart.new()
		var slot := grid_slot(k)
		var gi: int = back_idx + int(slot[0])
		var lane: float = slot[1]
		kart.body_color = KART_COLORS[k % KART_COLORS.size()]
		kart.position = data.points[gi] + data.right_of(gi) * lane + Vector3(0, 0.1, 0)
		kart.heading = data.heading_at(gi)
		kart.driver = AiDriver.new(data, lane, 999.0)
		kart.track_index = gi
		kart.kart_id = k
		world.add_child(kart)
		karts.append(kart)
	cam = Camera3D.new()
	cam.fov = 70.0
	world.add_child(cam)
	cam.current = true
	cam_target = 0
	cam_timer = 0.0
	# local coordinates: the world node sits at the origin (and may not be in the tree yet)
	cam.look_at_from_position(chase_pose(karts[0].position, karts[0].heading), karts[0].position + Vector3(0, 1.0, 0))

## Sky, sun and ground like the race scene, in the course's colours.
func _build_environment(theme: Dictionary) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = theme.sky_top
	sky_mat.sky_horizon_color = theme.sky_horizon
	sky_mat.ground_horizon_color = theme.sky_horizon
	e.sky.sky_material = sky_mat
	e.glow_enabled = true
	e.glow_hdr_threshold = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
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
	gmat.albedo_color = theme.ground
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	ground.position = Vector3(60, -0.5, 20)
	world.add_child(ground)

func _physics_process(delta: float) -> void:
	if data == null:
		return
	for k in karts:
		var kp: Vector3 = k.global_position
		k.track_index = data.nearest_index(kp, k.track_index)
		k.model.surface_scale = 1.0 if data.is_on_road(kp, k.track_index) else OFFROAD_SCALE
	cam_timer += delta
	if cam_timer >= CAM_HOLD:
		cam_timer = 0.0
		cam_target = next_target(cam_target, karts.size())

func _process(delta: float) -> void:
	if cam == null or karts.is_empty():
		return
	var k = karts[cam_target]
	cam.global_position = cam.global_position.lerp(chase_pose(k.global_position, k.heading), clampf(CAM_LERP * delta, 0.0, 1.0))
	cam.look_at(k.global_position + Vector3(0, 1.0, 0))
