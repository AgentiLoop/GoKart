extends Node3D
## Race scene: sky, ground, track, kart, chase camera, laps, boost pads and HUD.

const Kart := preload("res://scripts/kart.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const SpeedFx := preload("res://scripts/speed_fx.gd")
const KartEffects := preload("res://scripts/kart_effects.gd")
const Track := preload("res://scripts/track.gd")
const TrackData := preload("res://scripts/track_data.gd")
const LapTracker := preload("res://scripts/lap_tracker.gd")
const Hud := preload("res://scripts/hud.gd")
const ItemManager := preload("res://scripts/item_manager.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
const Slipstream := preload("res://scripts/slipstream.gd")
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
const Traffic := preload("res://scripts/traffic.gd")
const Highway := preload("res://scripts/highway.gd")
const Moles := preload("res://scripts/moles.gd")
const Molehills := preload("res://scripts/molehills.gd")
const Snowmen := preload("res://scripts/snowmen.gd")
const Snowfield := preload("res://scripts/snowfield.gd")
const Penguins := preload("res://scripts/penguins.gd")
const Rookery := preload("res://scripts/rookery.gd")
const CourseIntro := preload("res://scripts/course_intro.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")

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
var pause            # PauseMenu: Esc freezes the race under MK64's pause screen
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
## MK64 Toad's Turnpike traffic: the model (inactive on courses without traffic) and its node.
var traffic
var highway = null
## Minimap colour of a traffic vehicle.
const VEHICLE_COLOR := Color(0.4, 0.4, 0.45)
## MK64 Moo Moo Farm Monty Moles: the model (inactive on courses without holes) and its node.
var moles
var molehills = null
## Minimap colour of a mole hole.
const MOLE_COLOR := Color(0.45, 0.3, 0.15)
## MK64 Frappe Snowland snowmen: the model (inactive on courses without snowmen) and its node.
var snowmen
var snowfield = null
## Minimap colour of a snowman.
const SNOWMAN_COLOR := Color(0.92, 0.95, 1.0)
## MK64 Sherbet Land penguins: the model (inactive on courses without penguins) and its node.
var penguins
var rookery = null
## The hazard models that are active on this course, in the order the AI asks them for a clear lane.
var dodgers: Array = []
## Minimap colour of a penguin (its beak).
const PENGUIN_COLOR := Color(0.95, 0.6, 0.15)
## Time trial only: the run being recorded, the ghost of the best run (if any) and the filed result.
var recording = null
var ghost = null
var tt_result := {}
## MK64 course intro: seconds into the fly-over (-1 once the countdown is running); the countdown
## waits for it, Enter / the throttle skip it.
var intro_t := -1.0

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
	# MK64 Toad's Turnpike: traffic in two lanes, slow in 50cc and fast in 150cc, oncoming in Extra
	traffic = Traffic.new(data, engine.speed)
	if traffic.active():
		highway = Highway.new(traffic)
		add_child(highway)
	# MK64 Moo Moo Farm: Monty Moles hop in and out of holes in the road
	moles = Moles.new(data)
	if moles.active():
		molehills = Molehills.new(moles)
		add_child(molehills)
	# MK64 Frappe Snowland: snowmen stand about the road in rows
	snowmen = Snowmen.new(data)
	if snowmen.active():
		snowfield = Snowfield.new(snowmen)
		add_child(snowfield)
	# MK64 Sherbet Land: penguins slide back and forth across the icy stretches
	penguins = Penguins.new(data)
	if penguins.active():
		rookery = Rookery.new(penguins)
		add_child(rookery)
	for h in [traffic, moles, snowmen, penguins]:
		if h.active():
			dodgers.append(h)
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
	pause = PauseMenu.new()
	add_child(pause)
	hud.setup_minimap(data.points, data.rail)
	if time_trial:
		hud.show_cup(TimeTrial.hud_text(_track_name()))
	else:
		hud.show_cup(GrandPrix.race_label() if GrandPrix.active else "")
	if CourseIntro.pending:
		# from the menu (or on to the next cup race): the camera flies over the course under the
		# course's name card before the countdown; tools that load the scene directly skip it
		CourseIntro.pending = false
		intro_t = 0.0
		hud.show_intro(_track_name(), CourseIntro.caption(GrandPrix.race_label() if GrandPrix.active else "", time_trial, engine.name, laps))
		_fly_camera()
	audio = GameAudio.new()
	add_child(audio)
	audio.setup(kart, items)
	audio.start_music(_track_name())   # MK64: every course has its own tune, from GO
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
	# MK64 jump ramp: a whoosh off the lip, a thump on landing
	kart.jumped.connect(func(): audio.play("jump"))
	kart.landed.connect(func(): audio.play("thud", -4.0))

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
		if results_shown:
			# the results board is a screen of its own: Esc there goes back to the select screen
			GrandPrix.stop()
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
		else:
			# MK64: Start freezes the race under the pause screen (continue / retry / course change / quit)
			pause.open()
			get_viewport().set_input_as_handled()
		return
	if results_shown and event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER):
		CourseIntro.pending = true   # the next race (same course again or the next cup race) opens with its intro
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
	if intro_t >= 0.0 and event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER):
		_end_intro()   # MK64: Start skips the course intro

