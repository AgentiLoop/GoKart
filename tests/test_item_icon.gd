extends RefCounted
## HUD item window: Mario Kart 64 style item icons drawn from primitives (ItemIcon.glyph) in a
## navy window with a gold rim at the top centre, hidden while nothing is held.

const Hud := preload("res://scripts/hud.gd")
const Items := preload("res://scripts/items.gd")
const ItemIcon := preload("res://scripts/item_icon.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
var runner

## Every primitive carries a colour and sits inside the unit square.
static func _well_formed(prims: Array) -> bool:
	for p in prims:
		if not p.has("col"):
			return false
		if p.has("poly"):
			if p.poly.size() < 3:
				return false
			for v in p.poly:
				if absf(v.x) > 1.05 or absf(v.y) > 1.05:
					return false
		elif p.has("circle"):
			if p.r <= 0.0 or absf(p.circle.x) + p.r > 1.05 or absf(p.circle.y) + p.r > 1.05:
				return false
		elif not p.has("text"):
			return false
	return true

static func _has_colour(prims: Array, c: Color) -> bool:
	for p in prims:
		if p.col.is_equal_approx(c):
			return true
	return false

func test_every_item_has_a_glyph() -> void:
	runner.check(ItemIcon.glyph(Items.Type.NONE).is_empty(), "nothing drawn for NONE")
	for t in range(1, Items.Type.size()):
		var g := ItemIcon.glyph(t)
		runner.check(g.size() >= 2, "%s has an icon" % Items.name_of(t))
		runner.check(_well_formed(g), "%s icon is well formed and inside the window" % Items.name_of(t))

func test_icon_colours_match_the_items() -> void:
	runner.check(_has_colour(ItemIcon.glyph(Items.Type.SHELL), ItemIcon.SHELL_GREEN) and _has_colour(ItemIcon.glyph(Items.Type.SHELL), ItemIcon.SHELL_RIM), "green shell with a white rim")
	runner.check(_has_colour(ItemIcon.glyph(Items.Type.RED_SHELL), ItemIcon.SHELL_RED), "red shell")
	runner.check(_has_colour(ItemIcon.glyph(Items.Type.BLUE_SHELL), ItemIcon.SHELL_BLUE), "blue shell")
	runner.check(ItemIcon.glyph(Items.Type.BLUE_SHELL).size() == ItemIcon.glyph(Items.Type.SHELL).size() + 4, "blue shell has 4 spikes")
	runner.check(_has_colour(ItemIcon.glyph(Items.Type.MUSHROOM), ItemIcon.CAP_RED) and _has_colour(ItemIcon.glyph(Items.Type.MUSHROOM), Color.WHITE), "red mushroom cap with white spots")
	runner.check(_has_colour(ItemIcon.glyph(Items.Type.GOLDEN_MUSHROOM), ItemIcon.CAP_GOLD) and not _has_colour(ItemIcon.glyph(Items.Type.GOLDEN_MUSHROOM), ItemIcon.CAP_RED), "golden mushroom cap")
	runner.check(_has_colour(ItemIcon.glyph(Items.Type.BANANA), ItemIcon.BANANA), "yellow banana")
	runner.check(_has_colour(ItemIcon.glyph(Items.Type.STAR), ItemIcon.STAR) and ItemIcon.glyph(Items.Type.STAR)[0].poly.size() == 10, "five-point star")
	runner.check(_has_colour(ItemIcon.glyph(Items.Type.LIGHTNING), ItemIcon.BOLT), "yellow bolt")
	runner.check(_has_colour(ItemIcon.glyph(Items.Type.BOO), ItemIcon.BOO) and _has_colour(ItemIcon.glyph(Items.Type.BOO), ItemIcon.TONGUE), "white Boo with a tongue")
	var box := ItemIcon.glyph(Items.Type.FAKE_ITEM_BOX)
	runner.check(_has_colour(box, ItemIcon.BOX_RED) and box[-1].has("text") and box[-1].text == "¿", "red fake box with an upside-down ?")

func test_triples_are_three_small_copies() -> void:
	for pair in [[Items.Type.TRIPLE_SHELL, Items.Type.SHELL], [Items.Type.TRIPLE_RED_SHELL, Items.Type.RED_SHELL], [Items.Type.TRIPLE_MUSHROOM, Items.Type.MUSHROOM], [Items.Type.BANANA_BUNCH, Items.Type.BANANA]]:
		var three := ItemIcon.glyph(pair[0])
		var one := ItemIcon.glyph(pair[1])
		runner.check(three.size() == 3 * one.size(), "%s = 3 x %s" % [Items.name_of(pair[0]), Items.name_of(pair[1])])
		runner.check(_well_formed(three), "%s copies stay inside the window" % Items.name_of(pair[0]))
	var one := ItemIcon.glyph(Items.Type.SHELL)
	var moved := ItemIcon.place(one, Vector2(0.5, 0.0), 0.5)
	runner.check(moved[1].poly[0].is_equal_approx(Vector2(0.5, 0.0) + one[1].poly[0] * 0.5), "place shifts and scales polygons")
	runner.check(moved[2].circle.is_equal_approx(Vector2(0.5, 0.0) + one[2].circle * 0.5) and is_equal_approx(moved[2].r, one[2].r * 0.5), "place shifts and scales circles")
	runner.check(one[2].r == ItemIcon.glyph(Items.Type.SHELL)[2].r, "the original glyph is untouched")

func test_hud_item_window() -> void:
	var hud = Hud.new()
	hud._ready()
	runner.check(not hud.item_window.visible and hud.item_icon.item == Items.Type.NONE, "window hidden at start")
	hud.show_item(Items.Type.TRIPLE_SHELL, 2)
	runner.check(hud.item_window.visible and hud.item_icon.item == Items.Type.TRIPLE_SHELL, "window shows the held item's icon")
	runner.check(hud.item_label.text == "[ TRIPLE SHELLS x2 ]" and hud.hint_label.text != "", "name with charges and the use hint under the window")
	runner.check(hud.item_window.size == Vector2(Hud.ITEM_WINDOW, Hud.ITEM_WINDOW) and hud.item_icon.size == Vector2(Hud.ITEM_ICON, Hud.ITEM_ICON), "window / icon sizes")
	runner.check(hud.item_icon.position.x == (Hud.ITEM_WINDOW - Hud.ITEM_ICON) * 0.5 and hud.item_icon.position.y == hud.item_icon.position.x, "icon centred in the window")
	runner.check(hud.item_window.anchor_left == 0.5 and hud.item_window.anchor_right == 0.5 and hud.item_window.offset_left == -hud.item_window.offset_right, "window centred at the top")
	var sb: StyleBoxFlat = hud.item_window.get_theme_stylebox("panel")
	runner.check(sb.bg_color == UiStyle.PANEL_FILL and sb.border_color == UiStyle.PANEL_RIM, "navy window with a gold rim")
	runner.check(hud.item_label.get_theme_color("font_color") == UiStyle.GOLD and hud.item_label.get_theme_constant("outline_size") == 0, "gold item name, no outline")
	runner.check(hud.item_label.offset_top >= hud.item_window.offset_bottom and hud.hint_label.offset_top > hud.item_label.offset_top, "name then hint below the window")
	hud.show_item(Items.Type.NONE)
	runner.check(not hud.item_window.visible and hud.item_label.text == "" and hud.hint_label.text == "", "empty hand hides the window")
	hud.free()
