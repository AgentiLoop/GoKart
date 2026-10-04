extends RefCounted
## Mario Kart 64 Sherbet Land style ice: TrackData ice stretches, the KartPhysics slide and the AI's caution.

const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
var runner

const DT := 1.0 / 60.0

func test_ice_stretches() -> void:
	var t := TrackData.new(TrackData.DEFAULT_CONTROL, 16.0, {"ice": [[0.3, 0.355], [0.84, 0.895]]})
	runner.check(t.ice.size() == 2, "two stretches")
	var a: Dictionary = t.ice[0]
	runner.check(a.start == int(0.3 * t.count) and a.end == int(0.355 * t.count), "sample range %s" % [a])
	runner.check(t.ice_at(a.start) == a and t.ice_at(a.end) == a and t.ice_at(a.start - 1) == null and t.ice_at(a.end + 1) == null, "ice_at bounds")
	runner.check(t.ice_at(a.start + t.count) == a, "ice_at wraps")
	var mid: int = (a.start + a.end) / 2
	runner.check(t.on_ice(t.points[mid], mid), "on the road on ice")
	runner.check(t.on_ice(t.points[mid] + t.right_of(mid) * 7.0, mid), "near the edge, still ice")
	runner.check(not t.on_ice(t.points[mid] + t.right_of(mid) * 9.5, mid), "off the road: no ice")
	runner.check(not t.on_ice(t.points[a.end + 2], a.end + 2), "past the stretch")
	runner.check(t.ice_ahead(a.start - 10, 10) and not t.ice_ahead(a.start - 11, 10), "ice_ahead reaches n samples (inclusive)")
	runner.check(t.ice_ahead(a.end, 0) and not t.ice_ahead(a.end + 1, 3), "ice_ahead at / past the end")
	var bare := TrackData.new()
	runner.check(bare.ice.is_empty() and bare.ice_at(5) == null and not bare.on_ice(bare.points[5], 5) and not bare.ice_ahead(0, bare.count), "no ice by default")
	# the same stretches on the mirrored course (ice has no side)
	var m := TrackData.new(TrackData.DEFAULT_CONTROL, 16.0, {"ice": [[0.3, 0.355]], "mirror": true})
	runner.check(m.ice == [{"start": a.start, "end": a.end}], "mirror keeps the stretch %s" % [m.ice])

func test_frosty_peaks_has_ice_the_others_none() -> void:
	for i in TrackLibrary.count():
		var d := TrackLibrary.make_data(i)
		var icy: bool = TrackLibrary.info(i).name == "Frosty Peaks"
		runner.check(d.ice.is_empty() != icy, "%s ice %s" % [TrackLibrary.info(i).name, d.ice])
		if not icy:
			continue
		runner.check(d.ice.size() == 2, "two icy stretches")
		for s in d.ice:
			runner.check(s.end > s.start and s.end - s.start >= 10, "a stretch of road %s" % [s])
			# the ice keeps clear of the water edges and the snowmen (no sliding into the lake / a snowman)
			for k in range(s.start, s.end + 1):
				runner.check(d.water_at(k, 1) == null and d.water_at(k, -1) == null, "no water beside the ice at %d" % k)
			for sm in d.snowman_specs:
				var si: int = int(sm[0] * d.count)
				runner.check(si < s.start or si > s.end, "snowman %d off the ice %s" % [si, s])
	# the mirrored course (Extra) ices the same stretches
	var fp := TrackLibrary.make_data(2)
	var fm := TrackLibrary.make_data(2, true)
	runner.check(fp.ice == fm.ice, "mirror: same stretches")

