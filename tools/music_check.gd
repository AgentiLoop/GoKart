extends SceneTree
## Headless check of the Mario Kart 64 style course music:
##   perl -e 'alarm 120; exec @ARGV' godot --headless --path . -s tools/music_check.gd
## Run A (race, Green Hills): silence on the grid, the course tune starts at GO at normal pitch, the
## "Final Lap!" jingle plays once when the last lap begins and the loop speeds up, the Star theme takes
## over (course music ducked) and comes off again, the music fades out at the finish and the 1st-place
## fanfare plays.
## Run B (battle): the arena tune starts at GO.

const Music := preload("res://scripts/music.gd")
const GameAudio := preload("res://scripts/game_audio.gd")

var main
var stage := 0
var frames := 0
var ok := true
var run := "A"
var t0 := 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + "[%s] %s" % [run, msg])
	if not cond:
		ok = false

func _start(scene: String) -> void:
	load("res://scripts/track_library.gd").selected = 0
	if main != null:
		root.remove_child(main)
		main.free()
	main = load(scene).instantiate()
	root.add_child(main)
	stage = 0
	frames = 0

func _initialize() -> void:
	Input.action_release("accelerate")
	var t := Time.get_ticks_msec()
	for key in Music.SONGS:
		Music.stream(key)
	print("rendered %d songs in %d ms" % [Music.SONGS.size(), Time.get_ticks_msec() - t])
	_start("res://scenes/main.tscn")

func _physics_process(_d: float) -> bool:
	frames += 1
	var audio = main.audio
	var rs = main.race_start
	if run == "A":
		if stage == 0 and frames == 5:
			_check(audio.music.stream == Music.stream("Green Hills"), "the course's own tune is loaded")
			_check(not audio.music.playing and audio.music.volume_db == GameAudio.SILENT_DB, "silent on the grid")
			_check(not audio.played.has("final_lap"), "no final-lap jingle before GO")
		elif stage == 0 and rs.started:
			stage = 1
			t0 = frames
		elif stage == 1 and frames - t0 == 90:
			_check(audio.music.playing, "course music playing after GO")
			_check(audio.music.volume_db > GameAudio.MUSIC_DB - 1.0, "music up to level: %.1f dB" % audio.music.volume_db)
			_check(is_equal_approx(audio.music.pitch_scale, 1.0), "normal tempo on lap 1")
			_check(not audio.played.has("final_lap"), "no jingle yet")
			main.tracker.lap = main.tracker.total_laps   # the player starts the final lap
			stage = 2
			t0 = frames
		elif stage == 2 and frames - t0 == 60:
			_check(audio.played.count("final_lap") == 1, "Final Lap! jingle once")
			_check(audio.music.pitch_scale > 1.1, "music speeds up on the final lap: %.2f" % audio.music.pitch_scale)
			_check(audio.music.playing, "still the same loop, faster")
			main.kart.model.apply_star(2.0)
			stage = 3
			t0 = frames
		elif stage == 3 and frames - t0 == 60:
			_check(audio.star_music.playing, "Star theme playing")
			_check(audio.music.volume_db < GameAudio.SILENT_DB + 1.0, "course music ducked under the Star: %.1f dB" % audio.music.volume_db)
			stage = 4
			t0 = frames
		elif stage == 4 and frames - t0 == 120:
			_check(not main.kart.model.is_star(), "star over")
			_check(not audio.star_music.playing, "Star theme stopped")
			_check(audio.music.volume_db > GameAudio.MUSIC_DB - 1.0, "course music back: %.1f dB" % audio.music.volume_db)
			_check(audio.played.count("final_lap") == 1, "jingle not repeated")
			main.tracker.is_finished = true   # the player crosses the line first
			stage = 5
			t0 = frames
		elif stage == 5 and frames - t0 == 90:
			_check(not audio.music.playing, "music stopped after the finish")
			_check(audio.played.has("finish") and not audio.played.has("finish_ok") and not audio.played.has("finish_out"), "1st-place fanfare (nobody else has finished)")
			run = "B"
			load("res://scripts/battle.gd").arena = 0
			_start("res://scenes/battle.tscn")
	else:
		if stage == 0 and frames == 5:
			_check(audio.music.stream == Music.stream("battle"), "battle tune loaded")
			_check(not audio.music.playing, "silent before GO")
		elif stage == 0 and rs.started:
			stage = 1
			t0 = frames
		elif stage == 1 and frames - t0 == 90:
			_check(audio.music.playing and audio.music.volume_db > GameAudio.MUSIC_DB - 1.0, "battle music playing after GO")
			_check(is_equal_approx(audio.music.pitch_scale, 1.0), "battle music at normal tempo")
			print("MUSIC CHECK: " + ("OK" if ok else "FAILED"))
			quit(0 if ok else 1)
			return true
	if frames > 1500:
		print("FAIL [%s] timed out at stage %d" % [run, stage])
		quit(1)
		return true
	return false
