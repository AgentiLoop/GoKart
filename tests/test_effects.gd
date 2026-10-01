extends RefCounted
## Effects tests: construct nodes in a scene tree and verify signal wiring, trails and shader.

const KartPhysics := preload("res://scripts/kart_physics.gd")
const KartEffects := preload("res://scripts/kart_effects.gd")
const TireTrail := preload("res://scripts/tire_trail.gd")
const SpeedFx := preload("res://scripts/speed_fx.gd")
var runner

const WHEELS := [Vector3(-0.8, 0, -0.8), Vector3(0.8, 0, -0.8), Vector3(-0.8, 0, 0.8), Vector3(0.8, 0, 0.8)]

func _tree() -> Node:
	return Engine.get_main_loop().root

func _make_fx():
	var m = KartPhysics.new()
	var fx = KartEffects.new()
	_tree().add_child(fx)
	fx.setup(m, WHEELS)
	return [m, fx]

func test_spark_colors_per_level() -> void:
	runner.check(KartEffects.spark_color(1) != KartEffects.spark_color(2))
	runner.check(KartEffects.spark_color(2) != KartEffects.spark_color(3))
	runner.check(KartEffects.spark_color(99) == KartEffects.spark_color(3))
	runner.check(KartEffects.spark_color(-1) == KartEffects.spark_color(0))

func test_effect_nodes_created() -> void:
	var r = _make_fx()
	var fx = r[1]
	runner.check(fx.sparks.size() == 2, "sparks=%d" % fx.sparks.size())
	runner.check(fx.flames.size() == 2, "flames=%d" % fx.flames.size())
	runner.check(fx.trails.size() == 4, "trails=%d" % fx.trails.size())
	fx.queue_free()

func test_drift_emits_sparks_and_boost_emits_flames() -> void:
	var r = _make_fx()
	var m = r[0]
	var fx = r[1]
	m.speed = 25.0
	for i in 60:
		m.step(1.0 / 60.0, 1.0, 0.0, 1.0, true)
	runner.check(m.drifting)
	runner.check(fx.sparks[0].emitting, "sparks should emit while drifting")
	runner.check(not fx.flames[0].emitting)
	for i in 120:
		m.step(1.0 / 60.0, 1.0, 0.0, 1.0, true)
	runner.check(m.drift_level >= 1)
	var pm: ParticleProcessMaterial = fx.sparks[0].process_material
	runner.check(pm.color == KartEffects.spark_color(m.drift_level), "spark color tracks level")
	m.step(1.0 / 60.0, 1.0, 0.0, 1.0, false)   # release -> mini-turbo
	runner.check(m.is_boosting())
	runner.check(fx.flames[0].emitting, "flames on boost")
	runner.check(not fx.sparks[0].emitting)
	for i in 200:
		m.step(1.0 / 60.0, 1.0, 0.0, 0.0, false)
	runner.check(not fx.flames[0].emitting, "flames off after boost")
	fx.queue_free()

func test_mushroom_boost_flames() -> void:
	var r = _make_fx()
	r[0].apply_boost(1.0)
	runner.check(r[1].flames[0].emitting)
	r[1].queue_free()

func test_trail_grows_and_expires() -> void:
	var t = TireTrail.new()
	_tree().add_child(t)
	t.emitting = true
	for i in 10:
		t.track(1.0 / 60.0, Vector3(i * 0.5, 0, 0))
	runner.check(t.points.size() == 10, "points=%d" % t.points.size())
	t.emitting = false
	for i in 120:
		t.track(1.0 / 60.0, Vector3.ZERO)
	runner.check(t.points.size() == 0, "points=%d" % t.points.size())
	t.queue_free()

func test_trail_min_distance_and_break() -> void:
	var t = TireTrail.new()
	_tree().add_child(t)
	t.emitting = true
	t.track(0.01, Vector3.ZERO)
	t.track(0.01, Vector3(0.01, 0, 0))
	runner.check(t.points.size() == 1)
	t.track(0.01, Vector3(1, 0, 0))
	t.break_trail()
	t.break_trail()
	runner.check(t.points.size() == 3, "points=%d" % t.points.size())
	t.track(0.01, Vector3(2, 0, 0))
	runner.check(t.points.size() == 4)
	t.queue_free()

func test_speed_fx_shader_params() -> void:
	var fx = SpeedFx.new()
	_tree().add_child(fx)
	runner.check(fx.mat != null and fx.mat.shader != null)
	for i in 120:
		fx.update_fx(1.0 / 60.0, 1.0, true)
	runner.check(fx.boost_amount > 0.99 and fx.speed_amount > 0.95)
	runner.check(is_equal_approx(fx.mat.get_shader_parameter("boost_amount"), fx.boost_amount))
	for i in 300:
		fx.update_fx(1.0 / 60.0, 0.0, false)
	runner.check(fx.boost_amount == 0.0 and fx.speed_amount < 0.01)
	fx.queue_free()

