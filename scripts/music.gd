extends RefCounted
## Procedural course music, Mario Kart 64 style: every course has its own tune, the battle arenas
## share one, the Star has its own theme, and the title screen and the select screens each have
## their own tune like MK64's "Title" and "Selection Screens" (keys "title" / "menu"). Each song is a short three-voice chiptune loop (lead,
## bass, drums) written as step patterns and rendered to a looping AudioStreamWAV through
## SoundSynth — no audio files, like the sound effects. The race scene speeds the loop up on the
## final lap (pitch_scale), as MK64 does.
##
## Pattern notation (one token per eighth-note step, bars separated by "|" which is ignored):
##   lead / bass: a note name ("C4", "F#3", "Bb2"), "." holds the previous note, "-" is a rest
##   drums: "x" kick, "s" snare, "h" hi-hat, "-" nothing
## All three voices of a song must have the same number of steps.

const SoundSynth := preload("res://scripts/sound_synth.gd")

const STEPS_PER_BEAT := 2
const LEAD_VOLUME := 0.22
const BASS_VOLUME := 0.3
const RELEASE := 0.03            # seconds: every note is cut this long before its last step ends
const DEFAULT_SONG := "Green Hills"

## Course name (TrackLibrary) or mode key -> song.
const SONGS := {
	"Green Hills": {   # a farm tune: bouncy oom-pah bass, major key
		"bpm": 160,
		"lead": "E5 G5 E5 C5 D5 E5 . . | G5 E5 D5 C5 D5 . . . | E5 G5 A5 G5 E5 D5 C5 . | D5 E5 D5 B4 C5 . . . | C5 E5 G5 . A5 G5 E5 . | F5 A5 C6 . B5 A5 G5 . | E5 G5 A5 G5 E5 C5 D5 E5 | D5 . C5 . . . - -",
		"bass": "C3 - G3 - C3 - G3 - | C3 - G3 - C3 - G3 - | F3 - C3 - F3 - C3 - | G3 - D3 - G3 - D3 - | C3 - G3 - A3 - E3 - | F3 - C3 - G3 - D3 - | C3 - G3 - F3 - G3 - | C3 - G3 - C3 - - -",
		"drums": "x h h h x h s h | x h h h x h s h | x h h h x h s h | x h h h x h s h | x h h h x h s h | x h h h x h s h | x h h h x h s h | x h h h x h x -",
	},
	"Sunset Speedway": {   # a highway at dusk: walking bass, syncopated lead, minor key
		"bpm": 144,
		"lead": "- A4 C5 E5 . D5 C5 . | - A4 C5 F5 . E5 C5 . | - D5 F5 A5 . G5 F5 . | E5 . . G#4 B4 E5 . . | A5 . G5 E5 . C5 D5 E5 | F5 . E5 C5 . A4 C5 D5 | E5 . B4 . G#4 . B4 D5 | C5 . A4 . . . - -",
		"bass": "A2 - E3 - A2 - G2 - | F2 - C3 - F2 - E2 - | D2 - A2 - D2 - F2 - | E2 - B2 - E2 - G#2 - | A2 - E3 - A2 - G2 - | F2 - C3 - D2 - A2 - | E2 - B2 - E2 - G#2 - | A2 - E3 - A2 - - -",
		"drums": "x - h h x h h h | x - h h x h h h | x - h h x h h h | x - h h x h h h | x - h h x h h h | x - h h x h h h | x - h h x h h h | x - h h s - - -",
	},
	"Frosty Peaks": {   # snow: high bell-like lead over long bass notes
		"bpm": 132,
		"lead": "A5 . C6 . A5 G5 F5 . | G5 . A5 . G5 F5 E5 . | F5 . A5 . C6 . A5 . | G5 . E5 . C5 . . . | A5 . C6 . D6 . C6 . | Bb5 . A5 . G5 . F5 . | E5 F5 G5 A5 Bb5 . G5 . | F5 . . . . . - -",
		"bass": "F3 - - - C3 - - - | C3 - - - E3 - - - | F3 - - - A3 - - - | C3 - - - G3 - - - | F3 - - - A3 - - - | Bb2 - - - D3 - - - | C3 - - - E3 - - - | F3 - - - C3 - - -",
		"drums": "x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - - - - - -",
	},
	"Dusty Canyon": {   # the desert: a galloping bass and a pentatonic lead
		"bpm": 120,
		"lead": "D4 . F4 . A4 . . . | C5 . A4 . F4 . D4 . | G4 . Bb4 . C5 . G4 . | A4 . F4 . D4 . . . | F4 . A4 . C5 . D5 . | C5 . Bb4 . G4 . E4 . | F4 . D4 . E4 . C#5 . | D4 . . . . . - -",
		"bass": "D2 - D2 A2 D2 - D2 A2 | D2 - D2 A2 D2 - D2 A2 | C2 - C2 G2 C2 - C2 G2 | D2 - D2 A2 D2 - D2 A2 | F2 - F2 C3 F2 - F2 C3 | C2 - C2 G2 C2 - C2 G2 | Bb2 - Bb2 F2 A2 - A2 E2 | D2 - D2 A2 D2 - - -",
		"drums": "x h x h s h x h | x h x h s h x h | x h x h s h x h | x h x h s h x h | x h x h s h x h | x h x h s h x h | x h x h s h x h | x - - - x - - -",
	},
	"battle": {   # the arenas: tense staccato minor key
		"bpm": 168,
		"lead": "E4 - E4 - G4 - B4 - | - - A4 G4 F#4 - E4 - | C4 - C4 - E4 - G4 - | - - F#4 E4 D#4 - B3 - | E4 - G4 - B4 - E5 - | - - C5 B4 A4 - E4 - | G4 - E4 - D#4 - F#4 - | E4 - - - - - - -",
		"bass": "E2 - E2 - E2 - G2 - | E2 - E2 - E2 - D2 - | C2 - C2 - C2 - E2 - | B1 - B1 - B1 - D2 - | E2 - E2 - E2 - G2 - | A2 - A2 - A2 - C3 - | C2 - C2 - B1 - B1 - | E2 - E2 - E2 - - -",
		"drums": "x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x - s - x - - -",
	},
	"star": {   # Star power: a quick, bright arpeggio loop that replaces the course music
		"bpm": 184,
		"lead": "G5 B5 D6 B5 G5 B5 D6 . | A5 C6 E6 C6 A5 C6 E6 . | B5 D6 G6 D6 B5 D6 G6 . | D6 . C6 . A5 . . .",
		"bass": "G3 - D3 - G3 - D3 - | A3 - E3 - A3 - E3 - | G3 - D3 - B3 - D3 - | D3 - A3 - D3 - - -",
		"drums": "x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x - - -",
	},
	"title": {   # the title screen: a brassy, syncopated fanfare over a marching bass (MK64's title tune)
		"bpm": 140,
		"lead": "C5 . G4 . C5 . E5 . | G5 . . . E5 G5 C6 . | A5 . G5 . E5 . C5 . | D5 . E5 D5 . . - - | C5 . G4 . C5 . E5 . | G5 . . . A5 G5 F5 . | E5 . G5 . C6 . B5 . | C6 . . . . . - -",
		"bass": "C3 - C3 - G2 - G2 - | C3 - C3 - E3 - G3 - | F3 - F3 - C3 - C3 - | G2 - G2 - B2 - D3 - | C3 - C3 - G2 - G2 - | C3 - C3 - F3 - F3 - | A2 - A2 - G2 - G2 - | C3 - G2 - C3 - - -",
		"drums": "x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x - s - x - - -",
	},
	"menu": {   # the select screens: a two-bar bass ostinato in B flat with brief licks on top (MK64's Selection Screens)
		"bpm": 112,
		"lead": "- - - - - - - - | - - - - F5 G5 Bb5 . | - - - - - - - - | D6 . C6 Bb5 . . - - | - - - - - - - - | - - - - Bb5 C6 D6 . | F6 . Eb6 D6 . C6 . . | Bb5 . . . - - - -",
		"bass": "Bb2 - Bb2 F2 Bb2 - D3 F3 | Eb3 - Eb3 Bb2 F2 - F2 A2 | Bb2 - Bb2 F2 Bb2 - D3 F3 | Eb3 - Eb3 Bb2 F2 - F2 A2 | Bb2 - Bb2 F2 Bb2 - D3 F3 | Eb3 - Eb3 Bb2 F2 - F2 A2 | Bb2 - Bb2 F2 Bb2 - D3 F3 | Eb3 - Eb3 Bb2 F2 - F2 A2",
		"drums": "x - h - s - h - | x - h - s - h - | x - h - s - h - | x - h - s - h - | x - h - s - h - | x - h - s - h - | x - h - s - h - | x - h - s - - -",
	},
}

