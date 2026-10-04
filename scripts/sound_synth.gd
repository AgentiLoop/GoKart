extends RefCounted
## Procedural sound effects: all samples are synthesized from code (no audio assets).
## Pure helpers return PackedFloat32Array sample buffers in [-1, 1]; to_wav() wraps one in an AudioStreamWAV.

const MIX_RATE := 22050
const ENGINE_BASE_HZ := 55.0
const ENGINE_LOOP_CYCLES := 22   # whole cycles -> the loop point is seamless

static func sample_count(duration: float) -> int:
	return maxi(int(round(duration * MIX_RATE)), 1)

## Wrap float samples as a mono 16-bit AudioStreamWAV, optionally looping end to end.
static func to_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

## Peak absolute amplitude of a buffer.
static func peak(samples: PackedFloat32Array) -> float:
	var m := 0.0
	for s in samples:
		m = maxf(m, absf(s))
	return m

## Fast attack, exponential decay envelope value at t of duration.
static func envelope(t: float, duration: float, attack := 0.01) -> float:
	if t < 0.0 or t >= duration:
		return 0.0
	var a := minf(t / attack, 1.0)
	var d := 1.0 - t / duration
	return a * d * d

## Pitched tone sweeping from f0 to f1 (square-ish: sine plus odd harmonics).
static func sweep(f0: float, f1: float, duration: float, volume := 0.5) -> PackedFloat32Array:
	var n := sample_count(duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var f := lerpf(f0, f1, float(i) / n)
		phase += TAU * f / MIX_RATE
		var s := sin(phase) + sin(phase * 3.0) / 3.0 + sin(phase * 5.0) / 5.0
		out[i] = s * 0.75 * volume * envelope(t, duration)
	return out

static func tone(freq: float, duration: float, volume := 0.5) -> PackedFloat32Array:
	return sweep(freq, freq, duration, volume)

## Notes played back to back (a rising arpeggio for item pickups etc.).
static func arpeggio(freqs: Array, note_duration: float, volume := 0.5) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out.append_array(tone(f, note_duration, volume))
	return out

## Decaying noise burst; smoothing 0 = white, towards 1 = darker (low-passed).
static func noise_burst(duration: float, smoothing := 0.5, volume := 0.5, seed_value := 1) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := sample_count(duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		lp = lerpf(rng.randf_range(-1.0, 1.0), lp, smoothing)
		out[i] = lp * volume * envelope(float(i) / MIX_RATE, duration, 0.02) * (1.0 + smoothing)
	return out

## Seamless looping noise (tire screech); constant level with a cross-faded loop point.
static func screech_loop(duration := 0.5, volume := 0.3) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := sample_count(duration)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		lp = lerpf(x, lp, 0.35)
		hp = lp - lerpf(hp, lp, 0.1)
		out[i] = hp * volume
	var fade := n / 8
	for i in fade:   # blend the tail into the head so the loop has no click
		var w := float(i) / fade
		out[n - fade + i] = lerpf(out[n - fade + i], out[i], w)
	return out

## Seamless engine loop: sawtooth + harmonics with a slight wobble, whole cycles per loop.
static func engine_loop(volume := 0.35) -> PackedFloat32Array:
	var duration := ENGINE_LOOP_CYCLES / ENGINE_BASE_HZ
	var n := sample_count(duration)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var ph := float(i) / n * ENGINE_LOOP_CYCLES   # cycles elapsed
		var saw := 2.0 * (ph - floorf(ph + 0.5))
		var s := saw * 0.6 + sin(TAU * ph * 2.0) * 0.3 + sin(TAU * ph * 0.5) * 0.1
		out[i] = s * volume
	return out

## Engine pitch_scale for a speed ratio (0..1 of max speed); boosting revs higher.
static func engine_pitch(speed_ratio: float, boosting := false) -> float:
	var r := clampf(absf(speed_ratio), 0.0, 1.4)
	return 0.8 + 1.6 * r + (0.35 if boosting else 0.0)

## Countdown tick: returns the new ceil(remaining) when it dropped below last_ceil, else -1.
static func countdown_tick(last_ceil: int, remaining: float) -> int:
	var c := int(ceil(remaining))
	return c if c < last_ceil else -1

## Beep sample for a countdown value (3, 2, 1 low; 0 = GO high and longer).
static func countdown_beep(value: int) -> PackedFloat32Array:
	if value <= 0:
		return tone(880.0, 0.6, 0.55)
	return tone(440.0, 0.18, 0.5)

## Every named one-shot effect: name -> PackedFloat32Array.
static func effect_library() -> Dictionary:
	return {
		"beep": countdown_beep(3),
		"go": countdown_beep(0),
		"boost": noise_burst(0.7, 0.55, 0.7, 3),
		"drift_start": sweep(260.0, 560.0, 0.12, 0.4),   # the hop that starts a powerslide
		"mini_turbo": arpeggio([660.0, 880.0], 0.07, 0.45),
		"pickup": arpeggio([523.0, 659.0, 784.0, 1047.0], 0.06, 0.45),
		"item_ready": arpeggio([784.0, 1047.0], 0.09, 0.5),
		"hit": sweep(500.0, 90.0, 0.55, 0.65),
		"explosion": noise_burst(0.8, 0.8, 1.0, 11),
		"lightning": noise_burst(0.5, 0.05, 0.8, 13),
		"star": arpeggio([784.0, 988.0, 1175.0, 1568.0, 1175.0, 988.0], 0.07, 0.4),
		"boo": sweep(520.0, 180.0, 0.7, 0.4),
		"throw": sweep(300.0, 700.0, 0.15, 0.4),
		"splash": noise_burst(0.5, 0.75, 0.7, 17),
		"pop": noise_burst(0.12, 0.1, 0.8, 19),
		"burnout": noise_burst(1.5, 0.12, 0.45, 23),
		"block": sweep(1600.0, 700.0, 0.16, 0.5),
		"bell": arpeggio([1480.0, 1480.0], 0.11, 0.35),
		"crash": noise_burst(0.7, 0.65, 0.9, 29),
		"finish": arpeggio([523.0, 659.0, 784.0, 659.0, 784.0, 1047.0], 0.12, 0.5),   # MK64: the 1st-place fanfare
		"finish_ok": arpeggio([659.0, 784.0, 659.0, 784.0, 880.0], 0.12, 0.5),          # 2nd - 4th
		"finish_out": arpeggio([659.0, 587.0, 523.0, 494.0, 440.0], 0.18, 0.45),        # 5th or worse: a sagging fanfare
		"final_lap": arpeggio([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0], 0.075, 0.5),   # MK64 "Final Lap!" jingle
		"cursor": sweep(1400.0, 1900.0, 0.05, 0.35),      # menu: the cursor moves to another course
		"option": sweep(900.0, 1300.0, 0.06, 0.35),       # menu: an option / the mode changes
		"confirm": arpeggio([1047.0, 1319.0, 1568.0, 2093.0], 0.08, 0.45),   # menu: Enter (leave the title, start the race)
	}
