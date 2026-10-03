extends RefCounted
## Mario Kart 64 Time Trials: ghost recording/replay, records, save/load, ghost kart, menu mode.

const TimeTrial := preload("res://scripts/time_trial.gd")
const GhostRecording := preload("res://scripts/ghost_recording.gd")
const GhostKart := preload("res://scripts/ghost_kart.gd")
const Menu := preload("res://scripts/menu.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const ItemManager := preload("res://scripts/item_manager.gd")
const Items := preload("res://scripts/items.gd")
const TEST_PATH := "user://test_time_trials.cfg"
var runner

## A straight-line run: one sample every `interval`, x = t * speed.
func _straight(samples: int, interval := GhostRecording.INTERVAL, speed := 10.0) -> GhostRecording:
	var g := GhostRecording.new(interval)
	for i in samples:
		g.positions.append(Vector3(i * interval * speed, 0, 0))
		g.headings.append(0.5)
	return g

func test_ghost_recording_samples_at_fixed_rate() -> void:
	var g := GhostRecording.new(1.0 / 30.0)
	runner.check(g.count() == 0 and g.duration() == 0.0 and g.pose_at(0.0).is_empty())
	# 60 Hz physics: the first call stores the start pose, then every second step adds a sample
	var t := 0.0
	for i in 121:
		g.add(1.0 / 60.0 if i > 0 else 0.0, Vector3(t, 0, 0), 0.0)
		if i > 0:
			t += 1.0 / 60.0
	runner.check(g.count() == 61, "61 samples over 2 s at 30 Hz: %d" % g.count())
	runner.check(is_equal_approx(g.duration(), 2.0), "duration %f" % g.duration())
	# a big step still adds exactly one sample per interval elapsed
	var before := g.count()
	g.add(0.1, Vector3(9, 0, 0), 0.0)
	runner.check(g.count() == before + 3, "0.1 s = 3 samples: %d" % (g.count() - before))
	g.finish(Vector3(10, 0, 0), 1.0)
	runner.check(g.count() == before + 4 and g.positions[g.count() - 1] == Vector3(10, 0, 0))

func test_ghost_pose_interpolates_and_clamps() -> void:
	var g := _straight(31)   # 1 s at 10 m/s
	var p0: Dictionary = g.pose_at(0.0)
	runner.check(p0.position == Vector3.ZERO and not p0.done and is_equal_approx(p0.heading, 0.5))
	var mid: Dictionary = g.pose_at(0.5)
	runner.check(mid.position.distance_to(Vector3(5, 0, 0)) < 1e-4, "halfway: %s" % mid.position)
	var between: Dictionary = g.pose_at(0.5 * g.interval)
	runner.check(between.position.distance_to(Vector3(0.5 * g.interval * 10.0, 0, 0)) < 1e-4, "interpolated between samples")
	var end: Dictionary = g.pose_at(1.0)
	runner.check(end.done and end.position.distance_to(Vector3(10, 0, 0)) < 1e-4, "last sample is 'done'")
	var late: Dictionary = g.pose_at(5.0)
	runner.check(late.done and late.position == end.position, "clamped past the end")
	runner.check(g.pose_at(-1.0).position == Vector3.ZERO, "clamped before the start")
	# headings wrap the short way around
	g.headings[1] = -PI + 0.1
	g.headings[0] = PI - 0.1
	var h: float = g.pose_at(0.5 * g.interval).heading
	runner.check(absf(absf(h) - PI) < 1e-4, "lerp_angle across +-PI: %f" % h)

func test_ghost_recording_round_trips_through_dict() -> void:
	var g := _straight(5, 0.05)
	var d := g.to_dict()
	var back = GhostRecording.from_dict(d)
	runner.check(is_equal_approx(back.interval, 0.05) and back.count() == 5)
	runner.check(back.positions == g.positions and back.headings == g.headings)
	runner.check(GhostRecording.from_dict({}).count() == 0)

func test_mk64_time_trial_rules() -> void:
	runner.check(TrackLibrary.engine_info(TimeTrial.ENGINE_CLASS).name == "100cc", "MK64 time trials run at 100cc")
	runner.check(TimeTrial.LAPS == 3 and TimeTrial.RECORD_COUNT == 5, "3 laps, five best times kept")
	runner.check(TimeTrial.record_rank([], 60.0) == 1, "first finish is the record")
	runner.check(TimeTrial.record_rank([50.0, 55.0], 52.0) == 2)
	runner.check(TimeTrial.record_rank([50.0, 55.0], 55.0) == 3, "a tie ranks behind the existing time")
	runner.check(TimeTrial.record_rank([50.0, 51.0, 52.0, 53.0, 54.0], 60.0) == 0, "slower than five records = none")
	runner.check(TimeTrial.record_rank([50.0, 51.0, 52.0, 53.0, 54.0], 53.5) == 5)

func test_submit_keeps_five_best_and_ghost_of_fastest() -> void:
	TimeTrial.reset()
	var fast := _straight(10)
	var r := TimeTrial.submit("Test Track", 70.0, 23.0, _straight(10))
	runner.check(r.rank == 1 and r.new_best and r.new_best_lap, str(r))
	runner.check(TimeTrial.best_time("Test Track") == 70.0 and TimeTrial.best_lap("Test Track") == 23.0)
	runner.check(TimeTrial.ghost_for("Test Track") != null, "first run becomes the ghost")
	var r2 := TimeTrial.submit("Test Track", 75.0, 24.0, _straight(12))
	runner.check(r2.rank == 2 and not r2.new_best and not r2.new_best_lap, str(r2))
	runner.check(TimeTrial.ghost_for("Test Track").count() == 10, "slower run leaves the ghost alone")
	var r3 := TimeTrial.submit("Test Track", 65.0, 22.5, fast)
	runner.check(r3.rank == 1 and r3.new_best and r3.new_best_lap, str(r3))
	runner.check(TimeTrial.ghost_for("Test Track") == fast, "faster run replaces the ghost")
	runner.check(TimeTrial.times_for("Test Track") == [65.0, 70.0, 75.0], str(TimeTrial.times_for("Test Track")))
	for t in [80.0, 81.0, 82.0]:
		TimeTrial.submit("Test Track", t, 30.0, _straight(3))
	runner.check(TimeTrial.times_for("Test Track") == [65.0, 70.0, 75.0, 80.0, 81.0], "only five kept: %s" % str(TimeTrial.times_for("Test Track")))
	runner.check(TimeTrial.submit("Test Track", 90.0, 30.0, _straight(3)).rank == 0, "too slow for the list")
	runner.check(TimeTrial.times_for("Test Track").size() == 5)
	# a best lap can be set by a run that is not a record
	var r4 := TimeTrial.submit("Test Track", 95.0, 20.0, _straight(3))
	runner.check(r4.rank == 0 and r4.new_best_lap and TimeTrial.best_lap("Test Track") == 20.0)
	runner.check(TimeTrial.best_time("Other") == -1.0 and TimeTrial.best_lap("Other") == -1.0 and TimeTrial.ghost_for("Other") == null)
	runner.check(TimeTrial.submit("Other", 50.0, 0.0, null).rank == 1 and TimeTrial.ghost_for("Other") == null, "no ghost without a recording")
	TimeTrial.reset()

func test_records_and_ghost_survive_save_and_load() -> void:
	TimeTrial.reset()
	TimeTrial.submit("Green Hills", 62.5, 20.1, _straight(40))
	TimeTrial.submit("Green Hills", 64.0, 20.5, _straight(5))
	TimeTrial.submit("Frosty Peaks", 90.0, 29.0, null)
	runner.check(TimeTrial.save(TEST_PATH) == OK)
	TimeTrial.reset()
	runner.check(not TimeTrial.loaded and TimeTrial.best_time("Green Hills") == -1.0)
	TimeTrial.load_records(TEST_PATH)
	runner.check(TimeTrial.loaded)
	runner.check(TimeTrial.times_for("Green Hills") == [62.5, 64.0], str(TimeTrial.times_for("Green Hills")))
	runner.check(is_equal_approx(TimeTrial.best_lap("Green Hills"), 20.1))
	var g = TimeTrial.ghost_for("Green Hills")
	runner.check(g != null and g.count() == 40, "ghost restored with its samples")
	runner.check(g != null and g.pose_at(0.5).position.distance_to(Vector3(5, 0, 0)) < 1e-3, "ghost replays after loading")
	runner.check(TimeTrial.times_for("Frosty Peaks") == [90.0] and TimeTrial.ghost_for("Frosty Peaks") == null)
	TimeTrial.reset()
	TimeTrial.load_records("user://does_not_exist.cfg")
	runner.check(TimeTrial.loaded and TimeTrial.records.is_empty(), "missing file = no records, still counts as loaded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	TimeTrial.reset()

func test_hud_and_results_text() -> void:
	TimeTrial.reset()
	runner.check(TimeTrial.hud_text("X") == "TIME TRIAL   no record yet", TimeTrial.hud_text("X"))
	var res := TimeTrial.submit("X", 62.5, 20.1, _straight(10))
	runner.check(TimeTrial.hud_text("X") == "TIME TRIAL   BEST 1:02.500   vs GHOST", TimeTrial.hud_text("X"))
	var txt := TimeTrial.results_text("X", 62.5, [21.0, 20.1, 21.4], res)
	var lines := txt.split("\n")
	runner.check(lines[0] == "TIME TRIAL - X", lines[0])
	runner.check("1:02.500" in lines[1] and "NEW RECORD!" in lines[1], lines[1])
	runner.check(lines[2].begins_with("LAP 1") and "0:21.000" in lines[2], lines[2])
	runner.check(lines[4].begins_with("LAP 3") and "0:21.400" in lines[4], lines[4])
	runner.check(lines[5].begins_with("BEST LAP") and "0:20.100" in lines[5] and "NEW!" in lines[5], lines[5])
	runner.check(lines[7] == "RECORDS" and lines[8].begins_with("> 1st  1:02.500"), lines[8])
	runner.check(lines[lines.size() - 1] == "Press ENTER to race your ghost", lines[lines.size() - 1])
	var res2 := TimeTrial.submit("X", 70.0, 22.0, _straight(10))
	var lines2 := TimeTrial.results_text("X", 70.0, [23.0, 22.0, 25.0], res2).split("\n")
	runner.check(not "NEW RECORD" in lines2[1] and not "NEW!" in lines2[5], lines2[1] + " | " + lines2[5])
	runner.check(lines2[8].begins_with("  1st") and lines2[9].begins_with("> 2nd  1:10.000"), lines2[9])
	TimeTrial.reset()
	var none := TimeTrial.results_text("Y", 70.0, [], {"rank": 0})
	runner.check(none.ends_with("Press ENTER to race again") and not "BEST LAP" in none)

func test_ghost_kart_replays_recording_untouchably() -> void:
	var g := _straight(31)   # 1 s, 10 m/s along +x
	var ghost := GhostKart.new()
	ghost.setup(g)
	runner.check(ghost.position == Vector3.ZERO and is_equal_approx(ghost.rotation.y, 0.5), "placed at the start pose")
	runner.check(ghost.get_class() == "Node3D" and ghost.get_node_or_null("CollisionShape3D") == null, "no body: passes through everything")
	runner.check(ghost.model.materials.size() > 0)
	var see_through := true
	for m in ghost.model.materials:
		if not is_equal_approx(m.albedo_color.a, GhostKart.ALPHA) or m.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
			see_through = false
	runner.check(see_through, "every material faded to the ghost alpha")
	for i in 30:
		ghost.update_ghost(1.0 / 60.0)
	runner.check(ghost.position.distance_to(Vector3(5, 0, 0)) < 1e-3 and not ghost.done, "halfway after 0.5 s: %s" % ghost.position)
	runner.check(ghost.model.wheel_spins[0].rotation.x != 0.0, "wheels roll with the replay speed")
	for i in 60:
		ghost.update_ghost(1.0 / 60.0)
	runner.check(ghost.done and ghost.position.distance_to(Vector3(10, 0, 0)) < 1e-3, "stops at the line")
	var empty := GhostKart.new()
	empty.setup(null)
	empty.update_ghost(0.1)
	runner.check(empty.position == Vector3.ZERO, "no recording = stays put")
	ghost.free()
	empty.free()

func test_time_trial_has_no_course_items_but_a_triple_mushroom() -> void:
	var data := TrackLibrary.make_data(0)
	var stub := Node3D.new()
	var m := ItemManager.new()
	Engine.get_main_loop().root.add_child(m)
	m.setup(data, [stub], 0, false)
	runner.check(m.boxes.is_empty() and m.projectiles.is_empty(), "no item boxes, no hazards")
	runner.check(m.holders.size() == 1)
	m.holder.receive(Items.Type.TRIPLE_MUSHROOM, Items.charges_for(Items.Type.TRIPLE_MUSHROOM))
	runner.check(m.holder.held == Items.Type.TRIPLE_MUSHROOM and m.holder.charges == 3, "MK64: a triple mushroom to start with")
	var full := ItemManager.new()
	Engine.get_main_loop().root.add_child(full)
	full.setup(data, [stub])
	runner.check(full.boxes.size() == data.item_box_positions.size() and full.projectiles.size() == data.hazard_positions.size(), "a race keeps them")
	Engine.get_main_loop().root.remove_child(m)
	Engine.get_main_loop().root.remove_child(full)
	m.free()
	full.free()
	stub.free()

func test_menu_time_trial_mode() -> void:
	runner.check(Menu.next_mode(Menu.MODE_SINGLE) == Menu.MODE_GP and Menu.next_mode(Menu.MODE_GP) == Menu.MODE_TT)
	runner.check(Menu.next_mode(Menu.MODE_TT) == Menu.MODE_SINGLE, "G cycles back to a single race")
	runner.check("TIME TRIAL" in Menu.mode_text(Menu.MODE_TT, 3) and "ghost" in Menu.mode_text(Menu.MODE_TT, 3))
	var m = Menu.new()
	for prop in ["laps_label", "difficulty_label", "engine_label", "mode_label", "name_label", "blurb_label", "index_label"]:
		m.set(prop, Label.new())
	m.bg = ColorRect.new()
	m.preview = load("res://scripts/minimap.gd").new()
	m.laps = 7
	m.engine_class = 2
	m.toggle_mode()
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_TT)
	runner.check(m.laps_label.text == "Laps: 3  (Time Trial)", m.laps_label.text)
	runner.check(m.engine_label.text == "Class: 100cc  (Time Trial)", m.engine_label.text)
	runner.check(m.difficulty_label.text == "AI: none  (Time Trial)", m.difficulty_label.text)
	m.toggle_mode()
	runner.check(m.laps_label.text == Menu.laps_text(7) and m.engine_label.text == Menu.engine_text(2), "race options come back")
	for n in [m.laps_label, m.difficulty_label, m.engine_label, m.mode_label, m.name_label, m.blurb_label, m.index_label, m.bg, m.preview, m]:
		n.free()
