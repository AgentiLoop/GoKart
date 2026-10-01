extends Node3D
## Visual effects for a kart: drift sparks (GPUParticles3D), boost flames (GPUParticles3D)
## and tire trails (ribbon meshes). Listens to KartPhysics signals.

const TireTrail := preload("res://scripts/tire_trail.gd")

const SPARK_COLORS := [
	Color(1.0, 0.9, 0.5),    # level 0: warm white-yellow
	Color(0.3, 0.6, 1.0),    # level 1: blue
	Color(1.0, 0.55, 0.1),   # level 2: orange
	Color(0.8, 0.3, 1.0),    # level 3: purple
]

const FLAME_COLORS := [
	Color(1.0, 0.45, 0.05),  # mushroom / pad / start boost: orange-red
	Color(0.3, 0.6, 1.0),    # mini-turbo 1: blue
	Color(1.0, 0.55, 0.1),   # mini-turbo 2: orange
	Color(0.8, 0.3, 1.0),    # mini-turbo 3: purple
]
const FLASH_DECAY := 4.0      # 1/s: mini-turbo flash fades in ~0.25 s

var model            # KartPhysics
var sparks: Array[GPUParticles3D] = []
var flames: Array[GPUParticles3D] = []
var trails: Array = []
var wheel_nodes: Array[Node3D] = []
var pops: Array[GPUParticles3D] = []   # one-shot star burst when a drift level is reached
var flash_light: OmniLight3D
var flash_amount := 0.0                 # 1 right at mini-turbo release, decays to 0
var flash_color := Color.WHITE
var star_overlay: ShaderMaterial        # rainbow material_overlay applied to the body while invincible
var star_meshes: Array[MeshInstance3D] = []
var star_glitter: GPUParticles3D

## Exhaust flame tint: drift mini-turbos use the spark colour of their level, other boosts are orange.
static func flame_color(level: int, from_drift: bool) -> Color:
	return FLAME_COLORS[clampi(level, 1, 3)] if from_drift else FLAME_COLORS[0]

static func spark_color(level: int) -> Color:
	return SPARK_COLORS[clampi(level, 0, SPARK_COLORS.size() - 1)]

func setup(physics_model, wheel_offsets: Array) -> void:
	model = physics_model
	for off in wheel_offsets:
		var anchor := Node3D.new()
		anchor.position = off
		add_child(anchor)
		wheel_nodes.append(anchor)
		var t = TireTrail.new()
		add_child(t)
		trails.append(t)
	# sparks at the rear wheels, flames at the exhaust pipes
	for off in wheel_offsets:
		if off.z > 0.0:
			var s := _make_sparks()
			s.position = off + Vector3(0, 0.1, 0.2)
			add_child(s)
			sparks.append(s)
			var pop := _make_pop()
			pop.position = off + Vector3(0, 0.3, 0.2)
			add_child(pop)
			pops.append(pop)
			var f := _make_flame()
			f.position = Vector3(off.x * 0.45, 0.45, 1.2)
			add_child(f)
			flames.append(f)
	flash_light = OmniLight3D.new()
	flash_light.position = Vector3(0, 0.8, 0.6)
	flash_light.omni_range = 6.0
	flash_light.light_energy = 0.0
	flash_light.visible = false
	add_child(flash_light)
	model.drift_level_changed.connect(_on_level_changed)
	model.drift_started.connect(_on_drift_started)
	model.boost_started.connect(_on_boost_started)
	model.boost_ended.connect(_on_boost_ended)
	model.star_started.connect(_on_star_started)
	model.star_ended.connect(_on_star_ended)
	star_glitter = _make_glitter()
	star_glitter.position = Vector3(0, 0.7, 0)
	add_child(star_glitter)

## Remember the body meshes that get the rainbow overlay while the kart has a star.
func setup_star(body: Node3D) -> void:
	star_overlay = ShaderMaterial.new()
	star_overlay.shader = load("res://shaders/star.gdshader") as Shader
	for c in body.get_children():
		if c is MeshInstance3D:
			star_meshes.append(c)

func _make_glitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 48
	p.lifetime = 0.6
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.8, 0.4, 1.2)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -2, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.8
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.2, 0.2, 1), Color(1, 0.9, 0.2, 1), Color(0.2, 1, 0.4, 1), Color(0.2, 0.6, 1, 1), Color(0.8, 0.3, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = _particle_material(Color(1, 1, 1, 1))
	p.draw_pass_1 = q
	return p

func _on_star_started() -> void:
	for m in star_meshes:
		m.material_overlay = star_overlay
	star_glitter.emitting = true

func _on_star_ended() -> void:
	for m in star_meshes:
		m.material_overlay = null
	star_glitter.emitting = false

func _particle_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	return m

func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _make_sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.45
	p.explosiveness = 0.0
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0.6)
	pm.spread = 40.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -18, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.color = SPARK_COLORS[0]
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	q.material = _particle_material(Color(1, 1, 1, 1))
	p.draw_pass_1 = q
	return p

func _make_flame() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.35
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.1, 1)
	pm.spread = 8.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.1))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 0.9, 1), Color(1, 0.6, 0.1, 0.9), Color(1, 0.15, 0.0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	q.material = _particle_material(Color(1, 1, 1, 1))
	p.draw_pass_1 = q
	return p

func _make_pop() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 24
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, -10, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.0
	pm.color = SPARK_COLORS[1]
	pm.color_ramp = _fade_ramp()
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	q.material = _particle_material(Color(1, 1, 1, 1))
	p.draw_pass_1 = q
	return p

func _set_spark_color(level: int) -> void:
	for s in sparks:
		(s.process_material as ParticleProcessMaterial).color = spark_color(level)

func _on_drift_started(_dir: int) -> void:
	_set_spark_color(0)
	for s in sparks:
		s.emitting = true

func _on_level_changed(level: int) -> void:
	if model.drifting:
		_set_spark_color(level)
		for s in sparks:
			s.amount_ratio = 0.5 + 0.25 * level
		if level > 0:
			for p in pops:
				(p.process_material as ParticleProcessMaterial).color = spark_color(level)
				p.restart()
				p.emitting = true
	else:
		for s in sparks:
			s.emitting = false

func _on_boost_started(level: int) -> void:
	for s in sparks:
		s.emitting = false
	var col := flame_color(level, model.boost_from_drift)
	for f in flames:
		(f.process_material as ParticleProcessMaterial).color = col
		f.emitting = true
	if model.boost_from_drift:
		flash_color = spark_color(level)
		flash_amount = 1.0

func _on_boost_ended() -> void:
	for f in flames:
		f.emitting = false

## Called every physics frame by the kart.
func update_fx(delta: float, on_floor: bool) -> void:
	flash_amount = move_toward(flash_amount, 0.0, FLASH_DECAY * delta)
	flash_light.visible = flash_amount > 0.0
	flash_light.light_color = flash_color
	flash_light.light_energy = 8.0 * flash_amount
	if model.drifting == false:
		for s in sparks:
			if s.emitting and not model.is_boosting():
				s.emitting = false
	var skid: bool = on_floor and model.drifting
	for i in trails.size():
		var t = trails[i]
		t.emitting = skid
		t.color = spark_color(model.drift_level).darkened(0.35) if model.drifting and model.drift_level > 0 else Color(0.05, 0.05, 0.05, 0.7)
		if skid:
			t.track(delta, wheel_nodes[i].global_position + Vector3(0, 0.02, 0))
		else:
			t.break_trail()
			t.track(delta, Vector3.ZERO)
