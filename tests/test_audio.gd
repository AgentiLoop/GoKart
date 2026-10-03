extends RefCounted

const SoundSynth := preload("res://scripts/sound_synth.gd")
const GameAudio := preload("res://scripts/game_audio.gd")
var runner

func test_sample_count() -> void:
	runner.check(SoundSynth.sample_count(1.0) == SoundSynth.MIX_RATE)
	runner.check(SoundSynth.sample_count(0.0) == 1)

func test_envelope() -> void:
	runner.check(SoundSynth.envelope(-0.1, 1.0) == 0.0)
	runner.check(SoundSynth.envelope(1.0, 1.0) == 0.0)
	runner.check(SoundSynth.envelope(0.0, 1.0) == 0.0)   # starts silent (attack)
	runner.check(SoundSynth.envelope(0.05, 1.0) > SoundSynth.envelope(0.9, 1.0))

func test_tone_length_and_range() -> void:
	var s := SoundSynth.tone(440.0, 0.25, 0.5)
	runner.check(s.size() == SoundSynth.sample_count(0.25))
	var p := SoundSynth.peak(s)
	runner.check(p > 0.05 and p <= 1.0, str(p))

func test_sweep_not_silent_and_bounded() -> void:
	var s := SoundSynth.sweep(500.0, 90.0, 0.4, 0.65)
	runner.check(SoundSynth.peak(s) > 0.1 and SoundSynth.peak(s) <= 1.0)

func test_arpeggio_length() -> void:
	var s := SoundSynth.arpeggio([440.0, 550.0, 660.0], 0.1)
	runner.check(s.size() == 3 * SoundSynth.sample_count(0.1))

func test_noise_deterministic() -> void:
	var a := SoundSynth.noise_burst(0.1, 0.5, 0.5, 4)
	var b := SoundSynth.noise_burst(0.1, 0.5, 0.5, 4)
	var c := SoundSynth.noise_burst(0.1, 0.5, 0.5, 5)
	runner.check(a == b)
	runner.check(a != c)
	runner.check(SoundSynth.peak(a) > 0.01)

func test_engine_loop_is_seamless() -> void:
	var e := SoundSynth.engine_loop()
	runner.check(e.size() == SoundSynth.sample_count(SoundSynth.ENGINE_LOOP_CYCLES / SoundSynth.ENGINE_BASE_HZ))
	# the jump from the last sample back to the first is no bigger than a normal neighbour step
	var jump := absf(e[0] - e[e.size() - 1])
	var step := 0.0
	for i in range(1, e.size()):
		step = maxf(step, absf(e[i] - e[i - 1]))
	runner.check(jump <= step * 1.5 + 0.001, "jump %f step %f" % [jump, step])
	runner.check(SoundSynth.peak(e) <= 1.0)

func test_screech_loop_blend() -> void:
	var s := SoundSynth.screech_loop()
	runner.check(SoundSynth.peak(s) > 0.01 and SoundSynth.peak(s) <= 1.0)

func test_engine_pitch() -> void:
	runner.check(SoundSynth.engine_pitch(0.0) < SoundSynth.engine_pitch(0.5))
	runner.check(SoundSynth.engine_pitch(0.5) < SoundSynth.engine_pitch(1.0))
	runner.check(SoundSynth.engine_pitch(1.0, true) > SoundSynth.engine_pitch(1.0))
	runner.check(is_equal_approx(SoundSynth.engine_pitch(-0.5), SoundSynth.engine_pitch(0.5)))
	runner.check(SoundSynth.engine_pitch(99.0) == SoundSynth.engine_pitch(1.4))

func test_countdown_tick() -> void:
	runner.check(SoundSynth.countdown_tick(4, 3.0) == 3)
	runner.check(SoundSynth.countdown_tick(3, 2.99) == -1)
	runner.check(SoundSynth.countdown_tick(3, 2.0) == 2)
	runner.check(SoundSynth.countdown_tick(1, 0.0) == 0)
	runner.check(SoundSynth.countdown_tick(0, 0.0) == -1)

func test_countdown_beeps_differ() -> void:
	runner.check(SoundSynth.countdown_beep(0).size() > SoundSynth.countdown_beep(3).size())

func test_wav_conversion() -> void:
	var s := SoundSynth.tone(440.0, 0.1)
	var wav := SoundSynth.to_wav(s)
	runner.check(wav.format == AudioStreamWAV.FORMAT_16_BITS)
	runner.check(wav.data.size() == s.size() * 2)
	runner.check(wav.mix_rate == SoundSynth.MIX_RATE)
	runner.check(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED)
	var looped := SoundSynth.to_wav(s, true)
	runner.check(looped.loop_mode == AudioStreamWAV.LOOP_FORWARD and looped.loop_end == s.size())
	# encoding round trip of the loudest sample
	var idx := 0
	for i in s.size():
		if absf(s[i]) > absf(s[idx]):
			idx = i
	runner.check(absf(wav.data.decode_s16(idx * 2) / 32767.0 - s[idx]) < 0.001)

func test_effect_library() -> void:
	var lib := SoundSynth.effect_library()
	for name in ["beep", "go", "boost", "drift_start", "mini_turbo", "pickup", "item_ready", "hit", "explosion", "lightning", "star", "boo", "throw", "finish", "burnout", "block"]:
		runner.check(lib.has(name), name)
		runner.check(lib[name].size() > 100 and SoundSynth.peak(lib[name]) > 0.01 and SoundSynth.peak(lib[name]) <= 1.0, name)

func test_loop_db() -> void:
	runner.check(GameAudio.loop_db(true, -10.0) == -10.0)
	runner.check(GameAudio.loop_db(false, -10.0) == GameAudio.SILENT_DB)

func test_ai_engine_pitch_and_volume() -> void:
	var AiEngineAudio := preload("res://scripts/ai_engine_audio.gd")
	var idle: float = AiEngineAudio.pitch_for(0.0, 30.0, false)
	var fast: float = AiEngineAudio.pitch_for(30.0, 30.0, false)
	runner.check(fast > idle and idle > 0.0)
	runner.check(AiEngineAudio.pitch_for(30.0, 30.0, true) > fast)
	runner.check(AiEngineAudio.pitch_for(-15.0, 30.0, false) == AiEngineAudio.pitch_for(15.0, 30.0, false))
	runner.check(AiEngineAudio.volume_for(true) < AiEngineAudio.volume_for(false))
	var s: AudioStreamWAV = AiEngineAudio.engine_stream()
	runner.check(s != null and s == AiEngineAudio.engine_stream())   # cached and shared
	runner.check(s.loop_mode == AudioStreamWAV.LOOP_FORWARD)

func test_ai_engine_node_follows_kart() -> void:
	var AiEngineAudio := preload("res://scripts/ai_engine_audio.gd")
	var KartPhysics := preload("res://scripts/kart_physics.gd")
	var stub := Node.new()
	stub.set_script(preload("res://tests/stub_kart.gd"))
	stub.model = KartPhysics.new()
	stub.frozen = false
	var node: AudioStreamPlayer3D = AiEngineAudio.new()
	node.kart = stub
	stub.model.speed = 0.0
	node._physics_process(0.016)
	var idle := node.pitch_scale
	stub.model.speed = stub.model.max_speed
	node._physics_process(0.016)
	runner.check(node.pitch_scale > idle)
	runner.check(node.volume_db == AiEngineAudio.volume_for(false))
	stub.frozen = true
	node._physics_process(0.016)
	runner.check(node.volume_db == AiEngineAudio.volume_for(true))
	node.free()
	stub.free()
