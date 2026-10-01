extends AudioStreamPlayer3D
## Positional engine hum for a computer-driven kart: pitch follows the kart's speed and
## the sound fades with distance from the camera (the built-in 3D attenuation).

const SoundSynth := preload("res://scripts/sound_synth.gd")

const BASE_DB := -8.0
const MAX_DISTANCE := 60.0
const UNIT_SIZE := 6.0
const PITCH_SCALE_AI := 0.9   # a touch lower than the player's engine so the two can be told apart

static var shared_stream: AudioStreamWAV = null

var kart   # the Kart node this engine belongs to

static func engine_stream() -> AudioStreamWAV:
	if shared_stream == null:
		shared_stream = SoundSynth.to_wav(SoundSynth.engine_loop(), true)
	return shared_stream

## Playback pitch for a kart moving at `speed` with the given top speed.
static func pitch_for(speed: float, max_speed: float, boosting: bool) -> float:
	var ratio := absf(speed) / maxf(max_speed, 0.001)
	return SoundSynth.engine_pitch(ratio, boosting) * PITCH_SCALE_AI

## Volume for a kart that is frozen (countdown) or racing.
static func volume_for(frozen: bool) -> float:
	return BASE_DB - 8.0 if frozen else BASE_DB

func _ready() -> void:
	stream = engine_stream()
	max_distance = MAX_DISTANCE
	unit_size = UNIT_SIZE
	attenuation_model = ATTENUATION_INVERSE_DISTANCE
	volume_db = volume_for(true)
	play()

func _physics_process(_delta: float) -> void:
	if kart == null:
		return
	pitch_scale = pitch_for(kart.model.speed, kart.model.max_speed, kart.model.is_boosting())
	volume_db = volume_for(kart.frozen)
