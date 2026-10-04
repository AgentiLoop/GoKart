extends Node3D
## Mario Kart 64's Lakitu, the race referee on a cloud with a fishing rod. He hovers ahead of the
## player's kart and shows, in priority order: the fishing line while a kart is fished out of the
## water, the start signal (red, red, blue = GO), the checkered flag at the finish, the lap sign
## after a lap, and a flashing red "REVERSE" sign while the kart drives the wrong way.
## The pure helpers (lamps, going_wrong, lap_sign, rescue_pose) are unit tested without a scene.

const UiStyle := preload("res://scripts/ui_style.gd")

enum Mode { HIDDEN, START, RESCUE, FLAG, LAP_SIGN, REVERSE }

## Start signal: lamp i lights when the countdown drops below SIGNAL_STEPS[i] seconds; all three at GO.
const LAMP_COLORS := [Color(1.0, 0.1, 0.1), Color(1.0, 0.1, 0.1), Color(0.2, 0.5, 1.0)]
const SIGNAL_HOLD := 1.5        # seconds the signal stays up after GO
const REVERSE_DELAY := 1.0      # seconds of wrong-way driving before the sign comes out
const REVERSE_DOT := -0.3       # forward . track tangent below this counts as the wrong way
const REVERSE_MIN_SPEED := 2.0
const SIGN_TIME := 2.0          # how long a lap sign is shown
const FLAG_TIME := 3.0          # how long the checkered flag waves
## Rescue: the kart is lifted straight up, carried over the drop point and lowered onto the road.
const LIFT_TIME := 1.0
const CARRY_TIME := 1.0
const DROP_TIME := 0.6
const RESCUE_TIME := LIFT_TIME + CARRY_TIME + DROP_TIME
const LIFT_HEIGHT := 5.0
const FOLLOW_RATE := 4.0

var kart = null                 # the player's kart
var track = null                # TrackData
var mode: int = Mode.HIDDEN
var wrong_time := 0.0
var sign_text := ""
var sign_timer := 0.0
var flag_timer := 0.0
var time := 0.0
var appearances := 0            # times Lakitu came out of hiding (for checks/tests)

var _cloud: Node3D
var _rod_tip: Node3D
var _signal: Node3D
var _lamps: Array[MeshInstance3D] = []
var _sign: Node3D
var _sign_board: MeshInstance3D
var _sign_label: Label3D
var _flag: Node3D
var _line: MeshInstance3D

## Number of lit lamps on the start signal: 0 at "3", 1 at "2", 2 at "1", all three at GO.
static func lamps(remaining: float, started: bool) -> int:
	if started:
		return 3
	if remaining <= 1.0:
		return 2
	if remaining <= 2.0:
		return 1
	return 0

## True when a kart moving at `speed` with facing `forward` is driving against the track direction.
static func going_wrong(forward: Vector3, tangent: Vector3, speed: float) -> bool:
	return speed > REVERSE_MIN_SPEED and forward.dot(tangent) < REVERSE_DOT

## Sign held up when the kart starts lap `lap` of `total`: "LAP 2", ..., "FINAL LAP"; empty on lap 1.
static func lap_sign(lap: int, total: int) -> String:
	if lap <= 1 or lap > total:
		return ""
	if lap == total:
		return "FINAL LAP"
	return "LAP %d" % lap

## Where a rescued kart is t seconds into its rescue: up from `from`, across, then down onto `to`.
static func rescue_pose(t: float, from: Vector3, to: Vector3) -> Vector3:
	var top := maxf(from.y, to.y) + LIFT_HEIGHT
	if t <= LIFT_TIME:
		return Vector3(from.x, lerpf(from.y, top, smoothstep(0.0, 1.0, t / LIFT_TIME)), from.z)
	if t <= LIFT_TIME + CARRY_TIME:
		var f := smoothstep(0.0, 1.0, (t - LIFT_TIME) / CARRY_TIME)
		return Vector3(lerpf(from.x, to.x, f), top, lerpf(from.z, to.z, f))
	var d := clampf((t - LIFT_TIME - CARRY_TIME) / DROP_TIME, 0.0, 1.0)
	return Vector3(to.x, lerpf(top, to.y, d * d), to.z)

func _init() -> void:
	_build()

