extends RefCounted
## The select screen's kart portrait (Mario Kart 64's Player Select shows the picked driver live):
## the player's kart at the picked weight class's size in its own transparent 3D window, turning on
## a turntable, hopping once when the class changes, framed gold while the cursor is on the KART
## row — and the option cells re-laid to leave it room at the end of the panel.

const Menu := preload("res://scripts/menu.gd")
const KartPortrait := preload("res://scripts/kart_portrait.gd")
const KartWeight := preload("res://scripts/kart_weight.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
var runner

func _root() -> Node:
	return Engine.get_main_loop().root

func _menu() -> Node:
	var m = Menu.new()
	_root().add_child(m)
	if m.select_box == null:
		m._ready()   # the runner's root is not ready yet during _initialize
	m.dismiss_title()
	return m

func _rim(frame: Panel) -> Color:
	var sb: StyleBoxFlat = frame.get_theme_stylebox("panel")
	return sb.border_color

func test_portrait_helpers() -> void:
	runner.check(is_zero_approx(KartPortrait.turn_angle(0.0)), "turntable starts at 0")
	runner.check(is_equal_approx(KartPortrait.turn_angle(1.0), KartPortrait.TURN_RATE), "a second = TURN_RATE radians")
	var a := KartPortrait.turn_angle(TAU / KartPortrait.TURN_RATE + 0.5)
	runner.check(a >= 0.0 and a < TAU and is_equal_approx(a, KartPortrait.TURN_RATE * 0.5), "wraps after a revolution")
	runner.check(is_zero_approx(KartPortrait.hop_height(-0.1)) and is_zero_approx(KartPortrait.hop_height(0.0)), "no hop before it starts")
	runner.check(is_equal_approx(KartPortrait.hop_height(KartPortrait.HOP_TIME * 0.5), KartPortrait.HOP_HEIGHT), "the hop peaks at HOP_HEIGHT half way")
	runner.check(KartPortrait.hop_height(KartPortrait.HOP_TIME * 0.2) > 0.0 and KartPortrait.hop_height(KartPortrait.HOP_TIME * 0.8) > 0.0, "up and down are in the air")
	runner.check(is_zero_approx(KartPortrait.hop_height(KartPortrait.HOP_TIME)) and is_zero_approx(KartPortrait.hop_height(2.0)), "landed at HOP_TIME and after")
	for i in KartWeight.count():
		runner.check(is_equal_approx(KartPortrait.class_scale(i), KartWeight.info(i).size), "class %d shown at the size the race uses" % i)
	runner.check(KartPortrait.class_scale(KartWeight.LIGHT) < KartPortrait.class_scale(KartWeight.MEDIUM) and KartPortrait.class_scale(KartWeight.MEDIUM) < KartPortrait.class_scale(KartWeight.HEAVY), "light < medium < heavy")
	var sb := Menu.portrait_frame_style(true)
	var dim := Menu.portrait_frame_style(false)
	runner.check(sb.border_color == UiStyle.GOLD and dim.border_color == Menu.PORTRAIT_FRAME and sb.bg_color.a == 0.0 and dim.bg_color.a == 0.0, "frame: gold rim focused, faint white otherwise, no fill")

func test_portrait_window() -> void:
	var p = KartPortrait.new()
	runner.check(p.viewport != null and p.viewport.own_world_3d and p.viewport.transparent_bg, "own 3D world with a transparent background")
	runner.check(p.viewport.get_parent() == p and p.stretch, "the viewport fills the container")
	runner.check(p.cam != null and p.cam.current and p.cam.get_parent() == p.viewport, "a current camera in the window")
	runner.check(p.cam.transform.origin.is_equal_approx(KartPortrait.CAMERA_POS), "camera at its three-quarter spot")
	var fwd: Vector3 = -p.cam.transform.basis.z
	var to_kart := (KartPortrait.CAMERA_LOOK - KartPortrait.CAMERA_POS).normalized()
	runner.check(fwd.dot(to_kart) > 0.999, "camera looks at the kart")
	runner.check(p.kart != null and p.kart.get_parent() == p.turntable and p.turntable.get_parent() == p.viewport, "kart on the turntable in the world")
	runner.check(p.kart.get_child_count() > 10 and p.kart.color == KartPortrait.KART_COLOR, "a built kart model in the player's red")
	var lights := 0
	var disc: MeshInstance3D = null
	for c in p.viewport.get_children():
		if c is DirectionalLight3D:
			lights += 1
		if c is MeshInstance3D and c.name == "Disc":
			disc = c
	runner.check(lights == 1 and disc != null and disc.material_override.albedo_color == KartPortrait.DISC, "a sun and a gold turntable disc")
	runner.check(p.weight_class == KartWeight.MEDIUM and p.kart.scale.is_equal_approx(Vector3.ONE * KartWeight.info(KartWeight.MEDIUM).size), "starts on the medium kart at its size")
	runner.check(is_zero_approx(p.turntable.position.y) and is_zero_approx(p.turntable.rotation.y), "at rest: landed, not yet turned")
	# the turn
	p._process(1.0)
	runner.check(is_equal_approx(p.turntable.rotation.y, KartPortrait.TURN_RATE), "a second on: turned TURN_RATE radians")
	runner.check(is_zero_approx(p.turntable.position.y), "no hop without a class change")
	# the same class again: no hop
	p.show_class(KartWeight.MEDIUM)
	p._process(KartPortrait.HOP_TIME * 0.5)
	runner.check(is_zero_approx(p.turntable.position.y), "picking the same class does not hop")
	# a new class: scaled and hopping
	p.show_class(KartWeight.HEAVY)
	runner.check(p.weight_class == KartWeight.HEAVY and p.kart.scale.is_equal_approx(Vector3.ONE * KartWeight.info(KartWeight.HEAVY).size), "heavy: the bigger kart")
	p._process(KartPortrait.HOP_TIME * 0.5)
	runner.check(is_equal_approx(p.turntable.position.y, KartPortrait.HOP_HEIGHT), "half way through the hop: at the top")
	p._process(KartPortrait.HOP_TIME)
	runner.check(is_zero_approx(p.turntable.position.y), "landed again")
	p.show_class(KartWeight.LIGHT)
	runner.check(p.kart.scale.x < 1.0 and p.turntable.position.y == 0.0, "light: the smaller kart, the hop starts from the ground")
	p._process(KartPortrait.HOP_TIME * 0.25)
	runner.check(p.turntable.position.y > 0.0, "... and is in the air a moment later")
	p.free()

func test_menu_shows_the_portrait() -> void:
	var m = _menu()
	runner.check(m.portrait != null and m.portrait.get_parent() == m.select_box, "portrait in the select box (hidden with it on the title screen)")
	var rect := Rect2(m.portrait.position, m.portrait.size)
	runner.check(rect == Menu.PORTRAIT_RECT, "portrait at PORTRAIT_RECT")
	var panel := Rect2(80, 500, 1120, 142)
	runner.check(panel.grow(-8).encloses(rect), "portrait inside the option panel with a margin")
	var kart_row := Menu.row_rect(3)
	runner.check(rect.position.x > kart_row.end.x and rect.position.x > Menu.focus_rect(Menu.FOCUS_KART).end.x, "portrait right of the KART pills and clear of the cursor frame")
	runner.check(rect.position.x >= Menu.cell_rect(3).end.x and Menu.cell_rect(0).position.x == 80.0, "the four cells run from the panel's left edge and end before the portrait")
	for slot in 3:
		runner.check(is_equal_approx(Menu.cell_rect(slot).end.x, Menu.cell_rect(slot + 1).position.x), "cell %d meets cell %d" % [slot, slot + 1])
	runner.check(Menu.cell_rect(2).size.x > Menu.cell_rect(0).size.x, "the engine cell (four classes) is the widest")
	runner.check(m.mode_label.position.x + m.mode_label.size.x <= rect.position.x and m.mode_label.position.y + m.mode_label.size.y <= panel.end.y, "mode blurb beside the portrait, inside the panel")
	var frame_rect := Rect2(m.portrait_frame.position, m.portrait_frame.size)
	runner.check(frame_rect.grow(-2) == rect, "frame 2 px round the window")
	runner.check(m.portrait.weight_class == m.weight_class and m.weight_class == KartWeight.MEDIUM, "portrait shows the picked class")
	runner.check(_rim(m.portrait_frame) == Menu.PORTRAIT_FRAME, "frame faint with the cursor on the list")
	# V steps the class and the portrait follows (and hops)
	m.move_weight(1)
	runner.check(m.weight_class == KartWeight.HEAVY and m.portrait.weight_class == KartWeight.HEAVY and m.portrait.hop_t == 0.0, "V: heavy in the portrait, hopping")
	runner.check(m.portrait.kart.scale.is_equal_approx(Vector3.ONE * KartWeight.info(KartWeight.HEAVY).size), "the portrait's kart grew")
	# the cursor on the KART row lights the frame; elsewhere it dims again
	m.focus = Menu.FOCUS_KART
	m._refresh()
	runner.check(_rim(m.portrait_frame) == UiStyle.GOLD, "frame gold with the cursor on KART")
	m.move_focused(-1)
	runner.check(m.weight_class == KartWeight.MEDIUM and m.portrait.weight_class == KartWeight.MEDIUM, "Left on the KART row: back to medium in the portrait")
	m.move_focus(1)
	runner.check(m.focus == Menu.FOCUS_MODE and _rim(m.portrait_frame) == Menu.PORTRAIT_FRAME, "frame faint again on the mode row")
	# battle mode keeps the portrait (the kart races there too)
	m.mode = Menu.MODE_BATTLE
	m._refresh()
	runner.check(m.portrait.weight_class == m.weight_class and m.portrait.visible, "battle: portrait still shows the kart")
	# no text in the portrait window (nothing to outline), no 12 px hints added
	var labels := 0
	var stack: Array = [m.portrait]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label:
			labels += 1
		stack.append_array(n.get_children())
	runner.check(labels == 0, "the portrait is a picture, not text")
	m.free()