func test_slide_on_ice_only() -> void:
	# tarmac: steering turns the direction of travel with the nose, no slide
	var k := KartPhysics.new()
	k.speed = k.max_speed
	for i in 30:
		k.step(DT, 1.0, 0.0, 1.0, false)
	runner.check(k.slide == 0.0 and k.travel_offset() == 0.0, "no slide on tarmac")
	# ice: the nose turns (right -> negative yaw) but part of the turn goes into a slide (travel lags the nose)
	var ice := KartPhysics.new()
	ice.grip = KartPhysics.ICE_GRIP
	ice.speed = ice.max_speed
	var yaw := 0.0
	for i in 30:
		yaw += ice.step(DT, 1.0, 0.0, 1.0, false)
	runner.check(yaw < 0.0, "the nose still turns")
	runner.check(ice.slide > 0.05 and ice.slide <= KartPhysics.MAX_SLIDE, "slide builds on ice (%.3f)" % ice.slide)
	runner.check(ice.travel_offset() == ice.slide, "travel_offset is the slide")
	# a steady turn settles to a steady slide, never past MAX_SLIDE
	for i in 240:
		ice.step(DT, 1.0, 0.0, 1.0, false)
	var steady: float = ice.slide
	runner.check(steady > 0.1 and steady <= KartPhysics.MAX_SLIDE, "steady slide %.3f" % steady)
	ice.step(DT, 1.0, 0.0, 1.0, false)
	runner.check(absf(ice.slide - steady) < 0.01, "settled")
	# straighten up on ice: the slide decays slowly
	for i in 15:
		ice.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(ice.slide > steady * 0.5 and ice.slide < steady, "still sliding a quarter second later (%.3f of %.3f)" % [ice.slide, steady])
	# back on tarmac the tires bite within a few frames
	ice.grip = 1.0
	for i in 12:
		ice.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(ice.slide == 0.0, "tires bite again on tarmac")
	# a crawling kart does not slide
	var slow := KartPhysics.new()
	slow.grip = KartPhysics.ICE_GRIP
	slow.speed = 2.0
	for i in 30:
		slow.step(DT, 0.0, 0.0, 1.0, false)
	runner.check(absf(slow.slide) < 0.02, "hardly any slide at a crawl (%.3f)" % slow.slide)
	# a dead stop drops the slide
	ice.grip = KartPhysics.ICE_GRIP
	ice.speed = ice.max_speed
	for i in 30:
		ice.step(DT, 1.0, 0.0, -1.0, false)
	runner.check(ice.slide < 0.0, "left turn: negative slide")
	ice.stop()
	runner.check(ice.slide == 0.0, "stop() clears the slide")

func test_ice_weakens_brakes_and_coasting() -> void:
	var a := KartPhysics.new()
	var b := KartPhysics.new()
	b.grip = KartPhysics.ICE_GRIP
	a.speed = 30.0
	b.speed = 30.0
	for i in 30:
		a.step(DT, 0.0, 1.0, 0.0, false)
		b.step(DT, 0.0, 1.0, 0.0, false)
	runner.check(b.speed > a.speed + 5.0, "brakes bite less on ice (%.1f vs %.1f)" % [b.speed, a.speed])
	a.speed = 30.0
	b.speed = 30.0
	for i in 60:
		a.step(DT, 0.0, 0.0, 0.0, false)
		b.step(DT, 0.0, 0.0, 0.0, false)
	runner.check(b.speed > a.speed + 2.0, "coasts further on ice (%.1f vs %.1f)" % [b.speed, a.speed])
	# the throttle and the top speed are unchanged
	a.speed = 0.0
	b.speed = 0.0
	for i in 600:
		a.step(DT, 1.0, 0.0, 0.0, false)
		b.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(is_equal_approx(a.speed, b.speed) and is_equal_approx(b.speed, b.max_speed), "same top speed on ice")

func test_ai_slows_for_a_bend_on_ice() -> void:
	var t := TrackLibrary.make_data(2)
	var d := AiDriver.new(t, 0.0)
	var s: Dictionary = t.ice[0]
	var dry: float = d.corner_speed(s.start)
	d.grip = KartPhysics.ICE_GRIP
	var icy: float = d.corner_speed(s.start)
	runner.check(icy < dry, "slower into the icy bend (%.1f vs %.1f)" % [icy, dry])
	runner.check(icy >= AiDriver.MIN_CORNER_SPEED, "never below the floor")
	runner.check(is_equal_approx(icy, maxf(dry * KartPhysics.ICE_GRIP * KartPhysics.ICE_GRIP, AiDriver.MIN_CORNER_SPEED)), "grip squared")
	# a straight stays a straight
	runner.check(d.corner_speed(2) == INF or d.corner_speed(2) > 60.0, "straight")
	# at the dry corner speed the driver lifts off on ice
	var out: Dictionary = d.decide(DT, t.points[s.start], t.heading_at(s.start), dry if dry < 100.0 else 40.0)
	runner.check(out.throttle == 0.0, "lifts off for the icy bend")
	d.grip = 1.0
	out = d.decide(DT, t.points[s.start], t.heading_at(s.start), 20.0)
	runner.check(out.throttle == 1.0, "flat out when the ice is gone")
