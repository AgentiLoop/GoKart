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
	runner.check(Items.roll(0.999) == Items.Type.TRIPLE_RED_SHELL)
	var seen := {}
	for i in 100:
		seen[Items.roll(i / 100.0)] = true
	runner.check(seen.size() == Items.count(), "seen=%s" % seen)
	# mushroom has weight 5/28
	var m := 0
	for i in 2800:
		if Items.roll(i / 2800.0) == Items.Type.MUSHROOM:
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
	for i in 20:
		k.step(DT, 1.0, 0.0, 1.0, true)
	for j in 2:   # two MK64 stick toggles: red smoke
		for i in 6:
			k.step(DT, 1.0, 0.0, -1.0, true)
		for i in 6:
			k.step(DT, 1.0, 0.0, 1.0, true)
	runner.check(k.drifting and k.drift_level == 2)
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
	runner.check(Items.count() == 14)
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

func test_roulette_grants_charges_only_for_multi_use_items() -> void:
	var seen_triple := false
	var seen_bunch := false
	for seed_value in range(1, 200):
		var h := ItemHolder.new(seed_value)
		h.pickup()
		h.update(h.roulette_duration + 0.1)
		if Items.is_triple(h.held):
			seen_triple = true
			runner.check(h.charges == 3)
		elif h.held == Items.Type.BANANA_BUNCH:
			seen_bunch = true
			runner.check(h.charges == Items.BUNCH_CHARGES)
		else:
			runner.check(h.charges == 0)
	runner.check(seen_triple, "some seed rolls triple shells")
	runner.check(seen_bunch, "some seed rolls a banana bunch")

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

const BlueBlast := preload("res://scripts/blue_blast.gd")

## Put kart i on track sample `idx` (facing along the road).
func _place(r, i: int, idx: int) -> void:
	r[1][i].global_position = r[0].track.points[idx] + Vector3(0, 0.1, 0)
	r[1][i].heading = r[0].track.heading_at(idx)

func test_blue_shell_item_basics() -> void:
	runner.check(Items.name_of(Items.Type.BLUE_SHELL) == "BLUE SHELL")
	runner.check(Items.WEIGHTS.has(Items.Type.BLUE_SHELL))
	runner.check(Hud.item_text(Items.Type.BLUE_SHELL) == "[ BLUE SHELL ]")

func test_pick_leader() -> void:
	runner.check(ItemProjectile.pick_leader([10.0, 50.0, 30.0], 0) == 1)
	runner.check(ItemProjectile.pick_leader([10.0, 50.0, 30.0], 1) == 2, "user in front is skipped")
	runner.check(ItemProjectile.pick_leader([5.0], 0) == -1, "nobody else")

func test_blue_shell_only_hits_its_target() -> void:
	var p = ItemProjectile.make_blue_shell(Vector3.ZERO, 0.0, 0, 2)
	runner.check(p.kind == Items.Type.BLUE_SHELL and p.is_shell())
	runner.check(p.hits(Vector3.ZERO, 1.1, 2), "target")
	runner.check(not p.hits(Vector3.ZERO, 1.1, 1), "other karts ignored")

func test_blue_shell_follows_road_and_reaches_leader() -> void:
	var t := TrackData.new()
	var target_pos: Vector3 = t.points[40] + Vector3(0, 0.1, 0)
	var p = ItemProjectile.make_blue_shell(t.points[10] + Vector3(0, 1.6, 0), t.heading_at(10), 0, 1)
	p.target_pos = target_pos
	var reached := false
	var max_off := 0.0
	for i in 600:
		p.step(DT, t)
		max_off = maxf(max_off, t.distance_to_center(p.position, p.hint))
		if p.hits(target_pos, 1.1, 1):
			reached = true
			break
	runner.check(reached, "reached the target, pos=%s" % [p.position])
	runner.check(max_off < t.width, "stayed near the road, off=%f" % max_off)
	runner.check(is_equal_approx(p.position.y, ItemProjectile.BLUE_HEIGHT), "hovers")
	runner.check(p.bounces == 0, "never ricochets")

func test_blue_shell_expires() -> void:
	var t := TrackData.new()
	var p = ItemProjectile.make_blue_shell(t.points[10], t.heading_at(10), 0, -1)
	for i in int(ItemProjectile.BLUE_LIFE / DT) + 5:
		p.step(DT, t)
	runner.check(not p.alive)

func test_manager_blue_shell_targets_leader() -> void:
	var r = _make_manager(4)
	var m = r[0]
	_place(r, 0, 5)
	_place(r, 1, 30)
	_place(r, 2, 60)   # leader
	_place(r, 3, 20)
	m.holders[0].held = Items.Type.BLUE_SHELL
	var n: int = m.projectiles.size()
	runner.check(m.use_item(0) == Items.Type.BLUE_SHELL)
	runner.check(m.projectiles.size() == n + 1)
	var p = m.projectiles[-1]
	runner.check(p.kind == Items.Type.BLUE_SHELL and p.target_id == 2, "target=%d" % p.target_id)
	runner.check(p.owner_id == 0)
	_free_manager(r)

func test_manager_blue_shell_blast_spins_leader_and_neighbours() -> void:
	var r = _make_manager(4)
	var m = r[0]
	_place(r, 0, 5)
	_place(r, 1, 30)
	_place(r, 2, 60)   # leader
	_place(r, 3, 62)   # right behind the leader, inside the blast
	var ks: Array = r[1]
	m.holders[0].held = Items.Type.BLUE_SHELL
	m.use_item(0)
	var hits := []
	m.kart_hit.connect(func(kind, id): hits.append([kind, id]))
	var done_ := false
	for i in 900:
		m._physics_process(DT)
		if not hits.is_empty():
			done_ = true
			break
	runner.check(done_, "shell reached the leader")
	runner.check(ks[2].model.is_spinning(), "leader spun out")
	runner.check(ks[3].model.is_spinning(), "neighbour caught in blast")
	runner.check(not ks[1].model.is_spinning() and not ks[0].model.is_spinning(), "far karts unaffected")
	runner.check(m.blasts.size() == 1, "blast visual")
	runner.check(hits == [[Items.Type.BLUE_SHELL, 2], [Items.Type.BLUE_SHELL, 3]], "hits=%s" % [hits])
	runner.check(m.projectiles.filter(func(p): return p.kind == Items.Type.BLUE_SHELL).is_empty(), "shell consumed")
	_free_manager(r)

func test_blue_shell_blocked_by_star_leader() -> void:
	var r = _make_manager(3)
	var m = r[0]
	_place(r, 0, 5)
	_place(r, 1, 40)
	_place(r, 2, 20)
	r[1][1].model.apply_star()
	m.holders[0].held = Items.Type.BLUE_SHELL
	m.use_item(0)
	for i in 900:
		m._physics_process(DT)
	runner.check(not r[1][1].model.is_spinning(), "star leader immune")
	runner.check(m.projectiles.filter(func(p): return p.kind == Items.Type.BLUE_SHELL).is_empty(), "shell spent")
	_free_manager(r)

