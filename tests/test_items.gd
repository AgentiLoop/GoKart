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
	runner.check(Items.roll(0.99) == Items.Type.SHELL)
	var seen := {}
	for i in 100:
		seen[Items.roll(i / 100.0)] = true
	runner.check(seen.size() == 3, "seen=%s" % seen)
	# mushroom has weight 5/11
	var m := 0
	for i in 1100:
		if Items.roll(i / 1100.0) == Items.Type.MUSHROOM:
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
