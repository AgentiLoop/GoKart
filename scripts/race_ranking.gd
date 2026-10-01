extends RefCounted
## Race positions (pure). Progress is laps * samples + track sample index (+ a fractional
## part so karts in the same sample are ordered). Finished racers rank by finish time.

static func progress(lap: int, idx: int, count: int, frac := 0.0) -> float:
	return float(lap * count + idx) + clampf(frac, -0.5, 0.5)

## Racer indices ordered first to last. finish_time < 0 means not finished yet.
static func order(progresses: Array, finish_times: Array) -> Array:
	var ids: Array = []
	for i in progresses.size():
		ids.append(i)
	ids.sort_custom(func(a, b):
		var fa: float = finish_times[a]
		var fb: float = finish_times[b]
		if fa >= 0.0 and fb >= 0.0:
			return fa < fb
		if fa >= 0.0:
			return true
		if fb >= 0.0:
			return false
		return progresses[a] > progresses[b])
	return ids

## 1-based position of racer i.
static func rank_of(i: int, progresses: Array, finish_times: Array) -> int:
	return order(progresses, finish_times).find(i) + 1

static func ordinal(rank: int) -> String:
	if rank % 100 >= 11 and rank % 100 <= 13:
		return "%dth" % rank
	match rank % 10:
		1: return "%dst" % rank
		2: return "%dnd" % rank
		3: return "%drd" % rank
	return "%dth" % rank