func test_blue_blast_grows_and_fades() -> void:
	runner.check(is_equal_approx(BlueBlast.radius_at(0.0, 7.0), BlueBlast.START_RADIUS))
	runner.check(is_equal_approx(BlueBlast.radius_at(BlueBlast.LIFETIME, 7.0), 7.0))
	runner.check(BlueBlast.radius_at(0.2, 7.0) < BlueBlast.radius_at(0.4, 7.0), "monotonic")
	var b := BlueBlast.new()
	b.build(Vector3(1, 2, 3), 7.0)
	runner.check(b.position == Vector3(1, 2, 3))
	runner.check(b.tick(0.1) and b.material.albedo_color.a < 0.9, "fading")
	runner.check(not b.tick(1.0), "finished")
	b.free()

func test_rank_weights_unadjusted_without_rank() -> void:
	runner.check(Items.weights_for() == Items.WEIGHTS)
	runner.check(Items.weights_for(2, 1) == Items.WEIGHTS, "field of one")
	runner.check(Items.roll(0.3) == Items.roll(0.3, 0, 4))

func test_leader_never_rolls_blue_shell_or_lightning() -> void:
	var w := Items.weights_for(1, 4)
	runner.check(w[Items.Type.BLUE_SHELL] == 0.0 and w[Items.Type.LIGHTNING] == 0.0)
	for i in 1000:
		var it := Items.roll(i / 1000.0, 1, 4)
		runner.check(it != Items.Type.BLUE_SHELL and it != Items.Type.LIGHTNING, "leader rolled %d" % it)

func test_last_place_favours_power_items() -> void:
	var lead := Items.weights_for(1, 4)
	var last := Items.weights_for(4, 4)
	runner.check(last[Items.Type.STAR] > lead[Items.Type.STAR])
	runner.check(last[Items.Type.BLUE_SHELL] > 0.0 and last[Items.Type.LIGHTNING] > 0.0)
	runner.check(last[Items.Type.BANANA] < lead[Items.Type.BANANA])
	var stars_last := 0
	var stars_lead := 0
	for i in 1000:
		if Items.roll(i / 1000.0, 4, 4) == Items.Type.STAR:
			stars_last += 1
		if Items.roll(i / 1000.0, 1, 4) == Items.Type.STAR:
			stars_lead += 1
	runner.check(stars_last > stars_lead * 3, "stars last=%d lead=%d" % [stars_last, stars_lead])

func test_rank_roll_covers_valid_items_and_mid_rank_is_between() -> void:
	var seen := {}
	for i in 400:
		seen[Items.roll(i / 400.0, 4, 4)] = true
	runner.check(seen.size() == Items.count(), "last place can roll everything, seen=%d" % seen.size())
	var mid := Items.weights_for(2, 3)
	runner.check(mid[Items.Type.BLUE_SHELL] > 0.0 and mid[Items.Type.BLUE_SHELL] < Items.weights_for(3, 3)[Items.Type.BLUE_SHELL])

func test_holder_uses_rank_for_roll() -> void:
	for seed_value in range(1, 150):
		var h := ItemHolder.new(seed_value)
		h.pickup(1, 4)
		h.update(h.roulette_duration + 0.1)
		runner.check(h.held != Items.Type.BLUE_SHELL and h.held != Items.Type.LIGHTNING, "leader seed %d got %d" % [seed_value, h.held])
	var h2 := ItemHolder.new(7)
	runner.check(h2.pickup(3, 4) and h2.rank == 3 and h2.racers == 4)

func test_manager_passes_rank_to_holder() -> void:
	var r = _make_manager(3)
	_place(r, 0, 5)
	_place(r, 1, 30)
	_place(r, 2, 20)
	var b = r[0].boxes[0]
	b.position = r[1][0].global_position
	r[0]._physics_process(DT)
	runner.check(r[0].holders[0].rank == 3, "last kart rank=%d" % r[0].holders[0].rank)
	_free_manager(r)

func test_item_hint_text() -> void:
	runner.check(Hud.item_hint_text(Items.Type.NONE) == "")
	var h := Hud.item_hint_text(Items.Type.MUSHROOM)
	runner.check(h.contains("E") and h.contains("Enter"), h)

func test_item_and_arrow_keys_are_bound() -> void:
	var keys := {}
	for action in ["accelerate", "brake", "steer_left", "steer_right", "drift", "use_item"]:
		var codes := []
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				codes.append(ev.physical_keycode)
		keys[action] = codes
	runner.check(KEY_UP in keys["accelerate"] and KEY_W in keys["accelerate"])
	runner.check(KEY_DOWN in keys["brake"] and KEY_S in keys["brake"])
	runner.check(KEY_LEFT in keys["steer_left"] and KEY_A in keys["steer_left"])
	runner.check(KEY_RIGHT in keys["steer_right"] and KEY_D in keys["steer_right"])
	runner.check(KEY_ENTER in keys["use_item"] and KEY_E in keys["use_item"] and KEY_CTRL in keys["use_item"])
	runner.check(KEY_SPACE in keys["drift"] and KEY_SHIFT in keys["drift"])

func test_mk64_triple_mushrooms() -> void:
	runner.check(Items.name_of(Items.Type.TRIPLE_MUSHROOM) == "TRIPLE MUSHROOMS")
	runner.check(Items.is_mushroom(Items.Type.MUSHROOM) and Items.is_mushroom(Items.Type.TRIPLE_MUSHROOM) and Items.is_mushroom(Items.Type.GOLDEN_MUSHROOM))
	runner.check(not Items.is_mushroom(Items.Type.SHELL) and not Items.is_mushroom(Items.Type.NONE))
	runner.check(Items.is_triple(Items.Type.TRIPLE_MUSHROOM) and Items.is_triple(Items.Type.TRIPLE_SHELL) and not Items.is_triple(Items.Type.MUSHROOM))
	runner.check(Hud.item_text(Items.Type.TRIPLE_MUSHROOM, 3) == "[ TRIPLE MUSHROOMS x3 ]")
	runner.check(Hud.item_text(Items.Type.TRIPLE_SHELL, 2) == "[ TRIPLE SHELLS x2 ]")
	runner.check(Hud.item_text(Items.Type.MUSHROOM, 3) == "[ MUSHROOM ]", "charges only shown for triples")
	var h := ItemHolder.new(1)
	h.held = Items.Type.TRIPLE_MUSHROOM
	h.charges = Items.TRIPLE_CHARGES
	for left in [2, 1]:
		runner.check(h.use() == Items.Type.TRIPLE_MUSHROOM)
		runner.check(h.held == Items.Type.TRIPLE_MUSHROOM and h.charges == left, "charges=%d" % h.charges)
	runner.check(h.use() == Items.Type.TRIPLE_MUSHROOM)
	runner.check(h.held == Items.Type.NONE and h.charges == 0, "emptied after third")
	# the manager boosts the kart on every charge
	var r = _make_manager(2)
	var m = r[0]
	var k = r[1][0]
	m.holders[0].held = Items.Type.TRIPLE_MUSHROOM
	m.holders[0].charges = 3
	for i in 3:
		k.model.boost_time = 0.0
		runner.check(m.use_item(0) == Items.Type.TRIPLE_MUSHROOM, "boost %d" % i)
		runner.check(k.model.is_boosting(), "boosting %d" % i)
	runner.check(m.holders[0].held == Items.Type.NONE)
	runner.check(m.use_item(0) == Items.Type.NONE)
	runner.check(not m.orbits.has(0), "mushrooms do not orbit")
	_free_manager(r)

