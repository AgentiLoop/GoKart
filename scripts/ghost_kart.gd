extends Node3D
## See-through replay of a time-trial GhostRecording (Mario Kart 64 ghost): a plain kart model
## with no physics body, so it is untouchable and passes through karts and items.
## Positions are local, so parent the ghost to an untransformed node (the race scene root).

const KartModel := preload("res://scripts/kart_model.gd")

const ALPHA := 0.4
const COLOR := Color(0.85, 0.9, 1.0)

var recording   # GhostRecording
var model: Node3D
var time := 0.0
var heading := 0.0
var done := false

func _init() -> void:
	model = KartModel.new()
	add_child(model)
	model.build(COLOR)
	model.set_opacity(ALPHA)

## Attach the recording and park the ghost at its start pose.
func setup(rec) -> void:
	recording = rec
	time = 0.0
	done = false
	if recording == null:
		return
	var p: Dictionary = recording.pose_at(0.0)
	if not p.is_empty():
		position = p.position
		heading = p.heading
		rotation.y = heading

## Advance the replay by one physics step (call from GO onward).
func update_ghost(delta: float) -> void:
	if recording == null:
		return
	time += delta
	var p: Dictionary = recording.pose_at(time)
	if p.is_empty():
		return
	var speed: float = 0.0 if done else (p.position - position).length() / maxf(delta, 1e-6)
	position = p.position
	heading = p.heading
	rotation.y = heading
	done = p.done
	model.update_wheels(delta, speed, 0.0)