const SEMITONES := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

static var _cache := {}

## The song for a course name or mode key (the default course tune when unknown).
static func song(key: String) -> Dictionary:
	return SONGS[key] if SONGS.has(key) else SONGS[DEFAULT_SONG]

## Looping AudioStreamWAV for `key`, rendered once and shared.
static func stream(key: String) -> AudioStreamWAV:
	var name: String = key if SONGS.has(key) else DEFAULT_SONG
	if not _cache.has(name):
		_cache[name] = SoundSynth.to_wav(render(SONGS[name]), true)
	return _cache[name]

## Tokens of a pattern: whitespace separated, bar lines dropped.
static func tokens(pattern: String) -> PackedStringArray:
	var out := PackedStringArray()
	for t in pattern.split(" ", false):
		if t != "|":
			out.append(t)
	return out

## Frequency of a note name like "A4", "F#3" or "Bb2" (A4 = 440 Hz).
static func note_hz(note: String) -> float:
	var semi: int = SEMITONES[note[0]]
	var i := 1
	if note[i] == "#":
		semi += 1
		i += 1
	elif note[i] == "b":
		semi -= 1
		i += 1
	var octave := int(note.substr(i))
	var midi := 12 * (octave + 1) + semi
	return 440.0 * pow(2.0, (midi - 69) / 12.0)

