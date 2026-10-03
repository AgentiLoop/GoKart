extends RefCounted
## A time-trial ghost (pure): the player's pose sampled at a fixed rate from GO to the finish
## line, replayed by interpolating between samples. Mario Kart 64 keeps the best run of a track
## as a see-through ghost that drives the exact same path on the next attempt.

const INTERVAL := 1.0 / 30.0

var interval := INTERVAL
var positions := PackedVector3Array()
var headings := PackedFloat32Array()
var _since_sample := 0.0

func _init(sample_interval := INTERVAL) -> void:
	interval = sample_interval

func count() -> int:
	return positions.size()

## Seconds the replay runs for (0 with fewer than two samples).
func duration() -> float:
	return maxf(positions.size() - 1, 0) * interval

## Feed one physics step. The first call stores the start pose; after that one sample is kept
## per `interval` of elapsed time.
func add(delta: float, pos: Vector3, heading: float) -> void:
	if positions.is_empty():
		positions.append(pos)
		headings.append(heading)
		_since_sample = 0.0
		return
	_since_sample += delta
	while _since_sample >= interval - 1e-4:
		_since_sample -= interval
		positions.append(pos)
		headings.append(heading)

## Store the final pose (the line crossing) regardless of the sample clock.
func finish(pos: Vector3, heading: float) -> void:
	positions.append(pos)
	headings.append(heading)

## Pose at replay time t: {position, heading, done}; done once the last sample is reached.
## Empty when nothing was recorded.
func pose_at(t: float) -> Dictionary:
	if positions.is_empty():
		return {}
	var f := maxf(t, 0.0) / interval
	var i := int(floor(f))
	if i >= positions.size() - 1:
		return {"position": positions[positions.size() - 1], "heading": headings[headings.size() - 1], "done": true}
	var a := f - float(i)
	return {
		"position": positions[i].lerp(positions[i + 1], a),
		"heading": lerp_angle(headings[i], headings[i + 1], a),
		"done": false,
	}

func to_dict() -> Dictionary:
	return {"interval": interval, "positions": positions, "headings": headings}

static func from_dict(d: Dictionary):
	var g = load("res://scripts/ghost_recording.gd").new(float(d.get("interval", INTERVAL)))
	g.positions = PackedVector3Array(d.get("positions", PackedVector3Array()))
	g.headings = PackedFloat32Array(d.get("headings", PackedFloat32Array()))
	return g
