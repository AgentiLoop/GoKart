extends RefCounted
## Title / select-screen audio (MenuAudio): MK64 plays a title tune on the title screen and the
## Selection Screens tune on every select screen, ticks for the cursor and chimes on a confirmation.
## Covers the two new songs, the three menu effects, the node's cross-fade logic (outside the tree,
## like the GameAudio tests) and the menu's wiring (which key plays which sound, Enter hands the
## audio over to the scene root).

const Music := preload("res://scripts/music.gd")
const SoundSynth := preload("res://scripts/sound_synth.gd")
const MenuAudio := preload("res://scripts/menu_audio.gd")
const Menu := preload("res://scripts/menu.gd")
var runner

func _root() -> Node:
	return Engine.get_main_loop().root

func _menu() -> Node:
	var m = Menu.new()
	_root().add_child(m)
	if m.select_box == null:
		m._ready()   # the runner's root is not ready yet during _initialize
	return m

## A MenuAudio node on its own (not in the tree: _start never plays, which the tests do not need).
func _audio() -> Node:
	var a = MenuAudio.new()
	a._ready()
	return a

func test_title_and_menu_songs() -> void:
	for key in [MenuAudio.TITLE_KEY, MenuAudio.MENU_KEY]:
		runner.check(Music.SONGS.has(key) and Music.valid(Music.song(key)), key + " is a well-formed song")
		runner.check(Music.steps(Music.song(key)) == 64, key + " is 8 bars of eighth notes")
		var s: AudioStreamWAV = Music.stream(key)
		runner.check(s.loop_mode == AudioStreamWAV.LOOP_FORWARD and s.loop_end == Music.loop_samples(Music.song(key)), key + " loops")
		var samples := Music.render(Music.song(key))
		var pk := SoundSynth.peak(samples)
		runner.check(pk > 0.3 and pk <= 1.0, "%s peak %.2f (audible, no clipping)" % [key, pk])
	runner.check(Music.SONGS[MenuAudio.TITLE_KEY].lead != Music.SONGS[MenuAudio.MENU_KEY].lead, "the two tunes differ")
	# the select tune is built on a two-bar bass ostinato (MK64's Selection Screens has one)
	var bass := Music.tokens(Music.SONGS[MenuAudio.MENU_KEY].bass)
	var repeats := true
	for i in range(16, bass.size()):
		repeats = repeats and bass[i] == bass[i - 16]
	runner.check(repeats, "menu bass repeats every two bars")
	# the title tune has a lead note on the first step of every bar (a fanfare, not a groove)
	var lead := Music.tokens(Music.SONGS[MenuAudio.TITLE_KEY].lead)
	var downbeats := true
	for b in 8:
		downbeats = downbeats and lead[b * 8] != "-" and lead[b * 8] != "."
	runner.check(downbeats, "title lead hits every downbeat")

func test_menu_effects() -> void:
	var lib := SoundSynth.effect_library()
	for name in MenuAudio.EFFECTS:
		runner.check(lib.has(name), name)
		runner.check(lib[name].size() > 100 and SoundSynth.peak(lib[name]) > 0.01 and SoundSynth.peak(lib[name]) <= 1.0, name)
	# the ticks are short, the chime longer
	runner.check(lib["cursor"].size() < lib["confirm"].size() and lib["option"].size() < lib["confirm"].size(), "ticks shorter than the chime")
	runner.check(lib["cursor"].size() <= SoundSynth.sample_count(0.1) and lib["option"].size() <= SoundSynth.sample_count(0.1), "ticks are under 0.1 s")
	# the landing thud is a low falling sweep, longer than a tick
	runner.check(lib["land"].size() > lib["cursor"].size() and lib["land"].size() <= SoundSynth.sample_count(0.4), "the thud lasts longer than a tick, under 0.4 s")

