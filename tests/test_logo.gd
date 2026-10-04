extends RefCounted
## The "GOKART" logo like Mario Kart 64's: letters set on an arch (edge letters lower and leaning
## outward), each a stack of layers — a soft shadow, navy extrusion layers (MK64's 3D block letters,
## without the black), a dark red rim and a yellow -> orange -> red gradient fill painted by
## shaders/logo_gradient.gdshader — and the whole word inside its box, above the select banner.

const Menu := preload("res://scripts/menu.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const BANNER_TOP := 162.0   # the SELECT COURSE banner's y on the select screen (menu.gd _ready)
var runner

func _root() -> Node:
	return Engine.get_main_loop().root

func _menu() -> Node:
	var m = Menu.new()
	_root().add_child(m)
	if m.select_box == null:
		m._ready()   # the runner's root is not ready yet during _initialize
	return m

func test_arch_pose() -> void:
	var mid: Dictionary = Menu.logo_letter_pose(0.0, 820.0)
	runner.check(is_zero_approx(mid.drop) and is_zero_approx(mid.angle), "the middle of the word sits on the crown")
	var left: Dictionary = Menu.logo_letter_pose(-250.0, 820.0)
	var right: Dictionary = Menu.logo_letter_pose(250.0, 820.0)
	runner.check(left.drop > 30.0 and left.drop < 50.0 and is_equal_approx(left.drop, right.drop), "edge letters drop ~39 px: %f" % left.drop)
	runner.check(left.angle < -0.25 and is_equal_approx(left.angle, -right.angle), "edge letters lean outward, symmetric: %f" % left.angle)
	var near: Dictionary = Menu.logo_letter_pose(-100.0, 820.0)
	runner.check(near.drop < left.drop and near.angle > left.angle, "closer to the middle: less drop, less lean")
	var far: Dictionary = Menu.logo_letter_pose(5000.0, 820.0)
	runner.check(is_equal_approx(far.drop, 820.0) and is_equal_approx(far.angle, PI * 0.5), "clamped at the arc's end")

func test_letters_on_the_arch() -> void:
	var m = _menu()
	var letters: Array = m.title_box.get_children()
	var n := letters.size()
	runner.check(n == Menu.LOGO_TEXT.length(), "one box per letter: %d" % n)
	var ordered := true
	var prev_right := -1.0
	for i in n:
		var l: Control = letters[i]
		if l.position.x < prev_right:
			ordered = false
		prev_right = l.position.x + l.size.x
		var fill: Label = l.get_child(l.get_child_count() - 1)
		runner.check(fill.text == Menu.LOGO_TEXT[i], "letter %d reads %s" % [i, fill.text])
	runner.check(ordered, "letters left to right without overlapping")
	var mid := n / 2
	runner.check(letters[0].position.y > letters[mid].position.y + 15.0 and letters[n - 1].position.y > letters[mid - 1].position.y + 15.0, "edge letters sit lower than the middle ones (arch): %f vs %f" % [letters[0].position.y, letters[mid].position.y])
	runner.check(letters[0].rotation < -0.15 and letters[n - 1].rotation > 0.15 and absf(letters[mid].rotation) < 0.1 and absf(letters[mid - 1].rotation) < 0.1, "edge letters lean outward, the middle ones stand up")
	runner.check(letters[mid - 1].position.y >= Menu.LOGO_CROWN_Y and letters[mid - 1].position.y < Menu.LOGO_CROWN_Y + 4.0, "the crown letters sit at the top of the box")
	var ascent: float = m.font.get_ascent(Menu.LOGO_FONT)
	var reach: Vector2 = Menu.LOGO_DEPTH_STEP * Menu.LOGO_DEPTH + Menu.LOGO_SHADOW_OFF
	var word_w := 0.0
	for l in letters:
		runner.check(l.position.x >= 0.0 and l.position.x + l.size.x + reach.x <= Menu.LOGO_BOX.x, "letter and its shadow inside the box horizontally")
		runner.check(l.position.y + ascent + reach.y <= Menu.LOGO_BOX.y, "baseline + extrusion + shadow inside the box: %f" % (l.position.y + ascent + reach.y))
		word_w += l.size.x
	runner.check(is_equal_approx(letters[0].position.x, Menu.LOGO_BOX.x - prev_right), "word centred in the box")
	runner.check(word_w > 400.0 and word_w < 700.0, "a chunky word: %f px wide" % word_w)
	runner.check(Menu.MENU_LOGO_POS.y + Menu.LOGO_BOX.y <= BANNER_TOP, "the whole logo clears the SELECT banner on the select screen")
	runner.check(m.title_box.pivot_offset == Menu.LOGO_BOX * 0.5 and is_zero_approx(m.title_box.rotation), "scales about its centre; the arch replaces the old slant")
	m.free()

func test_letter_layers() -> void:
	var m = _menu()
	var letter: Control = m.title_box.get_child(0)
	var labels: Array = letter.get_children()
	var taps := 9   # the soft shadow: a centre copy and a ring of 8 around it, no rim, blurred
	runner.check(labels.size() == taps + Menu.LOGO_DEPTH + 2, "%d shadow taps + %d extrusion layers + rim + fill: %d" % [taps, Menu.LOGO_DEPTH, labels.size()])
	var shadow_at: Vector2 = Menu.LOGO_DEPTH_STEP * Menu.LOGO_DEPTH + Menu.LOGO_SHADOW_OFF
	var tap_alpha := 1.0 - pow(1.0 - Menu.LOGO_SHADOW.a, 1.0 / taps)
	var stacked := 1.0
	for s in taps:
		var shadow: Label = labels[s]
		var c: Color = shadow.get_theme_color("font_color")
		runner.check(Color(c, 1.0) == Color(Menu.LOGO_SHADOW, 1.0) and is_equal_approx(c.a, tap_alpha) and shadow.get_theme_constant("outline_size") == 0, "shadow tap %d is faint navy with no rim" % s)
		var off: Vector2 = shadow.position - shadow_at
		runner.check(is_equal_approx(off.length(), 0.0 if s == 0 else Menu.LOGO_SHADOW_BLUR), "shadow tap %d sits on the centre / the blur ring" % s)
		stacked *= 1.0 - c.a
	runner.check(is_equal_approx(1.0 - stacked, Menu.LOGO_SHADOW.a), "the taps stack to the soft shadow's alpha")
	for d in Menu.LOGO_DEPTH:
		var layer: Label = labels[taps + d]
		runner.check(layer.get_theme_color("font_color") == Menu.LOGO_EXTRUDE and layer.get_theme_color("font_outline_color") == Menu.LOGO_EXTRUDE, "extrusion layer %d is navy" % d)
		runner.check(layer.position.is_equal_approx(Menu.LOGO_DEPTH_STEP * (Menu.LOGO_DEPTH - d)), "layers stack from the back to the front")
	var rim: Label = labels[taps + Menu.LOGO_DEPTH]
	runner.check(rim.get_theme_color("font_color") == UiStyle.SIGN_RIM and rim.get_theme_color("font_outline_color") == UiStyle.SIGN_RIM and rim.position == Vector2.ZERO, "dark red rim layer under the fill")
	runner.check(rim.get_theme_constant("outline_size") == 7, "rim 7 px, as wide as the old logo rim (the sign rule: size / 16)")
	var fill: Label = labels[taps + Menu.LOGO_DEPTH + 1]
	runner.check(fill.get_theme_constant("outline_size") == 0 and fill.material is ShaderMaterial and fill.material.shader == Menu.LogoShader, "fill painted by the gradient shader, no outline of its own")
	var mat: ShaderMaterial = fill.material
	runner.check(mat.get_shader_parameter("top_color") == Menu.LOGO_TOP and mat.get_shader_parameter("mid_color") == Menu.LOGO_MID and mat.get_shader_parameter("bottom_color") == Menu.LOGO_RED, "yellow at the top, orange, red at the baseline")
	var top_y: float = mat.get_shader_parameter("top_y")
	var bottom_y: float = mat.get_shader_parameter("bottom_y")
	runner.check(is_equal_approx(bottom_y, m.font.get_ascent(Menu.LOGO_FONT)) and is_equal_approx(bottom_y - top_y, Menu.LOGO_FONT * Menu.LOGO_CAP_HEIGHT), "gradient spans the cap height down to the baseline")
	for l in labels:
		runner.check(l.text == Menu.LOGO_TEXT[0] and l.get_theme_font("font") == m.font and l.get_theme_font_size("font_size") == Menu.LOGO_FONT, "every layer is the same glyph in the menu font")
		runner.check(l.get_theme_color("font_shadow_color").a == 0.0, "layers carry no drop shadow of their own")
		runner.check(l.get_theme_constant("outline_size") <= 7, "no outline wider than the rim")
		var c: Color = l.get_theme_color("font_color")
		var o: Color = l.get_theme_color("font_outline_color")
		runner.check(c != Color(0, 0, 0, c.a) and (l.get_theme_constant("outline_size") == 0 or o != Color(0, 0, 0, o.a)), "no black layer")
	m.free()
