extends SceneTree
## Windowed: godot --path . -s tools/map_shot.gd
## -> /tmp/gokart_map_menu.png (the select screen with the course map over the picture's corner) and
##    /tmp/gokart_map_race.png (the race HUD's minimap, bottom-left, Green Hills).
## Mario Kart 64's course map is one light colour laid straight over the scene: both map regions
## are pixel-sampled for the cream route and the gold start tick / player ring, and for pure black
## (the old box and rim) — of which there must be none.
var f := 0
var t0 := 0
var ok := true

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

## Counts cream (route), gold (start tick / player ring) and pure black pixels in `rect`.
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

func _judge(name: String, s: Dictionary) -> void:
	var pass_: bool = s.cream > 60 and s.gold > 8 and s.black == 0
	ok = ok and pass_
	print("%s %s map: cream %d gold %d black %d" % ["PASS" if pass_ else "FAIL", name, s.cream, s.gold, s.black])

func _process(_d: float) -> bool:
	f += 1
	var cs := current_scene
	if cs == null:
		return false
	if f == 20:
		cs.dismiss_title()
	elif f == 75:
		var img := _shot("map_menu")
		_judge("select-screen", sample(img, _pixels(cs.preview)))
	elif f == 80:
		cs.start_race()
	elif f > 80 and cs.name == "Main" and t0 == 0:
		t0 = f
	elif t0 > 0 and f == t0 + 2:
		cs._end_intro()
	elif t0 > 0 and f == t0 + 90:
		var img := _shot("map_race")
		_judge("race HUD", sample(img, _pixels(cs.hud.minimap)))
		print("MAP SHOT: ", "OK" if ok else "FAILED")
		quit(0)
	return false
