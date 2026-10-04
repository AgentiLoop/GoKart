extends SceneTree
## Windowed: godot --path . -s tools/intro_shot.gd
## -> /tmp/gokart_intro.png: the Mario Kart 64 style course intro 1.2 s in (the fly-over of
##    Green Hills under the name card), /tmp/gokart_intro_cut2.png: the second cut.
## The card region is pixel-sampled: gold / cream text over the picture; the only near-black pixels
## are the text's drop shadow where it falls on a dark part of the scene (far fewer than the gold).
var f := 0
var t0 := 0

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	change_scene_to_file("res://scenes/menu.tscn")

func _shot(n: String) -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/gokart_%s.png" % n)
	return img

## Counts pixels in `rect` that are light (a text pixel: gold / cream) and that are near black.
static func sample(img: Image, rect: Rect2i) -> Dictionary:
	var light := 0
	var black := 0
	var gold := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := img.get_pixel(x, y)
			if c.r > 0.85 and c.g > 0.7 and c.b < 0.5:
				gold += 1
			if c.r > 0.85 and c.g > 0.85 and c.b > 0.8:
				light += 1
			if c.r < 0.08 and c.g < 0.08 and c.b < 0.08:
				black += 1
	return {"gold": gold, "light": light, "black": black}

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
	elif t0 > 0 and f == t0 + 72:
		var img := _shot("intro")
		var h := img.get_height()
		# the card sits INTRO_INSET from the bottom-left corner: name sign in the lower part
		var card := Rect2i(56, h - 72 - 119, 520, 119)
		var s := sample(img, card)
		var beside := sample(img, Rect2i(640, h - 72 - 119, 520, 119))
		print("intro shot: t=%.2f card gold %d light %d black %d | beside gold %d" % [cs.intro_t, s.gold, s.light, s.black, beside.gold])
		print("INTRO SHOT: ", "OK" if s.gold > 400 and s.light > 100 and s.black < s.gold / 2 and beside.gold < s.gold / 4 else "FAILED")
	elif t0 > 0 and f == t0 + 150:
		_shot("intro_cut2")
		print("saved /tmp/gokart_intro_cut2.png (t=%.2f)" % cs.intro_t)
		quit(0)
	return false