func setup(player, track_data) -> void:
	kart = player
	track = track_data
	visible = false

## The player started lap `lap` (2..total): hold up the lap sign for a moment.
func on_lap(lap: int, total: int) -> void:
	sign_text = lap_sign(lap, total)
	sign_timer = SIGN_TIME if sign_text != "" else 0.0

## The player crossed the finish line: wave the checkered flag.
func on_finish() -> void:
	flag_timer = FLAG_TIME

## Called every physics frame from the race scene with the start countdown state.
func update_lakitu(delta: float, remaining: float, started: bool, since_go: float) -> void:
	time += delta
	sign_timer = maxf(sign_timer - delta, 0.0)
	flag_timer = maxf(flag_timer - delta, 0.0)
	var forward := Vector3(-sin(kart.heading), 0, -cos(kart.heading))
	if started and going_wrong(forward, track.tangents[posmod(kart.track_index, track.count)], kart.model.speed):
		wrong_time += delta
	else:
		wrong_time = 0.0
	var next: int = Mode.HIDDEN
	if kart.is_rescued():
		next = Mode.RESCUE
	elif not started or since_go < SIGNAL_HOLD:
		next = Mode.START
	elif flag_timer > 0.0:
		next = Mode.FLAG
	elif sign_timer > 0.0:
		next = Mode.LAP_SIGN
	elif wrong_time >= REVERSE_DELAY:
		next = Mode.REVERSE
	if next != mode:
		if mode == Mode.HIDDEN:
			appearances += 1
		mode = next
	_show(remaining, started)
	_move(delta, forward)

func _show(remaining: float, started: bool) -> void:
	_signal.visible = mode == Mode.START
	_sign.visible = mode == Mode.LAP_SIGN or mode == Mode.REVERSE
	_flag.visible = mode == Mode.FLAG
	_line.visible = mode == Mode.RESCUE
	if mode == Mode.START:
		var lit := lamps(remaining, started)
		for i in _lamps.size():
			var m := _lamps[i].material_override as StandardMaterial3D
			m.emission_enabled = i < lit
			m.albedo_color = LAMP_COLORS[i] if i < lit else LAMP_COLORS[i].darkened(0.7)
	elif mode == Mode.REVERSE:
		_sign_label.text = "REVERSE"
		_set_board(Color(0.9, 0.05, 0.05))
		# MK64: the red sign flashes
		_sign.visible = fmod(wrong_time, 0.4) < 0.28
	elif mode == Mode.LAP_SIGN:
		_sign_label.text = sign_text
		_set_board(Color(0.1, 0.6, 0.2) if sign_text != "FINAL LAP" else Color(0.9, 0.6, 0.05))
	elif mode == Mode.FLAG:
		_flag.rotation.z = sin(time * 9.0) * 0.5

## Paints the sign board and gives the text a rim in the board's shade.
func _set_board(color: Color) -> void:
	(_sign_board.material_override as StandardMaterial3D).albedo_color = color
	_sign_label.outline_modulate = UiStyle.board_rim(color)

func _move(delta: float, forward: Vector3) -> void:
	var right := Vector3(-forward.z, 0, forward.x)
	var bob := sin(time * 3.0) * 0.2
	var target: Vector3
	if mode == Mode.RESCUE:
		# straight above the dangling kart, line down to it
		target = kart.position + Vector3(0, LIFT_HEIGHT + 2.5 + bob, 0)
	elif mode == Mode.HIDDEN:
		target = kart.position + forward * 2.0 + right * 2.2 + Vector3(0, 14.0, 0)
	else:
		target = kart.position + forward * 4.0 + right * 2.2 + Vector3(0, 3.2 + bob, 0)
	if not visible:
		position = target
	else:
		position = position.lerp(target, clampf(FOLLOW_RATE * delta, 0.0, 1.0))
	rotation.y = kart.heading + PI   # faces back towards the player / camera
	visible = mode != Mode.HIDDEN
	if mode == Mode.RESCUE:
		var drop: float = position.y - kart.position.y - 1.0
		_line.scale.y = maxf(drop, 0.1)
		_line.position.y = -drop * 0.5 - 0.3

# ---- procedural model ---------------------------------------------------------------------