static func step_duration(bpm: int) -> float:
	return 60.0 / bpm / STEPS_PER_BEAT

## Number of steps in a song (its voices all agree, see valid()).
static func steps(s: Dictionary) -> int:
	return tokens(s.lead).size()

static func valid(s: Dictionary) -> bool:
	var n := steps(s)
	return n > 0 and tokens(s.bass).size() == n and tokens(s.drums).size() == n

## Length of the rendered loop in samples.
static func loop_samples(s: Dictionary) -> int:
	return int(round(steps(s) * step_duration(s.bpm) * SoundSynth.MIX_RATE))

## Renders one voice's notes into `out`: a note sounds from its step until the end of the last "."
## that follows it, minus RELEASE, with a soft attack and a gentle decay. `harmonics` is a list of
## [multiple, amplitude] pairs.
static func _render_voice(out: PackedFloat32Array, pattern: String, step_dur: float, harmonics: Array, volume: float) -> void:
	var toks := tokens(pattern)
	var n := toks.size()
	var i := 0
	while i < n:
		var tok := toks[i]
		if tok == "-" or tok == ".":
			i += 1
			continue
		var length := 1
		while i + length < n and toks[i + length] == ".":
			length += 1
		var hz := note_hz(tok)
		var start := int(round(i * step_dur * SoundSynth.MIX_RATE))
		var dur := length * step_dur - RELEASE
		var count := mini(int(dur * SoundSynth.MIX_RATE), out.size() - start)
		var phase := 0.0
		for k in count:
			var t := float(k) / SoundSynth.MIX_RATE
			phase += TAU * hz / SoundSynth.MIX_RATE
			var s := 0.0
			for h in harmonics:
				s += sin(phase * h[0]) * h[1]
			var env := minf(t / 0.005, 1.0) * minf((dur - t) / 0.02, 1.0) * (1.0 - 0.35 * t / dur)
			out[start + k] += s * volume * env
		i += length

## Drum hits: kick = a pitch drop, snare = a short bright noise, hat = a tick of noise.
static func _render_drums(out: PackedFloat32Array, pattern: String, step_dur: float) -> void:
	var toks := tokens(pattern)
	var kick := SoundSynth.sweep(150.0, 45.0, 0.12, 0.6)
	var snare := SoundSynth.noise_burst(0.09, 0.3, 0.4, 31)
	var hat := SoundSynth.noise_burst(0.03, 0.05, 0.22, 37)
	var hits := {"x": kick, "s": snare, "h": hat}
	for i in toks.size():
		if not hits.has(toks[i]):
			continue
		var hit: PackedFloat32Array = hits[toks[i]]
		var start := int(round(i * step_dur * SoundSynth.MIX_RATE))
		var count := mini(hit.size(), out.size() - start)
		for k in count:
			out[start + k] += hit[k]

## The whole song as a seamless loop (every note is released before the loop point).
static func render(s: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(loop_samples(s))
	var sd := step_duration(s.bpm)
	_render_voice(out, s.lead, sd, [[1.0, 1.0], [3.0, 0.33], [5.0, 0.2]], LEAD_VOLUME)     # square-ish lead
	_render_voice(out, s.bass, sd, [[1.0, 1.0], [2.0, 0.35], [3.0, 0.11]], BASS_VOLUME)    # rounder bass
	_render_drums(out, s.drums, sd)
	return out