func _back() -> Vector3:
	return Vector3(sin(kart.heading), 0, cos(kart.heading))

func _physics_process(delta: float) -> void:
	var data: TrackData = track.data
	if intro_t >= 0.0:
		# the course intro: the countdown waits, the throttle skips the fly-over
		intro_t += delta
		if CourseIntro.finished(intro_t, Input.is_action_pressed("accelerate")):
			_end_intro()
	else:
		race_start.update(delta, Input.is_action_pressed("accelerate"))
	if railway != null:
		railway.update_train(delta)
	if highway != null and race_start.started:
		# the traffic sets off at GO, so nobody is run over on the grid
		highway.update_traffic(delta)
	if molehills != null:
		molehills.update_moles(delta)
	if snowfield != null:
		snowfield.update_snowmen(delta)
	if rookery != null:
		rookery.update_penguins(delta)
	var progresses: Array = []
	var finish_times: Array = []
	for k in karts:
		var kp: Vector3 = k.global_position
		k.track_index = data.nearest_index(kp, k.track_index)
		k.model.surface_scale = 1.0 if data.is_on_road(kp, k.track_index) else OFFROAD_SCALE
		# MK64 Sherbet Land ice: the tires bite less on an icy stretch, the kart slides on; CPU karts slow
		# for a bend they will take on ice before they reach it
		k.model.grip = KartPhysics.ICE_GRIP if data.on_ice(kp, k.track_index) else 1.0
		# MK64 jump ramp: the kart rides the ramp's slope and flies off its lip
		k.ramp_lift = data.ramp_height(kp, k.track_index)
		if k.driver != null:
			k.driver.grip = KartPhysics.ICE_GRIP if data.ice_ahead(k.track_index, AiDriver.ICE_LOOKAHEAD) else 1.0
		if race_start.started:
			k.tracker.update(delta, k.track_index)
		if data.pad_at(kp) != null:
			k.model.apply_boost(PAD_BOOST_TIME, 1)
		# fell in the water: Lakitu fishes the kart out and sets it down on the road
		if not k.is_rescued() and data.in_water(kp, k.track_index):
			k.start_rescue(data.rescue_point(k.track_index), data.heading_at(k.track_index))
			if k == kart:
				audio.play("splash")
		if k.driver != null and not dodgers.is_empty():
			# MK64: CPU karts steer round the traffic, the moles, the snowmen and the penguin runs ahead
			_dodge(k.driver, dodgers, k.track_index)
		if train.active():
			# MK64: CPU karts stop at a crossing while the train is there; anyone it meets is thrown into the air
			if k.driver != null:
				k.driver.wait = train.must_wait(k.track_index)
			var strike: Vector3 = train.hit_dir(kp)
			if strike != Vector3.ZERO and not k.is_rescued() and k.launch(Train.LAUNCH_SPEED, strike * Train.SHOVE) and k == kart:
				audio.play("crash")
		if traffic.active():
			# MK64 Toad's Turnpike: touch a vehicle and you are thrown into the air
			var bump: Vector3 = traffic.hit_dir(kp)
			if bump != Vector3.ZERO and not k.is_rescued() and k.launch(Traffic.LAUNCH_SPEED, bump * Traffic.SHOVE) and k == kart:
				audio.play("crash")
		if moles.active():
			# MK64 Moo Moo Farm: a mole that is out throws anyone who runs into it into the air, a Star
			# kart bowls the mole over instead
			var mi: int = moles.mole_at(kp)
			if mi >= 0 and not k.is_rescued():
				if k.model.is_star():
					moles.knock(mi)
					if k == kart:
						audio.play("pop")
				elif k.launch(Moles.LAUNCH_SPEED, moles.shove_dir(mi, kp) * Moles.SHOVE) and k == kart:
					audio.play("crash")
		if snowmen.active():
			# MK64 Frappe Snowland: run into a snowman and you are thrown into the air and it bursts into
			# snow, a Star kart bursts it and drives on
			var si: int = snowmen.snowman_at(kp)
			if si >= 0 and not k.is_rescued():
				if k.model.is_star():
					snowmen.smash(si)
					if k == kart:
						audio.play("pop")
				elif k.launch(Snowmen.LAUNCH_SPEED, snowmen.shove_dir(si, kp) * Snowmen.SHOVE):
					snowmen.smash(si)
					if k == kart:
						audio.play("crash")
		if penguins.active():
			# MK64 Sherbet Land: run into a penguin and you are pushed away and spin out, a Star kart
			# bowls it over and drives on
			var pg: int = penguins.penguin_at(kp)
			if pg >= 0 and not k.is_rescued():
				if k.model.is_star():
					penguins.knock(pg)
					if k == kart:
						audio.play("pop")
				elif k.launch(Penguins.LAUNCH_SPEED, penguins.shove_dir(pg, kp) * Penguins.SHOVE) and k == kart:
					audio.play("crash")
		var frac: float = (kp - data.points[k.track_index]).dot(data.tangents[k.track_index]) / data.spacing
		progresses.append(RaceRanking.progress(k.tracker.lap, k.track_index, data.count, frac))
		finish_times.append(k.tracker.race_time if k.tracker.is_finished else -1.0)
	kart_index = kart.track_index
	if moles.active():
		# MK64: a green or red shell knocks a mole that is out away (and is spent on it)
		for p in items.projectiles.duplicate():
			if p.alive and Items.is_blockable_shell(p.kind) and moles.knock_at(p.position, p.radius + Moles.HIT_RADIUS) >= 0:
				p.alive = false
				items._remove_projectile(p)
				audio.play("pop", -6.0)
	if snowmen.active():
		# MK64: a green or red shell smashes a snowman (and is spent on it)
		for p in items.projectiles.duplicate():
			if p.alive and Items.is_blockable_shell(p.kind) and snowmen.smash_at(p.position, p.radius + Snowmen.HIT_RADIUS) >= 0:
				p.alive = false
				items._remove_projectile(p)
				audio.play("pop", -6.0)
	if penguins.active():
		# MK64: a green or red shell bowls a penguin over (and is spent on it)
		for p in items.projectiles.duplicate():
			if p.alive and Items.is_blockable_shell(p.kind) and penguins.knock_at(p.position, p.radius + Penguins.HIT_RADIUS) >= 0:
				p.alive = false
				items._remove_projectile(p)
				audio.play("pop", -6.0)
	# MK64 rubber-banding: AI karts behind the player get a top-speed bonus, karts far ahead ease off
	var band: float = TrackLibrary.difficulty_info(TrackLibrary.difficulty).rubber_band
	for i in range(1, karts.size()):
		var gap: float = (progresses[0] - progresses[i]) * data.spacing
		karts[i].model.max_speed = ai_base_speed[i - 1] * AiDriver.rubber_band(gap, band)
	# MK64 slipstream: a kart that trails close behind another for a couple of seconds gets a brief burst of speed
	var wake_pos: Array = []
	var wake_fwd: Array = []
	var wake_spd: Array = []
	for k in karts:
		wake_pos.append(k.global_position)
		wake_fwd.append(Vector3(-sin(k.heading), 0, -cos(k.heading)))
		wake_spd.append(k.model.speed)
	for i in karts.size():
		var k = karts[i]
		var lead: int = Slipstream.leader(i, wake_pos, wake_fwd, wake_spd) if race_start.started and not k.is_rescued() else -1
		k.model.update_draft(delta, lead >= 0)
	var banner := "START" if tracker.lap == 0 else ("FINISH" if tracker.lap >= tracker.total_laps else "CONTINUE")
	if banner != track.banner_text:
		track.set_banner(banner)
	audio.update_audio(delta, race_start)
	audio.update_crossing(delta, train.active() and train.bell_near(kart.track_index))
	# MK64: the "Final Lap!" jingle and faster music on the last lap (of a race with more than one), the
	# Star theme while invincible, the music stops for the finish fanfare
	audio.update_music(delta, race_start.started, tracker.lap >= tracker.total_laps and tracker.total_laps > 1, tracker.is_finished, kart.model.is_star())
	lakitu.update_lakitu(delta, race_start.remaining, race_start.started, race_start.since_go)
	_update_time_trial(delta)
	var place := RaceRanking.rank_of(0, progresses, finish_times)
	if tracker.is_finished:
		if not finish_played:
			finish_played = true
			audio.play_finish(place)
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
	hud.update_hud(tracker, kart.model.speed, kart.model.is_boosting(), kart.model.drift_level, items.holder.display_item(items.time), Hud.place_text(place, karts.size()), kart.model.is_star(), kart.model.is_shrunk(), items.holder.charges, items.holder.golden_time, kart.model.is_ghost())
	hud.show_countdown(race_start.label() if intro_t < 0.0 else "")
	var marker_pos: Array = []
	var marker_col: Array = []
	for k in karts:
		marker_pos.append(k.global_position)
		marker_col.append(k.body_color)
	if ghost != null:
		marker_pos.append(ghost.global_position)
		marker_col.append(GhostKart.COLOR)
	for i in traffic.vehicles.size():
		marker_pos.append(traffic.vehicle_pose(i).pos)
		marker_col.append(VEHICLE_COLOR)
	for m in moles.moles:
		marker_pos.append(m.pos)
		marker_col.append(MOLE_COLOR)
	for sm in snowmen.snowmen:
		marker_pos.append(sm.pos)
		marker_col.append(SNOWMAN_COLOR)
	for i in penguins.penguins.size():
		marker_pos.append(penguins.position(i))
		marker_col.append(PENGUIN_COLOR)
	hud.update_minimap(marker_pos, marker_col)

