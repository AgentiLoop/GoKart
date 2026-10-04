extends SceneTree
## Windowed render check of the restyled race HUD (no black outlines, MK64 palette):
##   perl -e 'alarm 60; exec @ARGV' godot --path . -s tools/hud_shot.gd
## Saves /tmp/gokart_hud_countdown.png (the gold "3" sign over the grid, a green shell in the item window), /tmp/gokart_hud_results.png,
## _results_gp.png and _results_tt.png (the results boards on their navy panel) and samples a few pixels.
## Each board is shot 2 s after it comes up (the rows slide in over ~1.5 s); _results_mid.png is the
## race board 0.2 s in, with the first rows arriving and the rest still off to the left.

const RaceResults := preload("res://scripts/race_results.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const Items := preload("res://scripts/items.gd")
const ItemIcon := preload("res://scripts/item_icon.gd")

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
	if f == 20:
		# a green shell in the MK64 item window at the top centre
		main.items.holder.held = Items.Type.SHELL
	elif f == 30:
		print("countdown label: '%s'  outline %d rim %s" % [main.hud.countdown_label.text, main.hud.countdown_label.get_theme_constant("outline_size"), main.hud.countdown_label.get_theme_color("font_outline_color")])
		var img := _shot("hud_countdown")
		var size := img.get_size()
		var centre := Rect2i(size.x / 2 - 120, size.y / 2 - 230, 240, 240)
		print("gold sign at centre: ", _has_colour(img, centre, UiStyle.GOLD))
		print("gold lap label top-left: ", _has_colour(img, Rect2i(24, 16, 220, 48), UiStyle.GOLD))
		print("black outline pixels around lap label: ", _has_colour(img, Rect2i(24, 16, 220, 48), Color.BLACK, 0.04))
		var win := Rect2i(size.x / 2 - 48, 14, 96, 96)
		print("item window shown: %s  label '%s'" % [main.hud.item_window.visible, main.hud.item_label.text])
		print("item window navy fill: ", _has_colour(img, Rect2i(win.position + Vector2i(6, 6), Vector2i(10, 10)), Color(UiStyle.PANEL_FILL.r, UiStyle.PANEL_FILL.g, UiStyle.PANEL_FILL.b), 0.12))
		print("item window gold rim: ", _has_colour(img, Rect2i(win.position.x + 20, win.position.y, 56, 3), UiStyle.PANEL_RIM, 0.2))
		print("green shell in the window: ", _has_colour(img, win, ItemIcon.SHELL_GREEN, 0.15))
		print("shell rim (white) in the window: ", _has_colour(img, win, ItemIcon.SHELL_RIM, 0.1))
		print("gold item name under the window: ", _has_colour(img, Rect2i(size.x / 2 - 120, 114, 240, 30), UiStyle.GOLD, 0.15))
	elif f == 40:
		var names := ["YOU", "BLUE", "GREEN", "PURPLE", "RED", "TEAL", "PINK", "LIME"]
		var rows := RaceResults.rows(names, [900.0, 880.0, 860.0, 840.0, 820.0, 800.0, 780.0, 760.0], [92.4, 93.1, 95.0, 97.7, -1.0, -1.0, -1.0, -1.0])
		main.hud.show_results(RaceResults.table_text(rows, 0))
		main.hud.show_countdown("")
	elif f == 52:
		var img := _shot("hud_results_mid")
		var hud = main.hud
		var in_rows: int = hud.reveal_rows.filter(func(r): return r.modulate.a == 1.0).size()
		var waiting: int = hud.reveal_rows.filter(func(r): return r.modulate.a == 0.0).size()
		print("mid reveal (t %.2f): %d rows in, %d still waiting, %d ticks" % [hud.reveal_t, in_rows, waiting, hud.ticks])
		var size := img.get_size()
		var panel: Panel = hud.results_panel
		var top := Rect2i(int(size.x / 2 + panel.offset_left) + 30, int(size.y / 2 + panel.offset_top) + 46, 300, 28)
		var bottom := Rect2i(top.position.x, int(size.y / 2 + panel.offset_bottom) - 60, 300, 28)
		print("  cream text in the first row: %s  in the last row: %s" % [_has_colour(img, top, UiStyle.CREAM, 0.12), _has_colour(img, bottom, UiStyle.CREAM, 0.12)])
	elif f == 160:
		_sample_board("hud_results")
		print("  reveal over: %s  ticks: %d" % [main.hud.reveal_t < 0.0, main.hud.ticks])
	elif f == 170:
		# Grand Prix: results + cup standings + trophy (8 racers) must still fit the window
		var names := ["YOU", "BLUE", "GREEN", "PURPLE", "YELLOW", "ORANGE", "PINK", "TEAL"]
		var rows := RaceResults.rows(names, [900.0, 880.0, 860.0, 840.0, 820.0, 800.0, 780.0, 760.0], [92.4, 93.1, 95.0, 97.7, -1.0, -1.0, -1.0, -1.0])
		var gp = load("res://scripts/grand_prix.gd")
		gp.start([0, 1, 2, 3], 8)
		gp.race_index = 3
		gp.add_race(rows, 0)
		main.hud.show_results(RaceResults.table_text(rows, 0, gp.standings_text(names, 0)))
		gp.stop()
	elif f == 290:
		var r := _sample_board("hud_results_gp")
		var size := root.get_viewport().get_texture().get_image().get_size()
		print("GP board inside the window: ", r.position.y - 23 >= 0 and r.end.y <= size.y)
	elif f == 300:
		var tt = load("res://scripts/time_trial.gd")
		main.hud.show_results(tt.results_text("Green Hills", 62.5, [21.0, 20.1, 21.4], {"new_best": true, "new_best_lap": true, "rank": 1}))
	elif f == 420:
		_sample_board("hud_results_tt")
		quit(0)
		return true
	return false

## Saves the board shot and samples its panel, rim, text, title pill and the player's bar.
func _sample_board(name: String) -> Rect2i:
	var img := _shot(name)
	var size := img.get_size()
	var panel: Panel = main.hud.results_panel
	var r := Rect2i(int(size.x / 2 + panel.offset_left), int(size.y / 2 + panel.offset_top), int(panel.offset_right - panel.offset_left), int(panel.offset_bottom - panel.offset_top))
	print("%s panel rect: %s  rows: %d" % [name, r, main.hud.results_box.get_child_count()])
	print("  navy panel fill: ", _has_colour(img, Rect2i(r.position + Vector2i(8, 40), Vector2i(24, 24)), Color(UiStyle.PANEL_FILL.r, UiStyle.PANEL_FILL.g, UiStyle.PANEL_FILL.b), 0.12))
	print("  gold rim: ", _has_colour(img, Rect2i(r.position.x, r.position.y + 60, 4, 40), UiStyle.PANEL_RIM))
	print("  cream text: ", _has_colour(img, r, UiStyle.CREAM, 0.12))
	print("  gold text: ", _has_colour(img, r, UiStyle.GOLD, 0.12))
	var pill := Rect2i(r.position.x + r.size.x / 2 - 100, r.position.y - 23, 200, 23)
	print("  title pill above the top edge (gold rim + gold sign): ", _has_colour(img, pill, UiStyle.PANEL_RIM) and _has_colour(img, pill, UiStyle.GOLD, 0.12))
	print("  black pixels inside the board: ", _has_colour(img, Rect2i(r.position + Vector2i(6, 6), r.size - Vector2i(12, 12)), Color.BLACK, 0.03))
	return r
