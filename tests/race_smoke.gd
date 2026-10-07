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

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			player = a.substr(7)
		elif a.begins_with("--players="):
			want = int(a.substr(10))
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
	if clock > 80.0:
		print(player, ": TIMEOUT")
		quit(2)
	var scene := current_scene
	if race == null and scene != null and scene.get("online") == true:
		race = scene
		names = net.names.duplicate()
		print(player, ": race on ", race._track_name(), " with ", race.racer_names)
	if ok_at >= 0.0:
		if clock - ok_at > 4.0:
			quit(0)
		return false
	if race == null or not race.race_start.started:
		return false
	if starts.is_empty():
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