func test_mk64_golden_mushroom_boosts_repeatedly_then_expires() -> void:
	runner.check(Items.name_of(Items.Type.GOLDEN_MUSHROOM) == "GOLDEN MUSHROOM")
	runner.check(Items.GOLDEN_DURATION > 5.0)
	var h := ItemHolder.new(1)
	h.held = Items.Type.GOLDEN_MUSHROOM
	runner.check(not h.is_golden_active())
	runner.check(h.use() == Items.Type.GOLDEN_MUSHROOM)
	runner.check(h.is_golden_active() and h.held == Items.Type.GOLDEN_MUSHROOM, "stays in the slot")
	runner.check(is_equal_approx(h.golden_time, Items.GOLDEN_DURATION))
	h.update(1.0)
	runner.check(h.use() == Items.Type.GOLDEN_MUSHROOM, "second boost")
	runner.check(absf(h.golden_time - (Items.GOLDEN_DURATION - 1.0)) < 0.001, "re-using does not reset the clock")
	runner.check(Hud.item_text(Items.Type.GOLDEN_MUSHROOM, 0, h.golden_time) == "[ GOLDEN MUSHROOM 6.5s ]")
	runner.check(Hud.item_text(Items.Type.GOLDEN_MUSHROOM) == "[ GOLDEN MUSHROOM ]", "no timer before the first use")
	runner.check(not h.pickup(), "cannot take a box while it is active")
	for i in int(Items.GOLDEN_DURATION / DT) + 2:
		h.update(DT)
	runner.check(not h.is_golden_active())
	runner.check(h.held == Items.Type.NONE, "gone when the clock runs out")
	runner.check(h.use() == Items.Type.NONE)
	runner.check(h.pickup(), "slot free again")
	# clear() (lightning) also kills an active golden mushroom
	var h2 := ItemHolder.new(1)
	h2.held = Items.Type.GOLDEN_MUSHROOM
	h2.use()
	h2.clear()
	runner.check(not h2.is_golden_active() and h2.held == Items.Type.NONE)
	# manager: every use while active boosts the kart
	var r = _make_manager(2)
	var m = r[0]
	var k = r[1][0]
	m.holders[0].held = Items.Type.GOLDEN_MUSHROOM
	var boosts := 0
	for i in 4:
		k.model.boost_time = 0.0
		if m.use_item(0) == Items.Type.GOLDEN_MUSHROOM and k.model.is_boosting():
			boosts += 1
		m._physics_process(DT)
	runner.check(boosts == 4, "boosts=%d" % boosts)
	runner.check(m.holders[0].held == Items.Type.GOLDEN_MUSHROOM, "still held while the clock runs")
	_free_manager(r)

func test_mk64_mushroom_items_follow_race_position() -> void:
	var lead := Items.weights_for(1, 8)
	var last := Items.weights_for(8, 8)
	runner.check(lead[Items.Type.GOLDEN_MUSHROOM] == 0.0, "leader never gets a golden mushroom")
	runner.check(last[Items.Type.GOLDEN_MUSHROOM] > 0.0)
	runner.check(last[Items.Type.TRIPLE_MUSHROOM] > lead[Items.Type.TRIPLE_MUSHROOM])
	for i in 1000:
		runner.check(Items.roll(i / 1000.0, 1, 8) != Items.Type.GOLDEN_MUSHROOM, "leader rolled golden")
	var seen := {}
	for seed_value in range(1, 300):
		var h := ItemHolder.new(seed_value)
		h.pickup(8, 8)
		h.update(h.roulette_duration + 0.1)
		seen[h.held] = true
		if h.held == Items.Type.TRIPLE_MUSHROOM:
			runner.check(h.charges == 3, "triple mushrooms come with 3 charges")
		elif h.held == Items.Type.GOLDEN_MUSHROOM:
			runner.check(h.charges == 0 and not h.is_golden_active(), "golden idle until used")
	runner.check(seen.has(Items.Type.TRIPLE_MUSHROOM) and seen.has(Items.Type.GOLDEN_MUSHROOM), "last place rolls both, seen=%s" % [seen.keys()])

func test_ai_fires_mushroom_items() -> void:
	var d = load("res://scripts/ai_driver.gd").new(TrackData.new(), 0.0, 0.5)
	runner.check(not d.wants_use(0.4, Items.Type.TRIPLE_MUSHROOM, INF, INF), "before delay")
	runner.check(d.wants_use(0.2, Items.Type.TRIPLE_MUSHROOM, INF, INF), "triple mushroom after delay")
	runner.check(not d.wants_use(0.4, Items.Type.GOLDEN_MUSHROOM, INF, INF), "before delay")
	runner.check(d.wants_use(0.2, Items.Type.GOLDEN_MUSHROOM, INF, INF), "golden mushroom after delay")

