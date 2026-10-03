extends SceneTree
## Windowed render check of the restyled race HUD (no black outlines, MK64 palette):
##   perl -e 'alarm 60; exec @ARGV' godot --path . -s tools/hud_shot.gd
## Saves /tmp/gokart_hud_countdown.png (the gold "3" sign over the grid) and
## /tmp/gokart_hud_results.png (the results table on its navy panel) and samples a few pixels.

const RaceResults := preload("res://scripts/race_results.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

var main
var f := 0

func _initialize() -> void:
	load("res://scripts/track_library.gd").selected = 0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _shot(n: String) -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/gokart_%s.png" % n)
	print("saved /tmp/gokart_%s.png" % n)
	return img

## True when any pixel in `r` is close to `c` (ignoring alpha).
static func _has_colour(img: Image, r: Rect2i, c: Color, tol := 0.18) -> bool:
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			var p := img.get_pixel(x, y)
			if absf(p.r - c.r) < tol and absf(p.g - c.g) < tol and absf(p.b - c.b) < tol:
				return true
	return false

func _process(_d: float) -> bool:
	f += 1
	if f == 30:
		print("countdown label: '%s'  outline %d rim %s" % [main.hud.countdown_label.text, main.hud.countdown_label.get_theme_constant("outline_size"), main.hud.countdown_label.get_theme_color("font_outline_color")])
		var img := _shot("hud_countdown")
		var size := img.get_size()
		var centre := Rect2i(size.x / 2 - 120, size.y / 2 - 230, 240, 240)
		print("gold sign at centre: ", _has_colour(img, centre, UiStyle.GOLD))
		print("gold lap label top-left: ", _has_colour(img, Rect2i(24, 16, 220, 48), UiStyle.GOLD))
		print("black outline pixels around lap label: ", _has_colour(img, Rect2i(24, 16, 220, 48), Color.BLACK, 0.04))
	elif f == 40:
		var names := ["YOU", "BLUE", "GREEN", "PURPLE", "RED", "TEAL", "PINK", "LIME"]
		var rows := RaceResults.rows(names, [900.0, 880.0, 860.0, 840.0, 820.0, 800.0, 780.0, 760.0], [92.4, 93.1, 95.0, 97.7, -1.0, -1.0, -1.0, -1.0])
		main.hud.show_results(RaceResults.table_text(rows, 0))
		main.hud.show_countdown("")
	elif f == 50:
		var img := _shot("hud_results")
		var size := img.get_size()
		var panel: Panel = main.hud.results_panel
		var r := Rect2i(int(size.x / 2 + panel.offset_left), int(size.y / 2 + panel.offset_top), int(panel.offset_right - panel.offset_left), int(panel.offset_bottom - panel.offset_top))
		print("results panel rect: ", r)
		print("navy panel fill: ", _has_colour(img, Rect2i(r.position + Vector2i(8, 8), Vector2i(24, 24)), Color(UiStyle.PANEL_FILL.r, UiStyle.PANEL_FILL.g, UiStyle.PANEL_FILL.b), 0.12))
		print("gold rim: ", _has_colour(img, Rect2i(r.position.x, r.position.y, r.size.x, 4), UiStyle.PANEL_RIM))
		print("cream table text: ", _has_colour(img, r, UiStyle.CREAM, 0.12))
		quit(0)
		return true
	return false
