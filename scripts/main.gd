extends Node3D
## Race scene: sky, ground, track, kart, chase camera, laps, boost pads and HUD.

const Kart := preload("res://scripts/kart.gd")
const SpeedFx := preload("res://scripts/speed_fx.gd")
const KartEffects := preload("res://scripts/kart_effects.gd")
const Track := preload("res://scripts/track.gd")
const TrackData := preload("res://scripts/track_data.gd")
const LapTracker := preload("res://scripts/lap_tracker.gd")
const Hud := preload("res://scripts/hud.gd")
const ItemManager := preload("res://scripts/item_manager.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
const RaceRanking := preload("res://scripts/race_ranking.gd")
const RaceStart := preload("res://scripts/race_start.gd")
const RaceResults := preload("res://scripts/race_results.gd")
const GameAudio := preload("res://scripts/game_audio.gd")
const AiEngineAudio := preload("res://scripts/ai_engine_audio.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const GrandPrix := preload("res://scripts/grand_prix.gd")
const TimeTrial := preload("res://scripts/time_trial.gd")
const GhostRecording := preload("res://scripts/ghost_recording.gd")
const GhostKart := preload("res://scripts/ghost_kart.gd")
const Items := preload("res://scripts/items.gd")
const KartWeight := preload("res://scripts/kart_weight.gd")
const Lakitu := preload("res://scripts/lakitu.gd")
const Train := preload("res://scripts/train.gd")
const Railway := preload("res://scripts/railway.gd")

## Seconds after the player crosses the line before the results panel appears.
const RESULTS_DELAY := 2.0
## Mario Kart 64 fields eight racers; the player is racer 0, the rest follow AI_SPECS order.
const RACER_NAMES := ["YOU", "BLUE", "GREEN", "PURPLE", "YELLOW", "ORANGE", "PINK", "TEAL"]
const RACER_COUNT := 8

const OFFROAD_SCALE := 0.5
const PAD_BOOST_TIME := 1.2
## Rocket-start boost durations the AI karts get at GO (by AI_SPECS order; 0 = a bad start).
const AI_START_BOOSTS := [0.9, 0.5, 0.0, 0.7, 0.0, 0.3, 0.6]
## Half the lane spacing of the two-column MK64 grid.
const GRID_LANE := 2.4
## The eight grid slots, pole first: [samples ahead of the back row, lane offset]. Two columns,
## four rows 3 samples (9 m) apart. On the first race AI kart i takes slot i and the player the
## last slot (8th, as in MK64); later cup races line everyone up where they finished.
const GRID_SLOTS := [
	[9, -GRID_LANE], [9, GRID_LANE],
	[6, -GRID_LANE], [6, GRID_LANE],
	[3, -GRID_LANE], [3, GRID_LANE],
	[0, -GRID_LANE], [0, GRID_LANE],
]
const PLAYER_SLOT := 7
## AI karts: [speed scale, body colour, weight class], front row first.
## The field mixes MK64 weight classes: three light, two medium and two heavy karts.
const AI_SPECS := [
	[0.98, Color(0.15, 0.3, 0.95), KartWeight.HEAVY],    # BLUE   front row
	[0.96, Color(0.15, 0.75, 0.25), KartWeight.LIGHT],    # GREEN
	[0.95, Color(0.65, 0.2, 0.85), KartWeight.MEDIUM],   # PURPLE
	[0.94, Color(0.95, 0.85, 0.15), KartWeight.LIGHT],    # YELLOW
	[0.92, Color(0.95, 0.5, 0.1), KartWeight.HEAVY],     # ORANGE
	[0.90, Color(0.95, 0.4, 0.7), KartWeight.LIGHT],      # PINK
	[0.88, Color(0.1, 0.75, 0.75), KartWeight.MEDIUM],    # TEAL   back row, beside the player
]

var kart: CharacterBody3D
var cam: Camera3D
var speed_fx
var track
var tracker
var hud
var items
var kart_index := 0
var karts: Array = []   # karts[0] is the player
var ai_base_speed: Array = []   # top speed of each AI kart before rubber-banding (karts[1..] order)
var race_start := RaceStart.new()
var finish_timer := 0.0
var results_shown := false
var audio
var finish_played := false
var lakitu
## MK64 Kalimari Desert railway: the train model (inactive on courses without a rail) and its node.
var train
var railway = null
## Time trial only: the run being recorded, the ghost of the best run (if any) and the filed result.
var recording = null
var ghost = null
var tt_result := {}

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	var theme := TrackLibrary.info(TrackLibrary.selected)
	sky_mat.sky_top_color = theme.sky_top
	sky_mat.sky_horizon_color = theme.sky_horizon
	sky_mat.ground_horizon_color = theme.sky_horizon
	e.sky.sky_material = sky_mat
	e.glow_enabled = true
	e.glow_hdr_threshold = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := StaticBody3D.new()
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	gshape.size = Vector3(800, 1, 800)
	gcol.shape = gshape
	ground.add_child(gcol)
	var gmesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(800, 1, 800)
	gmesh.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = theme.ground
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	ground.position = Vector3(60, -0.5, 20)
	add_child(ground)

	# MK64 time trials: solo, 3 laps, 100cc, a triple mushroom and no items on the course
	var time_trial: bool = TimeTrial.active
	var laps: int = TimeTrial.LAPS if time_trial else TrackLibrary.laps
	var engine_index: int = TimeTrial.ENGINE_CLASS if time_trial else TrackLibrary.engine_class
	# MK64 Extra class: the course is raced flipped left-to-right
	track = Track.new(TrackLibrary.make_data(TrackLibrary.selected, TrackLibrary.is_mirrored(engine_index)))
	add_child(track)
	var data: TrackData = track.data
	tracker = LapTracker.new(data.count, 8, laps)
	# MK64 Kalimari Desert: two steam trains circle the railway and cross the road at level crossings
	train = Train.new(data)
	if train.active():
		railway = Railway.new(data, train)
		add_child(railway)

	var engine: Dictionary = TrackLibrary.engine_info(engine_index)
	kart = Kart.new()
	kart.model.apply_engine_class(engine.speed, engine.accel)
	# MK64 weight class picked on the menu: light / medium / heavy
	kart.apply_weight_class(KartWeight.selected)
	# the player starts in the right slot of the back row, just behind the line, facing along the
	# track — or, from the second cup race on, where it finished the last race (MK64 grid rule);
	# alone on the front row's centre in a time trial
	var back_idx := data.count - 10
	var player_slot: Array = GRID_SLOTS[GrandPrix.grid_slot_for(0, PLAYER_SLOT)]
	var start_idx := data.count - 1 if time_trial else back_idx + int(player_slot[0])
	var start_pos: Vector3 = data.points[start_idx] + data.right_of(start_idx) * (0.0 if time_trial else player_slot[1]) + Vector3(0, 0.1, 0)
	kart.position = start_pos
	kart.heading = data.heading_at(start_idx)
	kart.tracker = tracker
	kart.track_index = start_idx
	add_child(kart)
	kart_index = start_idx
	karts.append(kart)
	for spec in (AI_SPECS if not time_trial else []):
		var ai := Kart.new()
		var slot: Array = GRID_SLOTS[GrandPrix.grid_slot_for(karts.size(), karts.size() - 1)]
		var gi: int = back_idx + int(slot[0])
		var lane: float = slot[1]
		ai.body_color = spec[1]
		ai.position = data.points[gi] + data.right_of(gi) * lane + Vector3(0, 0.1, 0)
		ai.heading = data.heading_at(gi)
		ai.driver = AiDriver.new(data, lane, 1.0 + 0.7 * karts.size())
		ai.tracker = LapTracker.new(data.count, 8, laps)
		ai.track_index = gi
		ai.kart_id = karts.size()
		add_child(ai)
		ai.model.apply_engine_class(engine.speed, engine.accel)
		ai.apply_weight_class(spec[2])
		ai.model.max_speed *= spec[0] * TrackLibrary.difficulty_info(TrackLibrary.difficulty).speed
		ai_base_speed.append(ai.model.max_speed)
		var engine_sfx := AiEngineAudio.new()
		engine_sfx.kart = ai
		ai.add_child(engine_sfx)
		karts.append(ai)

	items = ItemManager.new()
	add_child(items)
	items.setup(data, karts, 0, not time_trial)
	if time_trial:
		TimeTrial.ensure_loaded()
		items.holder.receive(Items.Type.TRIPLE_MUSHROOM, Items.charges_for(Items.Type.TRIPLE_MUSHROOM))
		recording = GhostRecording.new()
		var best = TimeTrial.ghost_for(_track_name())
		if best != null:
			ghost = GhostKart.new()
			ghost.setup(best)
			add_child(ghost)

	cam = Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	add_child(cam)
	cam.global_position = start_pos + _back() * 6.0 + Vector3(0, 3.0, 0)
	speed_fx = SpeedFx.new()
	add_child(speed_fx)
	hud = Hud.new()
	add_child(hud)
	hud.setup_minimap(data.points, data.rail)
	if time_trial:
		hud.show_cup(TimeTrial.hud_text(_track_name()))
	else:
		hud.show_cup(GrandPrix.race_label() if GrandPrix.active else "")
	audio = GameAudio.new()
	add_child(audio)
	audio.setup(kart, items)
	# MK64 Lakitu: start signal, lap signs, REVERSE sign, checkered flag and water rescues
	lakitu = Lakitu.new()
	add_child(lakitu)
	lakitu.setup(kart, data)
	tracker.lap_completed.connect(func(lap, _t): lakitu.on_lap(lap + 1, tracker.total_laps))
	tracker.finished.connect(lakitu.on_finish)
	for k in karts:
		k.frozen = true
	race_start.go.connect(_on_go)
	kart.model.boost_started.connect(_on_player_boost)
	items.lightning_struck.connect(_on_lightning)

func _on_player_boost(level: int) -> void:
	if kart.model.boost_from_drift:
		speed_fx.trigger_flash(KartEffects.spark_color(level))

func _on_lightning(_user: int, _victims: Array) -> void:
	speed_fx.trigger_flash(Color(2.0, 2.0, 1.6))

func _on_go() -> void:
	for i in karts.size():
		karts[i].frozen = false
	var b := race_start.start_boost()
	if race_start.false_start():
		kart.model.stall(RaceStart.STALL_TIME)
	elif b > 0.0:
		kart.model.apply_boost(b, 1)
	for i in range(1, karts.size()):
		var ab: float = AI_START_BOOSTS[(i - 1) % AI_START_BOOSTS.size()] * TrackLibrary.difficulty_info(TrackLibrary.difficulty).start_boost
		if ab > 0.0:
			karts[i].model.apply_boost(ab, 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		GrandPrix.stop()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if results_shown and event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER):
		if GrandPrix.active:
			if GrandPrix.retry:
				# MK64: ranked out (5th or worse) — the same race is run again, nothing scored
				GrandPrix.begin_retry()
				get_tree().reload_current_scene()
			elif GrandPrix.advance():
				# next cup race: the menu's track choice is replaced by the cup order
				TrackLibrary.selected = GrandPrix.current_track()
				get_tree().reload_current_scene()
			else:
				GrandPrix.stop()
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
			return
		get_tree().reload_current_scene()

func _back() -> Vector3:
	return Vector3(sin(kart.heading), 0, cos(kart.heading))

func _physics_process(delta: float) -> void:
	var data: TrackData = track.data
	race_start.update(delta, Input.is_action_pressed("accelerate"))
	if railway != null:
		railway.update_train(delta)
	var progresses: Array = []
	var finish_times: Array = []
	for k in karts:
		var kp: Vector3 = k.global_position
		k.track_index = data.nearest_index(kp, k.track_index)
		k.model.surface_scale = 1.0 if data.is_on_road(kp, k.track_index) else OFFROAD_SCALE
		if race_start.started:
			k.tracker.update(delta, k.track_index)
		if data.pad_at(kp) != null:
			k.model.apply_boost(PAD_BOOST_TIME, 1)
		# fell in the water: Lakitu fishes the kart out and sets it down on the road
		if not k.is_rescued() and data.in_water(kp, k.track_index):
			k.start_rescue(data.rescue_point(k.track_index), data.heading_at(k.track_index))
			if k == kart:
				audio.play("splash")
		if train.active():
			# MK64: CPU karts stop at a crossing while the train is there; anyone it meets is thrown into the air
			if k.driver != null:
				k.driver.wait = train.must_wait(k.track_index)
			var strike: Vector3 = train.hit_dir(kp)
			if strike != Vector3.ZERO and not k.is_rescued() and k.launch(Train.LAUNCH_SPEED, strike * Train.SHOVE) and k == kart:
				audio.play("crash")
		var frac: float = (kp - data.points[k.track_index]).dot(data.tangents[k.track_index]) / data.spacing
		progresses.append(RaceRanking.progress(k.tracker.lap, k.track_index, data.count, frac))
		finish_times.append(k.tracker.race_time if k.tracker.is_finished else -1.0)
	kart_index = kart.track_index
	# MK64 rubber-banding: AI karts behind the player get a top-speed bonus, karts far ahead ease off
	var band: float = TrackLibrary.difficulty_info(TrackLibrary.difficulty).rubber_band
	for i in range(1, karts.size()):
		var gap: float = (progresses[0] - progresses[i]) * data.spacing
		karts[i].model.max_speed = ai_base_speed[i - 1] * AiDriver.rubber_band(gap, band)
	var banner := "START" if tracker.lap == 0 else ("FINISH" if tracker.lap >= tracker.total_laps else "CONTINUE")
	if banner != track.banner_text:
		track.set_banner(banner)
	audio.update_audio(delta, race_start)
	audio.update_crossing(delta, train.active() and train.bell_near(kart.track_index))
	lakitu.update_lakitu(delta, race_start.remaining, race_start.started, race_start.since_go)
	_update_time_trial(delta)
	if tracker.is_finished:
		if not finish_played:
			finish_played = true
			audio.play_finish()
			if recording != null:
				_finish_time_trial()
		if kart.driver == null:
			# the finished player is taken over by the autopilot so the kart keeps rolling
			kart.driver = AiDriver.new(data, 0.0, 999.0)
		finish_timer += delta
		if not results_shown and finish_timer >= RESULTS_DELAY:
			results_shown = true
			var names: Array = []
			for i in karts.size():
				names.append(RACER_NAMES[i % RACER_NAMES.size()])
			var rows := RaceResults.rows(names, progresses, finish_times)
			if recording != null:
				hud.show_results(TimeTrial.results_text(_track_name(), tracker.race_time, tracker.lap_times, tt_result))
			elif GrandPrix.active:
				GrandPrix.add_race(rows, 0)
				hud.show_results(RaceResults.table_text(rows, 0, GrandPrix.standings_text(names, 0)))
			else:
				hud.show_results(RaceResults.table_text(rows, 0))
	var place := RaceRanking.rank_of(0, progresses, finish_times)
	hud.update_hud(tracker, kart.model.speed, kart.model.is_boosting(), kart.model.drift_level, items.holder.display_item(items.time), Hud.place_text(place, karts.size()), kart.model.is_star(), kart.model.is_shrunk(), items.holder.charges, items.holder.golden_time, kart.model.is_ghost())
	hud.show_countdown(race_start.label())
	var marker_pos: Array = []
	var marker_col: Array = []
	for k in karts:
		marker_pos.append(k.global_position)
		marker_col.append(k.body_color)
	if ghost != null:
		marker_pos.append(ghost.global_position)
		marker_col.append(GhostKart.COLOR)
	hud.update_minimap(marker_pos, marker_col)

## Time trial: record the player's pose from GO to the line and replay the ghost alongside.
func _update_time_trial(delta: float) -> void:
	if recording == null or not race_start.started:
		return
	if not tracker.is_finished:
		recording.add(delta, kart.global_position, kart.heading)
	if ghost != null:
		ghost.update_ghost(delta)

## The player finished a time trial: file the time and the ghost, remember the outcome for the panel.
func _finish_time_trial() -> void:
	recording.finish(kart.global_position, kart.heading)
	tt_result = TimeTrial.submit(_track_name(), tracker.race_time, tracker.best_lap(), recording)
	TimeTrial.save()
	hud.show_cup(TimeTrial.hud_text(_track_name()))

func _track_name() -> String:
	return TrackLibrary.info(TrackLibrary.selected).name

func _process(delta: float) -> void:
	var target := kart.global_position + _back() * 6.0 + Vector3(0, 3.0, 0)
	cam.global_position = cam.global_position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	cam.look_at(kart.global_position + Vector3(0, 1.0, 0))
	var ratio: float = absf(kart.model.speed) / kart.model.max_speed
	speed_fx.update_fx(delta, ratio, kart.model.is_boosting())
	cam.fov = lerpf(cam.fov, 70.0 + 10.0 * speed_fx.speed_amount + 12.0 * speed_fx.boost_amount, clampf(5.0 * delta, 0.0, 1.0))