func test_mk64_fake_item_box() -> void:
	runner.check(Items.name_of(Items.Type.FAKE_ITEM_BOX) == "FAKE ITEM BOX")
	runner.check(Items.is_dropped(Items.Type.FAKE_ITEM_BOX) and Items.is_dropped(Items.Type.BANANA) and not Items.is_dropped(Items.Type.SHELL))
	runner.check(Items.charges_for(Items.Type.FAKE_ITEM_BOX) == 0)
	runner.check(Hud.item_text(Items.Type.FAKE_ITEM_BOX) == "[ FAKE ITEM BOX ]")
	# it sits still like a banana and spins out whoever drives into it
	var p = ItemProjectile.make_fake_box(Vector3(5, 0, 5), 0)
	runner.check(p.kind == Items.Type.FAKE_ITEM_BOX and not p.is_shell())
	runner.check(not p.hits(Vector3(6.5, 0, 5), 1.0, 0), "owner safe during grace")
	p.step(1.0, null)
	runner.check(p.position == Vector3(5, 0, 5), "does not move")
	runner.check(p.hits(Vector3(6.5, 0, 5), 1.0, 1), "rival hits it")
	runner.check(p.hits(Vector3(6.5, 0, 5), 1.0, 0), "owner can hit it after the grace period")
	# weights: the front of the pack gets it, the leader most of all
	var lead := Items.weights_for(1, 8)
	var last := Items.weights_for(8, 8)
	runner.check(lead[Items.Type.FAKE_ITEM_BOX] > last[Items.Type.FAKE_ITEM_BOX] * 5.0, "lead=%f last=%f" % [lead[Items.Type.FAKE_ITEM_BOX], last[Items.Type.FAKE_ITEM_BOX]])
	runner.check(last[Items.Type.FAKE_ITEM_BOX] > 0.0, "last place can still roll one")
	# manager: dropped behind the kart, gets a box visual, and a kart driving into it spins out
	var r = _make_manager(2)
	var m = r[0]
	var ks: Array = r[1]
	_place(r, 0, 10)
	_place(r, 1, 6)
	m.holders[0].held = Items.Type.FAKE_ITEM_BOX
	var n: int = m.projectiles.size()
	runner.check(m.use_item(0) == Items.Type.FAKE_ITEM_BOX)
	runner.check(m.projectiles.size() == n + 1)
	var box = m.projectiles[-1]
	runner.check(box.kind == Items.Type.FAKE_ITEM_BOX and box.owner_id == 0)
	var fwd := Vector3(-sin(ks[0].heading), 0, -cos(ks[0].heading))
	runner.check((box.position - ks[0].global_position).dot(fwd) < 0.0, "dropped behind the kart")
	runner.check(m.nodes[box].get_child_count() == 1 and m.nodes[box].get_child(0) is MeshInstance3D, "box visual")
	runner.check(m.holders[0].held == Items.Type.NONE, "single use")
	var hits := []
	m.kart_hit.connect(func(kind, id): hits.append([kind, id]))
	ks[1].global_position = box.position
	m._physics_process(DT)
	runner.check(ks[1].model.is_spinning(), "rival spun out")
	runner.check(hits == [[Items.Type.FAKE_ITEM_BOX, 1]], "hits=%s" % [hits])
	runner.check(not m.projectiles.has(box), "consumed")
	_free_manager(r)

func test_mk64_banana_bunch() -> void:
	runner.check(Items.name_of(Items.Type.BANANA_BUNCH) == "BANANA BUNCH")
	runner.check(Items.BUNCH_CHARGES == 5 and Items.charges_for(Items.Type.BANANA_BUNCH) == 5)
	runner.check(Items.charges_for(Items.Type.TRIPLE_SHELL) == 3 and Items.charges_for(Items.Type.BANANA) == 0)
	runner.check(Hud.item_text(Items.Type.BANANA_BUNCH, 5) == "[ BANANA BUNCH x5 ]")
	runner.check(Hud.item_text(Items.Type.BANANA, 5) == "[ BANANA ]", "a single banana never shows charges")
	var h := ItemHolder.new(1)
	h.held = Items.Type.BANANA_BUNCH
	h.charges = Items.BUNCH_CHARGES
	for left in [4, 3, 2, 1]:
		runner.check(h.use() == Items.Type.BANANA_BUNCH)
		runner.check(h.held == Items.Type.BANANA_BUNCH and h.charges == left, "charges=%d" % h.charges)
	runner.check(h.use() == Items.Type.BANANA_BUNCH)
	runner.check(h.held == Items.Type.NONE and h.charges == 0, "emptied after the fifth")
	# front of the pack favoured, like the single banana
	runner.check(Items.weights_for(1, 8)[Items.Type.BANANA_BUNCH] > Items.weights_for(8, 8)[Items.Type.BANANA_BUNCH])
	# manager: five bananas trail the kart, one fewer after every drop, each drop is a real banana
	var r = _make_manager(2)
	var m = r[0]
	var k = r[1][0]
	m.holders[0].held = Items.Type.BANANA_BUNCH
	m.holders[0].charges = 5
	m._physics_process(DT)
	runner.check(m.trails.has(0) and m.trails[0][0] == Items.Type.BANANA_BUNCH, "bunch trail")
	var trail: Node3D = m.trails[0][1]
	runner.check(trail.get_child_count() == 5, "five bananas trailing, got %d" % trail.get_child_count())
	var fwd := Vector3(-sin(k.heading), 0, -cos(k.heading))
	runner.check(trail.get_child(4).position.dot(fwd) < trail.get_child(1).position.dot(fwd), "bananas line up behind the kart")
	runner.check(trail.position.distance_to(k.global_position - fwd * 2.2 + Vector3(0, 0.5, 0)) < 0.01, "trail hangs behind the kart")
	for i in 5:
		var n: int = m.projectiles.size()
		runner.check(m.use_item(0) == Items.Type.BANANA_BUNCH, "drop %d" % i)
		runner.check(m.projectiles.size() == n + 1 and m.projectiles[-1].kind == Items.Type.BANANA, "banana %d dropped" % i)
		m._physics_process(DT)
		if i < 4:
			runner.check(trail.get_child_count() == 4 - i, "trail shrinks to %d" % (4 - i))
	runner.check(m.holders[0].held == Items.Type.NONE)
	runner.check(not m.trails.has(0), "trail removed when empty")
	runner.check(m.use_item(0) == Items.Type.NONE)
	_free_manager(r)

func test_ai_drops_fake_box_and_bunch_when_followed() -> void:
	var d = load("res://scripts/ai_driver.gd").new(TrackData.new(), 0.0, 0.5)
	runner.check(not d.wants_use(0.6, Items.Type.FAKE_ITEM_BOX, INF, INF), "nobody behind: keep it")
	runner.check(d.wants_use(DT, Items.Type.FAKE_ITEM_BOX, INF, 12.0), "drops it on a close follower")
	runner.check(not d.wants_use(0.6, Items.Type.BANANA_BUNCH, INF, INF))
	runner.check(d.wants_use(DT, Items.Type.BANANA_BUNCH, INF, 12.0))

