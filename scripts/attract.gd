extends SubViewportContainer
## Attract-mode demo behind the title menu. Mario Kart 64's title screen shows the logo over
## karts racing round a course; here a SubViewport with its own 3D world (sky, ground, the
## highlighted course) has four CPU karts lapping it while a chase camera hops from kart to
## kart. No HUD, items, laps or sound — just the race rolling under the menu.
## On the arena select screen (battle mode) the same world holds the picked arena instead, with
## four balloon karts patrolling it (MK64's battle map select shows the arena, not a course).

const Kart := preload("res://scripts/kart.gd")
const Track := preload("res://scripts/track.gd")
const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
const Arena := preload("res://scripts/arena.gd")
const ArenaData := preload("res://scripts/arena_data.gd")
const BattleAi := preload("res://scripts/battle_ai.gd")
const Balloons := preload("res://scripts/balloons.gd")
const Battle := preload("res://scripts/battle.gd")
const ItemBox := preload("res://scripts/item_box.gd")

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
## Course picture (MK64's course select shows a picture of the course beside the map): a second
## viewport looks into the same world through a camera flying along the road — above and to the
## right of the centre line, looking down the road ahead — so the select screen's window shows the
## course itself rather than another view of the chase camera's kart.
const FLY_SPEED := 14.0      # m/s along the centre line
const FLY_UP := 8.0
const FLY_SIDE := 6.0        # to the right of the centre line
const FLY_AHEAD := 9         # samples (27 m) ahead the camera looks at
const FLY_LOOK_UP := 0.5
## Arena demo (battle mode): the karts patrol the ring of item boxes — even karts one way round,
## odd karts the other, so they meet and jostle — steering on to the next box once within
## WAYPOINT_REACH of the current one (the battle driver's feelers keep them off the forts, the lava
## and the edge). The picture camera circles the arena from above so the window shows the whole
## arena turning slowly.
const WAYPOINT_REACH := 5.0  # metres from a waypoint that counts as reached
const ORBIT_TIME := 24.0     # seconds for one turn of the picture camera round the arena
const ORBIT_RADIUS := 1.6    # of the arena's half side
const ORBIT_UP := 1.0        # of the arena's half side

var viewport: SubViewport
var picture: SubViewport            # the course picture's viewport (shares the demo world)
var picture_box: SubViewportContainer
var picture_cam: Camera3D = null
var fly_s := 0.0                    # fly-over position along the loop, in samples
var world: Node3D = null
var track = null
var data = null                     # TrackData for a course, ArenaData for an arena
var karts: Array = []
var cam: Camera3D = null
var cam_target := 0
var cam_timer := 0.0
var course := -1
var mirrored := false
var arena_index := -1               # the arena shown (-1: a course)
var arena = null                    # the Arena node in the world (null: a course)
var waypoints: Array = []           # Vector3 ring the arena karts patrol
var goals: Array = []               # per kart: index into waypoints
var orbit_t := 0.0                  # seconds into the picture camera's turn round the arena

## Grid slot of kart k: [samples ahead of the back row, lane offset] — two columns, rows ROW_GAP apart.
static func grid_slot(k: int) -> Array:
	return [(k / 2) * ROW_GAP, -LANE if k % 2 == 0 else LANE]

## Where the chase camera wants to be for a kart at `pos` facing `heading`: behind and above it.
static func chase_pose(pos: Vector3, heading: float) -> Vector3:
	return pos + Vector3(sin(heading), 0, cos(heading)) * CAM_BACK + Vector3(0, CAM_UP, 0)

## Kart the camera watches next (wraps around).
static func next_target(current: int, count: int) -> int:
	return posmod(current + 1, maxi(count, 1))

## Point `s` samples along the closed loop of `points` (fractional s interpolates, wraps). Pure.
static func loop_sample(points: PackedVector3Array, s: float) -> Vector3:
	var n := points.size()
	if n == 0:
		return Vector3.ZERO
	var w := fposmod(s, float(n))
	var i := int(floor(w))
	return points[i].lerp(points[(i + 1) % n], w - i)

