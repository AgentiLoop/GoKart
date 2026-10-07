extends SceneTree
## ONLINE screen smoke test (run through tests/lobby_smoke.sh): each process opens
## scenes/online.tscn, types its name and presses QUICK MATCH; the host presses START NOW once the
## lobby lists everyone. Passes when the screen hands over to the race scene in online mode.

var player := "Smoke"
var want := 2
var clock := 0.0
var pressed := false
var started := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			player = a.substr(7)
		elif a.begins_with("--players="):
			want = int(a.substr(10))
	if root.get_node_or_null("Net") == null:
		var net: Node = load("res://scripts/net.gd").new()
		net.name = "Net"
		root.add_child(net)
	change_scene_to_file.call_deferred("res://scenes/online.tscn")

func _process(delta: float) -> bool:
	clock += delta
	if clock > 60.0:
		print(player, ": TIMEOUT")
		quit(2)
	var scene := current_scene
	if scene == null:
		return false
	if scene.get("online") == true:
		print(player, ": race scene loaded online with ", scene.racer_names)
		print(player, ": OK")
		quit(0)
		return false
	if scene.has_method("_quick_match"):
		if not pressed:
			pressed = true
			scene.name_edit.text = player
			scene.quick_button.pressed.emit()
			print(player, ": pressed QUICK MATCH")
		elif not started and scene.start_button.visible and scene.players_label.text.split("\n").size() >= want:
			started = true
			print(player, ": lobby\n", scene.players_label.text, "\n", scene.countdown_label.text)
			scene.start_button.pressed.emit()
	return false