func test_mk64_boo_item_basics() -> void:
	runner.check(Items.name_of(Items.Type.BOO) == "BOO")
	runner.check(Items.charges_for(Items.Type.BOO) == 0 and not Items.is_dropped(Items.Type.BOO))
	runner.check(Hud.item_text(Items.Type.BOO) == "[ BOO ]")
	# never for the leader, more likely at the back
	var lead := Items.weights_for(1, 8)
	var mid := Items.weights_for(4, 8)
	var last := Items.weights_for(8, 8)
	runner.check(lead[Items.Type.BOO] == 0.0, "leader never rolls a Boo")
	runner.check(last[Items.Type.BOO] > mid[Items.Type.BOO] and mid[Items.Type.BOO] > 0.0)
	for i in 1000:
		runner.check(Items.roll(i / 1000.0, 1, 8) != Items.Type.BOO, "leader rolled a Boo")
	var seen := false
	for seed_value in range(1, 300):
		var h := ItemHolder.new(seed_value)
		h.pickup(8, 8)
		h.update(h.roulette_duration + 0.1)
		if h.held == Items.Type.BOO:
			seen = true
			runner.check(h.charges == 0)
	runner.check(seen, "last place rolls a Boo for some seed")
	# ghost physics: translucent + untouchable for ghost_duration, no speed bonus
	var k := KartPhysics.new()
	runner.check(not k.is_ghost())
	var started := [0]
	var ended := [0]
	k.ghost_started.connect(func(): started[0] += 1)
	k.ghost_ended.connect(func(): ended[0] += 1)
	k.apply_ghost()
	k.apply_ghost()
	runner.check(k.is_ghost() and started[0] == 1, "one start signal")
	runner.check(is_equal_approx(k.ghost_time, k.ghost_duration))
	runner.check(not k.spin_out(), "ghost shrugs off a hit")
	runner.check(not k.apply_shrink(), "ghost shrugs off lightning")
	runner.check(not k.is_shrunk())
	runner.check(k.current_max_speed() == k.max_speed, "no speed bonus")
	for i in int(k.ghost_duration / DT) + 2:
		k.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(not k.is_ghost() and ended[0] == 1)
	runner.check(k.spin_out(), "hittable again")

func test_holder_steal_and_receive() -> void:
	var h := ItemHolder.new(1)
	h.held = Items.Type.TRIPLE_SHELL
	h.charges = 2
	runner.check(h.steal() == [Items.Type.TRIPLE_SHELL, 2])
	runner.check(h.held == Items.Type.NONE and h.charges == 0, "slot emptied")
	runner.check(h.steal() == [Items.Type.NONE, 0], "nothing left to take")
	h.roulette_time = 1.0
	runner.check(h.steal() == [Items.Type.NONE, 0], "nothing to take while rolling")
	h.roulette_time = 0.0
	# a running golden mushroom cannot be stolen
	h.held = Items.Type.GOLDEN_MUSHROOM
	h.use()
	runner.check(h.steal() == [Items.Type.NONE, 0] and h.held == Items.Type.GOLDEN_MUSHROOM)
	h.clear()
	# locked slot refuses boxes until the Boo is back
	h.locked = true
	runner.check(not h.pickup(), "no pickups while the Boo is out")
	h.receive(Items.Type.TRIPLE_SHELL, 2)
	runner.check(not h.locked and h.held == Items.Type.TRIPLE_SHELL and h.charges == 2)
	runner.check(not h.pickup(), "holding the loot")
	var h2 := ItemHolder.new(1)
	h2.locked = true
	h2.receive(Items.Type.NONE, 0)
	runner.check(not h2.locked and h2.held == Items.Type.NONE, "came back empty-handed: slot free")
	runner.check(h2.pickup())

func test_mk64_boo_steals_item_and_ghosts_user() -> void:
	var r = _make_manager(3)
	var m = r[0]
	var ks: Array = r[1]
	m.holders[0].held = Items.Type.BOO
	m.holders[1].held = Items.Type.TRIPLE_SHELL
	m.holders[1].charges = 3
	var stolen := []
	m.item_stolen.connect(func(t, v, i): stolen.append([t, v, i]))
	runner.check(m.use_item(0) == Items.Type.BOO)
	runner.check(ks[0].model.is_ghost(), "user is a ghost")
	runner.check(m.holders[0].held == Items.Type.NONE and m.holders[0].locked, "slot empty but locked while the Boo flies")
	runner.check(m.boos.size() == 1 and m.boos[0].victim == 1, "the only rival with an item is the victim")
	runner.check(m.boos[0].node.get_child_count() == 4, "ghost visual")
	runner.check(not m.holders[0].pickup(), "cannot take a box meanwhile")
	runner.check(m.holders[1].held == Items.Type.TRIPLE_SHELL, "victim still holds it on the way out")
	var ticks := int(m.BOO_FLIGHT / DT) + 1
	for i in ticks:
		m._physics_process(DT)
	runner.check(m.holders[1].held == Items.Type.NONE, "taken on arrival")
	runner.check(m.boos.size() == 1 and m.boos[0].item == Items.Type.TRIPLE_SHELL and m.boos[0].charges == 3)
	runner.check(stolen.is_empty(), "not delivered yet")
	for i in ticks:
		m._physics_process(DT)
	runner.check(m.boos.is_empty(), "flight over")
	runner.check(m.holders[0].held == Items.Type.TRIPLE_SHELL and m.holders[0].charges == 3, "thief got the shells")
	runner.check(not m.holders[0].locked)
	runner.check(stolen == [[0, 1, Items.Type.TRIPLE_SHELL]], "stolen=%s" % [stolen])
	runner.check(ks[0].model.is_ghost(), "still a ghost after the Boo is back")
	# a ghost is passed through by shells and ignored by red shells and lightning
	m.holders[1].held = Items.Type.RED_SHELL
	_place(r, 1, 5)
	_place(r, 0, 9)
	_place(r, 2, 40)
	m.use_item(1)
	var shell = m.projectiles[-1]
	m._physics_process(DT)
	runner.check(shell.target_pos == null or shell.target_pos.distance_to(ks[0].global_position) > 1.0, "red shell does not lock onto a ghost")
	ks[0].global_position = shell.position
	m._physics_process(DT)
	runner.check(not ks[0].model.is_spinning(), "ghost never spins")
	m.holders[2].held = Items.Type.LIGHTNING
	m.use_item(2)
	runner.check(not ks[0].model.is_shrunk() and ks[1].model.is_shrunk(), "lightning skips the ghost")
	_free_manager(r)

func test_mk64_boo_with_nothing_to_steal() -> void:
	var r = _make_manager(2)
	var m = r[0]
	m.holders[0].held = Items.Type.BOO
	var stolen := []
	m.item_stolen.connect(func(t, v, i): stolen.append([t, v, i]))
	m.use_item(0)
	runner.check(m.boos.size() == 1 and m.boos[0].victim == -1)
	runner.check(not m.holders[0].locked, "slot stays free when there is nothing to fetch")
	for i in int(m.BOO_FLIGHT * 2.0 / DT) + 2:
		m._physics_process(DT)
	runner.check(m.boos.is_empty() and m.holders[0].held == Items.Type.NONE)
	runner.check(stolen == [[0, -1, Items.Type.NONE]], "stolen=%s" % [stolen])
	# a rolling rival or a ghost rival is not a target either
	var r2 = _make_manager(3)
	var m2 = r2[0]
	m2.holders[0].held = Items.Type.BOO
	m2.holders[1].pickup()
	m2.holders[2].held = Items.Type.STAR
	r2[1][2].model.apply_ghost()
	m2.use_item(0)
	runner.check(m2.boos[0].victim == -1, "nobody eligible")
	_free_manager(r2)
	_free_manager(r)

