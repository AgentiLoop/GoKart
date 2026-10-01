extends RefCounted
## Kart model tests: structure, wheel spin and steering.

const KartModel := preload("res://scripts/kart_model.gd")
var runner

func _make():
	var m = KartModel.new()
	Engine.get_main_loop().root.add_child(m)
	m.build(Color(0.2, 0.7, 0.3))
	return m

func test_structure() -> void:
	var m = _make()
	runner.check(m.wheel_spins.size() == 4, "wheels=%d" % m.wheel_spins.size())
	runner.check(m.front_pivots.size() == 2, "front=%d" % m.front_pivots.size())
	for p in m.front_pivots:
		runner.check(p.position.z < 0.0, "front wheel z")
	var meshes := m.find_children("*", "MeshInstance3D", true, false)
	runner.check(meshes.size() > 20, "meshes=%d" % meshes.size())
	runner.check(m.driver_head != null and m.steering_wheel != null)
	m.queue_free()

func test_wheels_spin_with_speed() -> void:
	var m = _make()
	m.update_wheels(0.1, 0.0, 0.0)
	var r0: float = m.wheel_spins[0].rotation.x
	runner.check(is_equal_approx(r0, 0.0), "stationary spin")
	m.update_wheels(0.1, 20.0, 0.0)
	var r1: float = m.wheel_spins[0].rotation.x
	runner.check(not is_equal_approx(r1, 0.0), "spins at speed")
	runner.check(is_equal_approx(r1, fmod(-KartModel.wheel_roll_rate(20.0) * 0.1, TAU)))
	m.queue_free()

func test_front_wheels_steer_rear_do_not() -> void:
	var m = _make()
	for i in 30:
		m.update_wheels(0.05, 10.0, 1.0)
	for p in m.front_pivots:
		runner.check(absf(p.rotation.y - KartModel.front_steer_angle(1.0)) < 0.01, "front yaw %f" % p.rotation.y)
	for s in m.wheel_spins:
		if not m.front_pivots.has(s.get_parent()):
			runner.check(is_equal_approx(s.get_parent().rotation.y, 0.0), "rear fixed")
	m.queue_free()

func test_steer_angle_clamped_and_signed() -> void:
	runner.check(KartModel.front_steer_angle(1.0) < 0.0)
	runner.check(KartModel.front_steer_angle(-1.0) > 0.0)
	runner.check(is_equal_approx(KartModel.front_steer_angle(5.0), KartModel.front_steer_angle(1.0)))
	runner.check(is_equal_approx(KartModel.front_steer_angle(0.0), 0.0))
	runner.check(is_equal_approx(KartModel.wheel_roll_rate(3.0), 10.0))