## Fly-over camera for a point `pos` on the centre line looking towards `ahead` on it: FLY_SIDE to
## the right of the road, FLY_UP above it, aimed a little above the road at `ahead`. Pure.
static func fly_pose(pos: Vector3, ahead: Vector3) -> Dictionary:
	var dir := Vector3(ahead.x - pos.x, 0.0, ahead.z - pos.z)
	dir = dir.normalized() if dir.length() > 0.001 else Vector3(0, 0, -1)
	var right := dir.cross(Vector3.UP)
	return {"pos": pos + right * FLY_SIDE + Vector3(0, FLY_UP, 0), "look": ahead + Vector3(0, FLY_LOOK_UP, 0)}

## The viewport is built in _init so the menu can hand it a course as soon as it is created (also
## headless, where a child added during _initialize gets no _ready); the rect is fitted in _ready.
## The course picture's viewport shares the demo world and holds only the fly-over camera; the menu
## puts `picture_box` in the select screen's window.
func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	picture_box = SubViewportContainer.new()
	picture_box.name = "CoursePicture"
	picture_box.stretch = true
	picture_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture = SubViewport.new()
	picture.world_3d = viewport.find_world_3d()
	picture.handle_input_locally = false
	picture.msaa_3d = Viewport.MSAA_4X
	picture_box.add_child(picture)
	picture_cam = Camera3D.new()
	picture_cam.fov = 60.0
	picture.add_child(picture_cam)
	picture_cam.current = true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The picture container belongs to whoever placed it (the menu's select box); when nobody did, it
## goes with the demo.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and picture_box != null and picture_box.get_parent() == null:
		picture_box.free()

## Run the demo on course i (mirrored for the Extra class); rebuilds the world only on a change.
func show_course(i: int, mirror := false) -> void:
	if world != null and course == i and mirrored == mirror and arena == null:
		return
	course = i
	mirrored = mirror
	arena_index = -1
	arena = null
	_new_world()
	var theme := TrackLibrary.info(i)
	_build_environment(theme, Vector3(800, 1, 800), Vector3(60, -0.5, 20))
	data = TrackLibrary.make_data(i, mirror)
	track = Track.new(data)
	world.add_child(track)
	var back_idx: int = data.count - BACK_ROW
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
	_place_camera()
	# the course picture starts its fly-over at the start line, looking down the first straight
	fly_s = 0.0
	_fly(0.0)

## Run the demo in battle arena i (the arena select screen): the arena with its item boxes and four
## balloon karts patrolling the box ring from the start pads; the picture camera circles the arena.
## Rebuilds the world only on a change.
func show_arena(i: int) -> void:
	if world != null and arena != null and arena_index == i:
		return
	course = -1
	mirrored = false
	arena_index = i
	_new_world()
	var theme := ArenaData.info(i)
	data = ArenaData.make(i)
	# the floor is only as big as the arena when there is an edge to fall off (the rooftop)
	var side: float = data.half * 2.0 + (ArenaData.EDGE_FALL * 2.0 if not data.walled else 400.0)
	_build_environment(theme, Vector3(side, 1, side), Vector3(0, -0.5, 0))
	track = null
	arena = Arena.new(data)
	world.add_child(arena)
	for p in data.item_box_positions:
		var b := ItemBox.new()
		b.position = p
		world.add_child(b)
	waypoints = ring_waypoints(data.item_box_positions)
	goals = []
	for k in KART_COUNT:
		var kart := Kart.new()
		var s: Dictionary = data.spawns[k % data.spawns.size()]
		kart.body_color = KART_COLORS[k % KART_COLORS.size()]
		kart.position = s.position
		kart.heading = s.heading
		kart.driver = BattleAi.new(data, 999.0)
		kart.kart_id = k
		kart.add_child(Balloons.new(kart.body_color, Battle.BALLOONS))
		world.add_child(kart)
		karts.append(kart)
		goals.append(first_waypoint(k, kart.position, waypoints))
	_place_camera()
	orbit_t = 0.0
	_orbit(0.0)

## Drop the old demo world (if any) and start an empty one in the viewport.
func _new_world() -> void:
	if world != null:
		viewport.remove_child(world)
		world.queue_free()
	karts = []
	world = Node3D.new()
	viewport.add_child(world)

## The chase camera behind the first kart (local coordinates: the world node sits at the origin and
## may not be in the tree yet).
func _place_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 70.0
	world.add_child(cam)
	cam.current = true
	cam_target = 0
	cam_timer = 0.0
	cam.look_at_from_position(chase_pose(karts[0].position, karts[0].heading), karts[0].position + Vector3(0, 1.0, 0))

## The arena karts' patrol ring: the item boxes sorted by their angle round the centre, so stepping
## through the list goes round the arena. Pure.
static func ring_waypoints(boxes: Array) -> Array:
	var out: Array = boxes.duplicate()
	out.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2(a.z, a.x) < atan2(b.z, b.x))
	return out