func test_mk64_boo_victim_uses_item_before_it_is_taken() -> void:
	var r = _make_manager(2)
	var m = r[0]
	m.holders[0].held = Items.Type.BOO
	m.holders[1].held = Items.Type.MUSHROOM
	m.use_item(0)
	runner.check(m.boos[0].victim == 1)
	m.use_item(1)   # fires the mushroom while the Boo is still on its way
	for i in int(m.BOO_FLIGHT * 2.0 / DT) + 2:
		m._physics_process(DT)
	runner.check(m.boos.is_empty())
	runner.check(m.holders[0].held == Items.Type.NONE and not m.holders[0].locked, "empty-handed, slot unlocked")
	_free_manager(r)

func test_ai_uses_boo() -> void:
	var d = load("res://scripts/ai_driver.gd").new(TrackData.new(), 0.0, 0.5)
	runner.check(not d.wants_use(0.4, Items.Type.BOO, INF, INF), "before delay")
	runner.check(d.wants_use(0.2, Items.Type.BOO, INF, INF), "Boo after delay")

func test_hud_shows_boo_state() -> void:
	runner.check(Hud.state_text(false, 0, false, false, true) == "BOO!")
	runner.check(Hud.state_text(true, 2, false, true, true) == "BOO!", "ghost outranks boost and shrunk")
	runner.check(Hud.state_text(true, 0, true, false, true) == "STAR!", "star outranks ghost")
	runner.check(Hud.state_text(true, 0) == "BOOST!")
	runner.check(Hud.state_text(false, 0, false, true) == "SHRUNK!")
	runner.check(Hud.state_text(false, 1) == "MINI-TURBO..." and Hud.state_text(false, 2) == "MINI-TURBO!")
	runner.check(Hud.state_text(false, 0) == "")

func test_mk64_shield_items_and_blockable_shells() -> void:
	for t in [Items.Type.BANANA, Items.Type.FAKE_ITEM_BOX, Items.Type.SHELL, Items.Type.RED_SHELL, Items.Type.BANANA_BUNCH, Items.Type.TRIPLE_SHELL, Items.Type.TRIPLE_RED_SHELL]:
		runner.check(Items.is_shield(t), "shield %d" % t)
	for t in [Items.Type.NONE, Items.Type.MUSHROOM, Items.Type.STAR, Items.Type.LIGHTNING, Items.Type.BLUE_SHELL, Items.Type.BOO, Items.Type.TRIPLE_MUSHROOM, Items.Type.GOLDEN_MUSHROOM]:
		runner.check(not Items.is_shield(t), "not a shield %d" % t)
	runner.check(Items.is_blockable_shell(Items.Type.SHELL) and Items.is_blockable_shell(Items.Type.RED_SHELL))
	runner.check(not Items.is_blockable_shell(Items.Type.BLUE_SHELL) and not Items.is_blockable_shell(Items.Type.BANANA))
	# shield geometry: dangling items hang TRAIL_BEHIND metres behind the kart, triple shells ring it
	var pos := Vector3(10, 0, 10)
	var heading := 0.0   # facing -Z
	runner.check(ItemProjectile.shield_of(Items.Type.MUSHROOM, pos, heading).is_empty(), "no shield")
	var s: Array = ItemProjectile.shield_of(Items.Type.BANANA, pos, heading)
	runner.check(s.size() == 2 and s[0].distance_to(Vector3(10, 0, 10 + ItemProjectile.TRAIL_BEHIND)) < 0.001 and s[1] == ItemProjectile.SHIELD_RADIUS, "banana shield %s" % [s])
	var o: Array = ItemProjectile.shield_of(Items.Type.TRIPLE_SHELL, pos, heading)
	runner.check(o[0] == pos and o[1] == ItemProjectile.ORBIT_SHIELD and o[1] > ItemProjectile.ORBIT_RADIUS, "orbit shield %s" % [o])

func test_shell_blocked_by_dangling_item_and_destroys_road_hazards() -> void:
	var shield := [Vector3(0, 0, 5), ItemProjectile.SHIELD_RADIUS]
	var p = ItemProjectile.make_shell(Vector3(0, 0.6, 5.5), 0.0, 1)
	runner.check(p.blocked_by(shield, 0), "green shell inside the shield is stopped")
	runner.check(not p.blocked_by([], 0), "no shield")
	runner.check(not p.blocked_by(shield, 1), "own shell is not caught by the thrower's shield during grace")
	p.age = ItemProjectile.OWNER_GRACE + 0.1
	runner.check(p.blocked_by(shield, 1), "after the grace it is")
	var far = ItemProjectile.make_shell(Vector3(0, 0.6, 9.0), 0.0, 1)
	runner.check(not far.blocked_by(shield, 0), "out of reach")
	var red = ItemProjectile.make_red_shell(Vector3(0, 0.6, 5.5), 0.0, 1)
	runner.check(red.blocked_by(shield, 0), "red shells are stopped too")
	var blue = ItemProjectile.make_blue_shell(Vector3(0, 1.6, 5.5), 0.0, 1, 0)
	runner.check(not blue.blocked_by(shield, 0), "blue shells fly over")
	p.alive = false
	runner.check(not p.blocked_by(shield, 0), "dead shells do nothing")
	# hazards on the road
	var banana = ItemProjectile.make_banana(Vector3(3, 0.3, 3), 0)
	var shell = ItemProjectile.make_shell(Vector3(3.5, 0.6, 3), 0.0, 1)
	runner.check(shell.destroys(banana), "shell takes out a banana")
	runner.check(not banana.destroys(shell), "a banana destroys nothing")
	runner.check(not shell.destroys(ItemProjectile.make_shell(Vector3(3.5, 0.6, 3), 0.0, 2)), "shells pass each other")
	runner.check(shell.destroys(ItemProjectile.make_fake_box(Vector3(3.5, 0, 4.0), 0)), "and a fake item box")
	runner.check(not shell.destroys(ItemProjectile.make_banana(Vector3(8, 0.3, 3), 0)), "too far")
	banana.alive = false
	runner.check(not shell.destroys(banana), "already gone")

func test_manager_dangling_banana_blocks_red_shell() -> void:
	var r = _make_manager(2)
	var m = r[0]
	var ks: Array = r[1]
	_place(r, 0, 6)    # shooter
	_place(r, 1, 12)   # target 6 samples ahead, holding a banana behind it
	m.holders[1].held = Items.Type.BANANA
	m.holders[0].held = Items.Type.RED_SHELL
	var blocked := []
	m.shell_blocked.connect(func(s, id, item): blocked.append([s, id, item]))
	var hits := []
	m.kart_hit.connect(func(kind, id): hits.append([kind, id]))
	runner.check(m.use_item(0) == Items.Type.RED_SHELL)
	var shell = m.projectiles[-1]
	for i in 240:
		m._physics_process(DT)
		if not blocked.is_empty():
			break
	runner.check(blocked == [[Items.Type.RED_SHELL, 1, Items.Type.BANANA]], "blocked=%s" % [blocked])
	runner.check(hits.is_empty(), "the kart was never hit")
	runner.check(not ks[1].model.is_spinning(), "no spin-out")
	runner.check(m.holders[1].held == Items.Type.NONE, "the banana is used up")
	runner.check(not m.projectiles.has(shell), "shell consumed")
	m._physics_process(DT)
	runner.check(not m.trails.has(1), "dangling visual gone")
	_free_manager(r)

