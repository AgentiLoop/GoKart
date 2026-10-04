extends Node
## Plays the procedural sounds (SoundSynth) for a race: engine, tire screech, boosts,
## item events, hits, countdown beeps and the finish jingle, plus the course music (Music):
## the tune starts at GO, speeds up on the final lap after the "Final Lap!" jingle, gives way
## to the Star theme while the player is invincible and stops for the finish fanfare, which
## depends on the place (1st / 2nd - 4th / 5th or worse) — all as in Mario Kart 64. Listens to
## the player's KartPhysics signals and the ItemManager; nothing here needs audio files.

const SoundSynth := preload("res://scripts/sound_synth.gd")
const Music := preload("res://scripts/music.gd")
const Items := preload("res://scripts/items.gd")

const POOL_SIZE := 8
const SILENT_DB := -60.0
const ENGINE_DB := -14.0
const SCREECH_DB := -12.0
const MUSIC_DB := -16.0
const STAR_DB := -13.0
const FINAL_LAP_PITCH := 1.12   # MK64: the course music runs faster on the final lap

var streams := {}            # effect name -> AudioStreamWAV
var pool: Array = []         # AudioStreamPlayer one-shot voices
var engine: AudioStreamPlayer
var screech: AudioStreamPlayer
var music: AudioStreamPlayer      # the course / battle loop
var star_music: AudioStreamPlayer # the Star theme
var music_key := ""               # which song is loaded ("" = none)
var music_started := false
var was_final_lap := false
var kart                     # the player kart
var items
var last_count := 4
var was_rolling := false
var last_projectiles := 0
var played: Array = []       # names of the effects triggered so far (for tests)
## Level-crossing bell: rings every BELL_PERIOD while the player is near a blocked crossing.
const BELL_PERIOD := 0.55
var bell_timer := 0.0

func _ready() -> void:
	for name in SoundSynth.effect_library():
		streams[name] = SoundSynth.to_wav(SoundSynth.effect_library()[name])
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	engine = AudioStreamPlayer.new()
	engine.stream = SoundSynth.to_wav(SoundSynth.engine_loop(), true)
	engine.volume_db = SILENT_DB
	add_child(engine)
	screech = AudioStreamPlayer.new()
	screech.stream = SoundSynth.to_wav(SoundSynth.screech_loop(), true)
	screech.volume_db = SILENT_DB
	add_child(screech)
	_start(engine)
	_start(screech)
	music = AudioStreamPlayer.new()
	music.volume_db = SILENT_DB
	add_child(music)
	star_music = AudioStreamPlayer.new()
	star_music.stream = Music.stream("star")
	star_music.volume_db = STAR_DB
	add_child(star_music)

## Hook up to the player kart and the item manager.
func setup(player_kart, item_manager) -> void:
	kart = player_kart
	items = item_manager
	last_projectiles = items.projectiles.size()
	kart.model.drift_started.connect(func(_d): play("drift_start"))
	kart.model.drift_level_changed.connect(func(level): if level > 0: play("mini_turbo"))
	kart.model.boost_started.connect(func(_l): play("boost"))
	kart.model.draft_started.connect(func(): play("draft", -4.0))
	kart.model.spin_started.connect(func(): play("hit"))
	kart.model.star_started.connect(func(): play("star"))
	kart.model.ghost_started.connect(func(): play("boo"))
	kart.model.stall_started.connect(func(): play("burnout"))
	items.kart_hit.connect(_on_kart_hit)
	items.shell_blocked.connect(func(_s, id, _i): play("block", 0.0 if id == 0 else -6.0))
	items.item_stolen.connect(_on_item_stolen)
	items.lightning_struck.connect(func(_u, _v): play("lightning"))

func _on_kart_hit(kind: int, id: int) -> void:
	if kind == Items.Type.BLUE_SHELL:
		play("explosion", 0.0 if id == 0 else -8.0)

## The player's item was taken by a rival's Boo.
func _on_item_stolen(_thief: int, victim: int, item: int) -> void:
	if victim == 0 and item != Items.Type.NONE:
		play("boo", -4.0)

## Starts a player; playback needs the scene tree (unit tests drive this node outside it).
func _start(p: AudioStreamPlayer) -> void:
	if is_inside_tree():
		p.play()

