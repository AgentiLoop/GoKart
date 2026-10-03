extends SceneTree
## Windowed contact sheet of the HUD's Mario Kart 64 style item icons:
##   perl -e 'alarm 60; exec @ARGV' godot --path . -s tools/item_shot.gd
## Draws every item in its own navy window with its name underneath, saves /tmp/gokart_items.png
## and samples each window for the item's main colour.

const Items := preload("res://scripts/items.gd")
const ItemIcon := preload("res://scripts/item_icon.gd")
const UiStyle := preload("res://scripts/ui_style.gd")

const COLS := 5
const CELL := Vector2(240, 190)
const WIN := 110.0
const ICON := 84.0

## The colour that proves each icon drew (its biggest primitive).
const KEY_COLOUR := {
	Items.Type.MUSHROOM: ItemIcon.CAP_RED, Items.Type.BANANA: ItemIcon.BANANA, Items.Type.SHELL: ItemIcon.SHELL_GREEN,
	Items.Type.RED_SHELL: ItemIcon.SHELL_RED, Items.Type.STAR: ItemIcon.STAR, Items.Type.LIGHTNING: ItemIcon.BOLT,
	Items.Type.TRIPLE_SHELL: ItemIcon.SHELL_GREEN, Items.Type.BLUE_SHELL: ItemIcon.SHELL_BLUE,
	Items.Type.TRIPLE_MUSHROOM: ItemIcon.CAP_RED, Items.Type.GOLDEN_MUSHROOM: ItemIcon.CAP_GOLD,
	Items.Type.FAKE_ITEM_BOX: ItemIcon.BOX_RED, Items.Type.BANANA_BUNCH: ItemIcon.BANANA, Items.Type.BOO: ItemIcon.BOO,
	Items.Type.TRIPLE_RED_SHELL: ItemIcon.SHELL_RED,
}

var f := 0
var windows := {}

func _initialize() -> void:
	var font := UiStyle.make_font()
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.2, 0.5)
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var origin := Vector2((1280 - COLS * CELL.x) * 0.5, 60)
	for t in range(1, Items.Type.size()):
		var i := t - 1
		var cell := origin + Vector2(CELL.x * (i % COLS), CELL.y * (i / COLS))
		var win := Panel.new()
		win.position = cell + Vector2((CELL.x - WIN) * 0.5, 0)
		win.size = Vector2(WIN, WIN)
		win.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.PANEL_FILL, UiStyle.PANEL_RIM, 18))
		root.add_child(win)
		var icon := ItemIcon.new()
		icon.font = font
		icon.position = Vector2(WIN - ICON, WIN - ICON) * 0.5
		icon.size = Vector2(ICON, ICON)
		icon.item = t
		win.add_child(icon)
		var name := Label.new()
		name.position = cell + Vector2(0, WIN + 8)
		name.size = Vector2(CELL.x, 30)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.text = Items.name_of(t)
		UiStyle.style_label(name, font, 20, UiStyle.GOLD)
		root.add_child(name)
		windows[t] = Rect2i(Vector2i(win.position), Vector2i(win.size))

## Pixels in `r` close to `c` (every other pixel sampled).
static func _count_colour(img: Image, r: Rect2i, c: Color, tol := 0.15) -> int:
	var n := 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			var p := img.get_pixel(x, y)
			if absf(p.r - c.r) < tol and absf(p.g - c.g) < tol and absf(p.b - c.b) < tol:
				n += 1
	return n

static func _has_colour(img: Image, r: Rect2i, c: Color, tol := 0.15) -> bool:
	return _count_colour(img, r, c, tol) > 0

func _process(_d: float) -> bool:
	f += 1
	if f < 20:
		return false
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/gokart_items.png")
	print("saved /tmp/gokart_items.png")
	var ok := true
	for t in windows:
		var r: Rect2i = windows[t]
		var navy := _has_colour(img, Rect2i(r.position + Vector2i(5, 5), Vector2i(8, 8)), Color(UiStyle.PANEL_FILL.r, UiStyle.PANEL_FILL.g, UiStyle.PANEL_FILL.b), 0.12)
		# the icon's main colour should cover a fair share of the window (sampled every other pixel)
		var key := _count_colour(img, r, KEY_COLOUR[t])
		var share := float(key) / float(r.size.x * r.size.y / 4)
		print("%-18s window navy %s  icon colour %4d px (%.0f%% of the window)" % [Items.name_of(t), navy, key, share * 100.0])
		ok = ok and navy and share > 0.05
	print("ITEM SHOT: %s" % ("OK" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
