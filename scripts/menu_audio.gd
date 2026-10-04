extends Node
## Title / select-screen audio in Mario Kart 64's spirit: MK64 plays its title tune on the title
## screen and the "Selection Screens" tune on every selection screen, with a tick for the cursor and
## a chime for a confirmation. Here the title theme (Music "title") loops under the attract demo and
## the select theme ("menu") takes over with a short cross-fade when the select screen comes up;
## moving the course cursor ticks ("cursor"), changing an option or the mode ticks lower ("option")
## and Enter chimes ("confirm"); the logo bouncing to a stop on the title screen thuds ("land", MK64's
## title call as the logo arrives). Starting a race hands the tune and the chime over to the scene root
## (leave) so the chime finishes and the music fades out while the race loads. Everything is
## synthesized (SoundSynth / Music), no audio files.

const SoundSynth := preload("res://scripts/sound_synth.gd")
const Music := preload("res://scripts/music.gd")

const TITLE_KEY := "title"
const MENU_KEY := "menu"
const MUSIC_DB := -14.0
const SILENT_DB := -60.0
const FADE_RATE := 4.0        # cross-fade speed between the two tunes (1 / s)
const LEAVE_FADE := 0.6       # seconds the tune takes to fade out behind the race loading
const EFFECTS := ["cursor", "option", "confirm", "land"]
const POOL_SIZE := 3
const OUT_GROUP := "menu_audio_out"   # players handed to the scene root by leave()

static var leaves := 0        # how many times leave() ran (headless checks read it across the scene change)

var title: AudioStreamPlayer  # the title theme
var menu: AudioStreamPlayer   # the select-screen theme
var streams := {}             # effect name -> AudioStreamWAV
var pool: Array = []          # one-shot voices
var title_on := true
var left := false
var played: Array = []        # effect names triggered so far (for tests)

func _ready() -> void:
	var lib := SoundSynth.effect_library()
	for name in EFFECTS:
		streams[name] = SoundSynth.to_wav(lib[name])
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	title = AudioStreamPlayer.new()
	title.stream = Music.stream(TITLE_KEY)
	title.volume_db = MUSIC_DB
	add_child(title)
	menu = AudioStreamPlayer.new()
	menu.stream = Music.stream(MENU_KEY)
	menu.volume_db = SILENT_DB
	add_child(menu)

## Starts a player; playback needs the scene tree (unit tests drive this node outside it).
func _start(p: AudioStreamPlayer) -> void:
	if is_inside_tree():
		p.play()

## Level of a tune: loud while its screen is up, silent otherwise.
static func music_db(on_title: bool, is_title: bool) -> float:
	return MUSIC_DB if on_title == is_title else SILENT_DB

## The title screen (on) plays the title theme; the select screen starts the select theme and fades
## the title theme out. The title theme never comes back (Esc from a race returns to the select screen).
func set_title(on: bool) -> void:
	title_on = on
	if title == null or left:
		return
	if on and not title.playing:
		title.volume_db = MUSIC_DB
		_start(title)
	elif not on and not menu.playing:
		_start(menu)

func _process(delta: float) -> void:
	if title == null or left:
		return
	var k := clampf(FADE_RATE * delta, 0.0, 1.0)
	title.volume_db = lerpf(title.volume_db, music_db(title_on, true), k)
	menu.volume_db = lerpf(menu.volume_db, music_db(title_on, false), k)
	if not title_on and title.playing and title.volume_db < SILENT_DB + 1.0:
		title.stop()

## A one-shot on a free voice (or the first one).
func play(effect: String) -> void:
	played.append(effect)
	if not streams.has(effect) or pool.is_empty():
		return
	var voice: AudioStreamPlayer = pool[0]
	for p in pool:
		if not p.playing:
			voice = p
			break
	voice.stream = streams[effect]
	_start(voice)

## Enter starts the race: the chime and the tune move to the scene root so they outlive the menu —
## the chime plays out, the tune fades over LEAVE_FADE — and both free themselves afterwards.
func leave() -> void:
	leaves += 1
	left = true
	played.append("confirm")
	if not is_inside_tree():
		return
	var root := get_tree().root
	for p: AudioStreamPlayer in [title, menu]:
		if p.playing:
			p.reparent(root)
			p.add_to_group(OUT_GROUP)
			var tw := p.create_tween()
			tw.tween_property(p, "volume_db", SILENT_DB, LEAVE_FADE)
			tw.tween_callback(p.queue_free)
	var chime := AudioStreamPlayer.new()
	chime.stream = streams["confirm"]
	root.add_child(chime)
	chime.add_to_group(OUT_GROUP)
	chime.play()
	var tw := chime.create_tween()
	tw.tween_interval(chime.stream.get_length() + 0.1)
	tw.tween_callback(chime.queue_free)