func test_flame_color_by_boost_source() -> void:
	runner.check(KartEffects.flame_color(2, false) == KartEffects.FLAME_COLORS[0])
	runner.check(KartEffects.flame_color(1, true) != KartEffects.flame_color(3, true))
	runner.check(KartEffects.flame_color(3, true) == KartEffects.spark_color(3))

func _drift_to_level(m, level: int) -> void:
	m.speed = 25.0
	for i in 600:
		m.step(1.0 / 60.0, 1.0, 0.0, 1.0, true)
		if m.drift_level >= level:
			break

func test_level_up_pops_and_mini_turbo_flash() -> void:
	var r = _make_fx()
	var m = r[0]
	var fx = r[1]
	runner.check(fx.pops.size() == 2)
	runner.check(fx.flash_amount == 0.0)
	_drift_to_level(m, 2)
	runner.check(m.drift_level == 2, "level=%d" % m.drift_level)
	var pm: ParticleProcessMaterial = fx.pops[0].process_material
	runner.check(pm.color == KartEffects.spark_color(2), "pop colour = level colour")
	runner.check(fx.pops[0].emitting, "pop burst emitting")
	m.step(1.0 / 60.0, 1.0, 0.0, 1.0, false)   # release
	runner.check(m.boost_from_drift)
	runner.check(fx.flash_amount == 1.0 and fx.flash_color == KartEffects.spark_color(2), "flash triggered")
	var fm: ParticleProcessMaterial = fx.flames[0].process_material
	runner.check(fm.color == KartEffects.flame_color(2, true), "flame tinted by mini-turbo level")
	fx.update_fx(1.0 / 60.0, true)
	runner.check(fx.flash_light.visible and fx.flash_amount < 1.0)
	for i in 30:
		fx.update_fx(1.0 / 60.0, true)
	runner.check(fx.flash_amount == 0.0 and not fx.flash_light.visible, "flash fades")
	fx.queue_free()

func test_mushroom_boost_is_not_drift_boost() -> void:
	var r = _make_fx()
	r[0].apply_boost(1.0, 1)
	runner.check(not r[0].boost_from_drift)
	runner.check(r[1].flash_amount == 0.0, "no flash for mushroom")
	runner.check((r[1].flames[0].process_material as ParticleProcessMaterial).color == KartEffects.flame_color(1, false))
	r[1].queue_free()

func test_speed_fx_flash() -> void:
	var fx = SpeedFx.new()
	_tree().add_child(fx)
	fx.trigger_flash(Color(0.3, 0.6, 1.0))
	fx.update_fx(1.0 / 60.0, 0.0, false)
	runner.check(fx.flash_amount > 0.9 and fx.flash_amount < 1.0)
	runner.check(is_equal_approx(fx.mat.get_shader_parameter("flash_amount"), fx.flash_amount))
	for i in 60:
		fx.update_fx(1.0 / 60.0, 0.0, false)
	runner.check(fx.flash_amount == 0.0, "flash fades out")
	fx.queue_free()

func test_star_overlay_and_glitter() -> void:
	var r = _make_fx()
	var body := Node3D.new()
	for i in 3:
		body.add_child(MeshInstance3D.new())
	r[1].setup_star(body)
	runner.check(r[1].star_meshes.size() == 3)
	runner.check(not r[1].star_glitter.emitting)
	r[0].apply_star()
	runner.check(r[1].star_glitter.emitting, "glitter while star")
	for m in r[1].star_meshes:
		runner.check(m.material_overlay != null, "overlay on")
	runner.check(r[1].star_overlay.shader != null, "star shader loaded")
	for i in int(r[0].star_duration / (1.0 / 60.0)) + 5:
		r[0].step(1.0 / 60.0, 0.0, 0.0, 0.0, false)
	runner.check(not r[1].star_glitter.emitting, "glitter stops")
	for m in r[1].star_meshes:
		runner.check(m.material_overlay == null, "overlay off")
	r[1].queue_free()
	body.free()

func test_lightning_bolt_shape_and_fade() -> void:
	var LB := preload("res://scripts/lightning_bolt.gd")
	var ground := Vector3(3, 0.5, -7)
	var pts: PackedVector3Array = LB.make_points(ground, 5)
	runner.check(pts.size() == LB.SEGMENTS + 1)
	runner.check(pts[-1].is_equal_approx(ground), "ends at kart")
	runner.check(is_equal_approx(pts[0].y, ground.y + LB.HEIGHT), "starts in sky")
	runner.check(pts == LB.make_points(ground, 5), "deterministic")
	for i in range(1, pts.size()):
		runner.check(pts[i].y < pts[i - 1].y, "descends")
	var b = LB.new()
	_tree().add_child(b)
	b.build(ground)
	runner.check(b.materials.size() == LB.SEGMENTS)
	runner.check(b.tick(LB.LIFETIME * 0.5))
	runner.check(b.materials[0].albedo_color.a < 0.9, "fading")
	runner.check(not b.tick(LB.LIFETIME), "expires")
	b.queue_free()
