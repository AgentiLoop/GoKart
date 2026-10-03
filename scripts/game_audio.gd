extends Node
## Plays the procedural sounds (SoundSynth) for a race: engine, tire screech, boosts,
## item events, hits, countdown beeps and the finish jingle. Listens to the player's
## KartPhysics signals and the ItemManager; nothing here needs audio files.

const SoundSynth := preload("res://scripts/sound_synth.gd")
const Items := preload("res://scripts/items.gd")

const POOL_SIZE := 8
const SILENT_DB := -60.0
const ENGINE_DB := -14.0
const SCREECH_DB := -12.0

var streams := {}            # effect name -> AudioStreamWAV
var pool: Array = []         # AudioStreamPlayer one-shot voices
var engine: AudioStreamPlayer
var screech: AudioStreamPlayer
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
	engine.play()
	screech.play()

## Hook up to the player kart and the item manager.
func setup(player_kart, item_manager) -> void:
	kart = player_kart
	items = item_manager
	last_projectiles = items.projectiles.size()
	kart.model.drift_started.connect(func(_d): play("drift_start"))
	kart.model.drift_level_changed.connect(func(level): if level > 0: play("mini_turbo"))
	kart.model.boost_started.connect(func(_l): play("boost"))
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
	voice.play()
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

func play_finish() -> void:
	play("finish")

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