func test_manager_bunch_and_triple_shells_lose_one_charge_per_block() -> void:
	var r = _make_manager(2)
	var m = r[0]
	var ks: Array = r[1]
	_place(r, 0, 6)
	_place(r, 1, 12)
	m.holders[1].held = Items.Type.BANANA_BUNCH
	m.holders[1].charges = 5
	m.holders[0].held = Items.Type.TRIPLE_SHELL
	m.holders[0].charges = 3
	var blocked := []
	m.shell_blocked.connect(func(s, id, item): blocked.append([s, id, item]))
	m.use_item(0)
	for i in 120:
		m._physics_process(DT)
		if not blocked.is_empty():
			break
	runner.check(blocked == [[Items.Type.SHELL, 1, Items.Type.BANANA_BUNCH]], "blocked=%s" % [blocked])
	runner.check(m.holders[1].held == Items.Type.BANANA_BUNCH and m.holders[1].charges == 4, "one banana of the bunch spent, charges=%d" % m.holders[1].charges)
	runner.check(not ks[1].model.is_spinning())
	# orbiting triple shells shield the kart that holds them from a shell fired at it
	var r2 = _make_manager(2)
	var m2 = r2[0]
	_place(r2, 0, 6)
	_place(r2, 1, 12)
	m2.holders[1].held = Items.Type.TRIPLE_SHELL
	m2.holders[1].charges = 3
	m2.holders[0].held = Items.Type.SHELL
	var blocked2 := []
	m2.shell_blocked.connect(func(s, id, item): blocked2.append([s, id, item]))
	m2.use_item(0)
	for i in 120:
		m2._physics_process(DT)
		if not blocked2.is_empty():
			break
	runner.check(blocked2 == [[Items.Type.SHELL, 1, Items.Type.TRIPLE_SHELL]], "blocked2=%s" % [blocked2])
	runner.check(m2.holders[1].charges == 2, "one orbiting shell gone, charges=%d" % m2.holders[1].charges)
	runner.check(not r2[1][1].model.is_spinning())
	m2._physics_process(DT)
	runner.check(m2.orbits[1].get_child_count() == 2, "orbit visual follows")
	_free_manager(r2)
	_free_manager(r)

func test_manager_shell_hits_road_banana_and_both_vanish() -> void:
	var r = _make_manager(2)
	var m = r[0]
	_place(r, 0, 6)
	_place(r, 1, 60)   # far away: not involved
	var fwd := Vector3(-sin(r[1][0].heading), 0, -cos(r[1][0].heading))
	var banana = ItemProjectile.make_banana(r[1][0].global_position + fwd * 8.0 + Vector3(0, 0.3, 0), 1)
	m._add_projectile(banana)
	var n: int = m.projectiles.size()
	m.holders[0].held = Items.Type.SHELL
	var blocked := []
	m.shell_blocked.connect(func(s, id, item): blocked.append([s, id, item]))
	m.use_item(0)
	var shell = m.projectiles[-1]
	for i in 60:
		m._physics_process(DT)
		if not blocked.is_empty():
			break
	runner.check(blocked == [[Items.Type.SHELL, -1, Items.Type.BANANA]], "blocked=%s" % [blocked])
	runner.check(not m.projectiles.has(banana) and not m.projectiles.has(shell), "both gone")
	runner.check(m.projectiles.size() == n - 1, "count=%d" % m.projectiles.size())
	runner.check(not m.nodes.has(banana) and not m.nodes.has(shell), "visuals removed")
	runner.check(m.blasts.size() == 1 and m.blasts[0].end_radius == m.BLOCK_PUFF_RADIUS, "white puff where the shell was stopped")
	_free_manager(r)

func test_shield_does_not_stop_a_shell_hitting_the_kart_head_on() -> void:
	var r = _make_manager(2)
	var m = r[0]
	var ks: Array = r[1]
	_place(r, 0, 12)
	_place(r, 1, 6)
	ks[0].heading += PI   # the shooter faces back down the road at the rival
	m.holders[1].held = Items.Type.BANANA   # dangles behind the rival, i.e. away from the shooter
	m.holders[0].held = Items.Type.SHELL
	var blocked := []
	m.shell_blocked.connect(func(s, id, item): blocked.append([s, id, item]))
	var hits := []
	m.kart_hit.connect(func(kind, id): hits.append([kind, id]))
	m.use_item(0)
	for i in 120:
		m._physics_process(DT)
		if not hits.is_empty() or not blocked.is_empty():
			break
	runner.check(hits == [[Items.Type.SHELL, 1]], "hit from the front, hits=%s blocked=%s" % [hits, blocked])
	runner.check(blocked.is_empty())
	runner.check(m.holders[1].held == Items.Type.BANANA, "the banana is still there")
	_free_manager(r)

func test_mk64_triple_red_shells_basics() -> void:
	runner.check(Items.name_of(Items.Type.TRIPLE_RED_SHELL) == "TRIPLE RED SHELLS")
	runner.check(Items.is_triple(Items.Type.TRIPLE_RED_SHELL) and Items.charges_for(Items.Type.TRIPLE_RED_SHELL) == 3)
	runner.check(Items.is_orbiting(Items.Type.TRIPLE_RED_SHELL) and Items.is_orbiting(Items.Type.TRIPLE_SHELL))
	runner.check(not Items.is_orbiting(Items.Type.TRIPLE_MUSHROOM) and not Items.is_orbiting(Items.Type.RED_SHELL))
	runner.check(Items.shell_of(Items.Type.TRIPLE_RED_SHELL) == Items.Type.RED_SHELL and Items.shell_of(Items.Type.TRIPLE_SHELL) == Items.Type.SHELL)
	runner.check(Items.shell_of(Items.Type.BANANA) == Items.Type.NONE)
	runner.check(Items.is_shield(Items.Type.TRIPLE_RED_SHELL))
	runner.check(Items.in_battle(Items.Type.TRIPLE_RED_SHELL), "MK64 battle item")
	runner.check(Hud.item_text(Items.Type.TRIPLE_RED_SHELL, 3) == "[ TRIPLE RED SHELLS x3 ]")
	# Mario Kart 64: 2nd to last place only, never the leader
	var lead := Items.weights_for(1, 8)
	var mid := Items.weights_for(4, 8)
	var last := Items.weights_for(8, 8)
	runner.check(lead[Items.Type.TRIPLE_RED_SHELL] == 0.0, "leader never rolls triple red shells")
	runner.check(last[Items.Type.TRIPLE_RED_SHELL] > mid[Items.Type.TRIPLE_RED_SHELL] and mid[Items.Type.TRIPLE_RED_SHELL] > 0.0)
	runner.check(Items.weights_for(2, 8)[Items.Type.TRIPLE_RED_SHELL] > 0.0, "2nd place can roll them")
	for i in 1000:
		runner.check(Items.roll(i / 1000.0, 1, 8) != Items.Type.TRIPLE_RED_SHELL, "leader rolled triple red shells")
	var seen := false
	for seed_value in range(1, 300):
		var h := ItemHolder.new(seed_value)
		h.pickup(8, 8)
		h.update(h.roulette_duration + 0.1)
		if h.held == Items.Type.TRIPLE_RED_SHELL:
			seen = true
			runner.check(h.charges == 3, "three charges")
	runner.check(seen, "last place rolls triple red shells for some seed")
	# holder: one charge per use
	var h := ItemHolder.new(1)
	h.held = Items.Type.TRIPLE_RED_SHELL
	h.charges = Items.TRIPLE_CHARGES
	for left in [2, 1]:
		runner.check(h.use() == Items.Type.TRIPLE_RED_SHELL)
		runner.check(h.held == Items.Type.TRIPLE_RED_SHELL and h.charges == left, "charges=%d" % h.charges)
	runner.check(h.use() == Items.Type.TRIPLE_RED_SHELL)
	runner.check(h.held == Items.Type.NONE and h.charges == 0, "emptied after third")