## Which way kart k goes round the ring: even karts forwards, odd karts backwards. Pure.
static func patrol_dir(k: int) -> int:
	return 1 if k % 2 == 0 else -1

## The waypoint kart k starts for: the ring point nearest `pos`, stepped one on in the kart's
## direction so it drives off its pad rather than circling on it. Pure.
static func first_waypoint(k: int, pos: Vector3, ring: Array) -> int:
	if ring.is_empty():
		return 0
	var best := 0
	var best_d := INF
	for i in ring.size():
		var d: float = Vector2(ring[i].x - pos.x, ring[i].z - pos.z).length()
		if d < best_d:
			best_d = d
			best = i
	return posmod(best + patrol_dir(k), ring.size())

## The next waypoint for kart k once it is within WAYPOINT_REACH of ring[goal] (else goal). Pure.
static func next_waypoint(k: int, goal: int, pos: Vector3, ring: Array) -> int:
	if ring.is_empty():
		return 0
	var wp: Vector3 = ring[goal]
	if Vector2(wp.x - pos.x, wp.z - pos.z).length() <= WAYPOINT_REACH:
		return posmod(goal + patrol_dir(k), ring.size())
	return goal

## The picture camera `t` seconds into its turn round an arena of half side `half`: ORBIT_RADIUS
## halves out from the centre, ORBIT_UP halves up, looking at the centre. Pure.
static func orbit_pose(t: float, half: float) -> Dictionary:
	var a := TAU * t / ORBIT_TIME
	return {"pos": Vector3(cos(a), 0.0, sin(a)) * half * ORBIT_RADIUS + Vector3(0, half * ORBIT_UP, 0), "look": Vector3.ZERO}

## Move the course picture's camera `delta` seconds further along the road.
func _fly(delta: float) -> void:
	if picture_cam == null or data == null or data.count == 0:
		return
	fly_s = fposmod(fly_s + FLY_SPEED / data.spacing * delta, float(data.count))
	var pose := fly_pose(loop_sample(data.points, fly_s), loop_sample(data.points, fly_s + FLY_AHEAD))
	picture_cam.look_at_from_position(pose.pos, pose.look)

## Turn the arena picture's camera `delta` seconds further round the arena.
func _orbit(delta: float) -> void:
	if picture_cam == null or data == null:
		return
	orbit_t = fmod(orbit_t + delta, ORBIT_TIME)
	var pose := orbit_pose(orbit_t, data.half)
	picture_cam.look_at_from_position(pose.pos, pose.look)

## Sky, sun and ground like the race scene, in the course's / arena's colours.
func _build_environment(theme: Dictionary, ground_size: Vector3, ground_pos: Vector3) -> void:
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
	gshape.size = ground_size
	gcol.shape = gshape
	ground.add_child(gcol)
	var gmesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = ground_size
	gmesh.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = theme.ground
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	ground.position = ground_pos
	world.add_child(ground)

func _physics_process(delta: float) -> void:
	if data == null:
		return
	if arena != null:
		# the arena karts: fished out of the lava / back on to the roof, then on to the next waypoint
		# (local coordinates: the world node sits at the origin, and tests tick this outside the tree)
		for i in karts.size():
			var k = karts[i]
			var kp: Vector3 = k.position
			if not k.is_rescued() and data.in_pit(kp):
				k.start_rescue(data.respawn_point(kp), data.respawn_heading(kp))
			goals[i] = next_waypoint(i, goals[i], kp, waypoints)
			k.driver.goal = waypoints[goals[i]] if not waypoints.is_empty() else null
	else:
		for k in karts:
			var kp: Vector3 = k.global_position
			k.track_index = data.nearest_index(kp, k.track_index)
			k.model.surface_scale = 1.0 if data.is_on_road(kp, k.track_index) else OFFROAD_SCALE
			k.ramp_lift = data.ramp_height(kp, k.track_index)   # MK64 jump ramp: the demo karts fly too
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
	if picture_box.is_visible_in_tree():
		if arena != null:
			_orbit(delta)
		else:
			_fly(delta)