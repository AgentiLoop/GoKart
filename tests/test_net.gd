extends RefCounted
var runner

const Net := preload("res://scripts/net.gd")

func test_clean_name() -> void:
	runner.check(Net.clean_name("  Mario  ") == "Mario", "trims")
	runner.check(Net.clean_name("") == "Player", "empty -> Player")
	runner.check(Net.clean_name("a\tb\nc") == "abc", "control chars dropped")
	runner.check(Net.clean_name("ABCDEFGHIJKLMNOPQRST").length() == Net.NAME_MAX, "capped")

func test_names_of() -> void:
	var d: Dictionary = Net._names_of([{"id": 2.0, "name": "Bob"}, {"id": 1.0, "name": "Ann"}])
	runner.check(d.get(1) == "Ann" and d.get(2) == "Bob", "ids become ints")

func test_webrtc_available() -> void:
	var pc := WebRTCPeerConnection.new()
	runner.check(pc.initialize({"iceServers": Net.ICE_SERVERS}) == OK, "webrtc-native extension loaded")
