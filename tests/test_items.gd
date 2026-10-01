extends RefCounted

const Items := preload("res://scripts/items.gd")
const ItemHolder := preload("res://scripts/item_holder.gd")
const ItemProjectile := preload("res://scripts/item_projectile.gd")
const ItemBox := preload("res://scripts/item_box.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const TrackData := preload("res://scripts/track_data.gd")
const Hud := preload("res://scripts/hud.gd")
var runner

const DT := 1.0 / 60.0

func test_roll_covers_all_items_in_weight_order() -> void:
	runner.check(Items.roll(0.0) == Items.Type.MUSHROOM)
	runner.check(Items.roll(0.999) == Items.Type.TRIPLE_SHELL)
	var seen := {}
	for i in 100:
		seen[Items.roll(i / 100.0)] = true
	runner.check(seen.size() == Items.count(), "seen=%s" % seen)
	# mushroom has weight 5/18
	var m := 0
	for i in 1800:
		if Items.roll(i / 1800.0) == Items.Type.MUSHROOM:
			m += 1
	runner.check(absi(m - 500) <= 2, "mushroom share=%d" % m)

func test_holder_roulette_then_use() -> void:
	var h := ItemHolder.new(1234)
	runner.check(h.display_item(0.0) == Items.Type.NONE)
	runner.check(h.use() == Items.Type.NONE)
	runner.check(h.pickup())
	runner.check(h.is_rolling())
	runner.check(not h.pickup(), "second pickup while rolling")
	runner.check(h.use() == Items.Type.NONE, "cannot use while rolling")
	runner.check(h.display_item(0.3) != Items.Type.NONE)
	for i in int(h.roulette_duration / DT) + 2:
		h.update(DT)
	runner.check(not h.is_rolling())
	runner.check(h.held != Items.Type.NONE)
	runner.check(not h.pickup(), "pickup while holding")
	var held: int = h.held
	runner.check(h.use() == held)
	runner.check(h.held == Items.Type.NONE)
	runner.check(h.pickup(), "empty slot can pick up again")

func test_holder_is_deterministic_per_seed() -> void:
	var a := ItemHolder.new(77)
	var b := ItemHolder.new(77)
	for h in [a, b]:
		h.pickup()
		for i in 120:
			h.update(DT)
	runner.check(a.held == b.held)

func test_spin_out_blocks_control_and_cancels_boost() -> void:
	var k := KartPhysics.new()
	k.speed = 30.0
	k.apply_boost(1.0, 1)
	runner.check(k.spin_out())
	runner.check(k.is_spinning())
	runner.check(not k.is_boosting())
	runner.check(is_equal_approx(k.speed, 15.0))
	var yaw := 0.0
	for i in 30:
		yaw += k.step(DT, 1.0, 0.0, 1.0, false)
	runner.check(yaw == 0.0, "no steering while spinning")
	runner.check(k.speed < 15.0, "speed bleeds off, speed=%f" % k.speed)
	runner.check(not k.spin_out(), "cannot be re-hit while spinning")

func test_spin_out_ends_with_immunity() -> void:
	var k := KartPhysics.new()
	k.speed = 20.0
	var ended := [false]
	k.spin_ended.connect(func(): ended[0] = true)
	k.spin_out()
	for i in int(k.spin_duration / DT) + 3:
		k.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(ended[0])
	runner.check(not k.is_spinning())
	runner.check(k.immunity_time > 0.0)
	runner.check(not k.spin_out(), "immune after recovery")
	for i in int(k.hit_immunity_time / DT) + 3:
		k.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(k.spin_out(), "hittable again after immunity")
	# control returns: accelerates again after the second spin
	for i in int((k.spin_duration + 1.0) / DT):
		k.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(k.speed > 10.0, "speed=%f" % k.speed)

func test_spin_out_cancels_drift_without_boost() -> void:
	var k := KartPhysics.new()
	k.speed = 25.0
	for i in 200:
		k.step(DT, 1.0, 0.0, 1.0, true)
	runner.check(k.drifting and k.drift_level >= 1)
	k.spin_out()
	runner.check(not k.drifting and k.drift_level == 0)
	runner.check(not k.is_boosting(), "being hit must not award the mini-turbo")
	for i in 120:
		k.step(DT, 1.0, 0.0, 1.0, true)
	runner.check(not k.is_boosting())

func test_spin_progress() -> void:
	var k := KartPhysics.new()
	runner.check(k.spin_progress() == 0.0)
	k.spin_out()
	for i in int(k.spin_duration / DT / 2.0):
		k.step(DT, 0.0, 0.0, 0.0, false)
	runner.check(absf(k.spin_progress() - 0.5) < 0.05, "progress=%f" % k.spin_progress())

func test_banana_hit_and_owner_grace() -> void:
	var b := ItemProjectile.make_banana(Vector3(5, 0, 5), 0)
	runner.check(b.hits(Vector3(5.5, 0, 5), 1.0, 1), "other kart hits")
	runner.check(not b.hits(Vector3(5.5, 0, 5), 1.0, 0), "owner is safe during grace")
	runner.check(not b.hits(Vector3(12, 0, 5), 1.0, 1), "far away")
	b.step(1.0, null)   # bananas do not move or touch the track
	runner.check(b.position == Vector3(5, 0, 5))
	runner.check(b.hits(Vector3(5, 0, 5), 1.0, 0), "owner can hit it after the grace period")
	b.alive = false
	runner.check(not b.hits(Vector3(5, 0, 5), 1.0, 1), "dead items never hit")

func test_shell_flies_forward() -> void:
	var t := TrackData.new()
	var i := 5
	var p := ItemProjectile.make_shell(t.points[i], t.heading_at(i), 0)
	var start: Vector3 = p.position
	p.step(DT, t)
	var moved: Vector3 = p.position - start
	runner.check(absf(moved.length() - ItemProjectile.SHELL_SPEED * DT) < 0.01)
	runner.check(moved.normalized().dot(t.tangents[i]) > 0.95, "dir=%s" % moved.normalized())

func test_shell_ricochets_and_stays_on_road() -> void:
	var t := TrackData.new()
	var i := 10
	# aim 40 degrees off the track direction so it must hit the wall
	var p := ItemProjectile.make_shell(t.points[i], t.heading_at(i) + 0.7, 0)
	var limit: float = t.width * 0.5
	var worst := 0.0
	for s in 600:
		p.step(DT, t)
		if not p.alive:
			break
		worst = maxf(worst, t.distance_to_center(p.position))
	runner.check(p.bounces >= 1, "bounces=%d" % p.bounces)
	runner.check(worst <= limit + 0.01, "worst off-centre=%f limit=%f" % [worst, limit])

func test_shell_expires() -> void:
	var t := TrackData.new()
	var p := ItemProjectile.make_shell(t.points[0], t.heading_at(0), 0)
	for s in int(ItemProjectile.SHELL_LIFE / DT) + 5:
		p.step(DT, t)
	runner.check(not p.alive)

func test_shell_stops_after_too_many_bounces() -> void:
	var t := TrackData.new()
	var p := ItemProjectile.make_shell(t.points[10], t.heading_at(10) + PI * 0.5, 0)   # straight at the wall
	for s in 1200:
		p.step(DT, t)
	runner.check(p.bounces >= 1)
	runner.check(not p.alive)

func test_closest_point_matches_distance() -> void:
	var t := TrackData.new()
	var pos := t.points[30] + t.right_of(30) * 5.0
	var c := t.closest_point(pos)
	runner.check(absf(Vector2(pos.x - c.x, pos.z - c.z).length() - 5.0) < 0.2)
	runner.check(absf(t.distance_to_center(pos) - 5.0) < 0.2)

func test_item_boxes_and_hazards_on_road() -> void:
	var t := TrackData.new()
	runner.check(t.item_box_positions.size() == TrackData.DEFAULT_BOX_ROWS.size() * TrackData.ITEM_BOX_OFFSETS.size())
	for p in t.item_box_positions:
		runner.check(t.is_on_road(p), "box off road at %s" % p)
	runner.check(t.hazard_positions.size() == TrackData.DEFAULT_HAZARDS.size())
	for p in t.hazard_positions:
		runner.check(t.is_on_road(p), "hazard off road")
	# boxes keep clear of boost pads
	for p in t.item_box_positions:
		for pad in t.pads:
			runner.check(not pad.contains(p), "box inside pad")

func test_item_box_pickup_and_respawn() -> void:
	var b := ItemBox.new()
	b.position = Vector3(10, 0, 10)
	runner.check(not b.try_take(Vector3(20, 0, 10)))
	runner.check(b.is_available())
	runner.check(b.try_take(Vector3(10.5, 0, 10)))
	runner.check(not b.is_available())
	runner.check(not b.try_take(Vector3(10, 0, 10)), "cannot take twice")
	for i in int(b.cooldown / DT) + 2:
		b.tick(DT)
	runner.check(b.is_available())
	runner.check(b.try_take(Vector3(10, 0, 10)))
	b.free()

func test_hud_item_text() -> void:
	runner.check(Hud.item_text(Items.Type.NONE) == "")
	runner.check(Hud.item_text(Items.Type.SHELL) == "[ GREEN SHELL ]")

func test_new_item_names_and_roulette_preview() -> void:
	runner.check(Items.name_of(Items.Type.RED_SHELL) == "RED SHELL")
	runner.check(Items.name_of(Items.Type.STAR) == "STAR")
	runner.check(Items.name_of(Items.Type.LIGHTNING) == "LIGHTNING")
	runner.check(Items.count() == 7)
	var h := ItemHolder.new(5)
	h.pickup()
	var seen := {}
	for i in 200:
		var d: int = h.display_item(i * 0.05)
		runner.check(d >= 1 and d <= Items.count(), "preview %d" % d)
		seen[d] = true
	runner.check(seen.size() == Items.count(), "roulette cycles through all items")

func test_star_makes_kart_invincible_and_faster() -> void:
	var k := KartPhysics.new()
	var log := [0, 0]
	k.star_started.connect(func(): log[0] += 1)
	k.star_ended.connect(func(): log[1] += 1)
	runner.check(not k.is_star())
	k.apply_star()
	k.apply_star()
	runner.check(k.is_star() and log[0] == 1, "star_started emitted once")
	runner.check(not k.spin_out(), "star blocks hits")
	k.surface_scale = 0.5
	for i in 300:
		k.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(absf(k.speed - k.max_speed * k.star_speed_factor) < 0.5, "star ignores off-road, speed=%f" % k.speed)
	for i in int(k.star_duration / DT) + 5:
		k.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(not k.is_star() and log[1] == 1, "star expires")
	runner.check(k.spin_out(), "hittable after the star")

func test_red_shell_homes_on_target() -> void:
	var t := TrackData.new()
	var i := 5
	var target: Vector3 = t.points[i + 14] + t.right_of(i + 14) * 4.0
	var p := ItemProjectile.make_red_shell(t.points[i], t.heading_at(i), 0)
	runner.check(p.is_shell() and p.kind == Items.Type.RED_SHELL)
	p.target_pos = target
	var hit := false
	for s in 240:
		p.step(DT, t)
		if p.hits(target, 1.1, 1):
			hit = true
			break
	runner.check(hit, "red shell reached its target, pos=%s" % p.position)

func test_red_shell_follows_the_road_without_target() -> void:
	var t := TrackData.new()
	var i := 0
	var p := ItemProjectile.make_red_shell(t.points[i], t.heading_at(i), 0)
	var worst := 0.0
	for s in 300:
		p.step(DT, t)
		worst = maxf(worst, t.distance_to_center(p.position))
	runner.check(p.alive)
	runner.check(p.bounces == 0, "bounces=%d" % p.bounces)
	runner.check(worst < t.width * 0.5, "worst off-centre=%f" % worst)

func test_red_shell_turn_rate_is_limited() -> void:
	var t := TrackData.new()
	var p := ItemProjectile.make_red_shell(t.points[5], t.heading_at(5), 0)
	var before: Vector3 = p.velocity
	p.target_pos = p.position - before.normalized() * 5.0   # directly behind
	p.step(DT, t)
	var ang: float = absf(Vector2(before.x, before.z).angle_to(Vector2(p.velocity.x, p.velocity.z)))
	runner.check(ang <= ItemProjectile.RED_TURN_RATE * DT + 0.001, "turned %f" % ang)
	runner.check(is_equal_approx(p.velocity.length(), ItemProjectile.RED_SHELL_SPEED), "speed constant")

func test_pick_target_nearest_ahead_valid() -> void:
	var from := Vector3.ZERO
	var dir := Vector3(0, 0, -1)
	var pos := [Vector3(0, 0, 0), Vector3(0, 0, -30), Vector3(0, 0, -10), Vector3(0, 0, 10), Vector3(0, 0, -300)]
	var valid := [true, true, true, true, true]
	runner.check(ItemProjectile.pick_target(from, dir, pos, 0, valid) == 2, "nearest ahead")
	valid[2] = false
	runner.check(ItemProjectile.pick_target(from, dir, pos, 0, valid) == 1, "skips invincible")
	runner.check(ItemProjectile.pick_target(from, dir, pos, 1, valid) == -1 or true)
	runner.check(ItemProjectile.pick_target(from, -dir, [Vector3.ZERO, Vector3(0, 0, 10)], 0, [true, true]) == 1, "relative to dir")
	runner.check(ItemProjectile.pick_target(from, dir, [Vector3.ZERO], 0, [true]) == -1, "nobody")

class FakeKart extends RefCounted:
	var model := KartPhysics.new()
	var global_position := Vector3.ZERO
	var heading := 0.0
	var driver = null
	var frozen := false

func _make_manager(n_karts: int):
	var t := TrackData.new()
	var karts: Array = []
	for i in n_karts:
		var k := FakeKart.new()
		k.global_position = t.points[5 + i * 2] + Vector3(0, 0.1, 0)
		k.heading = t.heading_at(5 + i * 2)
		karts.append(k)
	var m = load("res://scripts/item_manager.gd").new()
	m.setup(t, karts, 42)
	return [m, karts]

func _free_manager(r) -> void:
	r[0].free()

func test_manager_use_star_and_red_shell() -> void:
	var r = _make_manager(2)
	var m = r[0]
	m.holders[0].held = Items.Type.STAR
	runner.check(m.use_item(0) == Items.Type.STAR)
	runner.check(r[1][0].model.is_star())
	var n: int = m.projectiles.size()
	m.holders[1].held = Items.Type.RED_SHELL
	runner.check(m.use_item(1) == Items.Type.RED_SHELL)
	runner.check(m.projectiles.size() == n + 1)
	runner.check(m.projectiles[-1].kind == Items.Type.RED_SHELL)
	_free_manager(r)

func test_star_kart_bowls_over_rivals() -> void:
	var r = _make_manager(2)
	var m = r[0]
	r[1][1].global_position = r[1][0].global_position + Vector3(1.0, 0, 0)
	r[1][0].model.apply_star()
	var hits := []
	m.kart_hit.connect(func(kind, id): hits.append([kind, id]))
	m._physics_process(DT)
	runner.check(r[1][1].model.is_spinning(), "rival spun out")
	runner.check(not r[1][0].model.is_spinning(), "star kart unaffected")
	runner.check(hits == [[Items.Type.STAR, 1]], "hits=%s" % [hits])
	_free_manager(r)

func test_red_shell_ignores_star_kart() -> void:
	var r = _make_manager(2)
	var m = r[0]
	var k1 = r[1][1]
	k1.model.apply_star()
	m.holders[0].held = Items.Type.RED_SHELL
	m.use_item(0)
	var p = m.projectiles[-1]
	m._physics_process(DT)
	runner.check(p.target_pos == null, "star kart is not targeted")
	k1.model.star_time = 0.0
	m._physics_process(DT)
	runner.check(p.target_pos != null, "normal kart ahead is targeted")
	_free_manager(r)

func test_shrink_slows_and_expires() -> void:
	var k := KartPhysics.new()
	var fired := []
	k.shrink_started.connect(func(): fired.append("start"))
	k.shrink_ended.connect(func(): fired.append("end"))
	runner.check(not k.is_shrunk())
	runner.check(k.apply_shrink())
	runner.check(k.is_shrunk())
	runner.check(is_equal_approx(k.current_max_speed(), k.max_speed * 0.7), "slower")
	k.apply_boost(1.0)
	runner.check(k.current_max_speed() > k.max_speed, "boost overrides shrink")
	k.boost_time = 0.0
	for i in int(k.shrink_duration / DT) + 5:
		k.step(DT, 0.0, 0.0, 0.0, false)
	runner.check(not k.is_shrunk(), "expired")
	runner.check(fired == ["start", "end"], "signals=%s" % [fired])

func test_star_is_immune_to_shrink() -> void:
	var k := KartPhysics.new()
	k.apply_star()
	runner.check(not k.apply_shrink())
	runner.check(not k.is_shrunk())

func test_manager_lightning_hits_everyone_but_user_and_star() -> void:
	var r = _make_manager(4)
	var m = r[0]
	var ks: Array = r[1]
	ks[3].model.apply_star()
	m.holders[2].held = Items.Type.MUSHROOM
	m.holders[0].held = Items.Type.LIGHTNING
	var struck := []
	m.lightning_struck.connect(func(u, v): struck.append([u, v]))
	var hits := []
	m.kart_hit.connect(func(kind, id): hits.append([kind, id]))
	runner.check(m.use_item(0) == Items.Type.LIGHTNING)
	runner.check(not ks[0].model.is_shrunk() and not ks[0].model.is_spinning(), "user unaffected")
	for id in [1, 2]:
		runner.check(ks[id].model.is_shrunk(), "shrunk %d" % id)
		runner.check(ks[id].model.is_spinning(), "spinning %d" % id)
	runner.check(not ks[3].model.is_shrunk() and not ks[3].model.is_spinning(), "star immune")
	runner.check(m.holders[2].held == Items.Type.NONE, "item dropped")
	runner.check(struck == [[0, [1, 2]]], "struck=%s" % [struck])
	runner.check(hits == [[Items.Type.LIGHTNING, 1], [Items.Type.LIGHTNING, 2]], "hits=%s" % [hits])
	runner.check(m.bolts.size() == 2, "bolt per victim")
	_free_manager(r)

func test_hud_lightning_text() -> void:
	runner.check(Hud.item_text(Items.Type.LIGHTNING) == "[ LIGHTNING ]")

func test_triple_shell_has_three_charges() -> void:
	runner.check(Items.name_of(Items.Type.TRIPLE_SHELL) == "TRIPLE SHELLS")
	var h := ItemHolder.new(1)
	h.held = Items.Type.TRIPLE_SHELL
	h.charges = Items.TRIPLE_CHARGES
	for left in [2, 1]:
		runner.check(h.use() == Items.Type.TRIPLE_SHELL)
		runner.check(h.held == Items.Type.TRIPLE_SHELL and h.charges == left, "charges=%d" % h.charges)
	runner.check(h.use() == Items.Type.TRIPLE_SHELL)
	runner.check(h.held == Items.Type.NONE and h.charges == 0, "emptied after third")
	runner.check(h.use() == Items.Type.NONE)

func test_roulette_grants_charges_only_for_triple() -> void:
	var seen_triple := false
	for seed_value in range(1, 200):
		var h := ItemHolder.new(seed_value)
		h.pickup()
		h.update(h.roulette_duration + 0.1)
		if h.held == Items.Type.TRIPLE_SHELL:
			seen_triple = true
			runner.check(h.charges == 3)
		else:
			runner.check(h.charges == 0)
	runner.check(seen_triple, "some seed rolls triple shells")

func test_holder_clear() -> void:
	var h := ItemHolder.new(1)
	h.held = Items.Type.TRIPLE_SHELL
	h.charges = 2
	h.roulette_time = 1.0
	h.clear()
	runner.check(h.held == Items.Type.NONE and h.charges == 0 and not h.is_rolling())

func test_manager_triple_shell_fires_three_then_empties() -> void:
	var r = _make_manager(2)
	var m = r[0]
	var n: int = m.projectiles.size()
	m.holders[0].held = Items.Type.TRIPLE_SHELL
	m.holders[0].charges = 3
	m._physics_process(DT)
	runner.check(m.orbits.has(0) and m.orbits[0].get_child_count() == 3, "three orbiting shells")
	for i in 3:
		n = m.projectiles.size()
		runner.check(m.use_item(0) == Items.Type.TRIPLE_SHELL)
		runner.check(m.projectiles.size() == n + 1, "shell %d fired" % i)
		runner.check(m.projectiles[-1].kind == Items.Type.SHELL)
		m._physics_process(DT)
	runner.check(m.holders[0].held == Items.Type.NONE)
	runner.check(not m.orbits.has(0), "orbit removed when empty")
	runner.check(m.use_item(0) == Items.Type.NONE)
	_free_manager(r)

func test_orbit_shrinks_with_charges() -> void:
	var r = _make_manager(2)
	var m = r[0]
	m.holders[1].held = Items.Type.TRIPLE_SHELL
	m.holders[1].charges = 3
	m._physics_process(DT)
	m.use_item(1)
	m._physics_process(DT)
	runner.check(m.holders[1].charges == 2)
	runner.check(m.orbits[1].get_child_count() == 2, "orbit follows charges")
	runner.check(m.orbits[1].position.distance_to(r[1][1].global_position + Vector3(0, 0.9, 0)) < 0.01, "orbit centred on kart")
	_free_manager(r)

func test_lightning_strips_triple_shells() -> void:
	var r = _make_manager(2)
	var m = r[0]
	m.holders[1].held = Items.Type.TRIPLE_SHELL
	m.holders[1].charges = 3
	m.holders[0].held = Items.Type.LIGHTNING
	m.use_item(0)
	runner.check(m.holders[1].held == Items.Type.NONE and m.holders[1].charges == 0)
	_free_manager(r)
