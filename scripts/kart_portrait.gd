extends SubViewportContainer
## Kart portrait on the select screen, after Mario Kart 64's Player Select: the picked driver is
## shown live, not as a name. GoKart's "driver" is the weight class, so the KART cell shows the
## player's kart at that class's size in a little 3D window of its own — on a showroom turntable
## turning slowly, hopping once when the class changes (MK64's portraits move when picked). The
## window has a transparent background, so the kart stands on the navy panel itself.

const KartModel := preload("res://scripts/kart_model.gd")
const KartWeight := preload("res://scripts/kart_weight.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

const KART_COLOR := Color(0.9, 0.1, 0.1)   # the player's kart red (Kart.body_color default)
const TURN_RATE := 0.9                      # rad/s round the turntable
const HOP_HEIGHT := 0.35                    # metres the kart hops when the class changes
const HOP_TIME := 0.45                      # seconds the hop lasts
const CAMERA_POS := Vector3(2.4, 1.7, 3.0)  # a three-quarter view from the front left
const CAMERA_LOOK := Vector3(0, 0.55, 0)
const DISC_RADIUS := 1.9
const DISC := Color(UiStyle.GOLD, 0.35)     # the turntable under the kart

var viewport: SubViewport
var turntable: Node3D       # turns; carries the kart (scaled to the class) and hops
var kart: KartModel
var cam: Camera3D
var weight_class := KartWeight.MEDIUM
var turn_t := 0.0           # seconds the turntable has been turning
var hop_t := HOP_TIME       # seconds into the current hop (HOP_TIME = landed)

## The turntable's angle `t` seconds in (a steady turn, wrapped to one revolution). Pure.
static func turn_angle(t: float) -> float:
	return fmod(TURN_RATE * t, TAU)

## How high the kart is `t` seconds into its hop: a single arc up and back down over HOP_TIME,
## 0 before it starts and once it has landed. Pure.
static func hop_height(t: float) -> float:
	if t <= 0.0 or t >= HOP_TIME:
		return 0.0
	return HOP_HEIGHT * sin(PI * t / HOP_TIME)

## The visible size of a weight class's kart (the class's `size`, as Kart scales its body). Pure.
static func class_scale(i: int) -> float:
	return KartWeight.info(i).size

func _init() -> void:
	name = "KartPortrait"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.75, 0.9)
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.3
	viewport.add_child(sun)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = DISC_RADIUS
	disc_mesh.bottom_radius = DISC_RADIUS
	disc_mesh.height = 0.06
	disc_mesh.radial_segments = 32
	disc.mesh = disc_mesh
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = DISC
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = disc_mat
	disc.position = Vector3(0, -0.03, 0)
	disc.name = "Disc"
	viewport.add_child(disc)
	turntable = Node3D.new()
	turntable.name = "Turntable"
	viewport.add_child(turntable)
	kart = KartModel.new()
	kart.name = "Kart"
	kart.build(KART_COLOR)
	turntable.add_child(kart)
	cam = Camera3D.new()
	cam.fov = 40.0
	viewport.add_child(cam)
	# a local transform: the window is built before it joins the tree (look_at needs the tree)
	cam.transform = Transform3D(Basis.looking_at(CAMERA_LOOK - CAMERA_POS, Vector3.UP), CAMERA_POS)
	cam.current = true
	show_class(weight_class)

## Show the kart of weight class i: scaled to the class's size; a change hops the kart.
func show_class(i: int) -> void:
	if i != weight_class:
		hop_t = 0.0
	weight_class = i
	kart.scale = Vector3.ONE * class_scale(i)
	_apply()

## Put the turntable where the turn and the hop have it.
func _apply() -> void:
	turntable.rotation.y = turn_angle(turn_t)
	turntable.position.y = hop_height(hop_t)

func _process(delta: float) -> void:
	turn_t += delta
	if hop_t < HOP_TIME:
		hop_t = minf(hop_t + delta, HOP_TIME)
	_apply()
