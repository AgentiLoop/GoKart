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

## Seconds after the player crosses the line before the results panel appears.
const RESULTS_DELAY := 2.0
const RACER_NAMES := ["YOU", "BLUE", "GREEN", "PURPLE"]

const OFFROAD_SCALE := 0.5
const PAD_BOOST_TIME := 1.2
## Rocket-start boost durations the AI karts get at GO (by AI_SPECS order; 0 = a bad start).
const AI_START_BOOSTS := [0.9, 0.5, 0.0]
## AI grid: [samples before the player's slot (negative = ahead), lane offset, speed scale, body colour]
const AI_SPECS := [
	[-6, -3.0, 0.97, Color(0.15, 0.3, 0.95)],
	[-6, 3.0, 0.94, Color(0.15, 0.75, 0.25)],
	[-3, 0.0, 0.91, Color(0.65, 0.2, 0.85)],
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
var race_start := RaceStart.new()
var finish_timer := 0.0
var results_shown := false
var audio
var finish_played := false

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

	track = Track.new(TrackLibrary.make_data(TrackLibrary.selected))
	add_child(track)
	var data: TrackData = track.data
	tracker = LapTracker.new(data.count, 8, TrackLibrary.laps)

	kart = Kart.new()
	# the player starts at the back of the grid, just behind the line, facing along the track
	var start_idx := data.count - 10
	var start_pos: Vector3 = data.points[start_idx] + Vector3(0, 0.1, 0)
	kart.position = start_pos
	kart.heading = data.heading_at(start_idx)
	kart.tracker = tracker
	kart.track_index = start_idx
	add_child(kart)
	kart_index = start_idx
	karts.append(kart)
	for spec in AI_SPECS:
		var ai := Kart.new()
		var gi: int = start_idx - spec[0]
		ai.body_color = spec[3]
		ai.position = data.points[gi] + data.right_of(gi) * spec[1] + Vector3(0, 0.1, 0)
		ai.heading = data.heading_at(gi)
		ai.driver = AiDriver.new(data, spec[1], 1.0 + 0.7 * karts.size())
		ai.tracker = LapTracker.new(data.count, 8, TrackLibrary.laps)
		ai.track_index = gi
		ai.kart_id = karts.size()
		add_child(ai)
		ai.model.max_speed *= spec[2] * TrackLibrary.difficulty_info(TrackLibrary.difficulty).speed
		var engine_sfx := AiEngineAudio.new()
		engine_sfx.kart = ai
		ai.add_child(engine_sfx)
		karts.append(ai)

	items = ItemManager.new()
	add_child(items)
	items.setup(data, karts)

	cam = Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	add_child(cam)
	cam.global_position = start_pos + _back() * 6.0 + Vector3(0, 3.0, 0)
	speed_fx = SpeedFx.new()
	add_child(speed_fx)
	hud = Hud.new()
	add_child(hud)
	hud.setup_minimap(data.points)
	audio = GameAudio.new()
	add_child(audio)
	audio.setup(kart, items)
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
	if b > 0.0:
		kart.model.apply_boost(b, 1)
	for i in range(1, karts.size()):
		var ab: float = AI_START_BOOSTS[(i - 1) % AI_START_BOOSTS.size()] * TrackLibrary.difficulty_info(TrackLibrary.difficulty).start_boost
		if ab > 0.0:
			karts[i].model.apply_boost(ab, 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if results_shown and event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER):
		get_tree().reload_current_scene()

func _back() -> Vector3:
	return Vector3(sin(kart.heading), 0, cos(kart.heading))

func _physics_process(delta: float) -> void:
	var data: TrackData = track.data
	race_start.update(delta, Input.is_action_pressed("accelerate"))
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
		var frac: float = (kp - data.points[k.track_index]).dot(data.tangents[k.track_index]) / data.spacing
		progresses.append(RaceRanking.progress(k.tracker.lap, k.track_index, data.count, frac))
		finish_times.append(k.tracker.race_time if k.tracker.is_finished else -1.0)
	kart_index = kart.track_index
	var banner := "START" if tracker.lap == 0 else ("FINISH" if tracker.lap >= tracker.total_laps else "CONTINUE")
	if banner != track.banner_text:
		track.set_banner(banner)
	audio.update_audio(delta, race_start)
	if tracker.is_finished:
		if not finish_played:
			finish_played = true
			audio.play_finish()
		if kart.driver == null:
			# the finished player is taken over by the autopilot so the kart keeps rolling
			kart.driver = AiDriver.new(data, 0.0, 999.0)
		finish_timer += delta
		if not results_shown and finish_timer >= RESULTS_DELAY:
			results_shown = true
			var names: Array = []
			for i in karts.size():
				names.append(RACER_NAMES[i % RACER_NAMES.size()])
			hud.show_results(RaceResults.table_text(RaceResults.rows(names, progresses, finish_times), 0))
	var place := RaceRanking.rank_of(0, progresses, finish_times)
	hud.update_hud(tracker, kart.model.speed, kart.model.is_boosting(), kart.model.drift_level, items.holder.display_item(items.time), Hud.place_text(place, karts.size()), kart.model.is_star(), kart.model.is_shrunk())
	hud.show_countdown(race_start.label())
	var marker_pos: Array = []
	var marker_col: Array = []
	for k in karts:
		marker_pos.append(k.global_position)
		marker_col.append(k.body_color)
	hud.update_minimap(marker_pos, marker_col)

func _process(delta: float) -> void:
	var target := kart.global_position + _back() * 6.0 + Vector3(0, 3.0, 0)
	cam.global_position = cam.global_position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	cam.look_at(kart.global_position + Vector3(0, 1.0, 0))
	var ratio: float = absf(kart.model.speed) / kart.model.max_speed
	speed_fx.update_fx(delta, ratio, kart.model.is_boosting())
	cam.fov = lerpf(cam.fov, 70.0 + 10.0 * speed_fx.speed_amount + 12.0 * speed_fx.boost_amount, clampf(5.0 * delta, 0.0, 1.0))
