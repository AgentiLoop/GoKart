extends SceneTree
## Headless check of the Mario Kart 64 slipstream in a real race scene:
##   perl -e 'alarm 120; exec @ARGV' godot --headless --path . -s tools/draft_check.gd
## After GO every kart is parked out of the way except a leader (kart 1) and the player, who is
## handed to an autopilot in the leader's lane. Run A: the player starts 6 m behind the slightly
## faster leader, sits in its wake and after ~2 s gets the draft burst (model flag, speed over its
## top speed, "draft" sound, grey wind emitting); the leader never drafts. Run B: the player runs
## a lane 5 m to the side for 6 s and never drafts.

const AiDriver := preload("res://scripts/ai_driver.gd")
const Slipstream := preload("res://scripts/slipstream.gd")

var main
var stage := 0
var frames := 0
var wait := 0
var ok := true
var run := "A"
var player_bursts := 0
var leader_bursts := 0
var peak_speed := 0.0
var wind_seen := false
var drafted_frames := 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + "[%s] %s" % [run, msg])
	if not cond:
		ok = false

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

## Park kart i on track sample idx, `lane` m right of the centre line, facing along the road, rolling at `speed`.
func _park(i: int, idx: int, lane := 0.0, speed := 0.0) -> void:
	var k = main.karts[i]
	var t = main.items.track
	k.frozen = true
	k.model.stop()
	k.model.draft_time = 0.0
	k.rescue_time = -1.0
	k.push = Vector3.ZERO
	k.global_position = t.points[idx] + t.right_of(idx) * lane + Vector3(0, 0.1, 0)
	k.track_index = idx
	k.heading = t.heading_at(idx)
	k.rotation.y = k.heading
	k.model.speed = speed

func _setup_run() -> void:
	wait = 0
	player_bursts = 0
	leader_bursts = 0
	peak_speed = 0.0
	wind_seen = false
	drafted_frames = 0
	var data = main.track.data
	for i in main.karts.size():
		_park(i, (int(data.count * 0.5) + i * 4) % data.count)   # the rest of the field half a lap away
	var leader = main.karts[1]
	var player = main.karts[0]
	var player_lane := 0.0 if run == "A" else 4.0
	var leader_lane := 0.0 if run == "A" else -1.0
	# just past the last pad (0.9 of the lap), already rolling, down the start straight: the next pad is
	# 135 m on, so no pad boost can mask the burst
	var start: int = data.count - 20
	_park(1, start + 2, leader_lane, 20.0)
	_park(0, start, player_lane, 20.0)   # 6 m behind
	leader.driver.lane_offset = leader_lane
	leader.driver.dodging = false
	player.driver = AiDriver.new(data, player_lane, 999.0)
	# the leader is a touch faster than the player, so the player cannot catch it on its own and sits in
	# its wake (a faster follower would just ram it)
	main.ai_base_speed[0] = player.model.max_speed * 1.02
	leader.frozen = false
	player.frozen = false

func _finish_run() -> void:
	var player = main.karts[0]
	match run:
		"A":
			_check(drafted_frames > 60, "the player sat in the leader's wake (%d frames)" % drafted_frames)
			_check(player_bursts >= 1, "the draft burst fired for the player (%d)" % player_bursts)
			var top: float = player.model.max_speed
			_check(peak_speed > top + 1.0 and peak_speed <= top * player.model.draft_speed_factor + 0.5, "the burst took the player over its top speed, by the draft factor at most (%.1f vs %.1f)" % [peak_speed, top])
			_check("draft" in main.audio.played, "the draft whoosh played")
			_check(wind_seen, "the grey wind streaks were emitting during the burst")
			_check(leader_bursts == 0, "the leader never drafted")
		"B":
			_check(drafted_frames == 0, "a lane to the side is not in the wake (%d frames)" % drafted_frames)
			_check(player_bursts == 0, "no burst out of the wake")

func _physics_process(_d: float) -> bool:
	frames += 1
	var rs = main.race_start
	if stage == 0:
		if rs.started:
			stage = 1
			main.karts[0].model.draft_started.connect(func(): player_bursts += 1)
			main.karts[1].model.draft_started.connect(func(): leader_bursts += 1)
			_setup_run()
	elif stage == 1:
		wait += 1
		var player = main.karts[0]
		if player.model.is_drafting():
			drafted_frames += 1
		if player.model.is_draft_boosting():
			if not player.model.is_boosting():   # a pad / mushroom boost would mask the burst's own speed
				peak_speed = maxf(peak_speed, player.model.speed)
			if player.effects.wind[0].emitting:
				wind_seen = true
		var done: bool = (run == "A" and player_bursts >= 1 and wait > 30 and not player.model.is_draft_boosting()) or wait > 600
		if run == "B":
			done = wait > 360
		if done:
			_finish_run()
			if run == "A":
				run = "B"
				_setup_run()
			else:
				print("DRAFT CHECK: " + ("OK" if ok else "FAILED"))
				quit(0 if ok else 1)
				return true
	if frames > 2000:
		print("FAIL [%s] timed out at stage %d" % [run, stage])
		quit(1)
		return true
	return false