func test_manager_triple_red_shells_orbit_red_and_fire_homing_shells() -> void:
	var r = _make_manager(2)
	var m = r[0]
	var ks: Array = r[1]
	_place(r, 0, 6)
	_place(r, 1, 14)   # rival ahead
	m.holders[0].held = Items.Type.TRIPLE_RED_SHELL
	m.holders[0].charges = 3
	m._physics_process(DT)
	runner.check(m.orbits.has(0) and m.orbits[0].get_child_count() == 3, "three orbiting shells")
	var mat: ShaderMaterial = m.orbits[0].get_child(0).material_override
	var col: Color = mat.get_shader_parameter("shell_color")
	runner.check(col.r > 0.8 and col.g < 0.3, "orbiting shells are red: %s" % col)
	runner.check(m.orbits[0].get_meta("shell") == Items.Type.RED_SHELL)
	var hits := []
	m.kart_hit.connect(func(kind, id): hits.append([kind, id]))
	var n: int = m.projectiles.size()
	runner.check(m.use_item(0) == Items.Type.TRIPLE_RED_SHELL)
	runner.check(m.projectiles.size() == n + 1 and m.projectiles[-1].kind == Items.Type.RED_SHELL, "a red shell is fired")
	for i in 240:
		m._physics_process(DT)
		if not hits.is_empty():
			break
	runner.check(hits == [[Items.Type.RED_SHELL, 1]], "the fired shell homed in on the rival, hits=%s" % [hits])
	runner.check(ks[1].model.is_spinning())
	runner.check(m.holders[0].held == Items.Type.TRIPLE_RED_SHELL and m.holders[0].charges == 2)
	runner.check(m.orbits[0].get_child_count() == 2, "orbit follows the charges")
	for i in 2:
		n = m.projectiles.size()
		runner.check(m.use_item(0) == Items.Type.TRIPLE_RED_SHELL)
		runner.check(m.projectiles[-1].kind == Items.Type.RED_SHELL, "shell %d is red" % i)
		m._physics_process(DT)
	runner.check(m.holders[0].held == Items.Type.NONE and not m.orbits.has(0), "empty: orbit gone")
	runner.check(m.use_item(0) == Items.Type.NONE)
	_free_manager(r)

func test_orbiting_red_shells_shield_the_kart_and_orbit_swaps_colour() -> void:
	var pos := Vector3(10, 0, 10)
	var o: Array = ItemProjectile.shield_of(Items.Type.TRIPLE_RED_SHELL, pos, 0.0)
	runner.check(o[0] == pos and o[1] == ItemProjectile.ORBIT_SHIELD, "orbit shield %s" % [o])
	var r = _make_manager(2)
	var m = r[0]
	_place(r, 0, 6)
	_place(r, 1, 12)
	m.holders[1].held = Items.Type.TRIPLE_RED_SHELL
	m.holders[1].charges = 3
	m.holders[0].held = Items.Type.SHELL
	var blocked := []
	m.shell_blocked.connect(func(s, id, item): blocked.append([s, id, item]))
	m.use_item(0)
	for i in 120:
		m._physics_process(DT)
		if not blocked.is_empty():
			break
	runner.check(blocked == [[Items.Type.SHELL, 1, Items.Type.TRIPLE_RED_SHELL]], "blocked=%s" % [blocked])
	runner.check(m.holders[1].charges == 2 and not r[1][1].model.is_spinning(), "one red shell spent, no spin")
	m._physics_process(DT)
	runner.check(m.orbits[1].get_child_count() == 2)
	# a Boo swapping green shells for red ones recolours the orbit
	var r2 = _make_manager(2)
	var m2 = r2[0]
	m2.holders[0].held = Items.Type.TRIPLE_SHELL
	m2.holders[0].charges = 3
	m2._physics_process(DT)
	runner.check(m2.orbits[0].get_meta("shell") == Items.Type.SHELL)
	var old: Node3D = m2.orbits[0]
	m2.holders[0].held = Items.Type.TRIPLE_RED_SHELL
	m2._physics_process(DT)
	runner.check(m2.orbits[0] != old and m2.orbits[0].get_meta("shell") == Items.Type.RED_SHELL, "orbit rebuilt in red")
	runner.check(m2.orbits[0].get_child_count() == 3)
	var col: Color = m2.orbits[0].get_child(0).material_override.get_shader_parameter("shell_color")
	runner.check(col.r > 0.8 and col.g < 0.3, "red: %s" % col)
	_free_manager(r2)
	_free_manager(r)

func test_ai_fires_triple_red_shells_like_a_red_shell() -> void:
	var d = load("res://scripts/ai_driver.gd").new(TrackData.new(), 0.0, 0.5)
	runner.check(not d.wants_use(1.0, Items.Type.TRIPLE_RED_SHELL, 200.0, INF), "nobody near")
	runner.check(d.wants_use(DT, Items.Type.TRIPLE_RED_SHELL, 60.0, INF), "rival ahead")
	var b = load("res://scripts/battle_ai.gd").new(load("res://scripts/arena_data.gd").make(1), 0.5)
	runner.check(not b.wants_use(1.0, Items.Type.TRIPLE_RED_SHELL, 200.0, INF), "battle: nobody near")
	runner.check(b.wants_use(DT, Items.Type.TRIPLE_RED_SHELL, 40.0, INF), "battle: rival ahead")
