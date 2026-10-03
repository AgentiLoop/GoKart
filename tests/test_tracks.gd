extends RefCounted
## Every track in TrackLibrary must be a valid, drivable circuit; plus title-menu logic.

const TrackLibrary := preload("res://scripts/track_library.gd")
const TrackData := preload("res://scripts/track_data.gd")
const LapTracker := preload("res://scripts/lap_tracker.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
const Menu := preload("res://scripts/menu.gd")
const Hud := preload("res://scripts/hud.gd")
var runner

const DT := 1.0 / 60.0

func test_library_has_several_distinct_tracks() -> void:
	runner.check(TrackLibrary.count() >= 2, "count=%d" % TrackLibrary.count())
	var names := {}
	for i in TrackLibrary.count():
		var info := TrackLibrary.info(i)
		runner.check(info.name != "" and info.blurb != "", "track %d has name/blurb" % i)
		names[info.name] = true
	runner.check(names.size() == TrackLibrary.count(), "names are unique")
	runner.check(TrackLibrary.info(0).control != TrackLibrary.info(1).control, "layouts differ")

func test_info_and_step_wrap() -> void:
	var n := TrackLibrary.count()
	runner.check(TrackLibrary.step(0, -1) == n - 1)
	runner.check(TrackLibrary.step(n - 1, 1) == 0)
	runner.check(TrackLibrary.step(0, 1) == 1 % n)
	runner.check(TrackLibrary.info(-1).name == TrackLibrary.info(n - 1).name)
	runner.check(TrackLibrary.info(n).name == TrackLibrary.info(0).name)

func test_default_track_matches_library_first_entry() -> void:
	var a := TrackData.new()
	var b := TrackLibrary.make_data(0)
	runner.check(a.count == b.count and is_equal_approx(a.length, b.length))

func test_each_track_is_closed_uniform_and_not_overlapping() -> void:
	for n in TrackLibrary.count():
		var t := TrackLibrary.make_data(n)
		runner.check(t.count > 150, "track %d count=%d" % [n, t.count])
		var worst := 0.0
		var best := INF
		for i in t.count:
			var d := t.points[i].distance_to(t.points[(i + 1) % t.count])
			worst = maxf(worst, d)
			best = minf(best, d)
		runner.check(worst < t.spacing * 1.3 and best > t.spacing * 0.5, "track %d gaps %f..%f" % [n, best, worst])
		runner.check(t.min_separation() > t.width * 1.5, "track %d separation=%f" % [n, t.min_separation()])

func test_each_track_has_a_straight_start() -> void:
	## The grid sits on the 12 samples before the line, and the line itself heads along -Z.
	for n in TrackLibrary.count():
		var t := TrackLibrary.make_data(n)
		runner.check(absf(t.heading_at(0)) < 0.3, "track %d start heading=%f" % [n, t.heading_at(0)])
		for k in range(-14, 3):
			var d: float = t.tangents[posmod(k, t.count)].dot(t.tangents[0])
			runner.check(d > 0.97, "track %d bend near start at %d (dot %f)" % [n, k, d])

func test_each_track_items_pads_hazards_on_road() -> void:
	for n in TrackLibrary.count():
		var t := TrackLibrary.make_data(n)
		runner.check(t.pads.size() >= 3, "track %d pads" % n)
		for p in t.pads:
			runner.check(t.is_on_road(p.center), "track %d pad off road" % n)
		runner.check(t.item_box_positions.size() >= 12, "track %d boxes" % n)
		for b in t.item_box_positions:
			runner.check(t.is_on_road(b), "track %d box off road" % n)
		runner.check(t.hazard_positions.size() >= 1, "track %d hazards" % n)
		for h in t.hazard_positions:
			runner.check(t.is_on_road(h), "track %d hazard off road" % n)

func test_each_track_has_a_sane_lap_length() -> void:
	for n in TrackLibrary.count():
		var t := TrackLibrary.make_data(n)
		runner.check(t.length > 500.0 and t.length < 2000.0, "track %d length=%f" % [n, t.length])

func test_ai_finishes_every_track() -> void:
	## One AI per track runs 3 laps without leaving the road for long.
	for n in TrackLibrary.count():
		var t := TrackLibrary.make_data(n)
		var k := KartPhysics.new()
		var drv := AiDriver.new(t, 0.0, 1.0)
		var lt := LapTracker.new(t.count, 8, 3)
		var start := t.count - 4
		var pos := t.points[start]
		var head := t.heading_at(start)
		var idx := -1
		var off := 0
		var time := 0.0
		while not lt.is_finished and time < 500.0:
			idx = t.nearest_index(pos, idx)
			var out: Dictionary = drv.decide(DT, pos, head, k.speed)
			k.surface_scale = 1.0 if t.is_on_road(pos, idx) else 0.5
			if k.surface_scale < 1.0:
				off += 1
			head += k.step(DT, out.throttle, out.brake, out.steer, out.drift)
			pos += Vector3(-sin(head), 0, -cos(head)) * k.speed * DT
			lt.update(DT, idx)
			time += DT
		runner.check(lt.is_finished, "track %d: AI did not finish (lap %d cp %d)" % [n, lt.lap, lt.next_cp])
		runner.check(off < 600, "track %d: off-road frames=%d" % [n, off])
		print("track %d (%s): AI total %s, offroad frames %d" % [n, TrackLibrary.info(n).name, Hud.format_time(lt.race_time), off])

func test_menu_keys() -> void:
	runner.check(Menu.direction_for_key(KEY_LEFT) == -1 and Menu.direction_for_key(KEY_A) == -1)
	runner.check(Menu.direction_for_key(KEY_RIGHT) == 1 and Menu.direction_for_key(KEY_D) == 1)
	runner.check(Menu.direction_for_key(KEY_X) == 0 and Menu.direction_for_key(KEY_ENTER) == 0)
	runner.check(Menu.is_confirm_key(KEY_ENTER) and Menu.is_confirm_key(KEY_KP_ENTER) and Menu.is_confirm_key(KEY_SPACE))
	runner.check(not Menu.is_confirm_key(KEY_A))
	runner.check(Menu.counter_text(0, 2) == "< 1 / 2 >")
	runner.check(Menu.lap_direction_for_key(KEY_W) == 1 and Menu.lap_direction_for_key(KEY_UP) == 1)
	runner.check(Menu.lap_direction_for_key(KEY_S) == -1 and Menu.lap_direction_for_key(KEY_DOWN) == -1)
	runner.check(Menu.lap_direction_for_key(KEY_A) == 0 and Menu.lap_direction_for_key(KEY_ENTER) == 0)
	runner.check(Menu.laps_text(5).contains("5"))

func test_lap_options() -> void:
	var L := TrackLibrary
	runner.check(L.step_laps(3, 1) == 5 and L.step_laps(3, -1) == 2)
	runner.check(L.step_laps(7, 1) == 1, "wraps up")
	runner.check(L.step_laps(1, -1) == 7, "wraps down")
	runner.check(L.step_laps(99, 1) == 5, "unknown value starts from default")
	for n in L.LAP_OPTIONS:
		runner.check(n >= 1)
	var seen := 3
	for i in L.LAP_OPTIONS.size():
		seen = L.step_laps(seen, 1)
	runner.check(seen == 3, "full cycle returns to start")
	# the menu applies the chosen count to the race
	var m = Menu.new()
	m.laps = 3
	m.laps_label = Label.new()
	m.difficulty_label = Label.new()
	m.engine_label = Label.new()
	m.weight_label = Label.new()
	m.mode_label = Label.new()
	m.name_label = Label.new()
	m.blurb_label = Label.new()
	m.index_label = Label.new()
	m.bg = ColorRect.new()
	m.preview = load("res://scripts/minimap.gd").new()
	m.move_laps(1)
	runner.check(m.laps == 5 and m.laps_label.text == Menu.laps_text(5))
	m.move_difficulty(1)
	runner.check(m.difficulty == 2 and m.difficulty_label.text == Menu.difficulty_text(2))
	m.move_difficulty(1)
	runner.check(m.difficulty == 0 and m.difficulty_label.text.contains("Easy"), "wraps to Easy")
	for n in [m.laps_label, m.difficulty_label, m.engine_label, m.weight_label, m.mode_label, m.name_label, m.blurb_label, m.index_label, m.bg, m.preview, m]:
		n.free()
	var lt = load("res://scripts/lap_tracker.gd").new(200, 8, 2)
	runner.check(lt.total_laps == 2)

func test_selected_track_survives_as_static() -> void:
	var old := TrackLibrary.selected
	TrackLibrary.selected = 1
	runner.check(TrackLibrary.selected == 1)
	TrackLibrary.selected = old

func test_full_throttle_pursuit_bot_finishes_every_track() -> void:
	## A naive bot (always on the throttle, no braking) must be able to get round: no bend may be so tight it's undriveable.
	for n in TrackLibrary.count():
		var t := TrackLibrary.make_data(n)
		var lt := LapTracker.new(t.count, 8, 3)
		var k := KartPhysics.new()
		var start := t.count - 4
		var pos := t.points[start]
		var head := t.heading_at(start)
		var idx := start
		var time := 0.0
		var off := 0
		while not lt.is_finished and time < 400.0:
			idx = t.nearest_index(pos, idx)
			var target := t.points[(idx + 10) % t.count]
			var err := wrapf(atan2(-(target.x - pos.x), -(target.z - pos.z)) - head, -PI, PI)
			k.surface_scale = 1.0 if t.is_on_road(pos, idx) else 0.5
			if k.surface_scale < 1.0:
				off += 1
			head += k.step(DT, 1.0, 0.0, clampf(-err * 2.5, -1.0, 1.0), false)
			pos += Vector3(-sin(head), 0, -cos(head)) * k.speed * DT
			lt.update(DT, idx)
			time += DT
		runner.check(lt.is_finished, "track %d: bot did not finish (lap %d)" % [n, lt.lap])
		runner.check(off < 600, "track %d: bot off-road frames=%d" % [n, off])
		print("track %d bot: total %s offroad %d" % [n, Hud.format_time(lt.race_time), off])

func test_ai_difficulty_levels() -> void:
	var L := TrackLibrary
	runner.check(L.DIFFICULTIES.size() == 3)
	runner.check(L.difficulty_info(0).name == "Easy" and L.difficulty_info(1).name == "Medium" and L.difficulty_info(2).name == "Hard")
	runner.check(L.difficulty == 1, "Medium is the default")
	# harder levels are strictly faster; Easy is clearly slower than the player's 1.0 top speed
	runner.check(L.difficulty_info(0).speed < L.difficulty_info(1).speed and L.difficulty_info(1).speed < L.difficulty_info(2).speed)
	runner.check(L.difficulty_info(2).speed <= 1.0 and L.difficulty_info(0).speed <= 0.75)
	runner.check(L.step_difficulty(0, -1) == 2 and L.step_difficulty(2, 1) == 0 and L.step_difficulty(1, 1) == 2)
	runner.check(Menu.difficulty_direction_for_key(KEY_Q) == -1 and Menu.difficulty_direction_for_key(KEY_E) == 1)
	runner.check(Menu.difficulty_direction_for_key(KEY_A) == 0 and Menu.difficulty_direction_for_key(KEY_ENTER) == 0)
	runner.check(Menu.difficulty_text(0) == "Easy")
	# MK64 rubber-banding grows with difficulty; even Easy's full catch-up bonus keeps the AI below the player's top speed
	for i in 3:
		runner.check(L.difficulty_info(i).rubber_band > 0.0 and L.difficulty_info(i).rubber_band <= 0.25, "band %d" % i)
	runner.check(L.difficulty_info(0).rubber_band < L.difficulty_info(1).rubber_band and L.difficulty_info(1).rubber_band < L.difficulty_info(2).rubber_band)
	runner.check(L.difficulty_info(0).speed * (1.0 + L.difficulty_info(0).rubber_band) < 1.0)

func test_mk64_eight_racer_grid() -> void:
	## Mario Kart 64 fields 8 racers on a two-column grid; every slot must sit on the road
	## behind the line on every track, with no two karts sharing a slot.
	var Main := load("res://scripts/main.gd")
	runner.check(Main.RACER_COUNT == 8 and Main.RACER_NAMES.size() == 8, "8 racers")
	runner.check(Main.AI_SPECS.size() == 7 and Main.AI_START_BOOSTS.size() == 7, "7 AI karts")
	runner.check(Main.GRID_SLOTS.size() == 8 and Main.PLAYER_SLOT == 7, "8 grid slots, the player's is the last")
	var seen := {}
	for n in Main.RACER_NAMES:
		runner.check(not seen.has(n) and n.length() <= 8, "name %s" % n)
		seen[n] = true
	for n in TrackLibrary.count():
		var t := TrackLibrary.make_data(n)
		var back_idx := t.count - 10
		var slots: Array = []
		for slot in Main.GRID_SLOTS:
			var gi: int = back_idx + slot[0]
			runner.check(gi >= back_idx and gi < t.count, "track %d slot %d is behind the line" % [n, gi])
			slots.append(t.points[gi] + t.right_of(gi) * slot[1])
		for i in slots.size():
			runner.check(t.is_on_road(slots[i]), "track %d grid slot %d on road" % [n, i])
			for j in range(i + 1, slots.size()):
				runner.check(slots[i].distance_to(slots[j]) > 3.5, "track %d slots %d/%d overlap" % [n, i, j])
	for i in range(1, Main.GRID_SLOTS.size()):
		runner.check(Main.GRID_SLOTS[i][0] <= Main.GRID_SLOTS[i - 1][0], "pole first")
	for i in range(1, Main.AI_SPECS.size()):
		runner.check(Main.AI_SPECS[i][0] <= Main.AI_SPECS[i - 1][0], "front rows are the faster karts")

func test_mk64_engine_classes() -> void:
	## 50cc / 100cc / 150cc scale every kart's top speed and acceleration; 150cc is the full-speed default.
	## Extra is MK64's mirror mode: 150cc tuning on flipped courses.
	var L := TrackLibrary
	runner.check(L.ENGINE_CLASSES.size() == 4)
	runner.check(L.engine_info(0).name == "50cc" and L.engine_info(1).name == "100cc" and L.engine_info(2).name == "150cc" and L.engine_info(3).name == "Extra")
	runner.check(L.engine_class == 2, "150cc is the default")
	runner.check(L.engine_info(0).speed < L.engine_info(1).speed and L.engine_info(1).speed < L.engine_info(2).speed, "faster classes")
	runner.check(L.engine_info(0).accel < L.engine_info(1).accel and L.engine_info(1).accel < L.engine_info(2).accel, "quicker classes")
	runner.check(is_equal_approx(L.engine_info(2).speed, 1.0) and is_equal_approx(L.engine_info(2).accel, 1.0), "150cc is the base tuning")
	runner.check(is_equal_approx(L.engine_info(3).speed, 1.0) and is_equal_approx(L.engine_info(3).accel, 1.0), "Extra runs at 150cc speed")
	runner.check(L.is_mirrored(3) and not L.is_mirrored(0) and not L.is_mirrored(1) and not L.is_mirrored(2), "only Extra mirrors")
	runner.check(L.engine_info(0).speed >= 0.7, "50cc is still a race, not a crawl")
	runner.check(L.step_engine(0, -1) == 3 and L.step_engine(3, 1) == 0 and L.step_engine(1, 1) == 2 and L.step_engine(2, 1) == 3)
	runner.check(L.engine_info(-1).name == "Extra" and L.engine_info(4).name == "50cc", "info wraps")
	runner.check(Menu.engine_direction_for_key(KEY_Z) == -1 and Menu.engine_direction_for_key(KEY_C) == 1)
	runner.check(Menu.engine_direction_for_key(KEY_Q) == 0 and Menu.engine_direction_for_key(KEY_ENTER) == 0)
	runner.check(Menu.engine_text(0) == "50cc")
	runner.check(Menu.engine_text(3) == "Extra")
	# a 50cc kart tops out lower and gets there more slowly than a 150cc kart
	var slow := KartPhysics.new()
	slow.apply_engine_class(L.engine_info(0).speed, L.engine_info(0).accel)
	var fast := KartPhysics.new()
	fast.apply_engine_class(L.engine_info(2).speed, L.engine_info(2).accel)
	runner.check(is_equal_approx(slow.max_speed, fast.max_speed * L.engine_info(0).speed), "50cc top speed")
	runner.check(slow.acceleration < fast.acceleration and slow.boost_acceleration < fast.boost_acceleration, "50cc accel")
	runner.check(slow.reverse_max_speed < fast.reverse_max_speed, "50cc reverse")
	for i in 30:
		slow.step(DT, 1.0, 0.0, 0.0, false)
		fast.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(slow.speed < fast.speed, "50cc accelerates more slowly: %f vs %f" % [slow.speed, fast.speed])
	for i in 600:
		slow.step(DT, 1.0, 0.0, 0.0, false)
		fast.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(is_equal_approx(slow.speed, slow.max_speed) and is_equal_approx(fast.speed, fast.max_speed), "both reach their top speed")
	runner.check(slow.speed < fast.speed * 0.8, "50cc tops out well below 150cc")
	# the menu steps the class and the title text follows
	var m = Menu.new()
	m.laps_label = Label.new()
	m.difficulty_label = Label.new()
	m.engine_label = Label.new()
	m.weight_label = Label.new()
	m.mode_label = Label.new()
	m.name_label = Label.new()
	m.blurb_label = Label.new()
	m.index_label = Label.new()
	m.bg = ColorRect.new()
	m.preview = load("res://scripts/minimap.gd").new()
	m.engine_class = 2
	m.move_engine(-1)
	runner.check(m.engine_class == 1 and m.engine_label.text == Menu.engine_text(1))
	m.move_engine(1)
	m.move_engine(1)
	runner.check(m.engine_class == 3 and m.engine_label.text.contains("Extra"), "150cc steps up to Extra")
	m.move_engine(1)
	runner.check(m.engine_class == 0 and m.engine_label.text.contains("50cc"), "wraps to 50cc")
	for n in [m.laps_label, m.difficulty_label, m.engine_label, m.weight_label, m.mode_label, m.name_label, m.blurb_label, m.index_label, m.bg, m.preview, m]:
		n.free()

func test_mk64_extra_mirror_mode() -> void:
	## MK64 "Extra": every course flipped left-to-right. The mirrored geometry is the exact
	## reflection (x negated) of the original, pads / hazards swap sides, and it stays drivable.
	var L := TrackLibrary
	for n in L.count():
		var a := L.make_data(n)
		var b := L.make_data(n, true)
		runner.check(not a.mirrored and b.mirrored, "track %d mirrored flag" % n)
		runner.check(a.count == b.count and is_equal_approx(a.length, b.length), "track %d same length" % n)
		var max_err := 0.0
		for i in a.count:
			max_err = maxf(max_err, (Vector3(-a.points[i].x, 0, a.points[i].z) - b.points[i]).length())
		runner.check(max_err < 0.01, "track %d is the x-reflection (err %f)" % [n, max_err])
		runner.check(absf(b.heading_at(0)) < 0.3, "track %d mirrored start still heads along -Z" % n)
		var right_err := 0.0
		for i in a.count:
			# the mirrored right-hand vector is the reflection of the original's LEFT-hand vector
			var ar := a.right_of(i)
			right_err = maxf(right_err, (Vector3(ar.x, 0, -ar.z) - b.right_of(i)).length())
		runner.check(right_err < 0.01, "track %d right and left swap sides (err %f)" % [n, right_err])
		runner.check(b.min_separation() > b.width * 1.5, "track %d mirrored separation" % n)
		runner.check(a.pads.size() == b.pads.size() and a.hazard_positions.size() == b.hazard_positions.size(), "track %d same items" % n)
		for i in a.pads.size():
			var want := Vector3(-a.pads[i].center.x, 0, a.pads[i].center.z)
			runner.check(want.distance_to(b.pads[i].center) < 0.01, "track %d pad %d mirrored" % [n, i])
			runner.check(b.is_on_road(b.pads[i].center), "track %d mirrored pad on road" % n)
		for i in a.hazard_positions.size():
			var want := Vector3(-a.hazard_positions[i].x, 0, a.hazard_positions[i].z)
			runner.check(want.distance_to(b.hazard_positions[i]) < 0.01, "track %d hazard %d mirrored" % [n, i])
		for bx in b.item_box_positions:
			runner.check(b.is_on_road(bx), "track %d mirrored box on road" % n)
		# the mirrored course turns the other way round
		var turn_a := 0.0
		var turn_b := 0.0
		for i in a.count:
			turn_a += a.tangents[i].cross(a.tangents[(i + 1) % a.count]).y
			turn_b += b.tangents[i].cross(b.tangents[(i + 1) % b.count]).y
		runner.check(turn_a * turn_b < 0.0, "track %d loops the opposite way (%f vs %f)" % [n, turn_a, turn_b])
		# an AI kart still gets round the flipped course
		var k := KartPhysics.new()
		var drv := AiDriver.new(b, 0.0, 1.0)
		var lt := LapTracker.new(b.count, 8, 1)
		var start := b.count - 4
		var pos := b.points[start]
		var head := b.heading_at(start)
		var idx := -1
		var time := 0.0
		while not lt.is_finished and time < 200.0:
			idx = b.nearest_index(pos, idx)
			var out: Dictionary = drv.decide(DT, pos, head, k.speed)
			k.surface_scale = 1.0 if b.is_on_road(pos, idx) else 0.5
			head += k.step(DT, out.throttle, out.brake, out.steer, out.drift)
			pos += Vector3(-sin(head), 0, -cos(head)) * k.speed * DT
			lt.update(DT, idx)
			time += DT
		runner.check(lt.is_finished, "track %d mirrored: AI did not finish a lap (cp %d)" % [n, lt.next_cp])
	# the pure helpers
	var ctrl: Array[Vector2] = [Vector2(1, 2), Vector2(-3, 4)]
	var mc := TrackData.mirror_control(ctrl)
	runner.check(mc[0] == Vector2(-1, 2) and mc[1] == Vector2(3, 4))
	runner.check(TrackData.mirror_specs([[0.2, 3.0], [0.5, 0.0]]) == [[0.2, -3.0], [0.5, 0.0]])
	# the menu tags the blurb and flips the preview only in the Extra class, never in a time trial
	runner.check(Menu.blurb_text("Bends", false) == "Bends" and Menu.blurb_text("Bends", true).contains("MIRRORED"))
	var m = Menu.new()
	m.laps_label = Label.new()
	m.difficulty_label = Label.new()
	m.engine_label = Label.new()
	m.weight_label = Label.new()
	m.mode_label = Label.new()
	m.name_label = Label.new()
	m.blurb_label = Label.new()
	m.index_label = Label.new()
	m.bg = ColorRect.new()
	m.preview = load("res://scripts/minimap.gd").new()
	m.selected = 1
	m.engine_class = 2
	m.move_engine(1)
	var plain := L.make_data(1)
	var Minimap = load("res://scripts/minimap.gd")
	var pf: Dictionary = Minimap.fit(plain.points, Vector2(280, 160), 14.0)
	var plain_x: float = Minimap.to_map(plain.points[20], pf["scale"], pf["offset"]).x
	runner.check(m.engine_class == 3 and m.blurb_label.text.contains("MIRRORED"), "Extra tags the blurb")
	runner.check(m.preview.map_points.size() == plain.count + 1 and absf(m.preview.map_points[20].x + plain_x - 280.0) < 0.01, "preview is mirrored")
	m.mode = Menu.MODE_TT
	m._refresh()
	runner.check(not m.blurb_label.text.contains("MIRRORED") and absf(m.preview.map_points[20].x - plain_x) < 0.01, "time trials never mirror")
	for n in [m.laps_label, m.difficulty_label, m.engine_label, m.weight_label, m.mode_label, m.name_label, m.blurb_label, m.index_label, m.bg, m.preview, m]:
		n.free()
