extends SceneTree
## Two-or-more-process online smoke test (not part of run_tests.sh — needs a lobby server):
##   GOKART_LOBBY=ws://localhost:8787/api/mp godot --headless --path . -s tests/net_smoke.gd -- --name=A &
##   GOKART_LOBBY=ws://localhost:8787/api/mp godot --headless --path . -s tests/net_smoke.gd -- --name=B
## Each process quick-matches, builds the WebRTC mesh, sends a packet to every peer over it and
## exits 0 once it has heard from all of them.

var net: Node
var heard := {}
var clock := 0.0
var player := "Smoke"
var want := 2 # host starts as soon as this many players are in the room
var sent := false

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
	net.room_updated.connect(_on_room)
	net.failed.connect(func(m): print(player, ": FAILED ", m); quit(1))
	net.match_started.connect(func(info): print(player, ": start as #", info.you, " with ", info.players))
	net.mesh_ready.connect(_on_mesh_ready)
	get_multiplayer().peer_packet.connect(_on_packet)
	net.quick_match.call_deferred(player)

func _on_room(code: String, players: Array, host: int, countdown: int) -> void:
	print(player, ": room ", code, " ", players.size(), " players, host ", host, ", countdown ", countdown)
	if host == net.my_id and players.size() >= want:
		net.start_now()

func _on_mesh_ready() -> void:
	print(player, ": mesh ready, peers ", get_multiplayer().get_peers())
	get_multiplayer().send_bytes(("hi from " + player).to_utf8_buffer(), 0, MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	sent = true
	_check_done()

func _on_packet(id: int, data: PackedByteArray) -> void:
	heard[id] = true
	print(player, ": got '", data.get_string_from_utf8(), "' from #", id, " (", net.names.get(id, "?"), ")")
	_check_done()

func _check_done() -> void:
	if sent and heard.size() == net.names.size() - 1:
		print(player, ": OK")
		await create_timer(1.0).timeout # let our own packets flush
		quit(0)

func _process(delta: float) -> bool:
	clock += delta
	if clock > 60.0:
		print(player, ": TIMEOUT")
		quit(2)
	return false