func test_audio_node_levels_and_crossfade() -> void:
	runner.check(MenuAudio.music_db(true, true) == MenuAudio.MUSIC_DB and MenuAudio.music_db(false, false) == MenuAudio.MUSIC_DB, "the tune of the current screen is loud")
	runner.check(MenuAudio.music_db(true, false) == MenuAudio.SILENT_DB and MenuAudio.music_db(false, true) == MenuAudio.SILENT_DB, "the other tune is silent")
	var a = _audio()
	runner.check(a.title.stream == Music.stream(MenuAudio.TITLE_KEY) and a.menu.stream == Music.stream(MenuAudio.MENU_KEY), "title / menu players carry their tunes")
	runner.check(a.title.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and a.menu.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "both loop")
	runner.check(a.pool.size() == MenuAudio.POOL_SIZE and a.streams.size() == MenuAudio.EFFECTS.size(), "voices + effect streams")
	a.set_title(true)
	runner.check(a.title_on and is_equal_approx(a.title.volume_db, MenuAudio.MUSIC_DB) and a.menu.volume_db == MenuAudio.SILENT_DB, "title screen: title tune up, select tune silent")
	for i in 60:
		a._process(1.0 / 60.0)
	runner.check(is_equal_approx(a.title.volume_db, MenuAudio.MUSIC_DB) and a.menu.volume_db == MenuAudio.SILENT_DB, "levels hold on the title screen")
	a.set_title(false)
	for i in 5:
		a._process(1.0 / 60.0)
	runner.check(a.title.volume_db < MenuAudio.MUSIC_DB - 1.0 and a.menu.volume_db > MenuAudio.SILENT_DB + 1.0, "select screen: cross-fade under way after 5 frames")
	for i in 180:
		a._process(1.0 / 60.0)
	runner.check(absf(a.menu.volume_db - MenuAudio.MUSIC_DB) < 0.5 and a.title.volume_db < MenuAudio.SILENT_DB + 1.0, "after 3 s: select tune up, title tune faded out")
	a.play("cursor")
	a.play("option")
	a.play("confirm")
	a.play("no_such_sound")
	runner.check(a.played == ["cursor", "option", "confirm", "no_such_sound"], "play records every request")
	runner.check(a.pool[0].stream == a.streams["confirm"], "the last effect was loaded on a voice")
	# leave() outside the tree only records the chime and stops the fades
	var before: int = MenuAudio.leaves
	a.leave()
	runner.check(a.left and MenuAudio.leaves == before + 1 and a.played[-1] == "confirm", "leave: chime + counter")
	var db: float = a.menu.volume_db
	a.set_title(true)
	a._process(1.0)
	runner.check(a.menu.volume_db == db and not a.title.playing, "after leave nothing changes any more")
	a.free()

func test_menu_wiring() -> void:
	var m = _menu()
	runner.check(m.audio != null and m.audio.get_parent() == m, "the menu owns a MenuAudio node")
	m.set_title(true)
	runner.check(m.audio.title_on, "title screen -> title tune")
	m.dismiss_title()
	runner.check(not m.audio.title_on and m.audio.played == ["confirm"], "any key off the title: select tune + chime")
	m.move(1)
	runner.check(m.audio.played[-1] == "cursor", "course cursor ticks")
	m.move_laps(1)
	m.move_difficulty(1)
	m.move_engine(-1)
	m.move_weight(1)
	m.toggle_mode()
	runner.check(m.audio.played.slice(2) == ["option", "option", "option", "option", "option"], "laps / CPU / engine / kart / mode tick lower: %s" % str(m.audio.played))
	m.dismiss_title()
	runner.check(m.audio.played.size() == 7, "dismiss off the title screen is silent")
	# a menu without its audio node (tests build bare menus) stays quiet without errors
	m.audio = null
	var sel: int = m.selected + m.arena_selected
	var laps: int = m.laps
	m.move(1)
	m.move_laps(-1)
	m.dismiss_title()
	runner.check(m.selected + m.arena_selected != sel and m.laps != laps, "moves still work without audio")
	m.free()