func _build() -> void:
	_cloud = Node3D.new()
	add_child(_cloud)
	for p in [Vector3(0, 0, 0), Vector3(-0.45, -0.1, 0.1), Vector3(0.45, -0.1, -0.1), Vector3(0, -0.15, 0.4), Vector3(0.1, -0.12, -0.4)]:
		_sphere(_cloud, 0.42 if p == Vector3.ZERO else 0.32, p, Color(1, 1, 1))
	# green shell, yellow face, goggles
	_sphere(_cloud, 0.34, Vector3(0, 0.55, 0), Color(0.25, 0.7, 0.2))
	_sphere(_cloud, 0.3, Vector3(0, 0.62, 0.15), Color(1.0, 0.85, 0.45))
	for x in [-0.12, 0.12]:
		_sphere(_cloud, 0.09, Vector3(x, 0.72, 0.4), Color(0.1, 0.1, 0.1))
	# fishing rod: tilted forward, the tip ahead of the cloud with the item hanging below
	var rod := MeshInstance3D.new()
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.03
	rod_mesh.bottom_radius = 0.04
	rod_mesh.height = 2.4
	rod.mesh = rod_mesh
	rod.material_override = _mat(Color(0.5, 0.3, 0.1))
	rod.position = Vector3(0.3, 1.1, 0.8)
	rod.rotation.x = deg_to_rad(55)
	_cloud.add_child(rod)
	_rod_tip = Node3D.new()
	_rod_tip.position = Vector3(0.3, 1.8, 1.8)
	add_child(_rod_tip)
	# start signal: a dark box with three lamps, red / red / blue. Lakitu's node faces away from the
	# player (rotation.y = heading + PI), so the signal is turned 180° to point its lamps at the racer.
	_signal = Node3D.new()
	_signal.position = Vector3(0, -1.6, 0)
	_signal.rotation.y = PI
	_rod_tip.add_child(_signal)
	_box(_signal, Vector3(0.6, 1.7, 0.25), Vector3(0, 0, 0), Color(0.12, 0.12, 0.14))
	for i in 3:
		var lamp := _sphere(_signal, 0.2, Vector3(0, 0.5 - i * 0.5, 0.14), LAMP_COLORS[i].darkened(0.7))
		(lamp.material_override as StandardMaterial3D).emission = LAMP_COLORS[i] * 2.0
		_lamps.append(lamp)
	# sign board (REVERSE / LAP n) on a short pole
	_sign = Node3D.new()
	_sign.position = Vector3(0, -1.3, 0)
	_rod_tip.add_child(_sign)
	_box(_sign, Vector3(0.08, 0.8, 0.08), Vector3(0, 0.3, 0), Color(0.6, 0.6, 0.6))
	_sign_board = _box(_sign, Vector3(2.0, 0.8, 0.12), Vector3(0, -0.3, 0), Color(0.9, 0.05, 0.05))
	_sign_label = Label3D.new()
	_sign_label.text = "REVERSE"
	_sign_label.pixel_size = 0.006
	# white text printed on the board: rounded font, thin rim in the board's shade, no black outline
	UiStyle.style_label3d(_sign_label, 96, Color(1, 1, 1), UiStyle.board_rim(Color(0.9, 0.05, 0.05)))
	_sign_label.position = Vector3(0, -0.3, 0.08)
	_sign.add_child(_sign_label)
	# checkered flag
	_flag = Node3D.new()
	_flag.position = Vector3(0, -0.4, 0)
	_rod_tip.add_child(_flag)
	_box(_flag, Vector3(0.06, 1.6, 0.06), Vector3(0, -0.8, 0), Color(0.8, 0.8, 0.8))
	for cx in 5:
		for cy in 4:
			var c := Color(0.05, 0.05, 0.05) if (cx + cy) % 2 == 0 else Color(1, 1, 1)
			_box(_flag, Vector3(0.24, 0.2, 0.04), Vector3(0.15 + cx * 0.24, -0.1 - cy * 0.2, 0), c)
	# fishing line (scaled to reach the kart during a rescue)
	_line = MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.015
	lm.bottom_radius = 0.015
	lm.height = 1.0
	_line.mesh = lm
	_line.material_override = _mat(Color(0.9, 0.9, 0.9))
	_rod_tip.add_child(_line)
	_signal.visible = false
	_sign.visible = false
	_flag.visible = false
	_line.visible = false

static func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi
