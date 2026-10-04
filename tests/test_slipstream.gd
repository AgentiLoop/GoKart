extends RefCounted
## MK64 slipstream: the wake geometry (Slipstream) and the draft charge / burst in KartPhysics.

const Slipstream := preload("res://scripts/slipstream.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
var runner

const F := Vector3(0, 0, -1)   # heading north (-z), as a kart with heading 0

func test_in_wake_geometry() -> void:
	var lead := Vector3(0, 0, -50)
	# straight behind, inside the range: in the wake
	runner.check(Slipstream.in_wake(lead + Vector3(0, 0, 6), F, 25.0, lead, F, 25.0), "6 m behind drafts")
	runner.check(Slipstream.in_wake(lead + Vector3(1.5, 0, Slipstream.RANGE - 0.5), F, 25.0, lead, F, 25.0), "near the back edge, 1.5 m across, drafts")
	# too far back, too close, beside, ahead
	runner.check(not Slipstream.in_wake(lead + Vector3(0, 0, Slipstream.RANGE + 1.0), F, 25.0, lead, F, 25.0), "beyond the range: no draft")
	runner.check(not Slipstream.in_wake(lead + Vector3(0, 0, 0.5), F, 25.0, lead, F, 25.0), "nose to tail (a bump): no draft")
	runner.check(not Slipstream.in_wake(lead + Vector3(Slipstream.WIDTH + 0.5, 0, 6), F, 25.0, lead, F, 25.0), "beside the wake: no draft")
	runner.check(not Slipstream.in_wake(lead + Vector3(0, 0, -6), F, 25.0, lead, F, 25.0), "the kart in front drafts nobody")
	# both must roll the same way and at speed
	var east := Vector3(1, 0, 0)
	runner.check(not Slipstream.in_wake(lead + Vector3(0, 0, 6), east, 25.0, lead, F, 25.0), "crossing headings: no draft")
	runner.check(not Slipstream.in_wake(lead + Vector3(0, 0, 6), F, Slipstream.MIN_SPEED - 1.0, lead, F, 25.0), "too slow: no draft")
	runner.check(not Slipstream.in_wake(lead + Vector3(0, 0, 6), F, 25.0, lead, F, Slipstream.MIN_SPEED - 1.0), "leader too slow: no draft")
	# a slightly angled follower (within ALIGN) still drafts; the wake is measured along the leader's heading
	var tilted := Vector3(0.2, 0, -1).normalized()
	runner.check(Slipstream.in_wake(lead + Vector3(0, 0, 6), tilted, 25.0, lead, F, 25.0), "a few degrees off still drafts")
	# a leader heading east: the wake trails west of it
	var lead_e := Vector3(20, 0, 0)
	runner.check(Slipstream.in_wake(lead_e + Vector3(-6, 0, 0.5), east, 25.0, lead_e, east, 25.0), "wake trails behind an eastbound leader")
	runner.check(not Slipstream.in_wake(lead_e + Vector3(0, 0, 6), east, 25.0, lead_e, east, 25.0), "not south of it")

func test_leader_picks_the_nearest() -> void:
	var pos := [Vector3(0, 0, 0), Vector3(0, 0, -5), Vector3(0.5, 0, -10), Vector3(5, 0, -5)]
	var fwd := [F, F, F, F]
	var spd := [25.0, 25.0, 25.0, 25.0]
	runner.check(Slipstream.leader(0, pos, fwd, spd) == 1, "kart 0 drafts the nearer kart 1 (got %d)" % Slipstream.leader(0, pos, fwd, spd))
	runner.check(Slipstream.leader(1, pos, fwd, spd) == 2, "kart 1 drafts kart 2")
	runner.check(Slipstream.leader(2, pos, fwd, spd) == -1, "the front kart drafts nobody")
	runner.check(Slipstream.leader(3, pos, fwd, spd) == -1, "the kart out to the side drafts nobody")
	runner.check(Slipstream.leader(0, [Vector3.ZERO], [F], [25.0]) == -1, "alone: nobody")

func test_draft_charges_then_bursts() -> void:
	var k = KartPhysics.new()
	k.speed = k.max_speed
	var dt := 1.0 / 60.0
	var fired := 0
	var started: Array = []   # lambdas capture by value: count in arrays
	var ended: Array = []
	k.draft_started.connect(func(): started.append(1))
	k.draft_ended.connect(func(): ended.append(1))
	# half the charge, then out of the wake: the charge is dropped
	for i in int(k.draft_charge_time * 0.5 / dt):
		if k.update_draft(dt, true):
			fired += 1
		k.step(dt, 1.0, 0.0, 0.0, false)
	runner.check(k.is_drafting() and fired == 0 and not k.is_draft_boosting(), "charging, no burst yet")
	k.update_draft(dt, false)
	runner.check(not k.is_drafting() and k.draft_time == 0.0, "leaving the wake drops the charge")
	# a full charge fires exactly once and raises the top speed
	for i in int(k.draft_charge_time / dt) + 2:
		if k.update_draft(dt, true):
			fired += 1
		k.step(dt, 1.0, 0.0, 0.0, false)
	runner.check(fired == 1 and started.size() == 1, "the burst fired once after the charge (fired %d, started %d)" % [fired, started.size()])
	runner.check(k.is_draft_boosting(), "burst running")
	runner.check(is_equal_approx(k.current_max_speed(), k.max_speed * k.draft_speed_factor), "top speed up by the draft factor")
	runner.check(k.speed > k.max_speed + 1.0, "the kart actually sped up (%.1f)" % k.speed)
	runner.check(not k.is_boosting(), "a draft burst is not a mushroom boost (no flames)")
	# it expires after draft_boost_duration and the kart settles back to max_speed
	for i in int((k.draft_boost_duration + 1.0) / dt):
		k.update_draft(dt, false)
		k.step(dt, 1.0, 0.0, 0.0, false)
	runner.check(not k.is_draft_boosting() and ended.size() == 1, "burst over (ended %d)" % ended.size())
	runner.check(is_equal_approx(k.speed, k.max_speed), "back to the top speed (%.2f)" % k.speed)
	# off-road the burst still respects the surface
	k.surface_scale = 0.5
	k.draft_boost_time = 1.0
	runner.check(is_equal_approx(k.current_max_speed(), k.max_speed * k.draft_speed_factor * 0.5), "off-road burst is scaled by the surface")
	k.surface_scale = 1.0
	# a mushroom boost outranks the draft burst
	k.apply_boost(1.0)
	runner.check(is_equal_approx(k.current_max_speed(), k.max_speed * k.boost_speed_factor), "a real boost outranks the burst")

func test_draft_dropped_by_spin_stall_and_stop() -> void:
	var k = KartPhysics.new()
	var dt := 1.0 / 60.0
	var ended: Array = []
	k.draft_ended.connect(func(): ended.append(1))
	k.speed = 20.0
	k.draft_time = 1.0
	k.draft_boost_time = 1.0
	k.spin_out()
	runner.check(k.draft_time == 0.0 and not k.is_draft_boosting() and ended.size() == 1, "a hit drops the charge and the burst")
	runner.check(not k.update_draft(dt, true) and k.draft_time == 0.0, "no charging while spinning")
	var k2 = KartPhysics.new()
	k2.stall()
	runner.check(not k2.update_draft(dt, true) and k2.draft_time == 0.0, "no charging during a false start")
	var k3 = KartPhysics.new()
	k3.draft_boost_time = 1.0
	k3.draft_time = 0.5
	k3.stop()
	runner.check(k3.draft_time == 0.0 and not k3.is_draft_boosting(), "a dead stop (Lakitu) drops both")
	# a second charge while a burst still runs just extends it, without a second draft_started
	var k4 = KartPhysics.new()
	var started: Array = []
	k4.draft_started.connect(func(): started.append(1))
	k4.draft_boost_time = 0.2
	k4.draft_time = k4.draft_charge_time
	runner.check(k4.update_draft(dt, true) and started.is_empty() and is_equal_approx(k4.draft_boost_time, k4.draft_boost_duration), "re-fire extends a running burst silently")
