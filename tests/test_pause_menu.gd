extends RefCounted
## Mario Kart 64 style pause screen: the pure helpers (cursor, keys, rows, the pop), the panel's
## look (navy / gold / cream, no black, no outlines on the lines) and the open / move / resume flow
## driven outside the scene tree (the race-side effects — the frozen tree, retry, course change,
## quit — are tools/pause_check.gd's job).

const PauseMenu := preload("res://scripts/pause_menu.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const SoundSynth := preload("res://scripts/sound_synth.gd")

var runner

func test_helpers() -> void:
	runner.check(PauseMenu.OPTIONS == ["CONTINUE", "RETRY", "COURSE CHANGE", "QUIT"], "four lines in MK64's order")
	runner.check(PauseMenu.step(PauseMenu.CONTINUE, 1) == PauseMenu.RETRY and PauseMenu.step(PauseMenu.QUIT, 1) == PauseMenu.CONTINUE and PauseMenu.step(PauseMenu.CONTINUE, -1) == PauseMenu.QUIT, "the cursor wraps both ways")
	runner.check(PauseMenu.direction_for_key(KEY_UP) == -1 and PauseMenu.direction_for_key(KEY_W) == -1 and PauseMenu.direction_for_key(KEY_DOWN) == 1 and PauseMenu.direction_for_key(KEY_S) == 1 and PauseMenu.direction_for_key(KEY_A) == 0, "Up / W and Down / S move, nothing else")
	runner.check(PauseMenu.is_confirm_key(KEY_ENTER) and PauseMenu.is_confirm_key(KEY_KP_ENTER) and not PauseMenu.is_confirm_key(KEY_SPACE), "Enter picks")
	runner.check(PauseMenu.is_pause_key(KEY_ESCAPE) and not PauseMenu.is_pause_key(KEY_P), "Esc pauses / resumes")
	for i in PauseMenu.OPTIONS.size():
		var r := PauseMenu.row_rect(i)
		runner.check(r.position.x == PauseMenu.ROW_INSET and r.end.x == PauseMenu.PANEL_SIZE.x - PauseMenu.ROW_INSET, "row %d spans the panel less the inset" % i)
		runner.check(is_equal_approx(r.position.y, PauseMenu.ROWS_Y + i * PauseMenu.ROW_H) and r.size.y == PauseMenu.ROW_H, "row %d under the one before" % i)
	runner.check(PauseMenu.row_rect(3).end.y < PauseMenu.PANEL_SIZE.y - PauseMenu.HINT_H - 12.0, "the last row clears the hint")
	# the pop: from POP_FROM, through an overshoot past 1, to exactly 1 at POP_TIME; alpha in over the first half
	var start: Dictionary = PauseMenu.pop_pose(0.0)
	runner.check(is_equal_approx(start.scale, PauseMenu.POP_FROM) and is_zero_approx(start.alpha), "starts small and clear")
	var mid: Dictionary = PauseMenu.pop_pose(PauseMenu.POP_TIME * 0.6)
	runner.check(mid.scale > 1.0 and is_equal_approx(mid.alpha, 1.0), "overshoots past full size once opaque: %.3f" % mid.scale)
	var done: Dictionary = PauseMenu.pop_pose(PauseMenu.POP_TIME)
	runner.check(is_equal_approx(done.scale, 1.0) and is_equal_approx(done.alpha, 1.0), "lands at 1")
	runner.check(is_equal_approx(PauseMenu.pop_pose(PauseMenu.POP_TIME * 3.0).scale, 1.0), "stays at 1")
	var lib := SoundSynth.effect_library()
	for name in PauseMenu.EFFECTS:
		runner.check(lib.has(name) and SoundSynth.peak(lib[name]) > 0.01, "effect %s" % name)
	runner.check(lib["pause"].size() == lib["resume"].size(), "pause and resume are the same two notes, down then up")

## The panel: over the HUD, a navy veil (no black), the PAUSE sign with the HUD's dark red rim, the
## four lines cream with no outline, the picked one gold on a lit bar, a grey hint, hidden until Esc.
func test_look() -> void:
	var p = PauseMenu.new()
	p._ready()
	runner.check(p.layer == PauseMenu.LAYER and p.layer > 10 and p.process_mode == Node.PROCESS_MODE_ALWAYS, "over the HUD, runs while the tree is paused")
	runner.check(not p.visible and not p.shown, "hidden until Esc")
	runner.check(p.veil.color.r < 0.1 and p.veil.color.b > p.veil.color.r and p.veil.color.a > 0.3 and p.veil.color.a < 0.6 and p.veil.color != Color.BLACK, "a navy, see-through veil, not black")
	runner.check(p.title.text == "PAUSE" and p.title.get_theme_color("font_color") == UiStyle.GOLD and p.title.get_theme_color("font_outline_color") == UiStyle.SIGN_RIM and p.title.get_theme_constant("outline_size") == maxi(3, PauseMenu.TITLE_FONT / 16), "PAUSE is a gold sign with the dark red rim")
	runner.check(p.title.position.y < 0.0, "the sign straddles the panel's top edge")
	runner.check(p.rows.size() == 4, "four lines")
	for i in p.rows.size():
		var l: Label = p.rows[i]
		runner.check(l.text == PauseMenu.OPTIONS[i], "line %d: %s" % [i, l.text])
		runner.check(l.get_theme_constant("outline_size") == 0 and l.get_theme_color("font_shadow_color") == UiStyle.SHADOW, "line %d has a drop shadow, no outline" % i)
		runner.check(l.get_theme_color("font_color") == (UiStyle.GOLD if i == PauseMenu.CONTINUE else UiStyle.CREAM), "line %d colour" % i)
	runner.check(p.hint.text == PauseMenu.HINT and p.hint.get_theme_color("font_color") == UiStyle.GREY and p.hint.get_theme_constant("outline_size") == 0, "a grey hint, no outline")
	var sb: StyleBoxFlat = p.panel.get_theme_stylebox("panel")
	runner.check(sb.bg_color == UiStyle.PANEL_FILL and sb.border_color == UiStyle.PANEL_RIM, "navy panel with the gold rim")
	var bar: StyleBoxFlat = p.bar.get_theme_stylebox("panel")
	runner.check(bar.border_color == UiStyle.GOLD and bar.bg_color.a < 0.5, "the lit bar is the menu's translucent gold")
	runner.check(p.bar.position.y > PauseMenu.row_rect(0).position.y and p.bar.position.y + p.bar.size.y < PauseMenu.row_rect(0).end.y, "the bar sits inside the CONTINUE row")
	runner.check(p.panel.pivot_offset == PauseMenu.PANEL_SIZE * 0.5 and is_equal_approx(p.panel.offset_left, -PauseMenu.PANEL_SIZE.x * 0.5), "centred, scaling about its middle")
	p.free()

## Esc brings the panel up on CONTINUE with the pause sound and the pop running; Down / Up move the
## cursor (tick, gold line, bar); Esc or CONTINUE resume with the resume sound; the next open starts
## on CONTINUE again.
func test_open_move_resume() -> void:
	var p = PauseMenu.new()
	p._ready()
	p.open()
	runner.check(p.shown and p.visible and p.cursor == PauseMenu.CONTINUE and p.played == ["pause"], "open: panel up on CONTINUE with the pause sound")
	runner.check(is_equal_approx(p.panel.scale.x, PauseMenu.POP_FROM) and is_zero_approx(p.panel.modulate.a), "the pop starts small")
	p._process(PauseMenu.POP_TIME * 0.5)
	runner.check(p.panel.scale.x > PauseMenu.POP_FROM and p.panel.modulate.a > 0.9, "half way through the pop")
	p._process(1.0)
	runner.check(is_equal_approx(p.panel.scale.x, 1.0) and is_equal_approx(p.anim_t, PauseMenu.POP_TIME), "landed, the clock stops at POP_TIME")
	p.open()
	runner.check(p.played == ["pause"], "a second open does nothing")
	p.move(1)
	runner.check(p.cursor == PauseMenu.RETRY and p.played[-1] == "cursor", "Down: RETRY with a tick")
	runner.check(p.rows[1].get_theme_color("font_color") == UiStyle.GOLD and p.rows[0].get_theme_color("font_color") == UiStyle.CREAM, "the gold moved to RETRY")
	runner.check(is_equal_approx(p.bar.position.y, PauseMenu.row_rect(1).position.y + PauseMenu.BAR_PAD), "the bar moved to RETRY")
	p.move(-1)
	p.move(-1)
	runner.check(p.cursor == PauseMenu.QUIT, "Up twice from RETRY wraps to QUIT")
	p.resume()
	runner.check(not p.shown and not p.visible and p.played[-1] == "resume", "Esc: panel away with the resume sound")
	p.resume()
	runner.check(p.played.count("resume") == 1, "a second resume does nothing")
	p.open()
	runner.check(p.cursor == PauseMenu.CONTINUE and is_zero_approx(p.anim_t), "the next open starts on CONTINUE with a fresh pop")
	p.pick(PauseMenu.CONTINUE)
	runner.check(not p.shown and p.picked == PauseMenu.CONTINUE and p.played[-1] == "resume", "Enter on CONTINUE resumes")
	p.free()
