extends Node
## Online multiplayer (autoload "Net"). gokart.games only does matchmaking and relays the WebRTC
## handshake (SDP offer/answer + ICE candidates) over a WebSocket; the race itself runs over a
## WebRTC full mesh (WebRTCMultiplayerPeer.create_mesh), so every kart talks directly to every
## other kart. Desktop builds get WebRTC from the webrtc-native GDExtension in addons/.
##
## Flow: quick_match()/join_room() -> "room" updates (room_updated) -> server "start" ->
## build mesh (match_started) -> all data channels open (mesh_ready) -> race.
## The lowest id in the room is the host: it decides anything that must agree (start time).

signal room_updated(code: String, players: Array, host: int, countdown: int)
signal match_started(info: Dictionary)
signal mesh_ready
signal peer_left(id: int)
signal failed(message: String)

enum State { IDLE, CONNECTING, LOBBY, SIGNALING, RACING }

const DEFAULT_LOBBY := "wss://gokart.games/api/mp"
const ICE_SERVERS := [
	{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]},
	{"urls": ["stun:stun.cloudflare.com:3478"]},
]
const MESH_TIMEOUT := 25.0
const NAME_MAX := 16

var state := State.IDLE
var lobby_url := DEFAULT_LOBBY
var my_id := 0
var host_id := 0
var room_code := ""
var names := {} # peer id -> display name (includes my_id)
var match_info := {} # the server's "start" message
var _ws: WebSocketPeer
var _hello := {}
var _rtc: WebRTCMultiplayerPeer
var _mesh_clock := 0.0

func _ready() -> void:
	var env := OS.get_environment("GOKART_LOBBY")
	if env != "":
		lobby_url = env
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lobby="):
			lobby_url = a.substr(8)
		elif a.begins_with("--smoke=res://tests/"):
			_run_smoke.call_deferred(a.substr(8))
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

## Exported games ignore Godot's -s, so `GoKart -- --smoke=res://tests/race_smoke.gd ...` runs a
## SceneTree smoke test shipped in the pack as the main loop (tests/export_smoke.sh).
func _run_smoke(path: String) -> void:
	var tree := get_tree()
	tree.set_script(load(path))
	tree.call("_initialize")

static func clean_name(s: String) -> String:
	var out := ""
	for ch in s.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127:
			out += ch
	out = out.strip_edges().left(NAME_MAX)
	return out if out != "" else "Player"

func is_online() -> bool:
	return state == State.RACING or state == State.SIGNALING

func quick_match(player_name: String, course := "") -> void:
	_connect({"t": "hello", "name": clean_name(player_name), "course": course})

func join_room(code: String, player_name: String, create := false, course := "") -> void:
	_connect({"t": "hello", "name": clean_name(player_name), "course": course, "room": code.to_upper(), "create": create})

## Host only: start before the auto-start countdown ends (needs 2+ players).
func start_now() -> void:
	_send({"t": "start"})

func leave() -> void:
	if _ws:
		_ws.close()
	_ws = null
	if _rtc:
		_rtc.close()
	_rtc = null
	if multiplayer.multiplayer_peer is WebRTCMultiplayerPeer:
		multiplayer.multiplayer_peer = null
	state = State.IDLE
	my_id = 0
	host_id = 0
	room_code = ""
	names = {}
	match_info = {}

func _connect(hello: Dictionary) -> void:
	leave()
	hello["version"] = str(ProjectSettings.get_setting("application/config/version", ""))
	_hello = hello
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(lobby_url)
	if err != OK:
		_fail("Can't reach %s (error %d)." % [lobby_url, err])
		return
	state = State.CONNECTING

func _send(msg: Dictionary) -> void:
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))

func _fail(message: String) -> void:
	leave()
	failed.emit(message)

func _process(delta: float) -> void:
	if _ws:
		_poll_lobby()
	if state == State.SIGNALING:
		_mesh_clock += delta
		if _all_connected():
			state = State.RACING
			if _ws:
				_ws.close() # signaling done: from here on it's peer-to-peer only
				_ws = null
			mesh_ready.emit()
		elif _mesh_clock > MESH_TIMEOUT:
			_fail("Couldn't connect to the other players (firewall or strict NAT).")

func _poll_lobby() -> void:
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if state == State.CONNECTING:
				state = State.LOBBY
				_send(_hello)
			while _ws and _ws.get_available_packet_count() > 0:
				var msg = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
				if msg is Dictionary:
					_on_lobby_message(msg)
		WebSocketPeer.STATE_CLOSED:
			_ws = null
			if state == State.CONNECTING or state == State.LOBBY:
				_fail("Lost connection to gokart.games.")

func _on_lobby_message(msg: Dictionary) -> void:
	match str(msg.get("t", "")):
		"room":
			my_id = int(msg.you)
			host_id = int(msg.host)
			room_code = str(msg.code)
			names = _names_of(msg.players)
			room_updated.emit(room_code, msg.players, host_id, int(msg.countdown))
		"start":
			match_info = msg
			my_id = int(msg.you)
			names = _names_of(msg.players)
			host_id = names.keys().min()
			_build_mesh()
			match_started.emit(msg)
		"sig":
			_on_signal(int(msg.from), msg.data)
		"left":
			pass # lobby leavers arrive as a "room" update; once racing, WebRTC reports disconnects
		"error":
			_fail(str(msg.message))

static func _names_of(players: Array) -> Dictionary:
	var d := {}
	for p in players:
		d[int(p.id)] = str(p.name)
	return d

func _build_mesh() -> void:
	state = State.SIGNALING
	_mesh_clock = 0.0
	_rtc = WebRTCMultiplayerPeer.new()
	_rtc.create_mesh(my_id)
	for id in names:
		if id == my_id:
			continue
		var pc := WebRTCPeerConnection.new()
		pc.initialize({"iceServers": ICE_SERVERS})
		pc.session_description_created.connect(_on_session.bind(id, pc))
		pc.ice_candidate_created.connect(_on_candidate.bind(id))
		_rtc.add_peer(pc, id)
		if my_id < id: # the lower id makes the offer, the other answers
			pc.create_offer()
	multiplayer.multiplayer_peer = _rtc

func _on_session(type: String, sdp: String, id: int, pc: WebRTCPeerConnection) -> void:
	pc.set_local_description(type, sdp)
	_send({"t": "sig", "to": id, "data": {"type": type, "sdp": sdp}})

func _on_candidate(mid: String, index: int, sdp: String, id: int) -> void:
	_send({"t": "sig", "to": id, "data": {"mid": mid, "index": index, "cand": sdp}})

func _on_signal(from: int, data) -> void:
	if not (data is Dictionary) or _rtc == null or not _rtc.has_peer(from):
		return
	var pc: WebRTCPeerConnection = _rtc.get_peer(from).connection
	if data.has("sdp"):
		pc.set_remote_description(str(data.type), str(data.sdp)) # an offer auto-creates our answer
	elif data.has("cand"):
		pc.add_ice_candidate(str(data.mid), int(data.index), str(data.cand))

func _all_connected() -> bool:
	if _rtc == null:
		return false
	var peers := multiplayer.get_peers()
	for id in names:
		if id != my_id and not peers.has(id):
			return false
	return true

func _on_peer_disconnected(id: int) -> void:
	if not names.has(id) or id == my_id:
		return
	names.erase(id)
	if _rtc and _rtc.has_peer(id):
		_rtc.remove_peer(id)
	if state == State.LOBBY:
		return
	if not names.is_empty():
		host_id = names.keys().min()
	peer_left.emit(id)
