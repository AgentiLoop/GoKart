extends SceneTree
## Windowed render check of the 3D sign text (no thick black outlines; rounded font, rim in the board's shade):
##   perl -e 'alarm 60; exec @ARGV' godot --path . -s tools/sign_shot.gd
## Saves /tmp/gokart_sign_banner.png (the start gate's START banner from the grid) and
## /tmp/gokart_sign_reverse.png (Lakitu holding the REVERSE sign in front of the player) and samples
## the text: the text colour and the rim colour are present, old outline colours / black are not.

const Lakitu := preload("res://scripts/lakitu.gd")

var main
var f := 0
var ok := true

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _shot(n: String) -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/gokart_%s.png" % n)
	print("saved /tmp/gokart_%s.png" % n)
	return img

## Rim pixels in `r`: darker than the board (value <= max_v) with the board's dominant channel
## (0 = red, 1 = green) clearly ahead of the other two (the rendered colour is tonemapped, so an exact match is not used).
static func _rim_count(img: Image, r: Rect2i, dominant: int, max_v: float) -> int:
	var n := 0
	for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
			var p := img.get_pixel(x, y)
			var ch := [p.r, p.g, p.b]
			var lead: float = ch[dominant]
			var rest: float = maxf(ch[(dominant + 1) % 3], ch[(dominant + 2) % 3])
			if p.v <= max_v and lead > rest + 0.15:
				n += 1
	return n

## Pixels in `r` within `tol` of `c`.
static func _count(img: Image, r: Rect2i, c: Color, tol := 0.12) -> int:
	var n := 0
	for y in range(maxi(r.position.y, 0), mini(r.end.y, img.get_height())):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, img.get_width())):
			var p := img.get_pixel(x, y)
			if absf(p.r - c.r) < tol and absf(p.g - c.g) < tol and absf(p.b - c.b) < tol:
				n += 1
	return n

func _check(cond: bool, msg: String) -> void:
	print("%s %s" % ["PASS" if cond else "FAIL", msg])
	ok = ok and cond

## Screen rect around a world point: `w` x `h` px centred on it.
func _around(p: Vector3, w: int, h: int) -> Rect2i:
	var s: Vector2 = main.cam.unproject_position(p)
	return Rect2i(int(s.x) - w / 2, int(s.y) - h / 2, w, h)

func _process(_d: float) -> bool:
	f += 1
	if f == 30:
		# park the chase camera: a low view of the start gate from the grid, HUD hidden
		main.set_process(false)
		main.hud.visible = false
		var d = main.track.data
		var p: Vector3 = d.points[0]
		var t: Vector3 = d.tangents[0]
		main.cam.global_position = p - t * 13.0 + Vector3(0, 5.0, 0)
		main.cam.look_at(p + Vector3(0, 6.2, 0))
	elif f == 45:
		var img := _shot("sign_banner")
		var d = main.track.data
		var r := _around(d.points[0] + Vector3(0, 6.2, 0), 420, 70)
		var white := _count(img, r, Color(1, 1, 1))
		var board := _rim_count(img, r, 1, 1.0)
		var rim := _rim_count(img, r, 1, 0.55)   # the board renders at ~0.65 value, the rim darker
		var navy := _count(img, r, Color(0.05, 0.05, 0.2), 0.06)
		var black := _count(img, r, Color(0, 0, 0), 0.07)
		_check(main.track.banner_text == "START" and white > 300, "START banner: white text (%d px)" % white)
		_check(rim > 300 and rim < board / 10, "banner rim: a thin dark green rim (%d px of %d green)" % [rim, board])
		_check(navy == 0 and black == 0, "no navy / black outline pixels around the banner text (%d / %d)" % [navy, black])
		# Lakitu holds the REVERSE sign up in front of the player
		main.set_physics_process(false)
		var lk = main.lakitu
		var fwd := Vector3(-sin(main.kart.heading), 0, -cos(main.kart.heading))
		lk.mode = Lakitu.Mode.REVERSE
		lk.wrong_time = 0.1
		lk.visible = false
		lk._show(0.0, true)
		lk._move(1.0, fwd)
		main.cam.global_position = main.kart.global_position + Vector3(0, 2.6, 0) - fwd * 1.0
		main.cam.look_at(lk._sign_label.global_position)
	elif f == 60:
		var img := _shot("sign_reverse")
		var lk = main.lakitu
		var r := _around(lk._sign_label.global_position, 520, 90)
		var white := _count(img, r, Color(1, 1, 1))
		var board := _rim_count(img, r, 0, 1.0)
		var rim := _rim_count(img, r, 0, 0.7)
		var black := _count(img, r, Color(0, 0, 0), 0.07)
		var old := _count(img, r, Color(0.1, 0.02, 0.02), 0.04)
		_check(lk._sign.visible and lk._sign_label.text == "REVERSE" and white > 300, "REVERSE sign: white text (%d px)" % white)
		_check(rim > 300 and rim < board / 4, "sign rim: a thin dark red rim (%d px of %d red)" % [rim, board])
		_check(black == 0 and old == 0, "no black / old dark outline pixels around the sign text (%d / %d)" % [black, old])
		print("SIGN SHOT: %s" % ("OK" if ok else "FAIL"))
		quit(0 if ok else 1)
		return true
	return false
