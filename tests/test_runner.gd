extends SceneTree
## Run: godot --headless --path . -s tests/test_runner.gd
## Discovers every tests/test_*.gd (excluding this file) and runs methods named test_*.

var passed := 0
var failed := 0
var current := ""

func _initialize() -> void:
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_runner.gd":
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		var t = script.new()
		t.runner = self
		for m in t.get_method_list():
			if String(m.name).begins_with("test_"):
				current = "%s::%s" % [f, m.name]
				t.call(m.name)
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(cond: bool, msg: String = "") -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL %s %s" % [current, msg])
