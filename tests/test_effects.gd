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
