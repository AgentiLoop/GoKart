extends RefCounted
## Mario Kart 64 style course music: every course has a tune, the battle arenas and the Star
## have their own, the loops render seamlessly and the race audio speeds the music up on the
## final lap and picks the finish fanfare by place.

const Music := preload("res://scripts/music.gd")
const SoundSynth := preload("res://scripts/sound_synth.gd")
const GameAudio := preload("res://scripts/game_audio.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
var runner

func test_note_hz() -> void:
	runner.check(is_equal_approx(Music.note_hz("A4"), 440.0))
	runner.check(absf(Music.note_hz("C4") - 261.63) < 0.01, str(Music.note_hz("C4")))
	runner.check(is_equal_approx(Music.note_hz("A5"), 880.0))
	runner.check(is_equal_approx(Music.note_hz("A#4"), Music.note_hz("Bb4")))
	runner.check(Music.note_hz("G#2") > Music.note_hz("G2") and Music.note_hz("G#2") < Music.note_hz("A2"))
	runner.check(is_equal_approx(Music.note_hz("E2") * 2.0, Music.note_hz("E3")))

func test_tokens_drop_bar_lines() -> void:
	var t := Music.tokens("C4 . - | D4 -")
	runner.check(t.size() == 5 and t[0] == "C4" and t[1] == "." and t[2] == "-" and t[3] == "D4", str(t))

func test_step_duration() -> void:
	runner.check(is_equal_approx(Music.step_duration(120), 0.25))   # eighth notes at 120 bpm
	runner.check(Music.step_duration(160) < Music.step_duration(120))

## Every course has its own song, the battle and the Star too, and all are well formed (equal voices).
func test_every_course_has_a_valid_song() -> void:
	for i in TrackLibrary.count():
		var name: String = TrackLibrary.info(i).name
		runner.check(Music.SONGS.has(name), name)
		runner.check(Music.valid(Music.song(name)), name)
	for key in ["battle", "star"]:
		runner.check(Music.SONGS.has(key) and Music.valid(Music.song(key)), key)
	# the course tunes differ from each other
	var leads := {}
	for key in Music.SONGS:
		leads[Music.SONGS[key].lead] = true
	runner.check(leads.size() == Music.SONGS.size(), "songs share a lead line")
	# an unknown key falls back to the default tune
	runner.check(Music.song("No Such Course") == Music.SONGS[Music.DEFAULT_SONG])

func test_valid_rejects_mismatched_voices() -> void:
	runner.check(not Music.valid({"bpm": 120, "lead": "C4 D4", "bass": "C3", "drums": "x -"}))
	runner.check(not Music.valid({"bpm": 120, "lead": "", "bass": "", "drums": ""}))
	runner.check(Music.valid({"bpm": 120, "lead": "C4 D4 | E4", "bass": "C3 - -", "drums": "x h s"}))

## A rendered song is exactly the pattern's length, audible, within range and quiet at the loop point.
func test_render_loop() -> void:
	var s := {"bpm": 240, "lead": "C5 . E5 - | G5 . . -", "bass": "C3 - - - | G2 - - -", "drums": "x h s h | x h s -"}
	var buf := Music.render(s)
	runner.check(buf.size() == Music.loop_samples(s), str(buf.size()))
	runner.check(buf.size() == int(round(8 * 0.125 * SoundSynth.MIX_RATE)))
	var p := SoundSynth.peak(buf)
	runner.check(p > 0.1 and p <= 1.0, str(p))
	# the notes are released before the loop point: the last and first samples are near silence
	runner.check(absf(buf[buf.size() - 1]) < 0.05 and absf(buf[0]) < 0.05, "%f %f" % [buf[0], buf[buf.size() - 1]])
	# a rest is silent (the last step of the first bar carries only a hat tick that dies within it)
	var rest_start := int(round(3.5 * 0.125 * SoundSynth.MIX_RATE))
	var rest_end := int(round(4 * 0.125 * SoundSynth.MIX_RATE))
	var quiet := true
	for i in range(rest_start, rest_end):
		if absf(buf[i]) > 0.02:
			quiet = false
	runner.check(quiet, "rest not silent")
	# a held note ("C5 .") sounds through its second step
	var held := int(round(1.5 * 0.125 * SoundSynth.MIX_RATE))
	var loud := false
	for i in range(held, held + 200):
		if absf(buf[i]) > 0.05:
			loud = true
	runner.check(loud, "held note silent")

func test_render_is_deterministic() -> void:
	var s: Dictionary = Music.SONGS["star"]
	runner.check(Music.render(s) == Music.render(s))

## The shared streams: looping WAVs, rendered once.
func test_stream_cached_and_looping() -> void:
	var a: AudioStreamWAV = Music.stream("battle")
	runner.check(a != null and a == Music.stream("battle"))
	runner.check(a.loop_mode == AudioStreamWAV.LOOP_FORWARD and a.loop_end == Music.loop_samples(Music.SONGS["battle"]))
	runner.check(a.mix_rate == SoundSynth.MIX_RATE)
	runner.check(Music.stream("No Such Course") == Music.stream(Music.DEFAULT_SONG))

## Every course tune renders audibly and within range.
func test_course_songs_render() -> void:
	for i in TrackLibrary.count():
		var name: String = TrackLibrary.info(i).name
		var wav: AudioStreamWAV = Music.stream(name)
		runner.check(wav.data.size() == Music.loop_samples(Music.song(name)) * 2, name)
		var peak := 0
		for k in range(0, wav.data.size(), 2 * 50):
			peak = maxi(peak, absi(wav.data.decode_s16(k)))
		runner.check(peak > 3000 and peak <= 32767, "%s peak %d" % [name, peak])

## MK64 race audio rules: faster music on the final lap, silent before GO / after the finish /
## under the Star theme, a fanfare per place.
func test_music_pitch_and_level() -> void:
	runner.check(GameAudio.music_pitch(false) == 1.0)
	runner.check(GameAudio.music_pitch(true) == GameAudio.FINAL_LAP_PITCH and GameAudio.FINAL_LAP_PITCH > 1.0)
	runner.check(GameAudio.music_db(true, false, false) == GameAudio.MUSIC_DB)
	runner.check(GameAudio.music_db(false, false, false) == GameAudio.SILENT_DB)
	runner.check(GameAudio.music_db(true, true, false) == GameAudio.SILENT_DB)
	runner.check(GameAudio.music_db(true, false, true) == GameAudio.SILENT_DB)

func test_finish_fanfare_by_place() -> void:
	runner.check(GameAudio.finish_effect(1) == "finish")
	runner.check(GameAudio.finish_effect(2) == "finish_ok" and GameAudio.finish_effect(4) == "finish_ok")
	runner.check(GameAudio.finish_effect(5) == "finish_out" and GameAudio.finish_effect(8) == "finish_out")
	var lib := SoundSynth.effect_library()
	for name in ["finish", "finish_ok", "finish_out", "final_lap"]:
		runner.check(lib.has(name) and SoundSynth.peak(lib[name]) > 0.1, name)
	runner.check(lib["finish"] != lib["finish_ok"] and lib["finish_ok"] != lib["finish_out"])

## The GameAudio node: the song is loaded silent, begins at GO, the "Final Lap!" jingle plays once
## when the last lap starts and the loop runs faster, the Star theme takes over, the finish stops it.
func test_game_audio_music_flow() -> void:
	var audio = GameAudio.new()
	audio._ready()
	audio.start_music("Green Hills")
	runner.check(audio.music.stream == Music.stream("Green Hills"))
	runner.check(audio.music.volume_db == GameAudio.SILENT_DB and not audio.music_started)
	audio.update_music(0.016, false, false, false, false)
	runner.check(not audio.music_started, "no music before GO")
	for i in 60:
		audio.update_music(0.05, true, false, false, false)
	runner.check(audio.music_started)
	runner.check(audio.music.volume_db > GameAudio.MUSIC_DB - 1.0, str(audio.music.volume_db))
	runner.check(is_equal_approx(audio.music.pitch_scale, 1.0))
	runner.check(not audio.played.has("final_lap"))
	for i in 40:
		audio.update_music(0.05, true, true, false, false)
	runner.check(audio.played.count("final_lap") == 1, "final lap jingle once: %d" % audio.played.count("final_lap"))
	runner.check(is_equal_approx(audio.music.pitch_scale, GameAudio.FINAL_LAP_PITCH), str(audio.music.pitch_scale))
	for i in 60:
		audio.update_music(0.05, true, true, false, true)
	runner.check(audio.music.volume_db < GameAudio.SILENT_DB + 1.0, "course music ducked under the Star theme: %f" % audio.music.volume_db)
	for i in 60:
		audio.update_music(0.05, true, true, false, false)
	runner.check(audio.music.volume_db > GameAudio.MUSIC_DB - 1.0, "course music back after the Star")
	for i in 60:
		audio.update_music(0.05, true, true, true, false)
	runner.check(audio.music.volume_db < GameAudio.SILENT_DB + 1.0, "music fades out after the finish")
	runner.check(audio.played.count("final_lap") == 1)
	audio.free()

## No music is loaded until a scene asks for it (update_music is then a no-op).
func test_game_audio_without_music() -> void:
	var audio = GameAudio.new()
	audio._ready()
	audio.update_music(0.05, true, true, false, false)
	runner.check(audio.played.is_empty() and not audio.music_started)
	audio.free()
