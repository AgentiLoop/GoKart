extends RefCounted
## Pure lap/checkpoint logic driven by the kart's nearest track-sample index.
## Checkpoint 0 is the start/finish line; checkpoints must be passed in order.

signal checkpoint_passed(k: int)
signal lap_completed(lap: int, time: float)
signal finished

var total_laps := 3
var checkpoint_count := 8
var sample_count := 200
var next_cp := 0
var lap := 0            # 0 = before the start line, 1..total_laps while racing
var lap_time := 0.0
var race_time := 0.0
var lap_times: Array[float] = []
var is_finished := false

func _init(samples: int = 200, checkpoints: int = 8, laps: int = 3) -> void:
	sample_count = samples
	checkpoint_count = checkpoints
	total_laps = laps

func cp_index(k: int) -> int:
	return k * sample_count / checkpoint_count

func update(delta: float, idx: int) -> void:
	if is_finished:
		return
	if lap > 0:
		lap_time += delta
		race_time += delta
	var window := sample_count / checkpoint_count
	if posmod(idx - cp_index(next_cp), sample_count) < window:
		_pass()

func _pass() -> void:
	var k := next_cp
	next_cp = (k + 1) % checkpoint_count
	checkpoint_passed.emit(k)
	if k != 0:
		return
	if lap > 0:
		lap_times.append(lap_time)
		lap_completed.emit(lap, lap_time)
		if lap >= total_laps:
			is_finished = true
			finished.emit()
			return
	lap += 1
	lap_time = 0.0

func best_lap() -> float:
	if lap_times.is_empty():
		return 0.0
	return lap_times.min()
