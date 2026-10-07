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
	"Green Hills": {   # a county-fair midway: calliope lead with chromatic slides over an oom-pah bass
		"bpm": 132, "lead_wave": "calliope",
		"lead": "G4 G#4 A4 . C5 . A4 . | G4 . E4 . C4 . - - | G4 G#4 A4 . C5 . E5 . | D5 . . . - - - - | F5 E5 D#5 E5 C5 . A4 . | G4 F#4 G4 A4 G4 . E4 . | D4 E4 F4 G4 A4 B4 C5 D5 | C5 . G4 . C5 . - -",
		"bass": "C3 - G2 - C3 - G2 - | C3 - G2 - C3 - E3 - | F2 - C3 - F2 - C3 - | G2 - D3 - G2 - B2 - | C3 - G2 - A2 - E3 - | D3 - A2 - G2 - D3 - | G2 - B2 - D3 - G2 - | C3 - G2 - C3 - - -",
		"drums": "x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x - s -",
	},
	"Sunset Speedway": {   # stock-car glory: a soaring major-key anthem over chugging power chords
		"bpm": 128, "drive": true,
		"lead": "D5 . . . A4 . D5 E5 | F#5 . . . E5 . D5 . | B4 . . . G4 . B4 C#5 | D5 . . . A4 . . . | G5 . . . F#5 . E5 . | F#5 . . . D5 . A4 . | B4 . C#5 . D5 . E5 . | D5 . . . . . - -",
		"bass": "D2 D2 D2 D2 D2 D2 D2 D2 | D2 D2 D2 D2 A2 A2 A2 A2 | G2 G2 G2 G2 G2 G2 G2 G2 | A2 A2 A2 A2 A2 A2 A2 A2 | G2 G2 G2 G2 A2 A2 A2 A2 | D2 D2 D2 D2 B2 B2 B2 B2 | G2 G2 G2 G2 A2 A2 A2 A2 | D2 D2 D2 D2 D2 - - -",
		"drums": "x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h s s s -",
	},
	"Frosty Peaks": {   # snow: high bell-like lead over long bass notes
		"bpm": 126, "drive": true,
		"lead": "A5 . C6 . A5 G5 F5 . | G5 . A5 . G5 F5 E5 . | F5 . A5 . C6 . A5 . | G5 . E5 . C5 . . . | A5 . C6 . D6 . C6 . | Bb5 . A5 . G5 . F5 . | E5 F5 G5 A5 Bb5 . G5 . | F5 . . . . . - -",
		"bass": "F3 - - - C3 - - - | C3 - - - E3 - - - | F3 - - - A3 - - - | C3 - - - G3 - - - | F3 - - - A3 - - - | Bb2 - - - D3 - - - | C3 - - - E3 - - - | F3 - - - C3 - - -",
		"drums": "x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - h - - h - | x - - - - - - -",
	},
	"Dusty Canyon": {   # the desert: southern-rock boogie bass with a flat-seven swagger
		"bpm": 136, "drive": true,
		"lead": "G4 . B4 . D5 . E5 D5 | B4 . G4 . A4 . . . | C5 . E5 . G5 . E5 C5 | D5 . . . B4 . . . | G4 . B4 . D5 . G5 . | F5 . E5 . D5 . C5 . | B4 . A4 . F#4 . A4 . | G4 . . . . . - -",
		"bass": "G2 - B2 - D3 - E3 - | G2 - B2 - D3 - B2 - | C3 - E3 - G3 - A3 - | D3 - F#3 - A3 - F#3 - | G2 - B2 - D3 - E3 - | F2 - A2 - C3 - A2 - | D3 - C3 - A2 - F#2 - | G2 - D2 - G2 - - -",
		"drums": "x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h x x s h | x h s h x - - -",
	},
	"battle": {   # the arenas: tense staccato minor key
		"bpm": 184, "drive": true,
		"lead": "E4 - E4 - G4 - B4 - | - - A4 G4 F#4 - E4 - | C4 - C4 - E4 - G4 - | - - F#4 E4 D#4 - B3 - | E4 - G4 - B4 - E5 - | - - C5 B4 A4 - E4 - | G4 - E4 - D#4 - F#4 - | E4 - - - - - - -",
		"bass": "E2 - E2 - E2 - G2 - | E2 - E2 - E2 - D2 - | C2 - C2 - C2 - E2 - | B1 - B1 - B1 - D2 - | E2 - E2 - E2 - G2 - | A2 - A2 - A2 - C3 - | C2 - C2 - B1 - B1 - | E2 - E2 - E2 - - -",
		"drums": "x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x h s h x h s h | x - s - x - - -",
	},
	"star": {   # Star power: a quick, bright arpeggio loop that replaces the course music
		"bpm": 200, "drive": true,
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

const TABLE_SIZE := 1024
const LEAD_WAVE := [[1.0, 0.707], [2.0, 0.5], [3.0, 0.236], [5.0, 0.141], [6.0, 0.167], [7.0, 0.101]]   # 25% pulse
const BASS_WAVE := [[1.0, 1.0], [2.0, 0.5], [3.0, 0.33], [4.0, 0.25], [5.0, 0.2]]                       # sawtooth
const CALLIOPE_WAVE := [[1.0, 1.0], [2.0, 0.45], [3.0, 0.2], [4.0, 0.1]]                              # steam-whistle organ
const CHUG_VOLUME := 0.05
const POWER_CHORD := [12, 19, 24]   # root / fifth / octave an octave over the bass

## One cycle of a wave built from [multiple, amplitude] harmonic pairs, peak-normalised.
static func _table(harmonics: Array) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(TABLE_SIZE)
	var peak := 0.0
	for i in TABLE_SIZE:
		var s := 0.0
		for h in harmonics:
			s += sin(TAU * i / TABLE_SIZE * h[0]) * h[1]
		t[i] = s
		peak = maxf(peak, absf(s))
	for i in TABLE_SIZE:
		t[i] /= peak
	return t

## One note into `out`: two slightly detuned oscillators reading `table`, a fast attack, a pluck that
## decays to `sustain`, optional delayed vibrato, and a short release before `dur` ends.
static func _note(out: PackedFloat32Array, start: int, dur: float, hz: float, table: PackedFloat32Array, volume: float, sustain: float, vibrato: bool) -> void:
	var count := mini(int(dur * SoundSynth.MIX_RATE), out.size() - start)
	var p1 := 0.0
	var p2 := 0.0
	for k in count:
		var t := float(k) / SoundSynth.MIX_RATE
		var f := hz
		if vibrato and t > 0.15:
			f *= 1.0 + 0.006 * sin(TAU * 5.5 * t)
		p1 += f / SoundSynth.MIX_RATE
		p2 += f * 1.007 / SoundSynth.MIX_RATE
		p1 -= floorf(p1)
		p2 -= floorf(p2)
		var s := table[int(p1 * TABLE_SIZE) % TABLE_SIZE] + 0.5 * table[int(p2 * TABLE_SIZE) % TABLE_SIZE]
		var env := minf(t / 0.004, 1.0) * minf((dur - t) / 0.02, 1.0) * (sustain + (1.0 - sustain) * exp(-t / 0.08))
		out[start + k] += s * volume * env

## Renders one voice's notes into `out`: a note sounds from its step until the end of the last "."
## that follows it, minus RELEASE.
static func _render_voice(out: PackedFloat32Array, pattern: String, step_dur: float, table: PackedFloat32Array, volume: float, sustain: float, vibrato: bool) -> void:
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
		var start := int(round(i * step_dur * SoundSynth.MIX_RATE))
		_note(out, start, length * step_dur - RELEASE, note_hz(tok), table, volume, sustain, vibrato)
		i += length

## Driving songs: a palm-muted power chord (root / fifth / octave) chugging on every eighth over the
## current bass note, like a rock rhythm guitar.
static func _render_chugs(out: PackedFloat32Array, bass: String, step_dur: float, table: PackedFloat32Array) -> void:
	var toks := tokens(bass)
	var root := ""
	for i in toks.size():
		if toks[i] != "-" and toks[i] != ".":
			root = toks[i]
		if root == "" or i == toks.size() - 1:
			continue
		var start := int(round(i * step_dur * SoundSynth.MIX_RATE))
		for semi in POWER_CHORD:
			_note(out, start, step_dur * 0.6, note_hz(root) * pow(2.0, semi / 12.0), table, CHUG_VOLUME, 0.2, false)

## Drum hits: kick = a pitch drop, snare = a short bright noise, hat = a tick of noise. Driving songs
## add a softer hat on every off-sixteenth.
static func _render_drums(out: PackedFloat32Array, pattern: String, step_dur: float, drive: bool) -> void:
	var toks := tokens(pattern)
	var kick := SoundSynth.sweep(170.0, 42.0, 0.13, 0.75)
	var snare := SoundSynth.noise_burst(0.1, 0.25, 0.45, 31)
	var hat := SoundSynth.noise_burst(0.03, 0.05, 0.22, 37)
	var ghost := SoundSynth.noise_burst(0.02, 0.05, 0.1, 41)
	var hits := {"x": kick, "s": snare, "h": hat}
	for i in toks.size():
		if hits.has(toks[i]):
			_mix(out, hits[toks[i]], int(round(i * step_dur * SoundSynth.MIX_RATE)))
		if drive and i < toks.size() - 1:
			_mix(out, ghost, int(round((i + 0.5) * step_dur * SoundSynth.MIX_RATE)))

static func _mix(out: PackedFloat32Array, hit: PackedFloat32Array, start: int) -> void:
	var count := mini(hit.size(), out.size() - start)
	for k in count:
		out[start + k] += hit[k]

## The whole song as a seamless loop (every note is released before the loop point), soft-clipped
## so the layers glue together and never exceed full scale.
static func render(s: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(loop_samples(s))
	var sd := step_duration(s.bpm)
	var drive: bool = s.get("drive", false)
	var calliope: bool = s.get("lead_wave", "") == "calliope"
	var lead_wave := _table(CALLIOPE_WAVE if calliope else LEAD_WAVE)
	var bass_wave := _table(BASS_WAVE)
	_render_voice(out, s.lead, sd, lead_wave, LEAD_VOLUME, 0.9 if calliope else 0.65, true)
	_render_voice(out, s.bass, sd, bass_wave, BASS_VOLUME, 0.45, false)
	if drive:
		_render_chugs(out, s.bass, sd, bass_wave)
	_render_drums(out, s.drums, sd, drive)
	for i in out.size():
		out[i] = tanh(out[i] * 1.3)
	return out