## Start a one-shot on a free voice (or steal the first one). Returns the voice used.
func play(effect: String, volume_db := 0.0) -> AudioStreamPlayer:
	played.append(effect)
	if not streams.has(effect):
		return null
	var voice: AudioStreamPlayer = pool[0]
	for p in pool:
		if not p.playing:
			voice = p
			break
	voice.stream = streams[effect]
	voice.volume_db = volume_db
	_start(voice)
	return voice

## Target volume of a looping voice: loud when active, silent otherwise.
static func loop_db(active: bool, loud_db: float) -> float:
	return loud_db if active else SILENT_DB

## Called every physics frame from the race scene.
func update_audio(delta: float, race_start) -> void:
	var tick := SoundSynth.countdown_tick(last_count, race_start.remaining)
	if tick >= 0:
		last_count = tick
		play("go" if tick == 0 else "beep")
	var m = kart.model
	# a false-start burnout revs the engine flat out while the kart sits still
	var ratio: float = 1.0 if m.is_stalled() else absf(m.speed) / m.max_speed
	var racing: bool = race_start.started and not kart.frozen
	engine.pitch_scale = SoundSynth.engine_pitch(ratio, m.is_boosting())
	engine.volume_db = lerpf(engine.volume_db, loop_db(true, ENGINE_DB if racing else ENGINE_DB - 8.0), clampf(8.0 * delta, 0.0, 1.0))
	var sliding: bool = m.drifting and m.speed > m.min_drift_speed
	screech.volume_db = lerpf(screech.volume_db, loop_db(sliding, SCREECH_DB), clampf(12.0 * delta, 0.0, 1.0))
	var rolling: bool = items.holder.is_rolling()
	if rolling and not was_rolling:
		play("pickup")
	elif was_rolling and not rolling and items.holder.held != Items.Type.NONE:
		play("item_ready")
	was_rolling = rolling
	var n: int = items.projectiles.size()
	if n > last_projectiles:
		play("throw", -6.0)
	last_projectiles = n

## The finish fanfare for the player's place: MK64 has one for 1st, one for 2nd - 4th and a sagging
## one for 5th or worse.
static func finish_effect(place: int) -> String:
	if place <= 1:
		return "finish"
	return "finish_ok" if place <= 4 else "finish_out"

func play_finish(place := 1) -> void:
	play(finish_effect(place))

## Load the song for a course name / mode key; it begins at GO (update_music).
func start_music(key: String) -> void:
	music_key = key
	music.stream = Music.stream(key)
	music_started = false
	music.volume_db = SILENT_DB

## Music pitch: faster on the final lap.
static func music_pitch(final_lap: bool) -> float:
	return FINAL_LAP_PITCH if final_lap else 1.0

## Course music level: silent before GO, after the finish and while the Star theme plays.
static func music_db(started: bool, finished: bool, star: bool) -> float:
	return MUSIC_DB if started and not finished and not star else SILENT_DB

## Called every physics frame: `final_lap` while the player is on the last lap (jingle on its
## first frame, then the faster tempo), `finished` once the player has crossed the line (the
## music fades out), `star` while the player is invincible (the Star theme takes over).
func update_music(delta: float, started: bool, final_lap: bool, finished: bool, star: bool) -> void:
	if music_key == "":
		return
	if started and not music_started and not finished:
		music_started = true
		_start(music)
	if final_lap and not was_final_lap and started and not finished:
		play("final_lap")
	was_final_lap = final_lap
	music.pitch_scale = move_toward(music.pitch_scale, music_pitch(final_lap), 0.4 * delta)
	var target := music_db(music_started, finished, star)
	music.volume_db = lerpf(music.volume_db, target, clampf(5.0 * delta, 0.0, 1.0))
	if finished and music.playing and music.volume_db < SILENT_DB + 1.0:
		music.stop()
	var star_on: bool = star and not finished
	if star_on and not star_music.playing:
		_start(star_music)
	elif not star_on and star_music.playing:
		star_music.stop()

## MK64 railway crossing: the bell rings steadily while `ringing` (a train is at or near the crossing
## the player is approaching); the first ring comes at once.
func update_crossing(delta: float, ringing: bool) -> void:
	if not ringing:
		bell_timer = 0.0
		return
	bell_timer -= delta
	if bell_timer <= 0.0:
		bell_timer = BELL_PERIOD
		play("bell", -8.0)
