extends SceneTree
## Online race smoke test (needs a lobby; run through tests/race_smoke.sh). Each process
## quick-matches, builds the WebRTC mesh, loads the race scene in online mode and lets an autopilot
## drive its kart from GO. It passes once the countdown started and every other player's kart
## (a puppet fed by their packets) has driven RACE_CHECK_M metres with a name tag over it.

const OnlineRace := preload("res://scripts/online_race.gd")
const AiDriver := preload("res://scripts/ai_driver.gd")
const RACE_CHECK_M := 40.0

var net: Node
var player := "Smoke"
var want := 2
var clock := 0.0
var race: Node = null
var starts := {}   # peer id -> puppet position when the race started
var names := {}    # peer id -> name, kept after a peer leaves
var ok_at := -1.0  # passed: linger so the others can finish their check too
## --finish: also race to the flag and pass once the results board has every player's reported time
var want_finish := false
var fin_at := -1.0
## --leave-at=S: this player quits S seconds after GO (the others must show it as LEFT)
var leave_at := -1.0
var go_at := -1.0
var noticed := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			player = a.substr(7)
		elif a.begins_with("--players="):
			want = int(a.substr(10))
		elif a == "--finish":
			want_finish = true
		elif a.begins_with("--leave-at="):
			leave_at = float(a.substr(11))
	net = root.get_node_or_null("Net")
	if net == null:
		net = load("res://scripts/net.gd").new()
		net.name = "Net"
		root.add_child(net)
	net.room_updated.connect(func(_c, players, host, _cd):
		if host == net.my_id and players.size() >= want:
			net.start_now())
	net.failed.connect(func(m): print(player, ": FAILED ", m); quit(1))
	net.mesh_ready.connect(_on_mesh_ready)
	net.quick_match.call_deferred(player)

func _on_mesh_ready() -> void:
	print(player, ": mesh ready, loading the race")
	OnlineRace.active = true
	change_scene_to_file("res://scenes/main.tscn")

func _process(delta: float) -> bool:
	clock += delta
	if clock > (360.0 if want_finish else 80.0):
		print(player, ": TIMEOUT")
		quit(2)
	var scene := current_scene
	if race == null and scene != null and scene.get("online") == true:
		race = scene
		names = net.names.duplicate()
		print(player, ": race on ", race._track_name(), " with ", race.racer_names)
	if race != null and race.hud != null and race.hud.cup_label.text.contains("left") and not noticed:
		noticed = true
		print(player, ": notice '", race.hud.cup_label.text, "'")
	if leave_at >= 0.0 and go_at >= 0.0 and clock - go_at > leave_at:
		print(player, ": LEAVING")
		net.leave()
		quit(0)
		return false
	if ok_at >= 0.0:
		if want_finish:
			_check_finish()
			return false
		if clock - ok_at > 4.0:
			quit(0)
		return false
	if race == null or not race.race_start.started:
		return false
	if starts.is_empty():
		go_at = clock
		print(player, ": GO")
		race.kart.driver = AiDriver.new(race.track.data, 0.0, 999.0)
		for id in race.peer_karts:
			starts[id] = race.peer_karts[id].global_position
	var done := true
	for id in race.peer_karts:
		var k = race.peer_karts[id]
		var tag_ok := false
		for c in k.get_children():
			tag_ok = tag_ok or (c is Label3D and c.text == names[id])
		done = done and tag_ok and k.global_position.distance_to(starts[id]) > RACE_CHECK_M
	if done:
		for id in race.peer_karts:
			print(player, ": sees ", names[id], " at ", race.peer_karts[id].global_position.snapped(Vector3.ONE * 0.1), " moved ", snappedf(race.peer_karts[id].global_position.distance_to(starts[id]), 0.1), " m")
		print(player, ": OK")
		ok_at = clock
	return false

## The board is complete once nobody is still racing: every row has a finish time.
func _check_finish() -> void:
	if fin_at >= 0.0:
		if clock - fin_at > 4.0:
			quit(0)
		return
	if not race.results_shown or race.hud.results_text.contains("WAITING"):
		return
	for line in race.hud.results_text.split("\n"):
		print(player, ": board ", line)
	print(player, ": FINISH OK")
	fin_at = clock
