extends SceneTree
## Windowed: godot --path . -s tools/pause_shot.gd
## -> /tmp/gokart_pause.png (the race frozen under the pause panel, Green Hills, 1 s after Esc) and
##    /tmp/gokart_pause_pop.png (the first frame of the pop, the panel still small).
## Mario Kart 64's pause screen: the panel's region is pixel-sampled for gold (the PAUSE sign, the
## lit CONTINUE line), cream (the other lines) and pure black (there must be none); the frozen race
## is checked by comparing two shots a second apart — all but identical outside the panel.
var f := 0
var t0 := 0
var ok := true
var before: Image

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	change_scene_to_file("res://scenes/menu.tscn")

func _shot(n: String) -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/gokart_%s.png" % n)
	return img

## Window pixels of a Control's rect.
func _pixels(c: Control) -> Rect2i:
	var r: Rect2 = root.get_final_transform() * c.get_global_rect()
	return Rect2i(r.position.round(), r.size.round())

## Counts gold, cream and pure black pixels in `rect`.
static func sample(img: Image, rect: Rect2i) -> Dictionary:
	var cream := 0
	var gold := 0
	var black := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if c.r > 0.85 and c.g > 0.85 and c.b > 0.8:
				cream += 1
			elif c.r > 0.85 and c.g > 0.7 and c.b < 0.5:
				gold += 1
			if c.r < 0.06 and c.g < 0.06 and c.b < 0.06:
				black += 1
	return {"cream": cream, "gold": gold, "black": black}

## Pixels that differ between two frames, outside `skip`.
static func changed(a: Image, b: Image, skip: Rect2i) -> Array:
	var out: Array = []
	for y in range(0, a.get_height(), 4):
		for x in range(0, a.get_width(), 4):
			if skip.has_point(Vector2i(x, y)):
				continue
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				out.append(Vector2i(x, y))
	return out

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	ok = ok and cond

func _process(_d: float) -> bool:
	f += 1
	var cs := current_scene
	if cs == null:
		return false
	if f == 20:
		cs.dismiss_title()
	elif f == 60:
		cs.start_race()
	elif f > 60 and cs.name == "Main" and t0 == 0:
		t0 = f
	elif t0 > 0 and f == t0 + 2:
		cs._end_intro()
		Input.action_press("accelerate")
	elif t0 > 0 and f == t0 + 300:
		# five seconds in: racing; Esc, then the first frame of the pop
		cs.pause.open()
	elif t0 > 0 and f == t0 + 301:
		var img := _shot("pause_pop")
		_check(cs.pause.panel.scale.x < 0.95, "first frame: the panel is still small (%.2f)" % cs.pause.panel.scale.x)
		var s := sample(img, _pixels(cs.pause.panel))
		print("pop frame panel region: cream %d gold %d black %d" % [s.cream, s.gold, s.black])
	elif t0 > 0 and f == t0 + 330:
		before = root.get_viewport().get_texture().get_image()
	elif t0 > 0 and f == t0 + 390:
		var img := _shot("pause")
		var rect := _pixels(cs.pause.panel)
		var s := sample(img, rect)
		_check(s.gold > 300 and s.cream > 300 and s.black == 0, "panel region: gold %d cream %d black %d" % [s.gold, s.cream, s.black])
		var outside := sample(img, Rect2i(rect.position.x - rect.size.x, rect.position.y, rect.size.x - 20, rect.size.y))
		_check(outside.gold + outside.cream < s.gold + s.cream and outside.black == 0, "left of the panel: gold %d cream %d black %d (the dimmed race, no black)" % [outside.gold, outside.cream, outside.black])
		var moved := changed(before, img, rect.grow(24))
		# a running race changes most of the frame in a second; a handful of samples is render noise
		_check(moved.size() < 20, "the race is frozen: %d sampled pixels changed outside the panel over a second %s" % [moved.size(), str(moved.slice(0, 8))])
		_check(is_equal_approx(cs.pause.panel.scale.x, 1.0), "the panel has landed")
		Input.action_release("accelerate")
		print("PAUSE SHOT: ", "OK" if ok else "FAILED")
		quit(0 if ok else 1)
	return false