## Points an AI driver at the lane the course's `hazards` (the traffic, the moles, the snowmen, the
## penguins — the active ones, in that order) say is clear ahead of it: its own lane when free,
## otherwise a dodge lane it keeps until the way is clear. Each hazard is asked in turn about the
## lane the one before settled on, so the last one (the penguins, whose runs sit just before the
## snowman gate on Frosty Peaks) has the final say while its hazard is ahead.
func _dodge(driver, hazards: Array, idx: int) -> void:
	var current: float = driver.dodge_lane if driver.dodging else driver.lane_offset
	var lane: float = driver.lane_offset
	for h in hazards:
		lane = h.clear_lane(idx, lane, current)
	driver.dodging = lane != driver.lane_offset
	driver.dodge_lane = lane

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

## The intro's fly-over camera for the current moment of the intro.
func _fly_camera() -> void:
	var pose := CourseIntro.cam_pose(maxf(intro_t, 0.0), track.data.points, track.data.spacing)
	cam.look_at_from_position(pose.pos, pose.look)

## The intro is over (or skipped): the HUD comes back, the camera cuts to its spot behind the
## player and the countdown starts from the next physics frame.
func _end_intro() -> void:
	if intro_t < 0.0:
		return
	intro_t = -1.0
	hud.end_intro()
	cam.look_at_from_position(kart.global_position + _back() * 6.0 + Vector3(0, 3.0, 0), kart.global_position + Vector3(0, 1.0, 0))

func _process(delta: float) -> void:
	if intro_t >= 0.0:
		_fly_camera()
		var card := CourseIntro.card_pose(intro_t)
		hud.intro_pose(card.alpha, card.y)
		return
	var target := kart.global_position + _back() * 6.0 + Vector3(0, 3.0, 0)
	cam.global_position = cam.global_position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	cam.look_at(kart.global_position + Vector3(0, 1.0, 0))
	var ratio: float = absf(kart.model.speed) / kart.model.max_speed
	speed_fx.update_fx(delta, ratio, kart.model.is_boosting())
	cam.fov = lerpf(cam.fov, 70.0 + 10.0 * speed_fx.speed_amount + 12.0 * speed_fx.boost_amount, clampf(5.0 * delta, 0.0, 1.0))
